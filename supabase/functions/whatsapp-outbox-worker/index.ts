import { createClient } from "npm:@supabase/supabase-js@2"
import { renderTemplateText } from "../_shared/template_renderer.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

const BOTCONVERSA_BASE_URL = "https://backend.botconversa.com.br/api/v1/webhook"
const META_API_BASE_URL = "https://graph.facebook.com/v21.0"
const PROVIDER_DWELL_TIME_MS = 15 * 60 * 1000 // 15 minutes minimum on fallback provider

interface CallResult {
  success: boolean
  status?: number
  body?: string
  error?: string
  isPermanent: boolean
  subscriberId?: string
}

interface MessageProviderRuntime {
  active_provider: string
  fallback_provider: string
  botconversa_enabled: boolean
  cloud_api_enabled: boolean
  automatic_failover_enabled: boolean
  last_provider_change_at: string
  last_provider_change_reason: string | null
  manual_override: boolean
  manual_provider: string | null
}

interface ProviderDecision {
  provider: "BOTCONVERSA" | "META_CLOUD_API"
  reason: string
}

// Helper to make fetch calls with strict 30s timeout and AbortController
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
  })

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
async function sendMessage(
  apiKey: string,
  subscriberId: string,
  type: string,
  value: string
): Promise<CallResult> {
  const url = `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_message/`
  
  // Rewrite PNG to JPEG if needed, parse JSON for interactive buttons
  let finalValue: any = value
  if (type === "file" && typeof value === "string" && value.toLowerCase().endsWith(".png")) {
    finalValue = value.replace(/\.png$/i, ".jpeg")
  } else if (type === "interactive" && typeof value === "string") {
    try {
      finalValue = JSON.parse(value)
    } catch (_) {}
  }

  const res = await fetchWithTimeout(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "API-KEY": apiKey,
    },
    body: JSON.stringify({ type, value: finalValue }),
  })

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
      // Default to document for unknown file types
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
  })

  if (res.timedOut) {
    return { success: false, status: 408, error: "Network Timeout (30s) no envio via Meta Cloud API", isPermanent: false }
  }

  if (!res.ok) {
    const isPermanent = res.status >= 400 && res.status < 500 && res.status !== 408 && res.status !== 429
    return { success: false, status: res.status, body: res.text, error: `Meta API HTTP ${res.status}: ${res.text}`, isPermanent }
  }

  return { success: true, status: res.status, body: res.text, isPermanent: false }
}

// Determines which provider should handle the current message
function resolveProvider(
  providerRuntime: MessageProviderRuntime,
  metaCredentialsAvailable: boolean
): ProviderDecision {
  // Priority 1: Manual override (operator control)
  if (providerRuntime.manual_override && providerRuntime.manual_provider) {
    const provider = providerRuntime.manual_provider as "BOTCONVERSA" | "META_CLOUD_API"
    if (provider === "META_CLOUD_API" && !metaCredentialsAvailable) {
      console.warn("[Provider] Manual override para META_CLOUD_API mas credentials ausentes. Fallback para BOTCONVERSA.")
      return { provider: "BOTCONVERSA", reason: "manual_override=META mas credentials Meta ausentes" }
    }
    return { provider, reason: `manual_override=${provider}` }
  }

  // Priority 2: Automatic failover disabled — use active_provider from table (default config)
  if (!providerRuntime.automatic_failover_enabled) {
    const activeProvider = providerRuntime.active_provider as "BOTCONVERSA" | "META_CLOUD_API"
    if (activeProvider === "META_CLOUD_API" && !metaCredentialsAvailable) {
      return { provider: "BOTCONVERSA", reason: "active_provider=META mas credentials Meta ausentes (failover desativado)" }
    }
    return { provider: activeProvider, reason: "automatic_failover_enabled=false" }
  }

  // Priority 3: Automatic failover enabled — use active_provider from table
  const activeProvider = providerRuntime.active_provider as "BOTCONVERSA" | "META_CLOUD_API"
  if (activeProvider === "META_CLOUD_API" && !metaCredentialsAvailable) {
    console.warn("[Provider] active_provider=META_CLOUD_API mas credentials ausentes. Fallback para BOTCONVERSA.")
    return { provider: "BOTCONVERSA", reason: "active_provider=META mas credentials Meta ausentes" }
  }

  return { provider: activeProvider, reason: `active_provider=${activeProvider}` }
}

