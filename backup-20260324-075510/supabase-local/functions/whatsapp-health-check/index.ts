// whatsapp-health-check — Cron job that monitors UAZAPI WhatsApp status
// Runs every 15 minutes. If UAZAPI is down, sends email alerts.
// Uses Resend API for email delivery.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const ALERT_EMAILS = [
  "cristiano.santos@gmx.com",
  "erikaosc@gmail.com",
]

// Minimum 1 hour between alert emails to avoid spam
const ALERT_COOLDOWN_MS = 60 * 60 * 1000

// Number of consecutive failures before alerting
const FAIL_THRESHOLD = 2

Deno.serve(async (_req: Request) => {
  try {
    const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")
    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SERVICE_ROLE_KEY")!

    if (!UAZAPI_URL || !UAZAPI_TOKEN) {
      console.error("[HealthCheck] UAZAPI_URL or UAZAPI_TOKEN not configured")
      return new Response(JSON.stringify({ error: "UAZAPI not configured" }), { status: 500 })
    }

    if (!RESEND_API_KEY) {
      console.error("[HealthCheck] RESEND_API_KEY not configured")
      return new Response(JSON.stringify({ error: "RESEND_API_KEY not configured" }), { status: 500 })
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

    // ── 1. Check UAZAPI status ──────────────────────────────────────────
    let uazapiOk = false
    let errorMsg = ""

    try {
      // Try the status endpoint
      const res = await fetch(`${UAZAPI_URL}/status`, {
        method: "GET",
        headers: { token: UAZAPI_TOKEN, Accept: "application/json" },
        signal: AbortSignal.timeout(15000), // 15s timeout
      })

      if (res.ok) {
        const rawText = await res.text()
        console.log(`[HealthCheck] /status response: ${rawText.substring(0, 500)}`)
        
        // Deep search the entire JSON string for connection indicators
        const lower = rawText.toLowerCase()
        if (lower.includes('"open"') || lower.includes('"connected"') || 
            lower.includes('"islogged"') || lower.includes('"online"') ||
            lower.includes('"isloggedin":true') || lower.includes('"islogged":true') ||
            lower.includes('"connected":true')) {
          uazapiOk = true
        } else {
          errorMsg = `UAZAPI respondeu mas sem indicador de conexão. Resposta: ${rawText.substring(0, 300)}`
        }
      } else {
        const body = await res.text().catch(() => "")
        errorMsg = `UAZAPI retornou HTTP ${res.status}: ${body.substring(0, 200)}`
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      errorMsg = `UAZAPI não respondeu: ${msg}`
    }

    // Fallback: try /instance endpoint
    if (!uazapiOk) {
      try {
        const res2 = await fetch(`${UAZAPI_URL}/instance`, {
          method: "GET",
          headers: { token: UAZAPI_TOKEN, Accept: "application/json" },
          signal: AbortSignal.timeout(10000),
        })
        if (res2.ok) {
          const rawText2 = await res2.text()
          console.log(`[HealthCheck] /instance response: ${rawText2.substring(0, 500)}`)
          const lower2 = rawText2.toLowerCase()
          if (lower2.includes('"open"') || lower2.includes('"connected"') || 
              lower2.includes('"islogged"') || lower2.includes('"online"') ||
              lower2.includes('"isloggedin":true') || lower2.includes('"islogged":true') ||
              lower2.includes('"connected":true')) {
            uazapiOk = true
            errorMsg = ""
          }
        }
      } catch (_) {
        // keep original error
      }
    }

    // Last resort: try sending a test to verify UAZAPI is reachable and authenticated
    if (!uazapiOk) {
      try {
        // Just ping the API root
        const res3 = await fetch(UAZAPI_URL, {
          method: "GET",
          headers: { token: UAZAPI_TOKEN },
          signal: AbortSignal.timeout(10000),
        })
        if (res3.ok) {
          // API is reachable and authenticated, assume it's working
          const rawText3 = await res3.text()
          console.log(`[HealthCheck] Root response: ${rawText3.substring(0, 300)}`)
          // If the root responds with 200, the API is up
          uazapiOk = true
          errorMsg = ""
        }
      } catch (_) {
        // keep original error
      }
    }

    // ── 2. Get current health status from DB ────────────────────────────
    const { data: currentStatus } = await supabase
      .from("whatsapp_health_status")
      .select("*")
      .eq("id", "singleton")
      .single()

    const now = new Date()
    const previousStatus = currentStatus?.status || "ok"
    const lastAlertAt = currentStatus?.last_alert_at ? new Date(currentStatus.last_alert_at) : null
    const currentFailCount = (currentStatus?.fail_count || 0)

    // ── 3. Handle status ────────────────────────────────────────────────

    if (uazapiOk) {
      // ▶ WhatsApp is OK
      const wasDown = previousStatus === "down"

      await supabase
        .from("whatsapp_health_status")
        .update({
          status: "ok",
          last_check_at: now.toISOString(),
          fail_count: 0,
          last_error: null,
        })
        .eq("id", "singleton")

      // Send recovery email if it was previously down
      if (wasDown) {
        await sendAlertEmail(
          RESEND_API_KEY,
          "✅ WhatsApp Condomeet VOLTOU!",
          `<h2>✅ WhatsApp voltou ao normal!</h2>
           <p>O serviço de WhatsApp (UAZAPI) do Condomeet voltou a funcionar.</p>
           <p><strong>Hora da recuperação:</strong> ${formatDateBR(now)}</p>
           <p>As mensagens voltarão a ser enviadas normalmente.</p>`
        )
        console.log("[HealthCheck] Recovery email sent")
      }

      console.log("[HealthCheck] UAZAPI is OK")
      return new Response(JSON.stringify({ status: "ok", checked_at: now.toISOString() }))
    }

    // ▶ WhatsApp is DOWN
    const newFailCount = currentFailCount + 1

    await supabase
      .from("whatsapp_health_status")
      .update({
        status: "down",
        last_check_at: now.toISOString(),
        fail_count: newFailCount,
        last_error: errorMsg,
      })
      .eq("id", "singleton")

    console.warn(`[HealthCheck] UAZAPI DOWN! fail_count=${newFailCount}, error: ${errorMsg}`)

    // Only alert after threshold consecutive failures AND respect cooldown
    const shouldAlert = newFailCount >= FAIL_THRESHOLD &&
      (!lastAlertAt || (now.getTime() - lastAlertAt.getTime()) > ALERT_COOLDOWN_MS)

    if (shouldAlert) {
      await sendAlertEmail(
        RESEND_API_KEY,
        "🚨 ALERTA: WhatsApp Condomeet FORA DO AR!",
        `<h2>🚨 WhatsApp do Condomeet está fora do ar!</h2>
         <p>O sistema detectou que o serviço de WhatsApp (UAZAPI) não está funcionando corretamente.</p>
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
         <p>Verifique o painel UAZAPI e o número de WhatsApp conectado.</p>
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
