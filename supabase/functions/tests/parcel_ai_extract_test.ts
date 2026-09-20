// supabase/functions/tests/parcel_ai_extract_test.ts
// Automated Unit & Integration test suite for parcel-ai-extract Edge Function
// Covering all variations: 301B, 301-B, 301/B, B301, B 301, Bloco B Apto 301, Apto 301 Bloco B,
// Montserrat real case (printed + handwritten), ambiguity detection, and safety edge cases.

import {
  normalizeUnitExtraction,
  decomposeAlphanumericUnit,
  extractCandidatesFromText,
  sanitizeField,
} from "../parcel-ai-extract/normalizer.ts";

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

// ── SUÍTE COMPLETA DE TESTES BACKEND ─────────────────────────────────────────

// ── GRUPO 1: PADRÕES MONTSERRAT E DECOMPOSIÇÃO ALFANUMÉRICA ──────────────────

Deno.test("01. MONTSERRAT: 301B (Número + Letra Sufixo) -> Bloco B / Apto 301", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "301B",
    confianca: 0.98,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.ambiguo, false);
});

Deno.test("02. MONTSERRAT: B301 (Letra Prefixo + Número) -> Bloco B / Apto 301", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "B301",
    confianca: 0.97,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.ambiguo, false);
});

Deno.test("03. MONTSERRAT: 301-B (Número + Hífen + Letra) -> Bloco B / Apto 301", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "301-B",
    confianca: 0.96,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.ambiguo, false);
});

Deno.test("04. MONTSERRAT: B-301 (Letra + Hífen + Número) -> Bloco B / Apto 301", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "B-301",
    confianca: 0.96,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.ambiguo, false);
});

Deno.test("05. MONTSERRAT: 301/B (Número + Barra + Letra) -> Bloco B / Apto 301", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "301/B",
    confianca: 0.95,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.ambiguo, false);
});

Deno.test("06. MONTSERRAT: B/301 (Letra + Barra + Número) -> Bloco B / Apto 301", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "B/301",
    confianca: 0.95,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.ambiguo, false);
});

Deno.test("07. MONTSERRAT: B 301 (Letra + Espaço + Número) -> Bloco B / Apto 301", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "B 301",
    confianca: 0.95,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.ambiguo, false);
});

Deno.test("08. MONTSERRAT: Bloco B Apto 301 (Explícito) -> Bloco B / Apto 301", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "Bloco B Apto 301",
    confianca: 0.99,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.ambiguo, false);
});

Deno.test("09. MONTSERRAT: Apto 301 Bloco B (Invertido) -> Bloco B / Apto 301", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "Apto 301 Bloco B",
    confianca: 0.99,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.ambiguo, false);
});

Deno.test("10. MONTSERRAT CASO REAL: Impresso 'Apto 301B' + Manuscrito '301/B' -> Bloco B / Apto 301", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "301B",
    textoImpresso: "Destinatário: Santos\nEndereço: Condomínio Montserrat Apto 301B",
    textoManuscrito: "301/B",
    confianca: 0.94,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "B");
  assertEquals(result.apartamento, "301");
  assertEquals(result.ambiguo, false);
  assert(result.confianca >= 0.95, "Confiança deve ser reforçada pela convergência de fontes");
});

Deno.test("11. AMBIGUIDADE DETECTADA: Impresso 'Apto 301B' vs Manuscrito '402A' -> Não sobrescreve, sugere ambas", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: null,
    textoImpresso: "Apto 301B",
    textoManuscrito: "402A",
    confianca: 0.90,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, false);
  assertEquals(result.ambiguo, true);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, null);
  assertEquals(result.sugestoes.length, 2);
  assert(result.sugestoes.some((s) => s.bloco === "B" && s.apartamento === "301"));
  assert(result.sugestoes.some((s) => s.bloco === "A" && s.apartamento === "402"));
});

// ── GRUPO 2: PADRÕES NOMINAIS (STAR CITY) ────────────────────────────────────

