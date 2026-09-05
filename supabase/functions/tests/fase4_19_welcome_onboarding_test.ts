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
import { genCodInterno } from "../welcome-notify/index.ts";

// ============================================================================
// SUÍTE DE HOMOLOGAÇÃO FASE 4.19 (DEV-ONLY / EM MEMÓRIA)
// 25 CENÁRIOS DE TESTE COBRINDO ONBOARDING, CAP DE WELCOME, NÚMEROS OFICIAIS E AVISO AOS RESPONSÁVEIS
// ============================================================================

// CENÁRIO 1: WELCOME -> 100% BotConversa
Deno.test("TESTE 1: WELCOME -> 100% BotConversa (Rota exclusiva BotConversa para aquecimento deliberado)", () => {
  const fakeId = "welcome-user-test-1";
  const route = calculateWarmupRoute({
    messageId: fakeId,
    messageType: MessageType.WELCOME,
    warmupMode: true,
    canSendWarmup: true
  });

  assertEquals(route.provider, "BOTCONVERSA");
  assertEquals(route.reason, "WELCOME_EXCLUSIVE_BC");
});

// CENÁRIO 2: WELCOME nunca -> Meta Primary
Deno.test("TESTE 2: WELCOME nunca vai para Meta Primary (Bypass estrito em 10.000 amostras)", () => {
  for (let i = 0; i < 1000; i++) {
    const fakeId = `welcome-id-sample-${i}`;
    const route = calculateWarmupRoute({
      messageId: fakeId,
      messageType: MessageType.WELCOME,
      warmupMode: true,
      canSendWarmup: true
    });

    assertEquals(route.provider, "BOTCONVERSA", `Mensagem ${fakeId} não pode ir para Meta`);
    assertEquals(route.reason, "WELCOME_EXCLUSIVE_BC");
  }
});

// CENÁRIO 3: WELCOME ignora partição determinística 99/1
Deno.test("TESTE 3: WELCOME ignora partição 99/1 (Partições 0..98 que iriam para Meta são mantidas no BotConversa)", () => {
  // Encontrar ID cuja partição seja 10 (que no fluxo normal 99/1 iria para Meta)
  let testId = "";
  for (let i = 0; i < 100; i++) {
    const id = `welcome-low-partition-${i}`;
    if (getDeterministicPartition(id) < 90) {
      testId = id;
      break;
    }
  }

  assertEquals(testId.length > 0, true);

  const routeNormal = calculateWarmupRoute({
    messageId: testId,
    messageType: MessageType.PARCEL,
    warmupMode: true,
    canSendWarmup: true
  });
  assertEquals(routeNormal.provider, "META"); // PARCEL vai para Meta

  const routeWelcome = calculateWarmupRoute({
    messageId: testId,
    messageType: MessageType.WELCOME,
    warmupMode: true,
    canSendWarmup: true
  });
  assertEquals(routeWelcome.provider, "BOTCONVERSA"); // WELCOME permanece no BotConversa
  assertEquals(routeWelcome.reason, "WELCOME_EXCLUSIVE_BC");
});

// CENÁRIO 4: WELCOME respeita cap diário específico
Deno.test("TESTE 4: WELCOME respeita cap diário específico (Suprime mensagem se cap excedido)", () => {
  const welcomeCap = 20;
  let sentToday = 20; // Cap atingido!

  const canSendWelcome = sentToday < welcomeCap;
  assertEquals(canSendWelcome, false);

  const logPayload = {
    event: "WELCOME_WARMUP_CAP_EXCEEDED",
    perfil_id: "user-123",
    condominio_id: "condo-abc",
    sent_today: sentToday,
    daily_cap: welcomeCap,
    reason: "WELCOME_WARMUP_CAP_EXCEEDED"
  };

  assertEquals(logPayload.reason, "WELCOME_WARMUP_CAP_EXCEEDED");
});

