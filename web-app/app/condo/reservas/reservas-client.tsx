'use client'

import React, { useState, useCallback, useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import {
  Users, Clock, X, ChevronLeft, ChevronRight,
  CheckCircle2, Calendar, BookOpen
} from 'lucide-react'
import type { AreaComum, MinhaReserva } from './page'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

interface Props {
  areas: AreaComum[]
  minhasReservas: MinhaReserva[]
  profile: { nome: string; bloco: string; apto: string }
  tipoEstrutura?: string
}

type HorarioSlot = { id: string; hora_inicio: string; duracao_minutos: number; disponivel: boolean }

const MESES = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho',
  'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro']
const DIAS_SEMANA = ['Dom','Seg','Ter','Qua','Qui','Sex','Sab']

function fmt(dateStr: string) {
  const d = new Date(dateStr + 'T12:00:00')
  return d.toLocaleDateString('pt-BR')
}

function fmtHora(h: string) { return h?.substring(0, 5) ?? '' }

function getPreco(area: AreaComum) {
  const precos = area.precos ?? []
  const p = precos.find(p => p.valor > 0)
  return p ? `R$ ${p.valor.toFixed(2).replace('.', ',')}` : 'Gratuito'
}

function labelLocal(area: AreaComum) {
  if (area.local === 'Outro') return area.outro_local ?? 'Outro'
  return area.local ?? ''
}

function labelTipo(area: AreaComum) {
  return area.tipo_reserva === 'por_hora' ? 'Agenda por período do dia' : 'Agenda diária'
}

