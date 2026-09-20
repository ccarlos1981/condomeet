/**
 * Condomeet Mobile — Normalizador e Decompositor de Endereço de Encomendas
 *
 * Decompõe variações como:
 * - 301B, 301-B, 301/B, 301 B, 301.B
 * - B301, B-301, B/301, B 301, B.301
 * - Bloco B Apto 301, Apto 301 Bloco B
 *
 * Garante a correta identificação de Bloco e Apartamento pós-OCR.
 */

class DecomposedUnit {
  final String apto;
  final String bloco;
  final String pattern;

  const DecomposedUnit({
    required this.apto,
    required this.bloco,
    required this.pattern,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecomposedUnit &&
          runtimeType == other.runtimeType &&
          apto == other.apto &&
          bloco == other.bloco;

  @override
  int get hashCode => apto.hashCode ^ bloco.hashCode;

  @override
  String toString() => 'DecomposedUnit(apto: $apto, bloco: $bloco, pattern: $pattern)';
}

class ParcelAddressNormalizer {
  /// Remove identificadores comuns como Apto, Apartamento, Bloco, etc.
  static String cleanUnitPrefix(String str) {
    return str
        .replaceAll(
          RegExp(
            r'^(?:apartamento|apto|apt|ap|unidade|un|casa|lote|lt)\b[\s:.-]*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'^(?:bloco|torre|bl|quadra|qd)\b[\s:.-]*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  /// Decompõe strings alfanuméricas em { apto, bloco }
  static DecomposedUnit? decompose(String? val) {
    if (val == null || val.trim().isEmpty) return null;

    var cleaned = val.trim().replaceAll(RegExp(r'^["\x27(\[]+|["\x27)\]]+$'), '').trim();

    // Caso 1: Explícito "Bloco B Apto 301" / "BL B AP 301" / "Torre B Ap 301"
    final expBlApto = RegExp(
      r'(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)[\s,/-]+(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (expBlApto != null) {
      return DecomposedUnit(
        bloco: expBlApto.group(1)!.toUpperCase(),
        apto: expBlApto.group(2)!,
        pattern: 'bloco_apto_explicito',
      );
    }

    // Caso 2: Explícito Invertido "Apto 301 Bloco B" / "301 Bloco B"
    final expAptoBl = RegExp(
      r'(?:apto|apt|ap|apartamento|unidade|un\.?)\s*(\d+)[\s,/-]+(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(cleaned) ?? RegExp(
      r'^(\d+)\s+(?:bloco|bl\.?|torre)\s*([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (expAptoBl != null) {
      return DecomposedUnit(
        bloco: expAptoBl.group(2)!.toUpperCase(),
        apto: expAptoBl.group(1)!,
        pattern: 'apto_bloco_invertido',
      );
    }

    // Limpa prefixo de unidade se presente (ex: "Apto 301B" -> "301B")
    cleaned = cleanUnitPrefix(cleaned);

    // Caso 3: Sufixo "301B", "301-B", "301/B", "301 B", "301.B", "301_B"
    final suffixMatch = RegExp(r'^(\d{1,5})\s*[\/\-._\s]?\s*([A-Za-z]{1,3})$').firstMatch(cleaned);
    if (suffixMatch != null) {
      return DecomposedUnit(
        apto: suffixMatch.group(1)!,
        bloco: suffixMatch.group(2)!.toUpperCase(),
        pattern: 'numero_letra_sufixo',
      );
    }

    // Caso 4: Prefixo "B301", "B-301", "B/301", "B 301", "B.301", "B_301"
    final prefixMatch = RegExp(r'^([A-Za-z]{1,3})\s*[\/\-._\s]?\s*(\d{1,5})$').firstMatch(cleaned);
    if (prefixMatch != null) {
      return DecomposedUnit(
        bloco: prefixMatch.group(1)!.toUpperCase(),
        apto: prefixMatch.group(2)!,
        pattern: 'letra_numero_prefixo',
      );
    }

    return null;
  }
}