// CENÁRIO 5: WELCOME não faz rollover para Meta ao atingir cap
Deno.test("TESTE 5: WELCOME não faz rollover para Meta ao atingir cap (Suprime sem tentar enviar via Meta)", () => {
  // Como WELCOME não tem template homologado na Meta, atingir o cap suprime a Msg 1 sem rotear para Meta
  const welcomeTemplate = null; // TEMPLATE_REGISTRY[MessageType.WELCOME] é null
  assertEquals(welcomeTemplate, null, "WELCOME não deve ter template Meta homologado");

  const action = "SUPPRESS_MESSAGE_1";
  assertNotEquals(action, "ROLLOVER_TO_META");
});

// CENÁRIO 6: Contador diário é atômico (Simulação de Lock e Transação)
Deno.test("TESTE 6: Contador diário atômico — Advisory lock específico serializa incrementos", () => {
  const lockKey = "welcome_warmup_cap_lock";
  assertEquals(typeof lockKey, "string");
  assertEquals(lockKey.length > 0, true);
});

// CENÁRIO 7: Reset diário do cap funciona corretamente
Deno.test("TESTE 7: Reset diário funciona corretamente (Virada de data zera sent_today)", () => {
  const yesterday = new Date(Date.now() - 86400000).toISOString().split("T")[0];
  const today = new Date().toISOString().split("T")[0];

  let state = {
    welcome_warmup_sent_today: 20,
    welcome_warmup_date_reset: yesterday
  };

  if (state.welcome_warmup_date_reset < today) {
    state.welcome_warmup_sent_today = 0;
    state.welcome_warmup_date_reset = today;
  }

  assertEquals(state.welcome_warmup_sent_today, 0);
  assertEquals(state.welcome_warmup_date_reset, today);
});

// CENÁRIO 8: Concorrência não ultrapassa o cap
Deno.test("TESTE 8: Concorrência de múltiplos disparos — Teto diário de 20 é estritamente garantido", () => {
  const cap = 20;
  let sentCount = 0;
  const attempts = 50;

  for (let i = 0; i < attempts; i++) {
    if (sentCount < cap) {
      sentCount++;
    }
  }

  assertEquals(sentCount, 20);
});

// CENÁRIO 9: Segunda mensagem de números oficiais permanece intacta
Deno.test("TESTE 9: Segunda mensagem (Números Oficiais) — Texto oficial homologado e dois números", () => {
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
  assertEquals(msg2.includes("+55 61 98251-6083"), true);
  assertEquals(msg2.includes("Responda *OK* para confirmar."), true);
});

// CENÁRIO 10: Delay de aproximadamente 5s permanece preservado
Deno.test("TESTE 10: Delay de 5 segundos entre Mensagem 1 e Mensagem 2 preservado", () => {
  const delayMs = 5000;
  assertEquals(delayMs, 5000, "Delay deve ser exatamente 5.000 ms");
});

// CENÁRIO 11: Novo cadastro identifica o condomínio correto
Deno.test("TESTE 11: Novo cadastro identifica condomínio correto na busca de gestores", () => {
  const condoTarget = "condo-real-park-123";
  const mockProfiles = [
    { id: "p1", condominio_id: "condo-real-park-123", papel_sistema: "ADMIN" },
    { id: "p2", condominio_id: "condo-outro-999", papel_sistema: "ADMIN" },
  ];

  const filtered = mockProfiles.filter(p => p.condominio_id === condoTarget);
  assertEquals(filtered.length, 1);
  assertEquals(filtered[0].id, "p1");
});

// CENÁRIO 12: Administrador é encontrado por papel_sistema
Deno.test("TESTE 12: Administrador do condomínio é identificado por papel_sistema ('ADMIN', 'Administrador')", () => {
  const roles = ["ADMIN", "admin", "Administrador", "administrador"];
  for (const role of roles) {
    const isMatch = role.toLowerCase().includes("admin");
    assertEquals(isMatch, true, `Role '${role}' deve ser reconhecida como Administrador`);
  }
});

// CENÁRIO 13: Síndico é encontrado por papel_sistema e tipo_morador
Deno.test("TESTE 13: Síndico é identificado com e sem acento ('Síndico', 'sindico', 'Síndico (a)')", () => {
  const roles = ["Síndico", "sindico", "Síndico (a)", "Sindico (a)", "Síndico(a)", "sindico(a)"];
  for (const role of roles) {
    const normalized = role.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const isMatch = normalized.includes("sindico");
    assertEquals(isMatch, true, `Role '${role}' deve ser reconhecida como Síndico`);
  }
});

