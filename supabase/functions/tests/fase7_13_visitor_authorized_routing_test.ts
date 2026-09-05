import { assertEquals } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { calculateWarmupRoute, getDeterministicPartition } from "../_shared/botconversa.ts";

Deno.test("FASE 7.13.1 — TESTE 1: VISITOR_AUTHORIZED com partição < 50 deve rotear para META (50%)", () => {
  // Encontrar uma chave com partição conhecida < 50
  // Exemplo: messageId que gera partição < 50
  let foundKey = "";
  for (let i = 0; i < 100; i++) {
    const key = `test-visitor-meta-${i}`;
    if (getDeterministicPartition(key) < 50) {
      foundKey = key;
      break;
    }
  }

  const route = calculateWarmupRoute({
    messageId: foundKey,
    perfilId: null,
    messageType: "VISITOR_AUTHORIZED",
    warmupMode: true,
    canSendWarmup: true,
    welcomePilotEnabled: true,
    welcomePilotPercentage: 100,
    evolutionConnected: true
  });

  assertEquals(route.provider, "META");
  assertEquals(route.reason, "VISITOR_AUTHORIZED_50PCT_META");
  assertEquals(route.partition < 50, true);
});

Deno.test("FASE 7.13.1 — TESTE 2: VISITOR_AUTHORIZED com partição >= 50 deve rotear para BOTCONVERSA (50%)", () => {
  let foundKey = "";
  for (let i = 0; i < 100; i++) {
    const key = `test-visitor-bc-${i}`;
    if (getDeterministicPartition(key) >= 50) {
      foundKey = key;
      break;
    }
  }

  const route = calculateWarmupRoute({
    messageId: foundKey,
    perfilId: null,
    messageType: "VISITOR_AUTHORIZED",
    warmupMode: true,
    canSendWarmup: true,
    welcomePilotEnabled: true,
    welcomePilotPercentage: 100,
    evolutionConnected: true
  });

  assertEquals(route.provider, "BOTCONVERSA");
  assertEquals(route.reason, "VISITOR_AUTHORIZED_50PCT_BOTCONVERSA");
  assertEquals(route.partition >= 50, true);
});

Deno.test("FASE 7.13.1 — TESTE 3: VISITOR_AUTHORIZED Idempotência estrita — Mesma chave sempre gera o mesmo provider", () => {
  const messageId = "f47ac10b-58cc-4372-a567-0e02b2c3d479";
  const perfilId = "perfil-morador-123";

  const route1 = calculateWarmupRoute({
    messageId,
    perfilId,
    messageType: "VISITOR_AUTHORIZED",
    warmupMode: true,
    canSendWarmup: true
  });

  const route2 = calculateWarmupRoute({
    messageId,
    perfilId,
    messageType: "VISITOR_AUTHORIZED",
    warmupMode: true,
    canSendWarmup: false // mesmo se canSendWarmup mudar
  });

  const route3 = calculateWarmupRoute({
    messageId,
    perfilId,
    messageType: "VISITOR_AUTHORIZED",
    warmupMode: false, // mesmo se warmupMode mudar
    canSendWarmup: true
  });

  assertEquals(route1.provider, route2.provider);
  assertEquals(route1.provider, route3.provider);
  assertEquals(route1.partition, route2.partition);
  assertEquals(route1.reason, route2.reason);
});

Deno.test("FASE 7.13.1 — TESTE 4: VISITOR_AUTHORIZED NUNCA deve rotear para EVOLUTION (0% Evolution)", () => {
  // Testar 1000 chaves aleatórias e garantir que NENHUMA retorna EVOLUTION
  for (let i = 0; i < 1000; i++) {
    const route = calculateWarmupRoute({
      messageId: `msg-uuid-${i}`,
      perfilId: `perfil-uuid-${i}`,
      messageType: "VISITOR_AUTHORIZED",
      warmupMode: true,
      canSendWarmup: true,
      welcomePilotEnabled: true,
      welcomePilotPercentage: 100,
      evolutionConnected: true
    });

    assertEquals(route.provider === "EVOLUTION", false, `Erro: VISITOR_AUTHORIZED retornou EVOLUTION para chave index=${i}`);
    assertEquals(route.provider === "META" || route.provider === "BOTCONVERSA", true);
  }
});

