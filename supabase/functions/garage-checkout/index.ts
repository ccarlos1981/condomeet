import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const ASAAS_API_KEY = Deno.env.get("ASAAS_API_KEY") || "";
const ASAAS_URL = Deno.env.get("ASAAS_API_URL") || "https://www.asaas.com/api/v3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    const { reservation_id } = await req.json();
    if (!reservation_id) throw new Error("reservation_id is required");

    // 1. Get reservation details
    const { data: reservation, error: resError } = await supabaseClient
      .from("garage_reservations")
      .select(`
        *,
        garages (
          id, chave_pix,
          perfil!garages_owner_id_fkey (nome_completo)
        ),
        perfil!garage_reservations_user_id_fkey (nome_completo, cpf, email)
      `)
      .eq("id", reservation_id)
      .single();

    if (resError || !reservation) throw new Error("Reservation not found");

    if (reservation.payment_status === 'pago') {
      return new Response(JSON.stringify({ error: "Reserva já está paga" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    // Se já gerou cobrança, retorna a mesma
    if (reservation.payment_id && reservation.payment_qr_code) {
       return new Response(
        JSON.stringify({
          qrCode: reservation.payment_qr_code,
          copyPaste: reservation.payment_copy_paste,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const valorTotal = Number(reservation.valor_total);
    const taxaPlataforma = valorTotal * 0.15;
    const valorLiquido = valorTotal - taxaPlataforma;

    // 2. Create Asaas Customer for the renter
    const renter = reservation.perfil;
    let customerId = "";
    
    // We try to create a customer. If it exists by CPF/email, Asaas might return it, 
    // but typically we can just create one or use a default one for quick PIX.
    // For simplicity, we just create a customer on the fly.
    const customerPayload = {
      name: renter.nome_completo || "Morador Condomeet",
      cpfCnpj: renter.cpf || "00000000000", // Asaas requires CPF for PIX generation in some cases.
      email: renter.email,
    };

    const customerRes = await fetch(`${ASAAS_URL}/customers`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "access_token": ASAAS_API_KEY,
      },
      body: JSON.stringify(customerPayload),
    });

    const customerData = await customerRes.json();
    if (customerData.id) {
      customerId = customerData.id;
    } else if (customerData.errors) {
      console.log("Customer creation error, maybe already exists or invalid CPF. Using generic logic.", customerData.errors);
      // Fallback: If creation fails due to invalid CPF, we might need a generic customer or handle it.
      // PIX sometimes allows generation without strict CPF if the account is approved.
      // To ensure it works, let's assume the user has a valid CPF in their profile, or we throw.
      throw new Error(`Asaas Customer Error: ${customerData.errors[0]?.description}`);
    }

    // 3. Create Asaas PIX Charge
    const chargePayload = {
      customer: customerId,
      billingType: "PIX",
      value: valorTotal,
      dueDate: new Date(Date.now() + 86400000).toISOString().split('T')[0], // tomorrow
      description: `Reserva Garagem #${reservation_id.split('-')[0]}`,
      externalReference: reservation_id,
    };

    const chargeRes = await fetch(`${ASAAS_URL}/payments`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "access_token": ASAAS_API_KEY,
      },
      body: JSON.stringify(chargePayload),
    });

    const chargeData = await chargeRes.json();
    if (chargeData.errors) {
      throw new Error(`Asaas Charge Error: ${chargeData.errors[0]?.description}`);
    }

    const paymentId = chargeData.id;

    // 4. Get QR Code for the Charge
    const qrRes = await fetch(`${ASAAS_URL}/payments/${paymentId}/pixQrCode`, {
      headers: {
        "access_token": ASAAS_API_KEY,
      },
    });
    const qrData = await qrRes.json();
    
    if (qrData.errors) {
      throw new Error("Failed to get PIX QR Code");
    }

    const qrCode = qrData.encodedImage;
    const copyPaste = qrData.payload;

    // 5. Update Database
    const supabaseServiceRole = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    await supabaseServiceRole
      .from("garage_reservations")
      .update({
        taxa_plataforma: taxaPlataforma,
        valor_liquido: valorLiquido,
        payment_id: paymentId,
        payment_qr_code: qrCode,
        payment_copy_paste: copyPaste,
      })
      .eq("id", reservation_id);

    return new Response(
      JSON.stringify({ qrCode, copyPaste }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
