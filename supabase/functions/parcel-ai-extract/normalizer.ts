/**
 * Condomeet — Normalizador e Interpretador Pós-OCR de Encomendas
 *
 * Responsável por:
 * 1. Decompor variações alfanuméricas de Bloco e Apartamento (ex: 301B, B301, 301/B, 301-B, B 301);
 * 2. Interpretar padrões explícitos (ex: "Bloco B Apto 301", "Apto 301 Bloco B");
 * 3. Correlacionar texto impresso e anotações manuscritas como fontes complementares;
 * 4. Detectar ambiguidades e gerar sugestões seguras sem sobrescrita silenciosa;
 * 5. Garantir estritamente a Regra Soberana de Não-Invenção (Zero Alucinação).
 */

export interface RawOcrInput {
  bloco?: string | null;
  apartamento?: string | null;
  confianca?: number;
  leitura_ok?: boolean;
  rawText?: string | null;
  textoImpresso?: string | null;
  textoManuscrito?: string | null;
  knownBlocos?: string[];
}

export interface UnitCandidate {
  bloco: string | null;
  apartamento: string | null;
  origem: string;
  confianca: number;
}

export interface NormalizationOutput {
  leitura_ok: boolean;
  bloco: string | null;
  apartamento: string | null;
  confianca: number;
  ambiguo: boolean;
  sugestoes: Array<{ bloco: string; apartamento: string }>;
  raw_text?: string;
  candidatos: UnitCandidate[];
}

/**
 * Higieniza campo de texto removendo valores nulos/inválidos e espaços.
 */
