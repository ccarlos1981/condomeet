'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Clock, Trash2, ArrowLeft, ToggleRight, ToggleLeft } from 'lucide-react'

const DIAS = ['Seg','Ter','Qua','Qui','Sex','Sab','Dom']

interface Horario {
  id: string
  area_id: string
  dia_semana: string
  hora_inicio: string // "HH:MM:SS"
  duracao_minutos: number
  ativo: boolean
}

interface Props {
  areaId: string
  tipoAgenda: string
  initialHorarios: Horario[]
}

export default function HorariosClient({ areaId, tipoAgenda, initialHorarios }: Props) {
  const router = useRouter()
  const [horarios, setHorarios] = useState<Horario[]>(initialHorarios)
  const [selectedDay, setSelectedDay] = useState('Seg')
  const [diaSemana, setDiaSemana] = useState('Seg')
  const [horaInicio, setHoraInicio] = useState('')
  const [duracao, setDuracao] = useState(60)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const slotsForDay = horarios
    .filter(h => h.dia_semana === selectedDay)
    .sort((a, b) => a.hora_inicio.localeCompare(b.hora_inicio))

  async function handleCreate() {
    if (!horaInicio) { setError('Informe a hora inicial'); return }
    setSaving(true); setError(null)

    const res = await fetch('/api/areas-comuns/horarios', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        area_id: areaId,
        dia_semana: diaSemana,
        hora_inicio: horaInicio,
        duracao_minutos: duracao,
      }),
    })
    const data = await res.json()
    if (!res.ok) { setError(data.error ?? 'Erro'); setSaving(false); return }
    setHorarios(prev => [...prev, data])
    setHoraInicio('')
    setDuracao(60)
    setSaving(false)
  }

  async function handleDelete(id: string) {
    await fetch(`/api/areas-comuns/horarios?id=${id}`, { method: 'DELETE' })
    setHorarios(prev => prev.filter(h => h.id !== id))
  }

  async function toggleAtivo(h: Horario) {
    const res = await fetch('/api/areas-comuns/horarios', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: h.id, ativo: !h.ativo }),
    })
    if (res.ok) {
      const data = await res.json()
      setHorarios(prev => prev.map(x => x.id === h.id ? data : x))
    }
  }

  function fmtHora(t: string) {
    return t?.slice(0, 5) ?? ''
  }

  return (
    <div className="max-w-3xl">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <button
          onClick={() => router.push('/admin/areas-comuns')}
          className="p-2 rounded-xl hover:bg-gray-100 transition-colors text-gray-500"
        >
          <ArrowLeft size={18} />
        </button>
        <div>
          <div className="flex items-center gap-2">
            <Clock size={20} className="text-[#E85D26]" />
            <h1 className="text-xl font-bold text-gray-900">
              Horários para uso do(a) {tipoAgenda}
            </h1>
          </div>
          <p className="text-sm text-gray-500 mt-0.5 ml-7">Horários disponíveis para agendamentos</p>
        </div>
      </div>

      {/* Create form */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 mb-6">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
          <div>
            <label className="text-xs font-semibold text-gray-500 block mb-1">Dia da semana</label>
            <select
              value={diaSemana}
              onChange={e => setDiaSemana(e.target.value)}
              className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26]/30"
            >
              {DIAS.map(d => <option key={d}>{d}</option>)}
            </select>
          </div>

          <div>
            <label className="text-xs font-semibold text-gray-500 block mb-1">Hora Inicial</label>
            <input
              type="time"
              value={horaInicio}
              onChange={e => setHoraInicio(e.target.value)}
              className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26]/30"
            />
          </div>

          <div>
            <label className="text-xs font-semibold text-gray-500 block mb-1">Duração (minutos)</label>
            <input
              type="number" min={15} step={5}
              value={duracao}
              onChange={e => setDuracao(Number(e.target.value))}
              className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26]/30"
            />
          </div>

          <div className="flex items-end">
            <button
              onClick={handleCreate}
              disabled={saving}
              className="w-full bg-[#E85D26] text-white px-4 py-2.5 rounded-xl text-sm font-semibold hover:bg-[#d44e1e] transition-colors disabled:opacity-50"
            >
              {saving ? '...' : 'CRIAR'}
            </button>
          </div>
        </div>
        {error && <p className="text-red-500 text-xs">{error}</p>}
      </div>

      {/* Day tabs */}
      <div className="flex gap-1 mb-4">
        {DIAS.map(d => {
          const count = horarios.filter(h => h.dia_semana === d).length
          return (
            <button
              key={d}
              onClick={() => setSelectedDay(d)}
              className={`flex-1 py-2 rounded-xl text-xs font-semibold transition-colors relative ${
                selectedDay === d
                  ? 'bg-[#E85D26] text-white shadow'
                  : 'bg-white border border-gray-100 text-gray-600 hover:bg-gray-50'
              }`}
            >
              {d}
              {count > 0 && (
                <span className={`absolute -top-1 -right-1 w-4 h-4 text-[10px] font-bold rounded-full flex items-center justify-center ${
                  selectedDay === d ? 'bg-white text-[#E85D26]' : 'bg-[#E85D26] text-white'
                }`}>
                  {count}
                </span>
              )}
            </button>
          )
        })}
      </div>

      {/* Slots list for selected day */}
      <div className="space-y-2">
        {slotsForDay.length === 0 ? (
          <div className="bg-white rounded-2xl border border-gray-100 py-10 text-center text-gray-400">
            <Clock size={28} className="mx-auto mb-2 opacity-25" />
            <p className="text-sm">Nenhum horário para {selectedDay}</p>
          </div>
        ) : slotsForDay.map(h => (
          <div
            key={h.id}
            className={`bg-white rounded-xl border border-gray-100 px-4 py-3 flex items-center gap-4 ${!h.ativo ? 'opacity-50' : ''}`}
          >
            <div className="w-10 h-10 bg-blue-50 rounded-full flex items-center justify-center">
              <Clock size={18} className="text-blue-500" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-gray-800">Dia {h.dia_semana}</p>
              <p className="text-xs text-gray-500">
                Hora Início: <span className="font-medium">{fmtHora(h.hora_inicio)}</span>
                {' — '}
                Tempo permanência: <span className="font-medium">{h.duracao_minutos} min</span>
              </p>
            </div>
            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={() => toggleAtivo(h)}
                className="text-gray-400 hover:text-gray-600 transition-colors"
                title={h.ativo ? 'Desativar' : 'Ativar'}
              >
                {h.ativo
                  ? <ToggleRight size={22} className="text-green-500" />
                  : <ToggleLeft size={22} className="text-gray-300" />}
              </button>
              <button
                onClick={() => handleDelete(h.id)}
                className="p-1.5 rounded-lg text-red-400 hover:bg-red-50 hover:text-red-600 transition-colors"
              >
                <Trash2 size={15} />
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
