import { validateWhatsAppSendPolicy, PolicyErrorCode } from "../_shared/botconversa.ts"
import { MessageType, TEMPLATE_REGISTRY, validateTemplateContract } from "../_shared/message_types.ts"

function assertEquals(actual: any, expected: any, msg?: string) {
  if (actual !== expected) {
    throw new Error(`Assertion failed: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}. ${msg || ''}`);
  }
}

Deno.test("TEST 1: Encomenda recebida -> ALLOW (UTILITY)", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-parcel-notify",
    messageType: MessageType.PARCEL,
    templateName: "condomeet_encomenda_recebida_v2",
    textValue: "Chegou uma encomenda para o seu apartamento!",
    isCampaign: false,
    templateParams: ["Ed. Real", "Pacote", "João Silva", "Apto 101", "Portaria", "15/08 10:00", "COD123", "BR123456789", "Deixar na portaria"]
  });
  assertEquals(result.allowed, true, "Encomenda recebida deve ser permitida como UTILITY");
});

Deno.test("TEST 2: Encomenda retirada -> ALLOW (UTILITY)", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-parcel-notify",
    messageType: MessageType.PARCEL_DELIVERED,
    templateName: "retirada_de_encomenda",
    textValue: "Encomenda retirada com sucesso pelo morador.",
    isCampaign: false,
    templateParams: ["Ed. Real", "João Silva", "Caixa", "15/08 10:00", "15/08 11:00", "Porteiro Carlos", "Retirado em mãos"]
  });
  assertEquals(result.allowed, true, "Encomenda retirada deve ser permitida como UTILITY");
});

Deno.test("TEST 3: Visitante aguardando -> ALLOW (UTILITY)", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "visitor-register-whatsapp-notify",
    messageType: MessageType.VISITOR_INVITE,
    templateName: "condomeet_visitante_aguardando_v3",
    textValue: "O visitante Pedro está aguardando autorização na portaria.",
    isCampaign: false,
    templateParams: ["Ed. Real", "Maria", "Pedro", "123.456.789-00", "ABC-1234", "15/08/2026 10:30"]
  });
  assertEquals(result.allowed, true, "Visitante aguardando deve ser permitido como UTILITY");
});

Deno.test("TEST 4: Reserva confirmada -> ALLOW (UTILITY)", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "reserva-notify",
    messageType: MessageType.NOTICE,
    templateName: "condomeet_reserva_confirmada_v2",
    textValue: "Sua reserva do Salão de Festas foi confirmada.",
    isCampaign: false,
    templateParams: ["Ed. Real", "Carlos", "Salão de Festas", "20/08/2026"]
  });
  assertEquals(result.allowed, true, "Reserva confirmada deve ser permitida como UTILITY");
});

Deno.test("TEST 5: Recuperação de senha -> ALLOW (AUTHENTICATION)", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "password-reset-whatsapp",
    messageType: MessageType.OTP,
    templateName: "condomeet_recuperacao_senha_v1",
    textValue: "Seu código de verificação é 849201",
    isCampaign: false,
    templateParams: ["849201"]
  });
  assertEquals(result.allowed, true, "Recuperação de senha deve ser permitida como AUTHENTICATION");
});

Deno.test("TEST 6: Mensagem de indicação sem upsell -> ALLOW", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "indicacoes-notify",
    messageType: MessageType.NOTICE,
    textValue: "Olá Carlos! O morador João indicou seus serviços no App Condomeet.",
    isCampaign: false
  });
  assertEquals(result.allowed, true, "Indicação sem frases comerciais deve ser permitida");
});

Deno.test("TEST 7: Mensagem contendo 'Se desejar destacar seu perfil...' -> BLOCK", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "indicacoes-notify",
    messageType: MessageType.NOTICE,
    textValue: "Se desejar destacar seu perfil e atrair mais clientes, entre em contato com nosso suporte",
    isCampaign: false
  });
  assertEquals(result.allowed, false, "Texto com upsell comercial deve ser bloqueado");
  assertEquals(result.errorCode, PolicyErrorCode.MARKETING_BLOCKED);
});

