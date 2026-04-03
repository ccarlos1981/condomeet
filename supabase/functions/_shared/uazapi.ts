// _shared/uazapi.ts — Shared UazAPI client utilities
// Used by: whatsapp-chatbot and future WhatsApp functions via UazAPI

export interface UazapiSendResult {
  success: boolean;
  phone: string;
  error?: string;
}

// ── Kill switch ───────────────────────────────────────────────────────────
// Set WHATSAPP_ENABLED=false in Supabase secrets to disable all WhatsApp sends
// Useful during temporary bans or maintenance
export function isWhatsAppEnabled(): boolean {
  const flag = Deno.env.get("WHATSAPP_ENABLED");
  // Enabled by default; only disabled when explicitly set to 'false' or '0'
  if (flag === "false" || flag === "0") return false;
  return true;
}

// ── Retry helper with exponential backoff ─────────────────────────────────
const MAX_RETRIES = 1; // 1 retry = 2 total attempts
const BASE_DELAY_MS = 2000; // 2 seconds

async function withRetry<T>(
  fn: () => Promise<T>,
  isRetryable: (error: unknown) => boolean,
): Promise<T> {
  let lastError: unknown;
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      if (attempt < MAX_RETRIES && isRetryable(err)) {
        const delay = BASE_DELAY_MS * Math.pow(2, attempt);
        console.warn(
          `[UazAPI] Retry ${attempt + 1}/${MAX_RETRIES} after ${delay}ms...`,
        );
        await new Promise((res) => setTimeout(res, delay));
      }
    }
  }
  throw lastError;
}

// Only retry on network/connection errors, NOT on API errors (4xx/5xx)
function isNetworkError(err: unknown): boolean {
  if (err instanceof TypeError) return true; // fetch network errors
  const msg = err instanceof Error ? err.message : String(err);
  return /timeout|network|connect|ECONNREFUSED|ENOTFOUND|socket/i.test(msg);
}

export interface IncomingMessage {
  phone: string; // sender phone number (e.g. "5531992707070")
  text: string; // message text body
  messageId: string; // unique message ID
  messageType: string; // "text", "image", "audio", etc.
  isGroup: boolean; // whether the message is from a group
  fromMe: boolean; // whether the message was sent BY our number (outgoing)
  raw: Record<string, unknown>; // raw webhook payload
}

// ── Parse incoming webhook from UazAPI ─────────────────────────────────────

