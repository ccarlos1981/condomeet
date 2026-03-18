'use client'

import { useState } from 'react'
import { Send, Megaphone } from 'lucide-react'

interface Condominio {
  id: string
  nome: string
}

interface Props {
  condominios: Condominio[]
}

export default function UniversalPushForm({ condominios }: Props) {
  const [condominioId, setCondominioId] = useState('')
  const [titulo, setTitulo] = useState('')
  const [corpo, setCorpo] = useState('')
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  const selectedCondo = condominios.find(c => c.id === condominioId)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!titulo.trim() || !corpo.trim()) return

    setLoading(true)
    setResult(null)

    try {
      const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
      const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

      const body: Record<string, string> = {
        titulo: titulo.trim(),
        corpo: corpo.trim(),
      }
      if (condominioId) {
        body.condominio_id = condominioId
      }

      const res = await fetch(`${supabaseUrl}/functions/v1/universal-push-notify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${anon}`,
        },
        body: JSON.stringify(body),
      })

      let data: Record<string, unknown>
      try {
        data = await res.json()
      } catch {
        throw new Error(`Resposta inválida do servidor (HTTP ${res.status}). Verifique os logs da Edge Function.`)
      }

      if (!res.ok) {
        throw new Error((data?.error as string) ?? `Erro ao enviar push (HTTP ${res.status})`)
      }

      setResult({
        type: 'success',
        message: `✅ Push enviado para ${data.sent} de ${data.total} dispositivos`,
      })
      setTitulo('')
      setCorpo('')
    } catch (err) {
      setResult({
        type: 'error',
        message: `❌ ${err instanceof Error ? err.message : 'Erro desconhecido'}`,
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      {/* Info banner */}
      <div className="bg-orange-50 border border-orange-200 rounded-xl p-4 flex gap-3 items-start">
        <Megaphone size={18} className="text-orange-500 mt-0.5 shrink-0" />
        <p className="text-sm text-orange-700">
          {condominioId
            ? <>Este push será enviado para os usuários do <strong>{selectedCondo?.nome}</strong>.</>
            : <>Este push será enviado para <strong>todos os usuários cadastrados</strong> em todos os condomínios.</>
          }
        </p>
      </div>

      {/* Result feedback */}
      {result && (
        <div className={`rounded-xl p-4 text-sm font-medium ${
          result.type === 'success'
            ? 'bg-green-50 border border-green-200 text-green-700'
            : 'bg-red-50 border border-red-200 text-red-700'
        }`}>
          {result.message}
        </div>
      )}

      {/* Condomínio selector */}
      <div>
        <label htmlFor="condominio-select" className="block text-sm font-medium text-gray-700 mb-1.5">
          Condomínio
        </label>
        <select
          id="condominio-select"
          value={condominioId}
          onChange={e => setCondominioId(e.target.value)}
          className="w-full px-4 py-3 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent transition appearance-none"
          title="Selecionar condomínio"
        >
          <option value="">Todos os Condomínios</option>
          {condominios.map(c => (
            <option key={c.id} value={c.id}>{c.nome}</option>
          ))}
        </select>
      </div>

      {/* Assunto */}
      <div>
        <label htmlFor="push-titulo" className="block text-sm font-medium text-gray-700 mb-1.5">
          Assunto do Push
        </label>
        <input
          id="push-titulo"
          type="text"
          value={titulo}
          onChange={e => setTitulo(e.target.value)}
          placeholder="Ex: Aviso Importante"
          maxLength={100}
          required
          className="w-full px-4 py-3 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent transition"
        />
        <p className="text-xs text-gray-400 mt-1 text-right">{titulo.length}/100</p>
      </div>

      {/* Conteúdo */}
      <div>
        <label htmlFor="push-corpo" className="block text-sm font-medium text-gray-700 mb-1.5">
          Conteúdo do Push
        </label>
        <textarea
          id="push-corpo"
          value={corpo}
          onChange={e => setCorpo(e.target.value)}
          placeholder="Ex: Nova funcionalidade disponível no app..."
          maxLength={300}
          required
          rows={4}
          className="w-full px-4 py-3 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent transition resize-none"
        />
        <p className="text-xs text-gray-400 mt-1 text-right">{corpo.length}/300</p>
      </div>

      {/* Submit */}
      <button
        type="submit"
        disabled={loading || !titulo.trim() || !corpo.trim()}
        className="w-full flex items-center justify-center gap-2 px-6 py-3 bg-[#FC5931] text-white font-semibold rounded-xl hover:bg-[#D42F1D] disabled:opacity-50 disabled:cursor-not-allowed transition-all"
      >
        {loading ? (
          <>
            <svg className="animate-spin w-4 h-4" viewBox="0 0 24 24" fill="none">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
            </svg>
            Enviando...
          </>
        ) : (
          <>
            <Send size={16} />
            {condominioId ? 'Enviar Push' : 'Enviar Push Universal'}
          </>
        )}
      </button>
    </form>
  )
}
