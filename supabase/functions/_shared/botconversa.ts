// _shared/botconversa.ts — Shared BotConversa API utilities
// Used by: botconversa-send, whatsapp-parcel-notify, and future functions

export const BOTCONVERSA_BASE_URL =
  "https://backend.botconversa.com.br/api/v1/webhook"
export const DELAY_TEXT_MS = 1_000
export const DELAY_FILE_MS = 2_000

export interface BotConversaSendResult {
  success: boolean
  subscriberId: string
  error?: string
}

// ── PNG → JPEG URL rewrite ────────────────────────────────────────────────
// BotConversa/WhatsApp has issues rendering PNGs.

export function ensureJpegUrl(url: string): string {
  if (!url.toLowerCase().endsWith(".png")) return url
  console.log(`[PNG→JPEG] URL rewrite: ${url}`)
  return url.replace(/\.png$/i, ".jpeg")
}

// ── Send text or file message ─────────────────────────────────────────────

export async function sendMessage(
  apiKey: string,
  subscriberId: string,
  tipo: "text" | "file",
  value: string
): Promise<BotConversaSendResult> {
  try {
    const finalValue = tipo === "file" ? ensureJpegUrl(value) : value

    const res = await fetch(
      `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_message/`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "API-KEY": apiKey,
        },
        body: JSON.stringify({ type: tipo, value: finalValue }),
      }
    )

    const resultText = await res.text()
    if (!res.ok) {
      console.error(
        `BotConversa error (${subscriberId}): ${res.status} ${resultText}`
      )
      return { success: false, subscriberId, error: `${res.status}: ${resultText}` }
    }
    return { success: true, subscriberId }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error(`BotConversa fetch error (${subscriberId}):`, message)
    return { success: false, subscriberId, error: message }
  }
}

// ── Send interactive button message ───────────────────────────────────────
// WhatsApp interactive buttons (max 3 buttons)

export interface InteractiveButton {
  id: string
  title: string // max 20 chars
}

export async function sendInteractiveButtons(
  apiKey: string,
  subscriberId: string,
  bodyText: string,
  buttons: InteractiveButton[],
  headerText?: string,
  footerText?: string
): Promise<BotConversaSendResult> {
  try {
    const interactive: Record<string, unknown> = {
      type: "button",
      body: { text: bodyText },
      action: {
        buttons: buttons.map((btn) => ({
          type: "reply",
          reply: { id: btn.id, title: btn.title },
        })),
      },
    }
    if (headerText) interactive.header = { type: "text", text: headerText }
    if (footerText) interactive.footer = { text: footerText }

    const res = await fetch(
      `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_message/`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "API-KEY": apiKey,
        },
        body: JSON.stringify({ type: "interactive", value: interactive }),
      }
    )

    const resultText = await res.text()
    if (!res.ok) {
      console.error(
        `BotConversa interactive error (${subscriberId}): ${res.status} ${resultText}`
      )
      return { success: false, subscriberId, error: `${res.status}: ${resultText}` }
    }
    return { success: true, subscriberId }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error(`BotConversa interactive error (${subscriberId}):`, message)
    return { success: false, subscriberId, error: message }
  }
}

// ── Send flow ─────────────────────────────────────────────────────────────

export async function sendFlow(
  apiKey: string,
  subscriberId: string,
  flowId: number
): Promise<BotConversaSendResult> {
  try {
    const res = await fetch(
      `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_flow/`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "API-KEY": apiKey,
        },
        body: JSON.stringify({ flow: flowId }),
      }
    )

    const resultText = await res.text()
    if (!res.ok) {
      console.error(
        `BotConversa flow error (${subscriberId}): ${res.status} ${resultText}`
      )
      return { success: false, subscriberId, error: `${res.status}: ${resultText}` }
    }
    return { success: true, subscriberId }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error(`BotConversa flow error (${subscriberId}):`, message)
    return { success: false, subscriberId, error: message }
  }
}

// ── Send to multiple recipients sequentially ──────────────────────────────

