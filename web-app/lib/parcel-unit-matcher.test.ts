// web-app/lib/parcel-unit-matcher.test.ts
// Testes unitários para o matching de unidades Web com a estrutura real de Montserrat e variações

import { matchParcelUnit, decomposeAlphanumeric } from "./parcel-unit-matcher";

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

// Estrutura Real do Condomínio Montserrat
const montserratBlocos = ["A", "B"];
const montserratUnits = [
  { blocoNome: "A", aptoNumero: "101" },
  { blocoNome: "A", aptoNumero: "301" },
  { blocoNome: "B", aptoNumero: "101" },
  { blocoNome: "B", aptoNumero: "301" },
  { blocoNome: "B", aptoNumero: "302" },
];

Deno.test("WEB 01. MONTSERRAT: '301B' sem bloco -> Localiza Bloco B / Apto 301", () => {
  const res = matchParcelUnit({
    rawBloco: null,
    rawApto: "301B",
    units: montserratUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, true);
  assertEquals(res.bloco, "B");
  assertEquals(res.apto, "301");
  assertEquals(res.ambiguous, false);
});

Deno.test("WEB 02. MONTSERRAT: '301/B' manuscrito sem bloco -> Localiza Bloco B / Apto 301", () => {
  const res = matchParcelUnit({
    rawBloco: null,
    rawApto: "301/B",
    units: montserratUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, true);
  assertEquals(res.bloco, "B");
  assertEquals(res.apto, "301");
});

Deno.test("WEB 03. MONTSERRAT: '301-B' sem bloco -> Localiza Bloco B / Apto 301", () => {
  const res = matchParcelUnit({
    rawBloco: null,
    rawApto: "301-B",
    units: montserratUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, true);
  assertEquals(res.bloco, "B");
  assertEquals(res.apto, "301");
});

Deno.test("WEB 04. MONTSERRAT: 'B301' sem bloco -> Localiza Bloco B / Apto 301", () => {
  const res = matchParcelUnit({
    rawBloco: null,
    rawApto: "B301",
    units: montserratUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, true);
  assertEquals(res.bloco, "B");
  assertEquals(res.apto, "301");
});

Deno.test("WEB 05. MONTSERRAT: 'B 301' sem bloco -> Localiza Bloco B / Apto 301", () => {
  const res = matchParcelUnit({
    rawBloco: null,
    rawApto: "B 301",
    units: montserratUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, true);
  assertEquals(res.bloco, "B");
  assertEquals(res.apto, "301");
});

Deno.test("WEB 06. MONTSERRAT: 'Bloco B Apto 301' -> Localiza Bloco B / Apto 301", () => {
  const res = matchParcelUnit({
    rawBloco: null,
    rawApto: "Bloco B Apto 301",
    units: montserratUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, true);
  assertEquals(res.bloco, "B");
  assertEquals(res.apto, "301");
});

Deno.test("WEB 07. MONTSERRAT: 'Apto 301 Bloco B' -> Localiza Bloco B / Apto 301", () => {
  const res = matchParcelUnit({
    rawBloco: null,
    rawApto: "Apto 301 Bloco B",
    units: montserratUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, true);
  assertEquals(res.bloco, "B");
  assertEquals(res.apto, "301");
});

Deno.test("WEB 08. MONTSERRAT: Bloco B pré-extraído com '301B' -> Localiza Bloco B / Apto 301", () => {
  const res = matchParcelUnit({
    rawBloco: "B",
    rawApto: "301B",
    units: montserratUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, true);
  assertEquals(res.bloco, "B");
  assertEquals(res.apto, "301");
});

Deno.test("WEB 09. MONTSERRAT: Caso padrão direto Bloco B / Apto 301 -> Preservado", () => {
  const res = matchParcelUnit({
    rawBloco: "B",
    rawApto: "301",
    units: montserratUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, true);
  assertEquals(res.bloco, "B");
  assertEquals(res.apto, "301");
});

Deno.test("WEB 10. AMBIGUIDADE NO CONDOMÍNIO: Se existir Apto 301B e Bloco B Apto 301 -> Não sobrescreve", () => {
  const ambiguousUnits = [
    { blocoNome: "A", aptoNumero: "301B" }, // Apto literalmente chamado 301B no Bloco A
    { blocoNome: "B", aptoNumero: "301" },  // Apto 301 no Bloco B
  ];
  const res = matchParcelUnit({
    rawBloco: null,
    rawApto: "301B",
    units: ambiguousUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, false);
  assertEquals(res.ambiguous, true);
  assertEquals(res.bloco, null);
  assertEquals(res.apto, null);
  assertEquals(res.suggestions.length, 2);
});

Deno.test("WEB 11. UNIDADE INEXISTENTE: '301Z' -> Não encontrada", () => {
  const res = matchParcelUnit({
    rawBloco: null,
    rawApto: "301Z",
    units: montserratUnits,
    blocos: montserratBlocos,
  });
  assertEquals(res.success, false);
  assertEquals(res.bloco, null);
  assertEquals(res.apto, null);
});
