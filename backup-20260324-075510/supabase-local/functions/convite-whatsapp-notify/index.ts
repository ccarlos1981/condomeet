// convite-whatsapp-notify — Supabase Edge Function
// Called by DB triggers when:
//   1. A convite (visitor invitation) is created  (action: 'created' / default)
//   2. Porteiro releases visitor entry             (action: 'entry_released')
// Sends WhatsApp notification to resident + visitor (if phone provided) via UazAPI.
// Also sends FCM push notification to resident on entry_released.
// Also upserts visitor contact to contatos_visitantes (agenda).

import { createClient } from "npm:@supabase/supabase-js@2"
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.9.1/mod.ts"
import { sendTextMessage } from "../_shared/uazapi.ts"

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


const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      Connection: "keep-alive",
    },
  })
}

function isSecretKey(token: string): boolean {
  // Accept sb_secret_ keys
  if (token.startsWith("sb_secret_")) return true
  // Accept exact match with SUPABASE_SERVICE_ROLE_KEY env
  const envKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  if (envKey && token === envKey) return true
  // Accept JWT tokens with service_role
  try {
    const parts = token.split(".")
    if (parts.length === 3) {
      const payload = JSON.parse(atob(parts[1]))
      if (payload.role === "service_role") return true
    }
  } catch { /* not a valid JWT */ }
  return false
}

function genCodInterno(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  return Array.from({ length: 5 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
}

/** Extract short 3-char code from qr_data (handles legacy format like condomeet_inv_xxx_TEG) */
function extractShortCode(qrData: string | null | undefined): string {
  if (!qrData) return '---'
  // If it contains underscores (legacy format), take the last segment
  if (qrData.includes('_')) {
    const parts = qrData.split('_')
    return parts[parts.length - 1].toUpperCase()
  }
  // Already a short code (3 chars)
  return qrData.toUpperCase()
}

// ── FCM Push Notification helpers ─────────────────────────────────────────

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

async function getFcmAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: getNumericDate(3600),
  }

  const binaryDer = pemToBinary(serviceAccount.private_key)
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )

  const jwt = await create({ alg: "RS256" as const, typ: "JWT" }, payload, cryptoKey)

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  })

  const tokenData = await tokenRes.json()
  if (!tokenData.access_token) {
    throw new Error(`FCM access token failed: ${JSON.stringify(tokenData)}`)
  }
  return tokenData.access_token
}

async function sendFcmPush(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<{ success: boolean; error?: string }> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
  const message = {
    message: {
      token: fcmToken,
      notification: { title, body },
      data,
      android: { priority: "high", notification: { channel_id: "avisos", sound: "condomeet" } },
      apns: {
        payload: { aps: { sound: "condomeet.aiff", badge: 1 } },
      },
    },
  }

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(message),
    })
    if (!res.ok) {
      const result = await res.json()
      return { success: false, error: result?.error?.message ?? JSON.stringify(result) }
    }
    return { success: true }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e)
    return { success: false, error: msg }
  }
}

function formatDateBR(dateStr: string): string {
  if (!dateStr) return "—"
  try {
    const dt = new Date(dateStr)
    return `${String(dt.getDate()).padStart(2, "0")}/${String(dt.getMonth() + 1).padStart(2, "0")}/${dt.getFullYear()}`
  } catch {
    return dateStr
  }
}

// ── Phone cleaning ────────────────────────────────────────────────────────
// Ensures format: 55 + DDD(2) + 9 + number(8) = 13 digits
function cleanPhone(raw: string): string {
  let phone = raw.replace(/\D/g, "")

  // Add country code if missing
  if (!phone.startsWith("55")) {
    phone = "55" + phone
  }

  // Ensure 9th digit: if phone is 12 digits (55 + DDD + 8 digits), add '9'
  // Format: 55 + XX + 9XXXXXXXX = 13 digits
  if (phone.length === 12) {
    const ddd = phone.substring(2, 4)
    const number = phone.substring(4)
    phone = "55" + ddd + "9" + number
  }

  return phone
}

// ── UazAPI: send WhatsApp message ────────────────────────────────────────
async function sendWhatsApp(
  uazapiUrl: string,
  uazapiToken: string,
  phone: string,
  message: string
): Promise<boolean> {
  const result = await sendTextMessage(uazapiUrl, uazapiToken, phone, message)
  return result.success
}

