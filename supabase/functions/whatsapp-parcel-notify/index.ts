// whatsapp-parcel-notify — Supabase Edge Function
// Sends WhatsApp notification to residents when a parcel arrives or is delivered.
// Uses BotConversa for WhatsApp messaging.

import { createClient } from "npm:@supabase/supabase-js@2"
import { sendToRecipients, smartSend, MessageType } from "../_shared/botconversa.ts"

// ── Dynamic structure labels ────────────────────────────────────────────────
function getBlocoLabel(tipo?: string): string {
  if (tipo === 'casa_quadra') return 'Quadra'
  if (tipo === 'casa_rua') return 'Rua'
  return 'Bloco'
}
function getAptoLabel(tipo?: string): string {
  if (tipo === 'casa_quadra') return 'Lote'
  if (tipo === 'casa_rua') return 'Número'
  return 'Apto'
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    })
  }

  try {
    const { parcel_id, event, condominio_id, bloco, apto, tipo, picked_up_by_name } = await req.json()

    // Only process known events
    if (event !== 'arrived' && event !== 'delivered') {
      return new Response(JSON.stringify({ skipped: true, reason: `Evento '${event}' ignorado` }), { status: 200 })
    }

    // ── Init ──────────────────────────────────────────────────────────
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY")
    if (!BOTCONVERSA_API_KEY) {
      return new Response(JSON.stringify({ error: "BOTCONVERSA_API_KEY not configured" }), { status: 500 })
    }

    // ── Fetch condo info ──────────────────────────────────────────────
    let condoNome = "Condomínio"
    let tipoEstrutura = 'predio'
    if (condominio_id) {
      const { data: condo } = await supabaseAdmin.from('condominios').select('nome, tipo_estrutura').eq('id', condominio_id).single()
      if (condo) {
        condoNome = condo.nome
        tipoEstrutura = condo.tipo_estrutura || 'predio'
      }
    }
    const blocoLabel = getBlocoLabel(tipoEstrutura)
    const aptoLabel = getAptoLabel(tipoEstrutura)

    // ── Fetch parcel data ─────────────────────────────────────────────
    let parcelData: Record<string, unknown> | null = null
    if (parcel_id) {
      const { data: enc } = await supabaseAdmin.from('encomendas').select('*').eq('id', parcel_id).single()
      parcelData = enc
    }

    // ── Fetch residents with whatsapp ─────────────────────────────────
        const { data: profiles, error } = await supabaseAdmin
      .from('perfil')
      .select('id, nome_completo, whatsapp, botconversa_id, notificacoes_whatsapp')
      .eq('condominio_id', condominio_id)
      .eq('bloco_txt', bloco)
      .eq('apto_txt', apto)
      .eq('status_aprovacao', 'aprovado')
      .eq('bloqueado', false)
      .eq('notificacoes_whatsapp', true)
      .not('whatsapp', 'is', null)
      .neq('whatsapp', '')

    if (error || !profiles || profiles.length === 0) {
      console.log(`No residents with whatsapp number in ${bloco}/${apto}`)
      return new Response(JSON.stringify({ error: "Nenhum contato encontrado para notificação" }), { status: 200 })
    }

    console.log(`[${event}] Sending parcel WhatsApp to ${profiles.length} resident(s) of unit ${bloco}/${apto}`)

    const results: { success: boolean; nome: string; error?: string }[] = []

    for (let i = 0; i < profiles.length; i++) {
      const profile = profiles[i]

      try {
        // Generate internal code for anti-ban
        const codInterno = Math.random().toString(36).substring(2, 7).toUpperCase()

        let txtMsg: string
        let msgTypeToSend: string
        let templateParamsToSend: string[]

        if (event === 'arrived') {
          // ── Arrival message ──
          msgTypeToSend = MessageType.PARCEL
          const createdDate = parcelData?.created_at ? new Date(parcelData.created_at as string) : new Date()
          createdDate.setDate(createdDate.getDate() + 7)
          const withdrawUntil = createdDate.toLocaleDateString('pt-BR', {
            timeZone: 'America/Sao_Paulo',
            day: '2-digit', month: '2-digit', year: 'numeric',
          })

          const observationText = (parcelData?.observacao as string)?.trim() || (parcelData?.notes as string)?.trim() || 'Nenhuma'
          const trackingCode = (parcelData?.tracking_code as string)?.trim() || 'Nenhum'

          txtMsg = `📦 ${condoNome}\n\nChegou uma encomenda para o seu apartamento.\n\n📨 Tipo de encomenda:\n${tipo || 'Pacote'}\n\n🏢 Unidade\n${blocoLabel}: ${bloco} / ${aptoLabel}: ${apto}\n\n🔍 Cod. rastreio: ${trackingCode}\n\n⏱ Retirar até: ${withdrawUntil}\n\n🗒️ Observação da encomenda:\n${observationText}\n\nCondomeet agradece!\nCod. interno: ${codInterno}`

          templateParamsToSend = [
            condoNome,
            tipo || "Pacote",
            blocoLabel || "Bloco",
            bloco || "—",
            aptoLabel || "Apto",
            apto || "—",
            trackingCode || "Não informado",
            withdrawUntil || "Imediato",
            observationText || "Sem observação"
          ]
        } else {
          // ── Delivery / Pickup message ──
          msgTypeToSend = MessageType.PARCEL_DELIVERED
          const arrivalDate = parcelData?.created_at ? new Date(parcelData.created_at as string) : new Date()
          const arrivalDateStr = arrivalDate.toLocaleString('pt-BR', {
            timeZone: 'America/Sao_Paulo',
            day: '2-digit', month: '2-digit', year: 'numeric',
            hour: '2-digit', minute: '2-digit',
          })

          const deliveryTime = parcelData?.delivery_time
            ? new Date(parcelData.delivery_time as string)
            : new Date()
          const deliveryStr = deliveryTime.toLocaleString('pt-BR', {
            timeZone: 'America/Sao_Paulo',
            day: '2-digit', month: '2-digit', year: 'numeric',
            hour: '2-digit', minute: '2-digit',
          })

          const whoPickedUp = (picked_up_by_name as string)?.trim() || profile.nome_completo || 'Morador'

          txtMsg = `📦 ${condoNome}\n\nOlá, ${profile.nome_completo || 'Morador'}! 👋\n\nInformamos que a encomenda abaixo foi entregue com sucesso.\n\n📦 ${tipo || 'Pacote'}\n\nRecebida em:\n${arrivalDateStr}\n\nRetirada em:\n${deliveryStr}\n\nObrigado.\n\nCondomeet.`

          templateParamsToSend = [
            condoNome,
            tipo || "caixa",
            bloco || "—",
            apto || "—",
            whoPickedUp,
            deliveryStr,
            parcel_id.substring(0, 5).toUpperCase()
          ]
        }

        const result = await smartSend(
          BOTCONVERSA_API_KEY,
          profile.botconversa_id,
          profile.whatsapp,
          "text",
          txtMsg,
          profile.nome_completo?.split(" ")[0],
          supabaseAdmin,
          profile.id,
          msgTypeToSend,
          "whatsapp-parcel-notify",
          templateParamsToSend
        )
        console.log(`WhatsApp to ${profile.nome_completo}: ${result.success ? "✅" : "❌"}`)

        // Send photo on 'arrived' if available (non-blocking to prevent pg_net timeout)
        console.log(`Photo URL for parcel: ${parcelData?.photo_url ? 'PRESENT' : 'MISSING'}`)
        if (event === 'arrived' && result.success && parcelData?.photo_url) {
          (async () => {
            try {
              const delayObj = Math.floor(Math.random() * (5000 - 2000 + 1) + 2000)
              console.log(`Waiting ${delayObj}ms before sending photo to bypass anti-spam...`)
              await new Promise(res => setTimeout(res, delayObj))
              
              const photoResult = await smartSend(
                BOTCONVERSA_API_KEY,
                profile.botconversa_id,
                profile.whatsapp,
                "file",
                parcelData.photo_url as string,
                profile.nome_completo?.split(" ")[0],
                supabaseAdmin,
                profile.id,
                MessageType.PARCEL,
                "whatsapp-parcel-notify"
              )
              console.log(`Photo to ${profile.nome_completo}: ${photoResult.success ? "✅" : "❌"} ${photoResult.error || ''}`)
            } catch (pErr) {
              console.error(`Async photo error:`, pErr)
            }
          })()
        }

        results.push({ success: result.success, nome: profile.nome_completo, error: result.error })
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err)
        results.push({ success: false, nome: profile.nome_completo, error: msg })
      }
    }

    const hasSuccess = results.some(r => r.success)

    // ALWAYS return 200 to prevent DB trigger retries via net.http_post
    // Failed sends are logged but should NOT cause the function to return 500
    return new Response(JSON.stringify({
      event,
      messages_sent: results.length,
      success: hasSuccess,
      results
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error)
    return new Response(JSON.stringify({ error: msg }), { status: 500 })
  }
})
