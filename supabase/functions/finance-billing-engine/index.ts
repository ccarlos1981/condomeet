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

    const body = await req.json()
    const { condominio_id, mes_referencia, boletos_rascunho } = body

    if (!condominio_id || !mes_referencia || !boletos_rascunho || !Array.isArray(boletos_rascunho)) {
      throw new Error('condominio_id, mes_referencia, and boletos_rascunho are required')
    }

    const { data: condo } = await supabaseClient
      .from('condominios')
      .select('gateway_account_id, multa_padrao, juros_mensal_padrao')
      .eq('id', condominio_id)
      .single()

    let mesReferenciaDate = mes_referencia;
    if (mes_referencia && mes_referencia.includes('/')) {
      const [m, y] = mes_referencia.split('/');
      mesReferenciaDate = `${y}-${m.padStart(2, '0')}-01`;
    }

    const errors: any[] = [];
    let gerados = 0;
    const dataVencimento = new Date();
    dataVencimento.setDate(dataVencimento.getDate() + 10); // Vence em 10 dias

    for (const rascunho of boletos_rascunho) {
       const { unidade_id, valor_total } = rascunho;
       
       if (!unidade_id || valor_total <= 0) continue;

       // Buscar dados da unidade e morador
        const { data: unidade } = await supabaseClient
          .from('unidades')
          .select('id, unidade_perfil(perfil(id, nome_completo, email, whatsapp, gateway_customer_id))')
          .eq('id', unidade_id)
          .single()

        const morador = unidade?.unidade_perfil?.[0]?.perfil; 

        if (morador) {
          // Integracao ASAAS
          let customerId = morador.gateway_customer_id;

          if (!customerId) {
             const customerPayload: any = {
               name: morador.nome_completo || `Morador Unidade ${unidade.id}`,
               email: morador.email || `morador-${unidade.id}@condomeet.com`,
               cpfCnpj: '05864928283'
             };
             if (morador.whatsapp) customerPayload.mobilePhone = morador.whatsapp;

            const customerRes = await fetch(`${ASAAS_URL}/customers`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', 'access_token': ASAAS_API_KEY },
              body: JSON.stringify(customerPayload)
            });
            const customerData = await customerRes.json();

            if (customerData.id) {
               customerId = customerData.id;
               await supabaseClient.from('perfil').update({ gateway_customer_id: customerId }).eq('id', morador.id);
            } else {
               console.error('Falha Asaas Customer:', customerData);
               errors.push({ unidade_id, error: customerData });
               continue; 
            }
         }

         const paymentPayload: any = {
            customer: customerId,
            billingType: 'UNDEFINED',
            value: valor_total,
            dueDate: dataVencimento.toISOString().split('T')[0],
            description: `Taxa Condominial - Ref: ${mes_referencia}`,
            fine: { value: Number(condo?.multa_padrao) || 2, type: 'PERCENTAGE' }, 
            interest: { value: Number(condo?.juros_mensal_padrao) || 3, type: 'PERCENTAGE' }, 
         };

         if (condo?.gateway_account_id) {
            paymentPayload.split = [
              {
                walletId: condo.gateway_account_id,
                percentualValue: 97 // Exemplo
              }
            ];
         }

         const paymentRes = await fetch(`${ASAAS_URL}/payments`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'access_token': ASAAS_API_KEY },
            body: JSON.stringify(paymentPayload)
         });
         const paymentData = await paymentRes.json();

         if (paymentData.id) {
             let pixCopiaECola = '';
             try {
                const pixRes = await fetch(`${ASAAS_URL}/payments/${paymentData.id}/pixQrCode`, {
                   headers: { 'access_token': ASAAS_API_KEY }
                });
                const pixData = await pixRes.json();
                pixCopiaECola = pixData.payload || '';
             } catch(e) { console.error('Falha PIX:', e); }

             const { data: fatRow, error: fatErr } = await supabaseClient
               .from('faturamentos')
               .insert({
                 condominio_id,
                 unidade_id: unidade.id,
                 morador_id: morador.id,
                 mes_referencia: mesReferenciaDate,
                 valor_total: valor_total,
                 data_vencimento: dataVencimento.toISOString().split('T')[0],
                 status_pagamento: 'pendente',
                 gateway_fatura_id: paymentData.id,
                 gateway_invoice_url: paymentData.invoiceUrl,
                 gateway_pix_copia_cola: pixCopiaECola
               })
               .select('id')
               .single();

              if (fatErr || !fatRow) {
                 console.error('Erro ao inserir faturamento:', fatErr);
                 errors.push({ unidade_id, error: fatErr || 'No fatRow returned' });
                 continue;
              }

             const faturamentoId = fatRow.id;

             // Fetch multas and reservations to breakdown items
             const { data: multas } = await supabaseClient
               .from('notificacoes_multas')
               .select('id, valor, titulo')
               .eq('unidade_id', unidade.id)
               .eq('tipo', 'MULTA')
               .eq('status', 'pendente');

              const userIds = unidade.unidade_perfil
                ?.map((up: any) => up.perfil?.id)
                .filter(Boolean) || [];

              let reservas: any[] = [];
              if (userIds.length > 0) {
                const { data: resData } = await supabaseClient
                  .from('reservas')
                  .select('id, valor_reserva, areas_comuns(tipo_agenda)')
                  .in('user_id', userIds)
                  .eq('status', 'aprovado')
                  .eq('status_pagamento', 'pendente');
                reservas = resData || [];
              }

             const itemsParaInserir: any[] = [];
             let totalAdicionais = 0;

             if (multas) multas.forEach(m => totalAdicionais += Number(m.valor || 0));
             if (reservas) reservas.forEach(r => totalAdicionais += Number(r.valor_reserva || 0));

             const valorBase = valor_total - totalAdicionais;

             // Add Base item
             itemsParaInserir.push({
               faturamento_id: faturamentoId,
               descricao: 'Taxa Condominial',
               valor: valorBase,
               tipo_item: 'ordinaria'
             });

             // Add multas items
             if (multas && multas.length > 0) {
               multas.forEach(m => {
                 itemsParaInserir.push({
                   faturamento_id: faturamentoId,
                   descricao: `Multa: ${m.titulo}`,
                   valor: m.valor,
                   tipo_item: 'multa',
                   referencia_id: m.id
                 });
               });
             }

             // Add reservations items
             if (reservas && reservas.length > 0) {
               const resIds = [];
               for (const r of reservas) {
                 itemsParaInserir.push({
                   faturamento_id: faturamentoId,
                   descricao: `Reserva: ${r.areas_comuns?.tipo_agenda || 'Área Comum'}`,
                   valor: r.valor_reserva,
                   tipo_item: 'reserva',
                   referencia_id: r.id
                 });
                 resIds.push(r.id);
               }

               // Mark reservations as faturado
               if (resIds.length > 0) {
                 await supabaseClient
                   .from('reservas')
                   .update({ status_pagamento: 'faturado' })
                   .in('id', resIds);
               }
             }

             // Bulk insert items
             if (itemsParaInserir.length > 0) {
               const { error: itemsErr } = await supabaseClient
                 .from('faturamento_itens')
                 .insert(itemsParaInserir);
               if (itemsErr) {
                 console.error('Erro ao inserir faturamento_itens:', itemsErr);
                 errors.push({ unidade_id, error: itemsErr });
               }
             }

             gerados++;
         } else {
             console.error('Falha Asaas Payment:', paymentData);
             errors.push({ unidade_id, error: paymentData });
         }
       }
    }

    // Faturas já gravadas individualmente com seus itens e baixas de reservas correspondentes

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Engine finalizado com Asaas',
        boletos_gerados: gerados,
        errors,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
