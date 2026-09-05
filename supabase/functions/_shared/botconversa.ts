// _shared/botconversa.ts — Shared BotConversa API utilities
// Used by: botconversa-send, whatsapp-parcel-notify, and other notification functions

export { MessageType, VALID_MESSAGE_TYPES, EVENT_PRIORITY_MAP, TEMPLATE_REGISTRY, validateTemplateContract, PolicyErrorCode, REGISTERED_OFFICIAL_TEMPLATES, AUTHORIZED_TRANSACTIONAL_CALLERS, CALLER_ALLOWED_MESSAGE_TYPES, MESSAGE_ABSOLUTE_TTL_SECONDS, MESSAGE_FALLBACK_WINDOW_SECONDS, getMessageTTL, getMessageFallbackWindow } from "./message_types.ts";
export type { MessageTypeValue, TemplateContract, TemplateDefinition } from "./message_types.ts";
import { MessageType, VALID_MESSAGE_TYPES, EVENT_PRIORITY_MAP, TEMPLATE_REGISTRY, validateTemplateContract, PolicyErrorCode, REGISTERED_OFFICIAL_TEMPLATES, AUTHORIZED_TRANSACTIONAL_CALLERS, CALLER_ALLOWED_MESSAGE_TYPES, TemplateContract, MessageTypeValue, getMessageTTL, getMessageFallbackWindow } from "./message_types.ts";

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

