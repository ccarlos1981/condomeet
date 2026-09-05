/**
 * MessageTypes oficiais do ecossistema Condomeet.
 * Este arquivo e a UNICA fonte da verdade para tipos de eventos operacionais de mensagem.
 * E PROHIBIDA a criacao de strings literais soltas no codigo.
 */

export const MessageType = Object.freeze({
  SOS: "SOS",                                 // Alerta Critico de Emergencia (Prioridade 1)
  VISITOR_INVITE: "VISITOR_INVITE",           // Convite de Visitante (Prioridade 2)
  VISITOR_AUTHORIZED: "VISITOR_AUTHORIZED",   // Autorizacao / Liberacao de Entrada (Prioridade 2)
  OTP: "OTP",                                 // Token / Validacao / Senha (Prioridade 1)
  PARCEL: "PARCEL",                           // Notificacao de Chegada de Encomenda (Prioridade 10)
  PARCEL_DELIVERED: "PARCEL_DELIVERED",       // Retirada / Baixa de Encomenda (Prioridade 10)
  RESERVATION: "RESERVATION",                 // Reserva de Espaco Comum (Prioridade 10)
  NOTICE: "NOTICE",                           // Comunicado / Aviso / Documento (Prioridade 15)
  WELCOME: "WELCOME",                         // Boas-Vindas / Aprovacao (Prioridade 15)
  FINANCIAL: "FINANCIAL",                     // Boleto / Lembrete Financeiro (Prioridade 20)
  TEXTO_LIVRE: "TEXTO_LIVRE",                 // Fallback / Texto generico
  RESPOSTA_MORADOR: "RESPOSTA_MORADOR",       // Resposta recebida via webhook
  TEMPLATE_MANUAL: "TEMPLATE_MANUAL",         // Disparo manual SuperAdmin
  TEXTO_LIVRE_MANUAL: "TEXTO_LIVRE_MANUAL",   // Disparo manual SuperAdmin
  DUAL_NUMBER_NOTICE: "DUAL_NUMBER_NOTICE"    // Aviso Informativo dos Dois Numeros (Prioridade 25)
} as const);

export type MessageTypeValue = typeof MessageType[keyof typeof MessageType];

export const PolicyErrorCode = Object.freeze({
  MARKETING_BLOCKED: "WHATSAPP_POLICY_MARKETING_BLOCKED",
  TEMPLATE_REQUIRED: "WHATSAPP_POLICY_TEMPLATE_REQUIRED",
  TEMPLATE_NOT_APPROVED: "WHATSAPP_POLICY_TEMPLATE_NOT_APPROVED",
  TEMPLATE_NOT_REGISTERED: "WHATSAPP_POLICY_TEMPLATE_NOT_REGISTERED",
  INVALID_CONTRACT: "WHATSAPP_POLICY_INVALID_CONTRACT",
  CAMPAIGN_FREE_TEXT_BLOCKED: "WHATSAPP_POLICY_CAMPAIGN_FREE_TEXT_BLOCKED",
  BROADCAST_BLOCKED: "WHATSAPP_POLICY_BROADCAST_BLOCKED",
  CALLER_NOT_AUTHORIZED: "WHATSAPP_POLICY_CALLER_NOT_AUTHORIZED",
  INVALID_CALLER_MESSAGE_TYPE: "WHATSAPP_POLICY_INVALID_CALLER_MESSAGE_TYPE",
} as const);

export const VALID_MESSAGE_TYPES = Object.freeze(new Set(Object.values(MessageType)));

/**
 * Whitelist oficial e imutável de Edge Functions e callers autorizados a despachar WhatsApp.
 * Qualquer caller não registrado nesta lista é sumariamente bloqueado no smartSend().
 */
