'use client'

import { useState, useEffect } from 'react'
import { X, AlertCircle, Loader2, ArrowRightLeft, PawPrint } from 'lucide-react'
import { adminTransferPetUnit } from '@/app/admin/actions'
import { PetData } from './[id]/resident-360-client'

interface PetUnitModalProps {
  isOpen: boolean
  onClose: () => void
  pet: PetData | null
  profileId: string
  residentName: string
  activeUnits: Array<{
    id: string
    unidade_id: string
    bloco_nome?: string | null
    apto_numero?: string | null
  }>
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

export default function PetUnitModal({
  isOpen,
  onClose,
  pet,
  profileId,
  residentName,
  activeUnits,
  onSuccess,
}: PetUnitModalProps) {
  // Candidate units: active units of the resident excluding the pet's current unit
  const candidateUnits = activeUnits.filter(
    u => u.unidade_id !== pet?.unidade_id
  )

  const [selectedUnitId, setSelectedUnitId] = useState('')
  const [motivo, setMotivo] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!isOpen) return
    setSelectedUnitId(candidateUnits.length > 0 ? candidateUnits[0].unidade_id : '')
    setMotivo('')
    setError(null)
    setLoading(false)
  }, [isOpen, pet])

  if (!isOpen || !pet) return null

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (loading || !pet) return

    if (!selectedUnitId) {
      setError('Selecione a nova unidade do pet.')
      return
    }

    if (selectedUnitId === pet.unidade_id) {
      setError('A nova unidade deve ser diferente da unidade atual.')
      return
    }

    setLoading(true)
    setError(null)

    try {
      const res = await adminTransferPetUnit({
        petId: pet.id,
        profileId,
        novaUnidadeId: selectedUnitId,
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
      setError(err instanceof Error ? err.message : 'Erro ao alterar unidade do pet.')
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="p-6 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-orange-50 text-[#FC5931] flex items-center justify-center">
              <ArrowRightLeft size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Alterar Unidade do Pet</h2>
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
          <div className="p-4 rounded-xl bg-gray-50 border border-gray-200/80 space-y-1 text-xs text-gray-700">
            <div className="flex items-center justify-between">
              <span className="font-bold text-sm text-gray-900">
                🐾 {pet.nome}
              </span>
              <span className="text-gray-500 font-medium">
                {formatEspecie(pet.especie)}
              </span>
            </div>
            <p className="text-gray-500">
              Unidade atual: <span className="font-semibold text-gray-800">Bloco {pet.unidade_bloco || '—'} · Apto {pet.unidade_apto || '—'}</span>
            </p>
          </div>

          {candidateUnits.length === 0 ? (
            <div className="p-3.5 rounded-xl bg-amber-50 border border-amber-200 text-xs text-amber-800">
              O morador não possui outra unidade ativa vinculada para transferência.
            </div>
          ) : (
            <>
              {/* Seleção de Nova Unidade */}
              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">
                  Nova Unidade Residencial *
                </label>
                <select
                  value={selectedUnitId}
                  onChange={e => setSelectedUnitId(e.target.value)}
                  disabled={loading}
                  className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
                >
                  <option value="" disabled>
                    Selecione a nova unidade
                  </option>
                  {candidateUnits.map(u => (
                    <option key={u.unidade_id} value={u.unidade_id}>
                      Bloco {u.bloco_nome || '—'} · Apto {u.apto_numero || '—'}
                    </option>
                  ))}
                </select>
              </div>

              {/* Motivo Opcional */}
              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">
                  Motivo da Transferência <span className="text-gray-400 font-normal">(opcional)</span>
                </label>
                <input
                  type="text"
                  value={motivo}
                  onChange={e => setMotivo(e.target.value)}
                  disabled={loading}
                  placeholder="Ex: Mudança de apartamento dentro do condomínio"
                  className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
                />
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
              disabled={loading || candidateUnits.length === 0}
              className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-[#FC5931] hover:bg-[#e04823] text-white text-xs font-semibold transition-colors disabled:opacity-50 shadow-2xs"
            >
              {loading && <Loader2 size={14} className="animate-spin" />}
              Transferir Unidade
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
