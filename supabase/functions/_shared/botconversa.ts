// _shared/botconversa.ts — Shared BotConversa API utilities
// Used by: botconversa-send, whatsapp-parcel-notify, and other notification functions

export const BOTCONVERSA_BASE_URL =
  "https://backend.botconversa.com.br/api/v1/webhook"
export const DELAY_TEXT_MS = 1_000
export const DELAY_FILE_MS = 2_000

export interface BotConversaSendResult {
  success: boolean
  skipped: boolean
  resolvedNow: boolean
  subscriberId: string
  phoneNormalized: string
  httpStatus?: number
  reason?: string
  error?: string
  deliveryStatus?: string
}

// ── In-Memory Deduplication and Cooldown Cache ──────────────────────────────
// NOTE: These Maps are valid ONLY within the scope of the running Deno instance
// container. They act as local optimizations to handle concurrent burst requests
// and api downtime, and do not assume synchronization across multiple cold/warm instances.
const pendingResolutions = new Map<string, Promise<BotConversaSendResult>>()
const failedResolutionsCooldown = new Map<string, number>()
const COOLDOWN_MS = 60_000 // 1 minute cooldown

// Rate Limit Caches
const recipientLastSendTime = new Map<string, number>()
const sentMessagesTimestamps: number[] = []
const MAX_MESSAGES_PER_MINUTE = 20

function checkGlobalRateLimit(): boolean {
  const now = Date.now()
  while (sentMessagesTimestamps.length > 0 && now - sentMessagesTimestamps[0] > 60000) {
    sentMessagesTimestamps.shift()
  }
  return sentMessagesTimestamps.length < MAX_MESSAGES_PER_MINUTE
}

// ── Global Processing Queue ────────────────────────────────────────────────
interface QueueItem {
  action: () => Promise<BotConversaSendResult>
  priority: number
  resolve: (res: BotConversaSendResult) => void
  reject: (err: any) => void
}

const messageQueue: QueueItem[] = []
let isProcessingQueue = false

async function processQueue() {
  if (isProcessingQueue) return
  isProcessingQueue = true

  while (messageQueue.length > 0) {
    // Sort by priority desc (higher priority first)
    messageQueue.sort((a, b) => b.priority - a.priority)
    const item = messageQueue.shift()!

    // Wait random delay between 3 and 5 seconds
    const delayMs = 3000 + Math.random() * 2000
    console.log(`[Queue] Delaying send for ${Math.round(delayMs)}ms to respect Meta rules (priority=${item.priority})...`)
    await new Promise(r => setTimeout(r, delayMs))

    try {
      const result = await item.action()
      item.resolve(result)
    } catch (err) {
      item.reject(err)
    }
  }

  isProcessingQueue = false
}

export function queueAction(
  action: () => Promise<BotConversaSendResult>,
  priority = 0
): Promise<BotConversaSendResult> {
  return new Promise((resolve, reject) => {
    messageQueue.push({ action, priority, resolve, reject })
    processQueue()
  })
}

// ── PNG → JPEG URL rewrite ────────────────────────────────────────────────
// BotConversa/WhatsApp has issues rendering PNGs.
export function ensureJpegUrl(url: string): string {
  if (!url.toLowerCase().endsWith(".png")) return url
  console.log(`[PNG→JPEG] URL rewrite: ${url}`)
  return url.replace(/\.png$/i, ".jpeg")
}

// ── Phone validation ──────────────────────────────────────────────────────
export function isValidPhone(phone: string): boolean {
  if (!phone) return false
  const digits = phone.replace(/\D/g, "")
  
  // Standard E.164 phone length is between 10 and 15 digits
  if (digits.length < 10 || digits.length > 15) return false

  // Specific validation rules for Brazilian numbers
  if (digits.startsWith("55")) {
    // Brazilian numbers must have 12 (landline) or 13 (mobile) digits total
    if (digits.length !== 12 && digits.length !== 13) return false
    
    // Extract DDD (digits 2 and 3)
    const ddd = digits.substring(2, 4)
    if (ddd.startsWith("0")) return false
  }
  
  return true
}

