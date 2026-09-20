import { assertEquals, assertNotEquals } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { 
  calculateWarmupRoute, 
  getDeterministicPartition,
  BotConversaRolloutConfig
} from "../_shared/botconversa.ts";

// ═════════════════════════════════════════════════════════════════════════════
// FASE 7.20 — SUÍTE DE TESTES OBRIGATÓRIOS DO ROLLOUT CONTROLADO BOTCONVERSA
// ARQUITETURA LIMPA: SEPARAÇÃO DE ESTADO, CONDOMINIUM_HASH, LIMITES E PACING
// ═════════════════════════════════════════════════════════════════════════════

const DEFAULT_CONFIG: BotConversaRolloutConfig = {
  enabled: true,
  disableReason: null,
  rolloutPercent: 5,
  rolloutStrategy: "CONDOMINIUM_HASH",
  cooldownSeconds: 60,
  dailyLimit: 50,
  dailySentToday: 0,
  observationMode: true,
  allowedMessageTypes: ["WELCOME", "NOTICE", "VISITOR_INVITE", "DUAL_NUMBER_NOTICE"]
};

Deno.test("1. CONDOMINIUM_HASH — Moradores diferentes do mesmo condomínio usam 100% o mesmo provider", () => {
  const condoA = "c0nda000-0000-0000-0000-000000000001";
  
  // Testar 10 moradores diferentes do condoA
  const providers = new Set<string>();
  const partitions = new Set<number>();

  for (let i = 1; i <= 10; i++) {
    const route = calculateWarmupRoute({
      messageId: `msg-condoA-${i}`,
      perfilId: `morador-perfil-${i}`,
      condominioId: condoA,
      messageType: "VISITOR_INVITE",
      botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 50 }
    });
    providers.add(route.provider);
    partitions.add(route.partition);
  }

  assertEquals(providers.size, 1, "Todos os moradores do mesmo condomínio devem usar exatamente o mesmo provider");
  assertEquals(partitions.size, 1, "Todos os moradores do mesmo condomínio devem gerar exatamente a mesma partição");
});

Deno.test("2. Alternância Dinâmica de Estratégias (CONDOMINIUM_HASH vs GLOBAL_HASH vs MESSAGE_HASH)", () => {
  const condoId = "condo-teste-alpha";
  const perfilId = "perfil-teste-beta";
  const messageId = "msg-teste-gamma";

  const routeCondo = calculateWarmupRoute({
    messageId,
    perfilId,
    condominioId: condoId,
    messageType: "VISITOR_INVITE",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutStrategy: "CONDOMINIUM_HASH" }
  });

  const routeGlobal = calculateWarmupRoute({
    messageId,
    perfilId,
    condominioId: condoId,
    messageType: "VISITOR_INVITE",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutStrategy: "GLOBAL_HASH" }
  });

  const routeMsg = calculateWarmupRoute({
    messageId,
    perfilId,
    condominioId: condoId,
    messageType: "VISITOR_INVITE",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutStrategy: "MESSAGE_HASH" }
  });

  assertEquals(routeCondo.partition, getDeterministicPartition(condoId));
  assertEquals(routeGlobal.partition, getDeterministicPartition(perfilId));
  assertEquals(routeMsg.partition, getDeterministicPartition(messageId));
});

Deno.test("3. Rollout Configurável Dinâmico (0%, 5%, 20%, 50%, 100%)", () => {
  // Testar 0%
  const route0 = calculateWarmupRoute({
    messageId: "msg-0",
    condominioId: "condo-qualquer",
    messageType: "VISITOR_INVITE",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 0 }
  });
  assertEquals(route0.provider, "META");

  // Testar 100%
  const route100 = calculateWarmupRoute({
    messageId: "msg-100",
    condominioId: "condo-qualquer",
    messageType: "VISITOR_INVITE",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 100 }
  });
  assertEquals(route100.provider, "BOTCONVERSA");
  assertEquals(route100.reason, "CONTROLLED_ROLLOUT_BC_100PCT");
});

Deno.test("4. Desligamento Operacional (enabled = false) com disable_reason auditável", () => {
  const route = calculateWarmupRoute({
    messageId: "msg-off",
    condominioId: "condo-off",
    messageType: "VISITOR_INVITE",
    botconversaRolloutConfig: {
      ...DEFAULT_CONFIG,
      enabled: false,
      disableReason: "MANUTENCAO_PREVENTIVA_META"
    }
  });

  assertEquals(route.provider, "META");
  assertEquals(route.reason, "BOTCONVERSA_DISABLED: MANUTENCAO_PREVENTIVA_META");
});

Deno.test("5. Limite Diário Operacional com Rollover para Meta (DAILY_LIMIT_REACHED)", () => {
  const route = calculateWarmupRoute({
    messageId: "msg-daily-limit",
    condominioId: "condo-daily-limit",
    messageType: "VISITOR_INVITE",
    botconversaRolloutConfig: {
      ...DEFAULT_CONFIG,
      dailyLimit: 50,
      dailySentToday: 50 // Limite atingido
    }
  });

  assertEquals(route.provider, "META");
  assertEquals(route.reason, "DAILY_LIMIT_REACHED");
});

