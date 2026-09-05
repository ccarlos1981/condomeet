import { createClient } from "npm:@supabase/supabase-js@2";
import { normalizePhone } from "../_shared/botconversa.ts";
import { dispatchSupportInboundAlert } from "../_shared/support_alert.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-evolution-token, token",
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

export function mapEvolutionStatus(statusRaw: unknown): string | null {
  if (statusRaw === undefined || statusRaw === null) return null;
  const s = String(statusRaw).toUpperCase().trim();
  if (s === "2" || s === "SERVER_ACK" || s === "SENT") return "sent";
  if (s === "3" || s === "DELIVERY_ACK" || s === "DELIVERED") return "delivered";
  if (s === "4" || s === "5" || s === "READ" || s === "PLAYED") return "read";
  if (s === "FAILED" || s === "ERROR") return "failed";
  if (s === "1" || s === "PENDING") return "pending";
  return null;
}

export function parseEvolutionUpsert(item: any): {
  fromMe: boolean;
  providerMessageId: string;
  remoteJid: string;
  cleanPhone: string;
  pushName: string;
  text: string;
  messageType: string;
} | null {
  if (!item) return null;
  const key = item.key || {};
  const fromMe = Boolean(key.fromMe);
  const providerMessageId = String(key.id || item.id || "");
  const remoteJid = String(key.remoteJid || item.remoteJid || "");

  // Ignorar mensagens de grupos (@g.us) ou status de broadcast
  if (remoteJid.includes("@g.us") || remoteJid.includes("status@broadcast")) {
    return null;
  }

  const rawPhone = remoteJid.replace(/@s\.whatsapp\.net$/i, "").replace(/\D/g, "");
  const cleanPhone = normalizePhone(rawPhone);

  const message = item.message || {};
  let text = "";
  let messageType = String(item.messageType || "text");

  if (message.conversation) {
    text = String(message.conversation);
  } else if (message.extendedTextMessage?.text) {
    text = String(message.extendedTextMessage.text);
  } else if (message.imageMessage?.caption) {
    text = String(message.imageMessage.caption);
    messageType = "image";
  } else if (message.documentMessage?.caption) {
    text = String(message.documentMessage.caption);
    messageType = "document";
  } else if (item.text) {
    text = String(item.text);
  }

  const pushName = String(item.pushName || "");

  return {
    fromMe,
    providerMessageId,
    remoteJid,
    cleanPhone,
    pushName,
    text,
    messageType,
  };
}

