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
  { id: 'parcel_history',    label: 'Histórico Encomendas',    icon: 'history',       emoji: '🕓', route: '/parcel-history',              defaultRoles: ['morador'] },
  { id: 'avisos',            label: 'Avisos',                  icon: 'campaign',      emoji: '📢', route: '/avisos',                      defaultRoles: ['morador'] },
  { id: 'visitor_approval',  label: 'Liberar Visitante',       icon: 'check_circle',  emoji: '✅', route: '/portaria-visitor-approval',   defaultRoles: ['portaria'] },
  { id: 'parcel_reg',        label: 'Registrar Encomenda',     icon: 'add_box',       emoji: '➕', route: '/parcel-registration',         defaultRoles: ['portaria'] },
  { id: 'pending_del',       label: 'Entregas Pendentes',      icon: 'local_shipping',emoji: '🚚', route: '/pending-deliveries',          defaultRoles: ['portaria'] },
  { id: 'approvals',         label: 'Aprovações',              icon: 'check_circle',  emoji: '✔️', route: '/manager-approval',            defaultRoles: ['sindico'] },
  { id: 'resident_search',   label: 'Busca Moradores',         icon: 'person_search', emoji: '🔍', route: '/resident-search',             defaultRoles: ['sindico'] },
  { id: 'condo_structure',   label: 'Estrutura do Condomínio', icon: 'apartment',     emoji: '🏢', route: '/condo-structure',             defaultRoles: ['sindico'] },
  { id: 'assemblies',        label: 'Assembleias',             icon: 'groups',        emoji: '👥', route: '/assemblies',                  defaultRoles: ['sindico'] },
]

// Normalize role name → key: "Porteiro (a)" → "portaria"
function normalizeRole(raw: string): string {
  const key = raw.toLowerCase().replace(/\s*\(.*?\)/g, '').replace(/[^a-záàéíóúãõâêôç]/g, '_').trim()
  const aliases: Record<string, string> = {
    porteiro: 'portaria', sindico: 'sindico', 'síndico': 'sindico',
    sub_sindico: 'sub_sindico', 'sub_síndico': 'sub_sindico',
    admin: 'admin', zelador: 'zelador', funcionario: 'funcionario',
    'funcionário': 'funcionario', locatario: 'locatario', 'locatário': 'locatario',
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
  // Build role list
  const roleMap: Record<string, RoleDef> = {
    morador:  { key: 'morador',  label: 'Morador' },
    portaria: { key: 'portaria', label: 'Portaria' },
    sindico:  { key: 'sindico',  label: 'Síndico' },
  }
  for (const raw of dbRoles) {
    const key = normalizeRole(raw)
    roleMap[key] = { key, label: raw }
  }
  const roles = Object.values(roleMap)

  // Build initial function configs
  const savedFunctions = (initialConfig?.functions as unknown[] ?? []) as Array<{
    id: string
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
        return { id: fn.id, icon: def.icon, label: def.label, route: def.route, roles: fn.roles }
      })
      // Merge with existing config (preserve order)
      const merged = {
        ...initialConfig,
        functions: functionsJson,
        resident_menu: buildLegacy(functions, ['morador']),
        porter_menu:   buildLegacy(functions, ['portaria', 'porteiro']),
        admin_menu:    buildLegacy(functions, ['sindico', 'admin']),
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
          className="flex items-center gap-2 bg-[#E85D26] text-white px-5 py-2.5 rounded-xl font-semibold text-sm hover:bg-[#c94e1f] transition-colors disabled:opacity-60"
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
                            ? <CheckSquare size={20} className="text-[#E85D26]" />
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
