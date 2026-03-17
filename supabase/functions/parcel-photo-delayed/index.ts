// parcel-photo-delayed — Supabase Edge Function
// Waits 10-20 seconds (random), then sends parcel photo via botconversa-send
// Called by the tr_fn_encomenda_arrived trigger when photo_url is present

import { createAdminClient } from "../_shared/auth.ts"
import { sendMessage, ensureJpegUrl } from "../_shared/botconversa.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", Connection: "keep-alive" },
  })
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { photo_url, condominio_id, bloco, apto } = await req.json()

    if (!photo_url) {
      return jsonResponse({ skipped: true, reason: "No photo_url provided" })
    }

    const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY")
    if (!BOTCONVERSA_API_KEY) {
      return jsonResponse({ error: "BOTCONVERSA_API_KEY não configurada" }, 500)
    }

    // 1. Random delay: 10-20 seconds
    const delayMs = Math.floor(Math.random() * 10_000) + 10_000 // 10000-20000ms
    console.log(`⏳ Waiting ${delayMs}ms before sending parcel photo...`)
    await new Promise((resolve) => setTimeout(resolve, delayMs))

    // 2. Resolve recipients (same logic as botconversa-send por_apto)
    const supabase = createAdminClient()

    const { data: recipients, error } = await supabase
      .from("perfil")
      .select("id, nome_completo, botconversa_id")
      .eq("condominio_id", condominio_id)
      .eq("bloco_txt", bloco)
      .eq("apto_txt", apto)
      .eq("status_aprovacao", "aprovado")
      .eq("bloqueado", false)
      .not("botconversa_id", "is", null)

    if (error || !recipients || recipients.length === 0) {
      console.log("No recipients found for photo delivery")
      return jsonResponse({ skipped: true, reason: "No recipients found" })
    }

    // Deduplicate by botconversa_id
    const seen = new Set<string>()
    const unique = recipients.filter((r: any) => {
      if (!r.botconversa_id || seen.has(r.botconversa_id)) return false
      seen.add(r.botconversa_id)
      return true
    })

    console.log(`📸 Sending parcel photo to ${unique.length} recipient(s)`)

    // 3. Send photo as file to each recipient
    const results = []
    for (let i = 0; i < unique.length; i++) {
      const r = unique[i] as any
      const result = await sendMessage(
        BOTCONVERSA_API_KEY,
        r.botconversa_id,
        "file",
        ensureJpegUrl(photo_url)
      )
      results.push({ ...result, nome: r.nome_completo })

      // Rate limit between sends
      if (i < unique.length - 1) {
        await new Promise((resolve) => setTimeout(resolve, 2_000))
      }
    }

    const successCount = results.filter((r) => r.success).length
    console.log(`📸 Photo sent: ${successCount}/${results.length}`)

    return jsonResponse({
      sent: successCount,
      total: results.length,
      delay_ms: delayMs,
      results,
    })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error("parcel-photo-delayed error:", message)
    return jsonResponse({ error: message }, 500)
  }
})
