// parcel-photo-delayed — Supabase Edge Function
// Waits 10-20 seconds (random), then sends parcel photo via UazAPI
// Called by the tr_fn_encomenda_arrived trigger when photo_url is present

import { createClient } from "npm:@supabase/supabase-js@2"
import { sendImageMessage, normalizePhone } from "../_shared/uazapi.ts"

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

function ensureJpegUrl(url: string): string {
  // If Supabase Storage URL, ensure it returns a proper image content type
  if (url.includes('supabase') && !url.includes('?')) {
    return url
  }
  return url
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

    const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")
    if (!UAZAPI_URL || !UAZAPI_TOKEN) {
      return jsonResponse({ error: "UAZAPI_URL or UAZAPI_TOKEN not configured" }, 500)
    }

    // 1. Random delay: 10-20 seconds
    const delayMs = Math.floor(Math.random() * 10_000) + 10_000
    console.log(`⏳ Waiting ${delayMs}ms before sending parcel photo...`)
    await new Promise((resolve) => setTimeout(resolve, delayMs))

    // 2. Resolve recipients
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    const { data: recipients, error } = await supabase
      .from("perfil")
      .select("id, nome_completo, whatsapp")
      .eq("condominio_id", condominio_id)
      .eq("bloco_txt", bloco)
      .eq("apto_txt", apto)
      .eq("status_aprovacao", "aprovado")
      .eq("bloqueado", false)
      .eq("notificacoes_whatsapp", true)
      .not("whatsapp", "is", null)

    if (error || !recipients || recipients.length === 0) {
      console.log("No recipients found for photo delivery")
      return jsonResponse({ skipped: true, reason: "No recipients found" })
    }

    // Deduplicate by whatsapp
    const seen = new Set<string>()
    const unique = recipients.filter((r: Record<string, unknown>) => {
      const wpp = (r.whatsapp as string)?.trim()
      if (!wpp || seen.has(wpp)) return false
      seen.add(wpp)
      return true
    })

    console.log(`📸 Sending parcel photo to ${unique.length} recipient(s)`)

    // 3. Send photo as image to each recipient
    const results = []
    for (let i = 0; i < unique.length; i++) {
      const r = unique[i] as Record<string, unknown>
      const phone = normalizePhone(r.whatsapp as string)
      const result = await sendImageMessage(
        UAZAPI_URL,
        UAZAPI_TOKEN,
        phone,
        ensureJpegUrl(photo_url),
        "📸 Foto da encomenda"
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