// ── Phone normalization ───────────────────────────────────────────────────
export function normalizePhone(raw: string): string {
  if (!raw) return ""
  
  // 1. Remove all non-digits and leading zeros
  let phone = raw.replace(/\D/g, "").replace(/^0+/, "")

  if (phone.length === 0) return ""

  // 2. Guarantee country code '55' for Brazil
  // If the number does not start with '55', OR if it starts with '55' but is too short (10 or 11 digits, meaning '55' is the DDD),
  // then we prefix it with '55'.
  if (!phone.startsWith("55") || phone.length === 10 || phone.length === 11) {
    phone = "55" + phone
  }

  // 3. Handle old 8-digit mobile numbers (add 9th digit '9')
  // Brazilian mobile numbers after DDD start with 6, 7, 8, or 9.
  // A number with country code '55' + 2-digit DDD + 8-digit local number has exactly 12 digits.
  if (phone.length === 12) {
    const country = phone.substring(0, 2) // "55"
    const ddd = phone.substring(2, 4)
    const local = phone.substring(4)
    const firstDigit = local.charAt(0)
    
    if (["6", "7", "8", "9"].includes(firstDigit)) {
      phone = country + ddd + "9" + local
    }
  }

  return phone
}

// ── Send text or file message (Direct Fetch) ─────────────────────────────────────
export async function sendMessageDirect(
  apiKey: string,
  subscriberId: string,
  tipo: "text" | "file",
  value: string
): Promise<BotConversaSendResult> {
  const finalValue = tipo === "file" ? ensureJpegUrl(value) : value
  const url = `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_message/`
  
  console.log(`[sendMessageDirect] Request: URL=${url}, payloadType=${tipo}, subscriberId=${subscriberId}`)

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "API-KEY": apiKey,
      },
      body: JSON.stringify({ type: tipo, value: finalValue }),
    })

    const resultText = await res.text()
    console.log(`[sendMessageDirect] Response: status=${res.status}, body=${resultText}`)

    if (!res.ok) {
      const resultLower = resultText.toLowerCase()
      const isDisconnected = resultLower.includes("disconnect") || 
                             resultLower.includes("offline") || 
                             resultLower.includes("not connected") ||
                             res.status === 503 || res.status === 402;
      return {
        success: false,
        skipped: false,
        resolvedNow: false,
        subscriberId,
        phoneNormalized: "",
        httpStatus: res.status,
        reason: `${res.status}: ${resultText}`,
        error: `${res.status}: ${resultText}`,
        deliveryStatus: isDisconnected ? "BOTCONVERSA_DISCONNECTED" : "BOTCONVERSA_API_ERROR"
      }
    }

    return {
      success: true,
      skipped: false,
      resolvedNow: false,
      subscriberId,
      phoneNormalized: "",
      httpStatus: res.status,
      deliveryStatus: "WHATSAPP_DELIVERY_UNKNOWN"
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error(`[sendMessageDirect] Fetch exception:`, message)
    return {
      success: false,
      skipped: false,
      resolvedNow: false,
      subscriberId,
      phoneNormalized: "",
      reason: message,
      error: message,
      deliveryStatus: "BOTCONVERSA_DISCONNECTED"
    }
  }
}

// ── Send text or file message (Queued Wrapper) ──────────────────────────────────
export async function sendMessage(
  apiKey: string,
  subscriberId: string,
  tipo: "text" | "file",
  value: string
): Promise<BotConversaSendResult> {
  const valLower = value.toLowerCase()
  const priority = (valLower.includes("sos") || valLower.includes("codigo") || valLower.includes("senha") || valLower.includes("urgente")) ? 1 : 0
  
  return queueAction(
    () => sendMessageDirect(apiKey, subscriberId, tipo, value),
    priority
  )
}

// ── Send interactive button message (Direct Fetch) ──────────────────────────────
export interface InteractiveButton {
  id: string
  title: string // max 20 chars
}

export async function sendInteractiveButtonsDirect(
  apiKey: string,
  subscriberId: string,
  bodyText: string,
  buttons: InteractiveButton[],
  headerText?: string,
  footerText?: string
): Promise<BotConversaSendResult> {
  const url = `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_message/`
  console.log(`[sendInteractiveButtonsDirect] Request: URL=${url}, subscriberId=${subscriberId}`)

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

    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "API-KEY": apiKey,
      },
      body: JSON.stringify({ type: "interactive", value: interactive }),
    })

    const resultText = await res.text()
    console.log(`[sendInteractiveButtonsDirect] Response: status=${res.status}, body=${resultText}`)

    if (!res.ok) {
      return {
        success: false,
        skipped: false,
        resolvedNow: false,
        subscriberId,
        phoneNormalized: "",
        httpStatus: res.status,
        reason: `${res.status}: ${resultText}`,
        error: `${res.status}: ${resultText}`
      }
    }
    return {
      success: true,
      skipped: false,
      resolvedNow: false,
      subscriberId,
      phoneNormalized: "",
      httpStatus: res.status
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error(`[sendInteractiveButtonsDirect] Fetch exception:`, message)
    return {
      success: false,
      skipped: false,
      resolvedNow: false,
      subscriberId,
      phoneNormalized: "",
      reason: message,
      error: message
    }
  }
}

