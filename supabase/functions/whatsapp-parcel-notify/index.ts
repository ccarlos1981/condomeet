// whatsapp-parcel-notify — Supabase Edge Function
// Sends WhatsApp notification to residents when a parcel arrives or is delivered.
// Uses UazAPI for WhatsApp messaging.

import { createClient } from "npm:@supabase/supabase-js@2"
import { sendTextMessage, sendImageMessage, normalizePhone } from "../_shared/uazapi.ts"

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

    const UAZAPI_URL = Deno.env.get('UAZAPI_URL')
    const UAZAPI_TOKEN = Deno.env.get('UAZAPI_TOKEN')
    if (!UAZAPI_URL || !UAZAPI_TOKEN) {
      return new Response(JSON.stringify({ error: "UAZAPI_URL or UAZAPI_TOKEN not configured" }), { status: 500 })
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
      .select('id, nome_completo, whatsapp, notificacoes_whatsapp')
      .eq('condominio_id', condominio_id)
      .eq('bloco_txt', bloco)
      .eq('apto_txt', apto)
      .eq('status_aprovacao', 'aprovado')
      .eq('bloqueado', false)
      .eq('notificacoes_whatsapp', true)
      .not('whatsapp', 'is', null)

    if (error || !profiles || profiles.length === 0) {
      console.log(`No residents with whatsapp in ${bloco}/${apto}`)
      return new Response(JSON.stringify({ error: "Nenhum contato encontrado para notificação" }), { status: 200 })
    }

    console.log(`[${event}] Sending parcel WhatsApp to ${profiles.length} resident(s) of unit ${bloco}/${apto}`)

    const results: { success: boolean; nome: string; error?: string }[] = []

    for (let i = 0; i < profiles.length; i++) {
      const profile = profiles[i]
      const phone = normalizePhone(profile.whatsapp)

      try {
        // Generate internal code for anti-ban
        const codInterno = Math.random().toString(36).substring(2, 7).toUpperCase()

        let txtMsg: string

        if (event === 'arrived') {
          // ── Arrival message ──
          const createdDate = parcelData?.created_at ? new Date(parcelData.created_at as string) : new Date()
          createdDate.setDate(createdDate.getDate() + 7)
          const withdrawUntil = createdDate.toLocaleDateString('pt-BR', {
            timeZone: 'America/Sao_Paulo',
            day: '2-digit', month: '2-digit', year: 'numeric',
          })

          const observationText = (parcelData?.observacao as string)?.trim() || (parcelData?.notes as string)?.trim() || 'Nenhuma'
          const trackingCode = (parcelData?.tracking_code as string)?.trim() || 'Nenhum'

          txtMsg = `📦 ${condoNome}\n\nChegou uma encomenda para o seu apartamento.\n\n📨 Tipo de encomenda:\n${tipo || 'Pacote'}\n\n🏢 Unidade\n${blocoLabel}: ${bloco} / ${aptoLabel}: ${apto}\n\n🔍 Cod. rastreio: ${trackingCode}\n\n⏱ Retirar até: ${withdrawUntil}\n\n🗒️ Observação da encomenda:\n${observationText}\n\nCondomeet agradece!\nCod. interno: ${codInterno}`
        } else {
          // ── Delivery message ──
          const deliveryTime = parcelData?.delivery_time
            ? new Date(parcelData.delivery_time as string)
            : new Date()
          const deliveryStr = deliveryTime.toLocaleString('pt-BR', {
            timeZone: 'America/Sao_Paulo',
            day: '2-digit', month: '2-digit', year: 'numeric',
            hour: '2-digit', minute: '2-digit',
          })

          const whoPickedUp = (picked_up_by_name as string)?.trim() || 'Morador'

          txtMsg = `✅ ${condoNome}\n\nEncomenda retirada com sucesso!\n\n📨 Tipo: ${tipo || 'Pacote'}\n\n🏢 Unidade\n${blocoLabel}: ${bloco} / ${aptoLabel}: ${apto}\n\n👤 Retirada por: ${whoPickedUp}\n📅 Data/Hora: ${deliveryStr}\n\nCondomeet agradece!\nCod. interno: ${codInterno}`
        }

        const result = await sendTextMessage(UAZAPI_URL, UAZAPI_TOKEN, phone, txtMsg)
        console.log(`WhatsApp to ${profile.nome_completo}: ${result.success ? "✅" : "❌"}`)

        // Send photo on 'arrived' if available
        console.log(`Photo URL for parcel: ${parcelData?.photo_url ? 'PRESENT' : 'MISSING'}`)
        if (event === 'arrived' && result.success && parcelData?.photo_url) {
          // Delay before sending photo (anti-spam + ensure upload complete)
          await new Promise(res => setTimeout(res, 3000))
          const photoResult = await sendImageMessage(UAZAPI_URL, UAZAPI_TOKEN, phone, parcelData.photo_url as string, "📸 Foto da encomenda")
          console.log(`Photo to ${profile.nome_completo}: ${photoResult.success ? "✅" : "❌"} ${photoResult.error || ''}`)
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
