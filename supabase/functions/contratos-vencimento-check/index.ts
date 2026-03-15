import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// Verifica contratos que vencem em exatamente 30, 60 ou 90 dias
// e dispara push para cada um que tiver o lembrete configurado.
serve(async (_req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const checks = [
      { dias: 30, campo: 'lembrar_30', evento: 'vencimento_30' },
      { dias: 60, campo: 'lembrar_60', evento: 'vencimento_60' },
      { dias: 90, campo: 'lembrar_90', evento: 'vencimento_90' },
    ]

    let totalDisparos = 0

    for (const { dias, campo, evento } of checks) {
      const alvo = new Date(today)
      alvo.setDate(alvo.getDate() + dias)
      const alvoStr = alvo.toISOString().slice(0, 10)

      const { data: contratos, error } = await supabase
        .from('contratos')
        .select('id, titulo, condominio_id')
        .eq('data_validade', alvoStr)
        .eq(campo, true)

      if (error) {
        console.error(`Erro ao buscar ${campo}:`, error.message)
        continue
      }

      for (const contrato of contratos ?? []) {
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
              tipo_evento: evento,
            }),
          },
        )

        if (res.ok) totalDisparos++
        else {
          const body = await res.text()
          console.error(`Falha ao notificar contrato ${contrato.id}:`, body)
        }
      }
    }

    return new Response(
      JSON.stringify({ ok: true, disparos: totalDisparos }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
