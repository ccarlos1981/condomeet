// whatsapp-chatbot — Supabase Edge Function
// Receives WhatsApp messages via UazAPI webhook, processes with Gemini AI,
// and responds to residents with context-aware answers.
// Also executes actions (create visitor auth, escalate, block, etc.)

import { createClient } from "npm:@supabase/supabase-js@2"
import { parseWebhook, sendTextMessage, normalizePhone } from "../_shared/uazapi.ts"
import { buildSystemPrompt, type MoradorContext } from "./system-prompt.ts"
import { executeActions } from "./actions.ts"

// ── Constants ─────────────────────────────────────────────────────────────

const GEMINI_MODEL = "gemini-2.5-flash"
const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models"
const MAX_HISTORY = 10 // last N messages for context
const HISTORY_TTL_HOURS = 24 // only load messages from last 24h

// ── Admin phone numbers that can control the bot ──────────────────────────
const ADMIN_PHONES = ["5531992707070", "5531994707070", "31992707070", "31994707070"]

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, token",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", Connection: "keep-alive" },
  })
}

// ── In-memory deduplication (30s window) ──────────────────────────────────

const recentMessages = new Map<string, number>()
const DEDUP_TTL_MS = 30_000

function isDuplicate(key: string): boolean {
  const now = Date.now()
  // Clean old entries
  for (const [k, ts] of recentMessages) {
    if (now - ts > DEDUP_TTL_MS) recentMessages.delete(k)
  }
  if (recentMessages.has(key)) {
    console.log(`[Dedup] Duplicate message blocked: ${key}`)
    return true
  }
  recentMessages.set(key, now)
  return false
}

// ── Gemini API call ───────────────────────────────────────────────────────

interface GeminiMessage {
  role: "user" | "model"
  parts: Array<{ text: string }>
}

async function callGemini(
  apiKey: string,
  systemPrompt: string,
  history: GeminiMessage[],
  userMessage: string
): Promise<string> {
  const url = `${GEMINI_API_URL}/${GEMINI_MODEL}:generateContent?key=${apiKey}`

  const contents: GeminiMessage[] = [
    ...history,
    { role: "user", parts: [{ text: userMessage }] },
  ]

  const requestBody = {
    system_instruction: {
      parts: [{ text: systemPrompt }],
    },
    contents,
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 1024,
    },
  }

  // Retry with exponential backoff for 429 errors
  const MAX_RETRIES = 2
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(requestBody),
    })

    if (res.ok) {
      const data = await res.json()
      // For thinking models (2.5+), the actual response is in the LAST part
      // Earlier parts contain thinking tokens
      const parts = data?.candidates?.[0]?.content?.parts || []
      const responsePart = parts.filter((p: Record<string, unknown>) => !p.thought).pop()
      return responsePart?.text || parts[parts.length - 1]?.text || ""
    }

    const errText = await res.text()

    // Rate limit — retry with backoff
    if (res.status === 429 && attempt < MAX_RETRIES) {
      const delayMs = (attempt + 1) * 2000 // 2s, 4s
      console.warn(`[Gemini] Rate limited (429), retrying in ${delayMs}ms (attempt ${attempt + 1}/${MAX_RETRIES})`)
      await new Promise(r => setTimeout(r, delayMs))
      continue
    }

    console.error(`[Gemini] Error ${res.status} URL=${url.split('?')[0]}: ${errText.substring(0, 500)}`)
    throw new Error(`Gemini API error: ${res.status} - ${errText.substring(0, 200)}`)
  }

  throw new Error("Gemini API: max retries exceeded")
}

// ── Parse Gemini JSON response ────────────────────────────────────────────

interface GeminiResponse {
  message: string
  actions: Array<{ type: string; params?: Record<string, unknown> }>
}

