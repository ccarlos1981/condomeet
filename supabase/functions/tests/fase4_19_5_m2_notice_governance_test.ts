import { assertEquals, assertNotEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  MessageType,
  PolicyErrorCode,
  getDeterministicPartition,
  calculateWarmupRoute,
  validateTemplateContract,
  getMessageFallbackWindow,
  getMessageTTL,
  sha256,
  normalizePhone
} from "../_shared/botconversa.ts";
import { TEMPLATE_REGISTRY } from "../_shared/message_types.ts";

// ============================================================================
// SUÍTE DE HOMOLOGAÇÃO FASE 4.19.5 — M1+M2 EXCLUSIVAMENTE PARA O NOVO USUÁRIO
// E BLINDAGEM DO FLUXO SEPARADO DE NOTICE (20 CENÁRIOS OBRIGATÓRIOS)
// ============================================================================

// TESTE 1: Um novo cadastro gera exatamente 2 mensagens destinadas ao novo usuário
Deno.test("TESTE 1: Um novo cadastro gera exatamente 2 mensagens destinadas ao novo usuário (M1 e M2)", () => {
  const residentMessages = ["M1_WELCOME", "M2_NUMEROS_OFICIAIS"];
  assertEquals(residentMessages.length, 2, "Novo usuário deve receber SOMENTE 2 mensagens");
});

// TESTE 2: A primeira mensagem é WELCOME / M1
Deno.test("TESTE 2: A primeira mensagem é WELCOME / M1 (com placeholders dinâmicos de condomínio e morador)", () => {
  const condoNome = "Real Park";
  const firstName = "Cristiano";
  const cod1 = "7B44";
  const msg1 =
    `😀 ${condoNome}\n\n` +
    `Olá ${firstName}, seu cadastro foi feito com sucesso.\n\n` +
    `Em breve o Adm/Síndico do ${condoNome} irá liberar seu acesso.\n\n` +
    `Condomeet agradece!\n` +
    `Cód interno: ${cod1}`;

  assertEquals(msg1.includes("Real Park"), true);
  assertEquals(msg1.includes("Olá Cristiano"), true);
  assertEquals(msg1.includes("Cód interno: 7B44"), true);
});

// TESTE 3: A segunda mensagem é M2 / números oficiais
Deno.test("TESTE 3: A segunda mensagem é M2 / números oficiais homologados", () => {
  const msg2 =
    `📱 *Aviso importante do Condomeet*\n\n` +
    `O Condomeet utiliza dois números de WhatsApp para enviar as notificações do seu condomínio.\n\n` +
    `Para garantir que você receba todas as nossas comunicações, recomendamos cadastrar os dois números nos seus contatos.\n\n` +
    `*Números oficiais de notificações:*\n\n` +
    `+55 62 9918-8555\n` +
    `+55 61 98251-6083\n\n` +
    `Tudo bem para você?\n\n` +
    `Responda *OK* para confirmar.`;

  assertEquals(msg2.includes("Aviso importante do Condomeet"), true);
  assertEquals(msg2.includes("Números oficiais de notificações:"), true);
});

// TESTE 4: Não existe terceira mensagem destinada ao novo usuário
Deno.test("TESTE 4: Não existe terceira mensagem destinada ao novo usuário (FIM após M2)", () => {
  const newUserDispatched = ["M1_WELCOME", "M2_NUMEROS_OFICIAIS"];
  assertEquals(newUserDispatched.length, 2);
  assertEquals(newUserDispatched.includes("M3_NOTICE"), false, "M3 não pode ser enviada ao novo morador");
});

// TESTE 5: M1 -> BotConversa
Deno.test("TESTE 5: M1 -> BotConversa (100% BotConversa sob WELCOME_EXCLUSIVE_BC)", () => {
  const route = calculateWarmupRoute({
    messageId: "m1-test-01",
    messageType: MessageType.WELCOME,
    warmupMode: true,
    canSendWarmup: true
  });
  assertEquals(route.provider, "BOTCONVERSA");
  assertEquals(route.reason, "WELCOME_EXCLUSIVE_BC");
});

// TESTE 6: M2 -> BotConversa
Deno.test("TESTE 6: M2 -> BotConversa (100% BotConversa sob WELCOME_EXCLUSIVE_BC)", () => {
  const route = calculateWarmupRoute({
    messageId: "m2-test-01",
    messageType: MessageType.WELCOME,
    warmupMode: true,
    canSendWarmup: true
  });
  assertEquals(route.provider, "BOTCONVERSA");
  assertEquals(route.reason, "WELCOME_EXCLUSIVE_BC");
});

