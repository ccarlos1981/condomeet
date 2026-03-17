'use client'

import { useState, useRef } from 'react'
import { Trash2, Megaphone, Users, Send, Bold, Italic, Underline } from 'lucide-react'

interface Aviso {
  id: string
  titulo: string
  corpo: string
  created_at: string
  lidos: number
}

interface Props {
  condominioId: string
  avisos: Aviso[]
  totalResidents: number
}

export default function AvisosAdminClient({ condominioId, avisos: initial, totalResidents }: Props) {
  const [avisos, setAvisos] = useState<Aviso[]>(initial)
  const [titulo, setTitulo] = useState('')
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const bodyRef = useRef<HTMLDivElement>(null)

  const readPct = (lidos: number) =>
    totalResidents > 0 ? Math.round((lidos / totalResidents) * 100) : 0

  function execCommand(cmd: string) {
    document.execCommand(cmd, false)
    bodyRef.current?.focus()
  }

  async function handleSend() {
    const corpo = bodyRef.current?.innerHTML ?? ''
    if (!titulo.trim()) { setError('Informe o título'); return }
    setSending(true)
    setError(null)

    const res = await fetch('/api/avisos', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ titulo: titulo.trim(), corpo, condominio_id: condominioId }),
    })
    const data = await res.json()
    if (!res.ok) { setError(data.error ?? 'Erro ao enviar'); setSending(false); return }

    setAvisos([{ ...data, lidos: 0 }, ...avisos])
    setTitulo('')
    if (bodyRef.current) bodyRef.current.innerHTML = ''
    setSending(false)
  }

  async function handleDelete(id: string) {
    if (!confirm('Excluir este aviso?')) return
    const res = await fetch(`/api/avisos?id=${id}`, { method: 'DELETE' })
    if (res.ok) setAvisos(avisos.filter(a => a.id !== id))
  }

  return (
    <div className="max-w-3xl">
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-1">
          <Megaphone size={22} className="text-[#FC5931]" />
          <h1 className="text-2xl font-bold text-gray-900">Avisos</h1>
        </div>
        <p className="text-sm text-gray-500">Envie comunicados para todos os moradores do condomínio.</p>
      </div>

      {/* Compose form */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 mb-8">
        <p className="text-sm font-semibold text-gray-700 mb-3">Escreva os avisos para todos:</p>

        {/* Title */}
        <input
          type="text"
          maxLength={40}
          placeholder="Título do aviso"
          value={titulo}
          onChange={e => setTitulo(e.target.value)}
          className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm mb-1 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
        />
        <p className="text-xs text-gray-400 text-right mb-3">{titulo.length}/40 caracteres</p>

        {/* Rich text toolbar */}
        <div className="border border-gray-200 rounded-xl overflow-hidden">
          <div className="flex items-center gap-1 border-b border-gray-100 bg-gray-50 px-3 py-2">
            <button onClick={() => execCommand('bold')} className="p-1.5 rounded hover:bg-gray-200 transition-colors" title="Negrito">
              <Bold size={14} />
            </button>
            <button onClick={() => execCommand('italic')} className="p-1.5 rounded hover:bg-gray-200 transition-colors" title="Itálico">
              <Italic size={14} />
            </button>
            <button onClick={() => execCommand('underline')} className="p-1.5 rounded hover:bg-gray-200 transition-colors" title="Sublinhado">
              <Underline size={14} />
            </button>
          </div>
          <div
            ref={bodyRef}
            contentEditable
            suppressContentEditableWarning
            className="min-h-[120px] px-4 py-3 text-sm text-gray-700 focus:outline-none"
            data-placeholder="Escreva aqui seu aviso..."
            onInput={() => {}}
          />
        </div>

        {error && <p className="text-red-500 text-xs mt-2">{error}</p>}

        <button
          onClick={handleSend}
          disabled={sending}
          className="mt-4 flex items-center gap-2 bg-[#FC5931] hover:bg-[#D42F1D] text-white px-6 py-2.5 rounded-full text-sm font-semibold transition-colors disabled:opacity-50"
        >
          <Send size={14} />
          {sending ? 'Enviando...' : 'Enviar Aviso'}
        </button>
      </div>

      {/* Avisos list */}
      <div className="space-y-3">
        {avisos.length === 0 && (
          <div className="text-center py-10 text-gray-400 bg-white rounded-2xl border border-gray-100">
            <Megaphone size={32} className="mx-auto mb-2 opacity-30" />
            <p className="text-sm">Nenhum aviso enviado ainda</p>
          </div>
        )}
        {avisos.map(aviso => {
          const pct = readPct(aviso.lidos)
          return (
            <div key={aviso.id} className="bg-white rounded-2xl border border-gray-100 shadow-sm px-5 py-4">
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-gray-900 text-sm truncate">
                    Título do Aviso: {aviso.titulo}
                  </p>
                  <p className="text-xs text-gray-400 mt-0.5">
                    Criado em: {new Date(aviso.created_at).toLocaleString('pt-BR', {
                      day: '2-digit', month: '2-digit', year: 'numeric',
                      hour: '2-digit', minute: '2-digit',
                    })}
                  </p>
                </div>

                <div className="flex items-center gap-3 shrink-0">
                  {/* Progress bar */}
                  <div className="w-32">
                    <div className="h-3 bg-gray-100 rounded-full overflow-hidden border border-gray-200">
                      <div
                        className="h-full bg-blue-500 transition-all"
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                    <div className="flex items-center justify-between mt-0.5">
                      <span className="text-[10px] text-gray-500">{pct}%</span>
                      <span className="text-[10px] text-gray-400 flex items-center gap-1">
                        <Users size={9} />
                        Lido por: {aviso.lidos}
                      </span>
                    </div>
                  </div>

                  <button
                    onClick={() => handleDelete(aviso.id)}
                    title="Excluir aviso"
                    className="p-1.5 rounded-lg text-red-400 hover:bg-red-50 hover:text-red-600 transition-colors"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
