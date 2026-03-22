'use client'

import { useState, useTransition } from 'react'
import { Save, CheckSquare, Square, ChevronDown } from 'lucide-react'

// ─── Master function catalog ─────────────────────────────────────
const ALL_FUNCTIONS = [
  { id: 'authorize_visitor', label: 'Autorizar Visitante',     icon: 'how_to_reg',    emoji: '🔑', route: '/invitation-generator',       defaultRoles: ['morador'] },
  { id: 'parcels',           label: 'Minhas Encomendas',       icon: 'inventory_2',   emoji: '📦', route: '/parcel-dashboard',            defaultRoles: ['morador'] },
  { id: 'guest_checkin',     label: 'Visitante c/ Autorização',icon: 'qr_code',       emoji: '📷', route: '/guest-checkin',               defaultRoles: ['morador', 'portaria'] },
  { id: 'occurrences',       label: 'Ocorrências',             icon: 'warning',       emoji: '⚠️', route: '/report-occurrence',           defaultRoles: ['morador'] },
  { id: 'bookings',          label: 'Reservas',                icon: 'calendar_month',emoji: '📅', route: '/area-booking',                defaultRoles: ['morador'] },
  { id: 'documents',         label: 'Documentos',              icon: 'file_copy',     emoji: '📄', route: '/document-center',             defaultRoles: ['morador'] },
  { id: 'contracts',         label: 'Contratos',               icon: 'description',   emoji: '📋', route: '/contratos',                    defaultRoles: ['morador'] },
  { id: 'avisos',            label: 'Avisos',                  icon: 'campaign',      emoji: '📢', route: '/avisos',                      defaultRoles: ['morador'] },
  { id: 'enquetes',          label: 'Enquetes',                icon: 'bar_chart',     emoji: '📊', route: '/enquetes',                    defaultRoles: ['morador'] },
  { id: 'visitor_approval',  label: 'Liberar Visitante Cadastrado', icon: 'check_circle',  emoji: '✅', route: '/portaria-visitor-approval',   defaultRoles: ['portaria'] },
  { id: 'pending_del',       label: 'Encomendas do Cond.',      icon: 'local_shipping',emoji: '🚚', route: '/pending-deliveries',          defaultRoles: ['portaria', 'sindico'] },
  { id: 'approvals',         label: 'Aprovações',              icon: 'check_circle',  emoji: '✔️', route: '/manager-approval',            defaultRoles: ['sindico'] },
  { id: 'resident_search',   label: 'Busca Moradores',         icon: 'person_search', emoji: '🔍', route: '/resident-search',             defaultRoles: ['sindico'] },
  { id: 'condo_structure',   label: 'Estrutura do Condomínio', icon: 'apartment',     emoji: '🏢', route: '/condo-structure',             defaultRoles: ['sindico'] },
  { id: 'assemblies',        label: 'Assembleias',             icon: 'groups',        emoji: '👥', route: '/assemblies',                  defaultRoles: ['sindico'] },
  { id: 'fale_sindico',      label: 'Fale com o Síndico',      icon: 'forum',         emoji: '💬', route: '/fale-sindico',                defaultRoles: ['morador'] },
  { id: 'registro_turno',   label: 'Registro de Turno',       icon: 'assignment',    emoji: '📝', route: '/registro-turno',             defaultRoles: ['portaria'] },
  { id: 'visitor_register', label: 'Registrar Visitante',     icon: 'badge',         emoji: '🪪', route: '/registrar-visitante',       defaultRoles: ['portaria'] },
  { id: 'portaria_authorize', label: 'Autorização Visitante (Portaria)', icon: 'how_to_reg', emoji: '🛂', route: '/autorizar-visitante-portaria', defaultRoles: ['portaria', 'sindico', 'sub_sindico'] },
  { id: 'reservas_portaria', label: 'Reservas (Portaria)', icon: 'calendar_month', emoji: '📅', route: '/reservas-portaria', defaultRoles: ['portaria', 'sindico', 'sub_sindico'] },
]

