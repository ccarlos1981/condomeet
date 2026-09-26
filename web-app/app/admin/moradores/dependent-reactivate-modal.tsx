'use client'

import { useState, useEffect } from 'react'
import { X, AlertCircle, Loader2, RefreshCw } from 'lucide-react'
import { adminReativarDependente } from '@/app/admin/actions'
import { DependenteData } from './[id]/resident-360-client'

const PARENTESCO_LABELS: Record<string, string> = {
  filho: 'Filho(a)',
  conjuge_companheiro: 'Cônjuge / Companheiro(a)',
  pai_mae: 'Pai / Mãe',
  enteado: 'Enteado(a)',
  outro_familiar: 'Outro familiar',
  outro_dependente: 'Outro dependente',
}

interface DependentReactivateModalProps {
  isOpen: boolean
  onClose: () => void
  dependente: DependenteData | null
  profileId: string
  residentName: string
  onSuccess: () => void
}

const MOTIVO_MIN = 3
const MOTIVO_MAX = 300

export default function DependentReactivateModal({
  isOpen,
  onClose,
  dependente,
  profileId,
  residentName,
  onSuccess,
}: DependentReactivateModalProps) {
  const [motivo, setMotivo] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!isOpen) return
    setMotivo('')
    setError(null)
    setLoading(false)
  }, [isOpen, dependente])

  if (!isOpen || !dependente) return null

  const parentescoLabel = dependente.parentesco
    ? (PARENTESCO_LABELS[dependente.parentesco] || dependente.parentesco)
    : '—'

  async function handleReactivate() {
    if (loading || !dependente) return

    setError(null)

    const finalMotivo = motivo.trim()
    if (finalMotivo.length < MOTIVO_MIN) {
      setError(`O motivo deve ter no mínimo ${MOTIVO_MIN} caracteres.`)
      return
    }

    if (finalMotivo.length > MOTIVO_MAX) {
      setError(`O motivo não pode exceder ${MOTIVO_MAX} caracteres.`)
      return
    }

    setLoading(true)

    try {
      const res = await adminReativarDependente({
        dependenteId: dependente.id,
        profileId,
        motivo: finalMotivo,
      })

      if (res.error) {
        setError(res.error)
        setLoading(false)
        return
      }

      onSuccess()
      onClose()
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Erro ao reativar dependente.')
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="p-6 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
              <RefreshCw size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Reativar dependente</h2>
              <p className="text-xs text-gray-500">
                Responsável: <span className="font-semibold text-gray-700">{residentName}</span>
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="text-gray-400 hover:text-gray-600 p-1 rounded-lg hover:bg-gray-50 transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Content Body */}
        <div className="p-6 space-y-4">
          {error && (
            <div className="p-3.5 rounded-xl bg-red-50 border border-red-200 flex items-start gap-2.5 text-xs text-red-700">
              <AlertCircle size={16} className="shrink-0 mt-0.5 text-red-600" />
              <span>{error}</span>
            </div>
          )}

          {/* Resumo do Dependente */}
          <div className="p-4 rounded-xl bg-gray-50 border border-gray-200/80 space-y-1.5 text-xs text-gray-700">
            <div className="flex items-center justify-between">
              <span className="font-bold text-sm text-gray-900">
                {dependente.nome_completo}
              </span>
              <span className="text-gray-500 font-medium">
                {parentescoLabel}
              </span>
            </div>
          </div>

          <div className="p-3.5 rounded-xl bg-emerald-50/70 border border-emerald-200/80 text-xs text-emerald-900 leading-relaxed">
            <p className="font-semibold mb-1">Confirmação de Reativação:</p>
            <p>
              Ao reativar o dependente, seu registro voltará ao status ATIVO e as ações administrativas de edição serão restauradas.
            </p>
          </div>

          {/* Motivo Obrigatório */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">
              Motivo da Reativação *
            </label>
            <textarea
              value={motivo}
              onChange={e => {
                if (e.target.value.length <= MOTIVO_MAX) {
                  setMotivo(e.target.value)
                }
              }}
              disabled={loading}
              rows={2}
              placeholder="Ex: Dependente retornou a residir com o morador"
              className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
            />
            <div className="text-right mt-1">
              <span className={`text-[11px] font-medium ${motivo.length >= MOTIVO_MAX ? 'text-red-500' : 'text-gray-400'}`}>
                {motivo.length}/{MOTIVO_MAX}
              </span>
            </div>
          </div>

          {/* Footer Actions */}
          <div className="pt-2 flex items-center justify-end gap-2 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-gray-600 hover:bg-gray-100 transition-colors"
            >
              Cancelar
            </button>
            <button
              type="button"
              onClick={handleReactivate}
              disabled={loading || motivo.trim().length < MOTIVO_MIN}
              className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold transition-colors disabled:opacity-50 shadow-2xs"
            >
              {loading && <Loader2 size={14} className="animate-spin" />}
              Reativar dependente
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
