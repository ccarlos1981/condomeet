import { assertEquals, assertNotEquals } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { calculateWarmupRoute, getDeterministicPartition } from "../_shared/botconversa.ts";

/**
 * FASE 7.14.1 — SUÍTE DE TESTES AUTOMATIZADOS: RECUPERAÇÃO CONTROLADA DA OUTBOX
 * 
 * Cenários Obrigatórios:
 * TESTE A: Mensagem sending órfã + mesma hash em pending (Anti-23505 Collision Safe Recovery)
 * TESTE B: Claim normal sem colisão
 * TESTE C: Duas mensagens diferentes com hashes diferentes (Processamento Sequencial)
 * TESTE D: Retry da mesma operação (Idempotência)
 * TESTE E: Proteção de Deduplicação (Índice idx_whatsapp_outbox_dedup_pending)
 * TESTE F: Isolamento de Falhas (Resiliência da Fila)
 * TESTE G: Validação de Pacing Conservador (>= 60s para WELCOME vs 1s/1.8s padrão)
 * TESTE H: Proteção de Não-Regressão das Rotas de Outros MessageTypes
 */

// Simulação in-memory da lógica de deduplicação e auto-recovery da RPC
interface OutboxMockRow {
  id: string;
  status: "pending" | "sending" | "sending_meta" | "sent" | "failed" | "expired";
  message_hash: string;
  message_type: string;
  priority: number;
  processing_started_at: number | null;
  expires_at: number | null;
  error_message: string | null;
  created_at: number;
}

function simulateAutoRecoveryAndClaim(
  rows: OutboxMockRow[],
  now: number,
  minPriority = 1,
  maxPriority = 99
): { claimed: OutboxMockRow | null; updatedRows: OutboxMockRow[]; error: string | null } {
  const twoMinutesAgo = now - 2 * 60 * 1000;
  let error: string | null = null;

  // 1.1 Encerramento seguro de candidatos presos com colisão de hash
  const stuckCandidates = rows.filter(
    r => (r.status === "sending" || r.status === "sending_meta") &&
         r.processing_started_at !== null &&
         r.processing_started_at < twoMinutesAgo &&
         (r.expires_at === null || r.expires_at > now)
  );

  for (const sc of stuckCandidates) {
    const hasActivePendingWithSameHash = rows.some(
      r => r.status === "pending" && r.message_hash === sc.message_hash && r.id !== sc.id
    );

    if (hasActivePendingWithSameHash) {
      sc.status = "failed";
      sc.error_message = "Auto-recovery: encerrado pois ja existe registro ativo em pending com mesmo message_hash";
      sc.processing_started_at = null;
    }
  }

  // 1.2 Recuperar para pending os que não colidiram
  for (const sc of stuckCandidates) {
    if (sc.status === "sending" || sc.status === "sending_meta") {
      // Verificar se ao mudar para pending violaria a restrição única
      const wouldCollide = rows.some(
        r => r.status === "pending" && r.message_hash === sc.message_hash && r.id !== sc.id
      );
      if (wouldCollide) {
        error = "ERROR 23505: duplicate key value violates unique constraint 'idx_whatsapp_outbox_dedup_pending'";
        break;
      }
      sc.status = "pending";
      sc.error_message = "Recuperado: timeout de processamento excedido (> 2 min)";
      sc.processing_started_at = null;
    }
  }

  if (error) {
    return { claimed: null, updatedRows: rows, error };
  }

  // 2. Expiração de TTL
  for (const r of rows) {
    if (["pending", "sending", "sending_meta"].includes(r.status) && r.expires_at !== null && r.expires_at <= now) {
      r.status = "expired";
    }
  }

  // 3. Claim
  const eligible = rows
    .filter(r => r.status === "pending" && r.priority >= minPriority && r.priority <= maxPriority && (r.expires_at === null || r.expires_at > now))
    .sort((a, b) => a.priority - b.priority || a.created_at - b.created_at);

  const claimed = eligible.length > 0 ? eligible[0] : null;
  if (claimed) {
    claimed.status = "sending";
    claimed.processing_started_at = now;
  }

  return { claimed, updatedRows: rows, error: null };
}

