'use client'

import React, { useState } from 'react'
import { CheckCircle, X, Loader2, AlertTriangle } from 'lucide-react'

interface ApproveConfirmModalProps {
  isOpen: boolean
  onClose: () => void
  onConfirm: (motivo?: string) => Promise<void>
  residentName: string
  isReapproval?: boolean
  loading: boolean
  error?: string | null
}

export default function ApproveConfirmModal({
  isOpen,
  onClose,
  onConfirm,
  residentName,
  isReapproval = false,
  loading,
  error,
}: ApproveConfirmModalProps) {
  const [motivo, setMotivo] = useState('')

  if (!isOpen) return null

  async function handleConfirm() {
    await onConfirm(motivo.trim() || undefined)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div
        className="bg-white rounded-2xl max-w-md w-full shadow-2xl border border-gray-100 p-6 relative animate-in fade-in zoom-in-95 duration-150"
        role="dialog"
        aria-modal="true"
      >
        {/* Close Button */}
        <button
          type="button"
          onClick={onClose}
          disabled={loading}
          className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 p-1 rounded-lg hover:bg-gray-100 transition-colors disabled:opacity-40"
          aria-label="Fechar"
        >
          <X size={18} />
        </button>

        {/* Icon & Title */}
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0 shadow-xs bg-emerald-50 text-emerald-700 border border-emerald-100">
            <CheckCircle size={22} />
          </div>

          <div className="flex-1 pr-6">
            <h3 className="text-lg font-bold text-gray-900 leading-tight">
              {isReapproval ? 'Aprovar cadastro rejeitado?' : 'Aprovar cadastro de morador?'}
            </h3>
            <p className="text-xs text-gray-500 mt-0.5">
              Ação administrativa de liberação de acesso
            </p>
          </div>
        </div>

        {/* Content Body */}
        <div className="mt-4 text-sm text-gray-600 leading-relaxed space-y-3">
          {isReapproval ? (
            <p>
              O cadastro previamente recusado de <strong className="text-gray-900">{residentName || 'selecionado'}</strong> será <span className="text-emerald-700 font-semibold">aprovado</span>. O morador terá o acesso restabelecido.
            </p>
          ) : (
            <p>
              Ao aprovar o cadastro de <strong className="text-gray-900">{residentName || 'selecionado'}</strong>, o acesso ao Condomeet será <span className="text-emerald-700 font-semibold">liberado</span> e a notificação de boas-vindas será enviada com as instruções de uso.
            </p>
          )}

          <div>
            <label htmlFor="approve-motivo" className="block text-xs font-semibold text-gray-700 mb-1">
              Observação / Motivo (opcional)
            </label>
            <input
              id="approve-motivo"
              type="text"
              value={motivo}
              onChange={(e) => setMotivo(e.target.value)}
              disabled={loading}
              placeholder={isReapproval ? "Ex: Reconsiderado após validação de documentos..." : "Ex: Documentação conferida e aprovada..."}
              className="w-full px-3 py-2 text-xs border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 disabled:bg-gray-50"
            />
          </div>

          {error && (
            <div className="flex items-center gap-2 p-3 rounded-xl bg-red-50 text-red-700 text-xs border border-red-200">
              <AlertTriangle size={15} className="flex-shrink-0 text-red-500" />
              <span>{error}</span>
            </div>
          )}
        </div>

        {/* Action Buttons */}
        <div className="mt-6 flex items-center justify-end gap-3 pt-3 border-t border-gray-100">
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="px-4 py-2 rounded-xl text-xs font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 transition-colors disabled:opacity-50"
          >
            Cancelar
          </button>

          <button
            type="button"
            onClick={handleConfirm}
            disabled={loading}
            className="px-4 py-2 rounded-xl text-xs font-semibold text-white bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 disabled:bg-emerald-400 transition-all shadow-xs flex items-center gap-2"
          >
            {loading && <Loader2 size={13} className="animate-spin" />}
            <span>{loading ? 'Aprovando...' : isReapproval ? 'Aprovar cadastro' : 'Confirmar aprovação'}</span>
          </button>
        </div>
      </div>
    </div>
  )
}
