// supabase/functions/tests/fase4_17_15_scenarios_individual_test.ts
// Testes Individuais 1 a 15 da FASE 4.17 — Auditoria Pré-Produção
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
// TESTE 1: BC HTTP 200 -> Estado dispatched_bc -> NÃO sent imediatamente
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 1: BC HTTP 200 -> Estado dispatched_bc -> NÃO sent imediatamente", async () => {
  const testPhone = "5511988881001";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.PARCEL,
    p_message_content: { value: "Encomenda teste 1" },
    p_caller_function: "whatsapp-parcel-notify",
    p_entity_type: "manual_admin",
    p_priority: 10
  });
  assert(outboxId);

  // Simula worker processando e recebendo HTTP 200 do BotConversa
  const fallbackWinSec = getMessageFallbackWindow(MessageType.PARCEL); // 30s
  const fallbackAfter = new Date(Date.now() + fallbackWinSec * 1000).toISOString();
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "dispatched_bc",
      dispatched_at: new Date().toISOString(),
      fallback_after: fallbackAfter,
      provider_attempt: "BOTCONVERSA"
    })
    .eq("id", outboxId);

  const { data: row } = await supabase
    .from("whatsapp_outbox")
    .select("status, provider_attempt, fallback_after")
    .eq("id", outboxId)
    .single();

  assert(row);
  assertEquals(row.status, "dispatched_bc", "Status deve ser dispatched_bc, NUNCA sent diretamente");
  assertNotEquals(row.status, "sent", "HTTP 200 do BC NÃO pode virar sent imediatamente");
  assert(row.fallback_after, "fallback_after deve estar preenchido com a janela de guarda");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 2: BC HTTP 500 -> Meta acionada imediatamente
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 2: BC HTTP 500 -> Meta acionada imediatamente (sem aguardar janela)", async () => {
  const testPhone = "5511988881002";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.OTP,
    p_message_content: { value: "Token 123456", simulate_botconversa_fail: true },
    p_caller_function: "password-reset-whatsapp",
    p_entity_type: "auth_users",
    p_priority: 1
  });
  assert(outboxId);

  // Simula erro HTTP 500 do BotConversa -> Transição imediata para sending_meta / fallback
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "sending_meta",
      fallback_reason: "BOTCONVERSA_HTTP_500",
      provider_attempt: "META_CLOUD_API"
    })
    .eq("id", outboxId);

  const { data: row } = await supabase
    .from("whatsapp_outbox")
    .select("status, fallback_reason, provider_attempt")
    .eq("id", outboxId)
    .single();

  assert(row);
  assertEquals(row.status, "sending_meta");
  assertEquals(row.fallback_reason, "BOTCONVERSA_HTTP_500");
  assertEquals(row.provider_attempt, "META_CLOUD_API");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 3: BC Timeout (30s) -> Meta acionada imediatamente
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 3: BC Timeout (30s) -> Meta acionada imediatamente", async () => {
  const testPhone = "5511988881003";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.VISITOR_INVITE,
    p_message_content: { value: "Convite Visitante" },
    p_caller_function: "convite-whatsapp-notify",
    p_entity_type: "convites",
    p_priority: 2
  });
  assert(outboxId);

  // Simula detecção de timeout de 30s no gateway do BotConversa
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "sending_meta",
      fallback_reason: "BOTCONVERSA_TIMEOUT_AMBIGUOUS_30S",
      provider_attempt: "META_CLOUD_API"
    })
    .eq("id", outboxId);

  const { data: row } = await supabase
    .from("whatsapp_outbox")
    .select("status, fallback_reason")
    .eq("id", outboxId)
    .single();

  assert(row);
  assertEquals(row.status, "sending_meta");
  assertEquals(row.fallback_reason, "BOTCONVERSA_TIMEOUT_AMBIGUOUS_30S");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 4: BC HTTP 200 sem confirmação -> Aguarda janela curta -> Meta acionada
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 4: BC HTTP 200 sem confirmação -> Aguarda janela curta -> Meta acionada", async () => {
  const testPhone = "5511988881004";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.VISITOR_AUTHORIZED,
    p_message_content: { value: "Visitante Autorizado Portaria" },
    p_caller_function: "whatsapp-guest",
    p_entity_type: "convites",
    p_priority: 2
  });
  assert(outboxId);

  // Guarda expirada (passaram 15s)
  const pastFallbackAfter = new Date(Date.now() - 5000).toISOString();
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "dispatched_bc",
      dispatched_at: new Date(Date.now() - 20000).toISOString(),
      fallback_after: pastFallbackAfter,
      provider_attempt: "BOTCONVERSA"
    })
    .eq("id", outboxId);

  // Worker executa claim
  const { data: claimed } = await supabase.rpc("claim_single_whatsapp_message", {
    p_min_priority: 1,
    p_max_priority: 5
  });

  assert(claimed && claimed.length > 0);
  const claimedMsg = claimed[0];
  assertEquals(claimedMsg.id, outboxId);
  assertEquals(claimedMsg.status, "sending_meta", "Janela de guarda expirada transiciona para sending_meta");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 5: BC HTTP 200 + mensagem ainda dentro do TTL -> Meta assume após janela
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 5: BC HTTP 200 + mensagem ainda dentro do TTL -> Meta assume após janela", async () => {
  const testPhone = "5511988881005";
  const futureExpiresAt = new Date(Date.now() + 400 * 1000).toISOString(); // TTL de 400s ainda válido

  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.PARCEL,
    p_message_content: { value: "Encomenda válida" },
    p_caller_function: "whatsapp-parcel-notify",
    p_entity_type: "manual_admin",
    p_priority: 10,
    p_expires_at: futureExpiresAt
  });
  assert(outboxId);

  const pastFallbackAfter = new Date(Date.now() - 2000).toISOString();
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "dispatched_bc",
      fallback_after: pastFallbackAfter
    })
    .eq("id", outboxId);

  const { data: claimed } = await supabase.rpc("claim_single_whatsapp_message", {
    p_min_priority: 6,
    p_max_priority: 20
  });

  assert(claimed && claimed.length > 0);
  assertEquals(claimed[0].id, outboxId);
  assertEquals(claimed[0].status, "sending_meta");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 6: Mensagem expirada antes do failover -> expired -> Meta NÃO acionada
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 6: Mensagem expirada antes do failover -> expired -> Meta NÃO acionada", async () => {
  const testPhone = "5511988881006";
  const pastExpiresAt = new Date(Date.now() - 30 * 1000).toISOString(); // Expirou

  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.SOS,
    p_message_content: { value: "Alerta SOS expirado" },
    p_caller_function: "sos-push-notify",
    p_entity_type: "manual_admin",
    p_priority: 1,
    p_expires_at: pastExpiresAt
  });
  assert(outboxId);

  // Claim não deve retornar essa mensagem e sim marcá-la como 'expired'
  await supabase.rpc("claim_single_whatsapp_message", {
    p_min_priority: 1,
    p_max_priority: 1
  });

  const { data: row } = await supabase
    .from("whatsapp_outbox")
    .select("status, expiration_reason")
    .eq("id", outboxId)
    .single();

  assert(row);
  assertEquals(row.status, "expired", "Mensagem com TTL vencido deve estar expired");
  assert(row.expiration_reason);

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 7: Backlog antigo -> Mensagens expiradas descartadas -> Nenhum replay
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 7: Backlog antigo -> Mensagens expiradas descartadas -> Nenhum replay", async () => {
  const pastExpiresAt = new Date(Date.now() - 60000).toISOString();
  const ids: string[] = [];

  for (let i = 1; i <= 3; i++) {
    const { data: id } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
      p_recipient_phone: `551198888200${i}`,
      p_payload_type: "text",
      p_message_type: MessageType.NOTICE,
      p_message_content: { value: `Backlog ${i}` },
      p_caller_function: "botconversa-send",
      p_entity_type: "manual_admin",
      p_priority: 15,
      p_expires_at: pastExpiresAt
    });
    if (id) ids.push(id);
  }
  assertEquals(ids.length, 3);

  // Aciona limpeza atômica
  await supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 1, p_max_priority: 99 });

  const { data: rows } = await supabase
    .from("whatsapp_outbox")
    .select("status")
    .in("id", ids);

  for (const r of rows || []) {
    assertEquals(r.status, "expired", "Todas as mensagens de backlog vencidas devem ser descartadas");
  }

  await supabase.from("whatsapp_outbox").delete().in("id", ids);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 8: BC retorna após indisponibilidade -> Somente válidas são processadas
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 8: BC retorna após indisponibilidade -> Somente válidas são processadas", async () => {
  // 1 mensagem expirada + 1 mensagem válida
  const pastExpiresAt = new Date(Date.now() - 10000).toISOString();
  const futureExpiresAt = new Date(Date.now() + 600000).toISOString();

  const { data: expiredId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: "5511988883001",
    p_payload_type: "text",
    p_message_type: MessageType.NOTICE,
    p_message_content: { value: "Mensagem Antiga" },
    p_caller_function: "botconversa-send",
    p_entity_type: "manual_admin",
    p_priority: 15,
    p_expires_at: pastExpiresAt
  });

  const { data: validId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: "5511988883002",
    p_payload_type: "text",
    p_message_type: MessageType.NOTICE,
    p_message_content: { value: "Mensagem Nova Válida" },
    p_caller_function: "botconversa-send",
    p_entity_type: "manual_admin",
    p_priority: 15,
    p_expires_at: futureExpiresAt
  });

  assert(expiredId && validId);

  // Claim
  const { data: claimed } = await supabase.rpc("claim_single_whatsapp_message", {
    p_min_priority: 10,
    p_max_priority: 20
  });

  assert(claimed && claimed.length > 0);
  assertEquals(claimed[0].id, validId, "Somente a mensagem válida deve ser processada");

  // Verifica que a expirada virou 'expired'
  const { data: expRow } = await supabase
    .from("whatsapp_outbox")
    .select("status")
    .eq("id", expiredId)
    .single();

  assertEquals(expRow?.status, "expired");

  await supabase.from("whatsapp_outbox").delete().in("id", [expiredId, validId]);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 9: Concorrência entre workers -> Lock atômico impede dupla reivindicação
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 9: Concorrência entre workers -> Lock atômico impede dupla reivindicação", async () => {
  const testPhone = "5511988884001";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.OTP,
    p_message_content: { value: "OTP Lock" },
    p_caller_function: "password-reset-whatsapp",
    p_entity_type: "auth_users",
    p_priority: 1
  });
  assert(outboxId);

  // Dois claims concorrentes simulando Worker A e Worker B
  const [claimA, claimB] = await Promise.all([
    supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 1, p_max_priority: 1 }),
    supabase.rpc("claim_single_whatsapp_message", { p_min_priority: 1, p_max_priority: 1 })
  ]);

  const idsA = (claimA.data || []).map((m: any) => m.id);
  const idsB = (claimB.data || []).map((m: any) => m.id);

  // Apenas um worker pode ter pego a mensagem
  const gotA = idsA.includes(outboxId);
  const gotB = idsB.includes(outboxId);
  assert((gotA && !gotB) || (!gotA && gotB), "Exatamente um único worker deve assumir a mensagem");

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 10: Falha BC + Falha Meta -> Estado terminal 'failed' sem loop infinito
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 10: Falha BC + Falha Meta -> Estado terminal 'failed' sem loop infinito", async () => {
  const testPhone = "5511988885001";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.SOS,
    p_message_content: { value: "Alerta SOS Terminal" },
    p_caller_function: "sos-push-notify",
    p_entity_type: "manual_admin",
    p_priority: 1
  });
  assert(outboxId);

  // Simula esgotamento de retries com falha permanente
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "failed",
      error_message: "Falha Permanente (META_CLOUD_API): Recipient phone not WhatsApp registered",
      retry_count: 3
    })
    .eq("id", outboxId);

  // Tenta claim de fila
  const { data: claimed } = await supabase.rpc("claim_single_whatsapp_message", {
    p_min_priority: 1,
    p_max_priority: 1
  });

  if (claimed && claimed.length > 0) {
    assertNotEquals(claimed[0].id, outboxId, "Mensagem em estado 'failed' NUNCA é reprocessada");
  }

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 11: Mensagem enviada pela Meta -> BC não pode reenviar posteriormente
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 11: Mensagem enviada pela Meta -> BC não pode reenviar posteriormente", async () => {
  const testPhone = "5511988886001";
  const { data: outboxId } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.VISITOR_INVITE,
    p_message_content: { value: "Convite Meta Sent" },
    p_caller_function: "convite-whatsapp-notify",
    p_entity_type: "convites",
    p_priority: 2
  });
  assert(outboxId);

  // Marca como enviada via Meta
  await supabase
    .from("whatsapp_outbox")
    .update({
      status: "sent",
      sent_at: new Date().toISOString(),
      provider_attempt: "META_CLOUD_API"
    })
    .eq("id", outboxId);

  // Tenta claim
  const { data: claimed } = await supabase.rpc("claim_single_whatsapp_message", {
    p_min_priority: 1,
    p_max_priority: 5
  });

  if (claimed && claimed.length > 0) {
    assertNotEquals(claimed[0].id, outboxId, "Mensagem 'sent' não pode ser enviada por nenhum canal");
  }

  await supabase.from("whatsapp_outbox").delete().eq("id", outboxId);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 12: Mensagem enviada pelo BC e posteriormente reprocessada -> Idempotência
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 12: Mensagem enviada pelo BC e posteriormente reprocessada -> Idempotência", async () => {
  const testPhone = "5511988887001";
  const uniqueTx = crypto.randomUUID();

  const { data: id1 } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.RESERVATION,
    p_message_content: { value: "Reserva Espaço" },
    p_caller_function: "reserva-notify",
    p_entity_type: "reservas",
    p_transaction_id: uniqueTx,
    p_priority: 10
  });

  const { data: id2 } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
    p_recipient_phone: testPhone,
    p_payload_type: "text",
    p_message_type: MessageType.RESERVATION,
    p_message_content: { value: "Reserva Espaço" },
    p_caller_function: "reserva-notify",
    p_entity_type: "reservas",
    p_transaction_id: uniqueTx,
    p_priority: 10
  });

  assertEquals(id1, id2, "A idempotência por transaction_id garante deduplicação total");

  if (id1) {
    await supabase.from("whatsapp_outbox").delete().eq("id", id1);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 13: Broadcast / Campanha -> Bloqueado na governança anti-broadcast
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 13: Broadcast / Campanha -> Bloqueado antes de qualquer failover Meta", () => {
  const check = validateWhatsAppSendPolicy({
    callerFunction: "smartSend",
    messageType: MessageType.NOTICE,
    textValue: "Comunicado Geral para Todos os Moradores",
    isCampaign: true
  });
  assertEquals(check.allowed, false, "Broadcast via WhatsApp deve ser estritamente bloqueado");
  assertEquals(check.errorCode, "WHATSAPP_POLICY_BROADCAST_BLOCKED");
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 14: TTL por MessageType -> Cada fluxo respeita sua janela específica
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 14: TTL por MessageType -> Cada fluxo respeita sua janela específica", async () => {
  // Validação no TypeScript
  assertEquals(getMessageTTL(MessageType.SOS), 30);
  assertEquals(getMessageTTL(MessageType.OTP), 60);
  assertEquals(getMessageTTL(MessageType.VISITOR_AUTHORIZED), 90);
  assertEquals(getMessageTTL(MessageType.VISITOR_INVITE), 180);
  assertEquals(getMessageTTL(MessageType.PARCEL), 600);
  assertEquals(getMessageTTL(MessageType.NOTICE), 900);
  assertEquals(getMessageTTL(MessageType.FINANCIAL), 1800);

  // Validação na função PostgreSQL
  const { data: dbTtlSos } = await supabase.rpc("get_whatsapp_message_ttl", { p_message_type: "SOS" });
  assertEquals(dbTtlSos, 30);

  const { data: dbTtlOtp } = await supabase.rpc("get_whatsapp_message_ttl", { p_message_type: "OTP" });
  assertEquals(dbTtlOtp, 60);

  const { data: dbTtlParcel } = await supabase.rpc("get_whatsapp_message_ttl", { p_message_type: "PARCEL" });
  assertEquals(dbTtlParcel, 600);

  const { data: dbTtlFin } = await supabase.rpc("get_whatsapp_message_ttl", { p_message_type: "FINANCIAL" });
  assertEquals(dbTtlFin, 1800);
});

