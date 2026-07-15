import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const ASAAS_API_KEY = Deno.env.get("ASAAS_API_KEY") || "";
const ASAAS_URL = Deno.env.get("ASAAS_API_URL") || "https://sandbox.asaas.com/api/v3";

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const body = await req.json()
    const { acordo_id } = body

    if (!acordo_id) {
      throw new Error('acordo_id is required')
    }

    console.log(`[Agreement Pix] Fetching agreement info for ID: ${acordo_id}`);

    // 1. Get Agreement details
    const { data: agreement, error: agreementErr } = await supabaseClient
      .from('financeiro_acordos')
      .select('id, valor_acordo, parcelas_qtd, perfil_id')
      .eq('id', acordo_id)
      .single()

    if (agreementErr || !agreement) {
      throw new Error(`Agreement not found: ${agreementErr?.message || 'Unknown error'}`)
    }

    // 2. Get first installment details
    const { data: firstParcela, error: parcelaErr } = await supabaseClient
      .from('financeiro_acordo_parcelas')
      .select('id, valor, data_vencimento')
      .eq('acordo_id', acordo_id)
      .eq('numero_parcela', 1)
      .single()

    if (parcelaErr || !firstParcela) {
      throw new Error(`First installment not found: ${parcelaErr?.message || 'Unknown error'}`)
    }

    // 3. Fetch resident profile details
    const { data: resident, error: residentErr } = await supabaseClient
      .from('perfil')
      .select('id, nome_completo, email, whatsapp, gateway_customer_id')
      .eq('id', agreement.perfil_id)
      .single()

    if (residentErr || !resident) {
      throw new Error(`Resident profile not found: ${residentErr?.message || 'Unknown error'}`)
    }

    // 4. Resolve/create Asaas Customer
    let customerId = resident.gateway_customer_id;
    if (!customerId) {
      console.log(`[Agreement Pix] Creating new Asaas customer for: ${resident.nome_completo}`);
      const customerPayload: any = {
        name: resident.nome_completo || 'Morador Condomeet',
        email: resident.email || `morador-${resident.id}@condomeet.com`,
        cpfCnpj: '05864928283' // Mathematically valid mock CPF for sandbox
      };
      if (resident.whatsapp) {
        customerPayload.mobilePhone = resident.whatsapp;
      }

      const customerRes = await fetch(`${ASAAS_URL}/customers`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'access_token': ASAAS_API_KEY },
        body: JSON.stringify(customerPayload)
      });
      const customerData = await customerRes.json();

      if (customerData.id) {
        customerId = customerData.id;
        // Update database with customer id using service role/admin client to bypass normal RLS constraints
        await supabaseAdmin.from('perfil').update({ gateway_customer_id: customerId }).eq('id', resident.id);
      } else {
        throw new Error(`Failed to create Asaas customer: ${JSON.stringify(customerData)}`);
      }
    }

    console.log(`[Agreement Pix] Creating Asaas payment of R$ ${firstParcela.valor} for customer: ${customerId}`);

    // 5. Create Payment for 1st installment
    const paymentPayload = {
      customer: customerId,
      billingType: 'UNDEFINED',
      value: Number(firstParcela.valor),
      dueDate: firstParcela.data_vencimento,
      description: `Entrada Acordo Condominial - Parcela 1/${agreement.parcelas_qtd}`,
    };

    const paymentRes = await fetch(`${ASAAS_URL}/payments`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'access_token': ASAAS_API_KEY },
      body: JSON.stringify(paymentPayload)
    });
    const paymentData = await paymentRes.json();

    if (!paymentData.id) {
      throw new Error(`Failed to create Asaas payment: ${JSON.stringify(paymentData)}`);
    }

    console.log(`[Agreement Pix] Payment created: ${paymentData.id}. Fetching Pix QrCode...`);

    // 6. Fetch Pix QrCode
    const pixRes = await fetch(`${ASAAS_URL}/payments/${paymentData.id}/pixQrCode`, {
      headers: { 'access_token': ASAAS_API_KEY }
    });
    
    if (!pixRes.ok) {
      const pixErrText = await pixRes.text();
      throw new Error(`Failed to fetch Pix QrCode: ${pixRes.status} - ${pixErrText}`);
    }

    const pixData = await pixRes.json();
    const pixCopiaECola = pixData.payload || '';
    
    if (!pixCopiaECola) {
      throw new Error('Asaas returned an empty Pix Copia e Cola payload.');
    }

    const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(pixCopiaECola)}`;

    console.log(`[Agreement Pix] Pix fetched successfully. Updating financeiro_acordo_parcelas...`);

    // 7. Update first installment details in DB (using admin client to bypass user UPDATE restriction)
    const { error: updateErr } = await supabaseAdmin
      .from('financeiro_acordo_parcelas')
      .update({
        gateway_invoice_id: paymentData.id,
        gateway_invoice_url: paymentData.invoiceUrl || null,
        gateway_pix_copia_cola: pixCopiaECola,
        gateway_pix_qr_code: qrCodeUrl
      })
      .eq('id', firstParcela.id);

    if (updateErr) {
      throw new Error(`Failed to update installment credentials in DB: ${updateErr.message}`);
    }

    console.log(`[Agreement Pix] Setup complete! Returning credentials.`);

    return new Response(
      JSON.stringify({ 
        success: true, 
        gateway_pix_copia_cola: pixCopiaECola,
        gateway_pix_qr_code: qrCodeUrl,
        gateway_invoice_id: paymentData.id
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.error(`[Agreement Pix] Error: ${errorMsg}`);
    return new Response(
      JSON.stringify({ success: false, error: errorMsg }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
