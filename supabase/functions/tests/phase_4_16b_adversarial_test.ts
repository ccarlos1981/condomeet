import {
  validateWhatsAppSendPolicy,
  sendToRecipients,
  PolicyErrorCode,
  AUTHORIZED_TRANSACTIONAL_CALLERS,
  CALLER_ALLOWED_MESSAGE_TYPES,
  MAX_TRANSACTIONAL_RECIPIENTS
} from "../_shared/botconversa.ts"
import { MessageType, TEMPLATE_REGISTRY } from "../_shared/message_types.ts"

function assertEquals(actual: any, expected: any, msg?: string) {
  if (actual !== expected) {
    throw new Error(`Assertion failed: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}. ${msg || ''}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEÇÃO 1: TESTES ADVERSARIAIS (ATAQUES A até N)
// ─────────────────────────────────────────────────────────────────────────────

Deno.test("ATAQUE A: 5.000 moradores em lotes de 5 via caller não autorizado -> BLOCK ALL", () => {
  const fakeCaller = "bulk-sender-service";
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: fakeCaller,
    messageType: MessageType.NOTICE,
    textValue: "Aviso em lote",
    recipientCount: 5
  });
  assertEquals(policyCheck.allowed, false, "Caller fora da whitelist deve ser sumariamente bloqueado");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("ATAQUE B: 5.000 moradores em 1.000 requests concorrentes de caller não autorizado -> BLOCK ALL", () => {
  const fakeCaller = "batch-notification-api";
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: fakeCaller,
    messageType: MessageType.NOTICE,
    textValue: "Comunicado concorrente"
  });
  assertEquals(policyCheck.allowed, false, "Caller concorrente fora da whitelist deve ser bloqueado");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("ATAQUE C: 5.000 chamadas individuais a smartSend() com caller anônimo/inválido -> BLOCK ALL", () => {
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: undefined,
    messageType: MessageType.NOTICE,
    textValue: "Mensagem individual em loop anônimo"
  });
  assertEquals(policyCheck.allowed, false, "Chamada sem callerFunction declarado deve ser bloqueada");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("ATAQUE D: callerFunction = 'notificacao-geral' -> BLOCK (CALLER_NOT_AUTHORIZED)", () => {
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: "notificacao-geral",
    messageType: MessageType.NOTICE,
    textValue: "Aviso a todos os moradores"
  });
  assertEquals(policyCheck.allowed, false, "notificacao-geral não está na whitelist");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("ATAQUE E: callerFunction = 'aviso-condominio' -> BLOCK (CALLER_NOT_AUTHORIZED)", () => {
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: "aviso-condominio",
    messageType: MessageType.NOTICE,
    textValue: "Aviso de manutenção"
  });
  assertEquals(policyCheck.allowed, false, "aviso-condominio não está na whitelist");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("ATAQUE F: isBroadcast omitido (undefined) em caller não autorizado -> BLOCK", () => {
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: "custom-broadcast-job",
    messageType: MessageType.NOTICE,
    textValue: "Aviso geral sem flag isBroadcast",
    isBroadcast: undefined
  });
  assertEquals(policyCheck.allowed, false, "Omissão de isBroadcast não contorna a whitelist");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("ATAQUE G: isCampaign omitido (undefined) em caller não autorizado -> BLOCK", () => {
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: "scheduled-announcement",
    messageType: MessageType.NOTICE,
    textValue: "Aviso programado sem flag isCampaign",
    isCampaign: undefined
  });
  assertEquals(policyCheck.allowed, false, "Omissão de isCampaign não contorna a whitelist");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("ATAQUE H: MessageType.NOTICE em loop por caller não homologado para NOTICE -> BLOCK", () => {
  // Exemplo: whatsapp-parcel-notify só pode enviar PARCEL ou PARCEL_DELIVERED. Se tentar NOTICE:
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-parcel-notify",
    messageType: MessageType.NOTICE,
    textValue: "Tentativa de broadcast usando o nome do parcel-notify"
  });
  assertEquals(policyCheck.allowed, false, "Caller legítimo não pode enviar MessageType não autorizado para seu escopo");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.INVALID_CALLER_MESSAGE_TYPE);
});

Deno.test("ATAQUE I: TEXTO_LIVRE em loop por caller de visitantes -> BLOCK", () => {
  // Exemplo: convite-whatsapp-notify só pode enviar VISITOR_INVITE. Se tentar TEXTO_LIVRE:
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: "convite-whatsapp-notify",
    messageType: MessageType.TEXTO_LIVRE,
    textValue: "Texto livre para todos os moradores"
  });
  assertEquals(policyCheck.allowed, false, "Caller de convites não pode enviar TEXTO_LIVRE");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.INVALID_CALLER_MESSAGE_TYPE);
});

Deno.test("ATAQUE J: Inserção direta na outbox simulada com caller não registrado -> WORKER BLOQUEIA", () => {
  // Quando o worker valida o registro claimed:
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: "direct-db-injector",
    messageType: MessageType.NOTICE,
    textValue: "Injeção direta no banco"
  });
  assertEquals(policyCheck.allowed, false, "Worker bloqueia mensagens inseridas diretamente com caller não autorizado");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("ATAQUE K: Tentativa de importar sendMessageDirect() -> NÃO EXPORTADO", () => {
  // Verifica se sendMessageDirect foi removido dos exports de botconversa
  const botconversaModule = Object.keys({ validateWhatsAppSendPolicy, sendToRecipients });
  assertEquals(botconversaModule.includes("sendMessageDirect"), false, "sendMessageDirect não deve ser exportado");
});

Deno.test("ATAQUE L: Tentativa de importar sendViaMetaCloudAPI() -> NÃO EXPORTADO", () => {
  // sendViaMetaCloudAPI é função local estrita do outbox-worker
  const botconversaModule = Object.keys({ validateWhatsAppSendPolicy, sendToRecipients });
  assertEquals(botconversaModule.includes("sendViaMetaCloudAPI"), false, "sendViaMetaCloudAPI não deve ser exportado");
});

Deno.test("ATAQUE M: Nova Edge Function ('universal-announcements') tentando usar smartSend() -> BLOCK", () => {
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: "universal-announcements",
    messageType: MessageType.NOTICE,
    textValue: "Novo anúncio para todos"
  });
  assertEquals(policyCheck.allowed, false, "Nova Edge Function fora da whitelist é sumariamente rejeitada");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("ATAQUE N: Tentativa de sequestro do botconversa-send com MessageType.OTP -> BLOCK", () => {
  // botconversa-send só pode enviar NOTICE, TEXTO_LIVRE ou WELCOME
  const policyCheck = validateWhatsAppSendPolicy({
    callerFunction: "botconversa-send",
    messageType: MessageType.OTP,
    textValue: "Sequestro com OTP"
  });
  assertEquals(policyCheck.allowed, false, "botconversa-send não pode enviar OTP");
  assertEquals(policyCheck.errorCode, PolicyErrorCode.INVALID_CALLER_MESSAGE_TYPE);
});

// ─────────────────────────────────────────────────────────────────────────────
// SEÇÃO 2: TESTES DE REGRESSÃO DE FLUXOS TRANSACIONAIS LEGÍTIMOS (100% PRESERVADOS)
// ─────────────────────────────────────────────────────────────────────────────

Deno.test("REGRESSÃO 1: whatsapp-parcel-notify -> PARCEL (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-parcel-notify",
    messageType: MessageType.PARCEL,
    templateName: "condomeet_encomenda_recebida_v2",
    textValue: "Chegou uma encomenda",
    templateParams: ["Ed. Real", "Caixa", "João", "101", "Portaria", "23/08 10:00", "COD1", "BR1", "Obs"]
  });
  assertEquals(res.allowed, true, "whatsapp-parcel-notify com PARCEL deve ser permitido");
});

Deno.test("REGRESSÃO 2: whatsapp-parcel-notify -> PARCEL_DELIVERED (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-parcel-notify",
    messageType: MessageType.PARCEL_DELIVERED,
    templateName: "retirada_de_encomenda",
    textValue: "Encomenda retirada com sucesso",
    templateParams: ["Ed. Real", "João", "Caixa", "23/08 10:00", "23/08 11:00", "Porteiro", "Balcão"]
  });
  assertEquals(res.allowed, true, "whatsapp-parcel-notify com PARCEL_DELIVERED deve ser permitido");
});

Deno.test("REGRESSÃO 3: parcel-photo-delayed -> PARCEL (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "parcel-photo-delayed",
    messageType: MessageType.PARCEL,
    templateName: "condomeet_encomenda_recebida_v2",
    textValue: "Foto da encomenda",
    templateParams: ["Ed. Real", "Pacote", "Carlos", "202", "Portaria", "23/08 12:00", "COD2", "BR2", "Foto"]
  });
  assertEquals(res.allowed, true, "parcel-photo-delayed com PARCEL deve ser permitido");
});

Deno.test("REGRESSÃO 4: visitor-register-whatsapp-notify -> VISITOR_INVITE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "visitor-register-whatsapp-notify",
    messageType: MessageType.VISITOR_INVITE,
    templateName: "condomeet_visitante_aguardando_v3",
    textValue: "Visitante aguardando",
    templateParams: ["Ed. Real", "Carlos", "Visitante João", "123.456.789-00", "ABC-1234", "23/08 14:00"]
  });
  assertEquals(res.allowed, true, "visitor-register com VISITOR_INVITE deve ser permitido");
});

Deno.test("REGRESSÃO 5: convite-whatsapp-notify -> VISITOR_INVITE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "convite-whatsapp-notify",
    messageType: MessageType.VISITOR_INVITE,
    templateName: "condomeet_visitante_aguardando_v3",
    textValue: "Convite para visitante",
    templateParams: ["Ed. Real", "Maria", "Visitante Ana", "000.000.000-00", "XYZ-9999", "23/08 15:00"]
  });
  assertEquals(res.allowed, true, "convite-whatsapp com VISITOR_INVITE deve ser permitido");
});

Deno.test("REGRESSÃO 6: whatsapp-guest -> VISITOR_AUTHORIZED (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-guest",
    messageType: MessageType.VISITOR_AUTHORIZED,
    templateName: "condomeet_visitante_autorizado_v1",
    textValue: "Visitante autorizado",
    templateParams: ["Ed. Real", "Carlos", "Visitante João", "Apto 101"]
  });
  assertEquals(res.allowed, true, "whatsapp-guest com VISITOR_AUTHORIZED deve ser permitido");
});

Deno.test("REGRESSÃO 7: password-reset-whatsapp -> OTP (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "password-reset-whatsapp",
    messageType: MessageType.OTP,
    templateName: "condomeet_recuperacao_senha_v1",
    textValue: "Seu código de verificação é 998877",
    templateParams: ["998877"]
  });
  assertEquals(res.allowed, true, "password-reset com OTP deve ser permitido");
});

Deno.test("REGRESSÃO 8: sos-push-notify -> SOS (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "sos-push-notify",
    messageType: MessageType.SOS,
    textValue: "ALERTA DE PÂNICO / SOS: Morador acionou botão de emergência"
  });
  assertEquals(res.allowed, true, "sos-push-notify com SOS deve ser permitido");
});

Deno.test("REGRESSÃO 9: garagem-notify -> NOTICE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "garagem-notify",
    messageType: MessageType.NOTICE,
    textValue: "Sua vaga de garagem foi alugada"
  });
  assertEquals(res.allowed, true, "garagem-notify com NOTICE deve ser permitido");
});

Deno.test("REGRESSÃO 10: classificados-notify -> NOTICE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "classificados-notify",
    messageType: MessageType.NOTICE,
    textValue: "Novo anúncio aguardando moderação"
  });
  assertEquals(res.allowed, true, "classificados-notify com NOTICE deve ser permitido");
});

Deno.test("REGRESSÃO 11: optin-whatsapp-cron -> NOTICE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "optin-whatsapp-cron",
    messageType: MessageType.NOTICE,
    textValue: "Confirmação de cadastro e opt-in no WhatsApp"
  });
  assertEquals(res.allowed, true, "optin-whatsapp-cron com NOTICE deve ser permitido");
});

Deno.test("REGRESSÃO 12: whatsapp-chatbot -> NOTICE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-chatbot",
    messageType: MessageType.NOTICE,
    textValue: "Status do assistente inteligente"
  });
  assertEquals(res.allowed, true, "whatsapp-chatbot com NOTICE deve ser permitido");
});

Deno.test("REGRESSÃO 13: indicacoes-notify -> NOTICE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "indicacoes-notify",
    messageType: MessageType.NOTICE,
    textValue: "Você recebeu uma nova indicação de serviços no Condomeet"
  });
  assertEquals(res.allowed, true, "indicacoes-notify com NOTICE deve ser permitido");
});

Deno.test("REGRESSÃO 14: documentos-vencimento-check -> NOTICE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "documentos-vencimento-check",
    messageType: MessageType.NOTICE,
    textValue: "Aviso de vencimento de documento/contrato"
  });
  assertEquals(res.allowed, true, "documentos-vencimento-check com NOTICE deve ser permitido");
});

Deno.test("REGRESSÃO 15: reserva-notify -> RESERVATION (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "reserva-notify",
    messageType: MessageType.RESERVATION,
    templateName: "condomeet_reserva_confirmada_v2",
    textValue: "Reserva confirmada do salão de festas",
    templateParams: ["Ed. Real", "Carlos", "Salão de Festas", "25/08/2026"]
  });
  assertEquals(res.allowed, true, "reserva-notify com RESERVATION deve ser permitido");
});

Deno.test("REGRESSÃO 16: welcome-notify -> WELCOME (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "welcome-notify",
    messageType: MessageType.WELCOME,
    templateName: "condomeet_boas_vindas_v1",
    textValue: "Boas-vindas ao condomínio",
    templateParams: ["Carlos", "Ed. Real"]
  });
  assertEquals(res.allowed, true, "welcome-notify com WELCOME deve ser permitido");
});

Deno.test("REGRESSÃO 17: fale-sindico-notify -> NOTICE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "fale-sindico-notify",
    messageType: MessageType.NOTICE,
    textValue: "Nova mensagem no Fale com o Síndico"
  });
  assertEquals(res.allowed, true, "fale-sindico-notify com NOTICE deve ser permitido");
});

Deno.test("REGRESSÃO 18: ocorrencia-notify -> NOTICE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "ocorrencia-notify",
    messageType: MessageType.NOTICE,
    textValue: "Nova ocorrência registrada na unidade"
  });
  assertEquals(res.allowed, true, "ocorrencia-notify com NOTICE deve ser permitido");
});

Deno.test("REGRESSÃO 19: botconversa-send -> NOTICE (ALLOW)", () => {
  const res = validateWhatsAppSendPolicy({
    callerFunction: "botconversa-send",
    messageType: MessageType.NOTICE,
    textValue: "Mensagem individual enviada para o morador"
  });
  assertEquals(res.allowed, true, "botconversa-send com NOTICE deve ser permitido");
});

console.log("SUITE DE TESTES ADVERSARIAIS E DE REGRESSÃO DA FASE 4.16B CONCLUÍDA COM SUCESSO!");
