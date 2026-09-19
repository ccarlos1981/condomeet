import { isTechnicalAdminRole } from './roles'
export { isTechnicalAdminRole } from './roles'

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


/**
 * Verifica se um par ou valor de bloco/apto representa uma unidade técnica administrativa
 * ('Admin', 'Administrador', ou placeholder técnico '0' / '0').
 */
export function isTechnicalAdminUnit(bloco?: string | null, apto?: string | null): boolean {
  const b = (bloco || '').trim().toLowerCase()
  const a = (apto || '').trim().toLowerCase()

  if (b === 'admin' || b === 'administrador' || b === 'administradora') return true
  if (a === 'admin' || a === 'administrador' || a === 'administradora') return true
  if (b === '0' && a === '0') return true
  if (b === '0' && !a) return true
  if (a === '0' && !b) return true

  return false
}

/**
 * Filtra blocos residenciais, removendo valores técnicos como 'Admin', 'Administrador', '0', etc.
 */
export function filterResidentialBlocos(blocos: (string | null | undefined)[]): string[] {
  const set = new Set<string>()
  for (const b of blocos) {
    if (!b) continue
    const trimmed = b.trim()
    if (!trimmed) continue
    const lower = trimmed.toLowerCase()
    if (lower === 'admin' || lower === 'administrador' || lower === 'administradora' || lower === '0') {
      continue
    }
    set.add(trimmed)
  }
  return Array.from(set).sort((a, b) => a.localeCompare(b, 'pt-BR', { numeric: true, sensitivity: 'base' }))
}

/**
 * Filtra apartamentos residenciais, removendo valores técnicos como 'Admin', 'Administrador', '0', etc.
 */
export function filterResidentialAptos(aptos: (string | null | undefined)[]): string[] {
  const set = new Set<string>()
  for (const a of aptos) {
    if (!a) continue
    const trimmed = a.trim()
    if (!trimmed) continue
    const lower = trimmed.toLowerCase()
    if (lower === 'admin' || lower === 'administrador' || lower === 'administradora' || lower === '0') {
      continue
    }
    set.add(trimmed)
  }
  return Array.from(set).sort((a, b) => a.localeCompare(b, 'pt-BR', { numeric: true, sensitivity: 'base' }))
}

export interface FormatUnitDisplayOptions {
  bloco?: string | null
  apto?: string | null
  role?: string | null
  tipoEstrutura?: string | null
  fallback?: string
  hideIfAdmin?: boolean
  separator?: string
  includeLabels?: boolean
}

/**
 * Formata a exibição de unidade residencial de forma segura, garantindo que
 * identidades técnicas de Administrador NUNCA sejam exibidas como unidade residencial
 * (ex: 'Bloco Admin', 'Apto Admin', 'Admin / Admin', 'Admin - Admin', 'Unidade Admin').
 */
export function formatUnitDisplay({
  bloco,
  apto,
  role,
  tipoEstrutura,
  fallback = 'Não aplicável (Administrativo)',
  hideIfAdmin = false,
  separator = ' · ',
  includeLabels = true,
}: FormatUnitDisplayOptions): string {
  if (isTechnicalAdminRole(role) || isTechnicalAdminUnit(bloco, apto)) {
    return hideIfAdmin ? '' : fallback
  }

  const b = bloco?.trim()
  const a = apto?.trim()

  if (!b && !a) return ''

  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)

  if (b && a) {
    if (includeLabels) {
      return `${blocoLabel} ${b}${separator}${aptoLabel} ${a}`
    }
    return `${b}${separator}${a}`
  }

  if (b) {
    return includeLabels ? `${blocoLabel} ${b}` : b
  }

  return includeLabels ? `${aptoLabel} ${a}` : (a || '')
}