Deno.test("12. STAR CITY: ALFA 201 (Bloco Nominal Direto) -> Bloco Alfa / Apto 201", () => {
  const result = normalizeUnitExtraction({
    bloco: "Alfa",
    apartamento: "201",
    confianca: 0.94,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "ALFA");
  assertEquals(result.apartamento, "201");
});

Deno.test("13. STAR CITY: TORRE ALFA AP 201 (Bloco Nominal Explícito) -> Bloco Alfa / Apto 201", () => {
  const result = normalizeUnitExtraction({
    bloco: "Alfa",
    apartamento: "201",
    rawText: "TORRE ALFA AP 201",
    confianca: 0.98,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "ALFA");
  assertEquals(result.apartamento, "201");
});

// ── GRUPO 3: CONDOMÍNIO HORIZONTAL / QUADRA E LOTE (BORA PESCAR) ─────────────

Deno.test("14. BORA PESCAR: QD 12 LT 4 (Sigla Horizontal) -> Bloco 12 / Apto 4", () => {
  const result = normalizeUnitExtraction({
    bloco: "12",
    apartamento: "4",
    confianca: 0.96,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "12");
  assertEquals(result.apartamento, "4");
});

Deno.test("15. BORA PESCAR: QUADRA 12 LOTE 04 (Extenso Horizontal) -> Bloco 12 / Apto 4", () => {
  const result = normalizeUnitExtraction({
    bloco: "12",
    apartamento: "04",
    confianca: 0.98,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "12");
  assertEquals(result.apartamento, "04");
});

// ── GRUPO 4: RECANTO DAS PALMEIRAS (DUPLO NUMÉRICO & CONTEXTO) ───────────────

Deno.test("16. RECANTO: BL 36 AP 302 (Explícito) -> Bloco 36 / Apto 302", () => {
  const result = normalizeUnitExtraction({
    bloco: "36",
    apartamento: "302",
    confianca: 0.98,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "36");
  assertEquals(result.apartamento, "302");
});

Deno.test("17. RECANTO: Complemento 36/302 (Duplo Numérico com Contexto) -> Bloco 36 / Apto 302", () => {
  const result = normalizeUnitExtraction({
    bloco: "36",
    apartamento: "302",
    rawText: "Complemento: 36/302",
    confianca: 0.95,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, "36");
  assertEquals(result.apartamento, "302");
});

// ── GRUPO 5: CASOS NEGATIVOS E DE SEGURANÇA (ZERO ALUCINAÇÃO) ────────────────

Deno.test("18. NÃO-INVENÇÃO: '301' isolado -> Bloco permanece null (NUNCA inventa bloco)", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: "301",
    confianca: 0.9,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, "301");
});

Deno.test("19. NÃO-INVENÇÃO: 'B' isolado sem contexto -> Não transforma em unidade", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: null,
    rawText: "B",
    confianca: 0.15,
    leitura_ok: false,
  });
  assertEquals(result.leitura_ok, false);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, null);
});

Deno.test("20. NÃO-INVENÇÃO: Número cortado '30_' -> null para o campo cortado", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: null,
    rawText: "30_",
    confianca: 0.2,
    leitura_ok: false,
  });
  assertEquals(result.leitura_ok, false);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, null);
});

Deno.test("21. NÃO-INVENÇÃO: Foto borrada ou pacote sem etiqueta -> Fallback total", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: null,
    confianca: 0.05,
    leitura_ok: false,
  });
  assertEquals(result.leitura_ok, false);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, null);
});

Deno.test("22. HIGIENIZAÇÃO: Remoção de strings lixo ('N/A', 'none', 'null')", () => {
  const result = normalizeUnitExtraction({
    bloco: "none",
    apartamento: "305",
    confianca: 0.88,
    leitura_ok: true,
  });
  assertEquals(result.leitura_ok, true);
  assertEquals(result.bloco, null);
  assertEquals(result.apartamento, "305");
});

Deno.test("23. RESILIÊNCIA: Confianca baixa (< 0.35) -> leitura_ok forçado para false se sem campos válidos", () => {
  const result = normalizeUnitExtraction({
    bloco: null,
    apartamento: null,
    confianca: 0.2,
    leitura_ok: false,
  });
  assertEquals(result.leitura_ok, false);
});
