'use client'

import { useState, useEffect } from 'react'
import { X, ShieldAlert, AlertCircle, Loader2 } from 'lucide-react'
import { adminCorrectVehiclePlate } from '@/app/admin/actions'
import { VehicleData } from './[id]/resident-360-client'

interface VehiclePlateModalProps {
  isOpen: boolean
  onClose: () => void
  vehicle: VehicleData | null
  profileId: string
  onSuccess: () => void
}

export default function VehiclePlateModal({
  isOpen,
  onClose,
  vehicle,
  profileId,
  onSuccess,
}: VehiclePlateModalProps) {
  const [novaPlaca, setNovaPlaca] = useState('')
  const [motivo, setMotivo] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!isOpen) return
    setNovaPlaca('')
    setMotivo('')
    setError(null)
    setLoading(false)
  }, [isOpen, vehicle])

  if (!isOpen || !vehicle) return null

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (loading || !vehicle) return

    setError(null)

    if (!novaPlaca.trim()) {
      setError('Informe a nova placa do veículo.')
      return
    }

    if (!motivo.trim()) {
      setError('O motivo da retificação é obrigatório para auditoria administrativa.')
      return
    }

    setLoading(true)

    try {
      const res = await adminCorrectVehiclePlate({
        veiculoId: vehicle.id,
        profileId,
        novaPlaca: novaPlaca.trim(),
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
      setError(err instanceof Error ? err.message : 'Erro ao retificar placa.')
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="p-6 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center">
              <ShieldAlert size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Corrigir Placa do Veículo</h2>
              <p className="text-xs text-gray-500">
                {vehicle.marca} {vehicle.modelo} · {vehicle.cor}
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

          {/* Instructional Box */}
          <div className="p-3.5 rounded-xl bg-amber-50/80 border border-amber-200/80 text-xs text-amber-900 leading-relaxed">
            <p className="font-semibold mb-1">Atenção Administrativa:</p>
            <p>
              Use esta opção apenas para corrigir um erro material de digitação. Se o morador trocou de veículo, inative o veículo atual e cadastre o novo.
            </p>
          </div>

          {/* Placa Atual */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">Placa Atual</label>
            <div className="px-3.5 py-2.5 rounded-xl bg-gray-100 border border-gray-200 font-mono text-sm font-bold text-gray-700">
              {vehicle.placa}
            </div>
          </div>

          {/* Nova Placa */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">Nova Placa *</label>
            <input
              type="text"
              value={novaPlaca}
              onChange={e => setNovaPlaca(e.target.value.toUpperCase())}
              disabled={loading}
              placeholder="Ex: ABC1D23 ou ABC-1234"
              maxLength={8}
              className="w-full text-xs rounded-xl border border-gray-200 p-2.5 font-mono uppercase bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
            />
          </div>

          {/* Motivo Obrigatório */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">
              Motivo da Correção *
            </label>
            <textarea
              value={motivo}
              onChange={e => setMotivo(e.target.value)}
              disabled={loading}
              rows={3}
              placeholder="Ex: Correção de digitação da última letra da placa Mercosul..."
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
              className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-[#FC5931] hover:bg-[#e04820] text-white text-xs font-semibold transition-colors disabled:opacity-50 shadow-2xs"
            >
              {loading && <Loader2 size={14} className="animate-spin" />}
              Retificar Placa
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
