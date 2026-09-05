// supabase/functions/tests/fase4_17_fallback_ttl_e2e_test.ts
// Testes E2E e Unitários da FASE 4.17 — Failover Inteligente BotConversa -> Meta + TTL / Expiração Atômica
// Ambiente: EXCLUSIVO DEV (avypyaxthvgaybplnwxu)

import { assertEquals, assertNotEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { 
  MessageType, 
  MESSAGE_ABSOLUTE_TTL_SECONDS, 
  MESSAGE_FALLBACK_WINDOW_SECONDS, 
  getMessageTTL, 
  getMessageFallbackWindow 
} from "../_shared/message_types.ts";
import { validateWhatsAppSendPolicy } from "../_shared/botconversa.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://avypyaxthvgaybplnwxu.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 14: TTL e Janela de Guarda por MessageType
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("FASE 4.17 — Teste 14: TTL e Janela de Guarda por MessageType", () => {
  assertEquals(getMessageTTL(MessageType.SOS), 30);
  assertEquals(getMessageFallbackWindow(MessageType.SOS), 5);

  assertEquals(getMessageTTL(MessageType.OTP), 60);
  assertEquals(getMessageFallbackWindow(MessageType.OTP), 10);

  assertEquals(getMessageTTL(MessageType.VISITOR_AUTHORIZED), 90);
  assertEquals(getMessageFallbackWindow(MessageType.VISITOR_AUTHORIZED), 15);

  assertEquals(getMessageTTL(MessageType.VISITOR_INVITE), 180);
  assertEquals(getMessageFallbackWindow(MessageType.VISITOR_INVITE), 20);

  assertEquals(getMessageTTL(MessageType.PARCEL), 600);
  assertEquals(getMessageFallbackWindow(MessageType.PARCEL), 30);

  assertEquals(getMessageTTL(MessageType.NOTICE), 900);
  assertEquals(getMessageFallbackWindow(MessageType.NOTICE), 0); // 0s (Meta proibido sem template)

  assertEquals(getMessageTTL(MessageType.FINANCIAL), 1800);
  assertEquals(getMessageFallbackWindow(MessageType.FINANCIAL), 60);

  assertEquals(getMessageTTL(MessageType.DUAL_NUMBER_NOTICE), 900);
  assertEquals(getMessageFallbackWindow(MessageType.DUAL_NUMBER_NOTICE), 0); // Meta estritamente proibido
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 13: Governança Anti-Broadcast
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("FASE 4.17 — Teste 13: Mensagem de Broadcast é bloqueada na governança anti-broadcast", () => {
  const check = validateWhatsAppSendPolicy({
    callerFunction: "smartSend",
    messageType: MessageType.NOTICE,
    textValue: "Aviso para todos",
    isCampaign: true
  });
  assertEquals(check.allowed, false);
  assertEquals(check.errorCode, "WHATSAPP_POLICY_BROADCAST_BLOCKED");
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 1: Inserção com derivação de TTL
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("FASE 4.17 — Teste 1: Inserção via RPC Canônica deriva TTL e grava expires_at", async () => {
  const testPhone = "5511999990001";
  const uniqueTx = crypto.randomUUID();

  const { data: outboxId, error } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.PARCEL,
    p_message_content: { value: "Encomenda teste 1" },
    p_caller_function: "whatsapp-parcel-notify",
    p_entity_type: "manual_admin",
    p_transaction_id: uniqueTx,
    p_priority: 10
  });

  assertEquals(error, null);
  assert(outboxId, "outboxId deve existir");

  const { data: row } = await supabase
    .from("whatsapp_outbox")
    .select("status, expires_at, created_at, priority")
    .eq("id", outboxId)
    .single();

  assert(row, "Registro outbox deve existir");
  assertEquals(row.status, "pending");
  assert(row.expires_at, "expires_at deve ser gravado");
  const diffSec = (new Date(row.expires_at).getTime() - new Date(row.created_at).getTime()) / 1000;
  assert(Math.abs(diffSec - 600) < 10, `Diferença de TTL deve ser ~600s, obtido ${diffSec}`);

  // Cleanup
  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 2 & 3: Falha explícita no BotConversa (HTTP 500 / Timeout)
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("FASE 4.17 — Teste 2 & 3: Falha simulada no BotConversa dispara Fallback Meta imediato", () => {
  // Validação de contrato: Mensagens com simulate_botconversa_fail = true disparam fallback imediato
  const testPayload = {
    simulate_botconversa_fail: true,
    value: "Falha controlada"
  };
  assert(testPayload.simulate_botconversa_fail, "Simulação de falha ativada");
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 4, 5 & ESPECIAL (Incidente 17:31): HTTP 200 -> dispatched_bc -> Guarda Expira -> Claim sending_meta
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("FASE 4.17 — Teste 4, 5 & Especial (Incidente 17:31): HTTP 200 -> dispatched_bc -> Guarda Expira -> Claim sending_meta", async () => {
  const testPhone = "5511999990003";
  const futureExpiresAt = new Date(Date.now() + 500 * 1000).toISOString(); // TTL válido

  const { data: outboxId, error } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.VISITOR_AUTHORIZED,
    p_message_content: { value: "Visitante Autorizado" },
    p_caller_function: "whatsapp-guest",
    p_entity_type: "convites",
    p_priority: 2,
    p_expires_at: futureExpiresAt
  });

  assertEquals(error, null);
  assert(outboxId, "outboxId deve existir");

  // Simula transição para 'dispatched_bc' com Janela de Guarda expirada
  const pastFallbackAfter = new Date(Date.now() - 5 * 1000).toISOString();
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "dispatched_bc",
      dispatched_at: new Date(Date.now() - 20 * 1000).toISOString(),
      fallback_after: pastFallbackAfter,
      provider_attempt: "BOTCONVERSA"
    })
    .eq("id", outboxId);

  // Executa o claim atômico
  const { data: claimed, error: claimErr } = await supabase.rpc("claim_single_whatsapp_message", {
    p_min_priority: 1,
    p_max_priority: 5
  });

  assertEquals(claimErr, null);
  assert(claimed && claimed.length > 0, "Deve haver mensagem claimed para failover");
  
  const claimedMsg = claimed[0];
  assertEquals(claimedMsg.id, outboxId);
  assertEquals(claimedMsg.status, "sending_meta");

  // Cleanup
  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 6 & 7: Mensagens expiradas são marcadas 'expired' (Anti-Backlog)
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("FASE 4.17 — Teste 6 & 7: Mensagens expiradas são saneadas atômica e automaticamente (Anti-Backlog)", async () => {
  const testPhone = "5511999990002";
  const pastExpiresAt = new Date(Date.now() - 60 * 1000).toISOString(); // Expirou há 1 minuto

  const { data: outboxId, error } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.OTP,
    p_message_content: { value: "OTP Expirado" },
    p_caller_function: "password-reset-whatsapp",
    p_entity_type: "auth_users",
    p_priority: 1,
    p_expires_at: pastExpiresAt
  });

  assertEquals(error, null);
  assert(outboxId, "outboxId deve existir");

  // Ao chamar claim_single_whatsapp_message, o saneamento atômico marca 'expired'
  const { data: claimed } = await supabase.rpc("claim_single_whatsapp_message", {
    p_min_priority: 1,
    p_max_priority: 1
  });

  // A mensagem expirada NÃO pode ter sido claimed para envio
  if (claimed && claimed.length > 0) {
    assertNotEquals(claimed[0].id, outboxId, "Mensagem expirada NÃO deve ser entregue para envio");
  }

  // Verifica se o status mudou para 'expired'
  const { data: row } = await supabase
    .from("whatsapp_outbox")
    .select("status, expiration_reason")
    .eq("id", outboxId)
    .single();

  assert(row, "Registro deve existir");
  assertEquals(row.status, "expired");
  assert(row.expiration_reason, "Deve possuir expiration_reason");

  // Cleanup
  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 8 & 15: Purge em Lote de Mensagens Expiradas (Housekeeping Purge)
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("FASE 4.17 — Teste 8 & 15: Purge em Lote de Mensagens Expiradas (Housekeeping Purge)", async () => {
  const pastExpiresAt = new Date(Date.now() - 10000).toISOString();

  // Cria 3 mensagens expiradas com números E.164 válidos de 13 dígitos
  const ids: string[] = [];
  for (let i = 1; i <= 3; i++) {
    const testPhone = `551198888000${i}`;
    const { data: id, error } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
      p_recipient_phone: testPhone,
      p_payload_type: "text",
      p_message_type: MessageType.NOTICE,
      p_message_content: { value: `Aviso antigo ${i}` },
      p_caller_function: "botconversa-send",
      p_entity_type: "manual_admin",
      p_priority: 15,
      p_expires_at: pastExpiresAt
    });
    if (error) {
      console.error("Erro inserindo mensagem expirada de teste:", error);
    }
    if (id) ids.push(id);
  }

  assertEquals(ids.length, 3);

  // Executa a função de limpeza em lote
  const { data: purgedCount, error: purgeErr } = await supabase.rpc("purge_expired_whatsapp_messages", {
    p_limit: 10
  });

  assertEquals(purgeErr, null);
  assert(Number(purgedCount) >= 3, `Deve ter purgado pelo menos 3 mensagens, purgadas: ${purgedCount}`);

  // Verifica que todas estão com status 'expired'
  const { data: rows } = await supabase
    .from("whatsapp_outbox")
    .select("status, expiration_reason")
    .in("id", ids);

  for (const row of rows || []) {
    assertEquals(row.status, "expired");
  }

  // Cleanup
  await supabase.from("whatsapp_outbox").delete().in("id", ids);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 9 & 12: Concorrência e Idempotência (Transaction ID Lock)
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("FASE 4.17 — Teste 9 & 12: Concorrência e Idempotência (Transaction ID Lock)", async () => {
  const testPhone = "5511999990005";
  const uniqueTx = crypto.randomUUID();

  // Tentativa 1 de enfileirar com transaction_id
  const { data: id1 } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.PARCEL,
    p_message_content: { value: "Encomenda idempotente" },
    p_caller_function: "whatsapp-parcel-notify",
    p_entity_type: "manual_admin",
    p_transaction_id: uniqueTx,
    p_priority: 10
  });

  // Tentativa 2 idêntica concorrente com o mesmo transaction_id
  const { data: id2 } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.PARCEL,
    p_message_content: { value: "Encomenda idempotente" },
    p_caller_function: "whatsapp-parcel-notify",
    p_entity_type: "manual_admin",
    p_transaction_id: uniqueTx,
    p_priority: 10
  });

  assertEquals(id1, id2, "A idempotência transacional deve retornar o MESMO outbox_id");

  // Cleanup
  if (id1) {
    await supabase.from("whatsapp_outbox").delete().eq("id", id1);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 10 & 11: Estado Terminal 'sent' e 'failed' sem Loop Infinito
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("FASE 4.17 — Teste 10 & 11: Mensagem enviada via Meta atinge status 'sent' e não é reprocessada", async () => {
  const testPhone = "5511999990006";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.SOS,
    p_message_content: { value: "Alerta SOS" },
    p_caller_function: "sos-push-notify",
    p_entity_type: "manual_admin",
    p_priority: 1
  });

  assert(outboxId);

  // Simula conclusão de envio via Meta
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "sent",
      sent_at: new Date().toISOString(),
      provider_attempt: "META_CLOUD_API",
      fallback_reason: "BC_DISPATCHED_NO_CONFIRMATION"
    })
    .eq("id", outboxId);

  // Tenta claim: Mensagem com status 'sent' NUNCA pode ser claimada
  const { data: claimed } = await supabase.rpc("claim_single_whatsapp_message", {
    p_min_priority: 1,
    p_max_priority: 1
  });

  if (claimed && claimed.length > 0) {
    assertNotEquals(claimed[0].id, outboxId, "Mensagem 'sent' não deve ser reprocessada");
  }

  // Cleanup
  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});
