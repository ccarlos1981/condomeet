/**
 * Condomeet Web — Matcher e Validador de Unidades Pós-OCR de Encomendas
 *
 * Valida a extração do OCR contra a estrutura real de blocos e apartamentos cadastrados no condomínio.
 * Decompõe variações como 301B, B301, 301/B, 301-B, Bloco B Apto 301, Apto 301 Bloco B
 * e impede sobrescrita em caso de ambiguidade.
 */

export interface RegisteredUnit {
  blocoNome: string;
  aptoNumero: string;
  residentId?: string | null;
  residentName?: string | null;
}

export interface MatchUnitOptions {
  rawBloco: string | null;
  rawApto: string | null;
  units: RegisteredUnit[];
  blocos: string[];
  aiAmbiguous?: boolean;
  aiSuggestions?: Array<{ bloco: string; apartamento: string }>;
  tipoEstrutura?: string;
}

export interface MatchUnitResult {
  success: boolean;
  bloco: string | null;
  apto: string | null;
  ambiguous: boolean;
  suggestions: Array<{ bloco: string; apto: string }>;
  message: string;
}

/**
 * Remove identificadores comuns de unidade.
 */
function cleanUnitPrefix(str: string): string {
  return str
    .replace(/^(?:apartamento|apto|apt|ap|unidade|un|casa|lote|lt)\b[\s:.-]*/i, '')
    .replace(/^(?:bloco|torre|bl|quadra|qd)\b[\s:.-]*/i, '')
    .trim();
}

/**
 * Decompõe string alfanumérica em { apto, bloco }.
 */