export async function handleEvolutionWebhook(req: Request): Promise<Response> {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed. Use POST." }, 405);
  }

  // ── 1. Validação de Autenticação / Segredo (FAIL-CLOSED) ────────────────
  const configuredSecret = Deno.env.get("EVOLUTION_WEBHOOK_SECRET");
  if (!configuredSecret) {
    console.error("[Evolution Webhook] Rejeitado: EVOLUTION_WEBHOOK_SECRET não configurado no ambiente.");
    return jsonResponse({ error: "Unauthorized: Invalid webhook secret." }, 403);
  }

  const authHeader = req.headers.get("x-evolution-token") ||
    req.headers.get("apikey") ||
    req.headers.get("token") ||
    req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");

  let body: any;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const bodyApiKey = body?.apikey;
  const providedToken = authHeader || bodyApiKey;

  if (!providedToken || providedToken !== configuredSecret) {
    console.warn("[Evolution Webhook] Rejeitado: Segredo inválido ou ausente.");
    return jsonResponse({ error: "Unauthorized: Invalid webhook secret." }, 403);
  }

  // ── 2. Validação Estrita da Instância ──────────────────────────────────────
  const expectedInstance = Deno.env.get("EVOLUTION_INSTANCE") ?? "condomeet-secundario-prod";
  const receivedInstance = body?.instance;

  if (!receivedInstance || receivedInstance !== expectedInstance) {
    console.warn(`[Evolution Webhook] Instância ignorada: recebida="${receivedInstance}", esperada="${expectedInstance}"`);
    return jsonResponse({
      status: "ignored_unknown_instance",
      instance: receivedInstance || null,
    }, 200);
  }

  const event = String(body?.event || "").trim();
  const SUPPORTED_EVENTS = ["messages.upsert", "messages.update", "connection.update"];

  // ── 3. Filtrar Eventos Não Suportados Imediatamente (Sem Overhead de DB) ──
  if (!SUPPORTED_EVENTS.includes(event)) {
    return jsonResponse({ status: "ignored", event }, 200);
  }

  // ── 4. Inicialização do Cliente Supabase ──────────────────────────────────
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "http://localhost:54321",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "anon_dummy_key",
  );

  // ── 5. Processamento: messages.upsert (Inbound) ───────────────────────────
  if (event === "messages.upsert") {
    const rawData = body.data;
    const items = Array.isArray(rawData) ? rawData : [rawData];
    const results = [];

    for (const item of items) {
      const parsed = parseEvolutionUpsert(item);
      if (!parsed) {
        results.push({ status: "ignored_group_or_invalid" });
        continue;
      }

      // Processar estritamente mensagens recebidas (fromMe === false)
      if (parsed.fromMe) {
        console.log(`[Evolution Webhook] Mensagem emitida ignorada (fromMe=true) id=${parsed.providerMessageId}`);
        results.push({ status: "ignored_from_me", messageId: parsed.providerMessageId });
        continue;
      }

      if (!parsed.cleanPhone) {
        results.push({ status: "ignored_empty_phone" });
        continue;
      }

      // Idempotência: Checar se o provider_message_id já foi persistido
      if (parsed.providerMessageId) {
        const { data: existing } = await supabase
          .from("whatsapp_outbox")
          .select("id")
          .eq("delivery_result->>provider_message_id", parsed.providerMessageId)
          .eq("status", "received")
          .limit(1)
          .maybeSingle();

        if (existing) {
          console.log(`[Evolution Webhook] Idempotência: mensagem id=${parsed.providerMessageId} já processada.`);
          results.push({ status: "duplicate_skipped", messageId: parsed.providerMessageId });
          continue;
        }
      }

      // Correlação com public.perfil
      let matchedPerfil: any = null;
      try {
        const { data: perfil } = await supabase
          .from("perfil")
          .select("id, condominio_id, nome_completo, bloco_txt, apto_txt")
          .or(`whatsapp.eq.${parsed.cleanPhone},whatsapp.eq.${parsed.cleanPhone.replace(/^55/, "")}`)
          .eq("status_aprovacao", "aprovado")
          .order("updated_at", { ascending: false })
          .limit(1)
          .maybeSingle();

        matchedPerfil = perfil;
      } catch (err: any) {
        console.warn("[Evolution Webhook] Erro ao correlacionar perfil:", err.message);
      }

      const firstName = matchedPerfil?.nome_completo
        ? matchedPerfil.nome_completo.split(" ")[0]
        : (parsed.pushName || "Morador");

      // Invocar RPC Canônica record_whatsapp_incoming_message
      try {
        const { data: outboxId, error: rpcErr } = await supabase.rpc(
          "record_whatsapp_incoming_message",
          {
            p_recipient_phone: parsed.cleanPhone,
            p_message_text: parsed.text || "Mensagem de mídia",
            p_first_name: firstName,
            p_perfil_id: matchedPerfil?.id || null,
            p_condominio_id: matchedPerfil?.condominio_id ? String(matchedPerfil.condominio_id) : null,
          },
        );

        if (rpcErr) {
          console.error("[Evolution Webhook] Erro na RPC record_whatsapp_incoming_message:", rpcErr.message);
          results.push({ status: "rpc_error", error: rpcErr.message });
          continue;
        }

        // Enriquecer delivery_result com metadados da Evolution
        if (outboxId) {
          try {
            await supabase
              .from("whatsapp_outbox")
              .update({
                delivery_result: {
                  provider: "EVOLUTION",
                  provider_message_id: parsed.providerMessageId || null,
                  instance: expectedInstance,
                  remoteJid: parsed.remoteJid,
                  pushName: parsed.pushName,
                  received_at: new Date().toISOString(),
                },
              })
              .eq("id", outboxId);
          } catch (evoUpdateErr: any) {
            console.warn("[Evolution Webhook] Aviso ao atualizar delivery_result:", evoUpdateErr.message);
          }

          // Disparar Alerta Interno de Suporte (Fase 4.24.25)
          try {
            await dispatchSupportInboundAlert({
              supabase,
              senderPhone: parsed.cleanPhone,
              inboundOutboxId: String(outboxId),
              providerMessageId: parsed.providerMessageId || null,
              callerFunction: "evolution-webhook",
            });
          } catch (alertErr: any) {
            console.error("[Evolution Webhook] Erro ao disparar alerta de suporte:", alertErr.message);
          }
        }

        results.push({
          status: "success",
          outboxId,
          correlated: Boolean(matchedPerfil),
          phone: parsed.cleanPhone,
        });
      } catch (insertErr: any) {
        console.error("[Evolution Webhook] Falha ao persistir inbound:", insertErr.message);
        results.push({ status: "insert_error", error: insertErr.message });
      }
    }

    return jsonResponse({ status: "success", event, results });
  }

  // ── 5. Processamento: messages.update (Status de Entrega / Leitura) ────────
  if (event === "messages.update") {
    const rawData = body.data;
    const items = Array.isArray(rawData) ? rawData : [rawData];
    const updateResults = [];

    for (const item of items) {
      const providerMsgId = item?.key?.id || item?.id;
      const statusRaw = item?.update?.status ?? item?.status;
      const statusMapped = mapEvolutionStatus(statusRaw);

      if (!providerMsgId || !statusMapped) {
        updateResults.push({ status: "skipped_no_id_or_unknown_status", rawStatus: statusRaw });
        continue;
      }

      // Atualizar estritamente mensagens pertencentes ao provedor EVOLUTION
      const { data: targetMsgs } = await supabase
        .from("whatsapp_outbox")
        .select("id, delivery_result, status")
        .eq("delivery_result->>provider_message_id", providerMsgId)
        .eq("delivery_result->>provider", "EVOLUTION")
        .limit(1);

      if (targetMsgs && targetMsgs.length > 0) {
        const target = targetMsgs[0];
        const updatedDeliveryResult = {
          ...target.delivery_result,
          evolution_delivery_status: statusMapped,
          evolution_delivery_updated_at: new Date().toISOString(),
        };

        const updatePayload: Record<string, any> = {
          delivery_result: updatedDeliveryResult,
        };

        if (statusMapped === "failed") {
          updatePayload.status = "failed";
          updatePayload.error_message = "Falha na entrega via Evolution API";
        }

        await supabase
          .from("whatsapp_outbox")
          .update(updatePayload)
          .eq("id", target.id);

        updateResults.push({
          status: "updated",
          outboxId: target.id,
          evolutionStatus: statusMapped,
        });
      } else {
        updateResults.push({ status: "msg_not_found_or_not_evolution", providerMsgId });
      }
    }

    return jsonResponse({ status: "success", event, updateResults });
  }

  // ── 6. Processamento: connection.update (Heartbeat da Sessão) ──────────────
  if (event === "connection.update") {
    const state = body.data?.state || body.data?.status || "unknown";
    console.log(`[Evolution Webhook] connection.update para ${expectedInstance}: state=${state}`);

    try {
      await supabase
        .from("whatsapp_health_status")
        .update({
          last_heartbeat: new Date().toISOString(),
          last_check_at: new Date().toISOString(),
        })
        .eq("id", "singleton");
    } catch (_) {}

    return jsonResponse({ status: "success", event, state });
  }

  // ── 7. Demais Eventos: Ignorar Silenciosamente ────────────────────────────
  return jsonResponse({ status: "ignored", event });
}

Deno.serve(handleEvolutionWebhook);

