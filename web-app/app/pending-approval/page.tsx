'use client'
import { useState, useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Clock, LogOut, RefreshCw, Building2 } from 'lucide-react'

export default function PendingApprovalPage() {
  const router = useRouter()
  const supabase = createClient()
  const [userName, setUserName] = useState('')
  const [condoName, setCondoName] = useState('')
  const [status, setStatus] = useState('pendente')
  const [checking, setChecking] = useState(false)

  const loadProfile = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { router.push('/login'); return }

    const { data: profile } = await supabase
      .from('perfil')
      .select('nome_completo, status_aprovacao, condominio_id')
      .eq('id', user.id)
      .single()

    if (!profile) { router.push('/login'); return }

    setUserName(profile.nome_completo?.split(' ')[0] || 'Usuário')
    setStatus(profile.status_aprovacao || 'pendente')

    if (profile.status_aprovacao === 'aprovado') {
      router.push('/condo')
      return
    }

    if (profile.condominio_id) {
      const { data: condo } = await supabase
        .from('condominios')
        .select('nome')
        .eq('id', profile.condominio_id)
        .single()
      setCondoName(condo?.nome || '')
    }
  }, [supabase, router])

  useEffect(() => {
    loadProfile()
  }, [loadProfile])

  async function checkStatus() {
    setChecking(true)
    await loadProfile()
    setChecking(false)
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    router.push('/login')
  }

  const isBlocked = status === 'bloqueado'

  return (
    <div className="min-h-screen bg-[#f4f6f9] flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-xl w-full max-w-md p-8 text-center">
        {/* Icon */}
        <div className={`w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-4 ${
          isBlocked ? 'bg-red-100' : 'bg-orange-100'
        }`}>
          {isBlocked ? (
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#DC2626" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>
          ) : (
            <Clock size={40} className="text-orange-500" />
          )}
        </div>

        {/* Title */}
        <h2 className="text-xl font-bold text-gray-900 mb-2">
          {isBlocked ? 'Acesso Bloqueado' : 'Aguardando Aprovação'}
        </h2>

        {/* Greeting */}
        {userName && (
          <p className="text-sm text-gray-500 mb-4">
            Olá, <strong>{userName}</strong>! 👋
          </p>
        )}

        {/* Message */}
        <p className="text-sm text-gray-500 mb-6">
          {isBlocked ? (
            <>Seu acesso foi bloqueado pelo Síndico ou Administradora. Entre em contato com a administração do seu condomínio para mais informações.</>
          ) : (
            <>Seu cadastro foi enviado para aprovação do <strong>Síndico</strong> ou <strong>Administradora</strong> responsável pelo condomínio.</>
          )}
        </p>

        {/* Condo info */}
        {condoName && (
          <div className="bg-gray-50 rounded-xl p-4 mb-6 flex items-center gap-3 justify-center">
            <Building2 size={16} className="text-[#FC5931]" />
            <span className="text-sm font-medium text-gray-700">{condoName}</span>
          </div>
        )}

        {/* Tips */}
        {!isBlocked && (
          <div className="bg-orange-50 border border-orange-200 rounded-xl p-4 mb-6 text-left">
            <p className="text-xs text-orange-700">
              💡 <strong>Dica:</strong> O síndico costuma analisar solicitações em horários comerciais. 
              Você receberá uma notificação por WhatsApp assim que seu cadastro for aprovado.
            </p>
          </div>
        )}

        {/* Check status button */}
        {!isBlocked && (
          <button
            onClick={checkStatus}
            disabled={checking}
            className="w-full py-3 bg-[#FC5931] text-white rounded-xl font-bold text-sm hover:bg-[#D42F1D] transition-all disabled:opacity-50 flex items-center justify-center gap-2 mb-3"
          >
            <RefreshCw size={16} className={checking ? 'animate-spin' : ''} />
            {checking ? 'Verificando...' : 'Verificar Status'}
          </button>
        )}

        {/* Logout */}
        <button
          onClick={handleLogout}
          className="w-full py-3 border-2 border-gray-200 text-gray-500 rounded-xl font-semibold text-sm hover:bg-gray-50 transition-all flex items-center justify-center gap-2"
        >
          <LogOut size={16} />
          Sair
        </button>

        <p className="text-center text-[10px] text-gray-400 mt-6">
          Todos os direitos reservados à @2SCapital @2026
        </p>
      </div>
    </div>
  )
}