export function decomposeAlphanumeric(val: string): { apto: string; bloco: string } | null {
  if (!val || typeof val !== 'string') return null;

  let cleaned = val.trim().replace(/^["'(\[]+|["')\]]+$/g, '').trim();

  // Caso 1: "Bloco B Apto 301", "BL B AP 301"
  const explicitBlApto = cleaned.match(
    /(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)\s*[\/,\-\s]+\s*(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)/i
  ) || cleaned.match(
    /(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)\s+(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)/i
  );
  if (explicitBlApto) {
    return { bloco: explicitBlApto[1].toUpperCase(), apto: explicitBlApto[2] };
  }

  // Caso 2: "Apto 301 Bloco B", "AP 301 BL B", "301 Bloco B"
  const explicitAptoBl = cleaned.match(
    /(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)\s*[\/,\-\s]+\s*(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)/i
  ) || cleaned.match(
    /(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)\s+(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)/i
  ) || cleaned.match(
    /^(\d+)\s+(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)/i
  );
  if (explicitAptoBl) {
    return { bloco: explicitAptoBl[2].toUpperCase(), apto: explicitAptoBl[1] };
  }

  cleaned = cleanUnitPrefix(cleaned);

  // Caso 3: Sufixo "301B", "301-B", "301/B", "301 B", "301.B"
  const suffixMatch = cleaned.match(/^(\d{1,5})\s*[\/\-._\s]?\s*([A-Za-z]{1,3})$/);
  if (suffixMatch) {
    return { apto: suffixMatch[1], bloco: suffixMatch[2].toUpperCase() };
  }

  // Caso 4: Prefixo "B301", "B-301", "B/301", "B 301", "B.301"
  const prefixMatch = cleaned.match(/^([A-Za-z]{1,3})\s*[\/\-._\s]?\s*(\d{1,5})$/);
  if (prefixMatch) {
    return { bloco: prefixMatch[1].toUpperCase(), apto: prefixMatch[2] };
  }

  return null;
}

/**
 * Realiza o matching determinístico da unidade com base nas unidades cadastradas no condomínio.
 */
export function matchParcelUnit({
  rawBloco,
  rawApto,
  units,
  blocos,
  aiAmbiguous = false,
  aiSuggestions = [],
  tipoEstrutura,
}: MatchUnitOptions): MatchUnitResult {
  const blocoLabel = tipoEstrutura === 'casas' ? 'Quadra' : 'Bloco';
  const aptoLabel = tipoEstrutura === 'casas' ? 'Casa' : 'Apartamento';

  // 1. Se a IA já marcou ambiguidade na leitura visual
  if (aiAmbiguous && aiSuggestions.length > 1) {
    const validSuggestions = aiSuggestions
      .map(s => ({
        bloco: s.bloco,
        apto: s.apartamento,
      }))
      .filter(s =>
        units.some(
          u => u.blocoNome.toLowerCase() === s.bloco.toLowerCase() &&
               u.aptoNumero.toLowerCase() === s.apto.toLowerCase()
        )
      );

    const suggestionStr = validSuggestions.length > 0
      ? validSuggestions.map(s => `${blocoLabel} ${s.bloco} - ${aptoLabel} ${s.apto}`).join(' ou ')
      : aiSuggestions.map(s => `${blocoLabel} ${s.bloco} - ${aptoLabel} ${s.apartamento}`).join(' ou ');

    return {
      success: false,
      bloco: null,
      apto: null,
      ambiguous: true,
      suggestions: validSuggestions.length > 0 ? validSuggestions : aiSuggestions.map(s => ({ bloco: s.bloco, apto: s.apartamento })),
      message: `⚠️ Leitura com ambiguidade detectada na foto (${suggestionStr}). Por favor, confirme a unidade manualmente.`,
    };
  }

  const b = rawBloco ? rawBloco.trim() : null;
  const a = rawApto ? rawApto.trim() : null;

  if (!b && !a) {
    return {
      success: false,
      bloco: null,
      apto: null,
      ambiguous: false,
      suggestions: [],
      message: '⚠️ Não foi possível identificar a unidade pela foto. Preencha manualmente.',
    };
  }

  // 2. Passo 1: Match Direto Exato
  if (b && a) {
    const directMatch = units.find(
      u => u.blocoNome.toLowerCase() === b.toLowerCase() &&
           u.aptoNumero.toLowerCase() === a.toLowerCase()
    );
    if (directMatch) {
      return {
        success: true,
        bloco: directMatch.blocoNome,
        apto: directMatch.aptoNumero,
        ambiguous: false,
        suggestions: [],
        message: '✓ Unidade identificada automaticamente pela foto',
      };
    }
  }

  // 3. Passo 2: Geração de Candidatos via Decomposição
  const candidates: Array<{ bloco: string; apto: string }> = [];

  // Se 'a' tiver decomposição (ex: "301B" -> apto "301", bloco "B")
  if (a) {
    const decA = decomposeAlphanumeric(a);
    if (decA) {
      candidates.push({ bloco: decA.bloco, apto: decA.apto });
    }
  }

  // Se 'b' tiver decomposição
  if (b) {
    const decB = decomposeAlphanumeric(b);
    if (decB) {
      candidates.push({ bloco: decB.bloco, apto: decB.apto });
    }
  }

  // Se 'b' e 'a' existem como valores puros
  if (b && a) {
    candidates.push({ bloco: b.toUpperCase(), apto: a });
  }

  // 4. Validação dos candidatos contra as unidades cadastradas
  const validMatchedUnits: RegisteredUnit[] = [];
  for (const cand of candidates) {
    const matched = units.filter(
      u => u.blocoNome.toLowerCase() === cand.bloco.toLowerCase() &&
           u.aptoNumero.toLowerCase() === cand.apto.toLowerCase()
    );
    for (const m of matched) {
      if (!validMatchedUnits.some(v => v.blocoNome === m.blocoNome && v.aptoNumero === m.aptoNumero)) {
        validMatchedUnits.push(m);
      }
    }
  }

  // Verifica se existia um apartamento cadastrado literalmente com o nome '301B' (caso raro em condomínio sem blocos)
  if (a) {
    const literalMatches = units.filter(
      u => u.aptoNumero.toLowerCase() === a.toLowerCase() &&
           (!b || u.blocoNome.toLowerCase() === b.toLowerCase())
    );
    for (const m of literalMatches) {
      if (!validMatchedUnits.some(v => v.blocoNome === m.blocoNome && v.aptoNumero === m.aptoNumero)) {
        validMatchedUnits.push(m);
      }
    }
  }

  // 5. Avaliação dos resultados validados
  if (validMatchedUnits.length === 1) {
    const single = validMatchedUnits[0];
    return {
      success: true,
      bloco: single.blocoNome,
      apto: single.aptoNumero,
      ambiguous: false,
      suggestions: [],
      message: '✓ Unidade identificada automaticamente pela foto',
    };
  }

  if (validMatchedUnits.length > 1) {
    const suggestionList = validMatchedUnits.map(u => ({ bloco: u.blocoNome, apto: u.aptoNumero }));
    const suggestionStr = suggestionList.map(s => `${blocoLabel} ${s.bloco} - ${aptoLabel} ${s.apto}`).join(' ou ');
    return {
      success: false,
      bloco: null,
      apto: null,
      ambiguous: true,
      suggestions: suggestionList,
      message: `⚠️ Mais de uma unidade correspondente encontrada (${suggestionStr}). Por favor, selecione manualmente.`,
    };
  }

  // 6. Caso nenhum candidato completo bata: verificar se ao menos o bloco foi localizado
  const candidateBloco = candidates[0]?.bloco || b;
  const matchingBlocoOnly = candidateBloco
    ? blocos.find(bk => bk.trim().toLowerCase() === candidateBloco.toLowerCase())
    : null;

  if (matchingBlocoOnly && !a) {
    return {
      success: false,
      bloco: matchingBlocoOnly,
      apto: null,
      ambiguous: false,
      suggestions: [],
      message: `✓ ${blocoLabel} identificado. Selecione o ${aptoLabel.toLowerCase()} manualmente.`,
    };
  }

  if (!matchingBlocoOnly && a) {
    const candidateApto = candidates[0]?.apto || a;
    return {
      success: false,
      bloco: null,
      apto: null,
      ambiguous: false,
      suggestions: [],
      message: `⚠️ ${aptoLabel} ${candidateApto} identificado, mas o ${blocoLabel.toLowerCase()} não está visível na foto. Selecione o ${blocoLabel.toLowerCase()} manualmente.`,
    };
  }

  return {
    success: false,
    bloco: null,
    apto: null,
    ambiguous: false,
    suggestions: [],
    message: '⚠️ A unidade identificada na foto não foi encontrada neste condomínio. Confira os dados manualmente.',
  };
}
