'use client'

import { useState, useEffect } from 'react'
import { X, Users, AlertCircle, Loader2, Info } from 'lucide-react'
import { adminCadastrarDependente, adminAtualizarDependente } from '@/app/admin/actions'
import { DependenteData } from './[id]/resident-360-client'

export const PARENTESCOS_DEPENDENTE = [
  { value: 'filho', label: 'Filho(a)' },
  { value: 'conjuge_companheiro', label: 'Cônjuge / Companheiro(a)' },
  { value: 'pai_mae', label: 'Pai / Mãe' },
  { value: 'enteado', label: 'Enteado(a)' },
  { value: 'outro_familiar', label: 'Outro familiar' },
  { value: 'outro_dependente', label: 'Outro dependente' },
]

interface DependentModalProps {
  isOpen: boolean
  onClose: () => void
  profileId: string
  unitId: string
  residentName: string
  editingDependente?: DependenteData | null
  onSuccess: () => void
}

export default function DependentModal({
  isOpen,
  onClose,
  profileId,
  unitId,
  residentName,
  editingDependente,
  onSuccess,
}: DependentModalProps) {
  const isEditing = Boolean(editingDependente)

  // Form State
  const [nomeCompleto, setNomeCompleto] = useState('')
  const [parentesco, setParentesco] = useState('filho')
  const [dataNascimento, setDataNascimento] = useState('')
  const [observacao, setObservacao] = useState('')

  // Submission State
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const todayStr = new Date().toISOString().split('T')[0]
  const OBS_MAX_LENGTH = 500

  // Protection flags for EDIT mode
  const isInactive = isEditing && editingDependente?.status !== 'ativo'
  const isConverted = isEditing && editingDependente?.perfil_convertido_id != null

  const isEditBlocked = isInactive || isConverted

  useEffect(() => {
    if (!isOpen) return

    setError(null)
    setLoading(false)

    if (editingDependente) {
      setNomeCompleto(editingDependente.nome_completo || '')
      setParentesco(editingDependente.parentesco || 'filho')
      setDataNascimento(editingDependente.data_nascimento ? editingDependente.data_nascimento.split('T')[0] : '')
      setObservacao(editingDependente.observacao || '')
    } else {
      setNomeCompleto('')
      setParentesco('filho')
      setDataNascimento('')
      setObservacao('')
    }
  }, [isOpen, editingDependente])

  if (!isOpen) return null

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (loading) return

    setError(null)

    if (!nomeCompleto.trim()) {
      setError('O nome completo do dependente é obrigatório.')
      return
    }

    if (!parentesco) {
      setError('O parentesco é obrigatório.')
      return
    }

    if (!dataNascimento) {
      setError('A data de nascimento é obrigatória.')
      return
    }

    if (dataNascimento > todayStr) {
      setError('A data de nascimento não pode estar no futuro.')
      return
    }

    if (observacao.length > OBS_MAX_LENGTH) {
      setError(`A observação não pode exceder ${OBS_MAX_LENGTH} caracteres.`)
      return
    }

    if (isEditBlocked) {
      setError('Não é possível editar este dependente no estado atual.')
      return
    }

    setLoading(true)

    try {
      if (isEditing && editingDependente) {
        const res = await adminAtualizarDependente({
          dependenteId: editingDependente.id,
          profileId,
          nomeCompleto: nomeCompleto.trim(),
          parentesco: parentesco || null,
          dataNascimento: dataNascimento || null,
          observacao: observacao.trim() || null,
        })

        if (res.error) {
          setError(res.error)
          setLoading(false)
          return
        }
      } else {
        const res = await adminCadastrarDependente({
          profileId,
          unidadeId: unitId,
          nomeCompleto: nomeCompleto.trim(),
          parentesco: parentesco || null,
          dataNascimento: dataNascimento || null,
          observacao: observacao.trim() || null,
        })

        if (res.error) {
          setError(res.error)
          setLoading(false)
          return
        }
      }

      onSuccess()
      onClose()
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Erro ao processar dependente.')
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg overflow-hidden border border-gray-100 flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between bg-gray-50/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-orange-100 flex items-center justify-center text-[#FC5931]">
              <Users size={20} />
            </div>
            <div>
              <h3 className="font-bold text-gray-900 text-base">
                {isEditing ? 'Editar dependente' : 'Adicionar dependente'}
              </h3>
              <p className="text-xs text-gray-500">
                Responsável: <span className="font-semibold text-gray-700">{residentName}</span>
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            disabled={loading}
            className="text-gray-400 hover:text-gray-600 p-2 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-6 space-y-4">
          {error && (
            <div className="p-3.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2.5 text-xs text-red-700 animate-in fade-in">
              <AlertCircle size={16} className="text-red-500 shrink-0 mt-0.5" />
              <div className="flex-1 font-medium">{error}</div>
            </div>
          )}

          {isInactive && (
            <div className="p-3.5 bg-amber-50 border border-amber-200 rounded-xl flex items-start gap-2.5 text-xs text-amber-800">
              <AlertCircle size={16} className="text-amber-600 shrink-0 mt-0.5" />
              <div>
                <strong>Dependente inativo.</strong> Não é possível editar um dependente com status inativo. Reative-o antes de realizar alterações.
              </div>
            </div>
          )}

          {isConverted && (
            <div className="p-3.5 bg-blue-50 border border-blue-200 rounded-xl flex items-start gap-2.5 text-xs text-blue-800">
              <Info size={16} className="text-blue-600 shrink-0 mt-0.5" />
              <div>
                <strong>Dependente convertido em morador.</strong> Este dependente já possui um perfil próprio no sistema e não pode mais ser editado como dependente.
              </div>
            </div>
          )}

          {/* Nome Completo */}
          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
              Nome completo <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              placeholder="Ex: Maria Luísa Santos"
              value={nomeCompleto}
              onChange={(e) => setNomeCompleto(e.target.value)}
              disabled={loading || isEditBlocked}
              className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all disabled:bg-gray-50 disabled:text-gray-400"
              required
            />
          </div>

          {/* Parentesco */}
          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
              Parentesco <span className="text-red-500">*</span>
            </label>
            <select
              value={parentesco}
              onChange={(e) => setParentesco(e.target.value)}
              disabled={loading || isEditBlocked}
              className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all disabled:bg-gray-50 disabled:text-gray-400"
              required
            >
              {PARENTESCOS_DEPENDENTE.map((p) => (
                <option key={p.value} value={p.value}>
                  {p.label}
                </option>
              ))}
            </select>
          </div>

          {/* Data de Nascimento */}
          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
              Data de nascimento <span className="text-red-500">*</span>
            </label>
            <input
              type="date"
              max={todayStr}
              value={dataNascimento}
              onChange={(e) => setDataNascimento(e.target.value)}
              disabled={loading || isEditBlocked}
              className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all disabled:bg-gray-50 disabled:text-gray-400"
              required
            />
          </div>

          {/* Observação */}
          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
              Observação <span className="text-gray-400 font-normal">(Opcional)</span>
            </label>
            <textarea
              rows={2}
              placeholder="Ex: Necessidades especiais, alergias, informações relevantes."
              value={observacao}
              onChange={(e) => {
                if (e.target.value.length <= OBS_MAX_LENGTH) {
                  setObservacao(e.target.value)
                }
              }}
              disabled={loading || isEditBlocked}
              className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all resize-none disabled:bg-gray-50 disabled:text-gray-400"
            />
            <div className="text-right mt-1">
              <span className={`text-[11px] font-medium ${observacao.length >= OBS_MAX_LENGTH ? 'text-red-500' : 'text-gray-400'}`}>
                {observacao.length}/{OBS_MAX_LENGTH}
              </span>
            </div>
          </div>

          {/* Footer Actions */}
          <div className="pt-3 border-t border-gray-100 flex items-center justify-end gap-2.5">
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
              disabled={loading || isEditBlocked}
              className="px-5 py-2 rounded-xl text-xs font-bold text-white bg-[#FC5931] hover:bg-[#FC5931]/90 transition-all shadow-sm flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <>
                  <Loader2 size={14} className="animate-spin" />
                  Salvando...
                </>
              ) : isEditing ? (
                'Salvar alterações'
              ) : (
                'Adicionar'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
