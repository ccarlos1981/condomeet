'use client'

import { useState } from 'react'
import { ClipboardList, Check, X } from 'lucide-react'

interface ReservaRow {
  id: string
  data_reserva: string
  status: string
  created_at: string
  areas_comuns: { tipo_agenda: string }
  perfil: { nome_completo: string; bloco_txt: string; apto_txt: string; papel_sistema: string }
}

interface Props {
  reservas: ReservaRow[]
  tiposAgenda: string[]
}

export default function ReservasAdminClient({ reservas: initial, tiposAgenda }: Props) {
  const [reservas, setReservas] = useState<ReservaRow[]>(initial)
  const [filterTipo, setFilterTipo] = useState('')
  const [filterStatus, setFilterStatus] = useState<'pendente' | 'aprovado' | ''>('pendente')
  const [updating, setUpdating] = useState<string | null>(null)

  const filtered = reservas.filter(r => {
    const tipoOk = !filterTipo || r.areas_comuns?.tipo_agenda === filterTipo
    const statusOk = !filterStatus || r.status === filterStatus
    return tipoOk && statusOk
  })

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

  const statusBadge = (s: string) => {
    const map: Record<string, string> = {
      pendente: 'bg-yellow-100 text-yellow-700',
      aprovado: 'bg-green-100 text-green-700',
      reprovado: 'bg-red-100 text-red-700',
      cancelado: 'bg-gray-100 text-gray-500',
    }
    return map[s] ?? 'bg-gray-100 text-gray-500'
  }

  return (
    <div className="max-w-5xl">
      <div className="flex items-center gap-3 mb-6">
        <ClipboardList size={22} className="text-[#FC5931]" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Aprovar Reservas</h1>
          <p className="text-sm text-gray-500">Gerencie as solicitações de reserva dos moradores.</p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 mb-6 bg-white rounded-2xl border border-gray-100 p-4">
        <select
          value={filterTipo}
          onChange={e => setFilterTipo(e.target.value)}
          className="border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
        >
          <option value="">Todos os tipos</option>
          {tiposAgenda.map(t => <option key={t}>{t}</option>)}
        </select>

        <div className="flex rounded-xl border border-gray-200 overflow-hidden">
          {[
            { val: 'pendente', label: 'Pendentes' },
            { val: 'aprovado', label: 'Aprovados' },
            { val: '', label: 'Todos' },
          ].map(b => (
            <button
              key={b.val}
              onClick={() => setFilterStatus(b.val as typeof filterStatus)}
              className={`px-4 py-2 text-sm font-medium transition-colors ${
                filterStatus === b.val
                  ? 'bg-[#FC5931] text-white'
                  : 'text-gray-600 hover:bg-gray-50'
              }`}
            >
              {b.label}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      {filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-2xl border border-gray-100">
          <ClipboardList size={40} className="mx-auto mb-3 text-gray-200" />
          <p className="text-gray-400 text-sm">Nenhuma reserva encontrada.</p>
          <p className="text-gray-300 text-xs mt-1">As reservas aparecerão aqui quando os moradores fizerem solicitações.</p>
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-[#FC5931] text-white">
                <th className="text-left px-4 py-3 font-semibold">Tipo Agenda</th>
                <th className="text-left px-4 py-3 font-semibold">Nome do Evento</th>
                <th className="px-4 py-3 font-semibold">Data</th>
                <th className="text-left px-4 py-3 font-semibold">Usuário</th>
                <th className="px-4 py-3 font-semibold">Apto/Bloco</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold text-center">Ações</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((r, idx) => (
                <tr key={r.id} className={`border-b border-gray-50 ${idx % 2 === 1 ? 'bg-gray-50/50' : ''}`}>
                  <td className="px-4 py-3 font-medium text-gray-900">
                    {r.areas_comuns?.tipo_agenda ?? '—'}
                  </td>
                  <td className="px-4 py-3 text-gray-700">
                    {r.areas_comuns?.tipo_agenda ?? '—'}
                  </td>
                  <td className="px-4 py-3 text-center text-gray-600">
                    {new Date(r.data_reserva).toLocaleDateString('pt-BR')}
                  </td>
                  <td className="px-4 py-3 text-gray-700">
                    {r.perfil?.nome_completo ?? '—'}
                  </td>
                  <td className="px-4 py-3 text-center text-gray-600">
                    {r.perfil ? `Apto: ${r.perfil.apto_txt} / Bloco: ${r.perfil.bloco_txt}` : '—'}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusBadge(r.status)}`}>
                      {r.status}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    {r.status === 'pendente' && (
                      <div className="flex items-center justify-center gap-2">
                        <button
                          onClick={() => setStatus(r.id, 'aprovado')}
                          disabled={updating === r.id}
                          className="flex items-center gap-1 text-xs bg-green-100 text-green-700 hover:bg-green-200 px-3 py-1.5 rounded-lg transition-colors disabled:opacity-50"
                        >
                          <Check size={13} /> Aprovar
                        </button>
                        <button
                          onClick={() => setStatus(r.id, 'reprovado')}
                          disabled={updating === r.id}
                          className="flex items-center gap-1 text-xs bg-red-100 text-red-600 hover:bg-red-200 px-3 py-1.5 rounded-lg transition-colors disabled:opacity-50"
                        >
                          <X size={13} /> Reprovar
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="text-xs text-gray-400 text-center py-3">
            {filtered.length} reserva{filtered.length !== 1 ? 's' : ''}
          </p>
        </div>
      )}
    </div>
  )
}
