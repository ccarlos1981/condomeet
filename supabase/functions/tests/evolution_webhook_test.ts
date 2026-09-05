import { parseEvolutionUpsert, mapEvolutionStatus } from "../evolution-webhook/index.ts";
import { MessageType, TEMPLATE_REGISTRY } from "../_shared/message_types.ts";

function assertEquals(actual: any, expected: any, msg?: string) {
  if (actual !== expected) {
    throw new Error(`Assertion failed: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}. ${msg || ''}`);
  }
}

// ── TESTES DE PARSING DE MENSAGENS INBOUND (messages.upsert) ─────────────────

Deno.test("TEST 1: Inbound messages.upsert com texto simples (conversation) -> parse correto", () => {
  const item = {
    key: {
      remoteJid: "5531992707070@s.whatsapp.net",
      fromMe: false,
      id: "3EB0ABC123456789"
    },
    pushName: "Cristiano Santos",
    message: {
      conversation: "OK"
    },
    messageType: "conversation"
  };

  const parsed = parseEvolutionUpsert(item);
  assertEquals(parsed !== null, true, "Payload deve ser parseado");
  assertEquals(parsed?.fromMe, false, "Mensagem deve ser inbound (fromMe=false)");
  assertEquals(parsed?.providerMessageId, "3EB0ABC123456789", "providerMessageId deve bater");
  assertEquals(parsed?.cleanPhone, "5531992707070", "Telefone normalizado canônico");
  assertEquals(parsed?.text, "OK", "Texto extraído");
  assertEquals(parsed?.pushName, "Cristiano Santos", "pushName extraído");
});

Deno.test("TEST 2: Inbound messages.upsert com extendedTextMessage -> parse correto", () => {
  const item = {
    key: {
      remoteJid: "5522998805319@s.whatsapp.net",
      fromMe: false,
      id: "BAE599887766"
    },
    pushName: "Morador Palmeiras",
    message: {
      extendedTextMessage: {
        text: "Tudo bem, número anotado!"
      }
    },
    messageType: "extendedTextMessage"
  };

  const parsed = parseEvolutionUpsert(item);
  assertEquals(parsed?.fromMe, false);
  assertEquals(parsed?.cleanPhone, "5522998805319");
  assertEquals(parsed?.text, "Tudo bem, número anotado!");
});

Deno.test("TEST 3: Inbound messages.upsert com imagem e caption -> parse correto", () => {
  const item = {
    key: {
      remoteJid: "5531992707070@s.whatsapp.net",
      fromMe: false,
      id: "3EB0IMG12345"
    },
    pushName: "Cristiano",
    message: {
      imageMessage: {
        caption: "Segue o comprovante"
      }
    },
    messageType: "imageMessage"
  };

  const parsed = parseEvolutionUpsert(item);
  assertEquals(parsed?.fromMe, false);
  assertEquals(parsed?.text, "Segue o comprovante");
  assertEquals(parsed?.messageType, "image");
});

Deno.test("TEST 4: Inbound messages.upsert com fromMe=true -> identificado corretamente para descarte", () => {
  const item = {
    key: {
      remoteJid: "5531992707070@s.whatsapp.net",
      fromMe: true,
      id: "BAE5OUTBOUND123"
    },
    message: {
      conversation: "Olá! Cadastro feito."
    }
  };

  const parsed = parseEvolutionUpsert(item);
  assertEquals(parsed?.fromMe, true, "Mensagem outbound deve ter fromMe=true");
});

Deno.test("TEST 5: Grupo de WhatsApp (@g.us) -> descartado (retorna null)", () => {
  const item = {
    key: {
      remoteJid: "12036302519927070@g.us",
      fromMe: false,
      id: "3EB0GROUP123"
    },
    message: {
      conversation: "Mensagem no grupo"
    }
  };

  const parsed = parseEvolutionUpsert(item);
  assertEquals(parsed, null, "Mensagens de grupo devem retornar null");
});

Deno.test("TEST 6: Broadcast status (@broadcast) -> descartado (retorna null)", () => {
  const item = {
    key: {
      remoteJid: "status@broadcast",
      fromMe: false,
      id: "STATUS123"
    },
    message: {
      conversation: "Status update"
    }
  };

  const parsed = parseEvolutionUpsert(item);
  assertEquals(parsed, null, "Status broadcast deve retornar null");
});

// ── TESTES DE MAPEAMENTO DE STATUS (messages.update) ─────────────────────────

Deno.test("TEST 7: Status mapping Baileys/Evolution numérico", () => {
  assertEquals(mapEvolutionStatus(1), "pending");
  assertEquals(mapEvolutionStatus(2), "sent");
  assertEquals(mapEvolutionStatus(3), "delivered");
  assertEquals(mapEvolutionStatus(4), "read");
  assertEquals(mapEvolutionStatus(5), "read");
});