export function parseWebhook(
  body: Record<string, unknown>,
): IncomingMessage | null {
  try {
    // UazAPI webhook format:
    // { BaseUrl, EventType, chat, chatSource, instanceName, message, owner, token }
    // message: { chatid, sender_pn, sender, fromMe, isGroup, messageType, content, messageid, ... }
    // chatid = "553192707070@s.whatsapp.net" (the user's phone)
    // sender_pn = "553192707070@s.whatsapp.net" (alternative phone field)
    // sender = "261653987909653@lid" (WhatsApp LID — NOT a phone number!)
    // content = "text message" or { text: "..." } for extended messages
    // fromMe = true/false

    // Handle BotConversa format directly
    if (body.subscriber && (body.message || body.last_message)) {
      const subscriber = body.subscriber as Record<string, unknown>;
      const msgData = (body.message || body.last_message) as Record<
        string,
        unknown
      >;

      const phone = String(subscriber.phone || body.phone || "").replace(
        /\D/g,
        "",
      );
      if (!phone) return null;

      let text = String(msgData.text || msgData.value || body.text || "")
        .trim();
      const messageType = String(
        msgData.type || body.type || (text ? "text" : "unknown"),
      );
      const isGroup = false;
      const fromMe = body.direction === "outbound" || !!body.fromMe;
      const messageId = String(msgData.id || body.id || Date.now());

      return {
        phone,
        text,
        messageId,
        messageType,
        isGroup,
        fromMe,
        raw: body,
      };
    }

    const eventType = body.EventType as string || body.event as string || "";

    // Only process message events
    if (
      eventType && !eventType.includes("messages") &&
      !eventType.includes("message")
    ) {
      console.log(`[UazAPI] Ignoring event: ${eventType}`);
      return null;
    }

    // UazAPI puts message data in body.message
    const msg = (body.message || body.data || body) as Record<string, unknown>;

    // Extract fromMe
    const fromMe = Boolean(msg.fromMe ?? false);

    // Extract isGroup
    const isGroup = Boolean(msg.isGroup ?? false);

    // Extract phone number — prefer chatid or sender_pn (NOT sender which is a LID)
    const chatid = String(msg.chatid || "");
    const senderPn = String(msg.sender_pn || "");

    // Extract phone from chatid or sender_pn (format: "553192707070@s.whatsapp.net")
    let phone = "";
    if (chatid.includes("@s.whatsapp.net")) {
      phone = chatid.replace("@s.whatsapp.net", "").replace(/\D/g, "");
    } else if (senderPn.includes("@s.whatsapp.net")) {
      phone = senderPn.replace("@s.whatsapp.net", "").replace(/\D/g, "");
    } else {
      // Fallback: try other fields but avoid LIDs (@lid)
      const rawPhone = String(msg.from || msg.phone || msg.remoteJid || "");
      if (!rawPhone.includes("@lid")) {
        phone = rawPhone.replace(/@.*/, "").replace(/\D/g, "");
      }
    }

    if (!phone || phone.length < 10) {
      console.log(
        `[UazAPI] No valid phone in webhook payload. chatid=${chatid}, sender_pn=${senderPn}`,
      );
      return null;
    }

    // Extract message type
    const messageType = String(msg.messageType || msg.type || "unknown");

    // Extract text content
    // UazAPI content can be a string or an object { text: "..." } or { description: "..." }
    let text = "";
    const content = msg.content;
    if (typeof content === "string") {
      text = content.trim();
    } else if (content && typeof content === "object") {
      const contentObj = content as Record<string, unknown>;
      text = String(contentObj.text || contentObj.description || "").trim();
    }
    // Fallback to msg.text or msg.body
    if (!text) {
      text = String(msg.text || msg.body || "").trim();
    }

    // Extract message ID
    const messageId = String(msg.messageid || msg.messageId || msg.id || "");

    return {
      phone,
      text,
      messageId,
      messageType,
      isGroup,
      fromMe,
      raw: body,
    };
  } catch (err) {
    console.error("[UazAPI] Error parsing webhook:", err);
    return null;
  }
}

// ── Send text message via UazAPI (AGORA BOTCONVERSA) ───────────────────────

export async function sendTextMessage(
  baseUrl: string, // Ignorado na nova versão
  token: string, // Ignorado na nova versão
  phone: string,
  message: string,
): Promise<UazapiSendResult> {
  if (!isWhatsAppEnabled()) {
    console.log(`[BotConversa] WhatsApp DISABLED — skipping text to ${phone}`);
    return { success: false, phone, error: "WhatsApp disabled" };
  }

  try {
    return await withRetry(async () => {
      const BOT_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY");
      if (!BOT_API_KEY) throw new Error("BOTCONVERSA_API_KEY missing");

      // 1. Resolver o ID interno do BotConversa (Subscriber) pelo telefone
      const subRes = await fetch(
        "https://backend.botconversa.com.br/api/v1/webhook/subscriber/",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "API-KEY": BOT_API_KEY,
          },
          body: JSON.stringify({
            phone,
            first_name: "Morador",
            last_name: ".",
          }),
        },
      );
      if (!subRes.ok) {
        throw new Error(`Subscriber failed: ${await subRes.text()}`);
      }

      const subData = await subRes.json();
      const subscriberId = subData.id || subData.subscriber_id;
      if (!subscriberId) throw new Error("Could not extract subscriberId");

      // 2. Enviar a mensagem para o ID resolvido
      const sendRes = await fetch(
        `https://backend.botconversa.com.br/api/v1/webhook/subscriber/${subscriberId}/send_message/`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "API-KEY": BOT_API_KEY,
          },
          body: JSON.stringify({ type: "text", value: message }),
        },
      );

      if (!sendRes.ok) {
        const resultText = await sendRes.text();
        console.error(
          `[BotConversa] Send error (${phone}): ${sendRes.status} ${resultText}`,
        );
        return {
          success: false,
          phone,
          error: `${sendRes.status}: ${resultText}`,
        };
      }

      console.log(
        `[BotConversa] Message sent to ${phone} (Sub: ${subscriberId})`,
      );
      return { success: true, phone };
    }, isNetworkError);
  } catch (err: unknown) {
    const message_ = err instanceof Error ? err.message : String(err);
    console.error(`[BotConversa] Fetch error (${phone}):`, message_);
    return { success: false, phone, error: message_ };
  }
}