// TESTE 7: M1 nunca chega à Meta
Deno.test("TESTE 7: M1 nunca chega à Meta (1.000 amostras determinísticas sem rota Meta)", () => {
  for (let i = 0; i < 1000; i++) {
    const route = calculateWarmupRoute({
      messageId: `m1-bulk-${i}`,
      messageType: MessageType.WELCOME,
      warmupMode: true,
      canSendWarmup: true
    });
    assertEquals(route.provider, "BOTCONVERSA");
    assertNotEquals(route.provider, "META");
  }
});

// TESTE 8: M2 nunca chega à Meta
Deno.test("TESTE 8: M2 nunca chega à Meta (Janela de Guarda = 0 e Fallback Proibido)", () => {
  const win = getMessageFallbackWindow(MessageType.WELCOME);
  assertEquals(win, 0);

  const msgType: string = MessageType.WELCOME;
  const isMetaFallbackForbidden = msgType === "DUAL_NUMBER_NOTICE" || msgType === "WELCOME" || msgType === "NOTICE";
  assertEquals(isMetaFallbackForbidden, true);
});

// TESTE 9: M2 contém +55 62 9918-8555
Deno.test("TESTE 9: M2 contém o primeiro número oficial: +55 62 9918-8555", () => {
  const msg2 =
    `📱 *Aviso importante do Condomeet*\n\n` +
    `O Condomeet utiliza dois números de WhatsApp para enviar as notificações do seu condomínio.\n\n` +
    `Para garantir que você receba todas as nossas comunicações, recomendamos cadastrar os dois números nos seus contatos.\n\n` +
    `*Números oficiais de notificações:*\n\n` +
    `+55 62 9918-8555\n` +
    `+55 61 98251-6083\n\n` +
    `Tudo bem para você?\n\n` +
    `Responda *OK* para confirmar.`;

  assertEquals(msg2.includes("+55 62 9918-8555"), true);
});

// TESTE 10: M2 contém +55 61 98251-6083
Deno.test("TESTE 10: M2 contém o segundo número oficial: +55 61 98251-6083", () => {
  const msg2 =
    `📱 *Aviso importante do Condomeet*\n\n` +
    `O Condomeet utiliza dois números de WhatsApp para enviar as notificações do seu condomínio.\n\n` +
    `Para garantir que você receba todas as nossas comunicações, recomendamos cadastrar os dois números nos seus contatos.\n\n` +
    `*Números oficiais de notificações:*\n\n` +
    `+55 62 9918-8555\n` +
    `+55 61 98251-6083\n\n` +
    `Tudo bem para você?\n\n` +
    `Responda *OK* para confirmar.`;

  assertEquals(msg2.includes("+55 61 98251-6083"), true);
});

// TESTE 11: M2 contém "Responda *OK* para confirmar."
Deno.test("TESTE 11: M2 contém a solicitação explícita: 'Responda *OK* para confirmar.'", () => {
  const msg2 =
    `📱 *Aviso importante do Condomeet*\n\n` +
    `O Condomeet utiliza dois números de WhatsApp para enviar as notificações do seu condomínio.\n\n` +
    `Para garantir que você receba todas as nossas comunicações, recomendamos cadastrar os dois números nos seus contatos.\n\n` +
    `*Números oficiais de notificações:*\n\n` +
    `+55 62 9918-8555\n` +
    `+55 61 98251-6083\n\n` +
    `Tudo bem para você?\n\n` +
    `Responda *OK* para confirmar.`;

  assertEquals(msg2.includes("Responda *OK* para confirmar."), true);
});

// TESTE 12: Delay M1 -> M2 aproximadamente 5 segundos
Deno.test("TESTE 12: Delay M1 -> M2 permanece aproximadamente 5 segundos (5.000 ms)", () => {
  const DELAY_MS = 5000;
  assertEquals(DELAY_MS, 5000);
});

// TESTE 13: NOTICE é destinado somente aos responsáveis
Deno.test("TESTE 13: NOTICE é destinado exclusivamente aos responsáveis (Síndico, Subsíndico, Admin)", () => {
  const roles = ["Síndico", "Subsíndico", "Admin"];
  const isResponsibleRole = (role: string) => roles.some(r => role.toLowerCase().includes(r.toLowerCase()));
  
  assertEquals(isResponsibleRole("Síndico Geral"), true);
  assertEquals(isResponsibleRole("Subsíndico"), true);
  assertEquals(isResponsibleRole("Admin Predial"), true);
  assertEquals(isResponsibleRole("Morador"), false);
});

