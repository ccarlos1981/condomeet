// _shared/uazapi.ts — Shared UazAPI client utilities
// Used by: whatsapp-chatbot and future WhatsApp functions via UazAPI

export interface UazapiSendResult {
  success: boolean
  phone: string
  error?: string
}

// ── Kill switch ───────────────────────────────────────────────────────────
// Set WHATSAPP_ENABLED=false in Supabase secrets to disable all WhatsApp sends
// Useful during temporary bans or maintenance
export function isWhatsAppEnabled(): boolean {
  const flag = Deno.env.get('WHATSAPP_ENABLED')
  // Enabled by default; only disabled when explicitly set to 'false' or '0'
  if (flag === 'false' || flag === '0') return false
  return true
}

// ── Retry helper with exponential backoff ─────────────────────────────────
const MAX_RETRIES = 1       // 1 retry = 2 total attempts
const BASE_DELAY_MS = 2000  // 2 seconds

async function withRetry<T>(
  fn: () => Promise<T>,
  isRetryable: (error: unknown) => boolean
): Promise<T> {
  let lastError: unknown
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      return await fn()
    } catch (err) {
      lastError = err
      if (attempt < MAX_RETRIES && isRetryable(err)) {
        const delay = BASE_DELAY_MS * Math.pow(2, attempt)
        console.warn(`[UazAPI] Retry ${attempt + 1}/${MAX_RETRIES} after ${delay}ms...`)
        await new Promise(res => setTimeout(res, delay))
      }
    }
  }
  throw lastError
}

// Only retry on network/connection errors, NOT on API errors (4xx/5xx)
function isNetworkError(err: unknown): boolean {
  if (err instanceof TypeError) return true // fetch network errors
  const msg = err instanceof Error ? err.message : String(err)
  return /timeout|network|connect|ECONNREFUSED|ENOTFOUND|socket/i.test(msg)
}

export interface IncomingMessage {
  phone: string       // sender phone number (e.g. "5531992707070")
  text: string        // message text body
  messageId: string   // unique message ID
  messageType: string // "text", "image", "audio", etc.
  isGroup: boolean    // whether the message is from a group
  fromMe: boolean     // whether the message was sent BY our number (outgoing)
  raw: Record<string, unknown> // raw webhook payload
}

// ── Parse incoming webhook from UazAPI ─────────────────────────────────────

export function parseWebhook(body: Record<string, unknown>): IncomingMessage | null {
  try {
    // UazAPI webhook format:
    // { BaseUrl, EventType, chat, chatSource, instanceName, message, owner, token }
    // message: { chatid, sender_pn, sender, fromMe, isGroup, messageType, content, messageid, ... }
    // chatid = "553192707070@s.whatsapp.net" (the user's phone)
    // sender_pn = "553192707070@s.whatsapp.net" (alternative phone field)
    // sender = "261653987909653@lid" (WhatsApp LID — NOT a phone number!)
    // content = "text message" or { text: "..." } for extended messages
    // fromMe = true/false

    const eventType = body.EventType as string || body.event as string || ""

    // Only process message events
    if (eventType && !eventType.includes("messages") && !eventType.includes("message")) {
      console.log(`[UazAPI] Ignoring event: ${eventType}`)
      return null
    }

    // UazAPI puts message data in body.message
    const msg = (body.message || body.data || body) as Record<string, unknown>

    // Extract fromMe
    const fromMe = Boolean(msg.fromMe ?? false)

    // Extract isGroup
    const isGroup = Boolean(msg.isGroup ?? false)

    // Extract phone number — prefer chatid or sender_pn (NOT sender which is a LID)
    const chatid = String(msg.chatid || "")
    const senderPn = String(msg.sender_pn || "")
    
    // Extract phone from chatid or sender_pn (format: "553192707070@s.whatsapp.net")
    let phone = ""
    if (chatid.includes("@s.whatsapp.net")) {
      phone = chatid.replace("@s.whatsapp.net", "").replace(/\D/g, "")
    } else if (senderPn.includes("@s.whatsapp.net")) {
      phone = senderPn.replace("@s.whatsapp.net", "").replace(/\D/g, "")
    } else {
      // Fallback: try other fields but avoid LIDs (@lid)
      const rawPhone = String(msg.from || msg.phone || msg.remoteJid || "")
      if (!rawPhone.includes("@lid")) {
        phone = rawPhone.replace(/@.*/, "").replace(/\D/g, "")
      }
    }

    if (!phone || phone.length < 10) {
      console.log(`[UazAPI] No valid phone in webhook payload. chatid=${chatid}, sender_pn=${senderPn}`)
      return null
    }

    // Extract message type
    const messageType = String(msg.messageType || msg.type || "unknown")

    // Extract text content
    // UazAPI content can be a string or an object { text: "..." } or { description: "..." }
    let text = ""
    const content = msg.content
    if (typeof content === "string") {
      text = content.trim()
    } else if (content && typeof content === "object") {
      const contentObj = content as Record<string, unknown>
      text = String(contentObj.text || contentObj.description || "").trim()
    }
    // Fallback to msg.text or msg.body
    if (!text) {
      text = String(msg.text || msg.body || "").trim()
    }

    // Extract message ID
    const messageId = String(msg.messageid || msg.messageId || msg.id || "")

    return {
      phone,
      text,
      messageId,
      messageType,
      isGroup,
      fromMe,
      raw: body,
    }
  } catch (err) {
    console.error("[UazAPI] Error parsing webhook:", err)
    return null
  }
}