// Evaluates whether a provider failover should occur after a send failure
async function evaluateFailover(
  supabase: any,
  runtime: any,
  providerRuntime: MessageProviderRuntime,
  failureResult: CallResult,
  currentProvider: string
): Promise<{ breakLoop: boolean }> {
  const nowStr = new Date().toISOString()
  const newFailures = runtime.consecutive_failures + 1
  const thresholdReached = newFailures >= runtime.failure_threshold

  if (!thresholdReached) {
    // Below threshold — just increment failures
    await supabase
      .from("whatsapp_runtime")
      .update({
        consecutive_failures: newFailures,
        last_failure_at: nowStr,
        last_reason: `${currentProvider}: ${failureResult.error}`,
      })
      .eq("id", "singleton")
    return { breakLoop: false }
  }

  // Threshold reached
  if (!providerRuntime.automatic_failover_enabled) {
    // Failover disabled — open Circuit Breaker and pause (original behavior)
    console.error(`[Failover] Threshold atingido (${newFailures}/${runtime.failure_threshold}). Failover desabilitado. Abrindo Circuit Breaker.`)
    await supabase
      .from("whatsapp_runtime")
      .update({
        consecutive_failures: newFailures,
        circuit_state: "OPEN",
        last_failure_at: nowStr,
        last_reason: `${currentProvider}: ${failureResult.error}`,
        state_changed_at: nowStr,
      })
      .eq("id", "singleton")

    // Audit: blocked failover
    try {
      await supabase.from("botconversa_monitoring").insert({
        action_type: "PROVIDER_FAILOVER_BLOCKED",
        recipient_phone: "system",
        error_message: `Threshold atingido (${newFailures} falhas). automatic_failover_enabled=false. Circuit Breaker OPEN.`,
        function_name: "whatsapp-outbox-worker",
        delivery_status: "PROVIDER_FAILOVER_BLOCKED"
      })
    } catch (_) {}

    return { breakLoop: true }
  }

  // Failover enabled — swap provider
  const newProvider = providerRuntime.fallback_provider
  console.warn(`[Failover] Threshold atingido (${newFailures}/${runtime.failure_threshold}). FAILOVER: ${currentProvider} → ${newProvider}`)

  // Update provider routing
  await supabase
    .from("message_provider_runtime")
    .update({
      active_provider: newProvider,
      last_provider_change_at: nowStr,
      last_provider_change_reason: `Auto-failover: ${newFailures} falhas consecutivas em ${currentProvider}. Erro: ${failureResult.error}`,
    })
    .eq("id", "singleton")

  // Reset circuit breaker and failures for the new provider
  await supabase
    .from("whatsapp_runtime")
    .update({
      consecutive_failures: 0,
      circuit_state: "CLOSED",
      last_failure_at: nowStr,
      last_reason: `Failover: ${currentProvider} → ${newProvider}`,
      state_changed_at: nowStr,
    })
    .eq("id", "singleton")

  // Audit: provider failover
  try {
    await supabase.from("botconversa_monitoring").insert({
      action_type: "PROVIDER_FAILOVER",
      recipient_phone: "system",
      error_message: `FAILOVER: ${currentProvider} → ${newProvider}. Motivo: ${newFailures} falhas consecutivas. Ultimo erro: ${failureResult.error}`,
      function_name: "whatsapp-outbox-worker",
      delivery_status: "PROVIDER_FAILOVER"
    })
  } catch (_) {}

  return { breakLoop: false } // Continue processing via new provider
}