function statusLabel(s: string) {
  switch(s) {
    case 'aprovado': return { label: 'Aprovado', cls: 'bg-green-100 text-green-700' }
    case 'pendente': return { label: 'Pendente', cls: 'bg-yellow-100 text-yellow-700' }
    case 'reprovado': return { label: 'Reprovado', cls: 'bg-red-100 text-red-700' }
    case 'cancelado': return { label: 'Cancelado', cls: 'bg-gray-100 text-gray-500' }
    default: return { label: s, cls: 'bg-gray-100 text-gray-500' }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Mini Calendar
// ──────────────────────────────────────────────────────────────────────────────
function MiniCalendar({
  selected, onSelect, bookedDates, onMonthChange
}: {
  selected: string | null
  onSelect: (d: string) => void
  bookedDates: Set<string>
  onMonthChange?: (year: number, month: number) => void
}) {
  const today = new Date()
  const [view, setView] = useState({ year: today.getFullYear(), month: today.getMonth() })

  const firstDay = new Date(view.year, view.month, 1)
  const lastDay = new Date(view.year, view.month + 1, 0)
  const startDow = firstDay.getDay()
  const todayStr = today.toISOString().split('T')[0]

  const cells: (number | null)[] = []
  for (let i = 0; i < startDow; i++) cells.push(null)
  for (let d = 1; d <= lastDay.getDate(); d++) cells.push(d)

  function toIso(day: number) {
    return `${view.year}-${String(view.month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
  }

  function prevMonth() {
    setView(v => {
      const next = v.month === 0 ? { year: v.year - 1, month: 11 } : { ...v, month: v.month - 1 }
      onMonthChange?.(next.year, next.month + 1)
      return next
    })
  }
  function nextMonth() {
    setView(v => {
      const next = v.month === 11 ? { year: v.year + 1, month: 0 } : { ...v, month: v.month + 1 }
      onMonthChange?.(next.year, next.month + 1)
      return next
    })
  }

  return (
    <div className="select-none">
      {/* Month nav */}
      <div className="flex items-center justify-between mb-3">
        <button
          onClick={() => { const t = new Date(); setView({ year: t.getFullYear(), month: t.getMonth() }) }}
          className="text-xs font-semibold text-white bg-[#FC5931] px-2 py-1 rounded-lg"
        >Hoje</button>
        <div className="flex items-center gap-2">
          <button onClick={prevMonth} aria-label="Mês anterior" title="Mês anterior" className="text-gray-500 hover:text-gray-800 p-1"><ChevronLeft size={16} /></button>
          <span className="text-sm font-semibold text-gray-700">{MESES[view.month]} de {view.year}</span>
          <button onClick={nextMonth} aria-label="Próximo mês" title="Próximo mês" className="text-gray-500 hover:text-gray-800 p-1"><ChevronRight size={16} /></button>
        </div>
      </div>

      {/* Header */}
      <div className="grid grid-cols-7 mb-1">
        {DIAS_SEMANA.map(d => (
          <div key={d} className="text-center text-xs font-semibold text-gray-400 py-1">{d}</div>
        ))}
      </div>

      {/* Grid */}
      <div className="grid grid-cols-7 gap-0.5">
        {cells.map((day, i) => {
          if (!day) return <div key={`e-${i}`} />
          const iso = toIso(day)
          const isPast = iso < todayStr
          const isBooked = bookedDates.has(iso)
          const isSel = iso === selected
          const isToday = iso === todayStr

          let cls = 'text-xs flex items-center justify-center rounded-lg h-8 w-full cursor-pointer transition-all font-medium '
          if (isPast) cls += 'text-gray-300 cursor-default'
          else if (isBooked) cls += 'bg-[#FC5931]/20 text-[#FC5931] cursor-default font-bold'
          else if (isSel) cls += 'bg-[#222] text-white'
          else if (isToday) cls += 'border-2 border-[#FC5931] text-[#FC5931]'
          else cls += 'text-gray-700 hover:bg-gray-100'

          return (
            <div
              key={iso}
              className={cls}
              onClick={() => { if (!isPast && !isBooked) onSelect(iso) }}
            >
              {day}
              {isToday && !isSel && <span className="absolute w-1 h-1 bg-[#FC5931] rounded-full bottom-1" />}
            </div>
          )
        })}
      </div>
    </div>
  )
}

// ──────────────────────────────────────────────────────────────────────────────
// Booking Modal
// ──────────────────────────────────────────────────────────────────────────────
function BookingModal({
  area, profile, tipoEstrutura, onClose, onBooked
}: {
  area: AreaComum
  profile: Props['profile']
  tipoEstrutura?: string
  onClose: () => void
  onBooked: () => void
}) {
  const [selectedDate, setSelectedDate] = useState<string | null>(null)
  const [horarios, setHorarios] = useState<HorarioSlot[]>([])
  const [selectedHorario, setSelectedHorario] = useState<string | null>(null)
  const [loadingSlots, setLoadingSlots] = useState(false)
  const [nomeEvento, setNomeEvento] = useState(area.tipo_agenda)
  const [ciente, setCiente] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [bookedDates, setBookedDates] = useState<Set<string>>(new Set())
  const loadedMonths = useRef<Set<string>>(new Set())

  const loadBookedDates = useCallback(async (year: number, month: number) => {
    const key = `${year}-${month}`
    if (loadedMonths.current.has(key)) return
    loadedMonths.current.add(key)
    const res = await fetch(`/api/reservas/booked?areaId=${area.id}&year=${year}&month=${month}`)
    const dates: string[] = await res.json()
    if (Array.isArray(dates)) {
      setBookedDates(prev => new Set([...prev, ...dates]))
    }
  }, [area.id])

  useEffect(() => {
    ;(async () => {
      const now = new Date()
      await loadBookedDates(now.getFullYear(), now.getMonth() + 1)
    })()
  }, [loadBookedDates])

  const handleDateSelect = useCallback(async (date: string) => {
    setSelectedDate(date)
    setSelectedHorario(null)
    setHorarios([])
    if (area.tipo_reserva === 'por_hora') {
      setLoadingSlots(true)
      const res = await fetch(`/api/reservas/horarios?areaId=${area.id}&data=${date}`)
      const slots = await res.json()
      setHorarios(Array.isArray(slots) ? slots : [])
      setLoadingSlots(false)
    }
  }, [area])

  async function handleAgendar() {
    if (!selectedDate) { setError('Selecione uma data'); return }
    if (area.tipo_reserva === 'por_hora' && !selectedHorario) { setError('Selecione um horário'); return }
    if (!ciente) { setError('Confirme que leu o regimento'); return }
    setSaving(true); setError(null)

    const res = await fetch('/api/reservas', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        area_id: area.id,
        horario_id: selectedHorario ?? null,
        data_reserva: selectedDate,
        nome_evento: nomeEvento || area.tipo_agenda,
      }),
    })

    const json = await res.json()
    if (!res.ok) { setError(json.error ?? 'Erro ao reservar'); setSaving(false); return }
    onBooked()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] overflow-y-auto"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-start justify-between p-5 border-b border-gray-100">
          <div className="grid grid-cols-3 gap-x-4 gap-y-1 text-xs flex-1">
            <div><span className="text-gray-400">Nome:</span><br /><span className="font-semibold text-gray-800">{profile.nome.split(' ')[0]}</span></div>
            <div><span className="text-gray-400">{getBlocoLabel(tipoEstrutura)}:</span><br /><span className="font-semibold text-gray-800">{profile.bloco || '—'}</span></div>
            <div><span className="text-gray-400">{getAptoLabel(tipoEstrutura)}:</span><br /><span className="font-semibold text-gray-800">{profile.apto || '—'}</span></div>
            <div className="col-span-3"><span className="text-gray-400">Área comum:</span><br /><span className="font-semibold text-gray-800">{area.tipo_agenda}</span></div>
          </div>
          <button onClick={onClose} aria-label="Fechar" title="Fechar" className="ml-2 text-gray-400 hover:text-gray-700 transition-colors">
            <X size={20} />
          </button>
        </div>

        <div className="p-5 space-y-5">
          {/* Calendar */}
          <MiniCalendar
            selected={selectedDate}
            onSelect={handleDateSelect}
            bookedDates={bookedDates}
            onMonthChange={loadBookedDates}
          />

          {/* Time slots (por_hora only) */}
          {area.tipo_reserva === 'por_hora' && selectedDate && (
            <div>
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">Escolha aqui seu horário</p>
              {loadingSlots ? (
                <p className="text-xs text-gray-400">Carregando horários...</p>
              ) : horarios.length === 0 ? (
                <p className="text-xs text-gray-400">Nenhum horário disponível para este dia.</p>
              ) : (
                <div className="flex flex-wrap gap-2">
                  {horarios.map(h => {
                    const hora = fmtHora(h.hora_inicio)
                    const isSel = selectedHorario === h.id
                    return (
                      <button
                        key={h.id}
                        disabled={!h.disponivel}
                        onClick={() => setSelectedHorario(h.id)}
                        className={`px-3 py-1.5 rounded-full text-xs font-semibold transition-all ${
                          !h.disponivel
                            ? 'bg-gray-100 text-gray-400 line-through cursor-not-allowed'
                            : isSel
                              ? 'bg-[#FC5931] text-white shadow-sm'
                              : 'bg-[#FC5931]/10 text-[#FC5931] hover:bg-[#FC5931]/20'
                        }`}
                      >{hora}</button>
                    )
                  })}
                </div>
              )}
            </div>
          )}

          {/* Event name */}
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1">Dê um nome para o seu evento ou deixe o nome padrão</p>
            <input
              type="text"
              value={nomeEvento}
              onChange={e => setNomeEvento(e.target.value)}
              placeholder={area.tipo_agenda}
              className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
            />
          </div>

          {/* Regimento */}
          <label className="flex items-center gap-2 cursor-pointer">
            <button
              type="button"
              onClick={() => setCiente(c => !c)}
              className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-all ${ciente ? 'bg-[#FC5931] border-[#FC5931]' : 'border-gray-300'}`}
            >
              {ciente && <CheckCircle2 size={12} className="text-white" />}
            </button>
            <span className="text-xs text-gray-600">
              Ciente do{' '}
              {area.instrucao_uso
                ? <span className="underline cursor-pointer text-[#FC5931]" title={area.instrucao_uso}>Regimento do condomínio</span>
                : 'Regimento do condomínio'
              }
            </span>
          </label>

          {error && <p className="text-red-500 text-xs">{error}</p>}

          {(() => {
            const dateBooked = !!selectedDate && bookedDates.has(selectedDate)
            const canBook = !!selectedDate &&
              !dateBooked &&
              (area.tipo_reserva !== 'por_hora' || !!selectedHorario) &&
              ciente &&
              !saving
            const label = saving ? 'Agendando...'
              : !selectedDate ? 'Selecione uma data'
              : dateBooked ? 'Data já reservada'
              : area.tipo_reserva === 'por_hora' && !selectedHorario ? 'Selecione um horário'
              : 'Agendar'
            return (
              <button
                onClick={handleAgendar}
                disabled={!canBook}
                className={`w-full rounded-full py-3 font-semibold text-sm transition-colors ${
                  canBook
                    ? 'bg-[#FC5931] text-white hover:bg-[#D42F1D]'
                    : 'bg-gray-200 text-gray-400 cursor-not-allowed'
                }`}
              >
                {label}
              </button>
            )
          })()}
        </div>
      </div>
    </div>
  )
}

// ──────────────────────────────────────────────────────────────────────────────
// Area Card
// ──────────────────────────────────────────────────────────────────────────────
function AreaCard({ area, onOpen }: { area: AreaComum; onOpen: () => void }) {
  const preco = getPreco(area)
  const [showRegimento, setShowRegimento] = useState(false)

  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex flex-col gap-4">
      <div className="flex items-start gap-4">
        <div className="w-10 h-10 rounded-full border-2 border-[#FC5931] shrink-0 mt-0.5" />
        <div className="flex-1">
          <h3 className="font-bold text-gray-900 text-sm leading-tight">
            {area.tipo_agenda}
            <span className="font-normal text-gray-500"> ({labelTipo(area)})</span>
          </h3>
          <p className="text-xs text-gray-400 mt-0.5">{labelLocal(area)}</p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2 text-xs">
        <div>
          <p className="text-gray-400 uppercase tracking-wider text-[10px] font-semibold mb-0.5">Capacidade</p>
          <p className="font-semibold text-gray-800 flex items-center gap-1"><Users size={12} /> {area.capacidade} Máx</p>
        </div>
        <div>
          <p className="text-gray-400 uppercase tracking-wider text-[10px] font-semibold mb-0.5">Taxa de Reserva</p>
          <p className="font-semibold text-gray-800">{preco}</p>
        </div>
        <div>
          <p className="text-gray-400 uppercase tracking-wider text-[10px] font-semibold mb-0.5">Cancelamento</p>
          <p className="font-semibold text-gray-800 flex items-center gap-1"><Clock size={12} /> {area.hrs_cancelar}h antes do evento</p>
        </div>
      </div>

      <div className="flex items-center justify-between pt-1 border-t border-gray-50">
        {area.instrucao_uso ? (
          <button
            onClick={() => setShowRegimento(s => !s)}
            className="text-xs font-semibold text-gray-700 underline hover:text-[#FC5931] transition-colors"
          >
            Regime de uso do Condomínio
          </button>
        ) : (
          <div />
        )}
        <button
          onClick={onOpen}
          className="flex items-center gap-2 text-[#FC5931] hover:text-[#D42F1D] transition-colors"
        >
          <Calendar size={18} />
          <span className="text-[#FC5931]">→</span>
        </button>
      </div>

      {showRegimento && area.instrucao_uso && (
        <div className="bg-orange-50 rounded-xl p-3 text-xs text-gray-700 leading-relaxed border border-orange-100">
          {area.instrucao_uso}
        </div>
      )}
    </div>
  )
}

