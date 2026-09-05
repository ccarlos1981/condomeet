import { createClient } from "npm:@supabase/supabase-js@2"
import { renderTemplateText } from "../_shared/template_renderer.ts"
import { validateWhatsAppSendPolicy, getMessageFallbackWindow, getMessageTTL, calculateWarmupRoute, getDeterministicPartition, sendViaEvolution } from "../_shared/botconversa.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

const BOTCONVERSA_BASE_URL = "https://backend.botconversa.com.br/api/v1/webhook"
const META_API_BASE_URL = "https://graph.facebook.com/v21.0"
const BOTCONVERSA_TIMEOUT_MS = 30000 // 30s timeout para BotConversa (permite fluxo de 2 etapas: resolve + send)
const META_TIMEOUT_MS = 15000        // 15s timeout para Meta Cloud API (Graph API)

interface CallResult {
  success: boolean
  status?: number
  body?: string
  error?: string
  isPermanent: boolean
  providerMessageId?: string
  subscriberId?: string
}

// Helper to make fetch calls with strict timeout and AbortController
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
      status: isTimeout ? 408 : 0,
      text: err.message || String(err),
      timedOut: isTimeout,
    }
  }
}

// Resolves subscriber ID from BotConversa
async function resolveSubscriber(
  apiKey: string,
  phone: string,
  firstName: string
): Promise<CallResult> {
  const url = `${BOTCONVERSA_BASE_URL}/subscriber/`
  const body = {
    phone: phone,
    first_name: firstName || "Morador",
    last_name: ".",
  }

  const res = await fetchWithTimeout(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "API-KEY": apiKey,
    },
    body: JSON.stringify(body),
  }, BOTCONVERSA_TIMEOUT_MS)

  if (res.timedOut) {
    return { success: false, status: 408, error: "Network Timeout (30s) na resolucao do contato", isPermanent: false }
  }

  if (!res.ok) {
    // 4xx errors are permanent (except 408 timeout/429 rate limit), 5xx are temporary
    const isPermanent = res.status >= 400 && res.status < 500 && res.status !== 408 && res.status !== 429
    return { success: false, status: res.status, body: res.text, error: `HTTP ${res.status}: ${res.text}`, isPermanent }
  }

  try {
    const data = JSON.parse(res.text)
    const subId = String(data.id || data.subscriber_id || "")
    if (!subId) {
      return { success: false, error: "API do BotConversa nao retornou subscriber ID no JSON", isPermanent: true }
    }
    return { success: true, subscriberId: subId, isPermanent: false }
  } catch (err) {
    return { success: false, error: `Falha ao parsear JSON da API: ${err}`, isPermanent: true }
  }
}

// Dispatches direct message send to BotConversa
async function sendMessageToBotConversa(
  apiKey: string,
  subscriberId: string,
  type: string,
  value: string
): Promise<CallResult> {
  const url = `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_message/`
  
  let finalType = type
  let finalValue: any = value

  if (type === "file" && typeof value === "string" && value.toLowerCase().endsWith(".png")) {
    finalValue = value.replace(/\.png$/i, ".jpeg")
  } else if (type === "interactive") {
    finalType = "text"
    let parsed: any = null
    if (typeof value === "string") {
      try {
        parsed = JSON.parse(value)
      } catch (_) {
        parsed = null
      }
    } else if (typeof value === "object" && value !== null) {
      parsed = value
    }

    if (parsed) {
      const headerText = parsed.header?.text ? `*${parsed.header.text}*\n\n` : ""
      const bodyText = parsed.body?.text || (typeof value === "string" ? value : "")
      const footerText = parsed.footer?.text ? `\n\n_${parsed.footer.text}_` : ""
      
      let buttonsPrompt = ""
      if (Array.isArray(parsed.action?.buttons) && parsed.action.buttons.length > 0) {
        const buttonsList = parsed.action.buttons.map((b: any, idx: number) => {
          const title = b.reply?.title || b.title || `Opção ${idx + 1}`
          const icon = idx === 0 ? "1️⃣" : (idx === 1 ? "2️⃣" : "🔹")
          return `${icon} *${title}*`
        }).join("\n")
        
        buttonsPrompt = `\n\nResponda com:\n${buttonsList}`
      } else {
        buttonsPrompt = `\n\nResponda com:\n1️⃣ *APROVAR* — para autorizar a entrada\n2️⃣ *RECUSAR* — para recusar a entrada`
      }

      if (bodyText.includes("Responda com:") || bodyText.includes("1️⃣")) {
        finalValue = `${headerText}${bodyText}${footerText}`.trim()
      } else {
        finalValue = `${headerText}${bodyText}${buttonsPrompt}${footerText}`.trim()
      }
    } else {
      finalValue = typeof value === "string" ? value : JSON.stringify(value)
    }
  }

  const res = await fetchWithTimeout(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "API-KEY": apiKey,
    },
    body: JSON.stringify({ type: finalType, value: finalValue }),
  }, BOTCONVERSA_TIMEOUT_MS)

  if (res.timedOut) {
    return { success: false, status: 408, error: "Network Timeout (30s) no envio da mensagem", isPermanent: false }
  }

  if (!res.ok) {
    const isPermanent = res.status >= 400 && res.status < 500 && res.status !== 408 && res.status !== 429
    return { success: false, status: res.status, body: res.text, error: `HTTP ${res.status}: ${res.text}`, isPermanent }
  }

  return { success: true, status: res.status, body: res.text, isPermanent: false }
}

