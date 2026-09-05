import { normalizePhone, smartSend } from "./botconversa.ts";
import { MessageType } from "./message_types.ts";

export const SUPPORT_PHONES = Object.freeze(["5531992707070", "5531994707070"]);
export const SUPPORT_ALERT_MESSAGE = "🔔 Alguém está querendo falar com o suporte.";

export interface SupportAlertParams {
  supabase: any;
  senderPhone: string;
  inboundOutboxId?: string | null;
  providerMessageId?: string | null;
  callerFunction: "whatsapp-webhook" | "evolution-webhook";
}

export interface SupportAlertResult {
  triggered: boolean;
  skippedReason?: string;
  results?: Array<{
    phone: string;
    success: boolean;
    error?: string;
  }>;
}

/**
 * Dispara alerta interno de suporte quando uma mensagem inbound real é recebida.
 * - Anti-Loop: Se a mensagem de entrada for originada por um dos números de suporte, o alerta é abortado.
 * - Idempotência: Impede disparos duplicados para o mesmo evento de entrada via checagem de entity_id.
 * - Zero Resposta: Nenhuma mensagem é enviada ao remetente original.
 */
export async function dispatchSupportInboundAlert(params: SupportAlertParams): Promise<SupportAlertResult> {
  const { supabase, senderPhone, inboundOutboxId, providerMessageId, callerFunction } = params;

  // 1. Normalização do Telefone do Remetente
  const cleanSenderPhone = normalizePhone(senderPhone);

  // 2. Anti-Loop: Se o remetente for um dos números de suporte, aborta imediatamente
  if (SUPPORT_PHONES.includes(cleanSenderPhone)) {
    console.log(`[SupportAlert] Origem do inbound é número de suporte (${cleanSenderPhone}). Alerta ignorado para prevenir loop.`);
    return { triggered: false, skippedReason: "LOOP_PROTECTION_SUPPORT_NUMBER" };
  }

  // 3. Identificador único do evento de entrada para idempotência
  const entityId = inboundOutboxId || providerMessageId;

  // 4. Checagem de Idempotência: verifica se o alerta já foi despachado para este evento
  if (supabase && entityId) {
    try {
      const { data: existingAlerts } = await supabase
        .from("whatsapp_outbox")
        .select("id")
        .eq("entity_type", "inbound_support_alert")
        .eq("entity_id", String(entityId))
        .limit(1);

      if (existingAlerts && existingAlerts.length > 0) {
        console.log(`[SupportAlert] Idempotência: Alerta de suporte já emitido para o evento ${entityId}. Ignorando retry.`);
        return { triggered: false, skippedReason: "ALREADY_DISPATCHED_FOR_EVENT" };
      }
    } catch (err: any) {
      console.warn(`[SupportAlert] Aviso ao verificar duplicidade de alerta:`, err.message);
    }
  }

  // 5. Despacho do alerta para os 2 números de suporte via smartSend
  const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY") || "";
  const results: Array<{ phone: string; success: boolean; error?: string }> = [];

  for (const supportPhone of SUPPORT_PHONES) {
    try {
      const sendResult = await smartSend(
        BOTCONVERSA_API_KEY,
        null,
        supportPhone,
        "text",
        SUPPORT_ALERT_MESSAGE,
        "Suporte",
        supabase,
        undefined,
        MessageType.NOTICE,
        callerFunction,
        undefined,
        "inbound_support_alert",
        entityId ? String(entityId) : undefined
      );

      results.push({
        phone: supportPhone,
        success: sendResult.success,
        error: sendResult.error
      });
    } catch (err: any) {
      console.error(`[SupportAlert] Erro ao despachar alerta para ${supportPhone}:`, err.message);
      results.push({
        phone: supportPhone,
        success: false,
        error: err.message
      });
    }
  }

  const overallSuccess = results.some(r => r.success);
  console.log(`[SupportAlert] Alerta de suporte processado (${callerFunction}): triggered=${overallSuccess}`);

  return {
    triggered: overallSuccess,
    results
  };
}