// ── Send text or file message (Direct Fetch - Encapsulado/Privado) ───────────────
async function sendMessageDirect(
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

// ── Send text or file message (Queued Wrapper - Encapsulado/Privado) ────────────
async function sendMessage(
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

// ── Send interactive button message (Direct Fetch - Encapsulado/Privado) ────────
export interface InteractiveButton {
  id: string
  title: string // max 20 chars
}

async function sendInteractiveButtonsDirect(
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
  phone?: string | null | undefined,
  messageType?: string,
  callerFunction?: string
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
    perfilId,
    messageType || MessageType.VISITOR_AUTHORIZED,
    callerFunction || "sendInteractiveButtons"
  )
}

// ── Send flow (Encapsulado/Privado) ──────────────────────────────────────────
async function sendFlow(
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

// ── Send by phone (Encapsulado/Privado) ──────────────────────────────────────
async function sendByPhone(
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
export async function sha256(text: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
  return hashHex;
}

export interface PolicyCheckParams {
  callerFunction?: string;
  messageType?: string;
  templateName?: string | null;
  templateCategory?: string | null;
  textValue?: string;
  isCampaign?: boolean;
  isBroadcast?: boolean;
  recipientCount?: number;
  templateParams?: string[];
}

export function validateWhatsAppSendPolicy(params: PolicyCheckParams): { allowed: boolean; reason?: string; errorCode?: string } {
  const { callerFunction, messageType, templateName, templateCategory, textValue = "", isCampaign = false, isBroadcast = false, recipientCount, templateParams } = params;
  const lowerText = textValue.toLowerCase();

  // 0a. Strict Whitelist Check (FASE 4.16B)
  if (!callerFunction || !AUTHORIZED_TRANSACTIONAL_CALLERS.has(callerFunction)) {
    return {
      allowed: false,
      reason: `Caller '${callerFunction || "anônimo"}' is not authorized in AUTHORIZED_TRANSACTIONAL_CALLERS. All WhatsApp dispatches must originate from homologated transactional callers.`,
      errorCode: PolicyErrorCode.CALLER_NOT_AUTHORIZED,
    };
  }

  // 0b. Caller Allowed MessageTypes Matrix Check (FASE 4.16B)
  if (messageType && callerFunction in CALLER_ALLOWED_MESSAGE_TYPES) {
    const allowedTypes = CALLER_ALLOWED_MESSAGE_TYPES[callerFunction];
    if (allowedTypes && !allowedTypes.has(messageType)) {
      return {
        allowed: false,
        reason: `MessageType '${messageType}' is not permitted for caller '${callerFunction}'.`,
        errorCode: PolicyErrorCode.INVALID_CALLER_MESSAGE_TYPE,
      };
    }
  }

  // 0c. Prohibit broadcast/campaign dispatches on WhatsApp
  if (isCampaign || isBroadcast) {
    return {
      allowed: false,
      reason: "Broadcast / mass campaign messages are strictly forbidden on WhatsApp by Condomeet Governance (FASE 4.16B). Use Push Notification (FCM), In-App Feed, or Email for broad communication.",
      errorCode: PolicyErrorCode.BROADCAST_BLOCKED,
    };
  }

  // 0d. Validate transactional recipient volume limit (Max 5 for transactional groups, e.g. board members / emergency contacts)
  if (recipientCount && recipientCount > 5) {
    return {
      allowed: false,
      reason: `Recipient count (${recipientCount}) exceeds maximum allowed transactional threshold (5). Mass dispatches on WhatsApp are forbidden.`,
      errorCode: PolicyErrorCode.BROADCAST_BLOCKED,
    };
  }

  // 1. Prohibit MARKETING category across all channels
  if (templateCategory === "MARKETING" || messageType === "MARKETING") {
    return {
      allowed: false,
      reason: "Marketing category is strictly forbidden in Condomeet WhatsApp ecosystem.",
      errorCode: PolicyErrorCode.MARKETING_BLOCKED,
    };
  }

  // 2. Prohibit commercial upsell, ads, sales calls, or marketing links in text content
  if (
    lowerText.includes("destacar seu perfil") ||
    lowerText.includes("atrair mais clientes") ||
    lowerText.includes("instagram.com") ||
    lowerText.includes("facebook.com") ||
    lowerText.includes("compre agora") ||
    lowerText.includes("oferta exclusiva") ||
    lowerText.includes("cupom de desconto")
  ) {
    return {
      allowed: false,
      reason: `Commercial marketing content detected in "${callerFunction || 'dispatch'}". Marketing dispatches are forbidden.`,
      errorCode: PolicyErrorCode.MARKETING_BLOCKED,
    };
  }

  // 3. Campaigns MUST use an approved template from TEMPLATE_REGISTRY (NO FREE TEXT FOR CAMPAIGNS)
  if (isCampaign) {
    if (!templateName || templateName.trim() === "") {
      return {
        allowed: false,
        reason: "WhatsApp campaigns must use an approved template from TEMPLATE_REGISTRY. Free text is forbidden.",
        errorCode: PolicyErrorCode.CAMPAIGN_FREE_TEXT_BLOCKED,
      };
    }

    // Check if template is registered in TEMPLATE_REGISTRY or REGISTERED_OFFICIAL_TEMPLATES
    const isRegistered = REGISTERED_OFFICIAL_TEMPLATES.has(templateName) || Object.values(TEMPLATE_REGISTRY).some(
      (tpl) => tpl && tpl.defaultName === templateName
    );
    if (!isRegistered) {
      return {
        allowed: false,
        reason: `Template '${templateName}' is not registered in TEMPLATE_REGISTRY.`,
        errorCode: PolicyErrorCode.TEMPLATE_NOT_REGISTERED,
      };
    }
  }

  // 4. Validate template contract if an explicit templateName is requested or worker is attempting Meta Cloud API dispatch
  if ((templateName || callerFunction === "whatsapp-outbox-worker") && messageType && messageType in TEMPLATE_REGISTRY) {
    const tplDef = TEMPLATE_REGISTRY[messageType as keyof typeof TEMPLATE_REGISTRY];
    if (tplDef) {
      if (templateName && templateName !== tplDef.defaultName && !templateName.startsWith(tplDef.family)) {
        return {
          allowed: false,
          reason: `Template '${templateName}' does not match registered family '${tplDef.family}' for messageType '${messageType}'.`,
          errorCode: PolicyErrorCode.INVALID_CONTRACT,
        };
      }

      if (templateParams && templateParams.length < tplDef.minParameters) {
        return {
          allowed: false,
          reason: `Template '${tplDef.defaultName}' requires at least ${tplDef.minParameters} parameters, provided ${templateParams.length}.`,
          errorCode: PolicyErrorCode.INVALID_CONTRACT,
        };
      }
    }
  }

  return { allowed: true };
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
  perfilId?: string,
  messageType?: string,
  callerFunction?: string,
  templateParams?: string[],
  entityType?: string,
  entityId?: string
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

  // 1b. Central Policy Governance Check (Whitelist de Callers, Anti-Broadcast e Diretrizes Gerais)
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: callerFunction || "smartSend",
    messageType,
    textValue: value,
    isCampaign: callerFunction === "campaign-worker",
  });

  if (!policyCheck.allowed) {
    console.error(JSON.stringify({
      event: "WHATSAPP_POLICY_BLOCKED",
      errorCode: policyCheck.errorCode,
      reason: policyCheck.reason,
      caller_function: callerFunction || "smartSend",
      message_type: messageType || null,
      recipient_phone: phoneNormalized
    }));

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
          action_type: "POLICY_BLOCKED",
          recipient_phone: phoneNormalized,
          perfil_id: perfilId || null,
          error_message: `[${policyCheck.errorCode}] ${policyCheck.reason}`,
          function_name: callerFunction || "smartSend",
          delivery_status: policyCheck.errorCode
        });
      } catch (_) {}
    }

    return {
      success: false,
      skipped: true,
      resolvedNow: false,
      subscriberId: botconversaId || "",
      phoneNormalized,
      reason: policyCheck.reason,
      error: policyCheck.reason,
      deliveryStatus: policyCheck.errorCode as any
    };
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
  let condominioId: string | null = null;

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

  // 4. Compute message priority via MessageType / EVENT_PRIORITY_MAP
  let priority: number;
  const isValidType = messageType && VALID_MESSAGE_TYPES.has(messageType as any);

  if (isValidType && messageType in EVENT_PRIORITY_MAP) {
    // Resolução Oficial Determinística por Tipo de Evento
    priority = EVENT_PRIORITY_MAP[messageType as keyof typeof EVENT_PRIORITY_MAP];
    console.log(JSON.stringify({
      event: "OFFICIAL_PRIORITY_RESOLVED",
      message_type: messageType,
      priority,
      queue: priority <= 5 ? "queue=high" : "queue=low",
      caller_function: callerFunction || "desconhecida"
    }));
  } else {
    // Transição Fases 1 e 2: Warning Estruturado + Fallback por Texto Temporário
    const lowerVal = value.toLowerCase();
    if (lowerVal.includes("sos") || lowerVal.includes("aprovar entrada") || lowerVal.includes("recusar entrada") || lowerVal.includes("senha")) {
      priority = 1; // Critical
    } else if (lowerVal.includes("lembrete") || lowerVal.includes("boleto") || lowerVal.includes("vencimento")) {
      priority = 20; // Low
    } else {
      priority = 10; // Default
    }

    console.warn(JSON.stringify({
      event: "DEPRECATED_FALLBACK_TRIGGERED",
      warning: `MessageType ausente ou nao homologado ("${messageType || "vazio"}"). Ativando fallback temporario por texto.`,
      caller_function: callerFunction || "desconhecida",
      received_message_type: messageType || null,
      calculated_priority: priority,
      queue: priority <= 5 ? "queue=high" : "queue=low"
    }));
  }

  // 4b. Validar contrato do Template se houver definição no TEMPLATE_REGISTRY
  // REGRA CANÔNICA FASE 4.17.1: A ausência, pendência ou erro de contrato do template Meta
  // NUNCA pode impedir o BotConversa de enfileirar e enviar a mensagem primária.
  // A validação Meta define apenas se o fallback para a Meta Cloud API estará disponível.
  let templateObject: TemplateContract | null = null;
  const isMetaTemplateCandidate = tipo !== "interactive" && !(callerFunction === "whatsapp-guest" && !templateParams);
  const templateDef = (isMetaTemplateCandidate && messageType) ? TEMPLATE_REGISTRY[messageType as MessageTypeValue] : null;

  if (templateDef) {
    let resolvedName = templateDef.defaultName;
    let resolvedVersion = templateDef.contractVersion || 1;
    let isDbApproved = false;

    // Tentativa de resolver automaticamente a versão/nome do template no banco local
    if (sb) {
      try {
        const { data: dbTemplate } = await sb.rpc("resolve_whatsapp_template", { 
          p_family: templateDef.family, 
          p_language: templateDef.language 
        });
        if (dbTemplate && dbTemplate.name) {
          resolvedName = dbTemplate.name;
          resolvedVersion = dbTemplate.template_version || resolvedVersion;
          isDbApproved = dbTemplate.status === "APPROVED";
        } else {
          console.warn(JSON.stringify({
            event: "TEMPLATE_FALLBACK_UNAPPROVED_LOCAL",
            template: templateDef.defaultName,
            family: templateDef.family,
            message_type: messageType,
            warning: `Template '${templateDef.defaultName}' não está APPROVED na tabela local de templates. O envio primário BotConversa prossegue normalmente.`,
            caller_function: callerFunction || "desconhecida"
          }));
        }
      } catch (e) {
        console.warn(`[smartSend] Erro não-bloqueante ao resolver template family ${templateDef.family}:`, e);
      }
    }

    const candidateTemplate: TemplateContract = {
      contract_version: resolvedVersion,
      name: resolvedName,
      language: templateDef.language,
      parameters: templateParams || []
    };

    const validation = validateTemplateContract(messageType!, candidateTemplate);
    if (validation.valid) {
      templateObject = candidateTemplate;
    } else {
      console.warn(JSON.stringify({
        event: "META_FALLBACK_TEMPLATE_UNAVAILABLE",
        warning: "Contrato de template Meta ausente ou incompleto para esta mensagem. O envio primário pelo BotConversa prosseguirá normalmente sem payload estruturado de fallback.",
        error: validation.error,
        message_type: messageType,
        caller_function: callerFunction || "desconhecida"
      }));
      // Fallback estruturado desabilitado, mas o envio primário no BotConversa CONTINUA!
      templateObject = null;
    }
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

  // 7. Enqueue message into whatsapp_outbox via Canonical PostgreSQL Governance RPC
  if (sb) {
    try {
      const resolvedEntityType = entityType || (messageType === MessageType.OTP ? "auth_users" : "perfil");
      const resolvedEntityId = entityId || finalPerfilId || undefined;
      const ttlSeconds = getMessageTTL(messageType);
      const calculatedExpiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();

      const { data: outboxId, error: rpcError } = await sb.rpc(
        "enqueue_whatsapp_transactional_message",
        {
          p_recipient_phone: phoneNormalized,
          p_payload_type: tipo,
          p_message_type: messageType || "TEXTO_LIVRE",
          p_message_content: {
            value,
            firstName: firstName || "",
            botconversaId: botconversaId || null,
            template: templateObject
          },
          p_caller_function: callerFunction || "smartSend",
          p_entity_type: resolvedEntityType,
          p_entity_id: resolvedEntityId,
          p_condominio_id: condominioId,
          p_perfil_id: finalPerfilId,
          p_priority: priority,
          p_expires_at: calculatedExpiresAt
        }
      );

      if (rpcError) {
        console.error("[smartSend] Governance RPC rejected message:", rpcError);
        return {
          success: false,
          skipped: false,
          resolvedNow: false,
          subscriberId: botconversaId || "",
          phoneNormalized,
          error: rpcError.message,
          deliveryStatus: "BOTCONVERSA_API_ERROR"
        };
      }
    } catch (err: any) {
      console.error("[smartSend] Exception invoking governance RPC:", err);
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

  // 7b. Fire & Forget Worker Wake-up Trigger
  try {
    const workerQueue = priority <= 5 ? "high" : "low"
    const edgeUrl = Deno.env.get("SUPABASE_URL") || "https://avypyaxthvgaybplnwxu.supabase.co"
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""

    if (edgeUrl && serviceKey) {
      fetch(`${edgeUrl}/functions/v1/whatsapp-outbox-worker?queue=${workerQueue}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceKey}`
        },
        body: JSON.stringify({})
      }).catch((wErr) => console.error("[smartSend] Background worker wake-up error:", wErr))
    }
  } catch (wakeErr) {
    console.error("[smartSend] Exception triggering worker wake-up:", wakeErr)
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
export const MAX_TRANSACTIONAL_RECIPIENTS = 5;

export async function sendToRecipients(
  apiKey: string,
  recipients: Array<{ id: string; botconversa_id?: string | null; whatsapp?: string | null; nome_completo: string }>,
  msg: string,
  tipo: "text" | "file",
  options?: { flowId?: number; personalizeMsg?: boolean; supabase?: any; messageType?: string; callerFunction?: string; templateParams?: string[] }
): Promise<BotConversaSendResult[]> {
  const delayMs = tipo === "file" ? DELAY_FILE_MS : DELAY_TEXT_MS
  const results: BotConversaSendResult[] = []

  // Anti-broadcast protection: reject batch calls exceeding transactional limits (FASE 4.16A)
  if (recipients.length > MAX_TRANSACTIONAL_RECIPIENTS) {
    console.error(JSON.stringify({
      event: "WHATSAPP_BROADCAST_BLOCKED",
      errorCode: PolicyErrorCode.BROADCAST_BLOCKED,
      recipient_count: recipients.length,
      max_allowed: MAX_TRANSACTIONAL_RECIPIENTS,
      reason: `Tentativa de envio em lote via WhatsApp com ${recipients.length} destinatários bloqueada por governança. Use Push FCM para difusão ampla.`,
      caller_function: options?.callerFunction || "sendToRecipients"
    }));
    return recipients.map((r) => ({
      success: false,
      skipped: true,
      resolvedNow: false,
      subscriberId: r.botconversa_id || "",
      phoneNormalized: normalizePhone(r.whatsapp || ""),
      reason: `Bloqueio de Governança (FASE 4.16A): Envio para ${recipients.length} destinatários excede o limite transacional (${MAX_TRANSACTIONAL_RECIPIENTS}). Broadcast via WhatsApp é proibido.`,
      error: `Bloqueio de Governança: Broadcast via WhatsApp é proibido.`,
      deliveryStatus: PolicyErrorCode.BROADCAST_BLOCKED as any
    }));
  }

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
      recipient.id,
      options?.messageType,
      options?.callerFunction,
      options?.templateParams
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

export interface CallResult {
  success: boolean
  status: number
  body?: string
  error?: string
  isPermanent: boolean
  providerMessageId?: string
  subscriberId?: string
}

async function fetchWithTimeout(
  url: string,
  options: RequestInit,
  timeoutMs = 30000
): Promise<{ ok: boolean; status: number; text: string; timedOut: boolean }> {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs)

  try {
    const res = await fetch(url, {
      ...options,
      signal: controller.signal,
    })
    const text = await res.text()
    clearTimeout(timeoutId)
    return { ok: res.ok, status: res.status, text, timedOut: false }
  } catch (err: any) {
    clearTimeout(timeoutId)
    const isTimeout = err.name === "AbortError"
    return {
      ok: false,
      status: isTimeout ? 408 : 500,
      text: err.message,
      timedOut: isTimeout,
    }
  }
}

// ── FASE 4.20.7: Evolution API Sender Helper ────────────────────────────────
export async function sendViaEvolution(
  apiUrl: string,
  apiKey: string,
  instanceName: string,
  recipientPhone: string,
  payloadType: string,
  messageContent: string
): Promise<CallResult> {
  const cleanPhone = normalizePhone(recipientPhone)
  const baseUrl = apiUrl.replace(/\/+$/, "")
  const isMedia = payloadType === "file" || payloadType === "image" || payloadType === "document"
  const endpoint = isMedia
    ? `${baseUrl}/message/sendMedia/${instanceName}`
    : `${baseUrl}/message/sendText/${instanceName}`

  const bodyPayload: Record<string, any> = {
    number: cleanPhone
  }

  if (isMedia) {
    bodyPayload.media = messageContent
    bodyPayload.mediatype = payloadType === "image" ? "image" : "document"
    bodyPayload.caption = ""
  } else {
    bodyPayload.text = messageContent
  }

  const res = await fetchWithTimeout(
    endpoint,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": apiKey
      },
      body: JSON.stringify(bodyPayload)
    },
    15000
  )

  if (res.timedOut) {
    return {
      success: false,
      status: 408,
      error: "Network Timeout (15s) no envio via Evolution API",
      isPermanent: false
    }
  }

  if (!res.ok) {
    // HTTP 400 e 404 indicam erro permanente (ex: formato incorreto); demais são transitórios
    const isPermanent = res.status === 400 || res.status === 404
    return {
      success: false,
      status: res.status,
      body: res.text,
      error: `Evolution API HTTP ${res.status}: ${res.text}`,
      isPermanent
    }
  }

  let providerMessageId: string | undefined
  try {
    const data = JSON.parse(res.text)
    providerMessageId = data?.key?.id || data?.id
  } catch (_) {
    // resposta em texto puro
  }

  return {
    success: true,
    status: res.status,
    body: res.text,
    providerMessageId,
    isPermanent: false
  }
}