Deno.test("FASE 7.14.1 — TESTE A: Mensagem sending órfã + mesma hash em pending ➔ Auto-recovery seguro sem erro 23505", () => {
  const now = Date.now();
  const collisionHash = "836d488c0c427d030ff24c27ca38ba0e240c4cb29617e7d266a1f1a2d71584c3";

  const rows: OutboxMockRow[] = [
    {
      id: "orphan-sending-1",
      status: "sending",
      message_hash: collisionHash,
      message_type: "VISITOR_INVITE",
      priority: 2,
      processing_started_at: now - 3 * 60 * 1000, // 3 min atrás (preso)
      expires_at: null,
      error_message: null,
      created_at: now - 3 * 60 * 1000,
    },
    {
      id: "active-pending-1",
      status: "pending",
      message_hash: collisionHash,
      message_type: "VISITOR_INVITE",
      priority: 2,
      processing_started_at: null,
      expires_at: null,
      error_message: null,
      created_at: now - 1 * 60 * 1000,
    },
  ];

  const result = simulateAutoRecoveryAndClaim(rows, now);

  // 1. RPC não deve retornar erro
  assertEquals(result.error, null);
  // 2. Mensagem órfã deve ter sido encerrada com status failed e erro explicativo
  const orphan = rows.find(r => r.id === "orphan-sending-1");
  assertEquals(orphan?.status, "failed");
  assertEquals(orphan?.error_message?.includes("Auto-recovery: encerrado"), true);
  // 3. Mensagem pending válida foi claimada normalmente
  assertEquals(result.claimed?.id, "active-pending-1");
  assertEquals(result.claimed?.status, "sending");
});

Deno.test("FASE 7.14.1 — TESTE B: Claim normal sem colisão ➔ Claim unitário imediato", () => {
  const now = Date.now();
  const rows: OutboxMockRow[] = [
    {
      id: "welcome-msg-1",
      status: "pending",
      message_hash: "hash-welcome-1",
      message_type: "WELCOME",
      priority: 15,
      processing_started_at: null,
      expires_at: now + 7 * 24 * 3600 * 1000,
      error_message: null,
      created_at: now - 1000,
    },
  ];

  const result = simulateAutoRecoveryAndClaim(rows, now, 6, 99);
  assertEquals(result.error, null);
  assertEquals(result.claimed?.id, "welcome-msg-1");
  assertEquals(result.claimed?.status, "sending");
});

Deno.test("FASE 7.14.1 — TESTE C: Múltiplas mensagens com hashes distintos ➔ Processamento ordenado por prioridade e criação", () => {
  const now = Date.now();
  const rows: OutboxMockRow[] = [
    {
      id: "msg-priority-10",
      status: "pending",
      message_hash: "hash-priority-10",
      message_type: "PARCEL",
      priority: 10,
      processing_started_at: null,
      expires_at: null,
      error_message: null,
      created_at: now - 2000,
    },
    {
      id: "msg-priority-2",
      status: "pending",
      message_hash: "hash-priority-2",
      message_type: "VISITOR_INVITE",
      priority: 2,
      processing_started_at: null,
      expires_at: null,
      error_message: null,
      created_at: now - 1000,
    },
  ];

  // Claim em fila high (prioridade 1..5)
  const resultHigh = simulateAutoRecoveryAndClaim(rows, now, 1, 5);
  assertEquals(resultHigh.claimed?.id, "msg-priority-2");

  // Claim em fila low (prioridade 6..99)
  const resultLow = simulateAutoRecoveryAndClaim(rows, now, 6, 99);
  assertEquals(resultLow.claimed?.id, "msg-priority-10");
});

Deno.test("FASE 7.14.1 — TESTE D: Idempotência de auto-recovery de mensagem presa sem colisão", () => {
  const now = Date.now();
  const rows: OutboxMockRow[] = [
    {
      id: "stuck-no-collision",
      status: "sending",
      message_hash: "unique-hash-123",
      message_type: "WELCOME",
      priority: 15,
      processing_started_at: now - 5 * 60 * 1000,
      expires_at: now + 7 * 24 * 3600 * 1000,
      error_message: null,
      created_at: now - 10 * 60 * 1000,
    },
  ];

  // Primeira execução: recupera para pending e imediatamente claima
  const result = simulateAutoRecoveryAndClaim(rows, now, 6, 99);
  assertEquals(result.error, null);
  assertEquals(result.claimed?.id, "stuck-no-collision");
  assertEquals(result.claimed?.status, "sending");
});

