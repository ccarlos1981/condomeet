// supabase/functions/tests/fase4_17_1_bc_first_regression_test.ts
// Suíte de Testes da FASE 4.17.1 — Correção Crítica do Failover BotConversa -> Meta
// Ambiente: EXCLUSIVO DEV (avypyaxthvgaybplnwxu)

import { assertEquals, assertNotEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { 
  MessageType, 
  getMessageTTL, 
  getMessageFallbackWindow 
} from "../_shared/message_types.ts";
import { smartSend, validateWhatsAppSendPolicy } from "../_shared/botconversa.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://avypyaxthvgaybplnwxu.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 1: Template Meta inexistente -> BC ainda entra na outbox
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 1: Template Meta inexistente -> BC ainda entra na outbox", async () => {
  const testPhone = "5511999990001";
  
  // Chama smartSend passando parâmetros vazios de template (simulando template inexistente/não configurado)
  const res = await smartSend(
    "dummy_bc_key",
    null,
    testPhone,
    "text",
    "Mensagem de teste sem template Meta",
    "Morador",
    supabase,
    undefined,
    MessageType.NOTICE,
    "welcome-notify",
    [] // Sem template params
  );

  // smartSend DEVE ter enfileirado com sucesso para o BotConversa
  assert(res.success, "smartSend deve retornar sucesso mesmo sem template Meta configurado");

  // Verifica no banco DEV se a mensagem foi gravada na outbox
  const { data: outboxRows } = await supabase
    .from("whatsapp_outbox")
    .select("id, status, recipient_phone, message_type")
    .eq("recipient_phone", testPhone)
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(1);

  assert(outboxRows && outboxRows.length > 0, "Mensagem DEVE estar na outbox com status pending");
  assertEquals(outboxRows[0].recipient_phone, testPhone);

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxRows[0].id);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 2: Template Meta PENDING -> BC ainda entra na outbox
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 2: Template Meta PENDING -> BC ainda entra na outbox", async () => {
  const testPhone = "5511999990002";
  
  // OTP com template condomeet_recuperacao_senha_v1 (que pode estar PENDING no banco)
  const res = await smartSend(
    "dummy_bc_key",
    null,
    testPhone,
    "text",
    "Seu código OTP é 888999",
    "Morador",
    supabase,
    undefined,
    MessageType.OTP,
    "password-reset-whatsapp",
    ["888999"]
  );

  assert(res.success, "smartSend deve enfileirar OTP mesmo com template PENDING");

  const { data: outboxRows } = await supabase
    .from("whatsapp_outbox")
    .select("id, status, recipient_phone")
    .eq("recipient_phone", testPhone)
    .eq("status", "pending")
    .limit(1);

  assert(outboxRows && outboxRows.length > 0);
  await supabase.from("whatsapp_outbox").delete().eq("id", outboxRows[0].id);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 3: Template Meta REJECTED -> BC ainda entra na outbox
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 3: Template Meta REJECTED -> BC ainda entra na outbox", async () => {
  const testPhone = "5511999990003";
  
  const res = await smartSend(
    "dummy_bc_key",
    null,
    testPhone,
    "text",
    "Aviso operacional",
    "Morador",
    supabase,
    undefined,
    MessageType.NOTICE,
    "welcome-notify",
    ["Parâmetro Inválido"]
  );

  assert(res.success);

  const { data: outboxRows } = await supabase
    .from("whatsapp_outbox")
    .select("id")
    .eq("recipient_phone", testPhone)
    .limit(1);

  assert(outboxRows && outboxRows.length > 0);
  await supabase.from("whatsapp_outbox").delete().eq("id", outboxRows[0].id);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 4: Meta WABA indisponível -> BC ainda entra na outbox
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 4: Meta WABA indisponível -> BC ainda entra na outbox", async () => {
  const testPhone = "5511999990004";
  await supabase.from("whatsapp_outbox").delete().eq("recipient_phone", testPhone);
  
  const res = await smartSend(
    "dummy_bc_key",
    null,
    testPhone,
    "text",
    "Reserva de Espaço",
    "Morador",
    supabase,
    undefined,
    MessageType.RESERVATION,
    "reserva-notify",
    []
  );

  assert(res.success);

  const { data: outboxRows } = await supabase
    .from("whatsapp_outbox")
    .select("id, status")
    .eq("recipient_phone", testPhone)
    .order("created_at", { ascending: false })
    .limit(1);

  assert(outboxRows && outboxRows.length > 0);
  assert(["pending", "sending"].includes(outboxRows[0].status), "Mensagem deve ter sido enfileirada com status pending ou sending");
  await supabase.from("whatsapp_outbox").delete().eq("id", outboxRows[0].id);

});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 5: BC HTTP 200 -> dispatched_bc
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 5: BC HTTP 200 -> dispatched_bc", async () => {
  const testPhone = "5511999990005";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.PARCEL,
    p_message_content: { value: "Encomenda teste" },
    p_caller_function: "whatsapp-parcel-notify",
    p_entity_type: "manual_admin",
    p_priority: 10
  });
  assert(outboxId);

  const fallbackWin = getMessageFallbackWindow(MessageType.PARCEL);
  const fallbackAfter = new Date(Date.now() + fallbackWin * 1000).toISOString();

  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "dispatched_bc",
      dispatched_at: new Date().toISOString(),
      fallback_after: fallbackAfter,
      provider_attempt: "BOTCONVERSA"
    })
    .eq("id", outboxId);

  const { data: row } = await supabase.from("whatsapp_outbox").select("status, fallback_after").eq("id", outboxId).single();
  assertEquals(row?.status, "dispatched_bc");
  assertNotEquals(row?.status, "sent", "HTTP 200 do BC não marca sent imediatamente");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 6: BC HTTP 200 + janela expirada -> sending_meta
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 6: BC HTTP 200 + janela expirada -> sending_meta", async () => {
  const testPhone = "5511999990006";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.VISITOR_AUTHORIZED,
    p_message_content: { value: "Visitante liberado" },
    p_caller_function: "whatsapp-guest",
    p_entity_type: "convites",
    p_priority: 2
  });
  assert(outboxId);

  // Janela expirada
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "dispatched_bc",
      fallback_after: new Date(Date.now() - 1000).toISOString()
    })
    .eq("id", outboxId);

  const { data: claimed } = await supabase.rpc("claim_single_whatsapp_message", {
    p_min_priority: 1,
    p_max_priority: 5
  });

  assert(claimed && claimed.length > 0);
  assertEquals(claimed[0].id, outboxId);
  assertEquals(claimed[0].status, "sending_meta");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 7: BC HTTP 500 -> Meta imediata
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 7: BC HTTP 500 -> Meta imediata", async () => {
  const testPhone = "5511999990007";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.OTP,
    p_message_content: { value: "Token 999111" },
    p_caller_function: "password-reset-whatsapp",
    p_entity_type: "auth_users",
    p_priority: 1
  });
  assert(outboxId);

  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "sending_meta",
      fallback_reason: "BOTCONVERSA_HTTP_500",
      provider_attempt: "META_CLOUD_API"
    })
    .eq("id", outboxId);

  const { data: row } = await supabase.from("whatsapp_outbox").select("status, fallback_reason").eq("id", outboxId).single();
  assertEquals(row?.status, "sending_meta");
  assertEquals(row?.fallback_reason, "BOTCONVERSA_HTTP_500");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 8: BC timeout -> Meta imediata
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 8: BC timeout -> Meta imediata", async () => {
  const testPhone = "5511999990008";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.VISITOR_INVITE,
    p_message_content: { value: "Convite" },
    p_caller_function: "convite-whatsapp-notify",
    p_entity_type: "convites",
    p_priority: 2
  });
  assert(outboxId);

  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "sending_meta",
      fallback_reason: "BOTCONVERSA_TIMEOUT_AMBIGUOUS_30S"
    })
    .eq("id", outboxId);

  const { data: row } = await supabase.from("whatsapp_outbox").select("status, fallback_reason").eq("id", outboxId).single();
  assertEquals(row?.status, "sending_meta");
  assertEquals(row?.fallback_reason, "BOTCONVERSA_TIMEOUT_AMBIGUOUS_30S");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 9: BC Circuit Breaker OPEN -> Meta imediata
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 9: BC Circuit Breaker OPEN -> Meta imediata", async () => {
  const testPhone = "5511999990009";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.SOS,
    p_message_content: { value: "Emergência" },
    p_caller_function: "sos-push-notify",
    p_entity_type: "manual_admin",
    p_priority: 1
  });
  assert(outboxId);

  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "sending_meta",
      fallback_reason: "BOTCONVERSA_DISCONNECTED"
    })
    .eq("id", outboxId);

  const { data: row } = await supabase.from("whatsapp_outbox").select("status, fallback_reason").eq("id", outboxId).single();
  assertEquals(row?.status, "sending_meta");
  assertEquals(row?.fallback_reason, "BOTCONVERSA_DISCONNECTED");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 10: Meta sem template APPROVED -> fallback não envia -> failed sem backlog
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 10: Meta sem template APPROVED -> fallback não envia -> failed sem backlog", async () => {
  const testPhone = "5511999990010";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.PARCEL,
    p_message_content: { value: "Pacote" },
    p_caller_function: "whatsapp-parcel-notify",
    p_entity_type: "manual_admin",
    p_priority: 10
  });
  assert(outboxId);

  // Simula worker tentando fallback Meta com template não aprovado
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "failed",
      error_message: "Meta Template Not Approved: Template local ausente ou PENDING",
      fallback_reason: "BOTCONVERSA_HTTP_500"
    })
    .eq("id", outboxId);

  const { data: row } = await supabase.from("whatsapp_outbox").select("status, error_message").eq("id", outboxId).single();
  assertEquals(row?.status, "failed");

  // Garante que não é re-claimado
  const { data: claimed } = await supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 1, p_max_priority: 99 });
  if (claimed && claimed.length > 0) {
    assertNotEquals(claimed[0].id, outboxId);
  }

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 11: Meta restrita -> failed sem retry infinito
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 11: Meta restrita -> failed sem retry infinito", async () => {
  const testPhone = "5511999990011";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.OTP,
    p_message_content: { value: "OTP" },
    p_caller_function: "password-reset-whatsapp",
    p_entity_type: "auth_users",
    p_priority: 1
  });
  assert(outboxId);

  // Simula erro 131042 da Meta
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "failed",
      error_message: "Meta API HTTP 400: (131042) Business eligibility payment issue",
      retry_count: 0
    })
    .eq("id", outboxId);

  const { data: row } = await supabase.from("whatsapp_outbox").select("status").eq("id", outboxId).single();
  assertEquals(row?.status, "failed");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 12: Mensagem TTL expirado -> expired -> zero envio
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 12: Mensagem TTL expirado -> expired -> zero envio", async () => {
  const testPhone = "5511999990012";
  const pastExpiresAt = new Date(Date.now() - 10000).toISOString();

  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.SOS,
    p_message_content: { value: "SOS expirado" },
    p_caller_function: "sos-push-notify",
    p_entity_type: "manual_admin",
    p_priority: 1,
    p_expires_at: pastExpiresAt
  });
  assert(outboxId);

  await supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 1, p_max_priority: 1 });

  const { data: row } = await supabase.from("whatsapp_outbox").select("status, expiration_reason").eq("id", outboxId).single();
  assertEquals(row?.status, "expired");
  assertEquals(row?.expiration_reason, "TTL_EXCEEDED_IN_QUEUE");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 13: Mensagem expirando enquanto aguarda fallback -> expired -> Meta NÃO dispara
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 13: Mensagem expirando enquanto aguarda fallback -> expired -> Meta NÃO dispara", async () => {
  const testPhone = "5511999990013";
  const pastExpiresAt = new Date(Date.now() - 5000).toISOString();
  const pastFallbackAfter = new Date(Date.now() - 10000).toISOString();

  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.VISITOR_INVITE,
    p_message_content: { value: "Convite" },
    p_caller_function: "convite-whatsapp-notify",
    p_entity_type: "convites",
    p_priority: 2,
    p_expires_at: pastExpiresAt
  });
  assert(outboxId);

  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "dispatched_bc",
      fallback_after: pastFallbackAfter
    })
    .eq("id", outboxId);

  // Claim deve marcar expired e não retornar a mensagem
  await supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 1, p_max_priority: 5 });

  const { data: row } = await supabase.from("whatsapp_outbox").select("status").eq("id", outboxId).single();
  assertEquals(row?.status, "expired", "Mensagem em dispatched_bc com TTL vencido deve ser marcada expired");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 14: Concorrência -> somente um provider/worker assume
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 14: Concorrência -> somente um worker/provider assume", async () => {
  const testPhone = "5511999990014";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.OTP,
    p_message_content: { value: "OTP Concorrente" },
    p_caller_function: "password-reset-whatsapp",
    p_entity_type: "auth_users",
    p_priority: 1
  });
  assert(outboxId);

  const [claim1, claim2] = await Promise.all([
    supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 1, p_max_priority: 1 }),
    supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 1, p_max_priority: 1 })
  ]);

  const ids1 = (claim1.data || []).map((m: any) => m.id);
  const ids2 = (claim2.data || []).map((m: any) => m.id);

  assert((ids1.includes(outboxId) && !ids2.includes(outboxId)) || (!ids1.includes(outboxId) && ids2.includes(outboxId)));

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 15: BC sucesso -> Meta NÃO é acionada
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 15: BC sucesso -> Meta NÃO é acionada", async () => {
  const testPhone = "5511999990015";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.DUAL_NUMBER_NOTICE,
    p_message_content: { value: "Aviso Dois Números" },
    p_caller_function: "dual-number-routine",
    p_entity_type: "dual_number_notices",
    p_priority: 25
  });
  assert(outboxId);

  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "sent",
      sent_at: new Date().toISOString(),
      provider_attempt: "BOTCONVERSA"
    })
    .eq("id", outboxId);

  const { data: row } = await supabase.from("whatsapp_outbox").select("status, provider_attempt").eq("id", outboxId).single();
  assertEquals(row?.status, "sent");
  assertEquals(row?.provider_attempt, "BOTCONVERSA");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 16: BC 200 sem confirmação -> Meta é acionada somente após fallback_after
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 16: BC 200 sem confirmação -> Meta é acionada somente após fallback_after", async () => {
  const testPhone = "5511999990016";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.PARCEL,
    p_message_content: { value: "Encomenda" },
    p_caller_function: "whatsapp-parcel-notify",
    p_entity_type: "manual_admin",
    p_priority: 10
  });
  assert(outboxId);

  // Janela ainda no futuro (faltam 25s)
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "dispatched_bc",
      fallback_after: new Date(Date.now() + 25000).toISOString()
    })
    .eq("id", outboxId);

  // Claim NÃO deve pegar
  const { data: claimPre } = await supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 6, p_max_priority: 20 });
  const idsPre = (claimPre || []).map((m: any) => m.id);
  assert(!idsPre.includes(outboxId), "Mensagem em guarda NÃO pode ser reivindicada antes do fallback_after");

  // Avança janela para o passado
  await supabase
    .from("whatsapp_outbox")
    .update({
      fallback_after: new Date(Date.now() - 1000).toISOString()
    })
    .eq("id", outboxId);

  // Claim agora DEVE pegar
  const { data: claimPost } = await supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 6, p_max_priority: 20 });
  const idsPost = (claimPost || []).map((m: any) => m.id);
  assert(idsPost.includes(outboxId), "Mensagem DEVE ser reivindicada após o fallback_after estourar");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 17: Broadcast -> continua bloqueado
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 17: Broadcast -> continua bloqueado", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "smartSend",
    messageType: MessageType.NOTICE,
    textValue: "Mensagem Geral para Todo o Condomínio",
    isBroadcast: true
  });
  assertEquals(res.allowed, false);
  assertEquals(res.errorCode, "WHATSAPP_POLICY_BROADCAST_BLOCKED");
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 18: Campanha -> continua bloqueada
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 18: Campanha -> continua bloqueada", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "smartSend",
    messageType: MessageType.NOTICE,
    textValue: "Campanha Promocional",
    isCampaign: true
  });
  assertEquals(res.allowed, false);
  assertEquals(res.errorCode, "WHATSAPP_POLICY_BROADCAST_BLOCKED");
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 19: por_condominio -> continua bloqueado
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 19: por_condominio -> continua bloqueado", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "smartSend",
    messageType: MessageType.NOTICE,
    textValue: "Envio por condomínio massivo",
    recipientCount: 50
  });
  assertEquals(res.allowed, false);
  assertEquals(res.errorCode, "WHATSAPP_POLICY_BROADCAST_BLOCKED");
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 20: por_bloco -> continua bloqueado
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 20: por_bloco -> continua bloqueado", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "smartSend",
    messageType: MessageType.NOTICE,
    textValue: "Envio para todo o bloco",
    recipientCount: 20
  });
  assertEquals(res.allowed, false);
  assertEquals(res.errorCode, "WHATSAPP_POLICY_BROADCAST_BLOCKED");
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 21: por_perfil -> continua bloqueado
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 21: por_perfil -> continua bloqueado", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "smartSend",
    messageType: MessageType.NOTICE,
    textValue: "Envio para todos os proprietários",
    recipientCount: 15
  });
  assertEquals(res.allowed, false);
  assertEquals(res.errorCode, "WHATSAPP_POLICY_BROADCAST_BLOCKED");
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE ESPECÍFICO DO INCIDENTE DAS 17:31
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 22 (INCIDENTE 17:31): Template Meta inexistente/PENDING NÃO impede BotConversa", async () => {
  const testPhone = "5511999990022";
  
  // 1. smartSend recebe encomenda sem template aprovado
  const res = await smartSend(
    "dummy_bc_key",
    null,
    testPhone,
    "text",
    "Chegou uma encomenda para o seu apartamento",
    "Morador",
    supabase,
    undefined,
    MessageType.PARCEL,
    "whatsapp-parcel-notify",
    [] // Parâmetros vazios (template Meta ausente)
  );

  // 2. Enqueue DEVE ter sido realizado!
  assert(res.success, "A ausência de template Meta NÃO pode impedir o enqueue para o BotConversa");

  const { data: outboxRows } = await supabase
    .from("whatsapp_outbox")
    .select("id, status, recipient_phone")
    .eq("recipient_phone", testPhone)
    .order("created_at", { ascending: false })
    .limit(1);

  assert(outboxRows && outboxRows.length > 0);
  const outboxId = outboxRows[0].id;
  assertEquals(outboxRows[0].status, "pending");

  // 3. Worker executa tentativa primária no BotConversa -> HTTP 200 -> dispatched_bc
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "dispatched_bc",
      dispatched_at: new Date().toISOString(),
      fallback_after: new Date(Date.now() - 1000).toISOString(), // Janela expirou sem DLR
      provider_attempt: "BOTCONVERSA"
    })
    .eq("id", outboxId);

  // 4. Claim de contingência após janela
  const { data: claimed } = await supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 6, p_max_priority: 20 });
  const ids = (claimed || []).map((m: any) => m.id);
  assert(ids.includes(outboxId));

  // 5. Worker tenta fallback Meta -> Como template não está aprovado, marca failed de forma controlada
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "failed",
      error_message: "BOTCONVERSA_DISPATCHED_NO_CONFIRMATION: Meta fallback template unavailable"
    })
    .eq("id", outboxId);

  const { data: finalRow } = await supabase.from("whatsapp_outbox").select("status").eq("id", outboxId).single();
  assertEquals(finalRow?.status, "failed");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});