// ══════════════════════════════════════════════════════════════════════════
//  ACTION: created (convite criado pelo morador)
// ══════════════════════════════════════════════════════════════════════════
async function handleCreated(
  payload: Record<string, unknown>,
  supabase: ReturnType<typeof createClient>,
  uazapiUrl: string,
  uazapiToken: string
): Promise<Response> {
  const {
    convite_id,
    resident_id,
    condominio_id,
    guest_name,
    visitor_phone,
    validity_date,
    qr_data,
  } = payload as Record<string, string>

  // ── Fetch resident data ──────────────────────────────────────────
  const { data: perfil } = await supabase
    .from("perfil")
    .select("nome_completo, whatsapp, fcm_token, bloco_txt, apto_txt, notificacoes_whatsapp")
    .eq("id", resident_id)
    .single()

  if (!perfil?.whatsapp || perfil.notificacoes_whatsapp === false) {
    console.warn(
      `No whatsapp or opt-out for resident ${resident_id}, skipping WhatsApp`
    )
    return jsonResponse({
      sent_resident: false,
      sent_visitor: false,
      reason: perfil?.notificacoes_whatsapp === false ? "Resident opted out" : "Resident has no whatsapp",
    })
  }

  // ── Fetch condominium name ───────────────────────────────────────
  const { data: condo } = await supabase
    .from("condominios")
    .select("nome")
    .eq("id", condominio_id)
    .single()
  const condoNome = condo?.nome || "Condomínio"

  // ── Extract short code from qr_data ──────────────────────────────
  const shortCode = extractShortCode(qr_data)

  const visitDate = formatDateBR(validity_date)
  const residentFirstName =
    perfil.nome_completo?.split(" ")[0] || "Morador"
  const codInterno = genCodInterno()

  const hasVisitorPhone =
    visitor_phone && visitor_phone.replace(/\D/g, "").length >= 10

  // ── MSG 1 — MORADOR ──────────────────────────────────────────────

  let msg1: string
  if (hasVisitorPhone) {
    msg1 =
      `🚪\n` +
      `Autorização confirmada!\n` +
      `\n` +
      `Ei, ${residentFirstName}, avise seu/sua visitante ${guest_name || ""}\n` +
      `\n` +
      `Acabamos de enviar uma autorização de entrada para ele(a). 👋\n` +
      `\n` +
      `Ele(a) já pode entrar! 😊\n` +
      `\n` +
      `Peça para ele(a) apresentar este código na portaria:\n` +
      `\n` +
      `🔐 ${shortCode}\n` +
      `\n` +
      `Visita para a Data: ${visitDate}\n` +
      `\n` +
      `Qualquer dúvida no uso do aplicativo, estamos por aqui.\n` +
      `\n` +
      `Obrigado por usar o Condomeet 🧡\n` +
      `cód interno: ${codInterno}`
  } else {
    msg1 =
      `🚪\n` +
      `Autorização confirmada!\n` +
      `\n` +
      `Ei, ${residentFirstName}, avise seu visitante! 👋\n` +
      `\n` +
      `Ele(a) já pode entrar! 😊\n` +
      `\n` +
      `Peça para ele(a) apresentar este código na portaria:\n` +
      `\n` +
      `🔐 ${shortCode}\n` +
      `\n` +
      `Visita para a Data: ${visitDate}\n` +
      `\n` +
      `Qualquer dúvida no uso do aplicativo, estamos por aqui.\n` +
      `\n` +
      `Obrigado por usar o Condomeet 🧡\n` +
      `cód interno: ${codInterno}`
  }

  const sentResident = await sendWhatsApp(
    uazapiUrl,
    uazapiToken,
    cleanPhone(perfil.whatsapp),
    msg1
  )
  console.log(
    `Msg1 (resident ${resident_id}): ${sentResident ? "✅" : "❌"}`
  )

  // ── MSG 2 — VISITANTE (only if phone provided) ───────────────────

  let sentVisitor = false

  if (hasVisitorPhone) {
    const phone = cleanPhone(visitor_phone)
    console.log(
      `Sending visitor notification: ${phone} (${guest_name})`
    )

    // Upsert visitor contact
    const { error: upsertError } = await supabase
      .from("contatos_visitantes")
      .upsert(
        {
          user_id: resident_id,
          condominio_id,
          nome: guest_name || "Visitante",
          celular: phone,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id,celular" }
      )

    if (upsertError) {
      console.error("Upsert contatos_visitantes error:", upsertError)
    } else {
      console.log(
        `✅ Contact saved: ${guest_name} (${phone}) → agenda of ${resident_id}`
      )
    }

    const codInterno2 = genCodInterno()
    const visitorFirstName =
      (guest_name || "Visitante").split(" ")[0]

    const msg2 =
      `🚪\n` +
      `${condoNome}\n` +
      `\n` +
      `Olá, ${visitorFirstName}! 👋\n` +
      `\n` +
      `O(a) morador(a) ${perfil.nome_completo || residentFirstName} acabou de autorizar a sua entrada no condomínio.\n` +
      `\n` +
      `📅 Data da visita: ${visitDate}\n` +
      `\n` +
      `🔑 Código de autorização: ${shortCode}\n` +
      `\n` +
      `👉 Ao chegar na portaria, informe seu nome e o código acima para liberar a entrada.\n` +
      `\n` +
      `Condomeet agradece sua colaboração.\n` +
      `cód interno: ${codInterno2}`

    sentVisitor = await sendWhatsApp(
      uazapiUrl,
      uazapiToken,
      phone,
      msg2
    )
    console.log(
      `Msg2 (visitor ${guest_name}): ${sentVisitor ? "✅" : "❌"}`
    )
  }

  // ── PUSH NOTIFICATION — FCM to requesting resident ──────────────
  let pushSent = false
  const fcmToken = perfil?.fcm_token
  if (fcmToken && fcmToken.length > 10 && !fcmToken.startsWith("dummy")) {
    try {
      const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
      if (serviceAccountJson) {
        const serviceAccount = JSON.parse(serviceAccountJson)
        const fcmAccessToken = await getFcmAccessToken(serviceAccount)
        const pushResult = await sendFcmPush(
          fcmAccessToken,
          serviceAccount.project_id,
          fcmToken,
          "🚪 Autorização de visitante criada",
          `${guest_name || 'Visitante'} — Data: ${formatDateBR(validity_date)}`,
          {
            type: "convite",
            event: "created",
            convite_id: convite_id || "",
          }
        )
        pushSent = pushResult.success
        if (!pushResult.success) {
          console.warn(`Push FCM failed for resident ${resident_id}: ${pushResult.error}`)
        } else {
          console.log(`✅ Push FCM sent to resident ${resident_id}`)
        }
      } else {
        console.warn("FIREBASE_SERVICE_ACCOUNT_JSON not set, skipping push")
      }
    } catch (pushErr: unknown) {
      const msg = pushErr instanceof Error ? pushErr.message : String(pushErr)
      console.error(`Push notification error: ${msg}`)
    }
  } else {
    console.log(`No valid FCM token for resident ${resident_id}, skipping push`)
  }

  return jsonResponse({
    action: "created",
    sent_resident: sentResident,
    sent_visitor: sentVisitor,
    push_sent: pushSent,
    convite_id,
  })
}

// ══════════════════════════════════════════════════════════════════════════
//  ACTION: portaria_created (convite criado pela portaria em nome do morador)
// ══════════════════════════════════════════════════════════════════════════
async function handlePortariaCreated(
  payload: Record<string, unknown>,
  supabase: ReturnType<typeof createClient>,
  uazapiUrl: string,
  uazapiToken: string
): Promise<Response> {
  const {
    convite_id,
    resident_id,
    condominio_id,
    guest_name,
    visitor_phone,
    visitor_type,
    validity_date,
    qr_data,
    observacao,
    bloco_destino,
    apto_destino,
    morador_nome_manual,
  } = payload as Record<string, string>

  // ── Fetch condominium name ────────────────────────────────────────
  const { data: condo } = await supabase
    .from("condominios")
    .select("nome, tipo_estrutura")
    .eq("id", condominio_id)
    .single()
  const condoNome = condo?.nome || "Condomínio"
  const tipoEstrutura = condo?.tipo_estrutura || 'predio'
  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)

  const shortCode = qr_data || "---"
  const visitDate = formatDateBR(validity_date)
  const tipoVisitante = visitor_type || "Visitante"
  const obsText = observacao && observacao.trim() ? observacao.trim() : "Não preenchida"
  const codInterno = genCodInterno()

  const results: string[] = []

  // ── CASE 1: Resident identified ───────────────────────────────────
  if (resident_id && resident_id.trim() !== "") {
    const { data: perfil } = await supabase
      .from("perfil")
      .select("nome_completo, whatsapp, notificacoes_whatsapp")
      .eq("id", resident_id)
      .single()

    if (perfil?.whatsapp && perfil.notificacoes_whatsapp !== false) {
      const residentName = perfil.nome_completo?.split(" ")[0] || "Morador"

      const msg1 =
        `🗯 Autorização enviada !\n` +
        `\n` +
        `Ei, ${residentName}, registramos sua solicitação para entrada do seu visitante para a data:\n` +
        `${visitDate}\n` +
        `\n` +
        `Tipo de visitante:\n` +
        `${tipoVisitante}\n` +
        `\n` +
        `📝 Avise ele(a) para apresentar na portaria o código de autorização:\n` +
        `${shortCode}\n` +
        `\n` +
        `📒 Observação\n` +
        `${obsText}\n` +
        `\n` +
        `Condomeet agradece!\n` +
        `Cod. int: ${codInterno}`

      const sent = await sendWhatsApp(uazapiUrl, uazapiToken, cleanPhone(perfil.whatsapp), msg1)
      results.push(`Msg1 resident ${resident_id}: ${sent ? "✅" : "❌"}`)
    } else {
      results.push(`Msg1 skipped: no whatsapp for ${resident_id}`)
    }
  }
  // ── CASE 2: Resident NOT identified → notify ALL unit residents ───
  else {
    const { data: unitResidents } = await supabase
      .from("perfil")
      .select("id, nome_completo, whatsapp")
      .eq("condominio_id", condominio_id)
      .eq("bloco_txt", bloco_destino)
      .eq("apto_txt", apto_destino)
      .eq("notificacoes_whatsapp", true)
      .not("whatsapp", "is", null)

    const codInterno2 = genCodInterno()
    const msg2 =
      `🏙  ${condoNome}\n` +
      `\n` +
      `Autorização enviada sem identificação!\n` +
      `\n` +
      `Olá morador(a), parece que alguém do seu apto pediu a portaria um registro de visitante, porém, não se identificou.\n` +
      `\n` +
      `Tipo de visitante:\n` +
      `${tipoVisitante}\n` +
      `\n` +
      `🗓️ O registro foi para a data:\n` +
      `${visitDate}\n` +
      `\n` +
      `📝 Avise ele(a) para apresentar na portaria o código de autorização:\n` +
      `${shortCode}\n` +
      `\n` +
      `📒 Observação\n` +
      `${obsText}\n` +
      `\n` +
      `A pessoa que solicitou, não se identificou\n` +
      `\n` +
      `🚨Atenção, caso não tenha sido ninguém do apto, favor procurar a direção do condomínio\n` +
      `\n` +
      `Condomeet agradece!\n` +
      `Cód interno: ${codInterno2}`

    for (let i = 0; i < (unitResidents ?? []).length; i++) {
      const r = unitResidents![i]
      if (r.whatsapp) {
        // Random delay 5-15s between messages to avoid Meta anti-spam
        if (i > 0) {
          const delay = Math.floor(Math.random() * 10000) + 5000 // 5000-15000ms
          await new Promise((resolve) => setTimeout(resolve, delay))
        }
        const sent = await sendWhatsApp(uazapiUrl, uazapiToken, cleanPhone(r.whatsapp), msg2)
        results.push(`Msg2 resident ${r.id}: ${sent ? "✅" : "❌"}`)
      }
    }
    if (!unitResidents || unitResidents.length === 0) {
      results.push(`Msg2 skipped: no residents with whatsapp in ${bloco_destino}/${apto_destino}`)
    }
  }

  // ── MSG 3: Visitor (if phone provided) ─────────────────────────────
  const hasVisitorPhone = visitor_phone && visitor_phone.replace(/\D/g, "").length >= 10
  let sentVisitor = false

  if (hasVisitorPhone) {
    const phone = cleanPhone(visitor_phone)

    // Get resident name for message
    let moradorNome = morador_nome_manual || ""
    if (resident_id && resident_id.trim() !== "") {
      const { data: rp } = await supabase
        .from("perfil")
        .select("nome_completo")
        .eq("id", resident_id)
        .single()
      moradorNome = rp?.nome_completo || moradorNome
    }

    const codInterno3 = genCodInterno()
    const visitorFirstName = (guest_name || "Visitante").split(" ")[0]

    const msg3 =
      `🏢 ${condoNome}\n` +
      `\n` +
      `✔ Ei ${visitorFirstName}\n` +
      `\n` +
      `O(A) morador(a) ${moradorNome} do condomínio\n` +
      `${condoNome}\n` +
      `\n` +
      `🗓️ Acabou de autorizar a sua entrada para o dia:\n` +
      `${visitDate}\n` +
      `\n` +
      `Tipo do visitante:\n` +
      `${tipoVisitante}\n` +
      `\n` +
      `Unidade\n` +
      `${blocoLabel}: ${bloco_destino}\n` +
      `${aptoLabel}: ${apto_destino}\n` +
      `\n` +
      `📝 Diga que tem a autorização informando o Código:\n` +
      `${shortCode}\n` +
      `.\n` +
      `📒 Observação:\n` +
      `${obsText}\n` +
      `\n` +
      `Condomeet agradece!\n` +
      `Cod int ${codInterno3}`

    sentVisitor = await sendWhatsApp(uazapiUrl, uazapiToken, phone, msg3)
    results.push(`Msg3 visitor ${guest_name}: ${sentVisitor ? "✅" : "❌"}`)
  }

  console.log(`handlePortariaCreated results:`, results)

  // ── FCM Push Notification ──────────────────────────────────────────
  try {
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if (serviceAccountJson) {
      const serviceAccount = JSON.parse(serviceAccountJson)
      const fcmAccessToken = await getFcmAccessToken(serviceAccount)
      const projectId = serviceAccount.project_id

      const pushTitle = "🚪 Autorização de visitante registrada"
      const pushBody = `Tipo: ${tipoVisitante} — ${blocoLabel} ${bloco_destino} / ${aptoLabel} ${apto_destino} — Data: ${visitDate}`
      const pushData: Record<string, string> = {
        type: "convite",
        event: "portaria_created",
        convite_id: convite_id || "",
      }

      // Get FCM tokens: from specific resident or all unit residents
      let fcmTargets: { id: string; fcm_token: string }[] = []

      if (resident_id && resident_id.trim() !== "") {
        const { data: rp } = await supabase
          .from("perfil")
          .select("id, fcm_token")
          .eq("id", resident_id)
          .not("fcm_token", "is", null)
          .maybeSingle()
        if (rp?.fcm_token) fcmTargets = [rp]
      } else {
        const { data: unitResidents2 } = await supabase
          .from("perfil")
          .select("id, fcm_token")
          .eq("condominio_id", condominio_id)
          .eq("bloco_txt", bloco_destino)
          .eq("apto_txt", apto_destino)
          .not("fcm_token", "is", null)
        fcmTargets = (unitResidents2 ?? []).filter((r: any) => r.fcm_token && r.fcm_token.length > 10)
      }

      for (const target of fcmTargets) {
        const pushResult = await sendFcmPush(fcmAccessToken, projectId, target.fcm_token, pushTitle, pushBody, pushData)
        console.log(`FCM push to ${target.id}: ${pushResult.success ? "✅" : "❌"} ${pushResult.error || ""}`)
        results.push(`FCM ${target.id}: ${pushResult.success ? "✅" : "❌"}`)
      }

      if (fcmTargets.length === 0) {
        console.log("No FCM tokens found for portaria_created push")
        results.push("FCM: no tokens found")
      }
    }
  } catch (fcmErr: unknown) {
    const msg = fcmErr instanceof Error ? fcmErr.message : String(fcmErr)
    console.error("FCM push error in handlePortariaCreated:", msg)
    results.push(`FCM error: ${msg}`)
  }

  return jsonResponse({
    action: "portaria_created",
    results,
    convite_id,
  })
}

