import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// Varredura diária de vigência e prazos de contratos inteligentes
// Dispara alertas administrativos em 90 dias, 30 dias, Vence Hoje e Pós-Vencimento (1 dia após).
serve(async (_req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const checks = [
      { dias: 90, campoLembrete: 'lembrar_90', evento: '90_DIAS' },
      { dias: 30, campoLembrete: 'lembrar_30', evento: '30_DIAS' },
      { dias: 0, campoLembrete: null, evento: 'VENCE_HOJE' },
      { dias: -1, campoLembrete: null, evento: 'VENCIDO' },
    ]

    let totalDisparos = 0
    let totalIgnorados = 0

    for (const { dias, campoLembrete, evento } of checks) {
      const alvo = new Date(today)
      alvo.setDate(alvo.getDate() + dias)
      const alvoStr = alvo.toISOString().slice(0, 10)

      let query = supabase
        .from('contratos')
        .select('id, titulo, condominio_id, fornecedor_id, fornecedor_nome, valor_mensal, data_validade, sem_validade, lembrar_30, lembrar_90, fornecedores(nome)')
        .eq('data_validade', alvoStr)
        .eq('sem_validade', false)

      if (campoLembrete) {
        query = query.eq(campoLembrete, true)
      }

      const { data: contratos, error } = await query

      if (error) {
        console.error(`Erro ao buscar contratos para evento ${evento} (${alvoStr}):`, error.message)
        continue
      }

      for (const contrato of contratos ?? []) {
        // Ignora contratos sem validade ou sem data
        if (contrato.sem_validade || !contrato.data_validade) {
          totalIgnorados++
          continue
        }

        const fornecedorResolvido = (contrato.fornecedores as unknown as { nome: string } | null)?.nome ||
          contrato.fornecedor_nome ||
          'Fornecedor'

        const res = await fetch(
          `${SUPABASE_URL}/functions/v1/contratos-push-notify`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            },
            body: JSON.stringify({
              contrato_id: contrato.id,
              condominio_id: contrato.condominio_id,
              titulo: contrato.titulo,
              fornecedor_nome: fornecedorResolvido,
              valor_mensal: contrato.valor_mensal,
              data_validade: contrato.data_validade,
              tipo_evento: evento,
            }),
          },
        )

        if (res.ok) {
          const respData = await res.json()
          totalDisparos += respData.sent ?? 0
        } else {
          const body = await res.text()
          console.error(`Falha ao notificar contrato ${contrato.id} (${evento}):`, body)
        }
      }
    }

    return new Response(
      JSON.stringify({ ok: true, disparos: totalDisparos, ignorados: totalIgnorados }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
