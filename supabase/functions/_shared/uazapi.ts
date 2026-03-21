// _shared/uazapi.ts — Shared UazAPI client utilities
// Used by: whatsapp-chatbot and future WhatsApp functions via UazAPI

export interface UazapiSendResult {
  success: boolean
  phone: string
  error?: string
}

export interface IncomingMessage {
  phone: string       // sender phone number (e.g. "5531992707070")
  text: string        // message text body
  messageId: string   // unique message ID
  messageType: string // "text", "image", "audio", etc.
  isGroup: boolean    // whether the message is from a group
  raw: Record<string, unknown> // raw webhook payload
}

// ── Parse incoming webhook from UazAPI ─────────────────────────────────────

export function parseWebhook(body: Record<string, unknown>): IncomingMessage | null {
  try {
    // UazAPI webhook format: the message can come in various structures
    // Most common: { event: "messages.upsert", data: { ... } }
    // or direct message object

    const event = body.event as string || ""
    const data = (body.data || body.message || body) as Record<string, unknown>

    // Only process incoming messages
    if (event && !event.includes("messages") && !event.includes("message")) {
      console.log(`[UazAPI] Ignoring event: ${event}`)
      return null
    }

    // Extract phone number - try multiple possible field names
    const phone = String(
      data.from ||
      data.sender ||
      data.phone ||
      data.remoteJid ||
      (data.key as any)?.remoteJid ||
      ""
    ).replace(/[@s.whatsapp.net]/g, "").replace(/\D/g, "")

    if (!phone || phone.length < 10) {
      console.log("[UazAPI] No valid phone in webhook payload")
      return null
    }

    // Check if group message
    const remoteJid = String(
      data.remoteJid ||
      (data.key as any)?.remoteJid ||
      data.from ||
      ""
    )
    const isGroup = remoteJid.includes("@g.us")

    // Extract message type
    const messageType = String(
      data.messageType ||
      data.type ||
      (data.message as any)?.conversation !== undefined ? "text" :
      (data.message as any)?.imageMessage !== undefined ? "image" :
      (data.message as any)?.audioMessage !== undefined ? "audio" :
      "unknown"
    )

    // Extract text content - try multiple paths
    const text = String(
      data.body ||
      data.text ||
      (data.message as any)?.conversation ||
      (data.message as any)?.extendedTextMessage?.text ||
      ""
    ).trim()

    // Extract message ID
    const messageId = String(
      data.messageId ||
      data.id ||
      (data.key as any)?.id ||
      ""
    )

    return {
      phone,
      text,
      messageId,
      messageType,
      isGroup,
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
  try {
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
  } catch (err: unknown) {
    const message_ = err instanceof Error ? err.message : String(err)
    console.error(`[UazAPI] Fetch error (${phone}):`, message_)
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