export const AUTHORIZED_TRANSACTIONAL_CALLERS = Object.freeze(new Set([
  "whatsapp-parcel-notify",
  "parcel-photo-delayed",
  "visitor-register-whatsapp-notify",
  "convite-whatsapp-notify",
  "whatsapp-guest",
  "password-reset-whatsapp",
  "sos-push-notify",
  "garagem-notify",
  "classificados-notify",
  "optin-whatsapp-cron",
  "whatsapp-chatbot",
  "indicacoes-notify",
  "documentos-vencimento-check",
  "reserva-notify",
  "fale-sindico-notify",
  "ocorrencia-notify",
  "welcome-notify",
  "approval-notify",
  "botconversa-send",
  "whatsapp-outbox-worker",
  "sendInteractiveButtons",
  "whatsapp-webhook",
  "evolution-webhook",
  "smartSend"
]));

/**
 * Matriz de amarração: Caller Autorizado ➔ MessageTypes Autorizados.
 * Impede que um caller legítimo (ex.: parcel-notify) seja sequestrado para despachar NOTICE ou TEXTO_LIVRE.
 */
export const CALLER_ALLOWED_MESSAGE_TYPES: Record<string, ReadonlySet<string>> = Object.freeze({
  "whatsapp-parcel-notify": new Set([MessageType.PARCEL, MessageType.PARCEL_DELIVERED]),
  "parcel-photo-delayed": new Set([MessageType.PARCEL]),
  "visitor-register-whatsapp-notify": new Set([MessageType.VISITOR_INVITE]),
  "convite-whatsapp-notify": new Set([MessageType.VISITOR_INVITE]),
  "whatsapp-guest": new Set([MessageType.VISITOR_AUTHORIZED, MessageType.VISITOR_INVITE]),
  "password-reset-whatsapp": new Set([MessageType.OTP]),
  "sos-push-notify": new Set([MessageType.SOS]),
  "garagem-notify": new Set([MessageType.NOTICE]),
  "classificados-notify": new Set([MessageType.NOTICE]),
  "optin-whatsapp-cron": new Set([MessageType.NOTICE]),
  "whatsapp-chatbot": new Set([MessageType.NOTICE]),
  "indicacoes-notify": new Set([MessageType.NOTICE]),
  "documentos-vencimento-check": new Set([MessageType.NOTICE]),
  "reserva-notify": new Set([MessageType.RESERVATION, MessageType.NOTICE]),
  "fale-sindico-notify": new Set([MessageType.NOTICE]),
  "ocorrencia-notify": new Set([MessageType.NOTICE]),
  "welcome-notify": new Set([MessageType.WELCOME, MessageType.NOTICE]),
  "approval-notify": new Set([MessageType.WELCOME, MessageType.NOTICE]),
  "botconversa-send": new Set([MessageType.NOTICE, MessageType.TEXTO_LIVRE, MessageType.WELCOME]),
  "whatsapp-outbox-worker": new Set(Object.values(MessageType)),
  "sendInteractiveButtons": new Set([MessageType.VISITOR_AUTHORIZED, MessageType.VISITOR_INVITE]),
  "whatsapp-webhook": new Set([MessageType.NOTICE]),
  "evolution-webhook": new Set([MessageType.NOTICE]),
  "smartSend": new Set(Object.values(MessageType))
});

export const EVENT_PRIORITY_MAP = Object.freeze({
  [MessageType.SOS]: 1,                // Queue: high (Faixa [1, 5])
  [MessageType.OTP]: 1,                // Queue: high (Faixa [1, 5])
  [MessageType.VISITOR_INVITE]: 2,     // Queue: high (Faixa [1, 5])
  [MessageType.VISITOR_AUTHORIZED]: 2, // Queue: high (Faixa [1, 5])
  [MessageType.PARCEL]: 10,            // Queue: low  (Faixa [6, 99])
  [MessageType.PARCEL_DELIVERED]: 10,  // Queue: low  (Faixa [6, 99])
  [MessageType.RESERVATION]: 10,       // Queue: low  (Faixa [6, 99])
  [MessageType.NOTICE]: 15,            // Queue: low  (Faixa [6, 99])
  [MessageType.WELCOME]: 15,           // Queue: low  (Faixa [6, 99])
  [MessageType.FINANCIAL]: 20,          // Queue: low  (Faixa [6, 99])
  [MessageType.TEXTO_LIVRE]: 10,       // Queue: low  (Fallback)
  [MessageType.RESPOSTA_MORADOR]: 10,  // Queue: low  (Respostas)
  [MessageType.TEMPLATE_MANUAL]: 10,   // Queue: low  (Disparo Manual)
  [MessageType.TEXTO_LIVRE_MANUAL]: 10, // Queue: low  (Disparo Manual)
  [MessageType.DUAL_NUMBER_NOTICE]: 25  // Queue: low  (Aviso Dois Numeros)
} as const);

