// optin-whatsapp-cron — Supabase Edge Function
// Sends opt-in confirmation messages to residents who haven't been asked yet.
// In test mode (?test=PHONE), sends only to the specified phone.
// In production mode (cron), picks 2 random residents per day.

import { createClient } from "npm:@supabase/supabase-js@2"
import { smartSend, normalizePhone } from "../_shared/botconversa.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY") ?? ""
    if (!BOTCONVERSA_API_KEY) {
      return new Response(JSON.stringify({ error: "BOTCONVERSA_API_KEY not configured" }), { status: 500 })
    }

    // ── Check for test mode ────────────────────────────────────────────
    const url = new URL(req.url)
    const testPhone = url.searchParams.get("test")
    const limit = 1 // Always 1 per execution (scheduled twice a day)

    let residents: any[] = []

    if (testPhone) {
      // TEST MODE: send to a specific phone
      const cleanPhone = normalizePhone(testPhone)
      console.log(`[OptIn] TEST MODE: sending to ${cleanPhone}`)

      const { data: perfil } = await supabase
        .from("perfil")
        .select("id, nome_completo, whatsapp, botconversa_id, condominio_id")
        .eq("whatsapp", cleanPhone)
        .limit(1)
        .maybeSingle()

      if (!perfil) {
        const withoutDDI = cleanPhone.startsWith("55") ? cleanPhone.substring(2) : cleanPhone
        const { data: perfil2 } = await supabase
          .from("perfil")
          .select("id, nome_completo, whatsapp, botconversa_id, condominio_id")
          .eq("whatsapp", withoutDDI)
          .limit(1)
          .maybeSingle()

        if (perfil2) residents = [perfil2]
      } else {
        residents = [perfil]
      }

      if (residents.length === 0) {
        return new Response(JSON.stringify({ error: `No profile found for phone: ${cleanPhone}` }), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        })
      }
    } else {
      // PRODUCTION MODE: pick random residents who haven't been asked yet
      const { data: candidates } = await supabase
        .from("perfil")
        .select("id, nome_completo, whatsapp, botconversa_id, condominio_id")
        .eq("status_aprovacao", "aprovado")
        .not("whatsapp", "is", null)
        .neq("notificacoes_whatsapp", false)
        .limit(200)

      if (candidates && candidates.length > 0) {
        // Filter out already asked
        const { data: alreadyAsked } = await supabase
          .from("optin_whatsapp_log")
          .select("perfil_id")

        const askedIds = new Set((alreadyAsked ?? []).map((a: any) => a.perfil_id))
        const filtered = candidates.filter((c: any) => !askedIds.has(c.id) && c.whatsapp?.trim())

        // Pick random
        const shuffled = filtered.sort(() => Math.random() - 0.5)
        residents = shuffled.slice(0, limit)
      }
    }

    if (residents.length === 0) {
      console.log("[OptIn] No candidates found")
      return new Response(JSON.stringify({ ok: true, sent: 0, reason: "No candidates" }), {
        headers: { "Content-Type": "application/json" },
      })
    }

    // ── Fetch condominium names ──────────────────────────────────────────
    const condoIds = [...new Set(residents.map((r: any) => r.condominio_id).filter(Boolean))]
    let condoMap: Record<string, string> = {}
    if (condoIds.length > 0) {
      const { data: condos } = await supabase
        .from("condominios")
        .select("id, nome")
        .in("id", condoIds)

      for (const c of (condos ?? [])) {
        condoMap[c.id] = c.nome
      }
    }

    // ── Send opt-in messages ────────────────────────────────────────────
    const results: string[] = []

    for (const resident of residents) {
      const firstName = resident.nome_completo?.split(" ")[0] || "Morador"
      const condoName = condoMap[resident.condominio_id] || "seu condomínio"
      const phone = normalizePhone(resident.whatsapp)

      const msg =
        `📱 *Condomeet*\n\n` +
        `Olá, *${firstName}*! 👋\n\n` +
        `Sou a assistente virtual do *${condoName}*.\n\n` +
        `Gostaria de saber se você deseja continuar recebendo notificações do seu condomínio pelo WhatsApp, como:\n\n` +
        `📦 Chegada de encomendas\n` +
        `🚪 Autorizações de visitantes\n` +
        `📢 Avisos importantes\n` +
        `📅 Reservas de áreas comuns\n\n` +
        `Responda com:\n\n` +
        `✅ *SIM* — para continuar recebendo\n` +
        `❌ *NÃO* — para parar de receber\n\n` +
        `_Sua resposta nos ajuda a melhorar o serviço!_ 😊`

      const sendResult = await smartSend(
        BOTCONVERSA_API_KEY,
        resident.botconversa_id,
        phone,
        "text",
        msg,
        firstName,
        supabase,
        resident.id
      )

      // Log the send
      await supabase.from("optin_whatsapp_log").insert({
        perfil_id: resident.id,
        condominio_id: resident.condominio_id,
        phone,
        sent_at: new Date().toISOString(),
      })

      results.push(`${firstName} (${phone}): ${sendResult.success ? "✅" : "❌ " + sendResult.error}`)
      console.log(`[OptIn] Sent to ${firstName} (${phone}): ${sendResult.success ? "OK" : sendResult.error}`)

      // Small delay between sends
      if (residents.indexOf(resident) < residents.length - 1) {
        await new Promise(r => setTimeout(r, 2000))
      }
    }

    return new Response(JSON.stringify({ ok: true, sent: results.length, results }), {
      headers: { "Content-Type": "application/json" },
    })

  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("[OptIn] Error:", msg)
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }
})