Deno.test("TEST 8: Status mapping Baileys/Evolution string", () => {
  assertEquals(mapEvolutionStatus("SERVER_ACK"), "sent");
  assertEquals(mapEvolutionStatus("DELIVERY_ACK"), "delivered");
  assertEquals(mapEvolutionStatus("READ"), "read");
  assertEquals(mapEvolutionStatus("PLAYED"), "read");
  assertEquals(mapEvolutionStatus("FAILED"), "failed");
  assertEquals(mapEvolutionStatus("ERROR"), "failed");
  assertEquals(mapEvolutionStatus("UNKNOWN_CODE"), null);
});

// ── TESTES DE REGRESSÃO E ISOLAMENTO DE PROVEDORES ───────────────────────────

Deno.test("TEST 9: Regressão — Template Registry Meta permanece 100% blindado contra WELCOME", () => {
  assertEquals(TEMPLATE_REGISTRY[MessageType.WELCOME], null, "WELCOME não deve possuir template Meta");
  assertEquals(TEMPLATE_REGISTRY[MessageType.PARCEL]?.defaultName, "condomeet_encomenda_recebida_v2", "PARCEL preservado");
  assertEquals(TEMPLATE_REGISTRY[MessageType.VISITOR_INVITE]?.defaultName, "condomeet_visitante_aguardando_v3", "VISITOR preservado");
  assertEquals(TEMPLATE_REGISTRY[MessageType.OTP]?.defaultName, "condomeet_recuperacao_senha_v1", "OTP preservado");
});

// ── TESTES DE REQUISIÇÃO HTTP (handleEvolutionWebhook) ───────────────────────

import { handleEvolutionWebhook } from "../evolution-webhook/index.ts";

const MOCK_TEST_SECRET = "mock_secret_test_only_12345";

Deno.test("TEST 10A: Fail-Closed — Sem EVOLUTION_WEBHOOK_SECRET configurado no ambiente -> HTTP 403 Forbidden", async () => {
  Deno.env.delete("EVOLUTION_WEBHOOK_SECRET");

  const req = new Request("http://localhost:8000/evolution-webhook", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-evolution-token": "qualquer_token"
    },
    body: JSON.stringify({
      event: "messages.upsert",
      instance: "condomeet-secundario-prod",
      data: {}
    })
  });

  const res = await handleEvolutionWebhook(req);
  assertEquals(res.status, 403, "Sem secret configurado, deve falhar fechado com 403");
});

Deno.test("TEST 10B: Requisição com segredo/token incorreto -> HTTP 403 Forbidden", async () => {
  Deno.env.set("EVOLUTION_WEBHOOK_SECRET", MOCK_TEST_SECRET);

  const req = new Request("http://localhost:8000/evolution-webhook", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-evolution-token": "token_incorreto_invalido"
    },
    body: JSON.stringify({
      event: "messages.upsert",
      instance: "condomeet-secundario-prod",
      data: {}
    })
  });

  const res = await handleEvolutionWebhook(req);
  assertEquals(res.status, 403, "Token incorreto deve retornar 403");
});

Deno.test("TEST 11: Requisição com segredo válido e instância desconhecida -> HTTP 200 com status ignored_unknown_instance", async () => {
  Deno.env.set("EVOLUTION_WEBHOOK_SECRET", MOCK_TEST_SECRET);

  const req = new Request("http://localhost:8000/evolution-webhook", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-evolution-token": MOCK_TEST_SECRET
    },
    body: JSON.stringify({
      event: "messages.upsert",
      instance: "instancia_estranha_nao_autorizada",
      data: {}
    })
  });

  const res = await handleEvolutionWebhook(req);
  assertEquals(res.status, 200, "Instância desconhecida deve retornar 200");
  const data = await res.json();
  assertEquals(data.status, "ignored_unknown_instance", "Status deve ser ignored_unknown_instance");
});

Deno.test("TEST 12: Requisição com segredo válido e evento não suportado -> HTTP 200 com status ignored", async () => {
  Deno.env.set("EVOLUTION_WEBHOOK_SECRET", MOCK_TEST_SECRET);

  const req = new Request("http://localhost:8000/evolution-webhook", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-evolution-token": MOCK_TEST_SECRET
    },
    body: JSON.stringify({
      event: "contacts.upsert",
      instance: "condomeet-secundario-prod",
      data: {}
    })
  });

  const res = await handleEvolutionWebhook(req);
  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.status, "ignored");
});
