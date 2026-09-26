'use client'

import { useState, useEffect, useMemo } from 'react'
import {
  X,
  ArrowRightLeft,
  Home,
  AlertTriangle,
  Loader2,
  CheckCircle,
  Building2,
  Users,
} from 'lucide-react'
import {
  adminGetResidentLinkContext,
  adminGetUnitOccupancy,
  adminTransferirUnidadeMorador,
} from '@/app/admin/actions'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

interface TransferirUnidadeModalProps {
  isOpen: boolean
  onClose: () => void
  profileId?: string
  residentId?: string
  condominioId?: string
  residentName: string
  activeUnit?: {
    id: string
    unidade_id: string
    bloco_nome?: string | null
    apto_numero?: string | null
    data_entrada?: string | null
  }
  currentUnit?: {
    id: string
    unidade_id: string
    bloco_nome?: string | null
    apto_numero?: string | null
    data_entrada?: string | null
  }
  tipoEstrutura?: string
  blocoLabel?: string
  aptoLabel?: string
  onSuccess: () => void
}

export default function TransferirUnidadeModal({
  isOpen,
  onClose,
  profileId,
  residentId,
  condominioId,
  residentName,
  activeUnit,
  currentUnit: providedCurrentUnit,
  tipoEstrutura = 'predio',
  blocoLabel: customBlocoLabel,
  aptoLabel: customAptoLabel,
  onSuccess,
}: TransferirUnidadeModalProps) {
  const targetResidentId = profileId || residentId || ''
  const currentUnit = activeUnit || providedCurrentUnit || { id: '', unidade_id: '' }
  const blocoLabel = customBlocoLabel || getBlocoLabel(tipoEstrutura)
  const aptoLabel = customAptoLabel || getAptoLabel(tipoEstrutura)

  // Estados de dados do condomínio
  const [loadingContext, setLoadingContext] = useState(true)
  const [contextError, setContextError] = useState<string | null>(null)
  const [blocos, setBlocos] = useState<Array<{ id: string; nome_ou_numero: string }>>([])
  const [units, setUnits] = useState<Array<{ id: string; bloco_id: string; numero: string }>>([])

  // Formulário
  const [selectedBlocoId, setSelectedBlocoId] = useState('')
  const [selectedUnidadeId, setSelectedUnidadeId] = useState('')
  const [dataTransferencia, setDataTransferencia] = useState(() => {
    return new Date().toISOString().split('T')[0]
  })
  const [motivo, setMotivo] = useState('')

  // Ocupação da unidade destino
  const MAX_OCUPANTES_UNIDADE = 4
  const [unitOccupancy, setUnitOccupancy] = useState<number | null>(null)
  const [loadingOccupancy, setLoadingOccupancy] = useState(false)
  const [occupancyError, setOccupancyError] = useState<string | null>(null)
  const isCapacidadeEsgotada = unitOccupancy !== null && unitOccupancy >= MAX_OCUPANTES_UNIDADE

  // Submissão
  const [submitting, setSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  // Carregar blocos e unidades ao abrir modal
  useEffect(() => {
    let isMounted = true

    async function loadData() {
      if (!isOpen || !targetResidentId) return
      setLoadingContext(true)
      setContextError(null)
      setErrorMessage(null)
      setSelectedBlocoId('')
      setSelectedUnidadeId('')
      setUnitOccupancy(null)
      setMotivo('')

      try {
        const res = await adminGetResidentLinkContext(targetResidentId)
        if (!isMounted) return

        if (res.error) {
          setContextError(res.error)
          setLoadingContext(false)
          return
        }

        setBlocos(res.blocos || [])
        setUnits(res.units || [])
        setLoadingContext(false)
      } catch (err: unknown) {
        if (!isMounted) return
        console.error('[TransferirUnidadeModal] Erro ao carregar contexto:', err)
        setContextError('Falha ao carregar blocos e unidades do condomínio.')
        setLoadingContext(false)
      }
    }

    loadData()

    return () => {
      isMounted = false
    }
  }, [isOpen, targetResidentId])

  // Filtrar unidades pelo bloco selecionado, excluindo a unidade atual
  const filteredUnits = useMemo(() => {
    if (!selectedBlocoId) return []
    return units.filter((u) => u.bloco_id === selectedBlocoId && u.id !== currentUnit.unidade_id)
  }, [units, selectedBlocoId, currentUnit.unidade_id])

  // Consultar ocupação da unidade de destino quando selecionada
  useEffect(() => {
    let isMounted = true

    async function checkOccupancy() {
      if (!selectedUnidadeId) {
        setUnitOccupancy(null)
        setOccupancyError(null)
        return
      }

      setLoadingOccupancy(true)
      setOccupancyError(null)

      try {
        const res = await adminGetUnitOccupancy(selectedUnidadeId)
        if (!isMounted) return

        if (res.error) {
          setOccupancyError(res.error)
          setUnitOccupancy(null)
        } else {
          setUnitOccupancy(res.ocupacao ?? 0)
        }
      } catch (err) {
        if (!isMounted) return
        setOccupancyError('Erro ao verificar ocupação.')
      } finally {
        if (isMounted) setLoadingOccupancy(false)
      }
    }

    checkOccupancy()

    return () => {
      isMounted = false
    }
  }, [selectedUnidadeId])

  if (!isOpen) return null

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)

    if (!selectedUnidadeId) {
      setErrorMessage('Selecione a nova unidade de destino.')
      return
    }

    if (selectedUnidadeId === currentUnit.unidade_id) {
      setErrorMessage('A unidade de destino deve ser diferente da unidade atual.')
      return
    }

    if (isCapacidadeEsgotada) {
      setErrorMessage('A unidade de destino já atingiu o limite de 4 ocupantes.')
      return
    }

    if (!dataTransferencia.trim()) {
      setErrorMessage('A data de transferência é obrigatória.')
      return
    }

    if (!motivo.trim() || motivo.trim().length < 3) {
      setErrorMessage('O motivo da transferência é obrigatório (mínimo de 3 caracteres).')
      return
    }

    setSubmitting(true)
    try {
      const res = await adminTransferirUnidadeMorador({
        residentId: targetResidentId,
        novaUnidadeId: selectedUnidadeId,
        dataTransferencia: `${dataTransferencia}T12:00:00Z`,
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
      console.error('[TransferirUnidadeModal] Erro ao submeter:', err)
      setErrorMessage(err instanceof Error ? err.message : 'Erro ao transferir unidade do morador.')
      setSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="relative w-full max-w-lg bg-white rounded-2xl shadow-2xl border border-gray-100 overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-100 bg-gray-50/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[#FC5931]/10 border border-[#FC5931]/20 flex items-center justify-center text-[#FC5931]">
              <ArrowRightLeft size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Transferir de Unidade</h2>
              <p className="text-xs text-gray-500">Mudança interna de residência no condomínio</p>
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
        {loadingContext ? (
          <div className="p-12 text-center">
            <Loader2 size={28} className="animate-spin text-[#FC5931] mx-auto mb-2" />
            <p className="text-xs text-gray-500">Carregando estrutura do condomínio...</p>
          </div>
        ) : contextError ? (
          <div className="p-6 text-center space-y-3">
            <AlertTriangle size={24} className="text-red-500 mx-auto" />
            <p className="text-sm text-red-700 font-semibold">{contextError}</p>
            <button
              onClick={onClose}
              className="px-4 py-2 text-xs font-semibold bg-gray-100 text-gray-700 rounded-xl"
            >
              Fechar
            </button>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="p-6 space-y-4">
            {errorMessage && (
              <div className="p-3.5 rounded-xl bg-red-50 border border-red-200 text-xs text-red-700 flex items-start gap-2">
                <AlertTriangle size={15} className="text-red-500 shrink-0 mt-0.5" />
                <span>{errorMessage}</span>
              </div>
            )}

            {/* Unidade Atual Read-Only */}
            <div className="p-3.5 bg-gray-50 rounded-xl border border-gray-200/60 space-y-1.5 text-xs">
              <div className="flex items-center justify-between">
                <span className="text-gray-500 font-medium">Morador:</span>
                <span className="font-bold text-gray-900">{residentName}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-gray-500 font-medium">Unidade atual (origem):</span>
                <span className="font-bold text-gray-900 flex items-center gap-1.5">
                  <Home size={13} className="text-gray-500" />
                  {blocoLabel} {currentUnit.bloco_nome || '—'} · {aptoLabel} {currentUnit.apto_numero || '—'}
                </span>
              </div>
            </div>

            {/* Seleção do Novo Bloco e Nova Unidade */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1.5">
                  Novo {blocoLabel} <span className="text-red-500">*</span>
                </label>
                <select
                  required
                  value={selectedBlocoId}
                  onChange={(e) => {
                    setSelectedBlocoId(e.target.value)
                    setSelectedUnidadeId('')
                  }}
                  disabled={submitting}
                  className="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-2 focus:ring-[#FC5931]/10 outline-none transition-all bg-white"
                >
                  <option value="">Selecione o {blocoLabel}...</option>
                  {blocos.map((b) => (
                    <option key={b.id} value={b.id}>
                      {blocoLabel} {b.nome_ou_numero}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1.5">
                  Nova {aptoLabel} <span className="text-red-500">*</span>
                </label>
                <select
                  required
                  value={selectedUnidadeId}
                  onChange={(e) => setSelectedUnidadeId(e.target.value)}
                  disabled={submitting || !selectedBlocoId}
                  className="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-2 focus:ring-[#FC5931]/10 outline-none transition-all bg-white disabled:bg-gray-50 disabled:text-gray-400"
                >
                  <option value="">
                    {!selectedBlocoId ? `Selecione primeiro o ${blocoLabel}` : `Selecione a ${aptoLabel}...`}
                  </option>
                  {filteredUnits.map((u) => (
                    <option key={u.id} value={u.id}>
                      {aptoLabel} {u.numero}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            {/* Indicador de Capacidade / Ocupação da Nova Unidade */}
            {selectedUnidadeId && (
              <div
                className={`p-3 rounded-xl border text-xs flex items-center justify-between transition-all ${
                  loadingOccupancy
                    ? 'bg-gray-50 border-gray-200 text-gray-500'
                    : isCapacidadeEsgotada
                    ? 'bg-red-50 border-red-200 text-red-700'
                    : 'bg-emerald-50/80 border-emerald-200 text-emerald-800'
                }`}
              >
                <div className="flex items-center gap-2">
                  <Users size={15} />
                  <span>Ocupação do destino:</span>
                </div>
                {loadingOccupancy ? (
                  <span className="flex items-center gap-1">
                    <Loader2 size={12} className="animate-spin" /> Verificando...
                  </span>
                ) : occupancyError ? (
                  <span className="text-red-600">{occupancyError}</span>
                ) : (
                  <div className="flex items-center gap-2">
                    <span className="font-bold">
                      {unitOccupancy} / {MAX_OCUPANTES_UNIDADE} pessoas
                    </span>
                    {isCapacidadeEsgotada ? (
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-red-600 text-white uppercase">
                        Capacidade Esgotada
                      </span>
                    ) : (
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-600 text-white uppercase">
                        Disponível
                      </span>
                    )}
                  </div>
                )}
              </div>
            )}

            {/* Data da Transferência */}
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1.5">
                Data da Transferência <span className="text-red-500">*</span>
              </label>
              <input
                type="date"
                required
                value={dataTransferencia}
                onChange={(e) => setDataTransferencia(e.target.value)}
                disabled={submitting}
                className="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-2 focus:ring-[#FC5931]/10 outline-none transition-all"
              />
              <p className="text-[11px] text-gray-400 mt-1">
                Data efetiva da saída da unidade anterior e ingresso na nova unidade.
              </p>
            </div>

            {/* Motivo da Transferência */}
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1.5">
                Motivo da Transferência <span className="text-red-500">*</span>
              </label>
              <textarea
                required
                rows={3}
                value={motivo}
                onChange={(e) => setMotivo(e.target.value)}
                placeholder="Informe a justificativa da troca de unidade residencial (ex: morador adquiriu novo apartamento)..."
                disabled={submitting}
                className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-2 focus:ring-[#FC5931]/10 outline-none resize-none transition-all"
              />
              <p className="text-[11px] text-gray-400 mt-1">
                O histórico residencial anterior será preservado e auditado compulsoriamente como UNIT_TRANSFERRED.
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
                disabled={submitting || isCapacidadeEsgotada || !selectedUnidadeId}
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-semibold text-white bg-[#FC5931] hover:bg-[#e04820] disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm"
              >
                {submitting ? (
                  <>
                    <Loader2 size={13} className="animate-spin" />
                    Transferindo...
                  </>
                ) : (
                  <>
                    <CheckCircle size={13} />
                    Confirmar Transferência
                  </>
                )}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}
