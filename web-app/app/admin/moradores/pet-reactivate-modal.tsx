'use client'

import { useState, useEffect } from 'react'
import { X, AlertCircle, Loader2, RefreshCw, PawPrint } from 'lucide-react'
import { adminReactivatePet } from '@/app/admin/actions'
import { PetData } from './[id]/resident-360-client'

interface PetReactivateModalProps {
  isOpen: boolean
  onClose: () => void
  pet: PetData | null
  profileId: string
  residentName: string
  onSuccess: () => void
}

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

export default function PetReactivateModal({
  isOpen,
  onClose,
  pet,
  profileId,
  residentName,
  onSuccess,
}: PetReactivateModalProps) {
  const [motivo, setMotivo] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!isOpen) return
    setMotivo('')
    setError(null)
    setLoading(false)
  }, [isOpen, pet])

  if (!isOpen || !pet) return null

  async function handleReactivate() {
    if (loading || !pet) return
    setLoading(true)
    setError(null)

    try {
      const res = await adminReactivatePet({
        petId: pet.id,
        profileId,
        motivo: motivo.trim() || undefined,
      })

      if (res.error) {
        setError(res.error)
        setLoading(false)
        return
      }

      onSuccess()
      onClose()
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Erro ao reativar pet.')
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
              <h2 className="text-base font-bold text-gray-900">Reativar Pet</h2>
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

        {/* Content Body */}
        <div className="p-6 space-y-4">
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
                Unidade Atual: Bloco {pet.unidade_bloco || '—'} · Apto {pet.unidade_apto || '—'}
              </p>
            )}
          </div>

          <div className="p-3.5 rounded-xl bg-emerald-50/70 border border-emerald-200/80 text-xs text-emerald-900 leading-relaxed">
            <p className="font-semibold mb-1">Confirmação de Reativação:</p>
            <p>
              Ao reativar o pet, seu registro voltará ao status ATIVO e suas ações administrativas de edição e transferência de unidade serão restauradas.
            </p>
          </div>

          {/* Observação / Motivo Opcional */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">
              Observação / Motivo da Reativação <span className="text-gray-400 font-normal">(opcional)</span>
            </label>
            <input
              type="text"
              value={motivo}
              onChange={e => setMotivo(e.target.value)}
              disabled={loading}
              placeholder="Ex: Pet retornou a residir com o morador"
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
              type="button"
              onClick={handleReactivate}
              disabled={loading}
              className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold transition-colors disabled:opacity-50 shadow-2xs"
            >
              {loading && <Loader2 size={14} className="animate-spin" />}
              Confirmar Reativação
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
