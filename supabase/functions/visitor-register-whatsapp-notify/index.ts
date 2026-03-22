// visitor-register-whatsapp-notify — Supabase Edge Function
// Called from the web app after registering a visitor (visitante_registros).
// Sends WhatsApp notification to all residents of the target unit.

import { createClient } from "npm:@supabase/supabase-js@2"

const BOTCONVERSA_BASE_URL =
  "https://backend.botconversa.com.br/api/v1/webhook"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      Connection: "keep-alive",
    },
  })
}

function genCodInterno(): string {
  return Math.random().toString(36).substring(2, 7).toUpperCase()
}

function formatDateBR(dateStr: string): string {
  if (!dateStr) return "—"
  try {
    const dt = new Date(dateStr)
    return `${String(dt.getDate()).padStart(2, "0")}/${String(dt.getMonth() + 1).padStart(2, "0")}/${dt.getFullYear()}`
  } catch {
    return dateStr
  }
}

// ── BotConversa: create/get subscriber ────────────────────────────────────
async function resolveSubscriber(
  apiKey: string,
  phone: string,
  fullName: string
): Promise<string | null> {
  try {
    const nameParts = (fullName || "Visitante").split(" ")
    const firstName = nameParts[0] || "Visitante"
    const lastName = nameParts.length > 1 ? nameParts.slice(1).join(" ") : "."

    const res = await fetch(`${BOTCONVERSA_BASE_URL}/subscriber/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "API-KEY": apiKey,
      },
      body: JSON.stringify({ phone, first_name: firstName, last_name: lastName }),
    })

    const text = await res.text()
    console.log(`BotConversa resolve subscriber (${phone}): ${res.status} ${text}`)

    if (!res.ok) return null

    const data = JSON.parse(text)
    return String(data.id || data.subscriber_id || "")
  } catch (err) {
    console.error("resolveSubscriber error:", err)
    return null
  }
}

// ── BotConversa: send message ─────────────────────────────────────────────
async function sendMessage(
  apiKey: string,
  subscriberId: string,
  message: string
): Promise<boolean> {
  try {
    const res = await fetch(
      `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_message/`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "API-KEY": apiKey,
        },
        body: JSON.stringify({ type: "text", value: message }),
      }
    )

    if (!res.ok) {
      const errText = await res.text()
      console.error(`BotConversa send error (${subscriberId}): ${res.status} ${errText}`)
      return false
    }
    return true
  } catch (err) {
    console.error(`BotConversa send error (${subscriberId}):`, err)
    return false
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  MAIN HANDLER
// ══════════════════════════════════════════════════════════════════════════

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const payload = await req.json()
    const {
      condominio_id,
      nome,
      whatsapp,
      tipo_visitante,
      empresa,
      bloco,
      apto,
      data_visita,
    } = payload as Record<string, string>

    console.log(`[visitor-register-notify] Visitor registered: ${nome} at ${bloco}/${apto}`)

    // ── Init Supabase ─────────────────────────────────────────────────
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // ── BotConversa API key ───────────────────────────────────────────
    const apiKey = Deno.env.get("BOTCONVERSA_API_KEY")
    if (!apiKey) {
      console.error("BOTCONVERSA_API_KEY not configured")
      return jsonResponse({ error: "BotConversa not configured" }, 500)
    }

    // ── Fetch condominium name ────────────────────────────────────────
    const { data: condo } = await supabase
      .from("condominios")
      .select("nome")
      .eq("id", condominio_id)
      .single()
    const condoNome = condo?.nome || "Condomínio"

    // ── Format values ─────────────────────────────────────────────────
    const visitDate = data_visita ? formatDateBR(data_visita) : formatDateBR(new Date().toISOString())
    const tipoVisitante = tipo_visitante || "Visitante"
    const whatsappDisplay = whatsapp && whatsapp.trim() ? whatsapp.trim() : "Não informado"
    const empresaDisplay = empresa && empresa.trim() ? empresa.trim() : "Não informada"

    // ── Fetch ALL residents of the unit ────────────────────────────────
    const { data: unitResidents } = await supabase
      .from("perfil")
      .select("id, nome_completo, botconversa_id, notificacoes_whatsapp")
      .eq("condominio_id", condominio_id)
      .eq("bloco_txt", bloco)
      .eq("apto_txt", apto)
      .not("botconversa_id", "is", null)

    const results: string[] = []

    if (!unitResidents || unitResidents.length === 0) {
      console.log(`No residents with botconversa_id in ${bloco}/${apto}`)
      return jsonResponse({ sent: false, reason: "No residents with WhatsApp configured" })
    }

    // ── Send to each resident ─────────────────────────────────────────
    for (let i = 0; i < unitResidents.length; i++) {
      const r = unitResidents[i]

      // Skip residents who opted out
      if (r.notificacoes_whatsapp === false) {
        results.push(`Skipped ${r.id}: opted out`)
        continue
      }

      // Anti-spam delay between messages
      if (i > 0) {
        const delay = Math.floor(Math.random() * 10000) + 5000
        await new Promise((resolve) => setTimeout(resolve, delay))
      }

      const codInterno = genCodInterno()

      const msg =
        `🏙  ${condoNome}\n` +
        `\n` +
        `Acabamos de autorizar a entrada do(a) visitante *${nome}*\n` +
        `\n` +
        `🗓️ *Data da visita:*\n` +
        `${visitDate}\n` +
        `\n` +
        `🗒️ *Tipo de visitante:*\n` +
        `${tipoVisitante}\n` +
        `\n` +
        `📝 *WhatsApp do Visitante:*\n` +
        `${whatsappDisplay}\n` +
        `\n` +
        `🏨 *Empresa:*\n` +
        `${empresaDisplay}\n` +
        `\n` +
        `Condomeet agradece!\n` +
        `Cód interno: ${codInterno}`

      const sent = await sendMessage(apiKey, r.botconversa_id, msg)
      results.push(`Resident ${r.id}: ${sent ? "✅" : "❌"}`)
      console.log(`WhatsApp to ${r.nome_completo}: ${sent ? "✅" : "❌"}`)
    }

    console.log(`[visitor-register-notify] Results:`, results)

    return jsonResponse({
      action: "visitor_registered",
      results,
      total_sent: results.filter(r => r.includes("✅")).length,
    })
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("[visitor-register-notify] Error:", msg)
    return jsonResponse({ error: msg }, 500)
  }
})
