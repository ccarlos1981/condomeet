'use client'

import { useState } from 'react'
import { ClipboardList, Check, X, Ban } from 'lucide-react'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

interface ReservaRow {
  id: string
  data_reserva: string
  status: string
  created_at: string
  user_id: string
  nome_evento?: string
  valor_reserva?: number
  status_pagamento?: string
  areas_comuns: { tipo_agenda: string; precos?: { valor: number; regra: string }[] }
  perfil: { nome_completo: string; bloco_txt: string; apto_txt: string; papel_sistema: string; whatsapp?: string; botconversa_id?: string }
}

const formatCurrency = (val: number) => {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
}

const getReservaValor = (areas_comuns: any) => {
  const precos = areas_comuns?.precos ?? []
  const p = precos.find((p: any) => p.valor > 0)
  return p ? formatCurrency(p.valor) : 'Gratuito'
}

interface Props {
  reservas: ReservaRow[]
  tiposAgenda: string[]
  tipoEstrutura?: string
}

export default function ReservasAdminClient({ reservas: initial, tiposAgenda, tipoEstrutura }: Props) {
  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)
  const [reservas, setReservas] = useState<ReservaRow[]>(initial)
  const [filterTipo, setFilterTipo] = useState('')
  const [filterStatus, setFilterStatus] = useState<'pendente' | 'aprovado' | ''>('pendente')
  const [updating, setUpdating] = useState<string | null>(null)
  const [cancelConfirm, setCancelConfirm] = useState<string | null>(null)

  const filtered = reservas.filter(r => {
    const tipoOk = !filterTipo || r.areas_comuns?.tipo_agenda === filterTipo
    const statusOk = !filterStatus || r.status === filterStatus
    return tipoOk && statusOk
  })

  // Check if a reservation date is in the future or today
  function isFutureOrToday(dateStr: string) {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const reservaDate = new Date(dateStr + 'T00:00:00')
    return reservaDate >= today
  }

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

      {/* Cancel confirmation modal */}
      {cancelConfirm && (() => {
        const reserva = reservas.find(r => r.id === cancelConfirm)
        if (!reserva) return null
        const dataFormatada = new Date(reserva.data_reserva + 'T00:00:00').toLocaleDateString('pt-BR')
        return (
          <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50" onClick={() => setCancelConfirm(null)}>
            <div className="bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-2xl" onClick={e => e.stopPropagation()}>
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
              {filtered.map((r, idx) => {
                const canCancel = r.status === 'aprovado' && isFutureOrToday(r.data_reserva)

                return (
                  <tr key={r.id} className={`border-b border-gray-50 ${idx % 2 === 1 ? 'bg-gray-50/50' : ''}`}>
                    <td className="px-4 py-3 font-medium text-gray-900">
                      {r.areas_comuns?.tipo_agenda ?? '—'}
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
                      {r.perfil ? `${r.perfil.apto_txt} / ${r.perfil.bloco_txt}` : '—'}
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
                        {r.status}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center justify-center gap-2">
                        {r.status === 'pendente' && (
                          <>
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
                          </>
                        )}
                        {canCancel && (
                          <button
                            onClick={() => setCancelConfirm(r.id)}
                            disabled={updating === r.id}
                            className="flex items-center gap-1 text-xs bg-orange-100 text-orange-700 hover:bg-orange-200 px-3 py-1.5 rounded-lg transition-colors disabled:opacity-50"
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
          <p className="text-xs text-gray-400 text-center py-3">
            {filtered.length} reserva{filtered.length !== 1 ? 's' : ''}
          </p>
        </div>
      )}
    </div>
  )
}
