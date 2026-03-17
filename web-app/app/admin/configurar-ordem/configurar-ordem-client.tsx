'use client'

import { useState, useTransition } from 'react'
import { Save } from 'lucide-react'

// Display catalog — only used for labels/emojis
const FUNCTION_CATALOG: Record<string, { label: string; emoji: string }> = {
  authorize_visitor:  { label: 'Autorizar Visitante',      emoji: '🔑' },
  parcels:            { label: 'Minhas Encomendas',        emoji: '📦' },
  guest_checkin:      { label: 'Visitante c/ Autorização', emoji: '📷' },
  occurrences:        { label: 'Ocorrências',              emoji: '⚠️' },
  bookings:           { label: 'Reservas',                 emoji: '📅' },
  documents:          { label: 'Documentos',               emoji: '📄' },
  contracts:          { label: 'Contratos',                emoji: '📋' },
  parcel_history:     { label: 'Histórico Encomendas',     emoji: '🕓' },
  visitor_approval:   { label: 'Liberar Visitante',        emoji: '✅' },
  parcel_reg:         { label: 'Registrar Encomenda',      emoji: '➕' },
  pending_del:        { label: 'Encomendas',               emoji: '🚚' },
  approvals:          { label: 'Aprovações',               emoji: '✔️' },
  resident_search:    { label: 'Busca Moradores',          emoji: '🔍' },
  condo_structure:    { label: 'Estrutura do Condomínio',  emoji: '🏢' },
  assemblies:         { label: 'Assembleias',              emoji: '👥' },
  avisos:             { label: 'Avisos',                   emoji: '📢' },
  enquetes:           { label: 'Enquetes',                 emoji: '📊' },
  fale_sindico:       { label: 'Fale com o Síndico',       emoji: '💬' },
  registro_turno:     { label: 'Registro de Turno',        emoji: '📝' },
  visitor_register:   { label: 'Registrar Visitante',      emoji: '🪪' },
  enquete_admin:      { label: 'Enquetes (Admin)',         emoji: '📊' },
  botconversa_send:   { label: 'Enviar WhatsApp',          emoji: '📱' },
  chat:               { label: 'Chat Oficial',             emoji: '💬' },
}

interface FnData {
  id: string
  order?: number
  [key: string]: unknown
}

interface Props {
  initialConfig: Record<string, unknown>
  condominioId: string
}

export default function ConfigurarOrdemClient({ initialConfig, condominioId }: Props) {
  // Build function list from DB config (preserves all fields including roles)
  const savedFns = (initialConfig?.functions as FnData[]) ?? []

  const [orders, setOrders] = useState<Record<string, number>>(() => {
    const m: Record<string, number> = {}
    for (const f of savedFns) {
      m[f.id] = typeof f.order === 'number' ? f.order : 99
    }
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
      // Helper: update order in any legacy menu array
      function applyOrderToMenu(menu: unknown) {
        if (!Array.isArray(menu)) return menu
        return menu.map((item: Record<string, unknown>) => ({
          ...item,
          order: orders[item.id as string] ?? (item.order as number) ?? 99,
        }))
      }

      // IMPORTANT: preserve ALL existing function data (roles, route, label, etc.)
      // Only update the 'order' field
      const updatedFunctions = savedFns.map(fn => ({
        ...fn,
        order: orders[fn.id] ?? 99,
      }))

      const merged = {
        ...initialConfig,
        functions: updatedFunctions,
        // Also update order inside legacy menu arrays
        resident_menu: applyOrderToMenu(initialConfig?.resident_menu),
        porter_menu:   applyOrderToMenu(initialConfig?.porter_menu),
        admin_menu:    applyOrderToMenu(initialConfig?.admin_menu),
      }

      const res = await fetch('/api/admin/save-menu-config', {
        method: 'POST',
        body: JSON.stringify({ condominioId, config: merged }),
        headers: { 'Content-Type': 'application/json' },
      })
      if (res.ok) {
        setSaved(true)
      }
    })
  }

  // Sort by current order for display
  const sortedFunctions = [...savedFns].sort((a, b) => (orders[a.id] ?? 99) - (orders[b.id] ?? 99))

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
          className="flex items-center gap-2 bg-[#FC5931] text-white px-5 py-2.5 rounded-xl font-semibold text-sm hover:bg-[#D42F1D] transition-colors disabled:opacity-60"
        >
          <Save size={16} />
          {isPending ? 'Salvando…' : saved ? '✅ Salvo!' : 'Salvar alterações'}
        </button>
      </div>

      {/* 2-column grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {sortedFunctions.map(fn => {
          const catalog = FUNCTION_CATALOG[fn.id]
          const label = (fn.label as string) ?? catalog?.label ?? fn.id
          const emoji = catalog?.emoji ?? '⚙️'
          const orderVal = orders[fn.id]

          return (
            <div
              key={fn.id}
              className="bg-white rounded-xl border border-gray-100 shadow-sm px-5 py-4 flex items-center gap-4"
            >
              {/* Icon + Label */}
              <div className="flex-1 min-w-0">
                <span className="mr-2 text-base">{emoji}</span>
                <span className="font-medium text-gray-800 text-sm">{label}</span>
              </div>
              {/* Order input */}
              <input
                type="number"
                min={1}
                value={orderVal === 99 ? '' : orderVal}
                placeholder="—"
                onChange={e => handleChange(fn.id, e.target.value)}
                aria-label={`Ordem de ${label}`}
                className="w-16 text-center text-base font-bold text-gray-700 border border-gray-200 rounded-lg py-1.5 px-1 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-gray-50"
              />
            </div>
          )
        })}
      </div>

      <p className="mt-4 text-xs text-gray-400 text-center">
        A ordem é única por condomínio — vale para todos os perfis que têm acesso a cada função.
        A lista se reorganiza ao salvar.
      </p>
    </div>
  )
}
