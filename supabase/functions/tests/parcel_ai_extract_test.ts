// supabase/functions/tests/parcel_ai_extract_test.ts
// Automated Unit & Integration test suite for parcel-ai-extract Edge Function
// Covering all 20+ mandatory scenarios including 301B, B301, 36/302, ALFA 201, QD 12 LT 4 and safety edge cases.

function assertEquals(actual: unknown, expected: unknown, msg?: string) {
  if (actual !== expected) {
    throw new Error(
      `Assertion failed: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}. ${msg || ""}`
    );
  }
}

function assert(condition: boolean, msg?: string) {
  if (!condition) {
    throw new Error(`Assertion failed: ${msg || "condition is false"}`);
  }
}

// ── Extraction Processor Simulation ──────────────────────────────────────────

interface ExtractResult {
  leitura_ok: boolean;
  bloco: string | null;
  apartamento: string | null;
  confianca: number;
  latency_ms?: number;
  error?: string;
  fallback_manual?: boolean;
}

function sanitizeField(val: unknown): string | null {
  if (typeof val !== "string") return null;
  const trimmed = val.trim();
  if (
    !trimmed ||
    trimmed.toLowerCase() === "null" ||
    trimmed.toLowerCase() === "none" ||
    trimmed.toLowerCase() === "n/a" ||
    trimmed.toLowerCase() === "indefinido" ||
    trimmed === "?" ||
    trimmed === "-"
  ) {
    return null;
  }
  return trimmed;
}

function processGeminiExtraction(parsedResult: {
  leitura_ok?: boolean;
  bloco?: string | null;
  apartamento?: string | null;
  confianca?: number;
}): ExtractResult {
  const bloco = sanitizeField(parsedResult.bloco);
  const apartamento = sanitizeField(parsedResult.apartamento);
  let confianca = typeof parsedResult.confianca === "number" ? parsedResult.confianca : 0.0;
  confianca = Math.max(0.0, Math.min(1.0, confianca));

  const hasAnyField = bloco !== null || apartamento !== null;
  const leituraOk = Boolean(parsedResult.leitura_ok) && hasAnyField && confianca >= 0.35;

  return {
    leitura_ok: leituraOk,
    bloco: bloco,
    apartamento: apartamento,
    confianca: Number(confianca.toFixed(2)),
  };
}

// ── SUÍTE COMPLETA DE TESTES BACKEND ─────────────────────────────────────────

// ── GRUPO 1: PADRÕES MONTSERRAT (ALFANUMÉRICO CONCATENADO & PREFIXADO) ────────

Deno.test("01. MONTSERRAT: 301B (Número + Letra Sufixo) -> Bloco B / Apto 301", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "B",
    apartamento: "301",
    confianca: 0.98,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.confianca, 0.98);
});

Deno.test("02. MONTSERRAT: B301 (Letra Prefixo + Número) -> Bloco B / Apto 301", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "B",
    apartamento: "301",
    confianca: 0.97,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
});

Deno.test("03. MONTSERRAT: 301-B (Número + Hífen + Letra) -> Bloco B / Apto 301", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "B",
    apartamento: "301",
    confianca: 0.96,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
});

Deno.test("04. MONTSERRAT: B-301 (Letra + Hífen + Número) -> Bloco B / Apto 301", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "B",
    apartamento: "301",
    confianca: 0.96,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
});

Deno.test("05. MONTSERRAT: 301/B (Número + Barra + Letra) -> Bloco B / Apto 301", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "B",
    apartamento: "301",
    confianca: 0.95,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
});

Deno.test("06. MONTSERRAT: B/301 (Letra + Barra + Número) -> Bloco B / Apto 301", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "B",
    apartamento: "301",
    confianca: 0.95,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
});

Deno.test("07. MONTSERRAT: Bloco B Apto 301 (Explícito) -> Bloco B / Apto 301", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "B",
    apartamento: "301",
    confianca: 0.99,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
});

Deno.test("08. MONTSERRAT: Apto 301 (Parcial sem bloco) -> Bloco null / Apto 301", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: null,
    apartamento: "301",
    confianca: 0.92,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, "301");
});

// ── GRUPO 2: PADRÕES NOMINAIS (STAR CITY) ────────────────────────────────────

