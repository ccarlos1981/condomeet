/**
 * Dynamic labels based on condominium tipo_estrutura.
 *
 * tipo_estrutura values:
 *   'predio'      → Bloco / Apto
 *   'casa_rua'    → Rua / Número
 *   'casa_quadra' → Quadra / Lote
 */

export function getBlocoLabel(tipo?: string | null): string {
  if (tipo === 'casa_rua') return 'Rua'
  if (tipo === 'casa_quadra') return 'Quadra'
  return 'Bloco'
}

export function getAptoLabel(tipo?: string | null): string {
  if (tipo === 'casa_rua') return 'Número'
  if (tipo === 'casa_quadra') return 'Lote'
  return 'Apto'
}

/** Returns "Blocos e Aptos" / "Quadras e Lotes" / "Ruas e Números" */
export function getEstruturaLabel(tipo?: string | null): string {
  return `${getBlocoLabel(tipo)}s e ${getAptoLabel(tipo)}s`
}
