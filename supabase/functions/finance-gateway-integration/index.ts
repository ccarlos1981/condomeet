import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const ASAAS_WEBHOOK_TOKEN = Deno.env.get('ASAAS_WEBHOOK_TOKEN')

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const asaasToken = req.headers.get('asaas-access-token')
  if (ASAAS_WEBHOOK_TOKEN && asaasToken !== ASAAS_WEBHOOK_TOKEN) {
    return new Response('Unauthorized', { status: 401 })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    
    // Ler o payload do Webhook (Exemplo padrão Asaas)
    const payload = await req.json()
    
    console.log('Webhook recebido:', JSON.stringify(payload))

    // Validar tipo de evento (Asaas usa PAYMENT_RECEIVED, PAYMENT_CONFIRMED)
    if (!payload.event || !payload.payment) {
      return new Response(JSON.stringify({ error: 'Payload inválido' }), { status: 400 })
    }

    const eventType = payload.event
    const gatewayId = payload.payment.id

    // Só nos interessa pagamentos confirmados/recebidos
    if (eventType === 'PAYMENT_RECEIVED' || eventType === 'PAYMENT_CONFIRMED') {
      
      // Busca o Faturamento correspondente no nosso banco usando o gateway_fatura_id
      const { data: faturamento, error: fetchError } = await supabase
        .from('faturamentos')
        .select('id, status_pagamento')
        .eq('gateway_fatura_id', gatewayId)
        .single()

      if (fetchError || !faturamento) {
        console.error('Faturamento não encontrado para o gateway ID:', gatewayId)
        // Retorna 200 pro gateway parar de tentar enviar, mas registra o erro internamente
        return new Response('Faturamento não encontrado', { status: 200 })
      }

      // Se já estiver pago, ignora
      if (faturamento.status_pagamento === 'pago') {
        return new Response('Faturamento já estava pago', { status: 200 })
      }

      // Atualiza o status para pago
      const { error: updateError } = await supabase
        .from('faturamentos')
        .update({ 
          status_pagamento: 'pago',
          data_pagamento: new Date().toISOString()
        })
        .eq('id', faturamento.id)

      if (updateError) {
        throw updateError
      }

      console.log(`Faturamento ${faturamento.id} marcado como pago via Webhook!`)

      // (Opcional) Podemos chamar a função universal-push-notify aqui para avisar o morador
      // await fetch('https://[PROJECT_REF].functions.supabase.co/universal-push-notify', ...)

      return new Response(JSON.stringify({ success: true, message: 'Faturamento liquidado.' }), { 
        headers: { 'Content-Type': 'application/json' },
        status: 200 
      })
    }

    // Outros eventos (vencido, estornado) podem ser tratados aqui futuramente
    return new Response('Evento ignorado', { status: 200 })

  } catch (err) {
    console.error('Webhook error:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
