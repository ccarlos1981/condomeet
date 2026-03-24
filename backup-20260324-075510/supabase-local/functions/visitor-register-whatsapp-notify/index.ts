// visitor-register-whatsapp-notify — Supabase Edge Function
// Called from the web app after registering a visitor (visitante_registros).
// Sends WhatsApp notification to all residents of the target unit via UazAPI.

import { createClient } from "npm:@supabase/supabase-js@2"
import { sendTextMessage, normalizePhone } from "../_shared/uazapi.ts"

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
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // ── UazAPI credentials ────────────────────────────────────────────
    const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")
    if (!UAZAPI_URL || !UAZAPI_TOKEN) {
      console.error("UAZAPI_URL or UAZAPI_TOKEN not configured")
      return jsonResponse({ error: "UazAPI not configured" }, 500)
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

    // ── Fetch ALL residents of the unit with whatsapp ──────────────────
    const { data: unitResidents } = await supabase
      .from("perfil")
      .select("id, nome_completo, whatsapp, notificacoes_whatsapp")
      .eq("condominio_id", condominio_id)
      .eq("bloco_txt", bloco)
      .eq("apto_txt", apto)
      .not("whatsapp", "is", null)

    const results: string[] = []

    if (!unitResidents || unitResidents.length === 0) {
      console.log(`No residents with whatsapp in ${bloco}/${apto}`)
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

      if (!r.whatsapp || r.whatsapp.trim() === "") {
        results.push(`Skipped ${r.id}: no whatsapp`)
        continue
      }

      const phone = normalizePhone(r.whatsapp)
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

      const sendResult = await sendTextMessage(UAZAPI_URL, UAZAPI_TOKEN, phone, msg)
      results.push(`Resident ${r.id}: ${sendResult.success ? "✅" : "❌"}`)
      console.log(`WhatsApp to ${r.nome_completo}: ${sendResult.success ? "✅" : "❌"}`)
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