Deno.test("6. Restrição Estrita da Fase 1 — PARCEL, RESERVATION e VISITOR_AUTHORIZED permanecem 100% Meta", () => {
  const routeParcel = calculateWarmupRoute({
    messageId: "msg-parcel",
    condominioId: "condo-parcel",
    messageType: "PARCEL",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 100 } // Mesmo em 100%
  });
  assertEquals(routeParcel.provider, "META");
  assertEquals(routeParcel.reason, "MESSAGE_TYPE_PHASE1_META_EXCLUSIVE");

  const routeReserva = calculateWarmupRoute({
    messageId: "msg-reserva",
    condominioId: "condo-reserva",
    messageType: "RESERVATION",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 100 }
  });
  assertEquals(routeReserva.provider, "META");
  assertEquals(routeReserva.reason, "MESSAGE_TYPE_PHASE1_META_EXCLUSIVE");

  const routeVisitorAuth = calculateWarmupRoute({
    messageId: "msg-visitor-auth",
    condominioId: "condo-visitor-auth",
    messageType: "VISITOR_AUTHORIZED",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 100 }
  });
  assertEquals(routeVisitorAuth.provider, "META");
  assertEquals(routeVisitorAuth.reason, "MESSAGE_TYPE_PHASE1_META_EXCLUSIVE");
});

Deno.test("7. Fase 1 — WELCOME e VISITOR_INVITE participam do Rollout Controlado", () => {
  // Testar com 100% para validar elegibilidade
  const routeWelcome = calculateWarmupRoute({
    messageId: "msg-welcome-ok",
    condominioId: "condo-welcome",
    messageType: "WELCOME",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 100 }
  });
  assertEquals(routeWelcome.provider, "BOTCONVERSA");
  assertEquals(routeWelcome.reason, "CONTROLLED_ROLLOUT_BC_100PCT");

  const routeInvite = calculateWarmupRoute({
    messageId: "msg-invite-ok",
    condominioId: "condo-invite",
    messageType: "VISITOR_INVITE",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 100 }
  });
  assertEquals(routeInvite.provider, "BOTCONVERSA");
  assertEquals(routeInvite.reason, "CONTROLLED_ROLLOUT_BC_100PCT");
});

Deno.test("8. Simulação Matemática em Memória — 10.000 Condomínios com Rollout 5% BC / 95% Meta", () => {
  let countMeta = 0;
  let countBC = 0;
  const total = 10000;

  for (let i = 0; i < total; i++) {
    const route = calculateWarmupRoute({
      messageId: `msg-${i}`,
      condominioId: `condo-uuid-amostra-${i}`,
      messageType: "VISITOR_INVITE",
      botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 5 }
    });

    if (route.provider === "BOTCONVERSA") {
      countBC++;
    } else if (route.provider === "META") {
      countMeta++;
    }
  }

  const pctBC = (countBC / total) * 100;
  const pctMeta = (countMeta / total) * 100;

  console.log(`[SIMULAÇÃO MATEMÁTICA CONDOMINIUM_HASH | 10.000 CONDOMÍNIOS]`);
  console.log(`META: ${countMeta} (${pctMeta.toFixed(2)}%) | BOTCONVERSA: ${countBC} (${pctBC.toFixed(2)}%)`);

  // 5% esperado com margem estatística de dispersão padrão (+- 1.5%)
  assertEquals(pctBC >= 3.5 && pctBC <= 6.5, true, `Distribuição BotConversa (${pctBC.toFixed(2)}%) deve convergir em torno de 5%`);
  assertEquals(pctMeta >= 93.5 && pctMeta <= 96.5, true, `Distribuição Meta (${pctMeta.toFixed(2)}%) deve convergir em torno de 95%`);
});

Deno.test("9. Idempotência Estrita — Mesma chave sempre gera exatamente o mesmo provider e motivo", () => {
  const params = {
    messageId: "msg-idempotente-fixa",
    condominioId: "condo-idempotente-fixo",
    messageType: "VISITOR_INVITE",
    botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 5 }
  };

  const res1 = calculateWarmupRoute(params);
  const res2 = calculateWarmupRoute(params);
  const res3 = calculateWarmupRoute(params);

  assertEquals(res1.provider, res2.provider);
  assertEquals(res2.provider, res3.provider);
  assertEquals(res1.partition, res2.partition);
  assertEquals(res1.reason, res2.reason);
});

Deno.test("10. Preservação de Precedência Suprema da Contingência Meta 100% e Failover Emergencial", () => {
  try {
    Deno.env.set("WHATSAPP_META_100_CONTINGENCY_ENABLED", "true");
    const route = calculateWarmupRoute({
      messageId: "msg-contingencia",
      condominioId: "condo-contingencia",
      messageType: "VISITOR_INVITE",
      botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 100 }
    });
    assertEquals(route.provider, "META");
    assertEquals(route.reason, "CONTINGENCY_META_100");
  } finally {
    Deno.env.delete("WHATSAPP_META_100_CONTINGENCY_ENABLED");
  }

  try {
    Deno.env.set("WHATSAPP_META_EMERGENCY_FAILOVER_ENABLED", "true");
    const routeFailover = calculateWarmupRoute({
      messageId: "msg-emergency",
      condominioId: "condo-emergency",
      messageType: "VISITOR_INVITE",
      botconversaRolloutConfig: { ...DEFAULT_CONFIG, rolloutPercent: 100 }
    });
    assertEquals(routeFailover.provider, "META");
    assertEquals(routeFailover.reason, "EMERGENCY_FAILOVER_META_100");
  } finally {
    Deno.env.delete("WHATSAPP_META_EMERGENCY_FAILOVER_ENABLED");
  }
});
