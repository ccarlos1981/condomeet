'use client'

import { useState, useEffect } from 'react'
import {
  X,
  Calendar,
  Home,
  AlertTriangle,
  Loader2,
  CheckCircle,
} from 'lucide-react'
import { adminCorrigirDatasVinculoMorador } from '@/app/admin/actions'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

function formatCivilDateForInput(dateStr?: string | null): string {
  if (!dateStr) return ''
  return dateStr.trim().split(/[T ]/)[0]
}

interface CorrigirVinculoModalProps {
  isOpen: boolean
  onClose: () => void
  profileId?: string
  residentId?: string
  residentName: string
  link: {
    id: string
    unidade_id: string
    status?: string | null
    data_entrada?: string | null
    data_saida?: string | null
    bloco_nome?: string | null
    apto_numero?: string | null
  } | null
  tipoEstrutura?: string
  blocoLabel?: string
  aptoLabel?: string
  onSuccess: () => void
}

export default function CorrigirVinculoModal({
  isOpen,
  onClose,
  profileId,
  residentId,
  residentName,
  link,
  tipoEstrutura = 'predio',
  blocoLabel: customBlocoLabel,
  aptoLabel: customAptoLabel,
  onSuccess,
}: CorrigirVinculoModalProps) {
  const targetResidentId = profileId || residentId || ''
  const blocoLabel = customBlocoLabel || getBlocoLabel(tipoEstrutura)
  const aptoLabel = customAptoLabel || getAptoLabel(tipoEstrutura)

  const [dataEntrada, setDataEntrada] = useState('')
  const [dataSaida, setDataSaida] = useState('')
  const [motivo, setMotivo] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    if (isOpen && link) {
      setDataEntrada(link.data_entrada ? formatCivilDateForInput(link.data_entrada) : '')
      setDataSaida(link.data_saida ? formatCivilDateForInput(link.data_saida) : '')
      setMotivo('')
      setErrorMessage(null)
    }
  }, [isOpen, link])

  if (!isOpen || !link) return null

  const isLinkActive = link.status === 'ativo'

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)

    if (!dataEntrada.trim()) {
      setErrorMessage('A data de entrada é obrigatória.')
      return
    }

    if (!isLinkActive && !dataSaida.trim()) {
      setErrorMessage('Para vínculos inativos (encerrados), a data de saída é obrigatória.')
      return
    }

    if (dataSaida.trim() && dataEntrada > dataSaida) {
      setErrorMessage('A data de entrada não pode ser posterior à data de saída.')
      return
    }

    if (!motivo.trim() || motivo.trim().length < 3) {
      setErrorMessage('O motivo da retificação é obrigatório (mínimo de 3 caracteres).')
      return
    }

    setSubmitting(true)
    try {
      const res = await adminCorrigirDatasVinculoMorador({
        vinculoId: link.id,
        residentId: targetResidentId,
        dataEntrada: `${dataEntrada}T12:00:00Z`,
        dataSaida: !isLinkActive && dataSaida.trim() ? `${dataSaida}T12:00:00Z` : null,
        motivo: motivo.trim(),
      })

      if (res.error) {
        setErrorMessage(res.error)
        setSubmitting(false)
        return
      }

      onSuccess()
      onClose()
    } catch (err: unknown) {
      console.error('[CorrigirVinculoModal] Erro ao submeter:', err)
      setErrorMessage(err instanceof Error ? err.message : 'Erro ao retificar vínculo.')
      setSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="relative w-full max-w-lg bg-white rounded-2xl shadow-2xl border border-gray-100 overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-100 bg-gray-50/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-600">
              <Calendar size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Corrigir Vínculo</h2>
              <p className="text-xs text-gray-500">Retificação material de datas de moradia</p>
            </div>
          </div>
          <button
            onClick={onClose}
            disabled={submitting}
            className="p-2 text-gray-400 hover:text-gray-600 rounded-xl hover:bg-gray-100 transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Content */}
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {errorMessage && (
            <div className="p-3.5 rounded-xl bg-red-50 border border-red-200 text-xs text-red-700 flex items-start gap-2">
              <AlertTriangle size={15} className="text-red-500 shrink-0 mt-0.5" />
              <span>{errorMessage}</span>
            </div>
          )}

          {/* Morador e Unidade Read-Only */}
          <div className="p-3.5 bg-gray-50 rounded-xl border border-gray-200/60 space-y-1.5 text-xs">
            <div className="flex items-center justify-between">
              <span className="text-gray-500 font-medium">Morador:</span>
              <span className="font-bold text-gray-900">{residentName}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-500 font-medium">Unidade vinculada:</span>
              <span className="font-bold text-gray-900 flex items-center gap-1.5">
                <Home size={13} className="text-[#FC5931]" />
                {blocoLabel} {link.bloco_nome || '—'} · {aptoLabel} {link.apto_numero || '—'}
              </span>
            </div>
            <div className="flex items-center justify-between pt-1 border-t border-gray-200/40">
              <span className="text-gray-500 font-medium">Situação do vínculo:</span>
              <span
                className={`px-2 py-0.5 rounded-full text-[11px] font-semibold ${
                  isLinkActive
                    ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                    : 'bg-gray-100 text-gray-600 border border-gray-200'
                }`}
              >
                {isLinkActive ? 'Vínculo Ativo (Vigente)' : 'Vínculo Histórico (Inativo)'}
              </span>
            </div>
          </div>

          {/* Campos de Data */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1.5">
                Data de Entrada <span className="text-red-500">*</span>
              </label>
              <input
                type="date"
                required
                value={dataEntrada}
                onChange={(e) => setDataEntrada(e.target.value)}
                disabled={submitting}
                className="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-2 focus:ring-[#FC5931]/10 outline-none transition-all"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1.5">
                Data de Saída {isLinkActive ? '(Vigente)' : <span className="text-red-500">*</span>}
              </label>
              {isLinkActive ? (
                <div className="px-3 py-2 text-xs text-gray-500 bg-gray-100 rounded-xl border border-gray-200 flex items-center h-[38px]">
                  Em aberto (vínculo vigente)
                </div>
              ) : (
                <input
                  type="date"
                  required
                  value={dataSaida}
                  onChange={(e) => setDataSaida(e.target.value)}
                  disabled={submitting}
                  className="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-2 focus:ring-[#FC5931]/10 outline-none transition-all"
                />
              )}
            </div>
          </div>

          {/* Motivo Obrigatório */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1.5">
              Motivo da Retificação <span className="text-red-500">*</span>
            </label>
            <textarea
              required
              rows={3}
              value={motivo}
              onChange={(e) => setMotivo(e.target.value)}
              placeholder="Descreva o motivo da correção das datas (ex: ajuste de data civil conforme contrato original)..."
              disabled={submitting}
              className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-2 focus:ring-[#FC5931]/10 outline-none resize-none transition-all"
            />
            <p className="text-[11px] text-gray-400 mt-1">
              Esta ação será auditada compulsoriamente no histórico administrativo deste morador.
            </p>
          </div>

          {/* Footer Buttons */}
          <div className="flex items-center justify-end gap-3 pt-3 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              disabled={submitting}
              className="px-4 py-2 text-xs font-semibold text-gray-600 hover:text-gray-800 rounded-xl hover:bg-gray-100 transition-colors"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-semibold text-white bg-amber-600 hover:bg-amber-700 disabled:opacity-50 transition-all shadow-sm"
            >
              {submitting ? (
                <>
                  <Loader2 size={13} className="animate-spin" />
                  Salvando...
                </>
              ) : (
                <>
                  <CheckCircle size={13} />
                  Salvar Correção
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
