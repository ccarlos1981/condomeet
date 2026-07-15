// whatsapp-health-check — Supabase Edge Function
// Performs a health check on the BotConversa connection,
// updates status columns and triggers the non-aggressive Operational Supervisor logic.

import { createClient } from "npm:@supabase/supabase-js@2"

const BOTCONVERSA_BASE_URL = "https://backend.botconversa.com.br/api/v1/webhook"
const FAIL_THRESHOLD = 5
const ALERT_COOLDOWN_MS = 60 * 60 * 1000 // 1 hour
const ALERT_EMAILS = ["cristiano.santos@gmx.com", "erikaosc@gmail.com"]

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY")
  const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")

  if (!BOTCONVERSA_API_KEY) {
    return new Response(JSON.stringify({ error: "BOTCONVERSA_API_KEY not configured" }), { status: 500 })
  }

  try {
    // ── 1. Perform health check ──────────────────────────────────────────
    // Fetch a real active botconversa_id from DB to check subscriber status
    const { data: activeMorador } = await supabase
      .from("perfil")
      .select("botconversa_id")
      .not("botconversa_id", "is", null)
      .limit(1)
      .maybeSingle()

    const checkId = activeMorador?.botconversa_id || "1" // Fallback to 1 if empty
    const checkUrl = `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(checkId)}/`

    let apiOk = false
    let errorMsg = ""
    const checkStart = Date.now()

    try {
      const res = await fetch(checkUrl, {
        method: "GET",
        headers: { "API-KEY": BOTCONVERSA_API_KEY },
      })
      
      const bodyText = await res.text()
      console.log(`[HealthCheck] API response status=${res.status}, body=${bodyText}`)

      // Prove API is working if status is 200 or 404 (404 confirms API works but contact id is not found)
      if (res.status === 200 || res.status === 404) {
        apiOk = true
      } else {
        errorMsg = `${res.status}: ${bodyText}`
      }
    } catch (fetchErr: unknown) {
      errorMsg = fetchErr instanceof Error ? fetchErr.message : String(fetchErr)
    }

    // ── 2. Query previous health status ─────────────────────────────────
    const { data: currentStatus } = await supabase
      .from("whatsapp_health_status")
      .select("*")
      .eq("id", "singleton")
      .single()

    const now = new Date()
    const previousStatus = currentStatus?.status || "ok"
    const lastAlertAt = currentStatus?.last_alert_at ? new Date(currentStatus.last_alert_at) : null
    const currentFailCount = (currentStatus?.fail_count || 0)
    const wasDisconnected = currentStatus?.whatsapp_connection_status === "disconnected"

    // ── 3. Supervisor Logic (Anti-Flapping & Audit) ───────────────────
    const runSupervisor = async (isApiOk: boolean, newFail: number) => {
      // 1. WhatsApp Disconnection temporal window (Critical > 5 minutes)
      const isCurrentlyOffline = !isApiOk || currentStatus?.whatsapp_connection_status === "disconnected"
      
      if (isCurrentlyOffline) {
        const lastDisconnect = currentStatus?.last_disconnected_at ? new Date(currentStatus.last_disconnected_at) : null
        const disconnectedMinutes = lastDisconnect ? (Date.now() - lastDisconnect.getTime()) / 60000 : 0
        
        // Critical disconnection check (more than 5 mins OR fail_count >= 5)
        if (disconnectedMinutes > 5 || newFail >= 5) {
          const reason = disconnectedMinutes > 5 
            ? `WhatsApp desconectado por ${Math.round(disconnectedMinutes)} minutos (limite excedido)`
            : `API em falha por ${newFail} verificacoes consecutivas`
          
          // Get active campaigns in status = 'sending'
          const { data: activeCamps } = await supabase
            .from("notification_campaigns")
            .select("id, title")
            .eq("status", "sending")
            
          for (const camp of activeCamps || []) {
            console.warn(`[Supervisor] Pausing campaign "${camp.title}" due to critical outage.`)
            await supabase
              .from("notification_campaigns")
              .update({
                status: "paused",
                pause_reason: `Pausado automaticamente pelo Supervisor: ${reason}`
              })
              .eq("id", camp.id)
              
            // Log audit
            await supabase.from("notification_supervisor_logs").insert({
              severity: "CRITICAL",
              rule_name: disconnectedMinutes > 5 ? "whatsapp_offline_threshold" : "api_fail_threshold",
              message: `Campanha "${camp.title}" pausada automaticamente. Razao: ${reason}`,
              campaign_id: camp.id,
              action_taken: "paused_campaign",
              metadata: { disconnected_minutes: disconnectedMinutes, fail_count: newFail }
            })
          }
        } else {
          // Warning state (disconnected but less than 5 minutes)
          await supabase.from("notification_supervisor_logs").insert({
            severity: "WARNING",
            rule_name: "whatsapp_connection_flapping",
            message: `Instabilidade detectada: WhatsApp offline ha ${Math.round(disconnectedMinutes)}m ou ${newFail} falhas. Monitorando janela de tempo.`,
            action_taken: "alert"
          })
        }
      }

      // 2. Dead Letter threshold check (> 10 dead letters in last 24h)
      const oneDayAgo = new Date(Date.now() - 24 * 3600000).toISOString()
      const { count: deadLetterCount } = await supabase
        .from("notification_campaign_recipients")
        .select("id", { count: "exact", head: true })
        .eq("status", "dead_letter")
        .gte("sent_at", oneDayAgo)

      if (deadLetterCount && deadLetterCount > 10) {
        await supabase.from("notification_supervisor_logs").insert({
          severity: "CRITICAL",
          rule_name: "dead_letter_threshold",
          message: `Excesso de Dead Letters detectado nas ultimas 24h: ${deadLetterCount} mensagens falharam permanentemente.`,
          action_taken: "alert",
          metadata: { dead_letter_count: deadLetterCount }
        })
      }

      // 3. Queue size warning (> 100 pending messages)
      const { count: pendingQueueSize } = await supabase
        .from("notification_campaign_recipients")
        .select("id", { count: "exact", head: true })
        .eq("status", "pending")

      if (pendingQueueSize && pendingQueueSize > 100) {
        await supabase.from("notification_supervisor_logs").insert({
          severity: "WARNING",
          rule_name: "queue_backlog_warning",
          message: `Crescimento de fila: ${pendingQueueSize} mensagens aguardando processamento.`,
          action_taken: "alert",
          metadata: { queue_size: pendingQueueSize }
        })
      }

      // 4. Connection Restored / Reconnection Check (INFO only, no auto-resume)
      if (isApiOk && wasDisconnected) {
        console.log("[Supervisor] Connection restored. Logged ready for resume.")
        await supabase.from("notification_supervisor_logs").insert({
          severity: "INFO",
          rule_name: "connection_recovered",
          message: "Conexao restabelecida. Campanhas de notificacoes estao aptas para retomada manual pelo administrador.",
          action_taken: "ready_for_resume"
        })
      }
    }

    // ── 4. Handle status updates ─────────────────────────────────────────

    if (apiOk) {
      // ▶ BotConversa is OK
      const wasDown = previousStatus === "down"

      const updatePayload: Record<string, any> = {
        status: "ok",
        api_status: "ok",
        whatsapp_connection_status: "connected",
        connection_source: "healthcheck",
        confidence_level: "inferred",
        last_check_at: now.toISOString(),
        last_heartbeat: now.toISOString(),
        last_api_success_at: now.toISOString(),
        fail_count: 0,
        last_error: null,
      }

      if (wasDisconnected) {
        updatePayload.last_reconnected_at = now.toISOString()
        
        // Log transition in telemetria
        try {
          await supabase.from("botconversa_monitoring").insert({
            action_type: "BOTCONVERSA_RECONNECTED",
            recipient_phone: "system",
            perfil_id: null,
            execution_time_ms: null,
            error_message: "Reconnection detected by health check",
            function_name: "healthcheck",
            delivery_status: "BOTCONVERSA_API_SUCCESS"
          })
        } catch (dbErr) {
          console.error("[HealthCheck] Failed to log transition metric:", dbErr)
        }
      }

      await supabase
        .from("whatsapp_health_status")
        .update(updatePayload)
        .eq("id", "singleton")

      // Run Supervisor
      await runSupervisor(true, 0)

      // Send recovery email if it was previously down
      if (wasDown && RESEND_API_KEY) {
        await sendAlertEmail(
          RESEND_API_KEY,
          "✅ WhatsApp Condomeet VOLTOU!",
          `<h2>✅ WhatsApp voltou ao normal!</h2>
           <p>O serviço de WhatsApp (BotConversa) do Condomeet voltou a funcionar.</p>
           <p><strong>Hora da recuperação:</strong> ${formatDateBR(now)}</p>
           <p>As mensagens voltarão a ser enviadas normalmente.</p>`
        )
        console.log("[HealthCheck] Recovery email sent")
      }

      console.log("[HealthCheck] BotConversa is OK")
      return new Response(JSON.stringify({ status: "ok", checked_at: now.toISOString() }))
    }

    // ▶ BotConversa is DOWN
    const newFailCount = currentFailCount + 1
    const wasConnected = currentStatus?.whatsapp_connection_status !== "disconnected"

    const updatePayload: Record<string, any> = {
      status: "down",
      api_status: "error",
      whatsapp_connection_status: "disconnected",
      connection_source: "healthcheck",
      confidence_level: "inferred",
      last_check_at: now.toISOString(),
      last_heartbeat: now.toISOString(),
      last_api_failure_at: now.toISOString(),
      last_disconnected_at: now.toISOString(),
      fail_count: newFailCount,
      last_error: errorMsg,
    }

    if (wasConnected) {
      // Log transition in telemetria
      try {
        await supabase.from("botconversa_monitoring").insert({
          action_type: "BOTCONVERSA_OFFLINE_DETECTED",
          recipient_phone: "system",
          perfil_id: null,
          execution_time_ms: null,
          error_message: errorMsg,
          function_name: "healthcheck",
          delivery_status: "BOTCONVERSA_DISCONNECTED"
        })
      } catch (dbErr) {
        console.error("[HealthCheck] Failed to log transition metric:", dbErr)
      }
    }

    await supabase
      .from("whatsapp_health_status")
      .update(updatePayload)
      .eq("id", "singleton")

    // Run Supervisor
    await runSupervisor(false, newFailCount)

    console.warn(`[HealthCheck] BotConversa DOWN! fail_count=${newFailCount}, error: ${errorMsg}`)

    // Only alert after threshold consecutive failures AND respect cooldown
    const shouldAlert = newFailCount >= FAIL_THRESHOLD &&
      (!lastAlertAt || (now.getTime() - lastAlertAt.getTime()) > ALERT_COOLDOWN_MS)

    if (shouldAlert && RESEND_API_KEY) {
      await sendAlertEmail(
        RESEND_API_KEY,
        "🚨 ALERTA: WhatsApp Condomeet FORA DO AR!",
        `<h2>🚨 WhatsApp do Condomeet está fora do ar!</h2>
         <p>O sistema detectou que o serviço de WhatsApp (BotConversa) não está funcionando corretamente.</p>
         <p><strong>Erro:</strong> ${errorMsg}</p>
         <p><strong>Falhas consecutivas:</strong> ${newFailCount}</p>
         <p><strong>Detectado em:</strong> ${formatDateBR(now)}</p>
         <hr>
         <p>⚠️ <strong>Consequências:</strong></p>
         <ul>
           <li>Notificações de encomenda por WhatsApp não estão sendo enviadas</li>
           <li>Chatbot IA Meet não está respondendo</li>
           <li>Alertas de visitante por WhatsApp não estão funcionando</li>
         </ul>
         <p>Verifique o painel BotConversa e a configuração da API Key.</p>
         <p style="color:gray;font-size:12px;">Este alerta é enviado automaticamente pelo Condomeet. Próximo alerta em no mínimo 1 hora se o problema persistir.</p>`
      )
      
      await supabase
        .from("whatsapp_health_status")
        .update({ last_alert_at: now.toISOString() })
        .eq("id", "singleton")

      console.log("[HealthCheck] Alert email sent!")
    }

    return new Response(JSON.stringify({
      status: "down",
      fail_count: newFailCount,
      error: errorMsg,
      alert_sent: shouldAlert,
      checked_at: now.toISOString(),
    }))

  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("[HealthCheck] Unexpected error:", msg)
    return new Response(JSON.stringify({ error: msg }), { status: 500 })
  }
})

// ── Send email via Resend API ───────────────────────────────────────────────

async function sendAlertEmail(apiKey: string, subject: string, htmlBody: string) {
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Condomeet Monitor <onboarding@resend.dev>",
        to: ALERT_EMAILS,
        subject: subject,
        html: htmlBody,
      }),
    })

    if (!res.ok) {
      const errText = await res.text()
      console.error(`[HealthCheck] Resend error: ${res.status} ${errText}`)
    } else {
      console.log(`[HealthCheck] Email sent to ${ALERT_EMAILS.join(", ")}`)
    }
  } catch (err: unknown) {
    console.error("[HealthCheck] Email send failed:", err instanceof Error ? err.message : err)
  }
}

function formatDateBR(date: Date): string {
  return date.toLocaleString("pt-BR", {
    timeZone: "America/Sao_Paulo",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  })
}