// ── Send interactive button message (Queued Wrapper) ───────────────────────────
export async function sendInteractiveButtons(
  apiKey: string,
  subscriberId: string | null | undefined,
  bodyText: string,
  buttons: InteractiveButton[],
  headerText?: string,
  footerText?: string,
  supabase?: any,
  perfilId?: string,
  phone?: string | null | undefined
): Promise<BotConversaSendResult> {
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

  return smartSend(
    apiKey,
    subscriberId,
    phone,
    "interactive",
    JSON.stringify(interactive),
    undefined,
    supabase,
    perfilId
  )
}

// ── Send flow ─────────────────────────────────────────────────────────────
export async function sendFlow(
  apiKey: string,
  subscriberId: string,
  flowId: number
): Promise<BotConversaSendResult> {
  const url = `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_flow/`
  console.log(`[sendFlow] Request: URL=${url}, subscriberId=${subscriberId}, flowId=${flowId}`)

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "API-KEY": apiKey,
      },
      body: JSON.stringify({ flow: flowId }),
    })

    const resultText = await res.text()
    console.log(`[sendFlow] Response: status=${res.status}, body=${resultText}`)

    if (!res.ok) {
      return {
        success: false,
        skipped: false,
        resolvedNow: false,
        subscriberId,
        phoneNormalized: "",
        httpStatus: res.status,
        reason: `${res.status}: ${resultText}`,
        error: `${res.status}: ${resultText}`
      }
    }
    return {
      success: true,
      skipped: false,
      resolvedNow: false,
      subscriberId,
      phoneNormalized: "",
      httpStatus: res.status
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error(`[sendFlow] Fetch exception:`, message)
    return {
      success: false,
      skipped: false,
      resolvedNow: false,
      subscriberId,
      phoneNormalized: "",
      reason: message,
      error: message
    }
  }
}