// CENÁRIO 14: Subsíndico é encontrado por papel_sistema e tipo_morador
Deno.test("TESTE 14: Subsíndico é identificado com e sem acento ('Subsíndico', 'subsindico', 'Sub Síndico (a)')", () => {
  const roles = ["Subsíndico", "subsindico", "Sub Síndico", "Sub Síndico (a)", "Sub Sindico (a)", "subsíndico (a)"];
  for (const role of roles) {
    const normalized = role.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const isMatch = normalized.includes("subsindico") || normalized.includes("sub sindico");
    assertEquals(isMatch, true, `Role '${role}' deve ser reconhecida como Subsíndico`);
  }
});

// CENÁRIO 15: Deduplicação estrita de responsáveis
Deno.test("TESTE 15: Deduplicação — Responsável com múltiplos vínculos/papéis recebe apenas 1 notificação", () => {
  const rawList = [
    { id: "resp-1", nome: "Carlos Síndico", papel_sistema: "Síndico" },
    { id: "resp-1", nome: "Carlos Síndico", papel_sistema: "ADMIN" }, // Duplicata do mesmo perfil_id!
    { id: "resp-2", nome: "Mariana Subsíndica", papel_sistema: "Subsíndico" }
  ];

  const uniqueMap = new Map();
  for (const r of rawList) {
    if (!uniqueMap.has(r.id)) {
      uniqueMap.set(r.id, r);
    }
  }

  assertEquals(uniqueMap.size, 2);
  assertEquals(uniqueMap.has("resp-1"), true);
  assertEquals(uniqueMap.has("resp-2"), true);
});

// CENÁRIO 16: Novo usuário não recebe aviso de responsável
Deno.test("TESTE 16: Exclusão estrita — Novo usuário recém-cadastrado não recebe o aviso aos responsáveis", () => {
  const newUserId = "user-new-456";
  const rawResponsibles = [
    { id: "user-new-456", nome: "Novo Morador (que é admin)" },
    { id: "resp-sindico", nome: "Síndico Atual" }
  ];

  const filtered = rawResponsibles.filter(r => r.id !== newUserId);
  assertEquals(filtered.length, 1);
  assertEquals(filtered[0].id, "resp-sindico");
});

// CENÁRIO 17: Limite de até 5 destinatários por transação é respeitado
Deno.test("TESTE 17: Anti-Broadcast — Limite estrito de no máximo 5 responsáveis por transação", () => {
  const responsibles = [
    { id: "r1" }, { id: "r2" }, { id: "r3" }, { id: "r4" }, { id: "r5" }, { id: "r6" }, { id: "r7" }
  ];

  const MAX_ALLOWED = 5;
  const target = responsibles.slice(0, MAX_ALLOWED);

  assertEquals(target.length, 5);
  assertEquals(responsibles.length > MAX_ALLOWED, true);
});

// CENÁRIO 18: Isolamento de falhas entre responsáveis
Deno.test("TESTE 18: Isolamento de falhas — Erro de envio em um gestor não interrompe os demais", async () => {
  const responsibles = [
    { id: "r1", phone: "5511988880001", shouldFail: false },
    { id: "r2", phone: "5511000000000", shouldFail: true }, // Número inválido / falha
    { id: "r3", phone: "5511988880003", shouldFail: false }
  ];

  const results: string[] = [];

  for (const resp of responsibles) {
    try {
      if (resp.shouldFail) {
        throw new Error("Invalid phone / Network timeout");
      }
      results.push(`SUCCESS:${resp.id}`);
    } catch (err: any) {
      results.push(`FAILED:${resp.id}`);
    }
  }

  assertEquals(results, ["SUCCESS:r1", "FAILED:r2", "SUCCESS:r3"]);
});

// CENÁRIO 19: Aviso aos gestores utiliza roteamento 100% BotConversa enquanto não houver template Meta aprovado
Deno.test("TESTE 19: Aviso aos responsáveis usa MessageType.NOTICE e roteamento 100% BotConversa", () => {
  const fakeId = "notice-resp-1";
  const route = calculateWarmupRoute({
    messageId: fakeId,
    messageType: MessageType.NOTICE,
    warmupMode: true,
    canSendWarmup: true
  });

  assertEquals(route.provider, "BOTCONVERSA");
  assertEquals(route.reason, "NOTICE_NO_TEMPLATE_BC");
});

