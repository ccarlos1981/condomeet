'use client'

import { useState } from 'react'
import {
  ClipboardList,
  Check,
  X,
  Ban,
  CalendarDays,
  List,
  ChevronLeft,
  ChevronRight,
  FilterX,
  User,
  Clock,
  Building,
  Info,
} from 'lucide-react'
import { getBlocoLabel, getAptoLabel, formatUnitDisplay } from '@/lib/labels'
import type { AreaItem, ReservaRow } from './page'

// ──────────────────────────────────────────────────────────────────────────────
// Deterministic Color Palette for Common Areas
// ──────────────────────────────────────────────────────────────────────────────
export const AREA_PALETTE = [
  '#FC5931', // Condomeet Coral/Orange
  '#10B981', // Emerald
  '#3B82F6', // Blue
  '#8B5CF6', // Purple
  '#F59E0B', // Amber
  '#EC4899', // Pink
  '#06B6D4', // Cyan
  '#6366F1', // Indigo
]

export function getAreaColor(areaIdOrName: string): string {
  if (!areaIdOrName) return AREA_PALETTE[0]
  let hash = 0
  for (let i = 0; i < areaIdOrName.length; i++) {
    hash = (hash << 5) - hash + areaIdOrName.charCodeAt(i)
    hash |= 0
  }
  const index = Math.abs(hash) % AREA_PALETTE.length
  return AREA_PALETTE[index]
}

const MESES = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
]
const DIAS_SEMANA = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']

const formatCurrency = (val: number) => {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
}

interface Props {
  reservas: ReservaRow[]
  areas: AreaItem[]
  blocos: string[]
  aptosPorBloco: Record<string, string[]>
  todosAptos: string[]
  tipoEstrutura?: string
}

