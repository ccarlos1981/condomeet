/**
 * Helpers canônicos para papéis de sistema (papel_sistema) e permissões.
 *
 * REGRA CANÔNICA CONDOMEET:
 * - Valor Técnico de Banco: 'Admin'
 * - Rótulo Visual: 'Administrador'
 * - Chave de features_config: 'admin'
 */

/**
 * Valida de forma canônica se um papel (papel_sistema) possui privilégios administrativos no condomínio.
 *
 * Papéis com acesso administrativo:
 * - Admin ('Admin', 'admin', 'ADMIN', 'administrador', 'administradora')
 * - Síndico ('síndico', 'sindico', 'síndico (a)', 'sindico (a)', 'síndico(a)', 'sindico(a)')
 * - Subsíndico ('subsíndico', 'subsindico', 'subsíndico (a)', 'subsindico (a)', 'sub_sindico')
 *
 * Rejeita expressamente:
 * - Porteiro / Portaria
 * - Zelador
 * - Morador / Inquilino / Locatário / Proprietário
 */
export function isAdminRole(role?: string | null): boolean {
  if (!role) return false
  const r = role.trim().toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
  if (!r) return false

  // Bloqueio preventivo de papéis não-administrativos
  if (
    r.startsWith('morador') ||
    r.startsWith('inquilino') ||
    r.startsWith('locat') ||
    r.startsWith('propriet') ||
    r.startsWith('visit') ||
    r.startsWith('porteir') ||
    r.startsWith('portaria') ||
    r.startsWith('zelador') ||
    r.startsWith('limpeza') ||
    r.startsWith('funcionario')
  ) {
    return false
  }

  // Whitelist de papéis administrativos
  return (
    r === 'admin' ||
    r === 'administrador' ||
    r === 'administradora' ||
    r === 'superadmin' ||
    r === 'super_admin' ||
    r === 'master' ||
    r.includes('sindico')
  )
}

/**
 * Valida se um papel possui nível Master/SuperAdmin no sistema (privilégio global da plataforma).
 * NOTA: Administradores de condomínio (Admin) possuem gestão local completa, mas NÃO são SuperAdmins globais.
 */
export function isMasterRole(role?: string | null): boolean {
  if (!role) return false
  const r = role.trim().toLowerCase()
  return ['superadmin', 'super_admin', 'master'].includes(r)
}

/**
 * Valida se um papel é de Portaria / Porteiro.
 */
export function isPorterRole(role?: string | null): boolean {
  if (!role) return false
  const r = role.trim().toLowerCase()
  return r.includes('portaria') || r.includes('porteiro')
}

/**
 * Retorna o rótulo visual oficial para exibição na interface.
 * Ex: 'Admin' -> 'Administrador'
 */
export function formatRoleName(role?: string | null): string {
  if (!role) return 'Morador'
  const r = role.trim()
  if (r.toLowerCase() === 'admin') return 'Administrador'
  return r
}

/**
 * Normaliza o papel_sistema para a chave técnica utilizada no features_config dos condomínios.
 */
export function normalizeRoleKey(role?: string | null): string {
  if (!role) return 'morador'
  const r = role.trim().toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')

  if (r === 'admin' || r === 'administrador' || r === 'administradora') return 'admin'
  if (r.includes('sindico') && !r.includes('sub')) return 'sindico'
  if (r.includes('sub') && r.includes('sindico')) return 'sub_sindico'
  if (r.includes('porteir') || r.includes('portaria')) return 'portaria'
  if (r.includes('zelador')) return 'zelador'
  if (r.includes('inquilino')) return 'inquilino'
  if (r.includes('locat')) return 'locatario'
  if (r.includes('propriet') && r.includes('nao')) return 'proprietario_nao_morador'
  if (r.includes('propriet')) return 'proprietario'
  if (r.includes('funcionar')) return 'funcionario'

  return r.replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_').replace(/^_|_$/g, '') || 'morador'
}