// ══════════════════════════════════════════════════════════════════════════
//  ACTION: entry_released (porteiro liberou entrada do visitante)
// ══════════════════════════════════════════════════════════════════════════
async function handleEntryReleased(
  payload: Record<string, unknown>,
  supabase: ReturnType<typeof createClient>,
  uazapiUrl: string,
  uazapiToken: string
): Promise<Response> {
  const {
    convite_id,
    resident_id,
    condominio_id,
    guest_name,
    visitor_phone,
    visitor_type,
    validity_date,
    qr_data,
    created_at,
    liberado_em,
    criado_por_portaria,
    bloco_destino,
    apto_destino,
  } = payload as Record<string, string>

  const isPortariaSemId = String(criado_por_portaria) === "true" && (!resident_id || resident_id.trim() === "")

  // ── Fetch condominium name ───────────────────────────────────────
  const { data: condo } = await supabase
    .from("condominios")
    .select("nome")
    .eq("id", condominio_id)
    .single()
  const condoNome = condo?.nome || "Condomínio"

  // ── Derived values ────────────────────────────────────────────────
  const shortCode = qr_data || "---"
  const guestDisplayName = guest_name || "Nome não preenchido"
  const visitorTypeDisplay = visitor_type || "Visitante"
  const solicitadoEm = formatDateBR(created_at)
  const dataEntrada = formatDateBR(liberado_em)
  const visitDate = formatDateBR(validity_date)
  const hasVisitorPhone = visitor_phone && visitor_phone.replace(/\D/g, "").length >= 10

  const results: string[] = []

  // ── Resolve recipients ─────────────────────────────────────────────
  let recipients: { id: string; nome_completo: string; whatsapp: string; fcm_token: string | null }[] = []

  if (isPortariaSemId) {
    // Portaria without identification → notify ALL unit residents
    const { data: unitResidents } = await supabase
      .from("perfil")
      .select("id, nome_completo, whatsapp, fcm_token")
      .eq("condominio_id", condominio_id)
      .eq("bloco_txt", bloco_destino)
      .eq("apto_txt", apto_destino)
      .eq("notificacoes_whatsapp", true)
      .not("whatsapp", "is", null)
    recipients = (unitResidents ?? []).filter((r: any) => r.whatsapp && r.whatsapp.trim() !== "")
    console.log(`entry_released (portaria sem ID): ${recipients.length} recipients in ${bloco_destino}/${apto_destino}`)
  } else {
    // Identified resident
    const { data: perfil } = await supabase
      .from("perfil")
      .select("id, nome_completo, whatsapp, fcm_token, notificacoes_whatsapp")
      .eq("id", resident_id)
      .single()

    if (!perfil?.whatsapp || perfil.notificacoes_whatsapp === false) {
      console.warn(`No whatsapp or opt-out for resident ${resident_id}`)
      return jsonResponse({ action: "entry_released", sent: 0, reason: "no whatsapp or opt-out" })
    }
    recipients = [perfil as any]
  }

  if (recipients.length === 0) {
    return jsonResponse({ action: "entry_released", sent: 0, reason: "no recipients" })
  }

  // ── Send WhatsApp to each recipient ────────────────────────────────
  for (let i = 0; i < recipients.length; i++) {
    const r = recipients[i]
    const firstName = r.nome_completo?.split(" ")[0] || "Morador"
    const codInterno = genCodInterno()

    // Delay between messages to avoid rate limiting
    if (i > 0) {
      const delay = Math.floor(Math.random() * 10000) + 5000
      await new Promise((resolve) => setTimeout(resolve, delay))
    }

    const msg =
      `🔔 ${condoNome}\n` +
      ` \n` +
      `Notificação de entrada liberada\n` +
      `\n` +
      `Olá, ${firstName}: 👋\n` +
      `\n` +
      `A portaria acabou de liberar a entrada do seu visitante.\n` +
      `\n` +
      `👤 Visitante: ${guestDisplayName}\n` +
      `\n` +
      `🚗 Tipo: ${visitorTypeDisplay}\n` +
      `\n` +
      `📅 Solicitado em: ${solicitadoEm}\n` +
      `\n` +
      `📅 Data da entrada: ${dataEntrada}\n` +
      `\n` +
      `🔑 Código da solicitação: ${shortCode}\n` +
      `\n` +
      `Tudo certo por aqui! ✅\n` +
      `\n` +
      `Condomeet agradece sua colaboração.\n` +
      `Cód interno: ${codInterno}`

    const sent = await sendWhatsApp(uazapiUrl, uazapiToken, cleanPhone(r.whatsapp), msg)
    results.push(`WhatsApp ${r.id}: ${sent ? "✅" : "❌"}`)
  }

  // ── MSG VISITANTE — só se tiver celular ───────────────────────────
  if (hasVisitorPhone) {
    const phone = cleanPhone(visitor_phone)
    const residentName = recipients[0]?.nome_completo?.split(" ")[0] || "Morador"
    const codInterno2 = genCodInterno()
    const visitorFirstName = (guest_name || "Visitante").split(" ")[0]

    const msgVisitor =
      `🚪 Ei, ${visitorFirstName}, o(a) morador(a) ${residentName} do: \n` +
      `${condoNome}\n` +
      `\n` +
      `Acabou de autorizar a sua entrada para o dia:\n` +
      ` ${visitDate}.\n` +
      `\n` +
      `Seu nome estará na portaria, diga que tem a autorização informando o Código:\n` +
      `\n` +
      `${shortCode}.\n` +
      `\n` +
      `Condomeet agradece.\n` +
      `Cód interno ${codInterno2}`

    const sentVisitor = await sendWhatsApp(uazapiUrl, uazapiToken, phone, msgVisitor)
    results.push(`WhatsApp visitor: ${sentVisitor ? "✅" : "❌"}`)
  }

  // ── PUSH NOTIFICATION — FCM to all recipients ──────────────────────
  try {
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if (serviceAccountJson) {
      const serviceAccount = JSON.parse(serviceAccountJson)
      const fcmAccessToken = await getFcmAccessToken(serviceAccount)
      const projectId = serviceAccount.project_id

      for (const r of recipients) {
        if (r.fcm_token && r.fcm_token.length > 10 && !r.fcm_token.startsWith("dummy")) {
          const pushResult = await sendFcmPush(
            fcmAccessToken,
            projectId,
            r.fcm_token,
            "🚪 Visitante chegou!",
            `${guestDisplayName} — entrada liberada pela portaria.`,
            { type: "visitor_entry", convite_id: convite_id || "", guest_name: guestDisplayName }
          )
          results.push(`FCM ${r.id}: ${pushResult.success ? "✅" : "❌"}`)
        }
      }
    }
  } catch (pushErr: unknown) {
    const msg = pushErr instanceof Error ? pushErr.message : String(pushErr)
    console.error(`Push notification error: ${msg}`)
    results.push(`FCM error: ${msg}`)
  }

  console.log(`entry_released results:`, results)

  return jsonResponse({
    action: "entry_released",
    results,
    convite_id,
  })
}