// ── FASE 4.18 / FASE 4.20.7: Deterministic Partition & Router Helpers ─────────
export function getDeterministicPartition(id: string): number {
  let hash = 0;
  for (let i = 0; i < id.length; i++) {
    const char = id.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash |= 0;
  }
  return Math.abs(hash) % 100;
}

export interface WelcomePilotParams {
  perfilId?: string | null;
  messageId: string;
  pilotEnabled?: boolean;
  pilotPercentage?: number;
  evolutionConnected?: boolean;
}

export function calculateWelcomePilotRoute(params: WelcomePilotParams): {
  provider: "EVOLUTION" | "BOTCONVERSA";
  partition: number;
  reason: string;
} {
  const pilotEnabled = params.pilotEnabled ?? false;
  const pilotPercentage = params.pilotPercentage ?? 0;
  const evolutionConnected = params.evolutionConnected ?? true;
  const partitionKey = params.perfilId || params.messageId;
  const partition = getDeterministicPartition(partitionKey);

  // 1. Se o piloto estiver desligado -> 100% BotConversa
  if (!pilotEnabled) {
    return {
      provider: "BOTCONVERSA",
      partition,
      reason: "WELCOME_PILOT_DISABLED"
    };
  }

  // 2. Se a Evolution estiver desconectada antes do envio -> Failover seguro para BotConversa
  if (!evolutionConnected) {
    return {
      provider: "BOTCONVERSA",
      partition,
      reason: "EVOLUTION_DISCONNECTED_FAILOVER_BC"
    };
  }

  // 3. Avaliação da partição determinística conforme percentual do piloto (0, 25, 50, 100)
  if (pilotPercentage >= 100) {
    return {
      provider: "EVOLUTION",
      partition,
      reason: "WELCOME_PILOT_EVOLUTION_100PCT"
    };
  }

  if (pilotPercentage > 0 && partition < pilotPercentage) {
    return {
      provider: "EVOLUTION",
      partition,
      reason: `WELCOME_PILOT_EVOLUTION_${pilotPercentage}PCT`
    };
  }

  return {
    provider: "BOTCONVERSA",
    partition,
    reason: `WELCOME_PILOT_BC_REMAINDER_${100 - pilotPercentage}PCT`
  };
}

