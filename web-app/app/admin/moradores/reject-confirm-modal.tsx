'use client'

import React, { useState } from 'react'
import { XCircle, X, Loader2, AlertTriangle } from 'lucide-react'

interface RejectConfirmModalProps {
  isOpen: boolean
  onClose: () => void
  onConfirm: (motivo: string) => Promise<void>
  residentName: string
  loading: boolean
  error?: string | null
}

export default function RejectConfirmModal({
  isOpen,
  onClose,
  onConfirm,
  residentName,
  loading,
  error,
}: RejectConfirmModalProps) {
  const [motivo, setMotivo] = useState('')
  const [validationError, setValidationError] = useState<string | null>(null)

  if (!isOpen) return null

  async function handleConfirm() {
    const cleanMotivo = motivo.trim()
    if (!cleanMotivo) {
      setValidationError('O motivo da rejeição é obrigatório.')
      return
    }
    setValidationError(null)
    await onConfirm(cleanMotivo)
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
          <div className="w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0 shadow-xs bg-red-50 text-red-600 border border-red-100">
            <XCircle size={22} />
          </div>

          <div className="flex-1 pr-6">
            <h3 className="text-lg font-bold text-gray-900 leading-tight">
              Rejeitar cadastro de morador?
            </h3>
            <p className="text-xs text-gray-500 mt-0.5">
              Ação administrativa de recusa cadastral
            </p>
          </div>
        </div>

        {/* Content Body */}
        <div className="mt-4 text-sm text-gray-600 leading-relaxed space-y-3">
          <p>
            O cadastro de <strong className="text-gray-900">{residentName || 'selecionado'}</strong> será <span className="text-red-600 font-semibold">rejeitado</span> e o morador não terá acesso ao condomínio. O motivo informado será gravado no histórico de auditoria.
          </p>

          <div>
            <label htmlFor="reject-motivo" className="block text-xs font-semibold text-gray-700 mb-1">
              Motivo da rejeição <span className="text-red-500">*</span>
            </label>
            <textarea
              id="reject-motivo"
              rows={3}
              value={motivo}
              onChange={(e) => {
                setMotivo(e.target.value)
                if (validationError) setValidationError(null)
              }}
              disabled={loading}
              placeholder="Descreva o motivo da recusa (ex: unidade não confere com contrato, cadastro duplicado, comprovante inválido...)"
              className={`w-full px-3 py-2 text-xs border rounded-xl focus:outline-none focus:ring-2 disabled:bg-gray-50 resize-none ${
                validationError
                  ? 'border-red-300 focus:ring-red-500/20 focus:border-red-500'
                  : 'border-gray-200 focus:ring-red-500/20 focus:border-red-500'
              }`}
            />
            {validationError && (
              <p className="text-[11px] text-red-600 mt-1 font-medium">{validationError}</p>
            )}
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
            disabled={loading || !motivo.trim()}
            className="px-4 py-2 rounded-xl text-xs font-semibold text-white bg-red-600 hover:bg-red-700 active:bg-red-800 disabled:bg-red-300 transition-all shadow-xs flex items-center gap-2"
          >
            {loading && <Loader2 size={13} className="animate-spin" />}
            <span>{loading ? 'Rejeitando...' : 'Confirmar rejeição'}</span>
          </button>
        </div>
      </div>
    </div>
  )
}
