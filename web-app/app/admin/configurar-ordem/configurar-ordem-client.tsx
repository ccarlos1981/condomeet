'use client'

import { useState, useTransition } from 'react'
import { Save } from 'lucide-react'

const ALL_FUNCTIONS = [
  { id: 'authorize_visitor', label: 'Autorizar Visitante',     icon: 'how_to_reg',    emoji: '🔑' },
  { id: 'parcels',           label: 'Minhas Encomendas',       icon: 'inventory_2',   emoji: '📦' },
  { id: 'guest_checkin',     label: 'Visitante c/ Autorização',icon: 'qr_code',       emoji: '📷' },
  { id: 'occurrences',       label: 'Ocorrências',             icon: 'warning',       emoji: '⚠️' },
  { id: 'bookings',          label: 'Reservas',                icon: 'calendar_month',emoji: '📅' },
  { id: 'documents',         label: 'Documentos',              icon: 'file_copy',     emoji: '📄' },
  { id: 'parcel_history',    label: 'Histórico Encomendas',    icon: 'history',       emoji: '🕓' },
  { id: 'visitor_approval',  label: 'Liberar Visitante',       icon: 'check_circle',  emoji: '✅' },
  { id: 'parcel_reg',        label: 'Registrar Encomenda',     icon: 'add_box',       emoji: '➕' },
  { id: 'pending_del',       label: 'Entregas Pendentes',      icon: 'local_shipping',emoji: '🚚' },
  { id: 'approvals',         label: 'Aprovações',              icon: 'check_circle',  emoji: '✔️' },
  { id: 'resident_search',   label: 'Busca Moradores',         icon: 'person_search', emoji: '🔍' },
  { id: 'condo_structure',   label: 'Estrutura do Condomínio', icon: 'apartment',     emoji: '🏢' },
  { id: 'assemblies',        label: 'Assembleias',             icon: 'groups',        emoji: '👥' },
]

interface Props {
  initialConfig: Record<string, unknown>
  condominioId: string
}

export default function ConfigurarOrdemClient({ initialConfig, condominioId }: Props) {
  // Extract existing orders from config
  const savedFns = (initialConfig?.functions as Array<{ id: string; order?: number }>) ?? []
  const savedOrderMap: Record<string, number> = {}
  for (const f of savedFns) savedOrderMap[f.id] = f.order ?? 99

  const [orders, setOrders] = useState<Record<string, number>>(() => {
    const m: Record<string, number> = {}
    for (const def of ALL_FUNCTIONS) m[def.id] = savedOrderMap[def.id] ?? 99
    return m
  })

  const [isPending, startTransition] = useTransition()
  const [saved, setSaved] = useState(false)

  function handleChange(id: string, value: string) {
    const n = parseInt(value, 10)
    setOrders(prev => ({ ...prev, [id]: isNaN(n) ? 99 : n }))
    setSaved(false)
  }

  async function handleSave() {
    startTransition(async () => {
      // Helper: update order in any menu array (resident_menu, porter_menu, admin_menu)
      function applyOrderToMenu(menu: unknown) {
        if (!Array.isArray(menu)) return menu
        return menu.map((item: Record<string, unknown>) => ({
          ...item,
          order: orders[item.id as string] ?? (item.order as number) ?? 99,
        }))
      }

      // Merge order into functions array
      const existingFns = (initialConfig?.functions as Array<Record<string, unknown>>) ?? []
      const existingMap: Record<string, Record<string, unknown>> = {}
      for (const f of existingFns) existingMap[f.id as string] = f

      const merged = {
        ...initialConfig,
        functions: ALL_FUNCTIONS.map(def => ({
          ...(existingMap[def.id] ?? { id: def.id }),
          order: orders[def.id] ?? 99,
        })),
        // Also update order inside the menu arrays that the mobile reads
        resident_menu: applyOrderToMenu(initialConfig?.resident_menu),
        porter_menu:   applyOrderToMenu(initialConfig?.porter_menu),
        admin_menu:    applyOrderToMenu(initialConfig?.admin_menu),
      }

      await fetch('/api/admin/save-menu-config', {
        method: 'POST',
        body: JSON.stringify({ condominioId, config: merged }),
        headers: { 'Content-Type': 'application/json' },
      })
      setSaved(true)
    })
  }

  // Sort by current order for display
  const sortedFunctions = [...ALL_FUNCTIONS].sort((a, b) => (orders[a.id] ?? 99) - (orders[b.id] ?? 99))

  return (
    <div>
      {/* Header */}
      <div className="mb-6 flex items-center justify-between flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Configurar Ordem</h1>
          <p className="text-gray-500 text-sm mt-1">
            Defina a posição de cada botão no app. Menor número = aparece primeiro.
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

      {/* 2-column grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {sortedFunctions.map(def => (
          <div
            key={def.id}
            className="bg-white rounded-xl border border-gray-100 shadow-sm px-5 py-4 flex items-center gap-4"
          >
            {/* Icon + Label */}
            <div className="flex-1 min-w-0">
              <span className="mr-2 text-base">{def.emoji}</span>
              <span className="font-medium text-gray-800 text-sm">{def.label}</span>
            </div>
            {/* Order input */}
            <input
              type="number"
              min={1}
              value={orders[def.id] === 99 ? '' : orders[def.id]}
              placeholder="—"
              onChange={e => handleChange(def.id, e.target.value)}
              className="w-16 text-center text-base font-bold text-gray-700 border border-gray-200 rounded-lg py-1.5 px-1 focus:outline-none focus:ring-2 focus:ring-[#E85D26]/30 focus:border-[#E85D26] bg-gray-50"
            />
          </div>
        ))}
      </div>

      <p className="mt-4 text-xs text-gray-400 text-center">
        A ordem é única por condomínio — vale para todos os perfis que têm acesso a cada função.
        A lista se reorganiza ao salvar.
      </p>
    </div>
  )
}
