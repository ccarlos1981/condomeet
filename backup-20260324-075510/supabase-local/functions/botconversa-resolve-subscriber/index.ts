// botconversa-resolve-subscriber — Supabase Edge Function v4
// Called by DB trigger when perfil.whatsapp is set/changed.
// Also supports resolving visitor contacts via save_to_table param.
// Auth: sb_secret_* key only (trigger-only, no user access).
// v3: Added retry logic (3 attempts with exponential backoff)
// v4: Fixed last_name requirement from BotConversa API

import { createClient } from "npm:@supabase/supabase-js@2"

const BOTCONVERSA_BASE_URL = "https://backend.botconversa.com.br/api/v1/webhook"
const MAX_RETRIES = 3
const BASE_DELAY_MS = 2000 // 2s, 4s, 8s

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

function isSecretKey(token: string): boolean {
  // Accept sb_secret_ keys
  if (token.startsWith("sb_secret_")) return true
  // Accept exact match with SUPABASE_SERVICE_ROLE_KEY env
  const envKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  if (envKey && token === envKey) return true
  // Accept JWT tokens with service_role
  try {
    const parts = token.split(".")
    if (parts.length === 3) {
      const payload = JSON.parse(atob(parts[1]))
      if (payload.role === "service_role") return true
    }
  } catch { /* not a valid JWT */ }
  return false
}

async function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

async function callBotConversaWithRetry(
  cleanPhone: string,
  firstName: string,
  lastName: string,
  apiKey: string
): Promise<{ ok: boolean; subscriberId: string | null; status: number; detail: string }> {
  let lastStatus = 0
  let lastDetail = ""

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      console.log(`BotConversa attempt ${attempt}/${MAX_RETRIES} for phone ${cleanPhone}`)
      
      const res = await fetch(`${BOTCONVERSA_BASE_URL}/subscriber/`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "API-KEY": apiKey,
        },
        body: JSON.stringify({
          phone: cleanPhone,
          first_name: firstName,
          last_name: lastName,
        }),
      })

      const resultText = await res.text()
      lastStatus = res.status
      lastDetail = resultText
      console.log(`BotConversa response (attempt ${attempt}): ${res.status} ${resultText}`)

      if (res.ok) {
        // Parse subscriber ID
        try {
          const data = JSON.parse(resultText)
          const subscriberId = String(data.id || data.subscriber_id || "")
          if (subscriberId) {
            return { ok: true, subscriberId, status: res.status, detail: resultText }
          }
        } catch {
          console.error(`Failed to parse BotConversa response (attempt ${attempt}):`, resultText)
        }
      }

      // Don't retry on 4xx client errors (except 429 rate limit)
      if (res.status >= 400 && res.status < 500 && res.status !== 429) {
        console.warn(`Client error ${res.status}, not retrying: ${resultText}`)
        break
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      console.error(`BotConversa fetch error (attempt ${attempt}):`, msg)
      lastDetail = msg
      lastStatus = 0
    }

    // Exponential backoff before retry
    if (attempt < MAX_RETRIES) {
      const delay = BASE_DELAY_MS * Math.pow(2, attempt - 1)
      console.log(`Waiting ${delay}ms before retry...`)
      await sleep(delay)
    }
  }

  return { ok: false, subscriberId: null, status: lastStatus, detail: lastDetail }
}

console.info("botconversa-resolve-subscriber server started (v5 — JWT service_role auth fix)")

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Use POST" }, 405)
  }

  try {
    // 1. Auth — only secret keys (triggers)
    const authHeader = req.headers.get("Authorization") ?? ""
    const token = authHeader.replace(/^Bearer\s+/i, "")
    if (!token || !isSecretKey(token)) {
      return jsonResponse({ error: "Unauthorized — trigger-only function" }, 401)
    }

    // 2. Parse request
    const body = await req.json()
    const { perfil_id, whatsapp, nome_completo, save_to_table, match_column } = body
    
    if (!whatsapp) {
      return jsonResponse({ error: "whatsapp is required" }, 400)
    }
    
    // perfil_id is required for perfil updates, optional for visitor contacts
    if (!perfil_id && !save_to_table) {
      return jsonResponse({ error: "perfil_id or save_to_table is required" }, 400)
    }

    // 3. Clean phone: remove non-digits, ensure 55 prefix
    let cleanPhone = whatsapp.replace(/\D/g, "")
    if (cleanPhone.length > 0 && !cleanPhone.startsWith("55")) {
      cleanPhone = "55" + cleanPhone
    }
    if (cleanPhone.length < 12) {
      console.warn(`Phone too short: ${cleanPhone}`)
      return jsonResponse({ error: "Phone number too short", phone: cleanPhone }, 400)
    }

    // 4. BotConversa API key
    const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY")
    if (!BOTCONVERSA_API_KEY) {
      return jsonResponse({ error: "BOTCONVERSA_API_KEY not configured" }, 500)
    }

    // 5. Create/upsert subscriber on BotConversa (with retry)
    // Split nome_completo into first_name + last_name (BotConversa requires both)
    const nameParts = (nome_completo || "").trim().split(/\s+/)
    const firstName = nameParts[0] || "Morador"
    const lastName = nameParts.length > 1 ? nameParts.slice(1).join(" ") : "."

    const result = await callBotConversaWithRetry(cleanPhone, firstName, lastName, BOTCONVERSA_API_KEY)

    if (!result.ok || !result.subscriberId) {
      return jsonResponse({
        error: "BotConversa API error after " + MAX_RETRIES + " attempts",
        status: result.status,
        detail: result.detail,
      }, 502)
    }

    const subscriberId = result.subscriberId

    // 6. Save botconversa_id
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    if (save_to_table && match_column) {
      // Save to custom table (e.g., contatos_visitantes)
      const columnToMatch = match_column || 'whatsapp'
      const { error: updateError } = await supabase
        .from(save_to_table)
        .update({ botconversa_id: subscriberId })
        .eq(columnToMatch, whatsapp)  // use original whatsapp (not cleaned)

      if (updateError) {
        // Try with cleaned phone
        const { error: updateError2 } = await supabase
          .from(save_to_table)
          .update({ botconversa_id: subscriberId })
          .eq(columnToMatch, cleanPhone)

        if (updateError2) {
          console.error(`Failed to update ${save_to_table}:`, updateError2)
        } else {
          console.log(`✅ Saved botconversa_id=${subscriberId} to ${save_to_table} (phone=${cleanPhone})`)
        }
      } else {
        console.log(`✅ Saved botconversa_id=${subscriberId} to ${save_to_table} (phone=${whatsapp})`)
      }
    }
    
    if (perfil_id) {
      // Update perfil (original behavior)
      const { error: updateError } = await supabase
        .from("perfil")
        .update({ botconversa_id: subscriberId })
        .eq("id", perfil_id)

      if (updateError) {
        console.error(`Failed to update perfil ${perfil_id}:`, updateError)
        return jsonResponse({
          error: "Failed to update perfil",
          detail: updateError.message,
          subscriber_id: subscriberId,
        }, 500)
      }

      console.log(`✅ Resolved botconversa_id=${subscriberId} for perfil=${perfil_id} (phone=${cleanPhone})`)
    }

    return jsonResponse({
      success: true,
      perfil_id: perfil_id || null,
      botconversa_id: subscriberId,
      phone: cleanPhone,
      saved_to: save_to_table || 'perfil',
    })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error("Unexpected error:", message)
    return jsonResponse({ error: message }, 500)
  }
})
