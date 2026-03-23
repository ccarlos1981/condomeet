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
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { condominio_id, classificado_id, action } = await req.json()

    if (!condominio_id || !classificado_id || !action) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } })
    }

    // 1. Load Firebase service account
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if (!serviceAccountJson) {
      return new Response(JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT_JSON not set" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } })
    }
    const serviceAccount = JSON.parse(serviceAccountJson)
    const firebaseProjectId = serviceAccount.project_id

    // 2. Load Supabase admin client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // 3. Fetch classificado data
    const { data: classificado, error: classError } = await supabase
      .from("classificados")
      .select("*")
      .eq("id", classificado_id)
      .single()

    if (classError || !classificado) {
      return new Response(JSON.stringify({ error: "Classificado not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } })
    }

    // 4. Fetch creator profile
    const { data: criador } = await supabase
      .from("perfil")
      .select("nome_completo, bloco_txt, apto_txt, whatsapp, fcm_token")
      .eq("id", classificado.criado_por)
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

    let pushResults: any[] = []
    let whatsappResults: any[] = []

    // ══════════════════════════════════════════════════════════
    // ACTION: novo — Notify síndicos (Push + WhatsApp)
    // ══════════════════════════════════════════════════════════
    if (action === "novo") {
      // Fetch síndicos (use ilike for accent-safe matching)
      const { data: sindicos, error: sindicosError } = await supabase
        .from("perfil")
        .select("id, nome_completo, fcm_token, whatsapp")
        .eq("condominio_id", condominio_id)
        .or("papel_sistema.ilike.%síndico%,papel_sistema.ilike.%sindico%,papel_sistema.ilike.%subsíndico%,papel_sistema.ilike.%subsindico%,papel_sistema.eq.admin,papel_sistema.eq.ADMIN")

      console.log(`[classificados-notify] sindicos found: ${sindicos?.length ?? 0}, error: ${sindicosError?.message ?? 'none'}`)

      const validSindicos = (sindicos ?? []).filter((s: any) => s.fcm_token && s.fcm_token.length > 10)

      const pushTitle = "📦 Novo anúncio para aprovação"
      const pushBody = `${criador?.nome_completo ?? "Morador"} publicou: ${classificado.titulo}`

      // Push to síndicos
      pushResults = await Promise.all(
        validSindicos.map((s: any) =>
          sendFcmMessage(accessToken, firebaseProjectId, s.fcm_token, pushTitle, pushBody, {
            type: "classificado_novo",
            classificado_id,
          })
        )
      )

      // WhatsApp to síndicos via UazAPI
      const codInterno = classificado.cod_interno || Math.random().toString(36).substring(2, 7).toUpperCase()
      const whatsappMsg = `📦 Condomeet informa\n\nTem um novo anúncio do morador do:\nNome: ${criador?.nome_completo ?? "Morador"}\n\n${blocoLabel}: ${criador?.bloco_txt ?? "?"}\n${aptoLabel}: ${criador?.apto_txt ?? "?"}\n\nAnúncio: ${classificado.titulo}\n\nO anúncio está pronto para você avaliar e se estiver dentro do regimento do condomínio, aprovar.\n\nCondomeet agradece!\nCod. interno: ${codInterno}`

      const whatsappRecipients = (sindicos ?? []).filter((s: any) => s.whatsapp && s.whatsapp.length > 8)
      console.log(`[classificados-notify] WA recipients: ${whatsappRecipients.length}, UAZAPI_URL set: ${!!UAZAPI_URL}`)

      if (whatsappRecipients.length > 0 && UAZAPI_URL && UAZAPI_TOKEN) {
        for (const recipient of whatsappRecipients) {
          const phone = normalizePhone(recipient.whatsapp)
          console.log(`[classificados-notify] Sending WA to ${recipient.nome_completo} (${phone})...`)
          const result = await sendTextMessage(UAZAPI_URL, UAZAPI_TOKEN, phone, whatsappMsg)
          console.log(`[classificados-notify] WA result: ${result.success ? '✅' : '❌'} ${result.error || ''}`)
          whatsappResults.push({ success: result.success, subscriberId: phone, error: result.error })
          // Rate limit between sends
          if (whatsappRecipients.indexOf(recipient) < whatsappRecipients.length - 1) {
            await new Promise(r => setTimeout(r, 1000))
          }
        }
      } else {
        console.log(`[classificados-notify] SKIPPING WA: recipients=${whatsappRecipients.length} uazapi=${!!UAZAPI_URL}`)
      }
    }

    // ══════════════════════════════════════════════════════════
    // ACTION: aprovado — Push to creator + all moradores
    // ══════════════════════════════════════════════════════════
    else if (action === "aprovado") {
      const dataFormatada = new Date().toLocaleDateString("pt-BR")

      // Push to creator
      if (criador?.fcm_token && criador.fcm_token.length > 10) {
        const approvalTitle = `📰 ${condoNome}`
        const approvalBody = `Seu anúncio foi aprovado pelo Condomínio\nAnúncio: ${classificado.titulo}\n\nLembre-se que o anúncio terá validade de 60 dias.\nData: ${dataFormatada}\n\nCondomeet agradece!\nCod. interno: ${classificado.cod_interno}`

        const creatorResult = await sendFcmMessage(
          accessToken, firebaseProjectId, criador.fcm_token,
          approvalTitle, approvalBody,
          { type: "classificado_aprovado", classificado_id }
        )
        pushResults.push(creatorResult)
      }

      // Push to all moradores
      const { data: moradores } = await supabase
        .from("perfil")
        .select("id, fcm_token")
        .eq("condominio_id", condominio_id)
        .not("fcm_token", "is", null)
        .neq("id", classificado.criado_por)

      const validMoradores = (moradores ?? []).filter((m: any) => m.fcm_token && m.fcm_token.length > 10)

      const allTitle = `🛒 Novo classificado no ${condoNome}`
      const allBody = `${classificado.titulo}${classificado.preco ? ` — R$ ${Number(classificado.preco).toFixed(2)}` : ""}`

      const moradoresResults = await Promise.all(
        validMoradores.map((m: any) =>
          sendFcmMessage(accessToken, firebaseProjectId, m.fcm_token, allTitle, allBody, {
            type: "classificado_novo_publicado",
            classificado_id,
          })
        )
      )
      pushResults.push(...moradoresResults)

      // WhatsApp to creator via UazAPI
      if (criador?.whatsapp && criador.whatsapp.length > 8 && UAZAPI_URL && UAZAPI_TOKEN) {
        const codInterno = classificado.cod_interno || Math.random().toString(36).substring(2, 7).toUpperCase()
        const waMsg = `📰 ${condoNome}\n\nSeu anúncio foi aprovado pelo Condomínio!\n\nAnúncio: ${classificado.titulo}\n\nLembre-se que o anúncio terá validade de 60 dias.\nData: ${dataFormatada}\n\nCondomeet agradece!\nCod. interno: ${codInterno}`
        const phone = normalizePhone(criador.whatsapp)
        console.log(`[classificados-notify] Sending approval WA to creator ${criador.nome_completo} (${phone})`)
        const waResult = await sendTextMessage(UAZAPI_URL, UAZAPI_TOKEN, phone, waMsg)
        console.log(`[classificados-notify] WA approval result: ${waResult.success ? '✅' : '❌'} ${waResult.error || ''}`)
        whatsappResults.push({ success: waResult.success, subscriberId: phone, error: waResult.error })
      }
    }

    // ══════════════════════════════════════════════════════════
    // ACTION: rejeitado — Push to creator only
    // ══════════════════════════════════════════════════════════
    else if (action === "rejeitado") {
      if (criador?.fcm_token && criador.fcm_token.length > 10) {
        const rejectTitle = `📰 ${condoNome}`
        const rejectBody = `Seu anúncio "${classificado.titulo}" foi rejeitado pelo condomínio.\n\nPor favor, revise o conteúdo e tente novamente.\n\nCondomeet agradece!\nCod. interno: ${classificado.cod_interno}`

        const creatorResult = await sendFcmMessage(
          accessToken, firebaseProjectId, criador.fcm_token,
          rejectTitle, rejectBody,
          { type: "classificado_rejeitado", classificado_id }
        )
        pushResults.push(creatorResult)
      }
    }

    const pushSuccess = pushResults.filter((r: any) => r.success).length
    console.log(`[classificados-notify] action=${action} push=${pushSuccess}/${pushResults.length} wa=${whatsappResults.length}`)

    return new Response(
      JSON.stringify({
        action,
        push: { sent: pushSuccess, total: pushResults.length },
        whatsapp: { sent: whatsappResults.filter((r: any) => r.success).length, total: whatsappResults.length },
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err: any) {
    console.error("Unexpected error:", err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } })
  }
})
