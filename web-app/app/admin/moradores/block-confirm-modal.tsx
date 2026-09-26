'use client'

import React from 'react'
import { Lock, Unlock, X, Loader2, AlertTriangle } from 'lucide-react'

interface BlockConfirmModalProps {
  isOpen: boolean
  onClose: () => void
  onConfirm: () => Promise<void>
  residentName: string
  action: 'block' | 'unblock'
  loading: boolean
  error?: string | null
}

export default function BlockConfirmModal({
  isOpen,
  onClose,
  onConfirm,
  residentName,
  action,
  loading,
  error,
}: BlockConfirmModalProps) {
  if (!isOpen) return null

  const isBlock = action === 'block'

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
          <div
            className={`w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0 shadow-xs ${
              isBlock
                ? 'bg-red-50 text-red-600 border border-red-100'
                : 'bg-emerald-50 text-emerald-700 border border-emerald-100'
            }`}
          >
            {isBlock ? <Lock size={22} /> : <Unlock size={22} />}
          </div>

          <div className="flex-1 pr-6">
            <h3 className="text-lg font-bold text-gray-900 leading-tight">
              {isBlock ? 'Bloquear acesso?' : 'Reativar acesso?'}
            </h3>
            <p className="text-xs text-gray-500 mt-0.5">
              Ação administrativa de controle cadastral
            </p>
          </div>
        </div>

        {/* Content Body */}
        <div className="mt-4 text-sm text-gray-600 leading-relaxed space-y-2">
          {isBlock ? (
            <p>
              O morador <strong className="text-gray-900">{residentName || 'selecionado'}</strong> continuará cadastrado e seus dados e vínculos serão preservados, mas <span className="text-red-700 font-semibold">não poderá acessar</span> o Condomeet enquanto estiver bloqueado.
            </p>
          ) : (
            <p>
              O acesso de <strong className="text-gray-900">{residentName || 'selecionado'}</strong> ao Condomeet será <span className="text-emerald-700 font-semibold">restabelecido</span>. A reativação não recria cadastro, não refaz onboarding nem altera senha.
            </p>
          )}

          {error && (
            <div className="flex items-center gap-2 p-3 mt-3 rounded-xl bg-red-50 text-red-700 text-xs border border-red-200">
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
            onClick={onConfirm}
            disabled={loading}
            className={`px-4 py-2 rounded-xl text-xs font-semibold text-white transition-all shadow-xs flex items-center gap-2 ${
              isBlock
                ? 'bg-red-600 hover:bg-red-700 active:bg-red-800 disabled:bg-red-400'
                : 'bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 disabled:bg-emerald-400'
            }`}
          >
            {loading && <Loader2 size={13} className="animate-spin" />}
            <span>
              {loading
                ? isBlock
                  ? 'Bloqueando...'
                  : 'Reativando...'
                : isBlock
                ? 'Bloquear acesso'
                : 'Reativar acesso'}
            </span>
          </button>
        </div>
      </div>
    </div>
  )
}
