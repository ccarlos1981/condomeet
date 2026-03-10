'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Eye, EyeOff, Mail, Lock } from 'lucide-react'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [remember, setRemember] = useState(true)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const router = useRouter()
  const supabase = createClient()

  async function handleLogin() {
    setLoading(true)
    setError('')
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) {
      setError('E-mail ou senha incorretos. Verifique seus dados.')
      setLoading(false)
      return
    }
    router.push('/condo')
    router.refresh()
  }

  return (
    <div className="min-h-screen bg-[#f4f6f9] flex">
      {/* Left brand panel */}
      <div className="hidden lg:flex flex-col items-center justify-center w-96 bg-gradient-to-b from-[#E85D26] to-[#c44d1e] p-10 text-white">
        <div className="w-20 h-20 bg-white/20 rounded-3xl flex items-center justify-center mb-6 backdrop-blur-sm">
          <svg width="44" height="44" viewBox="0 0 32 32" fill="none">
            <rect x="4" y="8" width="24" height="20" rx="2" fill="white" fillOpacity="0.9"/>
            <rect x="9" y="4" width="14" height="6" rx="1" fill="white"/>
            <rect x="10" y="14" width="4" height="4" rx="1" fill="#E85D26"/>
            <rect x="18" y="14" width="4" height="4" rx="1" fill="#E85D26"/>
            <rect x="13" y="20" width="6" height="8" rx="1" fill="#E85D26"/>
          </svg>
        </div>
        <h1 className="text-3xl font-bold mb-2">Condomeet</h1>
        <p className="text-white/70 text-center text-sm leading-relaxed">
          Seu condomínio digital.<br/>Simples, seguro e conectado.
        </p>
        <div className="mt-10 space-y-3 w-full">
          {['Autorizar visitantes', 'Gerenciar encomendas', 'Comunicação com moradores'].map(f => (
            <div key={f} className="flex items-center gap-3 text-sm text-white/80">
              <div className="w-5 h-5 rounded-full bg-white/20 flex items-center justify-center flex-shrink-0">
                <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                  <path d="M2 5l2 2 4-4" stroke="white" strokeWidth="1.5" strokeLinecap="round"/>
                </svg>
              </div>
              {f}
            </div>
          ))}
        </div>
      </div>

      {/* Right login panel */}
      <div className="flex-1 flex items-center justify-center p-6">
        <div className="bg-white rounded-3xl shadow-xl w-full max-w-sm p-8">
          {/* Mobile logo */}
          <div className="lg:hidden flex flex-col items-center mb-6">
            <div className="w-14 h-14 bg-[#E85D26] rounded-2xl flex items-center justify-center mb-3">
              <svg width="28" height="28" viewBox="0 0 32 32" fill="none">
                <rect x="4" y="8" width="24" height="20" rx="2" fill="white" fillOpacity="0.9"/>
                <rect x="9" y="4" width="14" height="6" rx="1" fill="white"/>
                <rect x="10" y="14" width="4" height="4" rx="1" fill="#E85D26"/>
                <rect x="18" y="14" width="4" height="4" rx="1" fill="#E85D26"/>
                <rect x="13" y="20" width="6" height="8" rx="1" fill="#E85D26"/>
              </svg>
            </div>
            <h1 className="text-xl font-bold text-gray-900">Condomeet</h1>
            <p className="text-xs text-[#E85D26] font-medium mt-0.5">seu Condomínio Digital</p>
          </div>

          {/* Register banner */}
          <a href="/register" className="block w-full mb-6 py-3 bg-[#E85D26] text-white rounded-xl text-sm font-semibold text-center hover:bg-[#c44d1e] transition-colors">
            Ainda não tem cadastro? Clique aqui!
          </a>

          <div className="text-center mb-5">
            <p className="text-sm font-semibold text-gray-700">Já é cadastrado?</p>
            <p className="text-xs text-gray-400">Digite E-mail e Senha</p>
          </div>

          {/* Form */}
          <div className="space-y-3">
            <div className="relative">
              <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type="email"
                placeholder="Digite seu email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleLogin()}
                className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#E85D26] bg-gray-50 text-sm"
              />
            </div>

            <div className="relative">
              <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type={showPassword ? 'text' : 'password'}
                inputMode="numeric"
                placeholder="Senha (somente números)"
                value={password}
                onChange={e => setPassword(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleLogin()}
                className="w-full pl-10 pr-11 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#E85D26] bg-gray-50 text-sm"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>

            <div className="flex items-center justify-between text-sm">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={remember}
                  onChange={e => setRemember(e.target.checked)}
                  className="w-4 h-4 rounded accent-[#E85D26]"
                />
                <span className="text-gray-600 text-xs">Lembrar Senha</span>
              </label>
              <a href="/forgot-password" className="text-xs text-[#E85D26] hover:underline">Esqueci a senha</a>
            </div>

            {error && <p className="text-red-500 text-xs text-center">{error}</p>}

            <button
              onClick={handleLogin}
              disabled={loading || !email || !password}
              className="w-full py-3 border-2 border-[#E85D26] text-[#E85D26] rounded-xl font-bold text-sm hover:bg-[#E85D26] hover:text-white transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? 'Acessando...' : 'Acessar'}
            </button>
          </div>

          <div className="mt-5 text-center">
            <a href="/sindico-register" className="text-xs text-gray-500 hover:text-[#E85D26] transition-colors">
              Sou Síndico e quero registrar meu condomínio
            </a>
          </div>

          <p className="mt-6 text-center text-[10px] text-gray-400">
            Todos os direitos reservados à @2SCapital @2026<br/>
            <a href="/privacidade" className="hover:underline">Política de Privacidade</a>
          </p>
        </div>
      </div>
    </div>
  )
}