function parseGeminiResponse(raw: string): GeminiResponse {
  // Helper to try parsing JSON from a string
  function tryParseJson(str: string): GeminiResponse | null {
    try {
      const parsed = JSON.parse(str)
      if (parsed.message || parsed.text) {
        return {
          message: (parsed.message || parsed.text || "").replace(/\\n/g, "\n"),
          actions: Array.isArray(parsed.actions) ? parsed.actions : [],
        }
      }
    } catch { /* not valid JSON */ }
    return null
  }

  // 1. Try to parse raw as JSON directly
  const direct = tryParseJson(raw)
  if (direct) return direct

  // 2. Try to extract JSON from markdown code block ```json ... ```
  const jsonMatch = raw.match(/```(?:json)?\s*([\s\S]*?)\s*```/)
  if (jsonMatch) {
    const fromBlock = tryParseJson(jsonMatch[1])
    if (fromBlock) return fromBlock
  }

  // 3. Try to find JSON object anywhere in the text (for thinking models)
  const braceMatch = raw.match(/\{[\s\S]*"message"\s*:\s*"[\s\S]*?\}/)
  if (braceMatch) {
    const fromBrace = tryParseJson(braceMatch[0])
    if (fromBrace) return fromBrace
  }

  // 4. Fallback: treat as plain text response
  console.warn("[Gemini] Could not parse JSON response, using raw text")
  return { message: raw, actions: [] }
}

// ── Check if message should be ignored ────────────────────────────────────

function shouldIgnoreMessage(text: string, messageType: string): boolean {
  // Accept known text message types from UazAPI
  const textTypes = ["text", "unknown", "conversation", "extendedtextmessage", "buttonsresponsemessage", "listresponsemessage"]
  const normalizedType = messageType.toLowerCase()
  
  // Ignore non-text messages (images, audio, video, stickers, etc.)
  if (!textTypes.includes(normalizedType)) return true

  // Ignore empty messages
  if (!text || text.trim().length === 0) return true

  // Ignore pure emoji messages (only emojis and spaces)
  const emojiRegex = /^[\p{Emoji_Presentation}\p{Emoji}\s\u200d\ufe0f]+$/u
  if (emojiRegex.test(text.trim())) return true

  return false
}

// ── Main handler ──────────────────────────────────────────────────────────

console.info("whatsapp-chatbot server started")

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Use POST" }, 405)
  }

  try {
    // 1. Parse incoming webhook
    let body: Record<string, unknown>
    try {
      body = await req.json()
    } catch {
      return jsonResponse({ error: "Invalid JSON body" }, 400)
    }

    console.log("[Webhook] Received:", JSON.stringify(body).substring(0, 500))

    const incoming = parseWebhook(body)
    if (!incoming) {
      return jsonResponse({ skipped: true, reason: "Could not parse webhook" })
    }


    // Ignore group messages
    if (incoming.isGroup) {
      return jsonResponse({ skipped: true, reason: "Group message ignored" })
    }

    // ★ Ignore outgoing messages (sent by our own number) — prevents self-reply loop
    if (incoming.fromMe) {
      console.log(`[Webhook] Ignoring outgoing message (fromMe=true) to: ${incoming.phone}`)
      return jsonResponse({ skipped: true, reason: "Outgoing message (fromMe) ignored" })
    }

    // Ignore non-text / emoji-only messages
    if (shouldIgnoreMessage(incoming.text, incoming.messageType)) {
      console.log(`[Webhook] Ignoring message: type=${incoming.messageType}, text="${incoming.text.substring(0, 50)}"`)
      return jsonResponse({ skipped: true, reason: "Non-text or emoji ignored" })
    }

    // Deduplication: prevent processing same message twice
    const dedupKey = `${incoming.phone}:${incoming.messageId || incoming.text.substring(0, 50)}`
    if (isDuplicate(dedupKey)) {
      return jsonResponse({ skipped: true, reason: "Duplicate message" })
    }

    console.log(`[Webhook] From: ${incoming.phone}, Type: ${incoming.messageType}, Text: "${incoming.text.substring(0, 100)}"`)

    // 2. Initialize Supabase admin client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // ── MAGIC WORD: admin can pause/resume bot ────────────────────────────
    const isAdmin = ADMIN_PHONES.some(p => incoming.phone.replace(/\D/g, '').endsWith(p.replace(/\D/g, '')))
    if (isAdmin) {
      const cmd = incoming.text.trim().toUpperCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
      const UAZAPI_URL_tmp = Deno.env.get("UAZAPI_URL") ?? ""
      const UAZAPI_TOKEN_tmp = Deno.env.get("UAZAPI_TOKEN") ?? ""

      if (cmd === "DESATIVAR" || cmd === "PAUSAR") {
        await supabase.from("bot_config").update({
          ativo: false,
          desativado_por: incoming.phone,
          desativado_em: new Date().toISOString(),
        }).eq("id", 1)
        await sendTextMessage(UAZAPI_URL_tmp, UAZAPI_TOKEN_tmp, incoming.phone,
          "🔴 Bot DESATIVADO. Atenda os moradores normalmente. Quando terminar, envie ATIVAR.")
        return jsonResponse({ ok: true, action: "bot_desativado" })
      }

      if (cmd === "ATIVAR" || cmd === "REATIVAR") {
        await supabase.from("bot_config").update({
          ativo: true,
          reativado_em: new Date().toISOString(),
        }).eq("id", 1)
        await sendTextMessage(UAZAPI_URL_tmp, UAZAPI_TOKEN_tmp, incoming.phone,
          "🟢 Bot ATIVADO. Voltei a atender os moradores automaticamente!")
        return jsonResponse({ ok: true, action: "bot_ativado" })
      }

      if (cmd === "STATUS") {
        const { data: cfg } = await supabase.from("bot_config").select("ativo, desativado_em, reativado_em").eq("id", 1).single()
        const statusMsg = cfg?.ativo
          ? `🟢 Bot está ATIVO.${cfg.reativado_em ? ` Reativado em: ${new Date(cfg.reativado_em).toLocaleString("pt-BR")}` : ""}`
          : `🔴 Bot está DESATIVADO.${cfg?.desativado_em ? ` Desde: ${new Date(cfg.desativado_em).toLocaleString("pt-BR")}` : ""}`
        await sendTextMessage(UAZAPI_URL_tmp, UAZAPI_TOKEN_tmp, incoming.phone, statusMsg)
        return jsonResponse({ ok: true, action: "status_enviado" })
      }

      // Admin sent something else — let it fall through normally (or skip)
      return jsonResponse({ skipped: true, reason: "Admin message, not a command" })
    }
    // ─────────────────────────────────────────────────────────────────────

    // 3. Get API keys
    const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")
    const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")

    if (!UAZAPI_URL || !UAZAPI_TOKEN) {
      console.error("UAZAPI_URL or UAZAPI_TOKEN not configured")
      return jsonResponse({ error: "UazAPI not configured" }, 500)
    }
    if (!GEMINI_API_KEY) {
      console.error("GEMINI_API_KEY not configured")
      return jsonResponse({ error: "Gemini API not configured" }, 500)
    }

    // ── Check if bot is active ────────────────────────────────────────────
    const { data: botCfg } = await supabase.from("bot_config").select("ativo").eq("id", 1).single()
    if (botCfg && !botCfg.ativo) {
      console.log("[Bot] Bot is DISABLED — skipping response")
      return jsonResponse({ skipped: true, reason: "Bot desativado pelo admin" })
    }
    // ─────────────────────────────────────────────────────────────────────

    // 4. Identify resident by phone number
    // Try matching with and without DDI prefix
    const phoneVariants = [
      incoming.phone,
      incoming.phone.startsWith("55") ? incoming.phone.substring(2) : `55${incoming.phone}`,
    ]

    let perfil: any = null
    for (const variant of phoneVariants) {
      const { data } = await supabase
        .from("perfil")
        .select("id, nome_completo, bloco_txt, apto_txt, condominio_id, tipo_morador, papel_sistema, status_aprovacao, whatsapp, notificacoes_whatsapp")
        .eq("whatsapp", variant)
        .eq("status_aprovacao", "aprovado")
        .limit(1)
        .maybeSingle()

      if (data) {
        perfil = data
        break
      }
    }

    // Also try matching without the 9th digit or with it
    if (!perfil) {
      const phone = incoming.phone.startsWith("55") ? incoming.phone : `55${incoming.phone}`
      // Try without 9th digit (55 + DD + 8 digits → remove 5th char which is the 9)
      if (phone.length === 13) {
        const without9 = phone.substring(0, 4) + phone.substring(5)
        const { data } = await supabase
          .from("perfil")
          .select("id, nome_completo, bloco_txt, apto_txt, condominio_id, tipo_morador, papel_sistema, status_aprovacao, whatsapp, notificacoes_whatsapp")
          .eq("whatsapp", without9)
          .eq("status_aprovacao", "aprovado")
          .limit(1)
          .maybeSingle()

        if (data) perfil = data
      }
      // Try with 9th digit
      if (!perfil && phone.length === 12) {
        const with9 = phone.substring(0, 4) + "9" + phone.substring(4)
        const { data } = await supabase
          .from("perfil")
          .select("id, nome_completo, bloco_txt, apto_txt, condominio_id, tipo_morador, papel_sistema, status_aprovacao, whatsapp, notificacoes_whatsapp")
          .eq("whatsapp", with9)
          .eq("status_aprovacao", "aprovado")
          .limit(1)
          .maybeSingle()

        if (data) perfil = data
      }
    }

    if (!perfil) {
      console.log(`[Webhook] No approved profile found for phone: ${incoming.phone}`)
      // Send a polite response to unidentified users
      await sendTextMessage(
        UAZAPI_URL,
        UAZAPI_TOKEN,
        incoming.phone,
        "Olá! 👋 Não consegui identificar seu número no nosso sistema. " +
        "Se você é morador, verifique se seu número de celular está cadastrado corretamente no aplicativo Condomeet. " +
        "Caso precise de ajuda, procure o síndico do seu condomínio."
      )
      return jsonResponse({ skipped: true, reason: "Profile not found" })
    }

    // Check if notifications are blocked
    if (perfil.notificacoes_whatsapp === false) {
      console.log(`[Webhook] User ${perfil.id} has opted out of WhatsApp notifications`)
      return jsonResponse({ skipped: true, reason: "User opted out" })
    }

    console.log(`[Webhook] Identified: ${perfil.nome_completo} (${perfil.bloco_txt}/${perfil.apto_txt})`)

    // 5. Fetch context data for the resident's unit

    // Encomendas pendentes da unidade
    const { data: encomendas } = await supabase
      .from("encomendas")
      .select("tipo, arrival_time, tracking_code, observacao, status")
      .eq("condominio_id", perfil.condominio_id)
      .eq("bloco", perfil.bloco_txt)
      .eq("apto", perfil.apto_txt)
      .eq("status", "pending")
      .order("arrival_time", { ascending: false })
      .limit(5)

    // Autorizações de visitante ativas da unidade
    const { data: autorizacoes } = await supabase
      .from("convites")
      .select("guest_name, visitor_type, validity_date, status")
      .eq("resident_id", perfil.id)
      .eq("status", "active")
      .gte("validity_date", new Date().toISOString().split("T")[0])
      .order("validity_date", { ascending: true })
      .limit(5)

    // Fetch condominium name
    const { data: condo } = await supabase
      .from("condominios")
      .select("nome")
      .eq("id", perfil.condominio_id)
      .single()

    // 6. Load conversation history
    const cutoff = new Date(Date.now() - HISTORY_TTL_HOURS * 60 * 60 * 1000).toISOString()
    const { data: historyRows } = await supabase
      .from("chatbot_conversas")
      .select("role, content")
      .eq("whatsapp", incoming.phone)
      .gte("created_at", cutoff)
      .order("created_at", { ascending: true })
      .limit(MAX_HISTORY)

    const geminiHistory: GeminiMessage[] = (historyRows || []).map((row: any) => ({
      role: row.role === "user" ? "user" : "model",
      parts: [{ text: row.content }],
    }))

    // 7. Build system prompt with context
    const moradorCtx: MoradorContext = {
      nome: perfil.nome_completo,
      primeiroNome: perfil.nome_completo?.split(" ")[0] || "Morador",
      bloco: perfil.bloco_txt,
      apto: perfil.apto_txt,
      condominioNome: condo?.nome || "Condomínio",
      tipoMorador: perfil.tipo_morador || perfil.papel_sistema || "Morador",
      encomendasPendentes: encomendas || [],
      autorizacoesAtivas: autorizacoes || [],
    }

    const systemPrompt = buildSystemPrompt(moradorCtx)

    // 8. Call Gemini API
    let geminiResponse: GeminiResponse
    try {
      console.log(`[Gemini] Calling with ${geminiHistory.length} history messages`)
      const geminiRaw = await callGemini(GEMINI_API_KEY, systemPrompt, geminiHistory, incoming.text)
      console.log(`[Gemini] Raw response: ${geminiRaw.substring(0, 300)}`)
      geminiResponse = parseGeminiResponse(geminiRaw)
    } catch (geminiErr: unknown) {
      const errMsg = geminiErr instanceof Error ? geminiErr.message : String(geminiErr)
      console.error(`[Gemini] Failed: ${errMsg}`)

      // Send friendly fallback message instead of crashing
      const fallbackMsg = `Oi, ${moradorCtx.primeiroNome}! 😊 No momento estou com uma dificuldade técnica temporária. Tente novamente em alguns minutos. Se for urgente, digite "atendente" que chamarei um especialista para você!`

      await sendTextMessage(UAZAPI_URL, UAZAPI_TOKEN, incoming.phone, fallbackMsg)

      // Save the failed interaction for debugging
      await supabase.from("chatbot_conversas").insert([
        { whatsapp: incoming.phone, perfil_id: perfil.id, condominio_id: perfil.condominio_id, role: "user", content: incoming.text },
        { whatsapp: incoming.phone, perfil_id: perfil.id, condominio_id: perfil.condominio_id, role: "system", content: `[ERRO] ${errMsg}` },
      ])

      return jsonResponse({ error: errMsg, fallback_sent: true })
    }

    // 9. Execute actions if any
    let actionResults: any[] = []
    if (geminiResponse.actions.length > 0) {
      console.log(`[Actions] Executing ${geminiResponse.actions.length} action(s):`, geminiResponse.actions.map(a => a.type))

      actionResults = await executeActions(geminiResponse.actions, {
        supabase,
        perfilId: perfil.id,
        condominioId: perfil.condominio_id,
        bloco: perfil.bloco_txt,
        apto: perfil.apto_txt,
        moradorNome: perfil.nome_completo,
        uazapiUrl: UAZAPI_URL,
        uazapiToken: UAZAPI_TOKEN,
      })

      console.log("[Actions] Results:", actionResults)
    }

    // 10. Send response to morador via UazAPI
    const sendResult = await sendTextMessage(
      UAZAPI_URL,
      UAZAPI_TOKEN,
      incoming.phone,
      geminiResponse.message
    )

    // 11. Save conversation to history
    await supabase.from("chatbot_conversas").insert([
      {
        whatsapp: incoming.phone,
        perfil_id: perfil.id,
        condominio_id: perfil.condominio_id,
        role: "user",
        content: incoming.text,
      },
      {
        whatsapp: incoming.phone,
        perfil_id: perfil.id,
        condominio_id: perfil.condominio_id,
        role: "assistant",
        content: geminiResponse.message,
        actions_executed: actionResults.length > 0 ? actionResults : null,
      },
    ])

    return jsonResponse({
      success: sendResult.success,
      message_sent: sendResult.success,
      actions_executed: actionResults,
      morador: `${perfil.nome_completo} (${perfil.bloco_txt}/${perfil.apto_txt})`,
    })

  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error)
    console.error("[Webhook] Unexpected error:", msg)
    return jsonResponse({ error: msg }, 500)
  }
})