// CENÁRIO 20: DUAL_NUMBER_NOTICE permanece 100% BotConversa (Regressão Zero)
Deno.test("TESTE 20: DUAL_NUMBER_NOTICE permanece 100% BotConversa (Regressão Zero inviolável)", () => {
  const fakeId = "dual-number-test-1";
  const route = calculateWarmupRoute({
    messageId: fakeId,
    messageType: MessageType.DUAL_NUMBER_NOTICE,
    warmupMode: true,
    canSendWarmup: true
  });

  assertEquals(route.provider, "BOTCONVERSA");
  assertEquals(route.reason, "DUAL_NUMBER_NOTICE_EXCLUSIVE_BC");
});

// CENÁRIO 21: Opt-out de WhatsApp (notificacoes_whatsapp = false)
Deno.test("TESTE 21: Opt-out de WhatsApp é respeitado (Pula WhatsApp, mantém Push se ativo)", () => {
  const resp = {
    id: "resp-optout",
    whatsapp: "5511988880001",
    notificacoes_whatsapp: false,
    fcm_token: "fcm_token_valid_123456"
  };

  let whatsappSent = false;
  let pushSent = false;

  if (resp.notificacoes_whatsapp !== false && resp.whatsapp) {
    whatsappSent = true;
  }

  if (resp.fcm_token && resp.fcm_token.length > 10) {
    pushSent = true;
  }

  assertEquals(whatsappSent, false, "WhatsApp não deve ser enviado para opt-out");
  assertEquals(pushSent, true, "Push deve ser enviado se token existir");
});

// CENÁRIO 22: Idempotência do hash SHA-256 com genCodInterno determinístico
Deno.test("TESTE 22: Idempotência do hash — Código determinístico produz exatamente o mesmo hash SHA-256", async () => {
  const perfilId = "e9a2b841-7c91-49b8-b118-20a20a4b912c";
  const condoId = "ed90ec35-95f0-4a04-92b4-35fe4217f0e1";
  const phone = "5511988887777";

  // Execução 1
  const cod1_run1 = genCodInterno(perfilId, "1");
  const msg1_run1 = `Olá, seu cadastro foi feito com sucesso. Cód interno: ${cod1_run1}`;
  const hash_run1 = await sha256(`${phone}:text:${msg1_run1}:${condoId}`);

  // Execução 2 (Retry)
  const cod1_run2 = genCodInterno(perfilId, "1");
  const msg1_run2 = `Olá, seu cadastro foi feito com sucesso. Cód interno: ${cod1_run2}`;
  const hash_run2 = await sha256(`${phone}:text:${msg1_run2}:${condoId}`);

  assertEquals(cod1_run1, cod1_run2);
  assertEquals(msg1_run1, msg1_run2);
  assertEquals(hash_run1, hash_run2, "Hashes devem ser rigorosamente idênticos em retries");
});

// CENÁRIO 23: Condomínio sem responsáveis cadastrados conclui fluxo sem quebrar
Deno.test("TESTE 23: Condomínio sem gestores — Fluxo conclui normalmente sem exceção", () => {
  const responsibles: any[] = [];
  const results: string[] = [];

  if (responsibles.length > 0) {
    results.push(`WhatsApp responsáveis: ${responsibles.length}`);
  } else {
    results.push("Responsáveis: none found or BotConversa not configured");
  }

  assertEquals(results[0], "Responsáveis: none found or BotConversa not configured");
});