// Evaluates whether recovery to primary provider should occur after a successful send
async function evaluateRecovery(
  supabase: any,
  runtime: any,
  providerRuntime: MessageProviderRuntime,
  currentProvider: string
): Promise<void> {
  const nowStr = new Date().toISOString()

  // Se o provedor que enviou com sucesso não for o fallback (ou seja, é o primário), apenas resetamos falhas
  if (currentProvider !== providerRuntime.fallback_provider) {
    if (runtime.circuit_state !== "CLOSED" || runtime.consecutive_failures > 0) {
      await supabase
        .from("whatsapp_runtime")
        .update({
          circuit_state: "CLOSED",
          consecutive_failures: 0,
          state_changed_at: nowStr,
        })
        .eq("id", "singleton")
    }
    return
  }

  // Estamos no fallback_provider (em contingência) — avaliar retorno ao primário (o oposto do fallback)
  if (runtime.consecutive_failures > 0) {
    await supabase
      .from("whatsapp_runtime")
      .update({
        consecutive_failures: 0,
        state_changed_at: nowStr,
      })
      .eq("id", "singleton")
  }

  // Gate 1: Dwell time — mínimo 15 minutos no fallback provider
  const timeSinceFailover = Date.now() - new Date(providerRuntime.last_provider_change_at).getTime()
  if (timeSinceFailover < PROVIDER_DWELL_TIME_MS) {
    const remainingMin = Math.round((PROVIDER_DWELL_TIME_MS - timeSinceFailover) / 60000)
    console.log(`[Recovery] Dwell time ativo. ${remainingMin}min restantes antes de tentar retorno ao provedor primário.`)
    return
  }

  const primaryProvider = providerRuntime.fallback_provider === "BOTCONVERSA" ? "META_CLOUD_API" : "BOTCONVERSA"

  // Gate 2: Saúde do primário (só se o primário for BOTCONVERSA, pois a Meta Cloud API é baseada em nuvem e não tem celular desconectado)
  if (primaryProvider === "BOTCONVERSA") {
    const { data: health } = await supabase
      .from("whatsapp_health_status")
      .select("whatsapp_connection_status")
      .eq("id", "singleton")
      .single()

    const connectionStatus = health?.whatsapp_connection_status || "unknown"
    if (connectionStatus !== "connected") {
      console.log(`[Recovery] BotConversa (provedor primário) ainda desconectado (status: ${connectionStatus}). Mantendo fallback.`)
      return
    }
  }

  // Gate 3: Circuit breaker must not be OPEN
  const { data: currentRuntime } = await supabase
    .from("whatsapp_runtime")
    .select("circuit_state")
    .eq("id", "singleton")
    .single()

  if (currentRuntime?.circuit_state === "OPEN") {
    console.log("[Recovery] Circuit breaker ainda OPEN. Mantendo fallback.")
    return
  }

  // All gates passed — recover to primary provider
  console.log(`[Recovery] Todos os gates passaram. RECOVERY: ${currentProvider} → ${primaryProvider}`)

  await supabase
    .from("message_provider_runtime")
    .update({
      active_provider: primaryProvider,
      last_provider_change_at: nowStr,
      last_provider_change_reason: `Auto-recovery: ${primaryProvider} saudavel após dwell time de ${Math.round(PROVIDER_DWELL_TIME_MS / 60000)}min`,
    })
    .eq("id", "singleton")

  // Audit: provider recovery
  try {
    await supabase.from("botconversa_monitoring").insert({
      action_type: "PROVIDER_RECOVERY",
      recipient_phone: "system",
      error_message: `RECOVERY: ${currentProvider} → ${primaryProvider}. Provedor primário saudável após dwell time.`,
      function_name: "whatsapp-outbox-worker",
      delivery_status: "PROVIDER_RECOVERY"
    })
  } catch (_) {}
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

  // Meta Cloud API credentials (optional — failover disabled if absent)
  const META_ACCESS_TOKEN = Deno.env.get("WHATSAPP_ACCESS_TOKEN") || null
  const META_PHONE_NUMBER_ID = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") || null
  const metaCredentialsAvailable = !!META_ACCESS_TOKEN && !!META_PHONE_NUMBER_ID

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

  console.log(`[Worker] Lease Lock obtido para lease=${leaseId}. Iniciando processamento. Instance: ${instanceId}`)

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
      console.log(`[Lease] Lease lock renovado com sucesso para instance=${instanceId} lease=${leaseId}`)
      return true
    } catch (err) {
      console.error(`[Lease] Excecao ao renovar lease:`, err)
      return false
    }
  };

  try {
    // 2.5 Carregar pilotos de rollout ativos do banco
    const pilotMap = new Map<string, string>()
    try {
      const { data: pilots } = await supabase
        .from("whatsapp_pilot_rollout")
        .select("condominio_id, current_stage")
        .eq("is_active", true)
      
      if (pilots) {
        for (const p of pilots) {
          pilotMap.set(p.condominio_id, p.current_stage)
        }
        console.log(`[Worker] Carregados ${pilotMap.size} pilotos de rollout ativos.`)
      }
    } catch (pilotErr: any) {
      console.error("[Worker] Erro ao carregar whatsapp_pilot_rollout:", pilotErr.message)
    }

    // 3. Auto-recover messages stuck in "sending" status for > 2 minutes
    const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000).toISOString()
    const { count: recoveredCount } = await supabase
      .from("whatsapp_outbox")
      .update({
        status: "pending",
        error_message: "Recuperado: expirou timeout de 2 minutos no status sending",
      })
      .eq("status", "sending")
      .lt("processing_started_at", twoMinutesAgo)

    if (recoveredCount && recoveredCount > 0) {
      console.log(`[Worker] Recuperadas ${recoveredCount} mensagens presas no status 'sending'.`)
    }

    // 4. Processing Loop (Unitary claim-send-commit)
    while (true) {
      // 4a-1. Renew Lease Lock before processing
      const leaseOkBefore = await renewLease()
      if (!leaseOkBefore) {
        console.log("[Worker] Nao foi possivel renovar o Lease Lock. Finalizando loop.")
        break
      }

      // 4a. Read configuration and operational limits
      const { data: runtime, error: runtimeErr } = await supabase
        .from("whatsapp_runtime")
        .select("*")
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

      // 4a-3. Read provider routing configuration
      const { data: providerRuntime, error: providerErr } = await supabase
        .from("message_provider_runtime")
        .select("*")
        .eq("id", "singleton")
        .single()

      if (providerErr || !providerRuntime) {
        console.error("[Worker] Erro ao carregar message_provider_runtime:", providerErr)
        break
      }

      // 4a-4. Resolve provider for current loop iteration
      let decision = resolveProvider(providerRuntime as MessageProviderRuntime, metaCredentialsAvailable)

      // 4a-2. Check BotConversa connection status (only relevant if BotConversa is the active provider)
      const isBotConversaActive = decision.provider === "BOTCONVERSA"
      let connectionStatus = "connected"

      if (isBotConversaActive) {
        const { data: health, error: healthErr } = await supabase
          .from("whatsapp_health_status")
          .select("whatsapp_connection_status")
          .eq("id", "singleton")
          .single()

        if (healthErr) {
          console.error("[Worker] Erro ao carregar whatsapp_health_status:", healthErr)
        }

        connectionStatus = health?.whatsapp_connection_status || "connected"
        
        if (connectionStatus !== "connected") {
          // Check if automatic failover can handle this
          if (providerRuntime.automatic_failover_enabled && metaCredentialsAvailable) {
            // Failover enabled — switch to Meta instead of pausing
            if (providerRuntime.active_provider !== "META_CLOUD_API") {
              console.warn(`[Worker] BotConversa desconectado (status: ${connectionStatus}). Failover para META_CLOUD_API.`)
              const nowFailover = new Date().toISOString()
              await supabase.from("message_provider_runtime").update({
                active_provider: "META_CLOUD_API",
                last_provider_change_at: nowFailover,
                last_provider_change_reason: `Auto-failover: BotConversa desconectado (status: ${connectionStatus})`
              }).eq("id", "singleton")

              // Reset circuit breaker for Meta
              await supabase.from("whatsapp_runtime").update({
                consecutive_failures: 0,
                circuit_state: "CLOSED",
                state_changed_at: nowFailover,
              }).eq("id", "singleton")

              // Audit failover
              try {
                await supabase.from("botconversa_monitoring").insert({
                  action_type: "PROVIDER_FAILOVER",
                  recipient_phone: "system",
                  error_message: `BotConversa desconectado (${connectionStatus}). FAILOVER: BOTCONVERSA → META_CLOUD_API.`,
                  function_name: "whatsapp-outbox-worker",
                  delivery_status: "PROVIDER_FAILOVER"
                })
              } catch (_) {}

              // Re-read provider runtime after update
              const { data: updatedProviderRuntime } = await supabase
                .from("message_provider_runtime")
                .select("*")
                .eq("id", "singleton")
                .single()
              if (updatedProviderRuntime) {
                Object.assign(providerRuntime, updatedProviderRuntime)
              }
            }
            // Continue processing via Meta (do NOT break)
          } else {
            // Failover disabled — pause queue (original behavior)
            console.warn(`[Worker] BotConversa WhatsApp esta desconectado (status: ${connectionStatus}). Pausando fila.`)

            // Log BOTCONVERSA_QUEUE_PAUSED if not already logged as paused in transition
            try {
              const { data: lastAction } = await supabase
                .from("botconversa_monitoring")
                .select("action_type")
                .in("action_type", ["BOTCONVERSA_QUEUE_PAUSED", "BOTCONVERSA_QUEUE_RESUMED"])
                .order("timestamp", { ascending: false })
                .limit(1)
                .maybeSingle()

              if (!lastAction || lastAction.action_type === "BOTCONVERSA_QUEUE_RESUMED") {
                await supabase.from("botconversa_monitoring").insert({
                  action_type: "BOTCONVERSA_QUEUE_PAUSED",
                  recipient_phone: "system",
                  error_message: `WhatsApp connection status is ${connectionStatus}`,
                  function_name: "whatsapp-outbox-worker",
                  delivery_status: "BOTCONVERSA_QUEUE_PAUSED"
                })
                console.log("[Worker] Logged BOTCONVERSA_QUEUE_PAUSED")
              }
            } catch (logErr) {
              console.error("[Worker] Failed to log queue paused:", logErr)
            }

            break
          }
        } else {
          // Log BOTCONVERSA_QUEUE_RESUMED if transitioning back
          try {
            const { data: lastAction } = await supabase
              .from("botconversa_monitoring")
              .select("action_type")
              .in("action_type", ["BOTCONVERSA_QUEUE_PAUSED", "BOTCONVERSA_QUEUE_RESUMED"])
              .order("timestamp", { ascending: false })
              .limit(1)
              .maybeSingle()

            if (lastAction && lastAction.action_type === "BOTCONVERSA_QUEUE_PAUSED") {
              await supabase.from("botconversa_monitoring").insert({
                action_type: "BOTCONVERSA_QUEUE_RESUMED",
                recipient_phone: "system",
                error_message: "WhatsApp connection status is connected",
                function_name: "whatsapp-outbox-worker",
                delivery_status: "BOTCONVERSA_QUEUE_RESUMED"
              })
              console.log("[Worker] Logged BOTCONVERSA_QUEUE_RESUMED")
            }
          } catch (logErr) {
            console.error("[Worker] Failed to log queue resumed:", logErr)
          }
        }
      }

      // 4b. Circuit Breaker Checks
      if (runtime.circuit_state === "OPEN") {
        const stateAgeMs = Date.now() - new Date(runtime.state_changed_at).getTime()
        const circuitCooldownMs = 5 * 60 * 1000 // 5 minutes cooldown

        if (stateAgeMs > circuitCooldownMs) {
          console.log("[Worker] Tempo limite do Circuit Breaker atingido. Mudando para HALF_OPEN.")
          await supabase
            .from("whatsapp_runtime")
            .update({
              circuit_state: "HALF_OPEN",
              state_changed_at: new Date().toISOString(),
            })
            .eq("id", "singleton")
        } else {
          console.log("[Worker] Circuit Breaker esta ABERTO. Fila suspensa.")
          break
        }
      }

      // 4c. Claim exactly ONE message within priority group
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

      console.log(`[Worker] Processando mensagem id=${msg.id}, telefone=${msg.recipient_phone}, prioridade=${msg.priority}`)

      let result: CallResult = { success: false, isPermanent: false }
      let resolvedSubscriberId = msg.message_content.botconversaId || null

      // 4d. Resolve provider for this message
      decision = resolveProvider(providerRuntime as MessageProviderRuntime, metaCredentialsAvailable)
      
      // 1. Regra Global Temporária: Encomendas vão sempre pela Meta Cloud API (se credenciais ok)
      const msgType = msg.message_type || ""
      const textBody = msg.message_content.value || ""
      
      if ((msgType === "PARCEL" || msgType === "PARCEL_DELIVERED" || msgType === "OTP") && metaCredentialsAvailable) {
        decision = { provider: "META_CLOUD_API", reason: "Canal Oficial Meta para Encomendas e Autenticação (OTP)" }
      }
      // 2. Aplicar filtro de rollout do piloto se ativo no banco
      else if (msg.condominio_id && pilotMap.has(msg.condominio_id)) {
        const stage = pilotMap.get(msg.condominio_id)
        let isMetaAllowed = false
        
        if (stage === "completo") {
          isMetaAllowed = true
        } else if (stage === "reservas") {
          // Encomendas + Visitantes + Reservas/Documentos
          if (msgType === "VISITOR_INVITE" || msgType === "VISITOR_AUTHORIZED" || textBody.includes("reserva") || textBody.includes("documento")) {
             isMetaAllowed = true
          }
        } else if (stage === "visitantes") {
          // Encomendas + Visitantes
          if (msgType === "VISITOR_INVITE" || msgType === "VISITOR_AUTHORIZED") {
             isMetaAllowed = true
          }
        }
        // Note: stage 'encomendas' removido daqui pois já está coberto pela Regra Global Temporária acima
        
        if (isMetaAllowed) {
          if (metaCredentialsAvailable) {
            decision = { provider: "META_CLOUD_API", reason: `Piloto ativo (stage=${stage})` }
          }
        } else {
          // Se não permitido no estágio atual, faz o fallback para o BotConversa
          decision = { provider: "BOTCONVERSA", reason: `Piloto ativo (stage=${stage}) - Fora do escopo do estágio` }
        }
      }
      
      console.log(`[Worker] Provider decidido: ${decision.provider} (${decision.reason})`)

      // 4e. Send message via resolved provider
      if (decision.provider === "META_CLOUD_API") {
        // A. Verificar se a janela de atendimento de 24 horas está aberta
        let isWindowOpen = false
        if (msg.perfil_id) {
          try {
            const { data: perfil } = await supabase
              .from("perfil")
              .select("last_interaction_at")
              .eq("id", msg.perfil_id)
              .single()

            if (perfil?.last_interaction_at) {
              const lastInteraction = new Date(perfil.last_interaction_at).getTime()
              const twentyFourHours = 24 * 60 * 60 * 1000
              if (Date.now() - lastInteraction < twentyFourHours) {
                isWindowOpen = true
                console.log(`[Worker] Janela de 24h aberta para perfil_id=${msg.perfil_id}`)
              }
            }
          } catch (e: any) {
            console.error("[Worker] Erro ao verificar last_interaction_at:", e.message)
          }
        }

        // B. Tentar resolver template caso a janela esteja FECHADA
        let finalTemplateName: string | undefined = undefined
        let finalTemplateLanguage: string | undefined = undefined
        let finalTemplateComponents: any[] | undefined = undefined

        const textBody = msg.message_content.value || ""

        if (msg.payload_type === "text") {
          // ── CAMINHO OFICIAL FASE 2: Contrato Estruturado (Zero Regex / Zero Lógica de Negócio) ──
          if (msg.message_content?.template?.name && Array.isArray(msg.message_content.template.parameters)) {
            const contractVersion = msg.message_content.template.contract_version || 1
            console.log(`[Worker] Processando via contrato estruturado FASE 2 (contract_version=${contractVersion}, template=${msg.message_content.template.name})`)

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
          } else if (!isWindowOpen) {
            // ── CAMINHO LEGADO DEPRECADO: Fallback por Regex (Para mensagens antigas sem contrato) ──
            // Aplicado Apenas se a janela estiver FECHADA, pois se estiver ABERTA, pode ir como texto livre.
            console.warn("[DEPRECATED_REGEX_FALLBACK] Executando fallback por regex para mensagem legada sem contrato estruturado.")

            // Buscar nome real do condomínio do banco para evitar fallbacks no template Meta
            let dbCondoName: string | undefined = undefined
            if (msg.condominio_id) {
              try {
                const { data: condoObj } = await supabase
                  .from("condominios")
                  .select("nome")
                  .eq("id", msg.condominio_id)
                  .single()
                if (condoObj?.nome) dbCondoName = condoObj.nome
              } catch (_) {}
            }

            // 1. Encomenda recebida (condomeet_encomenda_recebida_v2)
            if (textBody.includes("Chegou uma encomenda para o seu apartamento")) {
              finalTemplateName = "condomeet_encomenda_recebida_v2"
              finalTemplateLanguage = "pt_BR"

              const condoMatch = textBody.match(/📦 \*(.*?)\*/)
              const typeMatch = textBody.match(/📨 \*Tipo de encomenda:\*\n(.*)/)
              const unitMatch = textBody.match(/🏢 \*Unidade\*\n(.*?): (.*?) \/ (.*?): (.*)/)
              const trackMatch = textBody.match(/🔍 \*Cod. rastreio:\* (.*)/)
              const limitMatch = textBody.match(/⏱ \*Retirar até:\* (.*)/)
              const obsMatch = textBody.match(/🗒️ \*Observação da encomenda:\*\n([\s\S]*?)\n\nCondomeet agradece!/)

              const condo = dbCondoName || condoMatch?.[1] || "Condomínio"
              const type = typeMatch?.[1] || "Encomenda"
              const blockLabel = unitMatch?.[1] || "Bloco"
              const blockVal = unitMatch?.[2] || "—"
              const aptLabel = unitMatch?.[3] || "Apto"
              const aptVal = unitMatch?.[4] || "—"
              const tracking = trackMatch?.[1] || "Não informado"
              const limit = limitMatch?.[1] || "Imediato"
              const obs = obsMatch?.[1] || "Sem observação"

              finalTemplateComponents = [
                {
                  type: "body",
                  parameters: [
                    { type: "text", text: condo },
                    { type: "text", text: type },
                    { type: "text", text: blockLabel },
                    { type: "text", text: blockVal },
                    { type: "text", text: aptLabel },
                    { type: "text", text: aptVal },
                    { type: "text", text: tracking },
                    { type: "text", text: limit },
                    { type: "text", text: obs }
                  ]
                }
              ]
            }

            // 1b. Encomenda retirada / baixa (condomeet_encomenda_retirada_v1)
            else if (textBody.includes("entregue com sucesso") || textBody.includes("retirada com sucesso")) {
              finalTemplateName = "condomeet_encomenda_retirada_v1"
              finalTemplateLanguage = "pt_BR"

              const condoMatch = textBody.match(/📦 \*(.*?)\*/)
              const residentMatch = textBody.match(/Olá, (.*?)!/)
              const typeMatch = textBody.match(/📦 (.*?)\n\nRecebida em:/)
              const arrMatch = textBody.match(/Recebida em:\n(.*?)\n\nRetirada em:/)
              const delMatch = textBody.match(/Retirada em:\n(.*?)\n\nObrigado\./)

              const condo = dbCondoName || condoMatch?.[1] || "Condomínio"
              const resident = msg.message_content.firstName || residentMatch?.[1] || "Morador"
              const type = typeMatch?.[1] || "Pacote"
              const arrDate = arrMatch?.[1] || "—"
              const delDate = delMatch?.[1] || "—"

              finalTemplateComponents = [
                {
                  type: "body",
                  parameters: [
                    { type: "text", text: condo },
                    { type: "text", text: resident },
                    { type: "text", text: type },
                    { type: "text", text: arrDate },
                    { type: "text", text: delDate }
                  ]
                }
              ]
            }

            // 2. Visitante aguardando autorizacao (condomeet_visitante_aguardando_v3)
            else if (
              textBody.includes("registramos sua solicitação para entrada") ||
              textBody.includes("avise seu/sua visitante") ||
              textBody.includes("avise seu visitante") ||
              textBody.includes("autorizar a sua entrada no condomínio") ||
              textBody.includes("Autorização confirmada!")
            ) {
              finalTemplateName = "condomeet_visitante_aguardando_v3"
              finalTemplateLanguage = "pt_BR"

              const condoMatch = textBody.match(/🏙\s*(.*?)\n|🏢\s*(.*?)\n|🚪\n(.*?)\n/)
              const visitorMatch = textBody.match(/visitante (.*?)\n|Visitante: (.*?)\n|Olá, (.*?)!|Ei (.*?),/i)
              const typeMatch = textBody.match(/Tipo: (.*?)\n|Tipo de visitante:\n\s*(.*?)\n/i)
              const dateMatch = textBody.match(/Visita para a Data:\s*(.*?)\n|Data da visita:\s*(.*?)\n|data:\n\s*(.*?)\n|dia:\n\s*(.*?)\.|para o dia:\s*\n?\s*(.*?)\./i)
              const codeMatch = textBody.match(/(?:🔑|🔐)\s*([A-Za-z0-9]+)|código na portaria:\s*\n?\s*(?:🔑|🔐)?\s*([A-Za-z0-9]+)|Código de autorização:\s*([A-Za-z0-9]+)|Código:\s*\n?\s*([A-Za-z0-9]+)/i)

              const condo = dbCondoName || condoMatch?.[1] || condoMatch?.[2] || condoMatch?.[3] || "Condomínio"
              const resident = msg.message_content.firstName || "Morador"
              let visitor = visitorMatch?.[1] || visitorMatch?.[2] || visitorMatch?.[3] || visitorMatch?.[4] || "Visitante"
              if (visitor.includes("avise seu")) visitor = "Visitante"
              const type = typeMatch?.[1] || typeMatch?.[2] || "Visitante"
              const date = dateMatch?.[1] || dateMatch?.[2] || dateMatch?.[3] || dateMatch?.[4] || dateMatch?.[5] || "Hoje"
              let code = codeMatch?.[1] || codeMatch?.[2] || codeMatch?.[3] || codeMatch?.[4] || "—"
              code = code.trim().replace(/[\.\s]/g, "")

              finalTemplateComponents = [
                {
                  type: "body",
                  parameters: [
                    { type: "text", text: condo.trim() },
                    { type: "text", text: resident.trim() },
                    { type: "text", text: visitor.trim() },
                    { type: "text", text: type.trim() },
                    { type: "text", text: date.trim() },
                    { type: "text", text: code }
                  ]
                }
              ]
            }

            // 3. Reserva confirmada (condomeet_reserva_confirmada_v2)
            else if (textBody.includes("Sua reserva já está aprovada") || textBody.includes("reserva de vaga foi confirmada")) {
              finalTemplateName = "condomeet_reserva_confirmada_v2"
              finalTemplateLanguage = "pt_BR"

              const condoMatch = textBody.match(/📆\s*Condomínio (.*?)\n|📆Condomínio (.*?)\n/)
              const spaceMatch = textBody.match(/Espaço: (.*?)\n|Vaga: (.*?)\n/)
              const dateMatch = textBody.match(/Data do evento:\n(.*?)\n|Período: (.*?)\n/)

              const condo = condoMatch?.[1] || condoMatch?.[2] || "Condomínio"
              const resident = msg.message_content.firstName || "Morador"
              const space = spaceMatch?.[1] || spaceMatch?.[2] || "Área comum"
              const date = dateMatch?.[1] || dateMatch?.[2] || "Agendada"

              finalTemplateComponents = [
                {
                  type: "body",
                  parameters: [
                    { type: "text", text: condo.trim() },
                    { type: "text", text: resident },
                    { type: "text", text: space.trim() },
                    { type: "text", text: date.trim() }
                  ]
                }
              ]
            }

            // 4. Reserva cancelada (condomeet_reserva_cancelada_v2)
            else if (textBody.includes("reserva foi recusada") || textBody.includes("Reserva cancelada")) {
              finalTemplateName = "condomeet_reserva_cancelada_v2"
              finalTemplateLanguage = "pt_BR"

              const condoMatch = textBody.match(/📆\s*Condomínio (.*?)\n|📆Condomínio (.*?)\n/)
              const spaceMatch = textBody.match(/Espaço: (.*?)\n|Vaga: (.*?)\n/)
              const dateMatch = textBody.match(/Data: (.*?)\n|Período: (.*?)\n/)

              const condo = condoMatch?.[1] || condoMatch?.[2] || "Condomínio"
              const resident = msg.message_content.firstName || "Morador"
              const space = spaceMatch?.[1] || spaceMatch?.[2] || "Área comum"
              const date = dateMatch?.[1] || dateMatch?.[2] || "Agendada"

              finalTemplateComponents = [
                {
                  type: "body",
                  parameters: [
                    { type: "text", text: condo.trim() },
                    { type: "text", text: resident },
                    { type: "text", text: space.trim() },
                    { type: "text", text: date.trim() }
                  ]
                }
              ]
            }

            // 5. Documento disponível (condomeet_documento_disponivel_v2)
            else if (
              textBody.includes("documento de Título:") ||
              textBody.includes("contrato de Título:") ||
              textBody.includes("vencerá daqui a")
            ) {
              finalTemplateName = "condomeet_documento_disponivel_v2"
              finalTemplateLanguage = "pt_BR"

              const condoMatch = textBody.match(/do condomínio (.*?)\n/)
              const typeMatch = textBody.match(/O (documento|contrato) de Título:/)
              const titleMatch = textBody.match(/Título:\n(.*?)\n/)
              const catMatch = textBody.match(/Categoria do (?:documento|contrato):\n(.*?)\n/)
              const expMatch = textBody.match(/Data de Expedição:\n(.*?)\n/)
              const valMatch = textBody.match(/Data de Validade:\n(.*?)\n/)

              const condo = condoMatch?.[1] || "Condomínio"
              const resident = msg.message_content.firstName || "Morador"
              const type = typeMatch?.[1] || "documento"
              const title = titleMatch?.[1] || "Novo documento"
              const category = catMatch?.[1] || "Geral"
              const expedicao = expMatch?.[1] || "—"
              const validade = valMatch?.[1] || "—"

              finalTemplateComponents = [
                {
                  type: "body",
                  parameters: [
                    { type: "text", text: condo.trim() },
                    { type: "text", text: resident },
                    { type: "text", text: type },
                    { type: "text", text: title.trim() },
                    { type: "text", text: category.trim() },
                    { type: "text", text: expedicao },
                    { type: "text", text: validade }
                  ]
                }
              ]
            }
          }
        }

        // C. Validar obrigatoriamente se o template possui status APPROVED no MetaTemplateService
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

            if (!tplCheck || tplCheck.status !== "APPROVED") {
              isTemplateApproved = false
              unapprovedReason = `Template '${finalTemplateName}' não está APPROVED na WABA Meta (status local: ${tplCheck?.status || 'NÃO CADASTRADO'}). Envio bloqueado preventivamente.`
              console.warn(`[Worker PREVENTIVE BLOCK] ${unapprovedReason}`)
            }
          } catch (checkErr: any) {
            console.error("[Worker] Erro ao checar status do template:", checkErr.message)
          }
        }

        if (!isTemplateApproved) {
          // NÃO CHAMAR GRAPH API — Bloqueio Preventivo (evita HTTP 404 #132001)
          result = {
            success: false,
            skipped: false,
            resolvedNow: false,
            subscriberId: "",
            phoneNormalized: msg.recipient_phone,
            httpStatus: 400,
            reason: unapprovedReason,
            error: unapprovedReason,
            deliveryStatus: "TEMPLATE_NOT_APPROVED" as any
          }
        } else {
          // Executar chamada de envio via Meta Cloud API apenas se aprovado
          result = await sendViaMetaCloudAPI(
            META_ACCESS_TOKEN!,
            META_PHONE_NUMBER_ID!,
            msg.recipient_phone,
            msg.payload_type || "text",
            msg.message_content.value,
            finalTemplateName,
            finalTemplateLanguage,
            finalTemplateComponents
          )
        }

        // D. Registrar template_name e template_language no outbox para auditoria
        if (finalTemplateName) {
          try {
            await supabase
              .from("whatsapp_outbox")
              .update({
                template_name: finalTemplateName,
                template_language: finalTemplateLanguage || "pt_BR"
              })
              .eq("id", msg.id)
            console.log(`[Worker] Gravado template audit para msg_id=${msg.id}: ${finalTemplateName}`)
          } catch (auditErr: any) {
            console.error("[Worker] Erro ao gravar auditoria do template:", auditErr.message)
          }
        }
      } else {
        // BotConversa — uses same contract as Meta, adapted for text transport
        if (!resolvedSubscriberId) {
          console.log(`[Worker] Resolvendo subscriber ID para telefone=${msg.recipient_phone}`)
          const resolveRes = await resolveSubscriber(
            BOTCONVERSA_API_KEY,
            msg.recipient_phone,
            msg.message_content.firstName || "Morador"
          )

          if (resolveRes.success) {
            resolvedSubscriberId = resolveRes.subscriberId
            console.log(`[Worker] Telefone resolvido para subscriberId=${resolvedSubscriberId}. Salvando em perfil...`)

            if (msg.perfil_id) {
              await supabase
                .from("perfil")
                .update({ botconversa_id: resolvedSubscriberId })
                .eq("id", msg.perfil_id)
            }
          } else {
            result = resolveRes
          }
        }

        if (resolvedSubscriberId) {
          // Resolve final text: structured contract (FASE 2) or legacy value
          let finalTextValue = msg.message_content.value
          const tpl = msg.message_content?.template

          if (tpl?.name && Array.isArray(tpl.parameters) && tpl.parameters.length > 0) {
            // ── Contrato Estruturado: Renderizar texto via módulo dedicado template_renderer.ts ──
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
                  console.log(`[Worker] BotConversa: texto renderizado via template_renderer (template=${tpl.name})`)
                }
              }
            } catch (renderErr: any) {
              console.error(`[Worker] Erro ao renderizar template para BotConversa (fallback para value):`, renderErr.message)
              // finalTextValue já contém msg.message_content.value como fallback seguro
            }
          }

          result = await sendMessage(
            BOTCONVERSA_API_KEY,
            resolvedSubscriberId,
            msg.payload_type || "text",
            finalTextValue
          )
        }
      }

      // 4f. Write audit log (last_attempt_at and delivery_result)
      const nowStr = new Date().toISOString()
      let providerMessageId: string | null = null
      if (decision.provider === "META_CLOUD_API" && result.success && result.body) {
        try {
          const parsed = JSON.parse(result.body)
          if (parsed?.messages?.[0]?.id) {
            providerMessageId = parsed.messages[0].id
          }
        } catch (_) {}
      }

      await supabase
        .from("whatsapp_outbox")
        .update({
          last_attempt_at: nowStr,
          delivery_result: {
            provider: decision.provider,
            provider_reason: decision.reason,
            status_code: result.status || null,
            response: result.body || null,
            error_message: result.error || null,
            is_permanent_error: result.isPermanent,
            resolved_subscriber_id: resolvedSubscriberId,
            provider_message_id: providerMessageId,
          },
        })
        .eq("id", msg.id)

      // 4g. Process outcome (success, retry or permanent failure)
      if (result.success) {
        console.log(`[Worker] Mensagem id=${msg.id} enviada com SUCESSO via ${decision.provider}.`)
        await supabase
          .from("whatsapp_outbox")
          .update({
            status: "sent",
            sent_at: nowStr,
          })
          .eq("id", msg.id)

        // Evaluate recovery (includes dwell time check)
        await evaluateRecovery(supabase, runtime, providerRuntime as MessageProviderRuntime, decision.provider)
      } else {
        console.error(`[Worker] Falha no envio via ${decision.provider} da mensagem id=${msg.id}. Erro: ${result.error}`)
        
        if (result.isPermanent) {
          // Permanent failure -> Move directly to failed (Dead Letter)
          console.error(`[Worker] Erro permanente detectado. Movendo id=${msg.id} direto para Dead Letters.`)
          await supabase
            .from("whatsapp_outbox")
            .update({
              status: "failed",
              error_message: `Erro Permanente (${decision.provider}): ${result.error}`,
            })
            .eq("id", msg.id)
        } else {
          // Temporary failure -> Retry with backoff
          const shouldRetry = msg.retry_count < msg.max_retries
          const nextAttempt = shouldRetry
            ? new Date(Date.now() + Math.pow(2, msg.retry_count) * 60 * 1000).toISOString()
            : null

          console.log(`[Worker] Erro temporario (${decision.provider}). Tentativas: ${msg.retry_count + 1}/${msg.max_retries}. Reagendado? ${shouldRetry}`)

          await supabase
            .from("whatsapp_outbox")
            .update({
              status: shouldRetry ? "pending" : "failed",
              retry_count: msg.retry_count + 1,
              next_attempt_at: nextAttempt,
              error_message: `Erro Temporario (${decision.provider}): ${result.error}`,
            })
            .eq("id", msg.id)
        }

        // Evaluate failover (replaces manual consecutive_failures + Circuit Breaker block)
        const { breakLoop } = await evaluateFailover(supabase, runtime, providerRuntime as MessageProviderRuntime, result, decision.provider)
        if (breakLoop) {
          console.error(`[Worker] Circuit Breaker ativado! Pausando processamento.`)
          break
        }
      }

      // 4g-2. Renew Lease Lock after sending
      const leaseOkAfterSend = await renewLease()
      if (!leaseOkAfterSend) {
        console.log("[Worker] Nao foi possivel renovar o Lease Lock apos envio. Finalizando loop.")
        break
      }

      // 4h. Cooldown with Priority and Operational Mode (SAFE_MODE check)
      let baseCooldown = 3 // default
      let jitter = 0

      if (queueType === "high") {
        if (runtime.operational_mode === "SAFE_MODE") {
          baseCooldown = 3
        } else {
          baseCooldown = 1
        }
      } else {
        if (runtime.operational_mode === "SAFE_MODE") {
          baseCooldown = 20 // standard safe mode cooldown
        } else {
          if (msg.priority <= 5) {
            baseCooldown = 2 // critical (SOS, Visitor)
            jitter = Math.floor(Math.random() * 2) // +0 to 1s jitter
          } else if (msg.priority <= 10) {
            baseCooldown = 2 // Encomendas (Prioridade 10): 2s base + 0-2s jitter (Total 2s a 4s)
            jitter = Math.floor(Math.random() * 3) // +0 to 2s jitter
          } else {
            baseCooldown = 12 // informational (Avisos, Boletos)
            jitter = Math.floor(Math.random() * 5) + 1 // +1 to 5s jitter
          }
        }
      }

      const totalSleepSec = baseCooldown + jitter
      console.log(`[Worker] Cooldown de ${totalSleepSec}s iniciado antes do proximo claim para lease=${leaseId}.`)
      await new Promise((r) => setTimeout(r, totalSleepSec * 1000))

      // 4h-2. Renew Lease Lock after cooldown
      const leaseOkAfterCooldown = await renewLease()
      if (!leaseOkAfterCooldown) {
        console.log("[Worker] Nao foi possivel renovar o Lease Lock apos cooldown. Finalizando loop.")
        break
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