export async function sendToRecipients(
  apiKey: string,
  recipients: Array<{ botconversa_id: string; nome_completo: string }>,
  msg: string,
  tipo: "text" | "file",
  options?: { flowId?: number; personalizeMsg?: boolean }
): Promise<BotConversaSendResult[]> {
  const delayMs = tipo === "file" ? DELAY_FILE_MS : DELAY_TEXT_MS
  const results: BotConversaSendResult[] = []

  for (let i = 0; i < recipients.length; i++) {
    const recipient = recipients[i]
    let result: BotConversaSendResult

    if (options?.flowId) {
      result = await sendFlow(apiKey, recipient.botconversa_id, options.flowId)
    } else {
      const finalMsg =
        options?.personalizeMsg !== false
          ? msg.replace(
              /\|nome\|/g,
              recipient.nome_completo?.split(" ")[0] || "Morador"
            )
          : msg
      result = await sendMessage(apiKey, recipient.botconversa_id, tipo, finalMsg)
    }

    results.push(result)

    // Rate limit between sends (skip after last)
    if (i < recipients.length - 1) {
      await new Promise((resolve) => setTimeout(resolve, delayMs))
    }
  }

  return results
}

// ── Phone normalization ───────────────────────────────────────────────────

export function normalizePhone(raw: string): string {
  let phone = raw.replace(/\D/g, "")
  if (phone.length > 0 && !phone.startsWith("55")) phone = "55" + phone
  return phone
}

// ── Send by phone (fallback when botconversa_id is not available) ─────────

export async function sendByPhone(
  apiKey: string,
  phone: string,
  tipo: "text" | "file",
  value: string,
  firstName?: string
): Promise<BotConversaSendResult> {
  const cleanPhone = normalizePhone(phone)
  if (cleanPhone.length < 12) {
    return { success: false, subscriberId: "", error: "Phone too short" }
  }

  try {
    // 1. Resolve subscriber ID from phone
    const subRes = await fetch(`${BOTCONVERSA_BASE_URL}/subscriber/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "API-KEY": apiKey,
      },
      body: JSON.stringify({
        phone: cleanPhone,
        first_name: firstName || "Morador",
        last_name: ".",
      }),
    })

    if (!subRes.ok) {
      const errText = await subRes.text()
      console.error(`[BotConversa] Subscriber resolve failed for ${cleanPhone}: ${subRes.status} ${errText}`)
      return { success: false, subscriberId: "", error: `Subscriber: ${subRes.status}` }
    }

    const subData = await subRes.json()
    const subscriberId = String(subData.id || subData.subscriber_id || "")
    if (!subscriberId) {
      return { success: false, subscriberId: "", error: "No subscriber ID returned" }
    }

    // 2. Send using resolved subscriber ID
    return await sendMessage(apiKey, subscriberId, tipo, value)
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error(`[BotConversa] sendByPhone error (${cleanPhone}):`, message)
    return { success: false, subscriberId: "", error: message }
  }
}

// ── Smart send: prefer botconversa_id, fallback to phone ──────────────────

export async function smartSend(
  apiKey: string,
  botconversaId: string | null | undefined,
  phone: string | null | undefined,
  tipo: "text" | "file",
  value: string,
  firstName?: string
): Promise<BotConversaSendResult> {
  if (botconversaId && botconversaId.length > 0) {
    return await sendMessage(apiKey, botconversaId, tipo, value)
  }
  if (phone && phone.trim().length > 0) {
    return await sendByPhone(apiKey, phone, tipo, value, firstName)
  }
  return { success: false, subscriberId: "", error: "No botconversa_id or phone" }
}

// ── Webhook parsing (BotConversa format) ─────────────────────────

export interface IncomingMessage {
  phone: string
  text: string
  messageType: string
  isGroup: boolean
  fromMe: boolean
  messageId: string
  botconversa_id?: string
}

export function parseWebhook(body: any): IncomingMessage | null {
  // Try Botconversa format
  try {
    const subscriber = body.subscriber || {};
    const message = body.message || body.last_message || {};
    
    // Fallback parsing to handle different possible shapes of BotConversa webhook
    const phone = subscriber.phone || body.phone;
    const text = message.text || message.value || body.text || "";
    const messageType = message.type || body.type || (text ? "text" : "unknown");
    const isGroup = false; // Botconversa handles 1-1
    const fromMe = body.direction === "outbound" || !!body.fromMe;
    const messageId = message.id || body.id || String(Date.now());

    if (!phone) return null;

    return {
      phone: String(phone).replace(/\D/g, ""), // clean phone
      text: String(text),
      messageType: String(messageType),
      isGroup,
      fromMe,
      messageId: String(messageId),
      botconversa_id: subscriber.id ? String(subscriber.id) : undefined
    };
  } catch (err) {
    console.error("Failed to parse BotConversa webhook:", err);
    return null;
  }
}
