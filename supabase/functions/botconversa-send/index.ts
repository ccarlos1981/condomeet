// botconversa-send — Supabase Edge Function
// Sends WhatsApp messages via BotConversa API to resolved recipients
// Authorization: checks features_config for 'botconversa_send' function access

import { authorizeRequest, createAdminClient } from "../_shared/auth.ts"
import { sendToRecipients } from "../_shared/botconversa.ts"

// ── Types ─────────────────────────────────────────────────────────────────

interface SendRequest {
  msg: string
  tipo: "text" | "texto" | "file"
  condominio_id: string
  bloco?: string
  apto?: string
  modo_envio:
    | "por_apto"
    | "por_bloco"
    | "por_condominio"
    | "por_perfil"
    | "por_morador"
    | "por_botconversa"
  tipo_notificacao?: string
  perfil?: string
  user_id?: string
  botconversa_id?: string
  flow_id?: number
}

interface Recipient {
  id: string
  nome_completo: string
  botconversa_id: string
}

// ── Constants ─────────────────────────────────────────────────────────────

const FUNCTION_ID = "botconversa_send"
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const VALID_MODOS = [
  "por_apto",
  "por_bloco",
  "por_condominio",
  "por_perfil",
  "por_morador",
  "por_botconversa",
] as const

// ── Input validation ──────────────────────────────────────────────────────

function isValidUUID(value: string): boolean {
  return UUID_REGEX.test(value)
}

function validateRequest(
  params: SendRequest
): { valid: true } | { valid: false; error: string } {
  if (!params.msg || typeof params.msg !== "string") {
    return { valid: false, error: "msg é obrigatório e deve ser string" }
  }
  if (
    !params.condominio_id ||
    typeof params.condominio_id !== "string" ||
    !isValidUUID(params.condominio_id)
  ) {
    return { valid: false, error: "condominio_id é obrigatório e deve ser UUID válido" }
  }
  if (!params.modo_envio || !VALID_MODOS.includes(params.modo_envio as any)) {
    return { valid: false, error: `modo_envio inválido. Valores aceitos: ${VALID_MODOS.join(", ")}` }
  }
  if (params.user_id && !isValidUUID(params.user_id)) {
    return { valid: false, error: "user_id deve ser UUID válido" }
  }
  if (params.msg.length > 4096) {
    return { valid: false, error: "msg excede o limite de 4096 caracteres" }
  }
  return { valid: true }
}

function normalizeTipo(tipo: string): "text" | "file" {
  if (tipo === "texto" || tipo === "text") return "text"
  return "file"
}

// ── Recipient resolution ──────────────────────────────────────────────────

async function resolveRecipients(
  supabase: any,
  params: SendRequest
): Promise<Recipient[]> {
  const { modo_envio, condominio_id, bloco, apto, perfil, user_id, botconversa_id } = params

  const baseFilters = (query: any) =>
    query
      .eq("status_aprovacao", "aprovado")
      .eq("bloqueado", false)
      .eq("notificacoes_whatsapp", true)
      .not("botconversa_id", "is", null)

  let query: any

  switch (modo_envio) {
    case "por_apto": {
      query = supabase.from("perfil").select("id, nome_completo, botconversa_id").eq("condominio_id", condominio_id)
      if (bloco) query = query.eq("bloco_txt", bloco)
      if (apto) query = query.eq("apto_txt", apto)
      query = baseFilters(query)
      break
    }
    case "por_bloco": {
      query = supabase.from("perfil").select("id, nome_completo, botconversa_id").eq("condominio_id", condominio_id)
      if (bloco) query = query.eq("bloco_txt", bloco)
      query = baseFilters(query)
      break
    }
    case "por_condominio": {
      query = baseFilters(
        supabase.from("perfil").select("id, nome_completo, botconversa_id").eq("condominio_id", condominio_id)
      )
      break
    }
    case "por_perfil": {
      query = supabase.from("perfil").select("id, nome_completo, botconversa_id").eq("condominio_id", condominio_id)
      if (perfil) query = query.eq("papel_sistema", perfil)
      query = baseFilters(query)
      break
    }
    case "por_morador": {
      if (!user_id) return []
      query = baseFilters(
        supabase.from("perfil").select("id, nome_completo, botconversa_id").eq("condominio_id", condominio_id).eq("id", user_id)
      )
      break
    }
    case "por_botconversa": {
      if (!botconversa_id) return []
      query = supabase.from("perfil").select("id, nome_completo, botconversa_id").eq("botconversa_id", botconversa_id)
      break
    }
    default:
      return []
  }

  const { data, error } = await query
  if (error) {
    console.error("Error querying recipients:", error)
    return []
  }
  return (data || []).filter((r: any) => r.botconversa_id?.length > 0)
}

