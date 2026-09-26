'use client'

import { useState, useEffect } from 'react'
import { X, AlertCircle, Loader2, ArrowRightLeft } from 'lucide-react'
import { adminTrocarResponsavelDependente } from '@/app/admin/actions'
import { DependenteData, CoResidentData } from './[id]/resident-360-client'

const PARENTESCO_LABELS: Record<string, string> = {
  filho: 'Filho(a)',
  conjuge_companheiro: 'Cônjuge / Companheiro(a)',
  pai_mae: 'Pai / Mãe',
  enteado: 'Enteado(a)',
  outro_familiar: 'Outro familiar',
  outro_dependente: 'Outro dependente',
}

interface DependentResponsibleModalProps {
  isOpen: boolean
  onClose: () => void
  dependente: DependenteData | null
  profileId: string
  residentName: string
  coResidents: CoResidentData[]
  onSuccess: () => void
}

const MOTIVO_MIN = 3
const MOTIVO_MAX = 300

export default function DependentResponsibleModal({
  isOpen,
  onClose,
  dependente,
  profileId,
  residentName,
  coResidents,
  onSuccess,
}: DependentResponsibleModalProps) {
  const [novoResponsavelId, setNovoResponsavelId] = useState('')
  const [motivo, setMotivo] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Filter candidates: exclude the current responsible (profileId)
  const candidates = coResidents.filter(co => co.id !== profileId)

  useEffect(() => {
    if (!isOpen) return
    setNovoResponsavelId(candidates.length > 0 ? candidates[0].id : '')
    setMotivo('')
    setError(null)
    setLoading(false)
  }, [isOpen, dependente])

  if (!isOpen || !dependente) return null

  const parentescoLabel = dependente.parentesco
    ? (PARENTESCO_LABELS[dependente.parentesco] || dependente.parentesco)
    : '—'

  const noCandidates = candidates.length === 0

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (loading || !dependente) return

    setError(null)

    if (!novoResponsavelId) {
      setError('Selecione o novo responsável.')
      return
    }

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
      const res = await adminTrocarResponsavelDependente({
        dependenteId: dependente.id,
        profileId,
        novoResponsavelPerfilId: novoResponsavelId,
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
      setError(err instanceof Error ? err.message : 'Erro ao trocar responsável do dependente.')
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="p-6 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
              <ArrowRightLeft size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Trocar responsável</h2>
              <p className="text-xs text-gray-500">
                Responsável atual: <span className="font-semibold text-gray-700">{residentName}</span>
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

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
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

          {noCandidates ? (
            <div className="p-3.5 bg-amber-50 border border-amber-200 rounded-xl flex items-start gap-2.5 text-xs text-amber-800">
              <AlertCircle size={16} className="text-amber-600 shrink-0 mt-0.5" />
              <div>
                Não há outro morador disponível nesta unidade para assumir a responsabilidade.
              </div>
            </div>
          ) : (
            <>
              {/* Novo Responsável */}
              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1.5">
                  Novo responsável *
                </label>
                <select
                  value={novoResponsavelId}
                  onChange={(e) => setNovoResponsavelId(e.target.value)}
                  disabled={loading}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all"
                  required
                >
                  {candidates.map((co) => (
                    <option key={co.id} value={co.id}>
                      {co.nome_completo || 'Morador sem nome'}{co.tipo_morador ? ` — ${co.tipo_morador}` : ''}
                    </option>
                  ))}
                </select>
              </div>

              {/* Motivo Obrigatório */}
              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">
                  Motivo da transferência *
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
                  placeholder="Ex: Novo titular da unidade assumiu a responsabilidade"
                  className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
                />
                <div className="text-right mt-1">
                  <span className={`text-[11px] font-medium ${motivo.length >= MOTIVO_MAX ? 'text-red-500' : 'text-gray-400'}`}>
                    {motivo.length}/{MOTIVO_MAX}
                  </span>
                </div>
              </div>
            </>
          )}

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
              type="submit"
              disabled={loading || noCandidates || motivo.trim().length < MOTIVO_MIN}
              className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold transition-colors disabled:opacity-50 shadow-2xs"
            >
              {loading && <Loader2 size={14} className="animate-spin" />}
              Confirmar transferência
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
