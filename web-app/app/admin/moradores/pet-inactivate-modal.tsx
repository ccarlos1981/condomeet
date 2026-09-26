'use client'

import { useState, useEffect } from 'react'
import { X, AlertCircle, Loader2, PawPrint } from 'lucide-react'
import { adminInactivatePet } from '@/app/admin/actions'
import { PetData } from './[id]/resident-360-client'

interface PetInactivateModalProps {
  isOpen: boolean
  onClose: () => void
  pet: PetData | null
  profileId: string
  residentName: string
  onSuccess: () => void
}

const SUGESTOES_MOTIVO = [
  'Pet não reside mais no condomínio',
  'Mudança do animal',
  'Doação',
  'Falecimento',
  'Cadastro realizado incorretamente',
  'Outro motivo',
]

function formatEspecie(especie: string) {
  const map: Record<string, string> = {
    cao: 'Cão',
    gato: 'Gato',
    ave: 'Ave',
    roedor: 'Roedor',
    reptil: 'Réptil',
    peixe: 'Peixe',
    outro: 'Outro',
  }
  return map[especie] || especie
}

export default function PetInactivateModal({
  isOpen,
  onClose,
  pet,
  profileId,
  residentName,
  onSuccess,
}: PetInactivateModalProps) {
  const [motivo, setMotivo] = useState('')
  const [isOutro, setIsOutro] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!isOpen) return
    setMotivo('')
    setIsOutro(false)
    setError(null)
    setLoading(false)
  }, [isOpen, pet])

  if (!isOpen || !pet) return null

  function handleSelectSugestao(s: string) {
    if (s === 'Outro motivo') {
      setIsOutro(true)
      setMotivo('')
    } else {
      setIsOutro(false)
      setMotivo(s)
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (loading || !pet) return

    setError(null)

    const finalMotivo = motivo.trim()
    if (!finalMotivo) {
      setError(
        isOutro
          ? 'Por favor, descreva o motivo detalhado para a inativação do pet.'
          : 'O motivo da inativação é obrigatório para auditoria administrativa.'
      )
      return
    }

    if (isOutro && finalMotivo.toLowerCase() === 'outro motivo') {
      setError('Por favor, especifique o motivo em texto.')
      return
    }

    setLoading(true)

    try {
      const res = await adminInactivatePet({
        petId: pet.id,
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
      setError(err instanceof Error ? err.message : 'Erro ao inativar pet.')
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="p-6 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-red-50 text-red-600 flex items-center justify-center">
              <PawPrint size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Inativar Pet</h2>
              <p className="text-xs text-gray-500">
                Morador: <span className="font-semibold text-gray-700">{residentName}</span>
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

          {/* Resumo do Pet */}
          <div className="p-4 rounded-xl bg-gray-50 border border-gray-200/80 space-y-1.5 text-xs text-gray-700">
            <div className="flex items-center justify-between">
              <span className="font-bold text-sm text-gray-900">
                🐾 {pet.nome}
              </span>
              <span className="text-gray-500 font-medium">
                {formatEspecie(pet.especie)}
              </span>
            </div>
            {pet.raca && (
              <p className="text-gray-600">
                Raça: <span className="font-medium text-gray-800">{pet.raca}</span>
              </p>
            )}
            {(pet.unidade_bloco || pet.unidade_apto) && (
              <p className="text-gray-500">
                Unidade: Bloco {pet.unidade_bloco || '—'} · Apto {pet.unidade_apto || '—'}
              </p>
            )}
          </div>

          <div className="p-3 rounded-xl bg-amber-50/70 border border-amber-200/80 text-xs text-amber-800">
            O pet permanecerá no histórico do morador e não poderá ser editado enquanto estiver inativo.
          </div>

          {/* Sugestões Rápidas */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1.5">
              Sugestões de Motivo:
            </label>
            <div className="flex flex-wrap gap-1.5">
              {SUGESTOES_MOTIVO.map(s => {
                const isSelected = isOutro ? s === 'Outro motivo' : motivo === s
                return (
                  <button
                    key={s}
                    type="button"
                    onClick={() => handleSelectSugestao(s)}
                    className={`text-[11px] px-2.5 py-1 rounded-lg border transition-colors ${
                      isSelected
                        ? 'bg-red-50 text-red-700 border-red-300 font-semibold'
                        : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
                    }`}
                  >
                    {s}
                  </button>
                )
              })}
            </div>
          </div>

          {/* Motivo Obrigatório */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">
              Motivo da Inativação *
            </label>
            <textarea
              value={motivo}
              onChange={e => setMotivo(e.target.value)}
              disabled={loading}
              rows={2}
              placeholder={
                isOutro
                  ? 'Descreva obrigatoriamente o motivo da inativação...'
                  : 'Descreva ou selecione o motivo da inativação...'
              }
              className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
            />
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
              type="submit"
              disabled={loading}
              className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-red-600 hover:bg-red-700 text-white text-xs font-semibold transition-colors disabled:opacity-50 shadow-2xs"
            >
              {loading && <Loader2 size={14} className="animate-spin" />}
              Confirmar Inativação
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