// Normalize role name → key: "Porteiro (a)" → "portaria"
function normalizeRole(raw: string): string {
  const key = raw.toLowerCase().replace(/\s*\(.*?\)/g, '').replace(/[^a-záàéíóúãõâêôç]/g, '_').replace(/_+/g, '_').replace(/^_|_$/g, '').trim()
  const aliases: Record<string, string> = {
    porteiro: 'portaria',
    sindico: 'sindico', 'síndico': 'sindico',
    sub_sindico: 'sub_sindico', 'sub_síndico': 'sub_sindico',
    admin: 'admin', zelador: 'zelador',
    funcionario: 'funcionario', 'funcionário': 'funcionario',
    morador: 'morador',
    proprietario: 'proprietario', 'proprietário': 'proprietario',
    'proprietário_não_morador': 'proprietario_nao_morador',
    'proprietario_não_morador': 'proprietario_nao_morador',
    proprietario_nao_morador: 'proprietario_nao_morador',
    inquilino: 'inquilino',
    locatario: 'locatario', 'locatário': 'locatario',
    locador: 'locador', afiliado: 'afiliado', terceirizado: 'terceirizado',
    financeiro: 'financeiro', servicos: 'servicos', 'serviços': 'servicos',
  }
  return aliases[key] ?? key
}

// ─── Types ────────────────────────────────────────────────────────
interface RoleDef { key: string; label: string }
interface FuncConfig {
  id: string
  roles: Record<string, { visible: boolean }>
}

interface Props {
  initialConfig: Record<string, unknown>
  condominioId: string
  dbRoles: string[]   // raw papel_sistema values from perfil
}

