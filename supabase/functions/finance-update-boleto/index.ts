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
    const { faturamento_id, isentar_juros, nova_data_vencimento } = body

    if (!faturamento_id) {
      throw new Error('faturamento_id is required')
    }

    // Buscar fatura original
    const { data: fatura } = await supabaseClient
      .from('faturamentos')
      .select('id, gateway_fatura_id, data_vencimento, status_pagamento')
      .eq('id', faturamento_id)
      .single()

    if (!fatura || !fatura.gateway_fatura_id) {
        throw new Error('Faturamento não encontrado ou sem ID no gateway.')
    }

    if (fatura.status_pagamento !== 'pendente' && fatura.status_pagamento !== 'vencido') {
        throw new Error('Apenas boletos pendentes ou vencidos podem ser alterados.')
    }

    // Preparar payload para o Asaas
    const updatePayload: any = {};
    if (isentar_juros) {
        updatePayload.fine = { value: 0, type: 'PERCENTAGE' };
        updatePayload.interest = { value: 0, type: 'PERCENTAGE' };
    }
    if (nova_data_vencimento) {
        updatePayload.dueDate = nova_data_vencimento;
    }

    if (Object.keys(updatePayload).length > 0) {
        const updateRes = await fetch(`${ASAAS_URL}/payments/${fatura.gateway_fatura_id}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'access_token': ASAAS_API_KEY },
            body: JSON.stringify(updatePayload)
        });
        
        const updateData = await updateRes.json();
        
        if (!updateRes.ok) {
            console.error('Falha Asaas Update:', updateData);
            throw new Error('Erro ao atualizar boleto no Asaas: ' + JSON.stringify(updateData));
        }

        // Atualizar banco de dados se a data mudou
        if (nova_data_vencimento) {
            await supabaseClient
              .from('faturamentos')
              .update({ data_vencimento: nova_data_vencimento, status_pagamento: 'pendente' })
              .eq('id', faturamento_id);
        }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Boleto atualizado com sucesso'
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
