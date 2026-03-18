// convite-whatsapp-notify — Supabase Edge Function
// Called by DB triggers when:
//   1. A convite (visitor invitation) is created  (action: 'created' / default)
//   2. Porteiro releases visitor entry             (action: 'entry_released')
// Sends WhatsApp notification to resident + visitor (if phone provided).
// Also upserts visitor contact to contatos_visitantes (agenda).

import { createClient } from "npm:@supabase/supabase-js@2"

const BOTCONVERSA_BASE_URL =
  "https://backend.botconversa.com.br/api/v1/webhook"

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
  return Math.random().toString(36).substring(2, 7).toUpperCase()
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

// ── BotConversa: create/get subscriber ────────────────────────────────────
async function resolveSubscriber(
  apiKey: string,
  phone: string,
  fullName: string
): Promise<string | null> {
  try {
    const nameParts = (fullName || "Visitante").split(" ")
    const firstName = nameParts[0] || "Visitante"
    const lastName = nameParts.length > 1 ? nameParts.slice(1).join(" ") : "."

    const res = await fetch(`${BOTCONVERSA_BASE_URL}/subscriber/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "API-KEY": apiKey,
      },
      body: JSON.stringify({ phone, first_name: firstName, last_name: lastName }),
    })

    const text = await res.text()
    console.log(
      `BotConversa resolve subscriber (${phone}): ${res.status} ${text}`
    )

    if (!res.ok) return null

    const data = JSON.parse(text)
    return String(data.id || data.subscriber_id || "")
  } catch (err) {
    console.error("resolveSubscriber error:", err)
    return null
  }
}

// ── BotConversa: send message ─────────────────────────────────────────────
async function sendMessage(
  apiKey: string,
  subscriberId: string,
  message: string
): Promise<boolean> {
  try {
    const res = await fetch(
      `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_message/`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "API-KEY": apiKey,
        },
        body: JSON.stringify({ type: "text", value: message }),
      }
    )

    if (!res.ok) {
      const errText = await res.text()
      console.error(
        `BotConversa send error (${subscriberId}): ${res.status} ${errText}`
      )
      return false
    }
    return true
  } catch (err) {
    console.error(`BotConversa send error (${subscriberId}):`, err)
    return false
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  ACTION: created (convite criado pelo morador)
// ══════════════════════════════════════════════════════════════════════════
async function handleCreated(
  payload: Record<string, unknown>,
  supabase: ReturnType<typeof createClient>,
  apiKey: string
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
    .select("nome_completo, botconversa_id, bloco_txt, apto_txt")
    .eq("id", resident_id)
    .single()

  if (!perfil?.botconversa_id) {
    console.warn(
      `No botconversa_id for resident ${resident_id}, skipping WhatsApp`
    )
    return jsonResponse({
      sent_resident: false,
      sent_visitor: false,
      reason: "Resident has no botconversa_id",
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
  const shortCode = qr_data
    ? qr_data.split("_").pop() || "---"
    : "---"

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

  const sentResident = await sendMessage(
    apiKey,
    perfil.botconversa_id,
    msg1
  )
  console.log(
    `Msg1 (resident ${resident_id}): ${sentResident ? "✅" : "❌"}`
  )

  // ── MSG 2 — VISITANTE (only if phone provided) ───────────────────

  let sentVisitor = false
  let visitorBotconversaId: string | null = null

  if (hasVisitorPhone) {
    const phone = cleanPhone(visitor_phone)
    console.log(
      `Resolving visitor subscriber: ${phone} (${guest_name})`
    )

    visitorBotconversaId = await resolveSubscriber(
      apiKey,
      phone,
      guest_name || "Visitante"
    )

    if (visitorBotconversaId) {
      const { error: upsertError } = await supabase
        .from("contatos_visitantes")
        .upsert(
          {
            user_id: resident_id,
            condominio_id,
            nome: guest_name || "Visitante",
            celular: phone,
            botconversa_id: visitorBotconversaId,
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

      await new Promise((resolve) => setTimeout(resolve, 10_000))

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

      sentVisitor = await sendMessage(
        apiKey,
        visitorBotconversaId,
        msg2
      )
      console.log(
        `Msg2 (visitor ${guest_name}): ${sentVisitor ? "✅" : "❌"}`
      )
    } else {
      console.warn(
        `Could not resolve subscriber for phone ${phone}`
      )
    }
  }

  return jsonResponse({
    action: "created",
    sent_resident: sentResident,
    sent_visitor: sentVisitor,
    visitor_botconversa_id: visitorBotconversaId,
    convite_id,
  })
}

// ══════════════════════════════════════════════════════════════════════════
//  ACTION: entry_released (porteiro liberou entrada do visitante)
// ══════════════════════════════════════════════════════════════════════════
async function handleEntryReleased(
  payload: Record<string, unknown>,
  supabase: ReturnType<typeof createClient>,
  apiKey: string
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
  } = payload as Record<string, string>

  // ── Fetch resident data ──────────────────────────────────────────
  const { data: perfil } = await supabase
    .from("perfil")
    .select("nome_completo, botconversa_id")
    .eq("id", resident_id)
    .single()

  if (!perfil?.botconversa_id) {
    console.warn(
      `No botconversa_id for resident ${resident_id}, skipping entry_released WhatsApp`
    )
    return jsonResponse({
      action: "entry_released",
      sent_resident: false,
      sent_visitor: false,
      reason: "Resident has no botconversa_id",
    })
  }

  // ── Fetch condominium name ───────────────────────────────────────
  const { data: condo } = await supabase
    .from("condominios")
    .select("nome")
    .eq("id", condominio_id)
    .single()
  const condoNome = condo?.nome || "Condomínio"

  // ── Derived values ────────────────────────────────────────────────
  const shortCode = qr_data
    ? qr_data.split("_").pop() || "---"
    : "---"

  const residentFirstName =
    perfil.nome_completo?.split(" ")[0] || "Morador"
  const guestDisplayName = guest_name || "Nome não preenchido"
  const visitorTypeDisplay = visitor_type || "Visitante"
  const solicitadoEm = formatDateBR(created_at)
  const dataEntrada = formatDateBR(liberado_em)
  const visitDate = formatDateBR(validity_date)

  const hasVisitorPhone =
    visitor_phone && visitor_phone.replace(/\D/g, "").length >= 10

  // ── MSG MORADOR — Notificação de entrada liberada ─────────────────
  const codInterno1 = genCodInterno()
  const msgResident =
    `🔔 ${condoNome}\n` +
    ` \n` +
    `Notificação de entrada liberada\n` +
    `\n` +
    `Olá, ${residentFirstName}: 👋\n` +
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
    `Cód interno: ${codInterno1}`

  const sentResident = await sendMessage(
    apiKey,
    perfil.botconversa_id,
    msgResident
  )
  console.log(
    `entry_released Msg (resident ${resident_id}): ${sentResident ? "✅" : "❌"}`
  )

  // ── MSG VISITANTE — só se tiver celular ───────────────────────────
  let sentVisitor = false
  let visitorBotconversaId: string | null = null

  if (hasVisitorPhone) {
    const phone = cleanPhone(visitor_phone)
    console.log(
      `entry_released: Resolving visitor subscriber: ${phone} (${guest_name})`
    )

    // Try to find existing botconversa_id in contatos_visitantes first
    const { data: existingContact } = await supabase
      .from("contatos_visitantes")
      .select("botconversa_id")
      .eq("celular", phone)
      .not("botconversa_id", "is", null)
      .limit(1)
      .maybeSingle()

    visitorBotconversaId = existingContact?.botconversa_id || null

    // If not found, resolve via BotConversa API
    if (!visitorBotconversaId) {
      visitorBotconversaId = await resolveSubscriber(
        apiKey,
        phone,
        guest_name || "Visitante"
      )
    }

    if (visitorBotconversaId) {
      // Wait 10s before sending visitor message (anti-ban)
      await new Promise((resolve) => setTimeout(resolve, 10_000))

      const codInterno2 = genCodInterno()
      const visitorFirstName =
        (guest_name || "Visitante").split(" ")[0]

      const msgVisitor =
        `🚪 Ei, ${visitorFirstName}, o(a) morador(a) ${residentFirstName} do: \n` +
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

      sentVisitor = await sendMessage(
        apiKey,
        visitorBotconversaId,
        msgVisitor
      )
      console.log(
        `entry_released Msg (visitor ${guest_name}): ${sentVisitor ? "✅" : "❌"}`
      )
    } else {
      console.warn(
        `entry_released: Could not resolve subscriber for phone ${phone}`
      )
    }
  }

  return jsonResponse({
    action: "entry_released",
    sent_resident: sentResident,
    sent_visitor: sentVisitor,
    visitor_botconversa_id: visitorBotconversaId,
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

    if (!resident_id || !condominio_id) {
      return jsonResponse(
        { error: "resident_id and condominio_id are required" },
        400
      )
    }

    const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY")
    if (!BOTCONVERSA_API_KEY) {
      return jsonResponse(
        { error: "BOTCONVERSA_API_KEY not configured" },
        500
      )
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // ── Route by action ────────────────────────────────────────────
    if (action === "entry_released") {
      return await handleEntryReleased(payload, supabase, BOTCONVERSA_API_KEY)
    }

    // Default: 'created' (backward compatible — no action field from old trigger)
    return await handleCreated(payload, supabase, BOTCONVERSA_API_KEY)

  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error("convite-whatsapp-notify error:", message)
    return jsonResponse({ error: message }, 500)
  }
})