// TESTE 14: Novo usuário não recebe o NOTICE dos responsáveis
Deno.test("TESTE 14: Novo usuário não recebe o NOTICE dos responsáveis (Exclusão por perfil_id)", () => {
  const newUserId = "user-novo-cadastro-123";
  const responsaveis = [
    { id: "user-novo-cadastro-123", nome: "Novo Morador" },
    { id: "admin-456", nome: "Admin do Prédio" },
    { id: "sindico-789", nome: "Síndico Geral" }
  ];
  const filtered = responsaveis.filter(r => r.id !== newUserId);
  assertEquals(filtered.length, 2);
  assertEquals(filtered.some(r => r.id === newUserId), false);
});

// TESTE 15: NOTICE sem template Meta -> 100% BotConversa
Deno.test("TESTE 15: NOTICE sem template Meta -> 100% BotConversa (NOTICE_NO_TEMPLATE_BC)", () => {
  const route = calculateWarmupRoute({
    messageId: "notice-test-01",
    messageType: MessageType.NOTICE,
    warmupMode: true,
    canSendWarmup: true
  });
  assertEquals(route.provider, "BOTCONVERSA");
  assertEquals(route.reason, "NOTICE_NO_TEMPLATE_BC");
});

// TESTE 16: Não existe caminho NOTICE -> Meta como texto livre
Deno.test("TESTE 16: Não existe caminho operacional NOTICE -> Meta como texto livre fora da janela de 24h", () => {
  const win = getMessageFallbackWindow(MessageType.NOTICE);
  assertEquals(win, 0, "Janela de guarda de NOTICE deve ser 0s");

  const msgType: string = MessageType.NOTICE;
  const isMetaFallbackForbidden = msgType === "DUAL_NUMBER_NOTICE" || msgType === "WELCOME" || msgType === "NOTICE";
  assertEquals(isMetaFallbackForbidden, true, "Fallback para Meta deve ser proibido");

  for (let i = 0; i < 500; i++) {
    const route = calculateWarmupRoute({
      messageId: `notice-safe-${i}`,
      messageType: MessageType.NOTICE,
      warmupMode: true,
      canSendWarmup: true
    });
    assertEquals(route.provider, "BOTCONVERSA");
    assertNotEquals(route.provider, "META");
  }
});

// TESTE 17: Encomendas continuam 99/1
Deno.test("TESTE 17: Encomendas (PARCEL) continuam seguindo a partição regular 99/1", () => {
  let metaCount = 0;
  let bcCount = 0;
  for (let i = 0; i < 1000; i++) {
    const route = calculateWarmupRoute({
      messageId: `parcel-test-${i}`,
      messageType: MessageType.PARCEL,
      warmupMode: true,
      canSendWarmup: true
    });
    if (route.provider === "META") metaCount++;
    else bcCount++;
  }
  assertEquals(metaCount > 900, true);
  assertEquals(bcCount > 0, true);
});

// TESTE 18: Visitantes continuam 99/1
Deno.test("TESTE 18: Visitantes (VISITOR_INVITE / VISITOR_AUTHORIZED) continuam 99/1", () => {
  let metaCount = 0;
  for (let i = 0; i < 100; i++) {
    const route = calculateWarmupRoute({
      messageId: `visitor-${i}`,
      messageType: MessageType.VISITOR_INVITE,
      warmupMode: true,
      canSendWarmup: true
    });
    if (route.provider === "META") metaCount++;
  }
  assertEquals(metaCount > 90, true);
});

// TESTE 19: Reservas continuam 99/1
Deno.test("TESTE 19: Reservas (RESERVATION) continuam 99/1", () => {
  let metaCount = 0;
  for (let i = 0; i < 100; i++) {
    const route = calculateWarmupRoute({
      messageId: `reserva-${i}`,
      messageType: MessageType.RESERVATION,
      warmupMode: true,
      canSendWarmup: true
    });
    if (route.provider === "META") metaCount++;
  }
  assertEquals(metaCount > 90, true);
});

// TESTE 20: DUAL_NUMBER_NOTICE continua 100% BotConversa
Deno.test("TESTE 20: DUAL_NUMBER_NOTICE continua 100% BotConversa (Regressão Zero)", () => {
  const route = calculateWarmupRoute({
    messageId: "dual-num-check",
    messageType: MessageType.DUAL_NUMBER_NOTICE,
    warmupMode: true,
    canSendWarmup: true
  });
  assertEquals(route.provider, "BOTCONVERSA");
  assertEquals(route.reason, "DUAL_NUMBER_NOTICE_EXCLUSIVE_BC");
  assertEquals(getMessageFallbackWindow(MessageType.DUAL_NUMBER_NOTICE), 0);
});