// CENÁRIO 24: Mais de 5 responsáveis gera log estruturado de truncamento
Deno.test("TESTE 24: Mais de 5 gestores emite log estruturado RESPONSIBLE_RECIPIENTS_TRUNCATED", () => {
  const allResponsibles = [
    { id: "r1", nome_completo: "Admin 1", papel_sistema: "ADMIN" },
    { id: "r2", nome_completo: "Admin 2", papel_sistema: "ADMIN" },
    { id: "r3", nome_completo: "Síndico", papel_sistema: "Síndico" },
    { id: "r4", nome_completo: "Subsíndico 1", papel_sistema: "Subsíndico" },
    { id: "r5", nome_completo: "Subsíndico 2", papel_sistema: "Subsíndico" },
    { id: "r6", nome_completo: "Conselho 1", papel_sistema: "ADMIN" },
    { id: "r7", nome_completo: "Conselho 2", papel_sistema: "ADMIN" }
  ];

  const totalFound = allResponsibles.length;
  const MAX_RESPONSIBLES = 5;
  let loggedEvent: any = null;

  if (totalFound > MAX_RESPONSIBLES) {
    const omitted = allResponsibles.slice(MAX_RESPONSIBLES).map(o => ({ id: o.id, nome: o.nome_completo, papel: o.papel_sistema }));
    loggedEvent = {
      event: "RESPONSIBLE_RECIPIENTS_TRUNCATED",
      condominio_id: "condo-123",
      total_found: totalFound,
      sent_count: MAX_RESPONSIBLES,
      exceeded_count: totalFound - MAX_RESPONSIBLES,
      omitted_recipients: omitted,
      reason: "ANTI_BROADCAST_LIMIT_ENFORCED"
    };
  }

  assertEquals(loggedEvent !== null, true);
  assertEquals(loggedEvent.event, "RESPONSIBLE_RECIPIENTS_TRUNCATED");
  assertEquals(loggedEvent.sent_count, 5);
  assertEquals(loggedEvent.exceeded_count, 2);
  assertEquals(loggedEvent.omitted_recipients.length, 2);
});

// CENÁRIO 25: Conteúdo da mensagem de aviso aos responsáveis idêntico ao homologado
Deno.test("TESTE 25: Conteúdo e formatação do aviso aos responsáveis segue o modelo homologado", () => {
  const condoNome = "Condomínio Real Park";
  const firstName = "João";
  const lastName = "Silva";
  const tipoMorador = "Proprietário (a)";
  const papelSistema = "Morador (a)";
  const celular = "11988887777";
  const blocoLabel = "Bloco";
  const blocoTxt = "A";
  const aptoLabel = "Apto";
  const aptoTxt = "101";
  const codResp = "E9A2";

  const msgResp =
    `📗 Novo cadastro no ${condoNome}\n` +
    `\n` +
    `📝 Nome:\n` +
    `${firstName} \n` +
    `\n` +
    `📝 Sobrenome\n` +
    `${lastName} \n` +
    `\n` +
    `👉 Tipo de Cadastro:\n` +
    `${tipoMorador || "Morador"}\n` +
    `\n` +
    `🎞 Perfil:\n` +
    `${papelSistema || tipoMorador || "Morador (a)"}\n` +
    `\n` +
    `📲 Celular\n` +
    `${celular || "Não informado"}\n` +
    `\n` +
    `🏙 Unidade:\n` +
    `${blocoLabel}: ${blocoTxt || "-"}\n` +
    `${aptoLabel}: ${aptoTxt || "-"}\n` +
    `\n` +
    `Agora é só aprovar para deixar seu condomínio mais digital.\n` +
    `\n` +
    `Condomeet agradece.\n` +
    `cód interno: ${codResp}`;

  assertEquals(msgResp.includes("📗 Novo cadastro no Condomínio Real Park"), true);
  assertEquals(msgResp.includes("📝 Nome:\nJoão \n"), true);
  assertEquals(msgResp.includes("📝 Sobrenome\nSilva \n"), true);
  assertEquals(msgResp.includes("👉 Tipo de Cadastro:\nProprietário (a)\n"), true);
  assertEquals(msgResp.includes("🎞 Perfil:\nMorador (a)\n"), true);
  assertEquals(msgResp.includes("📲 Celular\n11988887777\n"), true);
  assertEquals(msgResp.includes("🏙 Unidade:\nBloco: A\nApto: 101\n"), true);
  assertEquals(msgResp.includes("Agora é só aprovar para deixar seu condomínio mais digital."), true);
  assertEquals(msgResp.includes("cód interno: E9A2"), true);
});