export default function ConfigurarAcessoClient({ initialConfig, condominioId, dbRoles }: Props) {
  // Build role list — complete list of all possible profiles
  const roleMap: Record<string, RoleDef> = {
    morador:                 { key: 'morador',                 label: 'Morador (a)' },
    proprietario:            { key: 'proprietario',            label: 'Proprietário (a)' },
    proprietario_nao_morador:{ key: 'proprietario_nao_morador', label: 'Proprietário não morador' },
    inquilino:               { key: 'inquilino',               label: 'Inquilino (a)' },
    locatario:               { key: 'locatario',               label: 'Locatário (a)' },
    funcionario:             { key: 'funcionario',             label: 'Funcionário (a)' },
    portaria:                { key: 'portaria',                label: 'Porteiro (a)' },
    zelador:                 { key: 'zelador',                 label: 'Zelador (a)' },
    sindico:                 { key: 'sindico',                 label: 'Síndico (a)' },
    sub_sindico:             { key: 'sub_sindico',             label: 'Sub Síndico (a)' },
  }
  for (const raw of dbRoles) {
    const key = normalizeRole(raw)
    if (!roleMap[key]) roleMap[key] = { key, label: raw }
  }
  const roles = Object.values(roleMap)

  // Build initial function configs
  const savedFunctions = (initialConfig?.functions as unknown[] ?? []) as Array<{
    id: string
    order?: number
    roles?: Record<string, { visible?: boolean }>
  }>
  const savedMap: Record<string, typeof savedFunctions[0]> = {}
  for (const f of savedFunctions) savedMap[f.id] = f

  const [functions, setFunctions] = useState<FuncConfig[]>(() =>
    ALL_FUNCTIONS.map(def => {
      const saved = savedMap[def.id]
      const roleConfig: Record<string, { visible: boolean }> = {}
      for (const role of roles) {
        const savedRole = saved?.roles?.[role.key]
        roleConfig[role.key] = {
          visible: savedRole ? (savedRole.visible ?? false) : def.defaultRoles.includes(role.key),
        }
      }
      return { id: def.id, roles: roleConfig }
    })
  )

  const [isPending, startTransition] = useTransition()
  const [saved, setSaved] = useState(false)

  function toggle(fnIndex: number, roleKey: string) {
    setFunctions(prev => {
      const next = [...prev]
      const fn = { ...next[fnIndex], roles: { ...next[fnIndex].roles } }
      fn.roles[roleKey] = { visible: !fn.roles[roleKey]?.visible }
      next[fnIndex] = fn
      return next
    })
    setSaved(false)
  }

  async function handleSave() {
    startTransition(async () => {
      const functionsJson = functions.map((fn, i) => {
        const def = ALL_FUNCTIONS[i]
        // Preserve existing order from saved config so 'Configurar Ordem' values are not lost
        const existingOrder = savedMap[fn.id]?.order as number | undefined
        return { id: fn.id, icon: def.icon, label: def.label, route: def.route, roles: fn.roles, ...(existingOrder !== undefined ? { order: existingOrder } : {}) }
      })
      // Merge with existing config (preserve order)
      const merged = {
        ...initialConfig,
        functions: functionsJson,
        resident_menu: buildLegacy(functions, ['morador', 'proprietario', 'proprietario_nao_morador', 'inquilino', 'locatario']),
        porter_menu:   buildLegacy(functions, ['portaria', 'funcionario', 'zelador']),
        admin_menu:    buildLegacy(functions, ['sindico', 'sub_sindico']),
      }
      await fetch('/api/admin/save-menu-config', {
        method: 'POST',
        body: JSON.stringify({ condominioId, config: merged }),
        headers: { 'Content-Type': 'application/json' },
      })
      setSaved(true)
    })
  }

  function buildLegacy(fns: FuncConfig[], roleKeys: string[]) {
    return fns
      .filter(fn => roleKeys.some(rk => fn.roles[rk]?.visible))
      .map(fn => {
        const def = ALL_FUNCTIONS.find(d => d.id === fn.id)!
        const order = (initialConfig?.functions as Array<{id:string,order?:number}>)
          ?.find(f => f.id === fn.id)?.order ?? 99
        return { id: fn.id, icon: def.icon, label: def.label, route: def.route, visible: true, order }
      })
  }

  return (
    <div>
      {/* Header */}
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Configurar Acesso</h1>
          <p className="text-gray-500 text-sm mt-1">
            Configure quais perfis podem ver cada função no app.
          </p>
        </div>
        <button
          onClick={handleSave}
          disabled={isPending}
          className="flex items-center gap-2 bg-[#FC5931] text-white px-5 py-2.5 rounded-xl font-semibold text-sm hover:bg-[#D42F1D] transition-colors disabled:opacity-60"
        >
          <Save size={16} />
          {isPending ? 'Salvando…' : saved ? '✅ Salvo!' : 'Salvar alterações'}
        </button>
      </div>

      {/* Matrix table */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100">
              <th className="text-left px-5 py-3 font-semibold text-gray-700 w-48 min-w-[180px]">Função</th>
              {roles.map(r => (
                <th key={r.key} className="px-2 py-3 text-center font-medium text-gray-500 text-xs min-w-[90px]">
                  {r.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {ALL_FUNCTIONS.map((def, fnIndex) => {
              const fn = functions[fnIndex]
              if (!fn) return null
              const anyChecked = roles.some(r => fn.roles[r.key]?.visible)
              return (
                <tr key={def.id} className={`border-b border-gray-50 hover:bg-gray-50 transition-colors ${!anyChecked ? 'opacity-50' : ''}`}>
                  <td className="px-5 py-3 font-medium text-gray-800">
                    <span className="mr-2">{def.emoji}</span>{def.label}
                  </td>
                  {roles.map(role => {
                    const checked = fn.roles[role.key]?.visible ?? false
                    return (
                      <td key={role.key} className="px-2 py-3 text-center">
                        <button
                          onClick={() => toggle(fnIndex, role.key)}
                          className="inline-flex items-center justify-center w-7 h-7 rounded-lg hover:bg-gray-100 transition-colors"
                        >
                          {checked
                            ? <CheckSquare size={20} className="text-[#FC5931]" />
                            : <Square size={20} className="text-gray-300" />}
                        </button>
                      </td>
                    )
                  })}
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      <p className="mt-4 text-xs text-gray-400 text-center">
        Linhas acinzentadas indicam funções sem nenhum perfil com acesso.
      </p>
    </div>
  )
}