Deno.test("FASE 7.13.1 — TESTE 5: Simulação Matemática em Memória — 10.000 chaves com distribuição 50% Meta / 50% BC / 0% Evo", () => {
  let metaCount = 0;
  let bcCount = 0;
  let evoCount = 0;
  const TOTAL_SAMPLES = 10000;

  for (let i = 0; i < TOTAL_SAMPLES; i++) {
    // Gerar UUID sintético para simulação
    const syntheticId = `d8f6b9c2-7a3e-4b1f-9c8d-${i.toString().padStart(12, "0")}`;
    const route = calculateWarmupRoute({
      messageId: syntheticId,
      messageType: "VISITOR_AUTHORIZED",
      warmupMode: true,
      canSendWarmup: true,
      welcomePilotEnabled: true,
      welcomePilotPercentage: 100
    });

    if (route.provider === "META") metaCount++;
    else if (route.provider === "BOTCONVERSA") bcCount++;
    else if (route.provider === "EVOLUTION") evoCount++;
  }

  const metaPct = (metaCount / TOTAL_SAMPLES) * 100;
  const bcPct = (bcCount / TOTAL_SAMPLES) * 100;
  const evoPct = (evoCount / TOTAL_SAMPLES) * 100;

  console.log(`[SIMULAÇÃO MATEMÁTICA LOCAL — ZERO TRÁFEGO | 10.000 AMOSTRAS]`);
  console.log(`META: ${metaCount} (${metaPct.toFixed(2)}%) | BOTCONVERSA: ${bcCount} (${bcPct.toFixed(2)}%) | EVOLUTION: ${evoCount} (${evoPct.toFixed(2)}%)`);

  assertEquals(evoCount, 0, "Evolution deve ser rigorosamente 0");
  assertEquals(metaPct >= 48 && metaPct <= 52, true, `Meta fora da faixa de 50% +/- 2%: ${metaPct}%`);
  assertEquals(bcPct >= 48 && bcPct <= 52, true, `BotConversa fora da faixa de 50% +/- 2%: ${bcPct}%`);
});

Deno.test("FASE 7.13.1 — TESTE 6: Proteção Absoluta das Encomendas — PARCEL permanece 100% inalterado", () => {
  // Testar uma chave que em VISITOR_AUTHORIZED iria para BC (partição >= 50)
  let foundKey = "";
  for (let i = 0; i < 100; i++) {
    const key = `parcel-key-${i}`;
    const part = getDeterministicPartition(key);
    if (part >= 50 && part < 99) {
      foundKey = key;
      break;
    }
  }

  const routeParcel = calculateWarmupRoute({
    messageId: foundKey,
    messageType: "PARCEL",
    warmupMode: true,
    canSendWarmup: true
  });

  // Em PARCEL com partição 0..98 deve continuar indo para META Primary
  assertEquals(routeParcel.provider, "META");
  assertEquals(routeParcel.reason, "WARMUP_ROTA_META_99PCT");
});

Deno.test("FASE 7.13.1 — TESTE 7: Proteção Absoluta das Encomendas — PARCEL_DELIVERED permanece 100% inalterado", () => {
  let foundKey = "";
  for (let i = 0; i < 100; i++) {
    const key = `parcel-deliv-key-${i}`;
    const part = getDeterministicPartition(key);
    if (part >= 50 && part < 99) {
      foundKey = key;
      break;
    }
  }

  const routeParcelDelivered = calculateWarmupRoute({
    messageId: foundKey,
    messageType: "PARCEL_DELIVERED",
    warmupMode: true,
    canSendWarmup: true
  });

  assertEquals(routeParcelDelivered.provider, "META");
  assertEquals(routeParcelDelivered.reason, "WARMUP_ROTA_META_99PCT");
});

Deno.test("FASE 7.13.1 — TESTE 8: Proteção de Demais Fluxos — NOTICE permanece 100% BotConversa", () => {
  const routeNotice = calculateWarmupRoute({
    messageId: "notice-uuid-1",
    messageType: "NOTICE",
    warmupMode: true,
    canSendWarmup: true
  });

  assertEquals(routeNotice.provider, "BOTCONVERSA");
  assertEquals(routeNotice.reason, "NOTICE_NO_TEMPLATE_BC");
});

Deno.test("FASE 7.13.1 — TESTE 9: Proteção de Demais Fluxos — DUAL_NUMBER_NOTICE permanece 100% BotConversa", () => {
  const routeDual = calculateWarmupRoute({
    messageId: "dual-uuid-1",
    messageType: "DUAL_NUMBER_NOTICE",
    warmupMode: true,
    canSendWarmup: true
  });

  assertEquals(routeDual.provider, "BOTCONVERSA");
  assertEquals(routeDual.reason, "DUAL_NUMBER_NOTICE_EXCLUSIVE_BC");
});

Deno.test("FASE 7.13.1 — TESTE 10: Proteção de Demais Fluxos — WELCOME permanece sob piloto de boas-vindas", () => {
  const routeWelcomeDisabled = calculateWarmupRoute({
    messageId: "welcome-uuid-1",
    messageType: "WELCOME",
    warmupMode: true,
    canSendWarmup: true,
    welcomePilotEnabled: false
  });

  assertEquals(routeWelcomeDisabled.provider, "BOTCONVERSA");
  assertEquals(routeWelcomeDisabled.reason, "WELCOME_PILOT_DISABLED");
});
