'use client'

import { useState, useEffect } from 'react'
import { X, UserX, AlertCircle, Loader2 } from 'lucide-react'
import { adminInactivateVehicle } from '@/app/admin/actions'
import { VehicleData } from './[id]/resident-360-client'

interface VehicleInactivateModalProps {
  isOpen: boolean
  onClose: () => void
  vehicle: VehicleData | null
  profileId: string
  residentName: string
  onSuccess: () => void
}

const SUGESTOES_MOTIVO = [
  'Venda do veículo',
  'Troca de veículo',
  'Veículo não pertence mais à unidade',
  'Outro motivo',
]

export default function VehicleInactivateModal({
  isOpen,
  onClose,
  vehicle,
  profileId,
  residentName,
  onSuccess,
}: VehicleInactivateModalProps) {
  const [motivo, setMotivo] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!isOpen) return
    setMotivo('')
    setError(null)
    setLoading(false)
  }, [isOpen, vehicle])

  if (!isOpen || !vehicle) return null

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (loading || !vehicle) return

    setError(null)

    if (!motivo.trim()) {
      setError('O motivo da inativação é obrigatório para auditoria administrativa.')
      return
    }

    setLoading(true)

    try {
      const res = await adminInactivateVehicle({
        veiculoId: vehicle.id,
        profileId,
        motivo: motivo.trim(),
      })

      if (res.error) {
        setError(res.error)
        setLoading(false)
        return
      }

      onSuccess()
      onClose()
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Erro ao inativar veículo.')
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
              <UserX size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Inativar Veículo</h2>
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

          {/* Resumo do Veículo */}
          <div className="p-4 rounded-xl bg-gray-50 border border-gray-200/80 space-y-1.5 text-xs text-gray-700">
            <div className="flex items-center justify-between">
              <span className="font-mono font-bold text-sm text-gray-900 bg-white px-2 py-0.5 rounded-md border border-gray-200">
                {vehicle.placa}
              </span>
              <span className="text-gray-500 capitalize">{vehicle.tipo}</span>
            </div>
            <p className="font-semibold text-gray-900">
              {vehicle.marca} {vehicle.modelo} {vehicle.cor ? `· ${vehicle.cor}` : ''}
            </p>
            {(vehicle.unidade_bloco || vehicle.unidade_apto) && (
              <p className="text-gray-500">
                Unidade: Bloco {vehicle.unidade_bloco || '—'} · Apto {vehicle.unidade_apto || '—'}
              </p>
            )}
            {vehicle.vaga_numero && (
              <p className="text-gray-500">Vaga: {vehicle.vaga_numero}</p>
            )}
          </div>

          <p className="text-xs text-gray-500">
            O veículo deixará de constar como cadastro vigente. O registro histórico de auditoria será integralmente preservado.
          </p>

          {/* Sugestões Rápidas */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1.5">
              Sugestões de Motivo:
            </label>
            <div className="flex flex-wrap gap-1.5">
              {SUGESTOES_MOTIVO.map(s => (
                <button
                  key={s}
                  type="button"
                  onClick={() => setMotivo(s)}
                  className={`text-[11px] px-2.5 py-1 rounded-lg border transition-colors ${
                    motivo === s
                      ? 'bg-red-50 text-red-700 border-red-300 font-semibold'
                      : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
                  }`}
                >
                  {s}
                </button>
              ))}
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
              placeholder="Descreva o motivo pelo qual este veículo está sendo inativado..."
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