// ── Resolve subscriber ID from phone ──────────────────────────
export async function resolveSubscriber(
  apiKey: string,
  phone: string,
  firstName?: string,
  supabase?: any,
  perfilId?: string
): Promise<{ success: boolean; subscriberId?: string; httpStatus?: number; error?: string }> {
  const cleanPhone = normalizePhone(phone)
  const url = `${BOTCONVERSA_BASE_URL}/subscriber/`

  try {
    const subRes = await fetch(url, {
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

    const subText = await subRes.text()
    if (!subRes.ok) {
      return {
        success: false,
        httpStatus: subRes.status,
        error: `Subscriber Resolve Failed: ${subRes.status} ${subText}`
      }
    }

    const subData = JSON.parse(subText)
    const subscriberId = String(subData.id || subData.subscriber_id || "")
    if (!subscriberId) {
      return {
        success: false,
        error: "No subscriber ID returned from BotConversa API"
      }
    }

    if (supabase && perfilId) {
      const { error: dbError } = await supabase
        .from("perfil")
        .update({ botconversa_id: subscriberId })
        .eq("id", perfilId)
      if (dbError) {
        console.error(`[resolveSubscriber] DB update failed for perfil=${perfilId}:`, dbError.message)
      }
    }

    return {
      success: true,
      subscriberId
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    return {
      success: false,
      error: message
    }
  }
}

// ── Send by phone ──────────────────────────────────────────
export async function sendByPhone(
  apiKey: string,
  phone: string,
  tipo: "text" | "file",
  value: string,
  firstName?: string
): Promise<BotConversaSendResult> {
  const cleanPhone = normalizePhone(phone)
  const resolveResult = await resolveSubscriber(apiKey, cleanPhone, firstName)

  if (!resolveResult.success) {
    const errorText = resolveResult.error || ""
    const isDisconnected = errorText.toLowerCase().includes("timeout") || 
                           errorText.toLowerCase().includes("fetch") || 
                           errorText.toLowerCase().includes("typeerror") ||
                           resolveResult.httpStatus === 503 || resolveResult.httpStatus === 402;
    return {
      success: false,
      skipped: false,
      resolvedNow: true,
      subscriberId: "",
      phoneNormalized: cleanPhone,
      httpStatus: resolveResult.httpStatus,
      reason: resolveResult.error,
      error: resolveResult.error,
      deliveryStatus: isDisconnected ? "BOTCONVERSA_DISCONNECTED" : "BOTCONVERSA_API_ERROR"
    }
  }

  const subscriberId = resolveResult.subscriberId!
  const sendResult = await sendMessage(apiKey, subscriberId, tipo, value)
  
  return {
    success: sendResult.success,
    skipped: false,
    resolvedNow: true,
    subscriberId,
    phoneNormalized: cleanPhone,
    httpStatus: sendResult.httpStatus,
    reason: sendResult.error,
    error: sendResult.error,
    deliveryStatus: sendResult.deliveryStatus
  }
}

// ── Smart send: prefer botconversa_id, fallback to phone ──────────────────
// SHA-256 helper
async function sha256(text: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
  return hashHex;
}

// ── Smart send: Produces outbox record instead of direct API call ──────────
export async function smartSend(
  apiKey: string,
  botconversaId: string | null | undefined,
  phone: string | null | undefined,
  tipo: "text" | "file" | "interactive",
  value: string,
  firstName?: string,
  supabase?: any,
  perfilId?: string
): Promise<BotConversaSendResult> {
  const rawPhone = phone || ""
  const phoneNormalized = normalizePhone(rawPhone)
  
  console.log(`[smartSend] Queuing message. phone: "${rawPhone}", Normalized: "${phoneNormalized}", botconversaId: "${botconversaId || "NULL"}", perfilId: "${perfilId || "unknown"}"`)

  // 1. Validate phone
  if (!phoneNormalized || !isValidPhone(phoneNormalized)) {
    const reason = `Telefone invalido ou vazio: "${rawPhone}" (normalizado: "${phoneNormalized}")`
    console.error(`[smartSend] ${reason}`)
    
    // Log to DB if Supabase client is available
    let sb = supabase;
    if (!sb) {
      try {
        const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
        sb = createClient(Deno.env.get("SUPABASE_URL") || "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
      } catch (_) {}
    }
    if (sb) {
      try {
        await sb.from("botconversa_monitoring").insert({
          action_type: "invalid_phone",
          recipient_phone: phoneNormalized,
          perfil_id: perfilId || null,
          error_message: reason,
          function_name: "smartSend",
          delivery_status: "BOTCONVERSA_API_ERROR"
        });
      } catch (_) {}
    }
    
    return {
      success: false,
      skipped: true,
      resolvedNow: false,
      subscriberId: "",
      phoneNormalized,
      reason,
      error: reason,
      deliveryStatus: "BOTCONVERSA_API_ERROR"
    }
  }

  // 2. Resolve database client
  let sb = supabase;
  if (!sb) {
    try {
      const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
      sb = createClient(Deno.env.get("SUPABASE_URL") || "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
    } catch (err) {
      console.error("[smartSend] Failed to initialize Supabase client:", err);
    }
  }

  let finalPerfilId = perfilId || null;
  let condominioId = null;

  // 3. Resolve condominio_id and perfil_id
  if (sb) {
    try {
      if (finalPerfilId) {
        const { data } = await sb
          .from("perfil")
          .select("condominio_id")
          .eq("id", finalPerfilId)
          .maybeSingle();
        if (data) condominioId = data.condominio_id;
      } else {
        // Fallback: search by phone
        const { data } = await sb
          .from("perfil")
          .select("id, condominio_id")
          .eq("whatsapp", phoneNormalized)
          .limit(1)
          .maybeSingle();
        if (data) {
          finalPerfilId = data.id;
          condominioId = data.condominio_id;
        }
      }
    } catch (err) {
      console.error("[smartSend] Failed to resolve condominio_id/perfil_id:", err);
    }
  }

  // 4. Compute message priority
  let priority = 10; // Default
  const lowerVal = value.toLowerCase();
  if (lowerVal.includes("sos") || lowerVal.includes("aprovar entrada") || lowerVal.includes("recusar entrada") || lowerVal.includes("senha")) {
    priority = 1; // Critical
  } else if (lowerVal.includes("lembrete") || lowerVal.includes("boleto") || lowerVal.includes("vencimento")) {
    priority = 20; // Low
  }

  // 5. Compute unique message hash
  const rawString = `${phoneNormalized}:${tipo}:${value}:${condominioId || ""}`;
  const messageHash = await sha256(rawString);

  // 6. Check dynamic deduplication (pending or sent within 2 minutes)
  if (sb) {
    try {
      const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000).toISOString();
      const { data: duplicate } = await sb
        .from("whatsapp_outbox")
        .select("id")
        .eq("message_hash", messageHash)
        .or(`status.eq.pending,and(status.eq.sent,sent_at.gt.${twoMinutesAgo})`)
        .limit(1)
        .maybeSingle();

      if (duplicate) {
        console.log(`[smartSend] Deduplicação ativada. Mensagem duplicada ignorada (Hash: ${messageHash})`);
        return {
          success: true,
          skipped: true,
          resolvedNow: false,
          subscriberId: botconversaId || "",
          phoneNormalized,
          deliveryStatus: "EDGE_FUNCTION_SUCCESS"
        }
      }
    } catch (err) {
      console.error("[smartSend] Error checking duplicate hash:", err);
    }
  }

  // 7. Insert message into whatsapp_outbox
  if (sb) {
    try {
      const { error: insError } = await sb
        .from("whatsapp_outbox")
        .insert({
          recipient_phone: phoneNormalized,
          perfil_id: finalPerfilId,
          condominio_id: condominioId,
          payload_type: tipo,
          message_type: "TEXTO_LIVRE",
          message_content: {
            value,
            firstName: firstName || "",
            botconversaId: botconversaId || null
          },
          priority,
          message_hash: messageHash
        });

      if (insError) {
        console.error("[smartSend] Error inserting into outbox:", insError);
        return {
          success: false,
          skipped: false,
          resolvedNow: false,
          subscriberId: botconversaId || "",
          phoneNormalized,
          error: insError.message,
          deliveryStatus: "BOTCONVERSA_API_ERROR"
        }
      }
    } catch (err: any) {
      console.error("[smartSend] Exception inserting into outbox:", err);
      return {
        success: false,
        skipped: false,
        resolvedNow: false,
        subscriberId: botconversaId || "",
        phoneNormalized,
        error: err.message || String(err),
        deliveryStatus: "BOTCONVERSA_API_ERROR"
      }
    }
  }

  return {
    success: true,
    skipped: false,
    resolvedNow: false,
    subscriberId: botconversaId || "",
    phoneNormalized,
    deliveryStatus: "EDGE_FUNCTION_SUCCESS"
  }
}

// ── Send to multiple recipients sequentially ──────────────────────────────
export async function sendToRecipients(
  apiKey: string,
  recipients: Array<{ id: string; botconversa_id?: string | null; whatsapp?: string | null; nome_completo: string }>,
  msg: string,
  tipo: "text" | "file",
  options?: { flowId?: number; personalizeMsg?: boolean; supabase?: any }
): Promise<BotConversaSendResult[]> {
  const delayMs = tipo === "file" ? DELAY_FILE_MS : DELAY_TEXT_MS
  const results: BotConversaSendResult[] = []

  for (let i = 0; i < recipients.length; i++) {
    const recipient = recipients[i]
    const finalMsg =
      options?.personalizeMsg !== false
        ? msg.replace(
            /\|nome\|/g,
            recipient.nome_completo?.split(" ")[0] || "Morador"
          )
        : msg

    const result = await smartSend(
      apiKey,
      recipient.botconversa_id,
      recipient.whatsapp,
      tipo,
      finalMsg,
      recipient.nome_completo?.split(" ")[0],
      options?.supabase,
      recipient.id
    )

    results.push(result)

    // Rate limit between sends (skip after last)
    if (i < recipients.length - 1) {
      await new Promise((resolve) => setTimeout(resolve, delayMs))
    }
  }

  return results
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
  try {
    const subscriber = body.subscriber || {};
    const message = body.message || body.last_message || {};
    
    const phone = subscriber.phone || body.phone;
    const text = message.text || message.value || body.text || "";
    const messageType = message.type || body.type || (text ? "text" : "unknown");
    const isGroup = false;
    const fromMe = body.direction === "outbound" || !!body.fromMe;
    const messageId = message.id || body.id || String(Date.now());

    if (!phone) return null;

    return {
      phone: String(phone).replace(/\D/g, ""),
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