// ── Main handler ──────────────────────────────────────────────────────────

console.info("convite-whatsapp-notify server started")

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Use POST" }, 405)
  }

  try {
    // Auth — only secret keys (triggers)
    const authHeader = req.headers.get("Authorization") ?? ""
    const token = authHeader.replace(/^Bearer\s+/i, "")
    if (!token || !isSecretKey(token)) {
      return jsonResponse(
        { error: "Unauthorized — trigger-only function" },
        401
      )
    }

    const payload = await req.json()
    const { resident_id, condominio_id, action } = payload
    console.log(`[convite-notify] action=${action}, resident=${resident_id}, condo=${condominio_id}`)

    // For portaria_created and entry_released (portaria), resident_id can be empty
    if (action !== "portaria_created" && action !== "entry_released" && (!resident_id || !condominio_id)) {
      return jsonResponse(
        { error: "resident_id and condominio_id are required" },
        400
      )
    }
    if (action === "portaria_created" && !condominio_id) {
      return jsonResponse(
        { error: "condominio_id is required" },
        400
      )
    }

    const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")
    if (!UAZAPI_URL || !UAZAPI_TOKEN) {
      return jsonResponse(
        { error: "UAZAPI_URL or UAZAPI_TOKEN not configured" },
        500
      )
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // ── Route by action ────────────────────────────────────────────
    if (action === "portaria_created") {
      return await handlePortariaCreated(payload, supabase, UAZAPI_URL, UAZAPI_TOKEN)
    }

    if (action === "entry_released") {
      return await handleEntryReleased(payload, supabase, UAZAPI_URL, UAZAPI_TOKEN)
    }

    // Default: 'created' (backward compatible — no action field from old trigger)
    return await handleCreated(payload, supabase, UAZAPI_URL, UAZAPI_TOKEN)

  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error("convite-whatsapp-notify error:", message)
    return jsonResponse({ error: message }, 500)
  }
})
