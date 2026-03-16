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

  // Estado para o modal de atualização de senha
  const [showPasswordSetup, setShowPasswordSetup] = useState(false)
  const [setupEmail, setSetupEmail] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [setupLoading, setSetupLoading] = useState(false)
  const [setupError, setSetupError] = useState('')
  const [showNewPwd, setShowNewPwd] = useState(false)
  const [showConfirmPwd, setShowConfirmPwd] = useState(false)

  // Estado para tela de bloqueio
  const [showBlocked, setShowBlocked] = useState(false)
  const [blockedMessage, setBlockedMessage] = useState('')

  async function handleLogin() {
    setLoading(true)
    setError('')
    const normalizedEmail = email.trim().toLowerCase()
    const { data: loginData, error: loginError } = await supabase.auth.signInWithPassword({ email: normalizedEmail, password })
    if (loginError) {
      // Verifica se é morador migrado que precisa configurar senha
      if (loginError.message?.includes('Invalid login credentials') || loginError.message?.includes('invalid_credentials')) {
        const { data: needsSetup } = await supabase.rpc('check_needs_password_setup', { user_email: normalizedEmail })
        if (needsSetup === true) {
          setSetupEmail(normalizedEmail)
          setShowPasswordSetup(true)
          setLoading(false)
          return
        }
      }
      setError('E-mail ou senha incorretos. Verifique seus dados.')
      setLoading(false)
      return
    }

    // Login OK — verifica se está bloqueado/pendente
    if (loginData?.user) {
      const { data: perfil } = await supabase
        .from('perfil')
        .select('status_aprovacao')
        .eq('id', loginData.user.id)
        .single()
      
      if (perfil?.status_aprovacao === 'bloqueado' || perfil?.status_aprovacao === 'pendente') {
        setShowBlocked(true)
        setBlockedMessage(
          perfil.status_aprovacao === 'bloqueado'
            ? 'Seu acesso está bloqueado. Aguarde a liberação do síndico.'
            : 'Seu cadastro está pendente de aprovação pelo síndico.'
        )
        setLoading(false)
        return
      }
    }

    router.push('/condo')
    router.refresh()
  }

  async function handlePasswordSetup() {
    if (newPassword.length < 4) { setSetupError('Mínimo de 4 dígitos'); return }
    if (newPassword !== confirmPassword) { setSetupError('As senhas não coincidem'); return }
    setSetupLoading(true)
    setSetupError('')
    try {
      await supabase.rpc('setup_user_password', { user_email: setupEmail, new_password: newPassword })
      const { data: loginData, error: loginError } = await supabase.auth.signInWithPassword({ email: setupEmail, password: newPassword })
      if (loginError) throw loginError

      // Verifica se está bloqueado/pendente após configurar senha
      if (loginData?.user) {
        const { data: perfil } = await supabase
          .from('perfil')
          .select('status_aprovacao')
          .eq('id', loginData.user.id)
          .single()
        
        if (perfil?.status_aprovacao === 'bloqueado' || perfil?.status_aprovacao === 'pendente') {
          setShowPasswordSetup(false)
          setShowBlocked(true)
          setBlockedMessage(
            perfil.status_aprovacao === 'bloqueado'
              ? 'Seu acesso está bloqueado. Aguarde a liberação do síndico.'
              : 'Seu cadastro está pendente de aprovação pelo síndico.'
          )
          setSetupLoading(false)
          return
        }
      }

      router.push('/condo')
      router.refresh()
    } catch (e: any) {
      setSetupError('Erro ao definir senha. Tente novamente.')
      setSetupLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#f4f6f9] flex">
      {/* Left brand panel */}
      <div className="hidden lg:flex flex-col items-center justify-center w-96 bg-gradient-to-b from-[#FC5931] to-[#D42F1D] p-10 text-white">
        <img src="/logo.png" alt="Condomeet" className="w-24 h-24 rounded-3xl object-cover mb-6 shadow-lg" />
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
            <img src="/logo.png" alt="Condomeet" className="w-16 h-16 rounded-2xl object-cover mb-3 shadow-md" />
            <h1 className="text-xl font-bold text-gray-900">Condomeet</h1>
            <p className="text-xs text-[#FC5931] font-medium mt-0.5">seu Condomínio Digital</p>
          </div>

          {/* Register banner */}
          <a href="/register" className="block w-full mb-6 py-3 bg-[#FC5931] text-white rounded-xl text-sm font-semibold text-center hover:bg-[#D42F1D] transition-colors">
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
                className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
              />
            </div>

            <div className="relative">
              <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type={showPassword ? 'text' : 'password'}
                inputMode="numeric"
                placeholder="Senha (somente números)"
                value={password}
                onChange={e => setPassword(e.target.value.replace(/\D/g, ''))}
                onKeyDown={e => e.key === 'Enter' && handleLogin()}
                className="w-full pl-10 pr-11 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
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
                  className="w-4 h-4 rounded accent-[#FC5931]"
                />
                <span className="text-gray-600 text-xs">Lembrar Senha</span>
              </label>
              <a href="/forgot-password" className="text-xs text-[#FC5931] hover:underline">Esqueci a senha</a>
            </div>

            {error && <p className="text-red-500 text-xs text-center">{error}</p>}

            <button
              onClick={handleLogin}
              disabled={loading || !email || !password}
              className="w-full py-3 border-2 border-[#FC5931] text-[#FC5931] rounded-xl font-bold text-sm hover:bg-[#FC5931] hover:text-white transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? 'Acessando...' : 'Acessar'}
            </button>
          </div>

          <div className="mt-5 text-center">
            <a href="/sindico-register" className="text-xs text-gray-500 hover:text-[#FC5931] transition-colors">
              Sou Síndico e quero registrar meu condomínio
            </a>
          </div>

          <p className="mt-6 text-center text-[10px] text-gray-400">
            Todos os direitos reservados à @2SCapital @2026<br/>
            <a href="/privacidade" className="hover:underline">Política de Privacidade</a>
          </p>
        </div>
      </div>

      {/* Modal: Atualize sua senha */}
      {showPasswordSetup && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-3xl shadow-2xl w-full max-w-sm p-8">
            <div className="flex flex-col items-center mb-6">
              <div className="w-14 h-14 bg-[#FC5931]/10 rounded-full flex items-center justify-center mb-3">
                <Lock size={28} className="text-[#FC5931]" />
              </div>
              <h2 className="text-xl font-bold text-gray-900">Atualize sua senha</h2>
              <p className="text-sm text-gray-500 text-center mt-1">
                Crie uma senha numérica para acessar o app.
              </p>
            </div>

            <div className="space-y-3">
              {/* Nova senha */}
              <div className="relative">
                <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type={showNewPwd ? 'text' : 'password'}
                  inputMode="numeric"
                  placeholder="Nova senha (somente números)"
                  value={newPassword}
                  onChange={e => setNewPassword(e.target.value.replace(/\D/g, ''))}
                  className="w-full pl-10 pr-11 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                />
                <button type="button" onClick={() => setShowNewPwd(!showNewPwd)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400">
                  {showNewPwd ? <EyeOff size={16}/> : <Eye size={16}/>}
                </button>
              </div>

              {/* Confirmar senha */}
              <div className="relative">
                <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type={showConfirmPwd ? 'text' : 'password'}
                  inputMode="numeric"
                  placeholder="Confirmar senha"
                  value={confirmPassword}
                  onChange={e => setConfirmPassword(e.target.value.replace(/\D/g, ''))}
                  className="w-full pl-10 pr-11 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                />
                <button type="button" onClick={() => setShowConfirmPwd(!showConfirmPwd)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400">
                  {showConfirmPwd ? <EyeOff size={16}/> : <Eye size={16}/>}
                </button>
              </div>

              {setupError && <p className="text-red-500 text-xs text-center">{setupError}</p>}

              <button
                onClick={handlePasswordSetup}
                disabled={setupLoading || !newPassword || !confirmPassword}
                className="w-full py-3 bg-[#FC5931] text-white rounded-xl font-bold text-sm hover:bg-[#D42F1D] transition-all disabled:opacity-50"
              >
                {setupLoading ? 'Salvando...' : 'Confirmar'}
              </button>

              <button onClick={() => setShowPasswordSetup(false)}
                className="w-full py-2 text-gray-400 text-xs hover:text-gray-600 transition-colors">
                Cancelar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Acesso Bloqueado */}
      {showBlocked && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-3xl shadow-2xl w-full max-w-sm p-8 text-center">
            <div className="w-20 h-20 bg-orange-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <span className="text-4xl">📞</span>
            </div>
            <h2 className="text-xl font-bold text-gray-900 mb-2">Solicitação Enviada!</h2>
            <p className="text-sm text-gray-500 mb-6">{blockedMessage}</p>
            <div className="bg-gray-50 rounded-xl p-4 mb-6">
              <p className="text-xs text-gray-500">💡 <strong>Dica:</strong> O síndico costuma analisar solicitações em horários comerciais.</p>
            </div>
            <button
              onClick={() => {
                setShowBlocked(false)
                supabase.auth.signOut()
              }}
              className="w-full py-3 bg-[#FC5931] text-white rounded-xl font-bold text-sm hover:bg-[#D42F1D] transition-all"
            >
              Voltar ao Início
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