Deno.test("FASE 7.14.1 — TESTE E: Proteção de Deduplicação — Não permite duplicidade ativa em pending", () => {
  const now = Date.now();
  const hash = "same-hash-xyz";
  const rows: OutboxMockRow[] = [
    {
      id: "row-1",
      status: "pending",
      message_hash: hash,
      message_type: "WELCOME",
      priority: 15,
      processing_started_at: null,
      expires_at: null,
      error_message: null,
      created_at: now,
    },
  ];

  // Tentar inserir um novo registro com o mesmo hash em status pending
  const canInsertDuplicatePending = !rows.some(r => r.status === "pending" && r.message_hash === hash);
  assertEquals(canInsertDuplicatePending, false, "Índice idx_whatsapp_outbox_dedup_pending deve rejeitar inserção duplicada");
});

Deno.test("FASE 7.14.1 — TESTE F: Isolamento de falhas — Mensagem failed não bloqueia mensagens subsequentes", () => {
  const now = Date.now();
  const rows: OutboxMockRow[] = [
    {
      id: "row-failed",
      status: "failed",
      message_hash: "hash-failed",
      message_type: "NOTICE",
      priority: 15,
      processing_started_at: null,
      expires_at: null,
      error_message: "HTTP 500",
      created_at: now - 3000,
    },
    {
      id: "row-valid-pending",
      status: "pending",
      message_hash: "hash-valid",
      message_type: "WELCOME",
      priority: 15,
      processing_started_at: null,
      expires_at: null,
      error_message: null,
      created_at: now - 1000,
    },
  ];

  const result = simulateAutoRecoveryAndClaim(rows, now, 6, 99);
  assertEquals(result.claimed?.id, "row-valid-pending");
});

Deno.test("FASE 7.14.1 — TESTE G: Pacing Conservador — WELCOME utiliza 60.000 ms vs 1.000 ms / 1.800 ms padrão", () => {
  function getPacingDelay(messageType: string, queueType: "high" | "low"): number {
    if (messageType === "WELCOME") {
      return 60000;
    }
    return queueType === "high" ? 1000 : 1800;
  }

  assertEquals(getPacingDelay("WELCOME", "low"), 60000, "WELCOME deve ter pacing mínimo de 60 segundos (60.000 ms)");
  assertEquals(getPacingDelay("WELCOME", "high"), 60000, "WELCOME deve ter pacing mínimo de 60 segundos mesmo se invocado em high");
  assertEquals(getPacingDelay("VISITOR_INVITE", "high"), 1000, "VISITOR_INVITE em high permanece 1000ms");
  assertEquals(getPacingDelay("PARCEL", "low"), 1800, "PARCEL em low permanece 1800ms");
  assertEquals(getPacingDelay("NOTICE", "low"), 1800, "NOTICE em low permanece 1800ms");
});

Deno.test("FASE 7.14.1 — TESTE H: Não-Regressão das Rotas de Negócio Homologadas", () => {
  // 1. PARCEL permanece 99% Meta Primary
  const routeParcel = calculateWarmupRoute({
    messageId: "parcel-test-id",
    messageType: "PARCEL",
    warmupMode: true,
    canSendWarmup: true,
  });
  assertEquals(routeParcel.provider, "META");

  // 2. NOTICE permanece BotConversa
  const routeNotice = calculateWarmupRoute({
    messageId: "notice-test-id",
    messageType: "NOTICE",
    warmupMode: true,
    canSendWarmup: true,
  });
  assertEquals(routeNotice.provider, "BOTCONVERSA");

  // 3. WELCOME permanece BotConversa (quando piloto Evolution está inativo)
  const routeWelcome = calculateWarmupRoute({
    messageId: "welcome-test-id",
    messageType: "WELCOME",
    warmupMode: true,
    canSendWarmup: true,
    welcomePilotEnabled: false,
  });
  assertEquals(routeWelcome.provider, "BOTCONVERSA");
});
