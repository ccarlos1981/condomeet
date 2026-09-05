import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateWhatsAppSendPolicy, normalizePhone } from "../_shared/botconversa.ts";
import { MessageType, AUTHORIZED_TRANSACTIONAL_CALLERS, CALLER_ALLOWED_MESSAGE_TYPES } from "../_shared/message_types.ts";
import { dispatchSupportInboundAlert, SUPPORT_PHONES, SUPPORT_ALERT_MESSAGE } from "../_shared/support_alert.ts";

Deno.test("Fase 4.24.25 - 1. Whitelist Verification for Webhook Callers", () => {
  assertEquals(AUTHORIZED_TRANSACTIONAL_CALLERS.has("whatsapp-webhook"), true);
  assertEquals(AUTHORIZED_TRANSACTIONAL_CALLERS.has("evolution-webhook"), true);

  const metaAllowed = CALLER_ALLOWED_MESSAGE_TYPES["whatsapp-webhook"];
  assertEquals(metaAllowed.has(MessageType.NOTICE), true);
  assertEquals(metaAllowed.has(MessageType.PARCEL), false); // must only allow NOTICE

  const evoAllowed = CALLER_ALLOWED_MESSAGE_TYPES["evolution-webhook"];
  assertEquals(evoAllowed.has(MessageType.NOTICE), true);
  assertEquals(evoAllowed.has(MessageType.PARCEL), false); // must only allow NOTICE
});

Deno.test("Fase 4.24.25 - 2. Policy Governance Validation for Webhooks", () => {
  const policyCheckMeta = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-webhook",
    messageType: MessageType.NOTICE,
    textValue: SUPPORT_ALERT_MESSAGE,
  });
  assertEquals(policyCheckMeta.allowed, true);

  const policyCheckEvo = validateWhatsAppSendPolicy({
    callerFunction: "evolution-webhook",
    messageType: MessageType.NOTICE,
    textValue: SUPPORT_ALERT_MESSAGE,
  });
  assertEquals(policyCheckEvo.allowed, true);

  // Adversarial: Webhook trying to send unauthorized MessageType
  const policyCheckBlocked = validateWhatsAppSendPolicy({
    callerFunction: "whatsapp-webhook",
    messageType: MessageType.PARCEL,
    textValue: "fake",
  });
  assertEquals(policyCheckBlocked.allowed, false);
});

Deno.test("Fase 4.24.25 - 3. Anti-Loop Protection for Support Numbers", async () => {
  const mockSupabase = {
    from: () => ({
      select: () => ({
        eq: () => ({
          eq: () => ({
            limit: () => Promise.resolve({ data: [] }),
          }),
        }),
      }),
    }),
  };

  // When sender is Support Phone 1 (5531992707070)
  const result1 = await dispatchSupportInboundAlert({
    supabase: mockSupabase,
    senderPhone: "5531992707070",
    inboundOutboxId: "test-uuid-1",
    callerFunction: "whatsapp-webhook",
  });
  assertEquals(result1.triggered, false);
  assertEquals(result1.skippedReason, "LOOP_PROTECTION_SUPPORT_NUMBER");

  // When sender is Support Phone 2 (5531994707070)
  const result2 = await dispatchSupportInboundAlert({
    supabase: mockSupabase,
    senderPhone: "31994707070", // with or without 55
    inboundOutboxId: "test-uuid-2",
    callerFunction: "evolution-webhook",
  });
  assertEquals(result2.triggered, false);
  assertEquals(result2.skippedReason, "LOOP_PROTECTION_SUPPORT_NUMBER");
});

Deno.test("Fase 4.24.25 - 4. Idempotency Check on Duplicate Inbound Event", async () => {
  const mockSupabaseDuplicate = {
    from: () => ({
      select: () => ({
        eq: () => ({
          eq: () => ({
            limit: () => Promise.resolve({ data: [{ id: "existing-alert-outbox-id" }] }),
          }),
        }),
      }),
    }),
  };

  const result = await dispatchSupportInboundAlert({
    supabase: mockSupabaseDuplicate,
    senderPhone: "5522998887777",
    inboundOutboxId: "duplicate-inbound-id",
    callerFunction: "whatsapp-webhook",
  });
  assertEquals(result.triggered, false);
  assertEquals(result.skippedReason, "ALREADY_DISPATCHED_FOR_EVENT");
});

Deno.test("Fase 4.24.25 - 5. Target Numbers and Alert Message Verification", () => {
  assertEquals(SUPPORT_PHONES.length, 2);
  assertEquals(SUPPORT_PHONES[0], "5531992707070");
  assertEquals(SUPPORT_PHONES[1], "5531994707070");
  assertEquals(SUPPORT_ALERT_MESSAGE, "🔔 Alguém está querendo falar com o suporte.");
});
