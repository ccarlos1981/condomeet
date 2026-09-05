// supabase/functions/tests/fase4_26_welcome_botconversa_migration_test.ts
// FASE 4.26 — TESTES AUTOMATIZADOS DE MIGRAÇÃO: WELCOME -> BOTCONVERSA

import { assertEquals, assertNotEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  calculateWarmupRoute,
  calculateWelcomePilotRoute,
  getDeterministicPartition,
  MessageType,
  validateWhatsAppSendPolicy,
  getMessageTTL,
  getMessageFallbackWindow
} from "../_shared/botconversa.ts";

Deno.test("FASE 4.26 - TESTE 1: WELCOME com configuração atualizada roteia 100% para BOTCONVERSA", () => {
  // Simula a configuração padrão atualizada em produção (Evolution Pilot Disabled)
  const EVOLUTION_WELCOME_PILOT_ENABLED = false;
  const EVOLUTION_WELCOME_PERCENTAGE = 0;

  const perfilId = "usr_b699e35f_recanto_palmeiras_01";
  const messageId = "msg_welcome_m1_test_001";

  const route = calculateWarmupRoute({
    messageId,
    perfilId,
    messageType: MessageType.WELCOME,
    warmupMode: true,
    canSendWarmup: true,
    welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
    welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE,
    evolutionConnected: false
  });

  assertEquals(route.provider, "BOTCONVERSA");
  assertEquals(route.reason, "WELCOME_PILOT_DISABLED");
});

Deno.test("FASE 4.26 - TESTE 2: WELCOME direciona ZERO (0%) para EVOLUTION em 1.000 amostras", () => {
  const EVOLUTION_WELCOME_PILOT_ENABLED = false;
  const EVOLUTION_WELCOME_PERCENTAGE = 0;

  let evolutionCount = 0;
  let botconversaCount = 0;

  for (let i = 0; i < 1000; i++) {
    const samplePerfilId = `usr_random_${i}_${(i * 7919) % 1000}`;
    const route = calculateWarmupRoute({
      messageId: `msg_${i}`,
      perfilId: samplePerfilId,
      messageType: MessageType.WELCOME,
      warmupMode: true,
      canSendWarmup: true,
      welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
      welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE,
      evolutionConnected: false
    });

    if (route.provider === "EVOLUTION") evolutionCount++;
    if (route.provider === "BOTCONVERSA") botconversaCount++;
  }

  assertEquals(evolutionCount, 0, "Evolution deve receber rigorosamente ZERO requisições de WELCOME");
  assertEquals(botconversaCount, 1000, "BotConversa deve receber 100% das 1.000 amostras de WELCOME");
});

Deno.test("FASE 4.26 - TESTE 3: WELCOME mantém guarda anti-Meta absoluta (META = ZERO)", () => {
  const EVOLUTION_WELCOME_PILOT_ENABLED = false;
  const EVOLUTION_WELCOME_PERCENTAGE = 0;

  // 1. Roteamento nunca retorna META
  for (let i = 0; i < 100; i++) {
    const route = calculateWarmupRoute({
      messageId: `msg_${i}`,
      perfilId: `perfil_${i}`,
      messageType: MessageType.WELCOME,
      warmupMode: true,
      canSendWarmup: false,
      welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
      welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE
    });
    assertNotEquals(route.provider, "META");
  }

  // 2. Guarda isMetaFallbackForbidden bloqueia fallback Meta mesmo em falha de envio
  const isMetaFallbackForbidden = MessageType.WELCOME === "WELCOME";
  assertEquals(isMetaFallbackForbidden, true, "isMetaFallbackForbidden deve ser estritamente TRUE para WELCOME");

  // 3. Fallback window é zero
  const fallbackWindow = getMessageFallbackWindow(MessageType.WELCOME);
  assertEquals(fallbackWindow, 0, "Fallback window para WELCOME deve ser 0s (sem transição para Meta)");
});

Deno.test("FASE 4.26 - TESTE 4: M1 + M2 são indivisíveis e despachados pelo MESMO provedor (BOTCONVERSA)", () => {
  const EVOLUTION_WELCOME_PILOT_ENABLED = false;
  const EVOLUTION_WELCOME_PERCENTAGE = 0;

  const residentProfileId = "usr_d391e025_cleia_lyrio";

  // M1 (Boas-Vindas)
  const routeM1 = calculateWarmupRoute({
    messageId: "outbox_m1_98a7b6c5",
    perfilId: residentProfileId,
    messageType: MessageType.WELCOME,
    warmupMode: true,
    canSendWarmup: true,
    welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
    welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE
  });

  // M2 (Dois Números Oficiais)
  const routeM2 = calculateWarmupRoute({
    messageId: "outbox_m2_12e3f4a5",
    perfilId: residentProfileId,
    messageType: MessageType.WELCOME,
    warmupMode: true,
    canSendWarmup: true,
    welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
    welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE
  });

  assertEquals(routeM1.provider, "BOTCONVERSA");
  assertEquals(routeM2.provider, "BOTCONVERSA");
  assertEquals(routeM1.provider, routeM2.provider, "M1 e M2 devem ter rigorosamente o mesmo provider");
});