// ── In-memory deduplication (30s window) ──────────────────────────────────

const recentMessages = new Map<string, number>()
const DEDUP_TTL_MS = 30_000

function isDuplicate(params: SendRequest): boolean {
  const key = `${params.condominio_id}:${params.bloco || ""}:${params.apto || ""}:${params.modo_envio}:${params.tipo_notificacao || ""}:${params.tipo}`
  const now = Date.now()
  for (const [k, ts] of recentMessages) {
    if (now - ts > DEDUP_TTL_MS) recentMessages.delete(k)
  }
  if (recentMessages.has(key)) {
    console.log(`Duplicate message blocked: ${key}`)
    return true
  }
  recentMessages.set(key, now)
  return false
}

// ── CORS + response helpers ───────────────────────────────────────────────

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

// ── Main handler ──────────────────────────────────────────────────────────

console.info("botconversa-send server started")

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Método não permitido. Use POST." }, 405)
  }

  try {
    let params: SendRequest
    try {
      params = await req.json()
    } catch {
      return jsonResponse({ error: "Body JSON inválido" }, 400)
    }

    // 1. Validate input
    const validation = validateRequest(params)
    if (!validation.valid) {
      return jsonResponse({ error: validation.error }, 400)
    }

    const tipoNormalized = normalizeTipo(params.tipo || "text")

    // 2. Deduplication
    if (isDuplicate(params)) {
      return jsonResponse({ skipped: true, reason: "Mensagem duplicada (30s window)" })
    }

    // 3. BotConversa API key
    const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY")
    if (!BOTCONVERSA_API_KEY) {
      console.error("BOTCONVERSA_API_KEY not configured")
      return jsonResponse({ error: "BOTCONVERSA_API_KEY não configurada" }, 500)
    }

    // 4. Initialize Supabase admin client
    const supabase = createAdminClient()

    // 5. ── AUTHORIZATION ──────────────────────────────────────────────
    const authResult = await authorizeRequest(
      supabase,
      req,
      params.condominio_id,
      FUNCTION_ID
    )

    if (!authResult.authorized) {
      return jsonResponse({ error: authResult.error }, authResult.status)
    }

    console.log(
      `Authorized: ${authResult.profile.nome_completo} (${authResult.profile.papel_sistema}) → ${FUNCTION_ID}`
    )

    // 6. Resolve recipients
    const recipients = await resolveRecipients(supabase, params)

    if (recipients.length === 0) {
      return jsonResponse({
        sent: 0,
        total: 0,
        message: "Nenhum destinatário encontrado com botconversa_id",
      })
    }

    // Deduplicate by botconversa_id
    const seen = new Set<string>()
    const uniqueRecipients = recipients.filter((r) => {
      if (seen.has(r.botconversa_id)) return false
      seen.add(r.botconversa_id)
      return true
    })

    console.log(
      `Sending ${tipoNormalized} to ${uniqueRecipients.length} recipient(s) via ${params.modo_envio}`
    )

    // 7. Send using shared module
    const results = await sendToRecipients(
      BOTCONVERSA_API_KEY,
      uniqueRecipients,
      params.msg,
      tipoNormalized,
      { flowId: params.flow_id, personalizeMsg: true }
    )

    const successCount = results.filter((r) => r.success).length
    const failedResults = results.filter((r) => !r.success)

    console.log(`BotConversa: sent ${successCount}/${results.length} messages`)
    if (failedResults.length > 0) {
      console.error("Failed sends:", JSON.stringify(failedResults))
    }

    return jsonResponse({
      sent: successCount,
      total: results.length,
      failed: failedResults.length,
      results,
    })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error("Unexpected error:", message)
    return jsonResponse({ error: message }, 500)
  }
})