export interface TemplateDefinition {
  family: string;
  defaultName: string;
  language: string;
  minParameters: number;
  contractVersion: number;
}

export interface TemplateContract {
  contract_version: number;
  name: string;
  language: string;
  parameters: string[];
}

export const REGISTERED_OFFICIAL_TEMPLATES = Object.freeze(new Set([
  "retirada_de_encomenda",
  "condomeet_encomenda_recebida_v2",
  "condomeet_visitante_aguardando_v3",
  "condomeet_visitante_autorizado_v1",
  "condomeet_reserva_confirmada_v2",
  "condomeet_reserva_cancelada_v2",
  "condomeet_boas_vindas_v1",
  "condomeet_recuperacao_senha_v1",
  "condomeet_documento_disponivel_v2"
]));

export const TEMPLATE_REGISTRY: Record<MessageTypeValue, TemplateDefinition | null> = Object.freeze({
  [MessageType.SOS]: null,
  [MessageType.OTP]: {
    family: "recuperacao_senha",
    defaultName: "condomeet_recuperacao_senha_v1",
    language: "pt_BR",
    minParameters: 1,
    contractVersion: 1
  },
  [MessageType.VISITOR_INVITE]: {
    family: "visitante_aguardando",
    defaultName: "condomeet_visitante_aguardando_v3",
    language: "pt_BR",
    minParameters: 6,
    contractVersion: 1
  },
  [MessageType.VISITOR_AUTHORIZED]: {
    family: "visitante_autorizado",
    defaultName: "condomeet_visitante_autorizado_v1",
    language: "pt_BR",
    minParameters: 4,
    contractVersion: 1
  },
  [MessageType.PARCEL]: {
    family: "encomenda_recebida",
    defaultName: "condomeet_encomenda_recebida_v2",
    language: "pt_BR",
    minParameters: 9,
    contractVersion: 1
  },
  [MessageType.PARCEL_DELIVERED]: {
    family: "retirada_de_encomenda",
    defaultName: "retirada_de_encomenda",
    language: "pt_BR",
    minParameters: 7,
    contractVersion: 2
  },
  [MessageType.RESERVATION]: null,
  [MessageType.NOTICE]: null,
  [MessageType.WELCOME]: null,
  [MessageType.FINANCIAL]: null,
  [MessageType.TEXTO_LIVRE]: null,
  [MessageType.RESPOSTA_MORADOR]: null,
  [MessageType.TEMPLATE_MANUAL]: null,

  [MessageType.TEXTO_LIVRE_MANUAL]: null,
  [MessageType.DUAL_NUMBER_NOTICE]: null
});

/**
 * Matriz oficial de TTL Absoluto (em segundos) por MessageType (FASE 4.17).
 * Após esse tempo, a mensagem perde validade operacional e NUNCA mais pode ser enviada por nenhum canal.
 */
export const MESSAGE_ABSOLUTE_TTL_SECONDS: Record<MessageTypeValue, number> = Object.freeze({
  [MessageType.SOS]: 30,                // 30s
  [MessageType.OTP]: 60,                // 60s (1 min)
  [MessageType.VISITOR_AUTHORIZED]: 90, // 90s (1.5 min)
  [MessageType.VISITOR_INVITE]: 180,    // 180s (3 min)
  [MessageType.PARCEL]: 600,            // 600s (10 min)
  [MessageType.PARCEL_DELIVERED]: 600,  // 600s (10 min)
  [MessageType.RESERVATION]: 600,       // 600s (10 min)
  [MessageType.NOTICE]: 900,            // 900s (15 min)
  [MessageType.WELCOME]: 900,           // 900s (15 min)
  [MessageType.FINANCIAL]: 1800,        // 1800s (30 min)
  [MessageType.TEXTO_LIVRE]: 600,       // 600s (10 min)
  [MessageType.RESPOSTA_MORADOR]: 60,   // 60s (1 min)
  [MessageType.TEMPLATE_MANUAL]: 600,   // 600s (10 min)
  [MessageType.TEXTO_LIVRE_MANUAL]: 600,// 600s (10 min)
  [MessageType.DUAL_NUMBER_NOTICE]: 900 // 900s (15 min)
});

