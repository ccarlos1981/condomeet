import { createClient } from "npm:@supabase/supabase-js@2";
import { normalizePhone, sha256 } from "../_shared/botconversa.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-botconversa-token, token",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export interface ParsedBotConversaInbound {
  rawPhone: string;
  cleanPhone: string;
  messageText: string;
  firstName: string;
  subscriberId: string | null;
  messageId: string | null;
}

export function parseBotConversaInbound(body: any): ParsedBotConversaInbound | null {
  if (!body || typeof body !== "object") return null;

  // Extrair telefone suportando diferentes variações de payload
  const rawPhone = String(
    body.phone ||
    body.whatsapp ||
    body.subscriber?.phone ||
    body.contact?.phone ||
    body.recipient_phone ||
    ""
  ).trim();

  // Extrair texto da mensagem
  let messageText = "";
  if (typeof body.message === "string") {
    messageText = body.message;
  } else if (body.message && typeof body.message === "object") {
    messageText = String(body.message.text || body.message.value || body.message.body || "");
  } else if (body.text) {
    messageText = String(body.text);
  } else if (body.value) {
    messageText = String(body.value);
  } else if (body.last_message) {
    messageText = String(body.last_message);
  }

  messageText = messageText.trim();

  if (!rawPhone || !messageText) {
    return null;
  }

  const cleanPhone = normalizePhone(rawPhone);
  if (!cleanPhone || cleanPhone.length < 10) {
    return null;
  }

  // Extrair primeiro nome
  const firstName = String(
    body.first_name ||
    body.subscriber?.first_name ||
    body.contact?.first_name ||
    body.name ||
    "Morador"
  ).trim();

  // Extrair ID do subscriber / mensagem
  const subscriberId = body.subscriber_id
    ? String(body.subscriber_id)
    : body.subscriber?.id
    ? String(body.subscriber.id)
    : body.contact?.id
    ? String(body.contact.id)
    : null;

  const messageId = body.message_id
    ? String(body.message_id)
    : body.message?.id
    ? String(body.message.id)
    : null;

  return {
    rawPhone,
    cleanPhone,
    messageText,
    firstName,
    subscriberId,
    messageId,
  };
}

export async function handleBotConversaWebhook(req: Request): Promise<Response> {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed. Use POST." }, 405);
  }

  // ── 1. Validação de Autenticação / Segredo (FAIL-CLOSED) ────────────────
  const configuredSecret = Deno.env.get("BOTCONVERSA_WEBHOOK_SECRET");
  if (!configuredSecret) {
    console.error("[BotConversa Webhook] Rejeitado: BOTCONVERSA_WEBHOOK_SECRET não configurado no ambiente.");
    return jsonResponse({ error: "Unauthorized: Invalid webhook secret." }, 403);
  }

  const authHeader = req.headers.get("x-botconversa-token") ||
    req.headers.get("apikey") ||
    req.headers.get("token") ||
    req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");

  let body: any;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const bodyApiKey = body?.secret || body?.apikey || body?.token;
  const providedToken = authHeader || bodyApiKey;

  if (!providedToken || providedToken !== configuredSecret) {
    console.warn("[BotConversa Webhook] Rejeitado: Segredo inválido ou ausente.");
    return jsonResponse({ error: "Unauthorized: Invalid webhook secret." }, 403);
  }

  // ── 2. Parse do Payload ────────────────────────────────────────────────────
  const parsed = parseBotConversaInbound(body);
  if (!parsed) {
    return jsonResponse({
      error: "Bad Request: phone and message text are required and must be valid.",
    }, 400);
  }

  // ── 3. Inicialização do Cliente Supabase ──────────────────────────────────
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "http://localhost:54321",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "anon_dummy_key",
  );

  // ── 4. Correlação com Perfil (Canônico E.164) ──────────────────────────────
  const rawWithout55 = parsed.cleanPhone.startsWith("55")
    ? parsed.cleanPhone.slice(2)
    : parsed.cleanPhone;

  const { data: matchedPerfil } = await supabase
    .from("perfil")
    .select("id, condominio_id, nome_completo, whatsapp")
    .or(`whatsapp.eq.${parsed.cleanPhone},whatsapp.eq.${rawWithout55}`)
    .limit(1)
    .maybeSingle();

  // ── 5. Verificação de Idempotência (Prevenção de Duplicatas por Retry) ──────
  const twoMinutesAgo = new Date(Date.now() - 120_000).toISOString();
  const { data: recentInbounds } = await supabase
    .from("whatsapp_outbox")
    .select("id, created_at, message_content")
    .eq("recipient_phone", parsed.cleanPhone)
    .eq("status", "received")
    .gte("created_at", twoMinutesAgo);

  const isDuplicate = recentInbounds?.some((msg: any) => {
    const textInDb = msg.message_content?.value || "";
    return textInDb.trim() === parsed.messageText.trim();
  });

  if (isDuplicate) {
    console.log(`[BotConversa Webhook] Inbound duplicado ignorado para telefone=${parsed.cleanPhone}.`);
    return jsonResponse({
      status: "ignored_duplicate",
      phone: parsed.cleanPhone,
    }, 200);
  }

  // ── 6. Persistência Canônica via RPC ───────────────────────────────────────
  const effectiveFirstName = matchedPerfil?.nome_completo || parsed.firstName || "Morador";
  const { data: incomingId, error: rpcError } = await supabase.rpc(
    "record_whatsapp_incoming_message",
    {
      p_recipient_phone: parsed.cleanPhone,
      p_message_text: parsed.messageText,
      p_first_name: effectiveFirstName,
      p_perfil_id: matchedPerfil?.id || null,
      p_condominio_id: matchedPerfil?.condominio_id || null,
    },
  );

  if (rpcError || !incomingId) {
    console.error("[BotConversa Webhook] Erro ao invocar record_whatsapp_incoming_message:", rpcError);
    return jsonResponse({
      error: "Internal Server Error: Failed to record incoming message.",
      details: rpcError?.message,
    }, 500);
  }

  // ── 7. Enriquecer Registro com Metadados do Provedor BOTCONVERSA ──────────
  const nowIso = new Date().toISOString();
  const fallbackMessageId = `bc_${parsed.subscriberId || parsed.cleanPhone}_${Date.now()}`;
  const providerMsgId = parsed.messageId || fallbackMessageId;

  await supabase
    .from("whatsapp_outbox")
    .update({
      delivery_result: {
        provider: "BOTCONVERSA",
        provider_message_id: providerMsgId,
        resolved_subscriber_id: parsed.subscriberId,
        received_at: nowIso,
      },
    })
    .eq("id", incomingId);

  console.log(
    `[BotConversa Webhook] Inbound persistido com SUCESSO: id=${incomingId}, telefone=${parsed.cleanPhone}, provider=BOTCONVERSA, perfil=${matchedPerfil?.id || "avulso"}`,
  );

  return jsonResponse({
    status: "recorded",
    id: incomingId,
    phone: parsed.cleanPhone,
    provider: "BOTCONVERSA",
  }, 200);
}

// Deno Entrypoint
if (import.meta.main) {
  Deno.serve(handleBotConversaWebhook);
}