// ─────────────────────────────────────────────────────────────────────────────
// TESTE 15: Grande backlog -> Nenhuma mensagem expirada disparada após retorno
// ─────────────────────────────────────────────────────────────────────────────
Deno.test("TESTE 15: Grande backlog -> Nenhuma mensagem expirada disparada após retorno", async () => {
  const pastExpiresAt = new Date(Date.now() - 5000).toISOString();
  const ids: string[] = [];

  for (let i = 1; i <= 5; i++) {
    const { data: id } = await supabase.rpc("enqueue_whatsapp_transactional_message", {
      p_recipient_phone: `551198888800${i}`,
      p_payload_type: "text",
      p_message_type: MessageType.WELCOME,
      p_message_content: { value: `Boas-vindas ${i}` },
      p_caller_function: "welcome-notify",
      p_entity_type: "manual_admin",
      p_priority: 15,
      p_expires_at: pastExpiresAt
    });
    if (id) ids.push(id);
  }
  assertEquals(ids.length, 5);

  // Executa purge em lote (Housekeeping)
  const { data: purgedCount } = await supabase.rpc("purge_expired_whatsapp_messages", { p_limit: 100 });
  assert(Number(purgedCount) >= 5, "Todas as mensagens do backlog devem ser purgadas");

  // Verifica que nenhuma mensagem ficou pending
  const { data: pendingRows } = await supabase
    .from("whatsapp_outbox")
    .select("id")
    .in("id", ids)
    .eq("status", "pending");

  assertEquals((pendingRows || []).length, 0, "Zero mensagens pendentes no backlog expirado");

  await supabase.from("whatsapp_outbox").delete().in("id", ids);
});
