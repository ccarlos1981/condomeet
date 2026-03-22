import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const UAZAPI_URL = Deno.env.get('UAZAPI_URL')
const UAZAPI_TOKEN = Deno.env.get('UAZAPI_TOKEN')

function genCodInterno(): string {
  return Math.random().toString(36).substring(2, 6).toUpperCase()
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return ''
  return dateStr.split('-').reverse().join('/')
}

async function sendWhatsApp(url: string, token: string, phone: string, msg: string): Promise<boolean> {
  try {
    const cleanedPhone = phone.replace(/\D/g, '')
    if (cleanedPhone.length < 10) return false
    const res = await fetch(`${url}/send/text`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'token': token },
      body: JSON.stringify({ number: cleanedPhone, text: msg }),
    })
    console.log(`WhatsApp → ${cleanedPhone}: ${res.ok ? '✅' : '❌'}`)
    return res.ok
  } catch (e) {
    console.error('WhatsApp error:', e)
    return false
  }
}

// Verifica documentos E contratos que vencem em exatamente 30, 60 ou 90 dias
// e dispara WhatsApp para síndicos e push para moradores.
serve(async (_req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const checks = [
      { dias: 30, campo: 'lembrar_30', evento: 'vencimento_30', label: '30 dias' },
      { dias: 60, campo: 'lembrar_60', evento: 'vencimento_60', label: '60 dias' },
      { dias: 90, campo: 'lembrar_90', evento: 'vencimento_90', label: '90 dias' },
    ]

    // Tables to check: documentos and contratos
    const tables = [
      { table: 'documentos', itemLabel: 'documento' },
      { table: 'contratos',  itemLabel: 'contrato'  },
    ]

    let totalDisparos = 0
    const log: unknown[] = []

    for (const { dias, campo, evento, label } of checks) {
      const alvo = new Date(today)
      alvo.setDate(alvo.getDate() + dias)
      const alvoStr = alvo.toISOString().slice(0, 10) // YYYY-MM-DD

      for (const { table, itemLabel } of tables) {
        const { data: docs, error } = await supabase
          .from(table)
          .select('id, titulo, categoria, data_expedicao, data_validade, condominio_id')
          .eq('data_validade', alvoStr)
          .eq(campo, true)

        if (error) {
          console.error(`Erro ao buscar ${campo} em ${table}:`, error.message)
          continue
        }

        for (const doc of docs ?? []) {
          // ── Fetch condo name ──
          const { data: condo } = await supabase.from('condominios').select('nome').eq('id', doc.condominio_id).single()
          const condoNome = condo?.nome || 'Condomínio'
          const labelCapital = itemLabel.charAt(0).toUpperCase() + itemLabel.slice(1)

          // ── WhatsApp to síndicos ──
          if (UAZAPI_URL && UAZAPI_TOKEN) {
            const { data: sindicos } = await supabase
              .from('perfil')
              .select('nome_completo, whatsapp, notificacoes_whatsapp')
              .eq('condominio_id', doc.condominio_id)
              .in('tipo_morador', ['Síndico'])

            for (const s of (sindicos ?? [])) {
              if (s.whatsapp?.trim() && s.notificacoes_whatsapp !== false) {
                const firstName = (s.nome_completo || 'Síndico').split(' ')[0]
                const cod = genCodInterno()
                const msg = `${labelCapital} do condomínio ${condoNome}\nEi, ${firstName}.\n\nO ${itemLabel} de Título:\n${doc.titulo || ''}\n\nCategoria do ${itemLabel}:\n${doc.categoria || ''}\n\nData de Expedição:\n${formatDate(doc.data_expedicao)}\n\nData de Validade:\n${formatDate(doc.data_validade)}\n\nVencerá daqui a ${label}.\n\nFique atento.\n\nCondomeet Agradece.\ncód interno: ${cod}`

                const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, s.whatsapp, msg)
                log.push({ table, doc_id: doc.id, sindico: firstName, canal: sent ? 'whatsapp_ok' : 'whatsapp_fail', dias })
                if (sent) totalDisparos++
              }
            }
          }

          // ── Push to moradores (via edge function) ──
          const res = await fetch(
            `${SUPABASE_URL}/functions/v1/documentos-push-notify`,
            {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
              },
              body: JSON.stringify({
                documento_id: doc.id,
                condominio_id: doc.condominio_id,
                titulo: doc.titulo,
                tipo_evento: evento,
              }),
            },
          )

          if (res.ok) {
            totalDisparos++
            log.push({ table, doc_id: doc.id, canal: 'push_moradores', dias })
          } else {
            const body = await res.text()
            console.error(`Falha ao notificar ${table} ${doc.id}:`, body)
            log.push({ table, doc_id: doc.id, canal: 'push_fail', dias, error: body })
          }
        }
      }
    }

    return new Response(
      JSON.stringify({ ok: true, disparos: totalDisparos, log }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