export default function ReservasAdminClient({
  reservas: initial,
  areas,
  blocos,
  aptosPorBloco,
  todosAptos,
  tipoEstrutura,
}: Props) {
  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)

  // Data & view state
  const [reservas, setReservas] = useState<ReservaRow[]>(initial)
  const [viewMode, setViewMode] = useState<'list' | 'calendar'>('list')
  const [updating, setUpdating] = useState<string | null>(null)
  const [cancelConfirm, setCancelConfirm] = useState<string | null>(null)

  // Filters state (shared between List and Calendar)
  const [filterAreaId, setFilterAreaId] = useState<string>('')
  const [filterBloco, setFilterBloco] = useState<string>('')
  const [filterApto, setFilterApto] = useState<string>('')
  const [filterStatus, setFilterStatus] = useState<'pendente' | 'aprovado' | ''>('pendente')

  // Calendar navigation state
  const today = new Date()
  const [calYear, setCalYear] = useState<number>(today.getFullYear())
  const [calMonth, setCalMonth] = useState<number>(today.getMonth())
  const [selectedDayIso, setSelectedDayIso] = useState<string | null>(null)
  const [dayModalOpen, setDayModalOpen] = useState<boolean>(false)

  // Derived apartments list based on selected block
  const availableAptos = filterBloco ? (aptosPorBloco[filterBloco] ?? []) : todosAptos

  const handleBlocoChange = (newBloco: string) => {
    setFilterBloco(newBloco)
    if (newBloco) {
      const allowedAptos = aptosPorBloco[newBloco] ?? []
      if (filterApto && !allowedAptos.includes(filterApto)) {
        setFilterApto('')
      }
    }
  }

  const handleClearFilters = () => {
    setFilterAreaId('')
    setFilterBloco('')
    setFilterApto('')
  }

  const hasActiveAdminFilters = Boolean(filterAreaId || filterBloco || filterApto)

  // Filtered reservations for List View
  const filteredList = reservas.filter(r => {
    const areaOk = !filterAreaId || r.area_id === filterAreaId || r.areas_comuns?.id === filterAreaId
    const blocoOk = !filterBloco || r.perfil?.bloco_txt === filterBloco
    const aptoOk = !filterApto || r.perfil?.apto_txt === filterApto
    const statusOk = !filterStatus || r.status === filterStatus
    return areaOk && blocoOk && aptoOk && statusOk
  })

  // Active reservations for Calendar View: only 'aprovado' and 'pendente'
  const calendarActiveReservas = reservas.filter(r => {
    const areaOk = !filterAreaId || r.area_id === filterAreaId || r.areas_comuns?.id === filterAreaId
    const blocoOk = !filterBloco || r.perfil?.bloco_txt === filterBloco
    const aptoOk = !filterApto || r.perfil?.apto_txt === filterApto
    const statusOk = r.status === 'aprovado' || r.status === 'pendente'
    return areaOk && blocoOk && aptoOk && statusOk
  })

  // Month navigation handlers
  const prevMonth = () => {
    if (calMonth === 0) {
      setCalYear(y => y - 1)
      setCalMonth(11)
    } else {
      setCalMonth(m => m - 1)
    }
  }

  const nextMonth = () => {
    if (calMonth === 11) {
      setCalYear(y => y + 1)
      setCalMonth(0)
    } else {
      setCalMonth(m => m + 1)
    }
  }

  const goToToday = () => {
    const t = new Date()
    setCalYear(t.getFullYear())
    setCalMonth(t.getMonth())
  }

  // Calculate calendar grid for current month
  const firstDay = new Date(calYear, calMonth, 1)
  const lastDay = new Date(calYear, calMonth + 1, 0)
  const startDow = firstDay.getDay()
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

  const cells: (number | null)[] = []
  for (let i = 0; i < startDow; i++) cells.push(null)
  for (let d = 1; d <= lastDay.getDate(); d++) cells.push(d)

  function toIso(day: number) {
    return `${calYear}-${String(calMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
  }

  // Group active reservations by ISO date for calendar
  const currentMonthPrefix = `${calYear}-${String(calMonth + 1).padStart(2, '0')}`
  const monthReservas = calendarActiveReservas.filter(r => r.data_reserva?.startsWith(currentMonthPrefix))

  const reservasByDate: Record<string, ReservaRow[]> = {}
  for (const r of monthReservas) {
    if (!reservasByDate[r.data_reserva]) {
      reservasByDate[r.data_reserva] = []
    }
    reservasByDate[r.data_reserva].push(r)
  }

  // Areas with reservations in current month for legend
  const areasInMonthMap: Record<string, { id: string; nome: string; color: string }> = {}
  for (const r of monthReservas) {
    const areaId = r.areas_comuns?.id || r.area_id || 'unknown'
    const areaNome = r.areas_comuns?.tipo_agenda || 'Área Comum'
    if (!areasInMonthMap[areaId]) {
      areasInMonthMap[areaId] = {
        id: areaId,
        nome: areaNome,
        color: getAreaColor(areaId),
      }
    }
  }
  const areasInMonth = Object.values(areasInMonthMap)

  // Day click handler
  const handleDayClick = (iso: string) => {
    setSelectedDayIso(iso)
    setDayModalOpen(true)
  }

  const selectedDayReservations = selectedDayIso ? (reservasByDate[selectedDayIso] ?? []) : []

  // Status handlers
  async function setStatus(id: string, status: 'aprovado' | 'reprovado') {
    setUpdating(id)
    const res = await fetch('/api/reservas', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, status }),
    })
    if (res.ok) {
      setReservas(prev => prev.map(r => r.id === id ? { ...r, status } : r))
    }
    setUpdating(null)
  }

  async function cancelReserva(reserva: ReservaRow) {
    setUpdating(reserva.id)
    setCancelConfirm(null)

    try {
      const res = await fetch('/api/reservas/cancel', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reserva_id: reserva.id }),
      })

      if (res.ok) {
        setReservas(prev => prev.map(r => r.id === reserva.id ? { ...r, status: 'cancelado' } : r))
      }
    } catch (err) {
      console.error('Failed to cancel reservation:', err)
    }
    setUpdating(null)
  }

  const statusBadge = (s: string) => {
    const map: Record<string, string> = {
      pendente: 'bg-yellow-100 text-yellow-700',
      aprovado: 'bg-green-100 text-green-700',
      reprovado: 'bg-red-100 text-red-700',
      cancelado: 'bg-gray-100 text-gray-500',
    }
    return map[s] ?? 'bg-gray-100 text-gray-500'
  }

  const statusLabel = (s: string) => {
    const map: Record<string, string> = {
      pendente: 'Pendente',
      aprovado: 'Aprovado',
      reprovado: 'Reprovado',
      cancelado: 'Cancelado',
    }
    return map[s] ?? s
  }

  return (
    <div className="max-w-5xl">
      {/* Header with Title and View Toggle */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-[#FC5931]/10 flex items-center justify-center">
            <ClipboardList size={22} className="text-[#FC5931]" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Aprovar Reservas</h1>
            <p className="text-sm text-gray-500">Gerencie as solicitações e a agenda de reservas dos moradores.</p>
          </div>
        </div>

        {/* View Mode Toggle: Lista ↔ Calendário */}
        <div className="flex items-center bg-gray-100 p-1 rounded-xl border border-gray-200 self-start sm:self-auto">
          <button
            onClick={() => setViewMode('list')}
            className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-sm font-semibold transition-all ${
              viewMode === 'list'
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            <List size={16} className={viewMode === 'list' ? 'text-[#FC5931]' : 'text-gray-400'} />
            Tabela
          </button>
          <button
            onClick={() => setViewMode('calendar')}
            className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-sm font-semibold transition-all ${
              viewMode === 'calendar'
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            <CalendarDays size={16} className={viewMode === 'calendar' ? 'text-[#FC5931]' : 'text-gray-400'} />
            Calendário
          </button>
        </div>
      </div>

      {/* Filter Bar (Shared between List & Calendar) */}
      <div className="bg-white rounded-2xl border border-gray-100 p-4 mb-6 shadow-sm">
        <div className="flex flex-wrap items-center gap-3">
          {/* Filter 1: Área Comum */}
          <select
            value={filterAreaId}
            onChange={e => setFilterAreaId(e.target.value)}
            className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 font-medium"
          >
            <option value="">Todas as áreas</option>
            {areas.map(a => {
              const localSuffix = a.local && a.local !== 'area_comum' ? ` (${a.local})` : ''
              return (
                <option key={a.id} value={a.id}>
                  {a.tipo_agenda}{localSuffix}
                </option>
              )
            })}
          </select>

          {/* Filter 2: Bloco */}
          <select
            value={filterBloco}
            onChange={e => handleBlocoChange(e.target.value)}
            className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 font-medium"
          >
            <option value="">Todos os {blocoLabel}s</option>
            {blocos.map(b => (
              <option key={b} value={b}>
                {blocoLabel} {b}
              </option>
            ))}
          </select>

          {/* Filter 3: Apartamento */}
          <select
            value={filterApto}
            onChange={e => setFilterApto(e.target.value)}
            className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 font-medium"
          >
            <option value="">Todos os {aptoLabel}s</option>
            {availableAptos.map(a => (
              <option key={a} value={a}>
                {aptoLabel} {a}
              </option>
            ))}
          </select>

          {/* Clear Filters Action */}
          {hasActiveAdminFilters && (
            <button
              onClick={handleClearFilters}
              className="flex items-center gap-1.5 text-xs font-semibold text-gray-600 hover:text-red-600 bg-gray-50 hover:bg-red-50 border border-gray-200 hover:border-red-200 px-3 py-2 rounded-xl transition-colors"
              title="Remover filtros de Bloco, Apartamento e Área"
            >
              <FilterX size={14} />
              Limpar filtros
            </button>
          )}

          {/* Status Filter (Primary in List view) */}
          {viewMode === 'list' && (
            <div className="flex ml-auto rounded-xl border border-gray-200 overflow-hidden">
              {[
                { val: 'pendente', label: 'Pendentes' },
                { val: 'aprovado', label: 'Aprovados' },
                { val: '', label: 'Todos' },
              ].map(b => (
                <button
                  key={b.val}
                  onClick={() => setFilterStatus(b.val as typeof filterStatus)}
                  className={`px-3.5 py-1.5 text-xs font-semibold transition-colors ${
                    filterStatus === b.val
                      ? 'bg-[#FC5931] text-white'
                      : 'text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  {b.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ─────────────────────────────────────────────────────────────────── */}
      {/* VIEW: CALENDAR                                                      */}
      {/* ─────────────────────────────────────────────────────────────────── */}
      {viewMode === 'calendar' && (
        <div className="bg-white rounded-2xl border border-gray-100 p-6 shadow-sm mb-6">
          {/* Month Navigator */}
          <div className="flex items-center justify-between mb-6 pb-4 border-b border-gray-100">
            <div className="flex items-center gap-2">
              <button
                onClick={prevMonth}
                aria-label="Mês anterior"
                className="p-2 rounded-xl text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-colors"
              >
                <ChevronLeft size={20} />
              </button>
              <h2 className="text-lg font-bold text-gray-900 min-w-44 text-center">
                {MESES[calMonth]} de {calYear}
              </h2>
              <button
                onClick={nextMonth}
                aria-label="Próximo mês"
                className="p-2 rounded-xl text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-colors"
              >
                <ChevronRight size={20} />
              </button>
            </div>

            <div className="flex items-center gap-3">
              <button
                onClick={goToToday}
                className="text-xs font-bold text-[#FC5931] hover:text-white bg-[#FC5931]/10 hover:bg-[#FC5931] px-3 py-1.5 rounded-xl transition-all"
              >
                Hoje
              </button>
              <span className="text-xs text-gray-400 hidden sm:inline">
                {monthReservas.length} reserva{monthReservas.length !== 1 ? 's' : ''} no mês
              </span>
            </div>
          </div>

          {/* Weekday Header */}
          <div className="grid grid-cols-7 gap-2 mb-2">
            {DIAS_SEMANA.map(d => (
              <div key={d} className="text-center text-xs font-bold text-gray-400 py-1">
                {d}
              </div>
            ))}
          </div>

          {/* Calendar Day Grid */}
          <div className="grid grid-cols-7 gap-2">
            {cells.map((day, i) => {
              if (!day) return <div key={`empty-${i}`} className="min-h-20 bg-gray-50/40 rounded-xl" />

              const iso = toIso(day)
              const isToday = iso === todayStr
              const dayList = reservasByDate[iso] ?? []
              const hasReservas = dayList.length > 0

              return (
                <div
                  key={iso}
                  onClick={() => handleDayClick(iso)}
                  className={`min-h-20 p-2 rounded-xl border transition-all cursor-pointer flex flex-col justify-between ${
                    isToday
                      ? 'border-[#FC5931] bg-orange-50/20'
                      : hasReservas
                      ? 'border-gray-200 bg-white hover:border-[#FC5931]/50 hover:shadow-md'
                      : 'border-gray-100 bg-white hover:border-gray-200 hover:bg-gray-50/50'
                  }`}
                >
                  {/* Day number header */}
                  <div className="flex items-center justify-between">
                    <span
                      className={`text-xs font-bold px-1.5 py-0.5 rounded-md ${
                        isToday
                          ? 'bg-[#FC5931] text-white'
                          : 'text-gray-700'
                      }`}
                    >
                      {day}
                    </span>
                    {hasReservas && (
                      <span className="text-[10px] font-bold text-gray-400">
                        {dayList.length}
                      </span>
                    )}
                  </div>

                  {/* Colored Dots per Common Area */}
                  {hasReservas ? (
                    <div className="mt-1 flex flex-wrap gap-1 items-center">
                      {dayList.map((r, rIdx) => {
                        const areaId = r.areas_comuns?.id || r.area_id || 'unknown'
                        const dotColor = getAreaColor(areaId)
                        return (
                          <span
                            key={`${r.id}-${rIdx}`}
                            className="w-2.5 h-2.5 rounded-full inline-block ring-1 ring-white"
                            style={{ backgroundColor: dotColor }}
                            title={`${r.areas_comuns?.tipo_agenda ?? 'Área'} — ${r.perfil?.nome_completo ?? 'Morador'} (${r.status})`}
                          />
                        )
                      })}
                    </div>
                  ) : (
                    <div className="text-[10px] text-gray-300 select-none">Livre</div>
                  )}
                </div>
              )
            })}
          </div>

          {/* Compact Legend of Common Areas in the Month */}
          {areasInMonth.length > 0 ? (
            <div className="mt-6 pt-4 border-t border-gray-100">
              <div className="text-xs font-bold text-gray-500 mb-2">Áreas reservadas neste mês:</div>
              <div className="flex flex-wrap items-center gap-3">
                {areasInMonth.map(a => (
                  <div key={a.id} className="flex items-center gap-1.5 text-xs text-gray-700 font-medium">
                    <span
                      className="w-2.5 h-2.5 rounded-full inline-block"
                      style={{ backgroundColor: a.color }}
                    />
                    <span>{a.nome}</span>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="mt-6 pt-4 border-t border-gray-100 text-xs text-gray-400 text-center">
              Nenhuma reserva ativa para o mês e filtros selecionados.
            </div>
          )}
        </div>
      )}

      {/* ─────────────────────────────────────────────────────────────────── */}
      {/* VIEW: TABLE                                                         */}
      {/* ─────────────────────────────────────────────────────────────────── */}
      {viewMode === 'list' && (
        <>
          {filteredList.length === 0 ? (
            <div className="text-center py-16 bg-white rounded-2xl border border-gray-100 shadow-sm">
              <ClipboardList size={40} className="mx-auto mb-3 text-gray-200" />
              <p className="text-gray-400 text-sm font-medium">Nenhuma reserva encontrada.</p>
              <p className="text-gray-300 text-xs mt-1">Ajuste os filtros ou aguarde novas solicitações dos moradores.</p>
            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-[#FC5931] text-white">
                    <th className="text-left px-4 py-3 font-semibold">Espaço</th>
                    <th className="text-left px-4 py-3 font-semibold">Nome do Evento</th>
                    <th className="px-4 py-3 font-semibold text-center">Data</th>
                    <th className="text-left px-4 py-3 font-semibold">Usuário</th>
                    <th className="px-4 py-3 font-semibold text-center">{aptoLabel}/{blocoLabel}</th>
                    <th className="px-4 py-3 font-semibold text-right">Taxa</th>
                    <th className="px-4 py-3 font-semibold text-center">Pagamento</th>
                    <th className="px-4 py-3 font-semibold text-center">Status</th>
                    <th className="px-4 py-3 font-semibold text-center">Ações</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredList.map((r, idx) => {
                    const canCancel = r.status === 'aprovado'
                    const areaColor = getAreaColor(r.areas_comuns?.id || r.area_id || 'unknown')

                    return (
                      <tr key={r.id} className={`border-b border-gray-50 ${idx % 2 === 1 ? 'bg-gray-50/50' : ''}`}>
                        <td className="px-4 py-3 font-medium text-gray-900">
                          <div className="flex items-center gap-2">
                            <span
                              className="w-2.5 h-2.5 rounded-full inline-block shrink-0"
                              style={{ backgroundColor: areaColor }}
                            />
                            <span>{r.areas_comuns?.tipo_agenda ?? '—'}</span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-gray-700">
                          {r.nome_evento || r.areas_comuns?.tipo_agenda || '—'}
                        </td>
                        <td className="px-4 py-3 text-center text-gray-600">
                          {new Date(r.data_reserva + 'T00:00:00').toLocaleDateString('pt-BR')}
                        </td>
                        <td className="px-4 py-3 text-gray-700">
                          {r.perfil?.nome_completo ?? '—'}
                        </td>
                        <td className="px-4 py-3 text-center text-gray-600">
                          {r.perfil ? formatUnitDisplay({ bloco: r.perfil.bloco_txt, apto: r.perfil.apto_txt, role: r.perfil.papel_sistema, tipoEstrutura, fallback: 'Identidade Administrativa', includeLabels: false, separator: ' / ' }) : '—'}
                        </td>
                        <td className="px-4 py-3 text-right font-medium text-gray-900">
                          {r.valor_reserva && Number(r.valor_reserva) > 0 
                            ? formatCurrency(Number(r.valor_reserva)) 
                            : 'Grátis'}
                        </td>
                        <td className="px-4 py-3 text-center">
                          {(() => {
                            const statusMap: Record<string, { label: string; style: string }> = {
                              isento: { label: 'Isento', style: 'bg-gray-100 text-gray-500 border border-gray-200' },
                              pendente: { label: 'Pendente', style: 'bg-yellow-100 text-yellow-700 border border-yellow-200' },
                              faturado: { label: 'Faturado', style: 'bg-blue-100 text-blue-700 border border-blue-200' },
                              pago: { label: 'Pago', style: 'bg-green-100 text-green-700 border border-green-200' },
                            }
                            const pStatus = r.status_pagamento || 'isento'
                            const meta = statusMap[pStatus] ?? { label: pStatus, style: 'bg-gray-100 text-gray-500' }
                            return (
                              <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${meta.style}`}>
                                {meta.label}
                              </span>
                            )
                          })()}
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusBadge(r.status)}`}>
                            {statusLabel(r.status)}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center justify-center gap-2">
                            {r.status === 'pendente' && (
                              <>
                                <button
                                  onClick={() => setStatus(r.id, 'aprovado')}
                                  disabled={updating === r.id}
                                  className="flex items-center gap-1 text-xs bg-green-100 text-green-700 hover:bg-green-200 px-3 py-1.5 rounded-lg transition-colors disabled:opacity-50 font-medium"
                                >
                                  <Check size={13} /> Aprovar
                                </button>
                                <button
                                  onClick={() => setStatus(r.id, 'reprovado')}
                                  disabled={updating === r.id}
                                  className="flex items-center gap-1 text-xs bg-red-100 text-red-600 hover:bg-red-200 px-3 py-1.5 rounded-lg transition-colors disabled:opacity-50 font-medium"
                                >
                                  <X size={13} /> Reprovar
                                </button>
                              </>
                            )}
                            {canCancel && (
                              <button
                                onClick={() => setCancelConfirm(r.id)}
                                disabled={updating === r.id}
                                className="flex items-center gap-1 text-xs bg-orange-100 text-orange-700 hover:bg-orange-200 px-3 py-1.5 rounded-lg transition-colors disabled:opacity-50 font-medium"
                              >
                                <Ban size={13} /> Cancelar
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
              <p className="text-xs text-gray-400 text-center py-3 border-t border-gray-50">
                {filteredList.length} reserva{filteredList.length !== 1 ? 's' : ''} exibida{filteredList.length !== 1 ? 's' : ''}
              </p>
            </div>
          )}
        </>
      )}

      {/* ─────────────────────────────────────────────────────────────────── */}
      {/* DAY DETAIL MODAL (Opens on Day Click)                              */}
      {/* ─────────────────────────────────────────────────────────────────── */}
      {dayModalOpen && selectedDayIso && (() => {
        const dataBr = new Date(selectedDayIso + 'T00:00:00').toLocaleDateString('pt-BR')
        return (
          <div
            className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50 p-4"
            onClick={() => setDayModalOpen(false)}
          >
            <div
              className="bg-white rounded-2xl p-6 max-w-2xl w-full max-h-[85vh] flex flex-col shadow-2xl"
              onClick={e => e.stopPropagation()}
            >
              <div className="flex items-center justify-between pb-4 border-b border-gray-100">
                <div className="flex items-center gap-2.5">
                  <div className="w-9 h-9 rounded-xl bg-[#FC5931]/10 flex items-center justify-center">
                    <CalendarDays size={18} className="text-[#FC5931]" />
                  </div>
                  <div>
                    <h3 className="text-lg font-bold text-gray-900">Reservas de {dataBr}</h3>
                    <p className="text-xs text-gray-500">
                      {selectedDayReservations.length} reserva{selectedDayReservations.length !== 1 ? 's' : ''} encontrada{selectedDayReservations.length !== 1 ? 's' : ''} para este dia
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setDayModalOpen(false)}
                  className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors"
                >
                  <X size={20} />
                </button>
              </div>

              <div className="flex-1 overflow-y-auto py-4 space-y-3">
                {selectedDayReservations.length === 0 ? (
                  <div className="text-center py-12">
                    <Info size={32} className="mx-auto text-gray-300 mb-2" />
                    <p className="text-sm text-gray-500">Nenhuma reserva ativa neste dia.</p>
                  </div>
                ) : (
                  selectedDayReservations.map(res => {
                    const canCancel = res.status === 'aprovado'
                    const areaColor = getAreaColor(res.areas_comuns?.id || res.area_id || 'unknown')

                    return (
                      <div
                        key={res.id}
                        className="border border-gray-200 rounded-xl p-4 hover:border-gray-300 transition-all bg-white shadow-xs"
                      >
                        <div className="flex items-start justify-between gap-3 mb-3">
                          <div className="flex items-center gap-2">
                            <span
                              className="w-3 h-3 rounded-full shrink-0"
                              style={{ backgroundColor: areaColor }}
                            />
                            <h4 className="font-bold text-gray-900 text-sm">
                              {res.areas_comuns?.tipo_agenda ?? 'Área Comum'}
                            </h4>
                            {res.nome_evento && res.nome_evento !== res.areas_comuns?.tipo_agenda && (
                              <span className="text-xs text-gray-500">({res.nome_evento})</span>
                            )}
                          </div>
                          <span className={`text-xs px-2.5 py-0.5 rounded-full font-bold ${statusBadge(res.status)}`}>
                            {statusLabel(res.status)}
                          </span>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs text-gray-600 mb-3 bg-gray-50 p-3 rounded-lg">
                          <div className="flex items-center gap-2">
                            <User size={13} className="text-gray-400" />
                            <span>Morador: <strong>{res.perfil?.nome_completo ?? '—'}</strong></span>
                          </div>
                          <div className="flex items-center gap-2">
                            <Building size={13} className="text-gray-400" />
                            <span>Unidade: <strong>{formatUnitDisplay({ bloco: res.perfil?.bloco_txt, apto: res.perfil?.apto_txt, role: res.perfil?.papel_sistema, tipoEstrutura, fallback: 'Identidade Administrativa' }) || '—'}</strong></span>
                          </div>
                          <div className="flex items-center gap-2">
                            <Clock size={13} className="text-gray-400" />
                            <span>Data: <strong>{dataBr}</strong></span>
                          </div>
                          <div className="flex items-center gap-2">
                            <DollarSignIcon size={13} className="text-gray-400" />
                            <span>Taxa: <strong>{res.valor_reserva && Number(res.valor_reserva) > 0 ? formatCurrency(Number(res.valor_reserva)) : 'Grátis'}</strong></span>
                          </div>
                        </div>

                        {/* Actions */}
                        <div className="flex items-center justify-end gap-2 pt-2 border-t border-gray-100">
                          {res.status === 'pendente' && (
                            <>
                              <button
                                onClick={() => setStatus(res.id, 'aprovado')}
                                disabled={updating === res.id}
                                className="flex items-center gap-1 text-xs bg-green-600 text-white hover:bg-green-700 px-3 py-1.5 rounded-lg transition-colors font-semibold disabled:opacity-50"
                              >
                                <Check size={14} /> Aprovar
                              </button>
                              <button
                                onClick={() => setStatus(res.id, 'reprovado')}
                                disabled={updating === res.id}
                                className="flex items-center gap-1 text-xs bg-red-100 text-red-700 hover:bg-red-200 px-3 py-1.5 rounded-lg transition-colors font-semibold disabled:opacity-50"
                              >
                                <X size={14} /> Reprovar
                              </button>
                            </>
                          )}
                          {canCancel && (
                            <button
                              onClick={() => setCancelConfirm(res.id)}
                              disabled={updating === res.id}
                              className="flex items-center gap-1 text-xs bg-orange-100 text-orange-700 hover:bg-orange-200 px-3 py-1.5 rounded-lg transition-colors font-semibold disabled:opacity-50"
                            >
                              <Ban size={14} /> Cancelar Reserva
                            </button>
                          )}
                        </div>
                      </div>
                    )
                  })
                )}
              </div>

              <div className="pt-3 border-t border-gray-100 flex justify-end">
                <button
                  onClick={() => setDayModalOpen(false)}
                  className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 text-xs font-bold rounded-xl transition-colors"
                >
                  Fechar
                </button>
              </div>
            </div>
          </div>
        )
      })()}

      {/* ─────────────────────────────────────────────────────────────────── */}
      {/* CANCEL CONFIRMATION MODAL                                          */}
      {/* ─────────────────────────────────────────────────────────────────── */}
      {cancelConfirm && (() => {
        const reserva = reservas.find(r => r.id === cancelConfirm)
        if (!reserva) return null
        const dataFormatada = new Date(reserva.data_reserva + 'T00:00:00').toLocaleDateString('pt-BR')
        return (
          <div
            className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50"
            onClick={() => setCancelConfirm(null)}
          >
            <div
              className="bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-2xl"
              onClick={e => e.stopPropagation()}
            >
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center">
                  <Ban size={20} className="text-red-600" />
                </div>
                <h3 className="text-lg font-bold text-gray-900">Cancelar Reserva</h3>
              </div>
              <p className="text-sm text-gray-600 mb-1">
                Tem certeza que deseja cancelar a reserva de <strong>{reserva.areas_comuns?.tipo_agenda}</strong> do dia <strong>{dataFormatada}</strong>?
              </p>
              <p className="text-sm text-gray-600 mb-5">
                Morador: <strong>{reserva.perfil?.nome_completo ?? '—'}</strong>
              </p>
              <p className="text-xs text-gray-400 mb-5">
                O morador será notificado via WhatsApp sobre o cancelamento.
              </p>
              <div className="flex gap-3">
                <button
                  onClick={() => setCancelConfirm(null)}
                  className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors"
                >
                  Voltar
                </button>
                <button
                  onClick={() => cancelReserva(reserva)}
                  className="flex-1 px-4 py-2.5 rounded-xl bg-red-600 text-white text-sm font-medium hover:bg-red-700 transition-colors"
                >
                  Confirmar Cancelamento
                </button>
              </div>
            </div>
          </div>
        )
      })()}
    </div>
  )
}

function DollarSignIcon({ size = 16, className = '' }: { size?: number; className?: string }) {
  return (
    <span className={`font-bold inline-block text-center ${className}`} style={{ fontSize: size }}>
      R$
    </span>
  )
}