export function calculateWarmupRoute(params: {
  messageId: string;
  perfilId?: string | null;
  messageType?: string | null;
  warmupMode: boolean;
  canSendWarmup: boolean;
  welcomePilotEnabled?: boolean;
  welcomePilotPercentage?: number;
  evolutionConnected?: boolean;
}): {
  provider: "META" | "BOTCONVERSA" | "EVOLUTION";
  partition: number;
  reason: string;
} {
  // Regra 1a: DUAL_NUMBER_NOTICE sempre 100% BotConversa
  if (params.messageType === "DUAL_NUMBER_NOTICE") {
    return {
      provider: "BOTCONVERSA",
      partition: getDeterministicPartition(params.perfilId || params.messageId),
      reason: "DUAL_NUMBER_NOTICE_EXCLUSIVE_BC"
    };
  }

  // Regra 1b: WELCOME — Roteado exclusivamente pelo calculateWelcomePilotRoute (Evolution Piloto ou BotConversa)
  if (params.messageType === "WELCOME") {
    const welcomeRoute = calculateWelcomePilotRoute({
      perfilId: params.perfilId,
      messageId: params.messageId,
      pilotEnabled: params.welcomePilotEnabled ?? false,
      pilotPercentage: params.welcomePilotPercentage ?? 0,
      evolutionConnected: params.evolutionConnected ?? true
    });
    return {
      provider: welcomeRoute.provider,
      partition: welcomeRoute.partition,
      reason: welcomeRoute.reason
    };
  }

  // Regra 1c: NOTICE sempre 100% BotConversa enquanto não houver template Meta aprovado
  if (params.messageType === "NOTICE") {
    return {
      provider: "BOTCONVERSA",
      partition: getDeterministicPartition(params.perfilId || params.messageId),
      reason: "NOTICE_NO_TEMPLATE_BC"
    };
  }

  // Regra 1d: VISITOR_AUTHORIZED — Roteamento Balanceado 50% Meta / 50% BotConversa / 0% Evolution (Fase 7.13.1)
  if (params.messageType === "VISITOR_AUTHORIZED") {
    const partitionKey = params.perfilId || params.messageId;
    const partition = getDeterministicPartition(partitionKey);
    const isMeta = partition < 50;
    return {
      provider: isMeta ? "META" : "BOTCONVERSA",
      partition,
      reason: isMeta ? "VISITOR_AUTHORIZED_50PCT_META" : "VISITOR_AUTHORIZED_50PCT_BOTCONVERSA"
    };
  }

  // Regra 2: Se WARMUP_MODE estiver desligado, volta 100% para BotConversa First
  if (!params.warmupMode) {
    return {
      provider: "BOTCONVERSA",
      partition: getDeterministicPartition(params.messageId),
      reason: "WARMUP_MODE_DISABLED"
    };
  }

  const partition = getDeterministicPartition(params.messageId);

  // Regra 3: Se a partição for 99 (1%) E o teto diário permitir -> BotConversa Warmup
  if (partition >= 99) {
    if (params.canSendWarmup) {
      return {
        provider: "BOTCONVERSA",
        partition,
        reason: "WARMUP_ROTA_BC_1PCT"
      };
    } else {
      return {
        provider: "META",
        partition,
        reason: "WARMUP_CAP_EXCEEDED_ROLLOVER_META"
      };
    }
  }

  // Regra 4: Partições 0..98 (99%) -> Meta Primary
  return {
    provider: "META",
    partition,
    reason: "WARMUP_ROTA_META_99PCT"
  };
}

