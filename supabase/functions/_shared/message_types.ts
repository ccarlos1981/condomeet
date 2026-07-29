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
  NOTICE: "NOTICE",                           // Comunicado / Aviso do Condominio (Prioridade 15)
  FINANCIAL: "FINANCIAL",                     // Boleto / Lembrete Financeiro (Prioridade 20)
  TEXTO_LIVRE: "TEXTO_LIVRE",                 // Fallback / Texto generico
  RESPOSTA_MORADOR: "RESPOSTA_MORADOR",       // Resposta recebida via webhook
  TEMPLATE_MANUAL: "TEMPLATE_MANUAL",         // Disparo manual SuperAdmin
  TEXTO_LIVRE_MANUAL: "TEXTO_LIVRE_MANUAL"    // Disparo manual SuperAdmin
} as const);

export type MessageTypeValue = typeof MessageType[keyof typeof MessageType];

export const VALID_MESSAGE_TYPES = Object.freeze(new Set(Object.values(MessageType)));

export const EVENT_PRIORITY_MAP = Object.freeze({
  [MessageType.SOS]: 1,                // Queue: high (Faixa [1, 5])
  [MessageType.OTP]: 1,                // Queue: high (Faixa [1, 5])
  [MessageType.VISITOR_INVITE]: 2,     // Queue: high (Faixa [1, 5])
  [MessageType.VISITOR_AUTHORIZED]: 2, // Queue: high (Faixa [1, 5])
  [MessageType.PARCEL]: 10,            // Queue: low  (Faixa [6, 99])
  [MessageType.PARCEL_DELIVERED]: 10,  // Queue: low  (Faixa [6, 99])
  [MessageType.NOTICE]: 15,            // Queue: low  (Faixa [6, 99])
  [MessageType.FINANCIAL]: 20,          // Queue: low  (Faixa [6, 99])
  [MessageType.TEXTO_LIVRE]: 10,       // Queue: low  (Fallback)
  [MessageType.RESPOSTA_MORADOR]: 10,  // Queue: low  (Respostas)
  [MessageType.TEMPLATE_MANUAL]: 10,   // Queue: low  (Disparo Manual)
  [MessageType.TEXTO_LIVRE_MANUAL]: 10 // Queue: low  (Disparo Manual)
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

export const TEMPLATE_REGISTRY: Record<MessageTypeValue, TemplateDefinition | null> = Object.freeze({
  [MessageType.SOS]: null,
  [MessageType.OTP]: {
    family: "recuperacao_senha",
    defaultName: "condomeet_recuperacao_senha_v1",
    language: "pt_BR",
    minParameters: 2,
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
  [MessageType.NOTICE]: null,
  [MessageType.FINANCIAL]: null,
  [MessageType.TEXTO_LIVRE]: null,
  [MessageType.RESPOSTA_MORADOR]: null,
  [MessageType.TEMPLATE_MANUAL]: null,
  [MessageType.TEXTO_LIVRE_MANUAL]: null
});

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