// ── Phone number normalization ────────────────────────────────────────────
export function normalizePhone(raw: string): string {
  let phone = raw.replace(/\D/g, "");
  if (!phone.startsWith("55")) phone = "55" + phone;
  return phone;
}

// ── Send image message via UazAPI (AGORA BOTCONVERSA) ─────────────────────

export async function sendImageMessage(
  baseUrl: string, // Ignorado
  token: string, // Ignorado
  phone: string,
  imageUrl: string,
  caption?: string,
): Promise<UazapiSendResult> {
  if (!isWhatsAppEnabled()) {
    console.log(`[BotConversa] WhatsApp DISABLED — skipping image to ${phone}`);
    return { success: false, phone, error: "WhatsApp disabled" };
  }

  // Corrigir formato PNG para BotConversa (bug interno da plataforma)
  let finalImageUrl = imageUrl;
  if (finalImageUrl.toLowerCase().endsWith(".png")) {
    finalImageUrl = finalImageUrl.replace(/\.png$/i, ".jpeg");
  }

  try {
    return await withRetry(async () => {
      const BOT_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY");
      if (!BOT_API_KEY) throw new Error("BOTCONVERSA_API_KEY missing");

      // 1. Resolver o ID interno do BotConversa (Subscriber) pelo telefone
      const subRes = await fetch(
        "https://backend.botconversa.com.br/api/v1/webhook/subscriber/",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "API-KEY": BOT_API_KEY,
          },
          body: JSON.stringify({
            phone,
            first_name: "Morador",
            last_name: ".",
          }),
        },
      );
      if (!subRes.ok) {
        throw new Error(`Subscriber failed: ${await subRes.text()}`);
      }

      const subData = await subRes.json();
      const subscriberId = subData.id || subData.subscriber_id;
      if (!subscriberId) throw new Error("Could not extract subscriberId");

      // 2. Enviar a imagem (file)
      const sendRes = await fetch(
        `https://backend.botconversa.com.br/api/v1/webhook/subscriber/${subscriberId}/send_message/`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "API-KEY": BOT_API_KEY,
          },
          body: JSON.stringify({ type: "file", value: finalImageUrl }),
        },
      );

      if (!sendRes.ok) {
        const resultText = await sendRes.text();
        console.error(
          `[BotConversa] Send image error (${phone}): ${sendRes.status} ${resultText}`,
        );
        return {
          success: false,
          phone,
          error: `${sendRes.status}: ${resultText}`,
        };
      }

      // Se houver caption, manda um text logo em seguida (já que BC não aceita legenda direto na API de file)
      if (caption) {
        await new Promise((r) => setTimeout(r, 1000));
        await fetch(
          `https://backend.botconversa.com.br/api/v1/webhook/subscriber/${subscriberId}/send_message/`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "API-KEY": BOT_API_KEY,
            },
            body: JSON.stringify({ type: "text", value: caption }),
          },
        );
      }

      console.log(
        `[BotConversa] Image sent to ${phone} (Sub: ${subscriberId})`,
      );
      return { success: true, phone };
    }, isNetworkError);
  } catch (err: unknown) {
    const message_ = err instanceof Error ? err.message : String(err);
    console.error(`[BotConversa] Image fetch error (${phone}):`, message_);
    return { success: false, phone, error: message_ };
  }
}