/**
 * Matriz oficial de Janela de Guarda para Fallback (em segundos) por MessageType (FASE 4.17).
 * Tempo de espera após HTTP 200 do BotConversa (dispatched_bc) antes de acionar a Meta Cloud API.
 */
export const MESSAGE_FALLBACK_WINDOW_SECONDS: Record<MessageTypeValue, number> = Object.freeze({
  [MessageType.SOS]: 5,                 // 5s
  [MessageType.OTP]: 10,                // 10s
  [MessageType.VISITOR_AUTHORIZED]: 15, // 15s
  [MessageType.VISITOR_INVITE]: 20,     // 20s
  [MessageType.PARCEL]: 30,             // 30s
  [MessageType.PARCEL_DELIVERED]: 30,   // 30s
  [MessageType.RESERVATION]: 30,        // 30s
  [MessageType.NOTICE]: 0,              // 0s (Sem promoção para Meta enquanto não houver template aprovado)
  [MessageType.WELCOME]: 0,             // N/A (Meta Proibido por Governança - 100% BotConversa)
  [MessageType.FINANCIAL]: 60,          // 60s
  [MessageType.TEXTO_LIVRE]: 30,        // 30s
  [MessageType.RESPOSTA_MORADOR]: 15,   // 15s
  [MessageType.TEMPLATE_MANUAL]: 30,    // 30s
  [MessageType.TEXTO_LIVRE_MANUAL]: 30, // 30s
  [MessageType.DUAL_NUMBER_NOTICE]: 0   // N/A (Meta Proibido por Governança)
});

export function getMessageTTL(messageType?: string | null): number {
  if (!messageType) return 600;
  const ttl = MESSAGE_ABSOLUTE_TTL_SECONDS[messageType as MessageTypeValue];
  return typeof ttl === "number" ? ttl : 600;
}

export function getMessageFallbackWindow(messageType?: string | null): number {
  if (!messageType) return 30;
  const win = MESSAGE_FALLBACK_WINDOW_SECONDS[messageType as MessageTypeValue];
  return typeof win === "number" ? win : 30;
}

export function validateTemplateContract(
  messageType: string,
  templatePayload?: { contract_version?: number; name?: string; language?: string; parameters?: string[] }
): { valid: boolean; error?: string } {
  if (!templatePayload) {
    return { valid: true }; // Sem payload de template (para mensagens sem template)
  }

  const definition = TEMPLATE_REGISTRY[messageType as MessageTypeValue];
  if (!definition) {
    return {
      valid: false,
      error: `CONTRACT_VALIDATION_FAILED: MessageType '${messageType}' nao possui definição de template no TEMPLATE_REGISTRY.`
    };
  }

  if (!templatePayload.name || templatePayload.name.trim() === "") {
    return { valid: false, error: "CONTRACT_VALIDATION_FAILED: O campo template.name e obrigatorio." };
  }

  if (!Array.isArray(templatePayload.parameters)) {
    return { valid: false, error: "CONTRACT_VALIDATION_FAILED: O campo template.parameters deve ser um array." };
  }

  if (templatePayload.parameters.length < definition.minParameters) {
    return {
      valid: false,
      error: `CONTRACT_VALIDATION_FAILED: O template family '${definition.family}' exige no minimo ${definition.minParameters} parametros, porem foram fornecidos apenas ${templatePayload.parameters.length}.`
    };
  }

  const invalidIndex = templatePayload.parameters.findIndex(
    (p) => p === null || p === undefined || String(p).trim() === ""
  );

  if (invalidIndex !== -1) {
    return {
      valid: false,
      error: `CONTRACT_VALIDATION_FAILED: O parametro no indice ${invalidIndex} esta nulo, indefinido ou vazio.`
    };
  }

  return { valid: true };
}


