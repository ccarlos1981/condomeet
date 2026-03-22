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
