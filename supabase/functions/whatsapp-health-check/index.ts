// whatsapp-health-check — Cron job that monitors WhatsApp messaging status
// Now that we use BotConversa (managed SaaS), this function simply verifies
// the API key is set and the BotConversa API is reachable.
// Runs every 15 minutes. If BotConversa is unreachable, sends email alerts.
// Uses Resend API for email delivery.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { BOTCONVERSA_BASE_URL } from "../_shared/botconversa.ts"

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
    const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY") ?? ""
    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SERVICE_ROLE_KEY")!

    if (!BOTCONVERSA_API_KEY) {
      console.error("[HealthCheck] BOTCONVERSA_API_KEY not configured")
      return new Response(JSON.stringify({ error: "BotConversa not configured" }), { status: 500 })
    }

    if (!RESEND_API_KEY) {
      console.error("[HealthCheck] RESEND_API_KEY not configured")
      return new Response(JSON.stringify({ error: "RESEND_API_KEY not configured" }), { status: 500 })
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

    // ── 1. Check BotConversa API reachability ──────────────────────────────
    let apiOk = false
    let errorMsg = ""

    try {
      // Try fetching subscriber list (lightweight endpoint) to verify API key works
      const res = await fetch(`${BOTCONVERSA_BASE_URL}/subscriber/?page_size=1`, {
        method: "GET",
        headers: {
          "API-KEY": BOTCONVERSA_API_KEY,
          "Accept": "application/json",
        },
        signal: AbortSignal.timeout(15000),
      })

      if (res.ok) {
        apiOk = true
        console.log("[HealthCheck] BotConversa API is OK")
      } else {
        const body = await res.text().catch(() => "")
        errorMsg = `BotConversa retornou HTTP ${res.status}: ${body.substring(0, 200)}`
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      errorMsg = `BotConversa não respondeu: ${msg}`
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

    if (apiOk) {
      // ▶ BotConversa is OK
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

    await supabase
      .from("whatsapp_health_status")
      .update({
        status: "down",
        last_check_at: now.toISOString(),
        fail_count: newFailCount,
        last_error: errorMsg,
      })
      .eq("id", "singleton")

    console.warn(`[HealthCheck] BotConversa DOWN! fail_count=${newFailCount}, error: ${errorMsg}`)

    // Only alert after threshold consecutive failures AND respect cooldown
    const shouldAlert = newFailCount >= FAIL_THRESHOLD &&
      (!lastAlertAt || (now.getTime() - lastAlertAt.getTime()) > ALERT_COOLDOWN_MS)

    if (shouldAlert) {
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
