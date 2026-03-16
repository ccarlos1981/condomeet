'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Mail, ArrowLeft } from 'lucide-react'

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('')
  const [loading, setLoading] = useState(false)
  const [sent, setSent] = useState(false)
  const [error, setError] = useState('')
  const supabase = createClient()

  async function handleSubmit() {
    const normalizedEmail = email.trim().toLowerCase()
    if (!normalizedEmail || !normalizedEmail.includes('@')) {
      setError('Digite um email válido')
      return
    }
    setLoading(true)
    setError('')
    try {
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(normalizedEmail, {
        redirectTo: `${window.location.origin}/reset-password`
      })
      if (resetError) throw resetError
      setSent(true)
    } catch (e: any) {
      setError('Erro ao enviar email. Verifique e tente novamente.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#f4f6f9] flex items-center justify-center p-6">
      <div className="bg-white rounded-3xl shadow-xl w-full max-w-sm p-8">
        <a href="/login" className="flex items-center gap-2 text-sm text-gray-500 hover:text-[#FC3951] mb-6 transition-colors">
          <ArrowLeft size={16} /> Voltar ao login
        </a>

        {sent ? (
          <div className="text-center">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <span className="text-3xl">✉️</span>
            </div>
            <h2 className="text-xl font-bold text-gray-900 mb-2">Email enviado!</h2>
            <p className="text-sm text-gray-500 mb-6">
              Verifique sua caixa de entrada e clique no link para redefinir sua senha.
            </p>
            <p className="text-xs text-gray-400">
              Enviado para <strong>{email}</strong>
            </p>
          </div>
        ) : (
          <>
            <div className="flex flex-col items-center mb-6">
              <div className="w-14 h-14 bg-[#FC3951]/10 rounded-full flex items-center justify-center mb-3">
                <Mail size={28} className="text-[#FC3951]" />
              </div>
              <h2 className="text-xl font-bold text-gray-900">Esqueci a senha</h2>
              <p className="text-sm text-gray-500 text-center mt-1">
                Digite seu email e enviaremos um link para redefinir sua senha.
              </p>
            </div>

            <div className="space-y-3">
              <div className="relative">
                <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type="email"
                  placeholder="Digite seu email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && handleSubmit()}
                  className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC3951] bg-gray-50 text-sm"
                />
              </div>

              {error && <p className="text-red-500 text-xs text-center">{error}</p>}

              <button
                onClick={handleSubmit}
                disabled={loading || !email}
                className="w-full py-3 bg-[#FC3951] text-white rounded-xl font-bold text-sm hover:bg-[#D4253D] transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? 'Enviando...' : 'Enviar Link de Redefinição'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