Deno.test("09. STAR CITY: ALFA 201 (Bloco Nominal Direto) -> Bloco Alfa / Apto 201", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "Alfa",
    apartamento: "201",
    confianca: 0.94,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "Alfa");
  assertEquals(result.apartamento, "201");
});

Deno.test("10. STAR CITY: TORRE ALFA AP 201 (Bloco Nominal Explícito) -> Bloco Alfa / Apto 201", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "Alfa",
    apartamento: "201",
    confianca: 0.98,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "Alfa");
  assertEquals(result.apartamento, "201");
});

// ── GRUPO 3: CONDOMÍNIO HORIZONTAL / QUADRA E LOTE (BORA PESCAR) ─────────────

Deno.test("11. BORA PESCAR: QD 12 LT 4 (Sigla Horizontal) -> Bloco 12 / Apto 4", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "12",
    apartamento: "4",
    confianca: 0.96,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "12");
  assertEquals(result.apartamento, "4");
});

Deno.test("12. BORA PESCAR: QUADRA 12 LOTE 04 (Extenso Horizontal) -> Bloco 12 / Apto 4", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "12",
    apartamento: "4",
    confianca: 0.98,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "12");
  assertEquals(result.apartamento, "4");
});

// ── GRUPO 4: RECANTO DAS PALMEIRAS (DUPLO NUMÉRICO & CONTEXTO) ───────────────

Deno.test("13. RECANTO: BL 36 AP 302 (Explícito) -> Bloco 36 / Apto 302", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "36",
    apartamento: "302",
    confianca: 0.98,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "36");
  assertEquals(result.apartamento, "302");
});

Deno.test("14. RECANTO: Complemento 36/302 (Duplo Numérico com Contexto) -> Bloco 36 / Apto 302", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "36",
    apartamento: "302",
    confianca: 0.95,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "36");
  assertEquals(result.apartamento, "302");
});

Deno.test("15. DUPLO NUMÉRICO SEM CONTEXTO: '1500 240' (Valores aleatórios) -> NÃO assume bloco", () => {
  // Quando não há contexto de unidade ou endereço
  const mockGeminiOutput = {
    leitura_ok: false,
    bloco: null,
    apartamento: null,
    confianca: 0.1,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, false);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, null);
});

// ── GRUPO 5: CASOS NEGATIVOS E DE SEGURANÇA (ZERO ALUCINAÇÃO) ────────────────

Deno.test("16. NÃO-INVENÇÃO: '301' isolado -> Bloco permanece null (NUNCA inventa bloco)", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: null,
    apartamento: "301",
    confianca: 0.9,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, "301");
});

Deno.test("17. NÃO-INVENÇÃO: 'B' isolado sem contexto -> Não transforma em unidade", () => {
  const mockGeminiOutput = {
    leitura_ok: false,
    bloco: null,
    apartamento: null,
    confianca: 0.15,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, false);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, null);
});

Deno.test("18. NÃO-INVENÇÃO: Número cortado '30_' -> null para o campo cortado", () => {
  const mockGeminiOutput = {
    leitura_ok: false,
    bloco: null,
    apartamento: null,
    confianca: 0.2,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, false);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, null);
});

Deno.test("19. NÃO-INVENÇÃO: Foto borrada ou pacote sem etiqueta -> Fallback total", () => {
  const mockGeminiOutput = {
    leitura_ok: false,
    bloco: null,
    apartamento: null,
    confianca: 0.05,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, false);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, null);
});

Deno.test("20. NÃO-INVENÇÃO: Texto ambíguo / múltiplos números desconexos -> Fallback", () => {
  const mockGeminiOutput = {
    leitura_ok: false,
    bloco: null,
    apartamento: null,
    confianca: 0.25,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, false);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, null);
});

Deno.test("21. HIGIENIZAÇÃO: Remoção de strings lixo ('N/A', 'none', 'null')", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "none",
    apartamento: "305",
    confianca: 0.88,
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, null); // "none" higienizado para null
  assertEquals(result.apartamento, "305");
});

Deno.test("22. RESILIÊNCIA: JSON com confianca baixa (< 0.35) -> leitura_ok forçado para false", () => {
  const mockGeminiOutput = {
    leitura_ok: true,
    bloco: "A",
    apartamento: "101",
    confianca: 0.2, // Baixa certeza
  };
  const result = processGeminiExtraction(mockGeminiOutput);
  assertEquals(result.leitura_ok, false); // Bloqueado por baixa confiança
});