// Dispatches message send via Meta Cloud API (WhatsApp Business Platform)
async function sendViaMetaCloudAPI(
  accessToken: string,
  phoneNumberId: string,
  recipientPhone: string,
  messageType: string,
  messageContent: any,
  templateName?: string,
  templateLanguage?: string,
  templateComponents?: any[]
): Promise<CallResult> {
  const url = `${META_API_BASE_URL}/${phoneNumberId}/messages`

  // Build Meta Cloud API payload based on message type or template
  let payload: Record<string, any> = {
    messaging_product: "whatsapp",
    to: recipientPhone,
  }

  if (templateName) {
    payload.type = "template"
    payload.template = {
      name: templateName,
      language: {
        code: templateLanguage || "pt_BR"
      }
    }
    if (templateComponents) {
      payload.template.components = templateComponents
    }
  } else if (messageType === "text") {
    payload.type = "text"
    payload.text = { body: messageContent }
  } else if (messageType === "file") {
    // Determine media type from URL extension
    const urlLower = typeof messageContent === "string" ? messageContent.toLowerCase() : ""
    if (urlLower.match(/\.(jpg|jpeg|png|gif|webp)$/)) {
      payload.type = "image"
      payload.image = { link: messageContent }
    } else if (urlLower.match(/\.(pdf|doc|docx|xls|xlsx)$/)) {
      payload.type = "document"
      payload.document = { link: messageContent }
    } else {
      payload.type = "document"
      payload.document = { link: messageContent }
    }
  } else if (messageType === "interactive") {
    payload.type = "interactive"
    try {
      const parsed = typeof messageContent === "string" ? JSON.parse(messageContent) : messageContent
      payload.interactive = parsed
    } catch (_) {
      return { success: false, error: "Failed to parse interactive message content for Meta API", isPermanent: true }
    }
  } else {
    return { success: false, error: `Unsupported message type for Meta API: ${messageType}`, isPermanent: true }
  }

  const res = await fetchWithTimeout(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${accessToken}`,
    },
    body: JSON.stringify(payload),
  }, META_TIMEOUT_MS)

  if (res.timedOut) {
    return { success: false, status: 408, error: "Network Timeout (15s) no envio via Meta Cloud API", isPermanent: false }
  }

  if (!res.ok) {
    const isPermanent = res.status >= 400 && res.status < 500 && res.status !== 408 && res.status !== 429
    return { success: false, status: res.status, body: res.text, error: `Meta API HTTP ${res.status}: ${res.text}`, isPermanent }
  }

  return { success: true, status: res.status, body: res.text, isPermanent: false }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const urlObj = new URL(req.url)
  const queueType = urlObj.searchParams.get("queue")

  // Validate queueType
  if (queueType !== "high" && queueType !== "low") {
    return new Response(JSON.stringify({ error: `Invalid queue parameter: "${queueType || ""}". Use 'high' or 'low'.` }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }

  // Resolve Lease Lock ID and priority range
  let leaseId: string
  let minPriority: number
  let maxPriority: number

  if (queueType === "high") {
    leaseId = "high_priority"
    minPriority = 1
    maxPriority = 5
  } else {
    leaseId = "low_priority"
    minPriority = 6
    maxPriority = 99
  }

  const instanceId = crypto.randomUUID()
  const startAt = new Date().toISOString()

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY")
  if (!BOTCONVERSA_API_KEY) {
    console.error("BOTCONVERSA_API_KEY is not configured in env variables.")
    return new Response(JSON.stringify({ error: "BOTCONVERSA_API_KEY is not configured" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }

  // Meta Cloud API credentials (used as in-flight fallback)
  const META_ACCESS_TOKEN = Deno.env.get("WHATSAPP_ACCESS_TOKEN") || null
  const META_PHONE_NUMBER_ID = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") || null
  const metaCredentialsAvailable = !!META_ACCESS_TOKEN && !!META_PHONE_NUMBER_ID

  // Evolution API credentials & Feature Flags (FASE 4.26 — WELCOME 100% BotConversa / Evolution suspensa)
  const EVOLUTION_WELCOME_PILOT_ENABLED = Deno.env.get("EVOLUTION_WELCOME_PILOT_ENABLED") === "true"
  const EVOLUTION_WELCOME_PERCENTAGE = parseInt(Deno.env.get("EVOLUTION_WELCOME_PERCENTAGE") || "0", 10)
  const EVOLUTION_API_URL = Deno.env.get("EVOLUTION_API_URL") || "https://evolution.condomeet.com.br"
  const EVOLUTION_API_KEY = Deno.env.get("EVOLUTION_API_KEY") || ""
  const EVOLUTION_INSTANCE = Deno.env.get("EVOLUTION_INSTANCE") || "condomeet-secundario-prod"

  // 1. Acquire Database Lease Lock (PgBouncer compatible, crash resilient)
  const { data: leaseAcquired } = await supabase.rpc("acquire_worker_lease", {
    p_instance_id: instanceId,
    p_lease_duration_sec: 120,
    p_lease_id: leaseId
  })

  if (!leaseAcquired) {
    console.log(`[Worker] Outro container ativo possui o Lease Lock ou lock ativo nao expirou. Encerrando instance_id=${instanceId} para lease=${leaseId}.`)
    return new Response(JSON.stringify({ status: "busy", message: `Lease lock for '${leaseId}' is active or held by another worker instance` }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }

  console.log(`[Worker] Lease Lock obtido para lease=${leaseId}. Iniciando processamento BotConversa First. Instance: ${instanceId}`)

  const renewLease = async (): Promise<boolean> => {
    try {
      const { data: renewed, error } = await supabase.rpc("acquire_worker_lease", {
        p_instance_id: instanceId,
        p_lease_duration_sec: 120,
        p_lease_id: leaseId
      })
      if (error || !renewed) {
        console.error(`[Lease] Falha ao renovar lease lock para instance=${instanceId} lease=${leaseId}:`, error || "Lock expirou ou foi tomado por outra instancia.")
        return false
      }
      return true
    } catch (err) {
      console.error(`[Lease] Excecao ao renovar lease:`, err)
      return false
    }
  };

  try {
    // 2. O auto-recovery atômico e seguro é executado de forma transacional e protegida
    // diretamente dentro da RPC public.claim_single_whatsapp_message, evitando colisões 23505.

    // 3. Processing Loop (Unitary claim-send-commit)
    while (true) {
      // 3a. Renew Lease Lock before claiming
      const leaseOkBefore = await renewLease()
      if (!leaseOkBefore) {
        console.log("[Worker] Nao foi possivel renovar o Lease Lock. Finalizando loop.")
        break
      }

      // 3b. Read runtime configuration
      const { data: runtime, error: runtimeErr } = await supabase
        .from("whatsapp_runtime")
        .select("operational_mode, circuit_state")
        .eq("id", "singleton")
        .single()

      if (runtimeErr || !runtime) {
        console.error("[Worker] Erro ao carregar whatsapp_runtime:", runtimeErr)
        break
      }

      if (runtime.operational_mode === "DISABLED") {
        console.log("[Worker] Desativado via operational_mode = DISABLED. Interrompendo loop.")
        break
      }

      // 3c. Claim exactly ONE message within priority group
      const { data: claimedArray, error: claimErr } = await supabase.rpc("claim_single_whatsapp_message", {
        p_min_priority: minPriority,
        p_max_priority: maxPriority
      })
      if (claimErr) {
        console.error("[Worker] Erro ao reivindicar mensagem:", claimErr)
        break
      }

      const msg = claimedArray && claimedArray[0]
      if (!msg) {
        console.log("[Worker] Fila vazia. Nenhuma mensagem pendente encontrada.")
        break
      }

      const startAttemptStr = new Date().toISOString()
      console.log(`[Worker] Processando mensagem id=${msg.id}, telefone=${msg.recipient_phone}, prioridade=${msg.priority}, tipo=${msg.message_type || "TEXTO_LIVRE"}, status_claimed=${msg.status}`)

      // 3c-1. Verificação de Deadline Absoluto (TTL / Anti-Backlog)
      const nowMs = Date.now()
      if (msg.expires_at && new Date(msg.expires_at).getTime() <= nowMs) {
        console.warn(`[Worker TTL] Mensagem id=${msg.id} expirou antes do envio (expires_at=${msg.expires_at}). Descartando com status=expired.`)
        await supabase
          .from("whatsapp_outbox")
          .update({
            status: "expired",
            expired_at: new Date().toISOString(),
            expiration_reason: "TTL_EXCEEDED_BEFORE_DISPATCH",
            updated_at: new Date().toISOString()
          })
          .eq("id", msg.id)
        continue
      }

      const isDirectMetaClaim = msg.status === "sending_meta"
      let resolvedSubscriberId = msg.message_content?.botconversaId || null
      let primaryResult: CallResult = { success: false, isPermanent: false }
      let sentSuccessfully = false
      let finalProviderUsed = isDirectMetaClaim ? "META_CLOUD_API" : "BOTCONVERSA"
      let fallbackTriggered = isDirectMetaClaim
      let fallbackReason: string | null = isDirectMetaClaim ? (msg.fallback_reason || "BC_DISPATCHED_NO_CONFIRMATION") : null
      let primaryError: string | null = null
      let enterDispatchedGuard = false
      let fallbackAfterStr: string | null = null

      // 3d. Routing Resolution: WARMUP_MODE (99% Meta / 1% BotConversa) vs BotConversa First vs Evolution WELCOME Pilot
      let selectedProvider: "META" | "BOTCONVERSA" | "EVOLUTION" = "BOTCONVERSA"

      if (!isDirectMetaClaim) {
        let warmupMode = false
        let canSendWarmup = false

        try {
          const { data: warmupCheck, error: warmupErr } = await supabase.rpc("check_and_increment_warmup_cap", {
            p_instance_id: "singleton"
          })
          if (!warmupErr && warmupCheck) {
            warmupMode = !!warmupCheck.warmup_mode
            canSendWarmup = !!warmupCheck.can_send_warmup
          }
        } catch (wErr: any) {
          console.error("[Worker Warmup] Erro ao checar warmup cap:", wErr.message)
        }

        // Checar status da Evolution caso o piloto esteja ativo
        let isEvolutionConnected = true
        if (EVOLUTION_WELCOME_PILOT_ENABLED) {
          try {
            const { data: evoHealth } = await supabase
              .from("whatsapp_health_status")
              .select("evolution_connection_status")
              .eq("id", "singleton")
              .maybeSingle()
            if (evoHealth?.evolution_connection_status === "disconnected") {
              isEvolutionConnected = false
            }
          } catch (_) {}
        }

        const routeResult = calculateWarmupRoute({
          messageId: msg.id,
          perfilId: msg.perfil_id,
          messageType: msg.message_type,
          warmupMode,
          canSendWarmup,
          welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
          welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE,
          evolutionConnected: isEvolutionConnected
        })

        selectedProvider = routeResult.provider
        console.log(`[Worker Router] Rota calculada para msg id=${msg.id}: ${selectedProvider} (partição=${routeResult.partition}, motivo=${routeResult.reason})`)
      } else {
        selectedProvider = "META"
      }

      // 3e-EVOLUTION. EXECUÇÃO ROTA EVOLUTION API (FASE 4.20.7 — Exclusivo para MessageType.WELCOME no escopo do piloto)
      if (selectedProvider === "EVOLUTION" && !isDirectMetaClaim) {
        let textVal = msg.message_content?.value || ""
        const tpl = msg.message_content?.template
        if (tpl?.name && Array.isArray(tpl.parameters) && tpl.parameters.length > 0) {
          try {
            const { data: templateRow } = await supabase
              .from("whatsapp_meta_templates")
              .select("definition_payload")
              .eq("name", tpl.name)
              .eq("language", tpl.language || "pt_BR")
              .maybeSingle()

            if (templateRow?.definition_payload) {
              const renderRes = renderTemplateText(templateRow.definition_payload, tpl.parameters)
              if (renderRes.success && renderRes.text) {
                textVal = renderRes.text
              }
            }
          } catch (renderErr: any) {
            console.error("[Worker] Erro ao renderizar template para Evolution:", renderErr.message)
          }
        }

        primaryResult = await sendViaEvolution(
          EVOLUTION_API_URL,
          EVOLUTION_API_KEY,
          EVOLUTION_INSTANCE,
          msg.recipient_phone,
          msg.payload_type || "text",
          textVal
        )

        if (primaryResult.success) {
          finalProviderUsed = "EVOLUTION"
          sentSuccessfully = true
          console.log(`[Worker] Requisição aceita com sucesso pela Evolution (HTTP 200/201) para id=${msg.id}, provider_message_id=${primaryResult.providerMessageId}.`)
        } else {
          primaryError = primaryResult.error || "Falha na Evolution API"
          console.warn(`[Worker Evolution Fail] Evolution falhou para msg id=${msg.id}: ${primaryError}`)
        }
      }

      // 3e. EXECUÇÃO ROTA BOTCONVERSA (Apenas se selecionado pelo router e não for claim direto Meta)
      if (selectedProvider === "BOTCONVERSA" && !isDirectMetaClaim) {
        // Check BotConversa connection status from whatsapp_health_status
        let isBotConversaDisconnected = false
        try {
          const { data: health } = await supabase
            .from("whatsapp_health_status")
            .select("whatsapp_connection_status")
            .eq("id", "singleton")
            .maybeSingle()

          if (health?.whatsapp_connection_status === "disconnected") {
            isBotConversaDisconnected = true
            console.warn(`[Worker] BotConversa reportado como DESCONECTADO em whatsapp_health_status.`)
          }
        } catch (healthErr: any) {
          console.error("[Worker] Erro ao checar whatsapp_health_status:", healthErr.message)
        }

        // ATTEMPT 1: BOTCONVERSA (PRIMARY) — Only if connected
        if (!isBotConversaDisconnected) {
          // Injeção de Falha Controlada Exclusiva para Testes Isolados de Fallback
          if (msg.message_content?.simulate_botconversa_fail) {
            console.warn(`[Worker Simulation] Injeção de falha controlada (HTTP 503) exclusivamente para a mensagem id=${msg.id}`)
            primaryResult = {
              success: false,
              status: 503,
              error: "HTTP 503: Service Unavailable (Simulação Controlada de Falha Isolada)",
              isPermanent: false,
            }
          } else {
            // Enforce Global Rate Limiter (3 consecutive msgs -> 13-27s cooldown)
            let slotAllowed = false
            while (!slotAllowed) {
              const { data: slot, error: slotErr } = await supabase.rpc("acquire_botconversa_slot", {
                p_instance_id: instanceId
              })

              if (slotErr || !slot) {
                console.error("[Worker RateLimiter Fail-Closed] Erro ao invocar acquire_botconversa_slot:", slotErr || "Resposta nula do limiter")
                await new Promise((r) => setTimeout(r, 13000))
                await renewLease()
                continue
              }

              if (slot?.allowed) {
                slotAllowed = true
              } else {
                const waitMs = Math.min(Math.max(slot?.wait_ms || 13000, 500), 27000)
                console.log(`[Worker RateLimiter] BotConversa em cooldown global (${waitMs}ms restante). Aguardando...`)
                await new Promise((r) => setTimeout(r, waitMs))
                await renewLease()
              }
            }

            // 3e-1. Resolve subscriber if not already cached
            if (!resolvedSubscriberId) {
              console.log(`[Worker] Resolvendo subscriber ID no BotConversa para telefone=${msg.recipient_phone}`)
              const resolveRes = await resolveSubscriber(
                BOTCONVERSA_API_KEY,
                msg.recipient_phone,
                msg.message_content?.firstName || "Morador"
              )

              if (resolveRes.success) {
                resolvedSubscriberId = resolveRes.subscriberId
                console.log(`[Worker] Telefone resolvido para subscriberId=${resolvedSubscriberId}. Atualizando perfil...`)

                if (msg.perfil_id) {
                  try {
                    await supabase
                      .from("perfil")
                      .update({ botconversa_id: resolvedSubscriberId })
                      .eq("id", msg.perfil_id)
                  } catch (_) {}
                }
              } else {
                primaryResult = resolveRes
              }
            }

            // 3e-2. Send message via BotConversa if subscriber resolved
            if (resolvedSubscriberId) {
              let finalTextValue = msg.message_content?.value || ""
              const tpl = msg.message_content?.template

              if (tpl?.name && Array.isArray(tpl.parameters) && tpl.parameters.length > 0) {
                try {
                  const { data: templateRow } = await supabase
                    .from("whatsapp_meta_templates")
                    .select("definition_payload")
                    .eq("name", tpl.name)
                    .eq("language", tpl.language || "pt_BR")
                    .maybeSingle()

                  if (templateRow?.definition_payload) {
                    const renderRes = renderTemplateText(templateRow.definition_payload, tpl.parameters)
                    if (renderRes.success && renderRes.text) {
                      finalTextValue = renderRes.text
                    }
                  }
                } catch (renderErr: any) {
                  console.error("[Worker] Erro ao renderizar template para BotConversa:", renderErr.message)
                }
              }

              primaryResult = await sendMessageToBotConversa(
                BOTCONVERSA_API_KEY,
                resolvedSubscriberId,
                msg.payload_type || "text",
                finalTextValue
              )
            }

            // 3e-3. If BotConversa returned HTTP 200 (Accepted)
            if (primaryResult.success) {
              finalProviderUsed = "BOTCONVERSA"
              console.log(`[Worker] Requisição aceita com sucesso pelo BotConversa (HTTP 200) para id=${msg.id}.`)

              try {
                await supabase.rpc("confirm_botconversa_sent", { p_instance_id: instanceId })
              } catch (confirmErr) {
                console.error("[Worker RateLimiter] Erro ao confirmar envio BotConversa:", confirmErr)
              }

              // Calcular Janela de Guarda por MessageType (FASE 4.17 / FASE 4.19)
              const fallbackWindowSec = getMessageFallbackWindow(msg.message_type)

              if (fallbackWindowSec === 0 || msg.message_type === "DUAL_NUMBER_NOTICE" || msg.message_type === "WELCOME" || msg.message_type === "NOTICE") {
                // Caso específico sem janela de fallback (ex.: DUAL_NUMBER_NOTICE, WELCOME e NOTICE onde Meta é estritamente proibido sem template)
                sentSuccessfully = true
                if (msg.message_type === "DUAL_NUMBER_NOTICE") {
                  try {
                    await supabase
                      .from("whatsapp_dual_number_notices")
                      .update({
                        status: "sent",
                        sent_at: new Date().toISOString(),
                        updated_at: new Date().toISOString()
                      })
                      .eq("recipient_phone", msg.recipient_phone)
                  } catch (dualSentErr: any) {
                    console.error("[Worker] Erro ao atualizar status do DUAL_NUMBER_NOTICE:", dualSentErr.message)
                  }
                }
              } else {
                // Entra em Estado de Guarda 'dispatched_bc'
                enterDispatchedGuard = true
                fallbackAfterStr = new Date(Date.now() + fallbackWindowSec * 1000).toISOString()
                console.log(`[Worker FASE 4.18] Mensagem id=${msg.id} entra em guarda 'dispatched_bc' (${fallbackWindowSec}s até ${fallbackAfterStr}).`)
              }

              // Disparo do gatilho pós-primeiro envio real: Enfileira DUAL_NUMBER_NOTICE se for primeira vez
              if (msg.message_type !== "DUAL_NUMBER_NOTICE") {
                try {
                  const { data: enqueueRes, error: enqueueErr } = await supabase.rpc("enqueue_dual_number_notice_if_needed", {
                    p_recipient_phone: msg.recipient_phone,
                    p_perfil_id: msg.perfil_id || null,
                    p_condominio_id: msg.condominio_id || null,
                    p_trigger_outbox_id: msg.id
                  })
                  if (enqueueErr) {
                    console.error("[Worker DualNumberNotice] Erro ao invocar enqueue_dual_number_notice_if_needed:", enqueueErr)
                  } else if (enqueueRes?.enqueued) {
                    console.log(`[Worker DualNumberNotice] DUAL_NUMBER_NOTICE enfileirado para telefone=${msg.recipient_phone} (outbox_id=${enqueueRes.outbox_id}, delay=${enqueueRes.delay_sec}s).`)
                  }
                } catch (dualErr: any) {
                  console.error("[Worker DualNumberNotice] Excecao ao enfileirar aviso:", dualErr.message)
                }
              }
            } else {
              primaryError = primaryResult.error || "Falha desconhecida no BotConversa"
              console.warn(`[Worker Primary Fail] BotConversa falhou para msg id=${msg.id}: ${primaryError}`)
            }
          }
        } else {
          primaryError = "BotConversa desconectado em whatsapp_health_status"
        }
      }

      // 3f. EXECUÇÃO ROTA META CLOUD API (PRIMARY OU CONTINGÊNCIA)
      // Acionado se:
      // a) Router selecionou META como Primary (WARMUP_MODE 90% ou teto diário atingido)
      // b) Claim direto de reconciliação (isDirectMetaClaim = true, guard window estourou)
      // c) Falha explícita no BotConversa (HTTP 4xx/5xx, timeout, desconectado) e não está em dispatched_guard
      const isMetaFallbackForbidden = msg.message_type === "DUAL_NUMBER_NOTICE" || msg.message_type === "WELCOME" || msg.message_type === "NOTICE" || msg.message_content?.allow_meta_fallback === false

      if (!sentSuccessfully && !enterDispatchedGuard) {
        if (isMetaFallbackForbidden) {
          console.warn(`[Worker Fallback] Fallback Meta BLOQUEADO para message_type=${msg.message_type || "DESCONHECIDO"}. Mensagem sera mantida em retry exclusivo no BotConversa.`)
        } else {
          if (selectedProvider === "BOTCONVERSA") {
            fallbackTriggered = true
            if (!fallbackReason) {
              const isTimeout = primaryResult.status === 408
              const is503 = primaryResult.status === 503
              fallbackReason = isDirectMetaClaim
                ? "BC_DISPATCHED_NO_CONFIRMATION"
                : (primaryError?.includes("desconectado")
                  ? "BOTCONVERSA_DISCONNECTED"
                  : (isTimeout ? "BOTCONVERSA_TIMEOUT_AMBIGUOUS_30S" : (is503 ? "BOTCONVERSA_HTTP_503" : `BOTCONVERSA_ERROR: ${primaryError}`)))
            }
            console.warn(`[Worker Fallback] Acionando contingência META_CLOUD_API para msg id=${msg.id}. Motivo: ${fallbackReason}`)
          } else {
            console.log(`[Worker Meta Primary] Disparando diretamente via META_CLOUD_API para msg id=${msg.id} (Rota 99% / Warmup)`)
          }

          if (!metaCredentialsAvailable) {
            console.error(`[Worker Fallback] Meta Cloud API credentials indisponiveis. Nao foi possivel acionar envio Meta.`)
          } else {
            finalProviderUsed = "META_CLOUD_API"

            // Prepare Meta Template / Contract Components
            let finalTemplateName: string | undefined = undefined
            let finalTemplateLanguage: string | undefined = undefined
            let finalTemplateComponents: any[] | undefined = undefined

            const textBody = msg.message_content?.value || ""

            // Check if structured contract exists
            if (msg.message_content?.template?.name && Array.isArray(msg.message_content.template.parameters)) {
              finalTemplateName = msg.message_content.template.name
              finalTemplateLanguage = msg.message_content.template.language || "pt_BR"
              finalTemplateComponents = [
                {
                  type: "body",
                  parameters: msg.message_content.template.parameters.map((p: any) => ({
                    type: "text",
                    text: String(p ?? "—").trim()
                  }))
                }
              ]

              // Authentication / OTP template button url parameter
              if (msg.message_type === "OTP" || finalTemplateName === "condomeet_recuperacao_senha_v1") {
                const otpCode = String(msg.message_content.template.parameters[0] ?? "").trim()
                finalTemplateComponents.push({
                  type: "button",
                  sub_type: "url",
                  index: "0",
                  parameters: [{ type: "text", text: otpCode }]
                })
              }
            }

            // Validate template approved status
            let isTemplateApproved = true
            let unapprovedReason = ""
            if (finalTemplateName) {
              try {
                const { data: tplCheck } = await supabase
                  .from("whatsapp_meta_templates")
                  .select("status")
                  .eq("name", finalTemplateName)
                  .eq("language", finalTemplateLanguage || "pt_BR")
                  .maybeSingle()

                if (tplCheck && tplCheck.status !== "APPROVED") {
                  isTemplateApproved = false
                  unapprovedReason = `Template '${finalTemplateName}' status local: ${tplCheck.status}.`
                }
              } catch (_) {}
            }

            // Injeção de Falha Controlada Exclusiva para Testes Isolados da Meta
            if (msg.message_content?.simulate_meta_fail) {
              console.warn(`[Worker Simulation] Injeção de falha controlada Meta para msg id=${msg.id}`)
              const simStatus = msg.message_content.simulate_meta_fail.status || 500
              const simError = msg.message_content.simulate_meta_fail.error || "Simulated Meta Error"
              const simPermanent = simStatus >= 400 && simStatus < 500 && simStatus !== 408 && simStatus !== 429
              primaryResult = {
                success: false,
                status: simStatus,
                error: simError,
                isPermanent: simPermanent
              }
            } else {
              // Policy check before dispatch
              const outboxPolicyCheck = validateWhatsAppSendPolicy({
                callerFunction: "whatsapp-outbox-worker",
                messageType: msg.message_type,
                templateName: finalTemplateName,
                textValue: textBody,
                isCampaign: msg.priority === 0
              })

              if (!outboxPolicyCheck.allowed) {
                primaryResult = {
                  success: false,
                  isPermanent: true,
                  status: 400,
                  error: `Policy Blocked: ${outboxPolicyCheck.reason}`
                }
              } else if (!isTemplateApproved && finalTemplateName) {
                primaryResult = {
                  success: false,
                  isPermanent: true,
                  status: 400,
                  error: `Meta Template Not Approved: ${unapprovedReason}`
                }
              } else {
                const metaResult = await sendViaMetaCloudAPI(
                  META_ACCESS_TOKEN!,
                  META_PHONE_NUMBER_ID!,
                  msg.recipient_phone,
                  msg.payload_type || "text",
                  msg.message_content?.value,
                  finalTemplateName,
                  finalTemplateLanguage,
                  finalTemplateComponents
                )

                if (metaResult.success) {
                  sentSuccessfully = true
                  primaryResult = metaResult
                  console.log(`[Worker] Mensagem id=${msg.id} enviada com SUCESSO via META_CLOUD_API.`)
                } else {
                  primaryResult = metaResult
                  console.error(`[Worker] Falha no envio Meta para msg id=${msg.id}: ${metaResult.error}`)
                }
              }
            }
          }
        }
      }


      // 3g. Update Outbox Record and Delivery Result (JSONB)
      const nowStr = new Date().toISOString()
      let providerMessageId: string | null = null
      if (finalProviderUsed === "META_CLOUD_API" && primaryResult.success && primaryResult.body) {
        try {
          const parsed = JSON.parse(primaryResult.body)
          if (parsed?.messages?.[0]?.id) {
            providerMessageId = parsed.messages[0].id
          }
        } catch (_) {}
      } else if (finalProviderUsed === "EVOLUTION" && primaryResult.success) {
        providerMessageId = primaryResult.providerMessageId || null
      }

      const deliveryResultPayload: Record<string, any> = {
        provider: finalProviderUsed,
        status_code: primaryResult.status || (sentSuccessfully ? 200 : null),
        response: primaryResult.body || null,
        error_message: primaryResult.error || null,
        is_permanent_error: primaryResult.isPermanent,
        resolved_subscriber_id: resolvedSubscriberId,
        provider_message_id: providerMessageId,
      }

      if (fallbackTriggered) {
        deliveryResultPayload.fallback_triggered = true
        deliveryResultPayload.fallback_reason = fallbackReason
        deliveryResultPayload.primary_attempt_provider = "BOTCONVERSA"
        deliveryResultPayload.primary_error = primaryError || (primaryResult.status === 503 ? "HTTP 503: Service Unavailable (Simulação Controlada de Falha Isolada)" : null)
        deliveryResultPayload.primary_attempt_at = startAttemptStr
        if (sentSuccessfully) {
          deliveryResultPayload.meta_sent_at = nowStr
        }
      }

      // 3h. Process Final State Transition
      if (enterDispatchedGuard) {
        // Mensagem aceita pelo BotConversa -> Transição para 'dispatched_bc' com Janela de Guarda
        await supabase
          .from("whatsapp_outbox")
          .update({
            status: "dispatched_bc",
            dispatched_at: nowStr,
            fallback_after: fallbackAfterStr,
            provider_attempt: "BOTCONVERSA",
            last_attempt_at: nowStr,
            delivery_result: deliveryResultPayload,
            updated_at: nowStr
          })
          .eq("id", msg.id)
      } else if (sentSuccessfully) {
        // Envio definitivo concluído (via Meta Cloud API ou BotConversa sem janela)
        await supabase
          .from("whatsapp_outbox")
          .update({
            status: "sent",
            sent_at: nowStr,
            last_attempt_at: nowStr,
            provider_attempt: finalProviderUsed,
            fallback_reason: fallbackReason,
            delivery_result: deliveryResultPayload,
            updated_at: nowStr
          })
          .eq("id", msg.id)
      } else {
        // Falha no envio
        if (primaryResult.isPermanent) {
          console.error(`[Worker] Erro permanente na mensagem id=${msg.id}. Movendo para Dead Letter (failed).`)
          await supabase
            .from("whatsapp_outbox")
            .update({
              status: "failed",
              last_attempt_at: nowStr,
              provider_attempt: finalProviderUsed,
              fallback_reason: fallbackReason,
              error_message: `Falha Permanente (${finalProviderUsed}): ${primaryResult.error}`,
              delivery_result: deliveryResultPayload,
              updated_at: nowStr
            })
            .eq("id", msg.id)
        } else {
          const shouldRetry = msg.retry_count < msg.max_retries
          const nextAttempt = shouldRetry
            ? new Date(Date.now() + Math.pow(2, msg.retry_count) * 60 * 1000).toISOString()
            : null

          console.log(`[Worker] Erro temporario (${finalProviderUsed}). Tentativas: ${msg.retry_count + 1}/${msg.max_retries}. Reagendado? ${shouldRetry}`)

          await supabase
            .from("whatsapp_outbox")
            .update({
              status: shouldRetry ? "pending" : "failed",
              retry_count: msg.retry_count + 1,
              next_attempt_at: nextAttempt,
              last_attempt_at: nowStr,
              provider_attempt: finalProviderUsed,
              fallback_reason: fallbackReason,
              error_message: `Falha Temporaria (${finalProviderUsed}): ${primaryResult.error}`,
              delivery_result: deliveryResultPayload,
              updated_at: nowStr
            })
            .eq("id", msg.id)
        }
      }

      // 3i. Renew lease after cycle
      const leaseOkAfter = await renewLease()
      if (!leaseOkAfter) {
        console.log("[Worker] Nao foi possivel renovar o Lease Lock apos ciclo. Finalizando loop.")
        break
      }

      // 3j. Pacing delay between iterations
      // FASE 7.14.2: Distinção estrita entre WELCOME ATRASADO (Backlog) e NOVO WELCOME
      if (msg.message_type === "WELCOME") {
        const msgAgeMs = Date.now() - new Date(msg.created_at).getTime()
        const isBacklogDelayed = msgAgeMs >= 15 * 60 * 1000 // 15 minutos ou mais de atraso na fila

        if (isBacklogDelayed) {
          const backlogPacingMs = 300000 // 5 minutos = 300.000 ms para WELCOME atrasado
          console.log(`[Worker Pacing] Mensagem WELCOME ATRASADA processada (id=${msg.id}, idade=${Math.round(msgAgeMs / 60000)}min). Aplicando intervalo conservador de 5 minutos (300s) antes do próximo envio do backlog...`)
          let elapsed = 0
          while (elapsed < backlogPacingMs) {
            const waitTime = Math.min(15000, backlogPacingMs - elapsed)
            await new Promise((r) => setTimeout(r, waitTime))
            elapsed += waitTime
            const renewed = await renewLease()
            if (!renewed) {
              console.warn(`[Worker Pacing] Perda de lease durante a espera de 5 minutos da mensagem id=${msg.id}.`)
              break
            }
          }
        } else {
          // NOVO WELCOME (criado recentemente < 15 min): pacing padrão da fila para entrega oportuna
          console.log(`[Worker Pacing] NOVO WELCOME processado (id=${msg.id}, idade=${Math.round(msgAgeMs / 1000)}s). Aplicando pacing operacional padrão (1.8s).`)
          const pacingMs = queueType === "high" ? 1000 : 1800
          await new Promise((r) => setTimeout(r, pacingMs))
        }
      } else {
        // Demais MessageTypes (PARCEL, VISITOR_INVITE, NOTICE, etc.): pacing padrão inalterado
        const pacingMs = queueType === "high" ? 1000 : 1800
        await new Promise((r) => setTimeout(r, pacingMs))
      }
    }
  } catch (err: any) {
    console.error("[Worker] Erro catastrófico de execução:", err)
  } finally {
    // Release Lease Lock
    try {
      const { data: released } = await supabase.rpc("release_worker_lease", { p_instance_id: instanceId, p_lease_id: leaseId })
      console.log(`[Worker] Execucao finalizada. Lease lock liberado para lease=${leaseId}? ${released}. Instance: ${instanceId}`)
    } catch (err) {
      console.error("[Worker] Erro ao liberar lease lock no finally:", err)
    }
  }

  return new Response(JSON.stringify({ status: "done" }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
})