// ──────────────────────────────────────────────────────────────────────────────
// Main Component
// ──────────────────────────────────────────────────────────────────────────────
export default function ReservasClient({ areas, minhasReservas, profile, tipoEstrutura }: Props) {
  const router = useRouter()
  const [tab, setTab] = useState<'disponiveis' | 'minhas'>('disponiveis')
  const [modalArea, setModalArea] = useState<AreaComum | null>(null)
  const [booked, setBooked] = useState(false)
  const [reservas, setReservas] = useState(minhasReservas)

  // Sync when server refreshes data
  useEffect(() => { setReservas(minhasReservas) }, [minhasReservas])

  function handleBooked() {
    setModalArea(null)
    setBooked(true)
    setTab('minhas')
    // Re-run the server component to get fresh data
    router.refresh()
    setTimeout(() => setBooked(false), 4000)
  }

  return (
    <div className="p-6 lg:p-8 max-w-3xl">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Reservar Espaço</h1>
        <p className="text-gray-500 text-sm mt-1">Reserve áreas comuns do seu condomínio</p>
      </div>

      {/* Success banner */}
      {booked && (
        <div className="flex items-center gap-2 bg-green-50 border border-green-200 text-green-700 rounded-xl px-4 py-3 mb-5 text-sm font-medium">
          <CheckCircle2 size={16} />
          Reserva realizada com sucesso! {areas.find(a => a.aprovacao_automatica) ? 'Aprovada automaticamente.' : 'Aguardando aprovação do síndico.'}
        </div>
      )}

      {/* Tabs */}
      <div className="flex border-b border-gray-200 mb-6">
        <button
          className={`pb-3 px-4 text-sm font-semibold transition-colors border-b-2 ${tab === 'disponiveis' ? 'border-[#FC5931] text-[#FC5931]' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
          onClick={() => setTab('disponiveis')}
        >
          Disponíveis para agendas
        </button>
        <button
          className={`pb-3 px-4 text-sm font-semibold transition-colors border-b-2 ${tab === 'minhas' ? 'border-[#FC5931] text-[#FC5931]' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
          onClick={() => setTab('minhas')}
        >
          Meus Agendamentos
        </button>
      </div>

      {/* Disponíveis */}
      {tab === 'disponiveis' && (
        <div className="space-y-4">
          {areas.length === 0 ? (
            <div className="text-center py-16 bg-white rounded-2xl border border-gray-100">
              <BookOpen size={36} className="mx-auto mb-3 text-gray-200" />
              <p className="text-gray-400 text-sm">Nenhuma área disponível para reserva.</p>
            </div>
          ) : (
            areas.map(area => (
              <AreaCard key={area.id} area={area} onOpen={() => setModalArea(area)} />
            ))
          )}
        </div>
      )}

      {/* Meus Agendamentos */}
      {tab === 'minhas' && (
        <div>
          {reservas.length === 0 ? (
            <div className="text-center py-16 bg-white rounded-2xl border border-gray-100">
              <Calendar size={36} className="mx-auto mb-3 text-gray-200" />
              <p className="text-gray-400 text-sm">Você ainda não tem agendamentos.</p>
            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-[#FC5931] text-white">
                    <th className="text-left px-4 py-3 font-semibold">Área</th>
                    <th className="text-left px-4 py-3 font-semibold">Data</th>
                    <th className="px-4 py-3 font-semibold">Horário</th>
                    <th className="px-4 py-3 font-semibold">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {reservas.map((r, i) => {
                    const st = statusLabel(r.status)
                    return (
                      <tr key={r.id} className={`border-b border-gray-50 ${i % 2 === 0 ? '' : 'bg-gray-50/40'}`}>
                        <td className="px-4 py-3 font-medium text-gray-900">
                          {(r.areas_comuns as { tipo_agenda: string })?.tipo_agenda ?? '—'}
                          {r.nome_evento && r.nome_evento !== (r.areas_comuns as { tipo_agenda: string })?.tipo_agenda && (
                            <span className="block text-xs text-gray-400">{r.nome_evento}</span>
                          )}
                        </td>
                        <td className="px-4 py-3 text-gray-600">{fmt(r.data_reserva)}</td>
                        <td className="px-4 py-3 text-center text-gray-600">
                          {(r.areas_comuns_horarios as { hora_inicio: string } | null)?.hora_inicio
                            ? fmtHora((r.areas_comuns_horarios as { hora_inicio: string }).hora_inicio)
                            : 'Dia inteiro'}
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className={`text-xs px-2 py-0.5 rounded-full font-semibold ${st.cls}`}>
                            {st.label}
                          </span>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Booking Modal */}
      {modalArea && (
        <BookingModal
          area={modalArea}
          profile={profile}
          tipoEstrutura={tipoEstrutura}
          onClose={() => setModalArea(null)}
          onBooked={handleBooked}
        />
      )}
    </div>
  )
}