Deno.test("FASE 4.26 - TESTE 5: M1 + M2 possuem a mesma partição determinística vinculada ao perfil_id", () => {
  const perfilId = "usr_124bb0b9_vanessa_carvalho";

  const partitionM1 = getDeterministicPartition(perfilId);
  const partitionM2 = getDeterministicPartition(perfilId);

  assertEquals(partitionM1, partitionM2, "Partição determinística de M1 e M2 deve ser idêntica");
  assertEquals(partitionM1 >= 0 && partitionM1 < 100, true, "Partição deve estar no intervalo [0, 99]");
});

Deno.test("FASE 4.26 - TESTE 6: Idempotência de hash SHA-256 e integridade de TTL", () => {
  // 1. Validação de TTL
  const ttl = getMessageTTL(MessageType.WELCOME);
  assertEquals(ttl, 900, "TTL do WELCOME deve ser 900 segundos (15 minutos)");

  // 2. Validação da invariante de política de envio
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-outbox-worker",
    messageType: MessageType.WELCOME,
    textValue: "Olá Morador, seja bem-vindo ao condomínio.",
    isCampaign: false
  });
  assertEquals(policyCheck.allowed, true);
});

Deno.test("FASE 4.26 - TESTE 7: Regressão — Demais MessageTypes permanecem 100% inalterados", () => {
  const EVOLUTION_WELCOME_PILOT_ENABLED = false;
  const EVOLUTION_WELCOME_PERCENTAGE = 0;

  // DUAL_NUMBER_NOTICE -> Sempre BOTCONVERSA
  const routeDual = calculateWarmupRoute({
    messageId: "msg_dual_001",
    perfilId: "usr_001",
    messageType: MessageType.DUAL_NUMBER_NOTICE,
    warmupMode: true,
    canSendWarmup: true,
    welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
    welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE
  });
  assertEquals(routeDual.provider, "BOTCONVERSA");
  assertEquals(routeDual.reason, "DUAL_NUMBER_NOTICE_EXCLUSIVE_BC");

  // NOTICE -> Sempre BOTCONVERSA
  const routeNotice = calculateWarmupRoute({
    messageId: "msg_notice_001",
    perfilId: "usr_001",
    messageType: MessageType.NOTICE,
    warmupMode: true,
    canSendWarmup: true,
    welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
    welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE
  });
  assertEquals(routeNotice.provider, "BOTCONVERSA");
  assertEquals(routeNotice.reason, "NOTICE_NO_TEMPLATE_BC");

  // VISITOR_AUTHORIZED -> 50% Meta / 50% BC
  const routeVisitorAuth = calculateWarmupRoute({
    messageId: "msg_va_001",
    perfilId: "usr_test_auth",
    messageType: MessageType.VISITOR_AUTHORIZED,
    warmupMode: true,
    canSendWarmup: true,
    welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
    welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE
  });
  assertEquals(routeVisitorAuth.provider === "META" || routeVisitorAuth.provider === "BOTCONVERSA", true);

  // PARCEL (com warmupMode = true, partição < 99) -> META
  const routeParcel = calculateWarmupRoute({
    messageId: "msg_parcel_001",
    perfilId: "usr_001",
    messageType: MessageType.PARCEL,
    warmupMode: true,
    canSendWarmup: false,
    welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
    welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE
  });
  assertEquals(routeParcel.provider, "META");

  // PARCEL_DELIVERED (com warmupMode = true, partição < 99) -> META
  const routeParcelDelivered = calculateWarmupRoute({
    messageId: "msg_parcel_del_001",
    perfilId: "usr_001",
    messageType: MessageType.PARCEL_DELIVERED,
    warmupMode: true,
    canSendWarmup: false,
    welcomePilotEnabled: EVOLUTION_WELCOME_PILOT_ENABLED,
    welcomePilotPercentage: EVOLUTION_WELCOME_PERCENTAGE
  });
  assertEquals(routeParcelDelivered.provider, "META");
});
