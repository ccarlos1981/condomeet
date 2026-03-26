import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"
import { sendTextMessage, normalizePhone } from "../_shared/uazapi.ts"

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

// ── FCM HTTP v1 ─────────────────────────────────────────────────────────────

function pemToBinary(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "")
  const binary = atob(b64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const binaryDer = pemToBinary(serviceAccount.private_key)
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"]
  )
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: now, exp: now + 3600,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    },
    cryptoKey
  )
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  })
  const tokenData = await tokenRes.json()
  if (!tokenData.access_token) throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`)
  return tokenData.access_token
}

async function sendFcmMessage(
  accessToken: string, projectId: string, fcmToken: string,
  title: string, body: string, data: Record<string, string>
): Promise<{ success: boolean; token: string; error?: string }> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
  const payload = {
    message: {
      token: fcmToken,
      notification: { title, body },
      data,
      android: { priority: "high", notification: { channel_id: "avisos", sound: "condomeet" } },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "condomeet.aiff", badge: 1 } },
      },
    },
  }
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify(payload),
    })
    const result = await res.json()
    if (!res.ok) return { success: false, token: fcmToken, error: result?.error?.message ?? JSON.stringify(result) }
    return { success: true, token: fcmToken }
  } catch (e: any) {
    return { success: false, token: fcmToken, error: e.message }
  }
}

// ── CORS headers ────────────────────────────────────────────────────────────
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

// ── Main handler ────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { condominio_id, reservation_id, action } = await req.json()

    if (!condominio_id || !reservation_id || !action) {
      return new Response(JSON.stringify({ error: "Missing required fields: condominio_id, reservation_id, action" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    // 1. Firebase service account
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if (!serviceAccountJson) {
      return new Response(JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT_JSON not set" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }
    const serviceAccount = JSON.parse(serviceAccountJson)
    const firebaseProjectId = serviceAccount.project_id

    // 2. Supabase admin client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // 3. Fetch reservation + garage data
    const { data: reservation, error: resError } = await supabase
      .from("garage_reservations")
      .select("*")
      .eq("id", reservation_id)
      .single()

    if (resError || !reservation) {
      return new Response(JSON.stringify({ error: "Reservation not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    const { data: garage } = await supabase
      .from("garages")
      .select("spot_identifier, spot_type, owner_id")
      .eq("id", reservation.garage_id)
      .single()

    // 4. Fetch profiles
    const { data: renter } = await supabase
      .from("perfil")
      .select("nome_completo, bloco_txt, apto_txt, whatsapp, fcm_token")
      .eq("id", reservation.renter_id)
      .single()

    const { data: owner } = await supabase
      .from("perfil")
      .select("nome_completo, bloco_txt, apto_txt, whatsapp, fcm_token")
      .eq("id", garage?.owner_id)
      .single()

    // 5. Fetch condo info
    const { data: condoData } = await supabase
      .from("condominios")
      .select("nome, tipo_estrutura")
      .eq("id", condominio_id)
      .single()

    const tipoEstrutura = condoData?.tipo_estrutura ?? "predio"
    const condoNome = condoData?.nome ?? "Condomínio"
    const blocoLabel = getBlocoLabel(tipoEstrutura)
    const aptoLabel = getAptoLabel(tipoEstrutura)

    const accessToken = await getAccessToken(serviceAccount)
    const UAZAPI_URL = Deno.env.get("UAZAPI_URL") ?? ""
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN") ?? ""

    const pushResults: any[] = []
    const whatsappResults: any[] = []

    const startDate = new Date(reservation.start_date).toLocaleDateString("pt-BR")
    const endDate = new Date(reservation.end_date).toLocaleDateString("pt-BR")
    const vagaId = garage?.spot_identifier ?? "?"

    // ══════════════════════════════════════════════════════════
    // ACTION: reserva_nova — Notify garage owner
    // ══════════════════════════════════════════════════════════
    if (action === "reserva_nova") {
      const pushTitle = "🅿️ Nova solicitação de vaga"
      const pushBody = `${renter?.nome_completo ?? "Morador"} quer alugar sua vaga ${vagaId} de ${startDate} a ${endDate}`

      // Push to owner
      if (owner?.fcm_token && owner.fcm_token.length > 10) {
        const result = await sendFcmMessage(accessToken, firebaseProjectId, owner.fcm_token, pushTitle, pushBody, {
          type: "garagem_reserva_nova",
          reservation_id,
        })
        pushResults.push(result)
        console.log(`[garagem-notify] Owner push: ${result.success ? '✅' : '❌'} ${result.error || ''}`)
      }

      // WhatsApp to owner
      if (owner?.whatsapp && owner.whatsapp.length > 8 && UAZAPI_URL && UAZAPI_TOKEN) {
        const waMsg = `🅿️ Condomeet - ${condoNome}\n\nNova solicitação de aluguel de vaga!\n\nVaga: ${vagaId}\nSolicitante: ${renter?.nome_completo ?? "Morador"}\n${blocoLabel}: ${renter?.bloco_txt ?? "?"}\n${aptoLabel}: ${renter?.apto_txt ?? "?"}\n\nPeríodo: ${startDate} a ${endDate}\nVeículo: ${reservation.vehicle_model ?? ""} - Placa: ${reservation.vehicle_plate ?? ""}\nValor: R$ ${Number(reservation.total_price || 0).toFixed(2)}\n\nAcesse o app para confirmar ou recusar.\n\nCondomeet agradece!`
        const phone = normalizePhone(owner.whatsapp)
        const waResult = await sendTextMessage(UAZAPI_URL, UAZAPI_TOKEN, phone, waMsg)
        whatsappResults.push({ success: waResult.success, subscriberId: phone, error: waResult.error })
      }

      // Notify portaria too
      const { data: porteiros } = await supabase
        .from("perfil")
        .select("id, nome_completo, fcm_token")
        .eq("condominio_id", condominio_id)
        .or("papel_sistema.ilike.%porteiro%,papel_sistema.ilike.%portaria%")

      const validPorteiros = (porteiros ?? []).filter((p: any) => p.fcm_token && p.fcm_token.length > 10)
      const portariaTitle = "🅿️ Aluguel de vaga solicitado"
      const portariaBody = `${renter?.nome_completo ?? "Morador"} → Vaga ${vagaId} (${startDate} a ${endDate})`

      for (const p of validPorteiros) {
        const result = await sendFcmMessage(accessToken, firebaseProjectId, p.fcm_token, portariaTitle, portariaBody, {
          type: "garagem_reserva_portaria",
          reservation_id,
        })
        pushResults.push(result)
      }
    }

    // ══════════════════════════════════════════════════════════
    // ACTION: reserva_confirmada — Notify renter
    // ══════════════════════════════════════════════════════════
    else if (action === "reserva_confirmada") {
      const pushTitle = "✅ Vaga confirmada!"
      const pushBody = `Sua reserva da vaga ${vagaId} foi confirmada! Período: ${startDate} a ${endDate}`

      // Push to renter
      if (renter?.fcm_token && renter.fcm_token.length > 10) {
        const result = await sendFcmMessage(accessToken, firebaseProjectId, renter.fcm_token, pushTitle, pushBody, {
          type: "garagem_reserva_confirmada",
          reservation_id,
        })
        pushResults.push(result)
        console.log(`[garagem-notify] Renter push: ${result.success ? '✅' : '❌'} ${result.error || ''}`)
      }

      // WhatsApp to renter
      if (renter?.whatsapp && renter.whatsapp.length > 8 && UAZAPI_URL && UAZAPI_TOKEN) {
        const waMsg = `✅ Condomeet - ${condoNome}\n\nSua reserva de vaga foi confirmada!\n\nVaga: ${vagaId}\nProprietário: ${owner?.nome_completo ?? "?"}\nPeríodo: ${startDate} a ${endDate}\nValor: R$ ${Number(reservation.total_price || 0).toFixed(2)}\n\nLembre-se de combinar a entrega da chave/controle com o proprietário.\n\nCondomeet agradece!`
        const phone = normalizePhone(renter.whatsapp)
        const waResult = await sendTextMessage(UAZAPI_URL, UAZAPI_TOKEN, phone, waMsg)
        whatsappResults.push({ success: waResult.success, subscriberId: phone, error: waResult.error })
      }

      // Notify portaria about confirmed reservation
      const { data: porteiros } = await supabase
        .from("perfil")
        .select("id, fcm_token")
        .eq("condominio_id", condominio_id)
        .or("papel_sistema.ilike.%porteiro%,papel_sistema.ilike.%portaria%")

      const validPorteiros = (porteiros ?? []).filter((p: any) => p.fcm_token && p.fcm_token.length > 10)
      for (const p of validPorteiros) {
        const result = await sendFcmMessage(accessToken, firebaseProjectId, p.fcm_token,
          "✅ Vaga de garagem confirmada",
          `${renter?.nome_completo ?? "Morador"} → Vaga ${vagaId} (${startDate} a ${endDate})`,
          { type: "garagem_reserva_portaria_confirmada", reservation_id }
        )
        pushResults.push(result)
      }
    }

    // ══════════════════════════════════════════════════════════
    // ACTION: reserva_cancelada — Notify the other party
    // ══════════════════════════════════════════════════════════
    else if (action === "reserva_cancelada") {
      // Notify both parties
      const pushTitle = "❌ Reserva cancelada"
      const pushBody = `A reserva da vaga ${vagaId} (${startDate} a ${endDate}) foi cancelada.`

      for (const person of [owner, renter]) {
        if (person?.fcm_token && person.fcm_token.length > 10) {
          const result = await sendFcmMessage(accessToken, firebaseProjectId, person.fcm_token, pushTitle, pushBody, {
            type: "garagem_reserva_cancelada",
            reservation_id,
          })
          pushResults.push(result)
        }
      }
    }

    const pushSuccess = pushResults.filter((r: any) => r.success).length
    console.log(`[garagem-notify] action=${action} push=${pushSuccess}/${pushResults.length} wa=${whatsappResults.length}`)

    return new Response(
      JSON.stringify({
        action,
        push: { sent: pushSuccess, total: pushResults.length },
        whatsapp: { sent: whatsappResults.filter((r: any) => r.success).length, total: whatsappResults.length },
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err: any) {
    console.error("[garagem-notify] Unexpected error:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