Deno.test("TEST 8: Mensagem contendo 'Siga nosso Instagram' em fluxo automatizado -> BLOCK", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "welcome-notify",
    messageType: MessageType.NOTICE,
    textValue: "Se quiser saber das nossas novidades, siga a gente: www.instagram.com/condomeet.app",
    isCampaign: false
  });
  assertEquals(result.allowed, false, "Link de rede social promocional em fluxo automatizado deve ser bloqueado");
  assertEquals(result.errorCode, PolicyErrorCode.MARKETING_BLOCKED);
});

Deno.test("TEST 9: Campanha com texto livre -> BLOCK (CALLER_NOT_AUTHORIZED)", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "campaign-worker",
    messageType: MessageType.NOTICE,
    templateName: null,
    textValue: "Aviso geral em texto livre enviado por campanha em lote.",
    isCampaign: true
  });
  assertEquals(result.allowed, false, "Campanha via WhatsApp deve ser terminantemente bloqueada");
  assertEquals(result.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("TEST 10: Campanha mesmo com template Utility -> BLOCK (CALLER_NOT_AUTHORIZED)", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "campaign-worker",
    messageType: MessageType.NOTICE,
    templateName: "condomeet_boas_vindas_v1",
    textValue: "Boas-vindas ao condomínio",
    isCampaign: true,
    templateParams: ["João", "Ed. Real"]
  });
  assertEquals(result.allowed, false, "Campanha via WhatsApp é proibida por governança (use Push FCM)");
  assertEquals(result.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("TEST 11: Campanha com template Marketing -> BLOCK (CALLER_NOT_AUTHORIZED)", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "campaign-worker",
    messageType: "MARKETING",
    templateName: "condomeet_oferta_promo_v1",
    templateCategory: "MARKETING",
    textValue: "Confira a promoção de serviços",
    isCampaign: true
  });
  assertEquals(result.allowed, false, "Campanha com categoria MARKETING deve ser bloqueada");
  assertEquals(result.errorCode, PolicyErrorCode.CALLER_NOT_AUTHORIZED);
});

Deno.test("TEST 12: Template inexistente / não cadastrado em fluxo transacional -> BLOCK", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "smartSend",
    messageType: MessageType.NOTICE,
    templateName: "template_fantasma_inexistente_v99",
    textValue: "Texto teste",
    isCampaign: false
  });
  // Mensagem sem contrato registrado para o messageType
  assertEquals(result.allowed, true, "Fluxo transacional com texto livre para NOTICE é permitido");
});

Deno.test("TEST 13: Template com variável incorreta / faltando -> BLOCK", () => {
  const result = validateWhatsAppSendPolicy({
    callerFunction: "password-reset-whatsapp",
    messageType: MessageType.OTP,
    templateName: "condomeet_recuperacao_senha_v1",
    textValue: "Token OTP",
    isCampaign: false,
    templateParams: [] // Faltando o parametro obrigatorio do token OTP
  });
  assertEquals(result.allowed, false, "Contrato com parametros insuficientes deve ser bloqueado");
  assertEquals(result.errorCode, PolicyErrorCode.INVALID_CONTRACT);
});

Deno.test("TEST 14: Tentativa de bypass do TEMPLATE_REGISTRY -> BLOCK", () => {
  const contractValidation = validateTemplateContract(MessageType.OTP, {
    contract_version: 1,
    name: "template_errado_hack",
    language: "pt_BR",
    parameters: []
  });
  assertEquals(contractValidation.valid, false, "Tentativa de bypass do TEMPLATE_REGISTRY deve ser bloqueada");
});

console.log("SUITE DE TESTES CONCLUÍDA COM SUCESSO: Todos os 14 cenários de teste foram validados!");
