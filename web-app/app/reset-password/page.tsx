'use client'
import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Lock, Eye, EyeOff } from 'lucide-react'

export default function ResetPasswordPage() {
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showNew, setShowNew] = useState(false)
  const [showConfirm, setShowConfirm] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)
  const [sessionReady, setSessionReady] = useState(false)
  const supabase = createClient()
  const router = useRouter()

  useEffect(() => {
    // Supabase processes the hash fragment automatically when the page loads
    // We need to wait for the auth state to settle
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event) => {
      if (event === 'PASSWORD_RECOVERY') {
        setSessionReady(true)
      }
    })
    // Also check if user is already logged in (e.g. token already processed)
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) setSessionReady(true)
    })
    return () => subscription.unsubscribe()
  }, [supabase.auth])

  async function handleReset() {
    if (newPassword.length < 4) { setError('Mínimo de 4 dígitos'); return }
    if (newPassword !== confirmPassword) { setError('As senhas não coincidem'); return }
    setLoading(true)
    setError('')
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password: newPassword })
      if (updateError) throw updateError
      setSuccess(true)
      setTimeout(() => router.push('/login'), 3000)
    } catch (e: any) {
      setError('Erro ao redefinir senha. Tente novamente.')
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#f4f6f9] flex items-center justify-center p-6">
      <div className="bg-white rounded-3xl shadow-xl w-full max-w-sm p-8">
        {success ? (
          <div className="text-center">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <span className="text-3xl">✅</span>
            </div>
            <h2 className="text-xl font-bold text-gray-900 mb-2">Senha redefinida!</h2>
            <p className="text-sm text-gray-500">
              Redirecionando para o login...
            </p>
          </div>
        ) : !sessionReady ? (
          <div className="text-center">
            <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4 animate-pulse">
              <Lock size={28} className="text-gray-400" />
            </div>
            <h2 className="text-lg font-bold text-gray-900 mb-2">Processando...</h2>
            <p className="text-sm text-gray-500">Verificando o link de redefinição.</p>
          </div>
        ) : (
          <>
            <div className="flex flex-col items-center mb-6">
              <div className="w-14 h-14 bg-[#FC3951]/10 rounded-full flex items-center justify-center mb-3">
                <Lock size={28} className="text-[#FC3951]" />
              </div>
              <h2 className="text-xl font-bold text-gray-900">Redefinir Senha</h2>
              <p className="text-sm text-gray-500 text-center mt-1">
                Crie uma nova senha numérica.
              </p>
            </div>

            <div className="space-y-3">
              <div className="relative">
                <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type={showNew ? 'text' : 'password'}
                  inputMode="numeric"
                  placeholder="Nova senha (somente números)"
                  value={newPassword}
                  onChange={e => setNewPassword(e.target.value.replace(/\D/g, ''))}
                  className="w-full pl-10 pr-11 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC3951] bg-gray-50 text-sm"
                />
                <button type="button" onClick={() => setShowNew(!showNew)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400">
                  {showNew ? <EyeOff size={16}/> : <Eye size={16}/>}
                </button>
              </div>

              <div className="relative">
                <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type={showConfirm ? 'text' : 'password'}
                  inputMode="numeric"
                  placeholder="Confirmar nova senha"
                  value={confirmPassword}
                  onChange={e => setConfirmPassword(e.target.value.replace(/\D/g, ''))}
                  onKeyDown={e => e.key === 'Enter' && handleReset()}
                  className="w-full pl-10 pr-11 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC3951] bg-gray-50 text-sm"
                />
                <button type="button" onClick={() => setShowConfirm(!showConfirm)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400">
                  {showConfirm ? <EyeOff size={16}/> : <Eye size={16}/>}
                </button>
              </div>

              {error && <p className="text-red-500 text-xs text-center">{error}</p>}

              <button
                onClick={handleReset}
                disabled={loading || !newPassword || !confirmPassword}
                className="w-full py-3 bg-[#FC3951] text-white rounded-xl font-bold text-sm hover:bg-[#D4253D] transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? 'Salvando...' : 'Redefinir Senha'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