export function sanitizeField(val: unknown): string | null {
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

/**
 * Remove identificadores e prefixos comuns de unidade (Apto, Apartamento, Bloco, etc.)
 */
function cleanUnitPrefix(str: string): string {
  return str
    .replace(/^(?:apartamento|apto|apt|ap|unidade|un|casa|lote|lt)\b[\s:.-]*/i, "")
    .replace(/^(?:bloco|torre|bl|quadra|qd)\b[\s:.-]*/i, "")
    .trim();
}

/**
 * Decompõe uma string alfanumérica única (ex: "301B", "301/B", "B301", "301-B", "B 301", "Apto 301B")
 * retornando { apto, bloco } se houver um padrão claro de número e letra, ou null.
 */
export function decomposeAlphanumericUnit(val: string): { apto: string; bloco: string; padrao: string } | null {
  if (!val || typeof val !== "string") return null;

  let cleaned = val.trim();
  // Remove aspas ou pontuações de borda
  cleaned = cleaned.replace(/^["'(\[]+|["')\]]+$/g, "").trim();

  // Caso 1: Padrões explícitos com palavras-chave completas dentro da string
  // Ex: "Bloco B Apto 301", "BL B AP 301", "Torre B Ap 301"
  const explicitBlApto = cleaned.match(
    /(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)\s*[\/,\-\s]+\s*(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)/i
  ) || cleaned.match(
    /(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)\s+(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)/i
  );
  if (explicitBlApto) {
    return { bloco: explicitBlApto[1].toUpperCase(), apto: explicitBlApto[2], padrao: "bloco_apto_explicito" };
  }

  // Ex: "Apto 301 Bloco B", "AP 301 BL B", "301 Bloco B"
  const explicitAptoBl = cleaned.match(
    /(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)\s*[\/,\-\s]+\s*(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)/i
  ) || cleaned.match(
    /(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)\s+(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)/i
  ) || cleaned.match(
    /^(\d+)\s+(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)/i
  );
  if (explicitAptoBl) {
    return { bloco: explicitAptoBl[2].toUpperCase(), apto: explicitAptoBl[1], padrao: "apto_bloco_invertido" };
  }

  // Remove prefixos como "Apto", "Ap.", "Apartamento" para focar no miolo alfanumérico
  cleaned = cleanUnitPrefix(cleaned);

  // Caso 2: Padrão Sufixo: Número seguido de Letra (ex: "301B", "301-B", "301/B", "301 B", "301.B", "301_B")
  // Restringe letras a 1 a 3 caracteres para evitar pegar palavras completas como "301 RUA"
  const suffixMatch = cleaned.match(/^(\d{1,5})\s*[\/\-._\s]?\s*([A-Za-z]{1,3})$/);
  if (suffixMatch) {
    return {
      apto: suffixMatch[1],
      bloco: suffixMatch[2].toUpperCase(),
      padrao: "numero_letra_sufixo",
    };
  }

  // Caso 3: Padrão Prefixo: Letra seguida de Número (ex: "B301", "B-301", "B/301", "B 301", "B.301", "B_301")
  const prefixMatch = cleaned.match(/^([A-Za-z]{1,3})\s*[\/\-._\s]?\s*(\d{1,5})$/);
  if (prefixMatch) {
    return {
      bloco: prefixMatch[1].toUpperCase(),
      apto: prefixMatch[2],
      padrao: "letra_numero_prefixo",
    };
  }

  return null;
}

/**
 * Procura padrões de unidade dentro de um bloco maior de texto (impresso, manuscrito ou raw).
 */
export function extractCandidatesFromText(text: string, origem: string): UnitCandidate[] {
  if (!text || typeof text !== "string") return [];
  const candidates: UnitCandidate[] = [];

  // Padrão 1: "Bloco B Apto 301" / "BL 36 AP 302" / "Torre Alfa Ap 201"
  const regexBlApto = /(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)[\s,/-]+(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)/gi;
  let match: RegExpExecArray | null;
  while ((match = regexBlApto.exec(text)) !== null) {
    candidates.push({
      bloco: match[1].trim().toUpperCase(),
      apartamento: match[2].trim(),
      origem: `${origem}:bloco_apto`,
      confianca: 0.98,
    });
  }

  // Padrão 2: "Apto 301 Bloco B" / "AP 301 BL B"
  const regexAptoBl = /(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)[\s,/-]+(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)/gi;
  while ((match = regexAptoBl.exec(text)) !== null) {
    candidates.push({
      bloco: match[2].trim().toUpperCase(),
      apartamento: match[1].trim(),
      origem: `${origem}:apto_bloco`,
      confianca: 0.98,
    });
  }

  // Padrão 3: "Apto 301B", "Ap 301-B", "Apt 301/B", "Apto B301"
  const regexPrefixedAlphanum = /(?:apto|apt|ap|apartamento|unidade|un\.?)\s*([A-Za-z0-9/.\-_]+)/gi;
  while ((match = regexPrefixedAlphanum.exec(text)) !== null) {
    const raw = match[1].trim();
    const decomposed = decomposeAlphanumericUnit(raw);
    if (decomposed) {
      candidates.push({
        bloco: decomposed.bloco,
        apartamento: decomposed.apto,
        origem: `${origem}:apto_prefixado_${decomposed.padrao}`,
        confianca: 0.95,
      });
    } else if (/^\d{1,5}$/.test(raw)) {
      candidates.push({
        bloco: null,
        apartamento: raw,
        origem: `${origem}:apto_apenas_numero`,
        confianca: 0.85,
      });
    }
  }

  // Padrão 4: Expressões isoladas "301B", "301/B", "301-B", "B301" delimitadas por espaço/quebra de linha
  const tokens = text.split(/[\n,;]+/).map((t) => t.trim());
  for (const token of tokens) {
    const decomposed = decomposeAlphanumericUnit(token);
    if (decomposed) {
      candidates.push({
        bloco: decomposed.bloco,
        apartamento: decomposed.apto,
        origem: `${origem}:token_${decomposed.padrao}`,
        confianca: 0.92,
      });
    }
  }

  return candidates;
}

/**
 * Normaliza a extração bruta gerada pelo OCR, aplicando decomposição alfanumérica,
 * conciliação entre fontes complementares (impresso + manuscrito) e detecção de ambiguidade.
 */
export function normalizeUnitExtraction(input: RawOcrInput): NormalizationOutput {
  const rawBloco = sanitizeField(input.bloco);
  const rawApto = sanitizeField(input.apartamento);
  let baseConfianca = typeof input.confianca === "number" ? input.confianca : 0.0;
  baseConfianca = Math.max(0.0, Math.min(1.0, baseConfianca));

  const allCandidates: UnitCandidate[] = [];

  // 1. Analisa os campos pré-extraídos diretamente pelo modelo
  if (rawApto) {
    const decomposedApto = decomposeAlphanumericUnit(rawApto);
    if (decomposedApto) {
      allCandidates.push({
        bloco: decomposedApto.bloco,
        apartamento: decomposedApto.apto,
        origem: "decomposicao_apartamento_bruto",
        confianca: 0.96,
      });
    } else {
      // Se não decompôs, mas há um bloco pré-extraído, adiciona a combinação direta
      allCandidates.push({
        bloco: rawBloco ? rawBloco.toUpperCase() : null,
        apartamento: rawApto,
        origem: "campos_diretos_ocr",
        confianca: baseConfianca,
      });
    }
  }

  if (rawBloco && !rawApto) {
    const decomposedBloco = decomposeAlphanumericUnit(rawBloco);
    if (decomposedBloco) {
      allCandidates.push({
        bloco: decomposedBloco.bloco,
        apartamento: decomposedBloco.apto,
        origem: "decomposicao_bloco_bruto",
        confianca: 0.95,
      });
    } else {
      allCandidates.push({
        bloco: rawBloco.toUpperCase(),
        apartamento: null,
        origem: "apenas_bloco_direto",
        confianca: baseConfianca,
      });
    }
  }

  // 2. Extrai candidatos de texto impresso e manuscrito
  if (input.textoImpresso) {
    allCandidates.push(...extractCandidatesFromText(input.textoImpresso, "impresso"));
  }
  if (input.textoManuscrito) {
    allCandidates.push(...extractCandidatesFromText(input.textoManuscrito, "manuscrito"));
  }
  if (input.rawText) {
    allCandidates.push(...extractCandidatesFromText(input.rawText, "raw_text"));
  }

  // 3. Agrupa e unifica candidatos únicos (bloco + apartamento)
  const candidateMap = new Map<string, { bloco: string | null; apartamento: string | null; count: number; maxConf: number }>();

  for (const c of allCandidates) {
    if (!c.bloco && !c.apartamento) continue;
    const key = `${c.bloco ?? "NULL"}|${c.apartamento ?? "NULL"}`;
    const existing = candidateMap.get(key);
    if (existing) {
      existing.count += 1;
      existing.maxConf = Math.max(existing.maxConf, c.confianca);
    } else {
      candidateMap.set(key, {
        bloco: c.bloco,
        apartamento: c.apartamento,
        count: 1,
        maxConf: c.confianca,
      });
    }
  }

  // 4. Filtra candidatos completos (que possuem bloco E apartamento)
  const completeCandidates = Array.from(candidateMap.values()).filter(
    (c) => c.bloco !== null && c.apartamento !== null
  );

  // 5. Avalia ambiguidade e consenso
  if (completeCandidates.length === 1) {
    // Consenso unânime em uma combinação completa
    const best = completeCandidates[0];
    const finalConf = best.count > 1 ? Math.min(1.0, best.maxConf + 0.05) : best.maxConf;

    return {
      leitura_ok: true,
      bloco: best.bloco,
      apartamento: best.apartamento,
      confianca: Number(finalConf.toFixed(2)),
      ambiguo: false,
      sugestoes: [],
      raw_text: input.rawText ?? undefined,
      candidatos: allCandidates,
    };
  }

  if (completeCandidates.length > 1) {
    // Múltiplas combinações completas distintas encontradas (ex: impresso 301B e manuscrito 402A)
    // Ordena por maior contagem e depois por maior confiança
    completeCandidates.sort((a, b) => b.count - a.count || b.maxConf - a.maxConf);

    // Se o primeiro candidato tiver evidência esmagadora sobre os outros (ex: 3 vezes mais citações)
    if (completeCandidates[0].count >= 3 && completeCandidates[1].count === 1) {
      const best = completeCandidates[0];
      return {
        leitura_ok: true,
        bloco: best.bloco,
        apartamento: best.apartamento,
        confianca: Number(best.maxConf.toFixed(2)),
        ambiguo: false,
        sugestoes: completeCandidates.slice(1).map((c) => ({ bloco: c.bloco!, apartamento: c.apartamento! })),
        raw_text: input.rawText ?? undefined,
        candidatos: allCandidates,
      };
    }

    // Ambiguidade real detectada: não sobrescrever nem chutar!
    return {
      leitura_ok: false,
      bloco: null,
      apartamento: null,
      confianca: Number(completeCandidates[0].maxConf.toFixed(2)),
      ambiguo: true,
      sugestoes: completeCandidates.map((c) => ({ bloco: c.bloco!, apartamento: c.apartamento! })),
      raw_text: input.rawText ?? undefined,
      candidatos: allCandidates,
    };
  }

  // 6. Caso não haja candidatos completos: verificar se temos ao menos o apartamento ou o bloco
  const partialCandidates = Array.from(candidateMap.values());
  const aptoOnly = partialCandidates.find((c) => c.bloco === null && c.apartamento !== null);
  const blocoOnly = partialCandidates.find((c) => c.bloco !== null && c.apartamento === null);

  if (aptoOnly && !blocoOnly) {
    return {
      leitura_ok: true,
      bloco: null,
      apartamento: aptoOnly.apartamento,
      confianca: Number(aptoOnly.maxConf.toFixed(2)),
      ambiguo: false,
      sugestoes: [],
      raw_text: input.rawText ?? undefined,
      candidatos: allCandidates,
    };
  }

  if (blocoOnly && !aptoOnly) {
    return {
      leitura_ok: true,
      bloco: blocoOnly.bloco,
      apartamento: null,
      confianca: Number(blocoOnly.maxConf.toFixed(2)),
      ambiguo: false,
      sugestoes: [],
      raw_text: input.rawText ?? undefined,
      candidatos: allCandidates,
    };
  }

  if (blocoOnly && aptoOnly) {
    // Temos bloco separado e apartamento separado em evidências parciais
    return {
      leitura_ok: true,
      bloco: blocoOnly.bloco,
      apartamento: aptoOnly.apartamento,
      confianca: Number(Math.min(blocoOnly.maxConf, aptoOnly.maxConf).toFixed(2)),
      ambiguo: false,
      sugestoes: [],
      raw_text: input.rawText ?? undefined,
      candidatos: allCandidates,
    };
  }

  // 7. Fallback seguro (Zero Leitura)
  return {
    leitura_ok: false,
    bloco: null,
    apartamento: null,
    confianca: 0.0,
    ambiguo: false,
    sugestoes: [],
    raw_text: input.rawText ?? undefined,
    candidatos: allCandidates,
  };
}
