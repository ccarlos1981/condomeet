'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { CheckCircle, XCircle, Lock, Unlock } from 'lucide-react'
import { useRouter } from 'next/navigation'

type Action = 'approve' | 'reject' | 'block' | 'unblock'

const ACTION_CONFIG: Record<Action, {
  label: string
  loadingLabel: string
  newStatus: string
  className: string
  icon: React.ReactNode
}> = {
  approve: {
    label: 'Aprovar',      loadingLabel: '...',
    newStatus: 'aprovado', className: 'bg-green-500 text-white hover:bg-green-600',
    icon: <CheckCircle size={14} />,
  },
  reject: {
    label: 'Rejeitar',     loadingLabel: '...',
    newStatus: 'rejeitado',className: 'bg-gray-100 text-gray-600 hover:bg-red-100 hover:text-red-600',
    icon: <XCircle size={14} />,
  },
  block: {
    label: 'Bloquear',     loadingLabel: '...',
    newStatus: 'bloqueado',className: 'bg-red-50 text-red-600 border border-red-200 hover:bg-red-100',
    icon: <Lock size={14} />,
  },
  unblock: {
    label: 'Reativar',     loadingLabel: '...',
    newStatus: 'aprovado', className: 'bg-green-50 text-green-700 border border-green-200 hover:bg-green-100',
    icon: <Unlock size={14} />,
  },
}

export default function ApproveButton({ profileId, action }: { profileId: string; action: Action }) {
  const [loading, setLoading] = useState(false)
  const supabase = createClient()
  const router = useRouter()
  const cfg = ACTION_CONFIG[action]

  async function handleAction() {
    setLoading(true)
    await supabase.from('perfil').update({ status_aprovacao: cfg.newStatus }).eq('id', profileId)
    setLoading(false)
    router.refresh()
  }

  return (
    <button
      onClick={handleAction}
      disabled={loading}
      className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors disabled:opacity-50 ${cfg.className}`}
    >
      {cfg.icon}
      {loading ? cfg.loadingLabel : cfg.label}
    </button>
  )
}
