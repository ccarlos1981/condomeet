import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { parseBotConversaInbound, handleBotConversaWebhook } from "../botconversa-webhook/index.ts";

Deno.test("TEST 1: Inbound BotConversa com campos planos (phone + message) -> parse correto", () => {
  const payload = {
    phone: "31992707070",
    message: "Ok",
    first_name: "Cristiano",
    subscriber_id: "346077263",
  };

  const parsed = parseBotConversaInbound(payload);
  assertEquals(parsed !== null, true);
  assertEquals(parsed?.cleanPhone, "5531992707070");
  assertEquals(parsed?.messageText, "Ok");
  assertEquals(parsed?.firstName, "Cristiano");
  assertEquals(parsed?.subscriberId, "346077263");
});

Deno.test("TEST 2: Inbound BotConversa com objeto aninhado (subscriber + message) -> parse correto", () => {
  const payload = {
    subscriber: {
      phone: "5585989194889",
      first_name: "Luciano",
      id: "468326495",
    },
    message: {
      text: "Confirmado recebimento",
      id: "msg_abc123",
    },
  };

  const parsed = parseBotConversaInbound(payload);
  assertEquals(parsed !== null, true);
  assertEquals(parsed?.cleanPhone, "5585989194889");
  assertEquals(parsed?.messageText, "Confirmado recebimento");
  assertEquals(parsed?.firstName, "Luciano");
  assertEquals(parsed?.subscriberId, "468326495");
  assertEquals(parsed?.messageId, "msg_abc123");
});

Deno.test("TEST 3: Inbound sem telefone ou mensagem -> retorna null (rejeição)", () => {
  assertEquals(parseBotConversaInbound({ phone: "31992707070" }), null);
  assertEquals(parseBotConversaInbound({ message: "Ok" }), null);
  assertEquals(parseBotConversaInbound({}), null);
});

Deno.test("TEST 4: Fail-Closed — Sem BOTCONVERSA_WEBHOOK_SECRET configurado -> HTTP 403 Forbidden", async () => {
  const origSecret = Deno.env.get("BOTCONVERSA_WEBHOOK_SECRET");
  Deno.env.delete("BOTCONVERSA_WEBHOOK_SECRET");

  try {
    const req = new Request("http://localhost:8000/botconversa-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-botconversa-token": "algum_token",
      },
      body: JSON.stringify({ phone: "5531992707070", message: "Ok" }),
    });

    const res = await handleBotConversaWebhook(req);
    assertEquals(res.status, 403);
    const body = await res.json();
    assertEquals(body.error, "Unauthorized: Invalid webhook secret.");
  } finally {
    if (origSecret) Deno.env.set("BOTCONVERSA_WEBHOOK_SECRET", origSecret);
  }
});

Deno.test("TEST 5: Requisição com segredo/token incorreto -> HTTP 403 Forbidden", async () => {
  const origSecret = Deno.env.get("BOTCONVERSA_WEBHOOK_SECRET");
  Deno.env.set("BOTCONVERSA_WEBHOOK_SECRET", "super_secret_homologado_2026");

  try {
    const req = new Request("http://localhost:8000/botconversa-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-botconversa-token": "token_errado_invalido",
      },
      body: JSON.stringify({ phone: "5531992707070", message: "Ok" }),
    });

    const res = await handleBotConversaWebhook(req);
    assertEquals(res.status, 403);
    const body = await res.json();
    assertEquals(body.error, "Unauthorized: Invalid webhook secret.");
  } finally {
    if (origSecret) {
      Deno.env.set("BOTCONVERSA_WEBHOOK_SECRET", origSecret);
    } else {
      Deno.env.delete("BOTCONVERSA_WEBHOOK_SECRET");
    }
  }
});

Deno.test("TEST 6: Requisição com segredo válido e payload incompleto -> HTTP 400 Bad Request", async () => {
  const origSecret = Deno.env.get("BOTCONVERSA_WEBHOOK_SECRET");
  Deno.env.set("BOTCONVERSA_WEBHOOK_SECRET", "super_secret_homologado_2026");

  try {
    const req = new Request("http://localhost:8000/botconversa-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-botconversa-token": "super_secret_homologado_2026",
      },
      body: JSON.stringify({ phone: "5531992707070" }), // sem mensagem
    });

    const res = await handleBotConversaWebhook(req);
    assertEquals(res.status, 400);
    const body = await res.json();
    assertEquals(body.error.includes("phone and message text are required"), true);
  } finally {
    if (origSecret) {
      Deno.env.set("BOTCONVERSA_WEBHOOK_SECRET", origSecret);
    } else {
      Deno.env.delete("BOTCONVERSA_WEBHOOK_SECRET");
    }
  }
});
