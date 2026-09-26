'use client'
import { useState, useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Home, LogOut, RefreshCw, Building2 } from 'lucide-react'

export default function InactiveAccountPage() {
  const router = useRouter()
  const supabase = createClient()
  const [userName, setUserName] = useState('')
  const [condoName, setCondoName] = useState('')
  const [checking, setChecking] = useState(false)

  const loadProfile = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      router.push('/login')
      return
    }

    const { data: profile } = await supabase
      .from('perfil')
      .select('nome_completo, status_aprovacao, condominio_id')
      .eq('id', user.id)
      .single()

    if (!profile) {
      router.push('/login')
      return
    }

    setUserName(profile.nome_completo?.split(' ')[0] || 'Usuário')

    // Se o perfil foi reativado para aprovado, redireciona ao condomínio
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

  return (
    <div className="min-h-screen bg-[#f4f6f9] flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-xl w-full max-w-md p-8 text-center">
        {/* Ícone Institucional Neutro */}
        <div className="w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-4 bg-slate-100">
          <Home size={38} className="text-slate-500" />
        </div>

        {/* Título Canônico */}
        <h2 className="text-xl font-bold text-gray-900 mb-2">
          Cadastro inativo
        </h2>

        {/* Saudação */}
        {userName && (
          <p className="text-sm text-gray-500 mb-4">
            Olá, <strong>{userName}</strong>! 👋
          </p>
        )}

        {/* Mensagem Institucional Canônica */}
        <div className="text-sm text-gray-600 mb-6 space-y-3 leading-relaxed text-left bg-slate-50 p-4 rounded-xl border border-slate-100">
          <p>
            Seu cadastro não possui um vínculo residencial ativo neste condomínio no momento.
          </p>
          <p className="text-xs text-gray-500">
            Se você ainda reside aqui ou precisa recuperar seu acesso, entre em contato com a administração do condomínio.
          </p>
        </div>

        {/* Informação do Condomínio */}
        {condoName && (
          <div className="bg-gray-50 rounded-xl p-4 mb-6 flex items-center gap-3 justify-center">
            <Building2 size={16} className="text-[#FC5931]" />
            <span className="text-sm font-medium text-gray-700">{condoName}</span>
          </div>
        )}

        {/* Verificar se o síndico já reativou */}
        <button
          onClick={checkStatus}
          disabled={checking}
          className="w-full py-3 bg-[#FC5931] text-white rounded-xl font-bold text-sm hover:bg-[#D42F1D] transition-all disabled:opacity-50 flex items-center justify-center gap-2 mb-3"
        >
          <RefreshCw size={16} className={checking ? 'animate-spin' : ''} />
          {checking ? 'Verificando...' : 'Verificar Status'}
        </button>

        {/* Ação de Sair */}
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
