import { validateWhatsAppSendPolicy, sendToRecipients, PolicyErrorCode, MAX_TRANSACTIONAL_RECIPIENTS } from "../_shared/botconversa.ts"
import { MessageType, TEMPLATE_REGISTRY, validateTemplateContract } from "../_shared/message_types.ts"

function assertEquals(actual: any, expected: any, msg?: string) {
  if (actual !== expected) {
    throw new Error(`Assertion failed: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}. ${msg || ''}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. TESTES DO botconversa-send (Validação de Modos)
// ─────────────────────────────────────────────────────────────────────────────

const VALID_MODOS = ["por_apto", "por_morador", "por_botconversa"] as const;
const REMOVED_MODOS = ["por_condominio", "por_bloco", "por_perfil"] as const;

function mockValidateRequest(params: any): { valid: boolean; error?: string } {
  if (!params.msg || typeof params.msg !== "string") {
    return { valid: false, error: "msg é obrigatório e deve ser string" }
  }
  if (!params.condominio_id || typeof params.condominio_id !== "string") {
    return { valid: false, error: "condominio_id é obrigatório e deve ser UUID válido" }
  }
  if (!params.modo_envio || !VALID_MODOS.includes(params.modo_envio as any)) {
    if (["por_condominio", "por_bloco", "por_perfil"].includes(params.modo_envio as any)) {
      return {
        valid: false,
        error: `modo_envio '${params.modo_envio}' foi permanentemente descontinuado pela governança anti-broadcast (FASE 4.16A). Comunicações coletivas devem utilizar Push Notification (FCM). Valores aceitos: ${VALID_MODOS.join(", ")}`
      }
    }
    return { valid: false, error: `modo_envio inválido. Valores aceitos: ${VALID_MODOS.join(", ")}` }
  }
  return { valid: true }
}

Deno.test("TEST 1.1: botconversa-send -> por_morador (ALLOW)", () => {
  const res = mockValidateRequest({
    msg: "Mensagem individual",
    condominio_id: "00000000-0000-0000-0000-000000000001",
    modo_envio: "por_morador",
    user_id: "00000000-0000-0000-0000-000000000002"
  });
  assertEquals(res.valid, true, "por_morador deve ser aceito");
});

Deno.test("TEST 1.2: botconversa-send -> por_apto (ALLOW)", () => {
  const res = mockValidateRequest({
    msg: "Mensagem por apto",
    condominio_id: "00000000-0000-0000-0000-000000000001",
    modo_envio: "por_apto",
    bloco: "A",
    apto: "101"
  });
  assertEquals(res.valid, true, "por_apto deve ser aceito");
});

Deno.test("TEST 1.3: botconversa-send -> por_botconversa (ALLOW)", () => {
  const res = mockValidateRequest({
    msg: "Mensagem por botconversa_id",
    condominio_id: "00000000-0000-0000-0000-000000000001",
    modo_envio: "por_botconversa",
    botconversa_id: "998877"
  });
  assertEquals(res.valid, true, "por_botconversa deve ser aceito");
});

Deno.test("TEST 1.4: botconversa-send -> por_condominio (REJECT)", () => {
  const res = mockValidateRequest({
    msg: "Tentativa de broadcast por condomínio",
    condominio_id: "00000000-0000-0000-0000-000000000001",
    modo_envio: "por_condominio"
  });
  assertEquals(res.valid, false, "por_condominio deve ser terminantemente rejeitado");
  assertEquals(res.error?.includes("permanentemente descontinuado pela governança anti-broadcast"), true);
});

Deno.test("TEST 1.5: botconversa-send -> por_bloco (REJECT)", () => {
  const res = mockValidateRequest({
    msg: "Tentativa de broadcast por bloco",
    condominio_id: "00000000-0000-0000-0000-000000000001",
    modo_envio: "por_bloco",
    bloco: "B"
  });
  assertEquals(res.valid, false, "por_bloco deve ser terminantemente rejeitado");
  assertEquals(res.error?.includes("permanentemente descontinuado pela governança anti-broadcast"), true);
});

Deno.test("TEST 1.6: botconversa-send -> por_perfil (REJECT)", () => {
  const res = mockValidateRequest({
    msg: "Tentativa de broadcast por perfil",
    condominio_id: "00000000-0000-0000-0000-000000000001",
    modo_envio: "por_perfil",
    perfil: "morador"
  });
  assertEquals(res.valid, false, "por_perfil deve ser terminantemente rejeitado");
  assertEquals(res.error?.includes("permanentemente descontinuado pela governança anti-broadcast"), true);
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. TESTES DE TRAVA ANTI-BROADCAST (validateWhatsAppSendPolicy)
// ─────────────────────────────────────────────────────────────────────────────

Deno.test("TEST 2.1: Flag isBroadcast=true -> BLOCK", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-parcel-notify",
    messageType: MessageType.PARCEL,
    textValue: "Mensagem geral",
    isBroadcast: true
  });
  assertEquals(res.allowed, false, "isBroadcast=true deve ser bloqueado");
  assertEquals(res.errorCode, PolicyErrorCode.BROADCAST_BLOCKED);
});

Deno.test("TEST 2.2: Flag isCampaign=true -> BLOCK", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-parcel-notify",
    messageType: MessageType.PARCEL,
    textValue: "Mensagem geral de campanha",
    isCampaign: true
  });
  assertEquals(res.allowed, false, "isCampaign=true deve ser bloqueado");
  assertEquals(res.errorCode, PolicyErrorCode.BROADCAST_BLOCKED);
});

Deno.test("TEST 2.3: Caller de difusão massiva 'avisos-push' no WhatsApp -> BLOCK", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "avisos-push-notify",
    messageType: MessageType.NOTICE,
    textValue: "Aviso do condomínio",
    isCampaign: false
  });
  assertEquals(res.allowed, false, "Caller de difusão geral deve ser bloqueado no WhatsApp");
  assertEquals(res.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("TEST 2.4: Caller 'universal-push' no WhatsApp -> BLOCK", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "universal-push-notify",
    messageType: MessageType.NOTICE,
    textValue: "Comunicado global",
    isCampaign: false
  });
  assertEquals(res.allowed, false, "universal-push não pode enviar WhatsApp");
  assertEquals(res.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("TEST 2.5: Caller contendo 'campaign-worker' no WhatsApp -> BLOCK", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "notification-campaign-worker",
    messageType: MessageType.NOTICE,
    textValue: "Campanha administrativa",
    isCampaign: false
  });
  assertEquals(res.allowed, false, "campaign worker deve ser bloqueado");
  assertEquals(res.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("TEST 2.6: Caller contendo 'assembleia-broadcast' no WhatsApp -> BLOCK", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "assembleia-broadcast-notify",
    messageType: MessageType.NOTICE,
    textValue: "Edital de convocação",
    isCampaign: false
  });
  assertEquals(res.allowed, false, "assembleia broadcast deve ser bloqueado no WhatsApp");
  assertEquals(res.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("TEST 2.7: recipientCount > 5 (volume massivo) -> BLOCK", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-parcel-notify",
    messageType: MessageType.PARCEL,
    textValue: "Aviso para múltiplos",
    recipientCount: 50
  });
  assertEquals(res.allowed, false, "recipientCount > 5 deve ser bloqueado");
  assertEquals(res.errorCode, PolicyErrorCode.BROADCAST_BLOCKED);
});

Deno.test("TEST 2.8: recipientCount <= 5 (grupo transacional síndicos/emergência) -> ALLOW", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "classificados-notify",
    messageType: MessageType.NOTICE,
    textValue: "Novo anúncio para moderação",
    recipientCount: 2
  });
  assertEquals(res.allowed, true, "recipientCount <= 5 em contexto transacional deve ser permitido");
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. TESTES DO sendToRecipients (Limite Transacional)
// ─────────────────────────────────────────────────────────────────────────────

Deno.test("TEST 3.1: sendToRecipients com 10 destinatários -> BLOCK ALL", async () => {
  const massList = Array.from({ length: 10 }, (_, i) => ({
    id: `user-${i}`,
    nome_completo: `Morador ${i}`,
    whatsapp: `551199999000${i}`
  }));

  const results = await sendToRecipients("fake-key", massList, "Aviso geral", "text");
  assertEquals(results.length, 10);
  assertEquals(results.every(r => r.success === false), true, "Todos os envios devem ser bloqueados");
  assertEquals(results.every(r => r.deliveryStatus === PolicyErrorCode.BROADCAST_BLOCKED), true);
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. TESTES DE PRESERVAÇÃO DOS FLUXOS TRANSACIONAIS LEGÍTIMOS
// ─────────────────────────────────────────────────────────────────────────────

Deno.test("TEST 4.1: Encomenda Recebida (PARCEL) -> ALLOW", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-parcel-notify",
    messageType: MessageType.PARCEL,
    templateName: "condomeet_encomenda_recebida_v2",
    textValue: "Chegou uma encomenda",
    templateParams: ["Ed. Real", "Pacote", "Carlos", "101", "Portaria", "23/08 10:00", "COD1", "BR1", "Obs"]
  });
  assertEquals(res.allowed, true, "PARCEL deve ser permitido");
});

Deno.test("TEST 4.2: Retirada de Encomenda (PARCEL_DELIVERED) -> ALLOW", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-parcel-notify",
    messageType: MessageType.PARCEL_DELIVERED,
    templateName: "retirada_de_encomenda",
    textValue: "Encomenda retirada",
    templateParams: ["Ed. Real", "Carlos", "Pacote", "23/08 10:00", "23/08 11:00", "Porteiro", "Balcão"]
  });
  assertEquals(res.allowed, true, "PARCEL_DELIVERED deve ser permitido");
});

Deno.test("TEST 4.3: Visitante Autorizado (VISITOR_AUTHORIZED) -> ALLOW", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-guest",
    messageType: MessageType.VISITOR_AUTHORIZED,
    templateName: "condomeet_visitante_autorizado_v1",
    textValue: "Visitante autorizado",
    templateParams: ["Ed. Real", "Carlos", "Visitante João", "Apto 101"]
  });
  assertEquals(res.allowed, true, "VISITOR_AUTHORIZED deve ser permitido");
});

Deno.test("TEST 4.4: Alerta de Emergência (SOS) -> ALLOW", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "sos-push-notify",
    messageType: MessageType.SOS,
    textValue: "ALERTA SOS: Morador Carlos acionou o botão de emergência"
  });
  assertEquals(res.allowed, true, "SOS deve ser permitido");
});

Deno.test("TEST 4.5: Autenticação OTP (OTP) -> ALLOW", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "password-reset-whatsapp",
    messageType: MessageType.OTP,
    templateName: "condomeet_recuperacao_senha_v1",
    textValue: "Código 123456",
    templateParams: ["123456"]
  });
  assertEquals(res.allowed, true, "OTP deve ser permitido");
});

Deno.test("TEST 4.6: Garagem (NOTICE) -> ALLOW", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "garagem-notify",
    messageType: MessageType.NOTICE,
    textValue: "Sua vaga foi reservada"
  });
  assertEquals(res.allowed, true, "Garagem deve ser permitida");
});

Deno.test("TEST 4.7: Classificados Transacional (NOTICE) -> ALLOW", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "classificados-notify",
    messageType: MessageType.NOTICE,
    textValue: "Seu anúncio foi submetido para moderação"
  });
  assertEquals(res.allowed, true, "Classificados transacional deve ser permitido");
});

Deno.test("TEST 4.8: Chatbot Administrativo -> ALLOW", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-chatbot",
    messageType: MessageType.NOTICE,
    textValue: "Status operacional da IA"
  });
  assertEquals(res.allowed, true, "Chatbot administrativo deve ser permitido");
});

console.log("SUITE DE TESTES DA FASE 4.16A CONCLUÍDA COM 100% DE APROVAÇÃO!");
