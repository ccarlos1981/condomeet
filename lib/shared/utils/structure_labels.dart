/// Dynamic labels based on condominium tipo_estrutura.
///
/// tipo_estrutura values:
///   'predio'      → Bloco / Apto
///   'casa_rua'    → Rua / Número
///   'casa_quadra' → Quadra / Lote
library;

String getBlocoLabel(String? tipo) {
  if (tipo == 'casa_rua') return 'Rua';
  if (tipo == 'casa_quadra') return 'Quadra';
  return 'Bloco';
}

String getAptoLabel(String? tipo) {
  if (tipo == 'casa_rua') return 'Número';
  if (tipo == 'casa_quadra') return 'Lote';
  return 'Apto';
}

/// Returns "Blocos e Aptos" / "Quadras e Lotes" / "Ruas e Números"
String getEstruturaLabel(String? tipo) {
  return '${getBlocoLabel(tipo)}s e ${getAptoLabel(tipo)}s';
}