// ── Send text message via UazAPI ──────────────────────────────────────────

export async function sendTextMessage(
  baseUrl: string,
  token: string,
  phone: string,
  message: string
): Promise<UazapiSendResult> {
  // Kill switch check
  if (!isWhatsAppEnabled()) {
    console.log(`[UazAPI] WhatsApp DISABLED — skipping text to ${phone}`)
    return { success: false, phone, error: 'WhatsApp disabled (maintenance mode)' }
  }

  try {
    return await withRetry(async () => {
      const url = `${baseUrl}/send/text`

      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "token": token,
        },
        body: JSON.stringify({
          number: phone,
          text: message,
        }),
      })

      const resultText = await res.text()

      if (!res.ok) {
        console.error(`[UazAPI] Send error (${phone}): ${res.status} ${resultText}`)
        return { success: false, phone, error: `${res.status}: ${resultText}` }
      }

      console.log(`[UazAPI] Message sent to ${phone}: ${res.status}`)
      return { success: true, phone }
    }, isNetworkError)
  } catch (err: unknown) {
    const message_ = err instanceof Error ? err.message : String(err)
    console.error(`[UazAPI] Fetch error (${phone}) after retries:`, message_)
    return { success: false, phone, error: message_ }
  }
}

// ── Phone number normalization ────────────────────────────────────────────
// Ensures format: 55 + DDD(2) + number = 12-13 digits

export function normalizePhone(raw: string): string {
  let phone = raw.replace(/\D/g, "")

  // Add country code if missing
  if (!phone.startsWith("55")) {
    phone = "55" + phone
  }

  return phone
}

// ── Send image message via UazAPI ─────────────────────────────────────────

export async function sendImageMessage(
  baseUrl: string,
  token: string,
  phone: string,
  imageUrl: string,
  caption?: string
): Promise<UazapiSendResult> {
  // Kill switch check
  if (!isWhatsAppEnabled()) {
    console.log(`[UazAPI] WhatsApp DISABLED — skipping image to ${phone}`)
    return { success: false, phone, error: 'WhatsApp disabled (maintenance mode)' }
  }

  try {
    return await withRetry(async () => {
      // UazAPI uses /send/media for media messages
      const url = `${baseUrl}/send/media`

      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "token": token,
        },
        body: JSON.stringify({
          number: phone,
          type: "image",
          file: imageUrl,
          text: caption || "",
        }),
      })

      const resultText = await res.text()

      if (!res.ok) {
        console.error(`[UazAPI] Send image error (${phone}): ${res.status} ${resultText}`)
        return { success: false, phone, error: `${res.status}: ${resultText}` }
      }

      console.log(`[UazAPI] Image sent to ${phone}: ${res.status}`)
      return { success: true, phone }
    }, isNetworkError)
  } catch (err: unknown) {
    const message_ = err instanceof Error ? err.message : String(err)
    console.error(`[UazAPI] Image fetch error (${phone}) after retries:`, message_)
    return { success: false, phone, error: message_ }
  }
}
