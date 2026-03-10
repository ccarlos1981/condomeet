'use client'

import { useState, useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { MessageSquare, Plus, ChevronRight, Send, X, ArrowLeft, Paperclip } from 'lucide-react'

// ─── Types ───────────────────────────────────────────────────────────────────

type Thread = {
  id: string
  tipo: string
  assunto: string
  status: string
  ultima_mensagem_at: string
  created_at: string
}

type Mensagem = {
  id: string
  sender_id: string
  is_admin: boolean
  texto: string
  arquivo_url: string | null
  created_at: string
}

// ─── Constants ────────────────────────────────────────────────────────────────

const TIPO_CONFIG: Record<string, { label: string; emoji: string; color: string; bg: string }> = {
  reclamacao: { label: 'Reclamação',  emoji: '⚠️', color: 'text-red-700',    bg: 'bg-red-50 border-red-200' },
  elogio:     { label: 'Elogio',      emoji: '👏', color: 'text-green-700',  bg: 'bg-green-50 border-green-200' },
  pendencia:  { label: 'Pendência',   emoji: '📋', color: 'text-orange-700', bg: 'bg-orange-50 border-orange-200' },
  sugestao:   { label: 'Sugestão',    emoji: '💡', color: 'text-blue-700',   bg: 'bg-blue-50 border-blue-200' },
  duvida:     { label: 'Dúvida',      emoji: '❓', color: 'text-purple-700', bg: 'bg-purple-50 border-purple-200' },
}

const STATUS_CONFIG: Record<string, { label: string; dot: string }> = {
  aberto:     { label: 'Aguardando', dot: 'bg-amber-400' },
  respondido: { label: 'Respondido', dot: 'bg-emerald-500' },
  fechado:    { label: 'Fechado',    dot: 'bg-gray-400' },
}

function formatTime(dateStr: string) {
  const d = new Date(dateStr)
  const now = new Date()
  const diffDays = Math.floor((now.getTime() - d.getTime()) / 86400000)
  if (diffDays === 0) return d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
  if (diffDays === 1) return 'Ontem'
  if (diffDays < 7) return d.toLocaleDateString('pt-BR', { weekday: 'short' })
  return d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' })
}

function formatFull(dateStr: string) {
  return new Date(dateStr).toLocaleString('pt-BR', {
    day: '2-digit', month: '2-digit', year: '2-digit',
    hour: '2-digit', minute: '2-digit',
  })
}

// ─── Thread List Item ─────────────────────────────────────────────────────────

function ThreadCard({ thread, onClick }: { thread: Thread; onClick: () => void }) {
  const tipo = TIPO_CONFIG[thread.tipo] ?? TIPO_CONFIG.duvida
  const status = STATUS_CONFIG[thread.status] ?? STATUS_CONFIG.aberto

  return (
    <button
      onClick={onClick}
      className="w-full text-left bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md hover:border-[#E85D26]/20 transition-all duration-200 p-4 group"
    >
      <div className="flex items-start gap-3">
        {/* Emoji tipo */}
        <div className={`w-11 h-11 rounded-xl flex items-center justify-center text-lg flex-shrink-0 border ${tipo.bg}`}>
          {tipo.emoji}
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-0.5">
            <span className={`text-xs font-semibold px-2 py-0.5 rounded-full border ${tipo.bg} ${tipo.color}`}>
              {tipo.label}
            </span>
            <span className="ml-auto text-xs text-gray-400 shrink-0">{formatTime(thread.ultima_mensagem_at)}</span>
          </div>
          <p className="font-semibold text-gray-800 text-sm truncate">{thread.assunto}</p>
          <div className="flex items-center gap-1.5 mt-1">
            <div className={`w-2 h-2 rounded-full ${status.dot}`} />
            <span className="text-xs text-gray-500">{status.label}</span>
          </div>
        </div>

        <ChevronRight size={16} className="text-gray-300 group-hover:text-[#E85D26] transition-colors mt-1 flex-shrink-0" />
      </div>
    </button>
  )
}

// ─── Chat View ────────────────────────────────────────────────────────────────

function ChatView({
  thread,
  userId,
  onBack,
  onStatusUpdate,
}: {
  thread: Thread
  userId: string
  onBack: () => void
  onStatusUpdate: (id: string, status: string) => void
}) {
  const [mensagens, setMensagens] = useState<Mensagem[]>([])
  const [loading, setLoading] = useState(true)
  const [text, setText] = useState('')
  const [sending, setSending] = useState(false)
  const bottomRef = useRef<HTMLDivElement>(null)
  const tipo = TIPO_CONFIG[thread.tipo] ?? TIPO_CONFIG.duvida
  const status = STATUS_CONFIG[thread.status] ?? STATUS_CONFIG.aberto

  useEffect(() => {
    loadMessages()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [thread.id])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [mensagens])

  async function loadMessages() {
    setLoading(true)
    const supabase = createClient()
    const { data } = await supabase
      .from('fale_sindico_mensagens')
      .select('id, sender_id, is_admin, texto, arquivo_url, created_at')
      .eq('thread_id', thread.id)
      .order('created_at', { ascending: true })
    setMensagens(data ?? [])
    setLoading(false)
  }

  async function handleSend() {
    if (!text.trim() || sending) return
    setSending(true)
    const supabase = createClient()
    const { data: { user: cu } } = await supabase.auth.getUser()
    const now = new Date().toISOString()

    const { data: inserted, error } = await supabase
      .from('fale_sindico_mensagens')
      .insert({
        thread_id: thread.id,
        sender_id: cu?.id ?? userId,
        is_admin: false,
        texto: text.trim(),
      })
      .select()
      .single()

    if (!error && inserted) {
      // Update thread ultima_mensagem_at
      await supabase
        .from('fale_sindico_threads')
        .update({ ultima_mensagem_at: now, status: 'aberto' })
        .eq('id', thread.id)

      setMensagens(prev => [...prev, inserted])
      setText('')
    }
    setSending(false)
  }

  return (
    <div className="flex flex-col h-[calc(100vh-12rem)] bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
      {/* Header */}
      <div className="flex items-center gap-3 px-5 py-4 border-b border-gray-100 bg-white">
        <button
          onClick={onBack}
          className="p-1.5 rounded-xl hover:bg-gray-100 transition-colors text-gray-500"
        >
          <ArrowLeft size={18} />
        </button>
        <div className={`w-10 h-10 rounded-xl flex items-center justify-center text-lg flex-shrink-0 border ${tipo.bg}`}>
          {tipo.emoji}
        </div>
        <div className="flex-1 min-w-0">
          <p className="font-bold text-gray-900 text-sm truncate">{thread.assunto}</p>
          <div className="flex items-center gap-1.5">
            <div className={`w-1.5 h-1.5 rounded-full ${status.dot}`} />
            <span className="text-xs text-gray-500">{tipo.label} · {status.label}</span>
          </div>
        </div>
      </div>

      {/* Messages area */}
      <div className="flex-1 overflow-y-auto px-5 py-4 space-y-3"
        style={{ background: 'linear-gradient(180deg, #f9fafb 0%, #f3f4f6 100%)' }}
      >
        {loading ? (
          <div className="flex items-center justify-center h-full">
            <div className="w-6 h-6 border-2 border-[#E85D26]/30 border-t-[#E85D26] rounded-full animate-spin" />
          </div>
        ) : mensagens.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-4xl mb-3">💬</p>
            <p className="text-sm text-gray-400">Nenhuma mensagem ainda. Inicie a conversa!</p>
          </div>
        ) : (
          mensagens.map((msg) => {
            const isOwn = !msg.is_admin
            return (
              <div key={msg.id} className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
                <div
                  className={`max-w-[75%] rounded-2xl px-4 py-2.5 shadow-sm ${
                    isOwn
                      ? 'bg-[#E85D26] text-white rounded-br-sm'
                      : 'bg-white text-gray-800 rounded-bl-sm border border-gray-100'
                  }`}
                >
                  {msg.is_admin && (
                    <p className="text-xs font-semibold text-[#E85D26] mb-1">Síndico/Adm</p>
                  )}
                  <p className="text-sm leading-relaxed">{msg.texto}</p>
                  <p className={`text-[10px] mt-1 ${isOwn ? 'text-white/60' : 'text-gray-400'}`}>
                    {formatFull(msg.created_at)}
                  </p>
                </div>
              </div>
            )
          })
        )}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="px-4 py-3 border-t border-gray-100 bg-white flex items-end gap-2">
        <textarea
          value={text}
          onChange={e => setText(e.target.value)}
          onKeyDown={e => {
            if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSend() }
          }}
          placeholder="Digite sua mensagem..."
          rows={1}
          className="flex-1 resize-none border border-gray-200 rounded-2xl px-4 py-2.5 text-sm text-gray-700 focus:outline-none focus:ring-2 focus:ring-[#E85D26]/30 focus:border-[#E85D26] transition-all max-h-32 overflow-y-auto"
          style={{ lineHeight: '1.5' }}
        />
        <button
          onClick={handleSend}
          disabled={sending || !text.trim()}
          className="w-10 h-10 bg-[#E85D26] text-white rounded-2xl flex items-center justify-center hover:bg-[#c44d1e] transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex-shrink-0 shadow-sm shadow-[#E85D26]/30"
        >
          {sending
            ? <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            : <Send size={16} />
          }
        </button>
      </div>
    </div>
  )
}

// ─── New Thread Modal ─────────────────────────────────────────────────────────

function NewThreadModal({
  onClose,
  onCreated,
  userId,
  condoId,
}: {
  onClose: () => void
  onCreated: (thread: Thread, firstMsg: string) => void
  userId: string
  condoId: string
}) {
  const [tipo, setTipo] = useState('reclamacao')
  const [assunto, setAssunto] = useState('')
  const [mensagem, setMensagem] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit() {
    if (!assunto.trim() || !mensagem.trim()) {
      setError('Preencha o assunto e a mensagem para continuar.')
      return
    }
    setSaving(true)
    setError('')
    const supabase = createClient()
    const { data: { user: cu } } = await supabase.auth.getUser()
    const now = new Date().toISOString()

    // Create thread
    const { data: thread, error: te } = await supabase
      .from('fale_sindico_threads')
      .insert({
        condominio_id: condoId,
        resident_id: cu?.id ?? userId,
        tipo,
        assunto: assunto.trim(),
        status: 'aberto',
        ultima_mensagem_at: now,
      })
      .select()
      .single()

    if (te || !thread) {
      setError('Erro ao criar conversa. Tente novamente.')
      setSaving(false)
      return
    }

    // Create first message
    await supabase.from('fale_sindico_mensagens').insert({
      thread_id: thread.id,
      sender_id: cu?.id ?? userId,
      is_admin: false,
      texto: mensagem.trim(),
    })

    onCreated(thread, mensagem.trim())
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div
        className="bg-white rounded-3xl shadow-2xl w-full max-w-md overflow-hidden"
        style={{ animation: 'modalIn 0.2s ease-out' }}
      >
        <style>{`@keyframes modalIn { from { opacity:0; transform: scale(0.96) translateY(8px) } to { opacity:1; transform: scale(1) translateY(0) } }`}</style>

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <div>
            <h2 className="text-lg font-bold text-gray-900">Novo Assunto</h2>
            <p className="text-xs text-gray-400 mt-0.5">Envie uma mensagem à administração</p>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-xl flex items-center justify-center text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-colors"
          >
            <X size={16} />
          </button>
        </div>

        <div className="px-6 py-5 flex flex-col gap-5">
          {/* Tipo */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">
              Tipo de assunto
            </label>
            <div className="flex flex-wrap gap-2">
              {Object.entries(TIPO_CONFIG).map(([key, cfg]) => (
                <button
                  key={key}
                  onClick={() => setTipo(key)}
                  className={`flex items-center gap-1.5 text-sm px-3 py-1.5 rounded-xl border font-medium transition-all ${
                    tipo === key
                      ? `${cfg.bg} ${cfg.color} border-current`
                      : 'bg-gray-50 text-gray-500 border-gray-200 hover:border-gray-300'
                  }`}
                >
                  <span>{cfg.emoji}</span>
                  <span>{cfg.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Assunto */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">
              Assunto
            </label>
            <input
              value={assunto}
              onChange={e => setAssunto(e.target.value)}
              placeholder="Ex: Barulho excessivo no corredor"
              maxLength={120}
              className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26]/30 focus:border-[#E85D26] transition-all"
            />
          </div>

          {/* Mensagem */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">
              Sua mensagem
            </label>
            <textarea
              value={mensagem}
              onChange={e => setMensagem(e.target.value)}
              rows={4}
              placeholder="Descreva o que aconteceu ou o que você precisa..."
              className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#E85D26]/30 focus:border-[#E85D26] transition-all"
            />
          </div>

          {error && <p className="text-sm text-red-600 bg-red-50 px-4 py-2.5 rounded-xl border border-red-100">{error}</p>}
        </div>

        <div className="px-6 py-4 border-t border-gray-100 flex gap-3 justify-end">
          <button
            onClick={onClose}
            className="text-sm font-medium px-5 py-2.5 rounded-xl border border-gray-200 text-gray-600 hover:bg-gray-50 transition-colors"
          >
            Cancelar
          </button>
          <button
            onClick={handleSubmit}
            disabled={saving}
            className="flex items-center gap-2 bg-[#E85D26] text-white text-sm font-semibold px-6 py-2.5 rounded-xl hover:bg-[#c44d1e] transition-colors disabled:opacity-40 shadow-sm shadow-[#E85D26]/30"
          >
            {saving ? (
              <><div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" /> Enviando...</>
            ) : (
              <><Send size={14} /> Enviar</>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── Main Component ───────────────────────────────────────────────────────────

export default function FaleSindicoClient({
  initialThreads,
  userId,
  condoId,
  userName,
}: {
  initialThreads: Thread[]
  userId: string
  condoId: string
  userName: string
}) {
  const [threads, setThreads] = useState<Thread[]>(initialThreads)
  const [selectedThread, setSelectedThread] = useState<Thread | null>(null)
  const [showModal, setShowModal] = useState(false)
  const [filter, setFilter] = useState<'todos' | 'aberto' | 'respondido'>('todos')

  const filtered = threads.filter(t => {
    if (filter === 'aberto') return t.status === 'aberto'
    if (filter === 'respondido') return t.status === 'respondido'
    return true
  })

  const pending = threads.filter(t => t.status === 'aberto').length

  function handleCreated(thread: Thread) {
    setThreads(prev => [thread, ...prev])
    setShowModal(false)
    setSelectedThread(thread)
  }

  if (selectedThread) {
    return (
      <ChatView
        thread={selectedThread}
        userId={userId}
        onBack={() => setSelectedThread(null)}
        onStatusUpdate={(id, status) =>
          setThreads(prev => prev.map(t => t.id === id ? { ...t, status } : t))
        }
      />
    )
  }

  return (
    <div>
      {/* Toolbar */}
      <div className="flex items-center justify-between mb-5 gap-3 flex-wrap">
        <div className="flex items-center gap-2 flex-wrap">
          {[
            { key: 'todos',      label: `Todos (${threads.length})` },
            { key: 'aberto',     label: `Aguardando${pending > 0 ? ` (${pending})` : ''}` },
            { key: 'respondido', label: 'Respondidos' },
          ].map(({ key, label }) => (
            <button
              key={key}
              onClick={() => setFilter(key as typeof filter)}
              className={`text-sm font-medium px-4 py-2 rounded-xl border transition-all ${
                filter === key
                  ? 'bg-[#E85D26] text-white border-[#E85D26] shadow-sm shadow-[#E85D26]/20'
                  : 'bg-white text-gray-600 border-gray-200 hover:border-[#E85D26]/50 hover:text-[#E85D26]'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        <button
          onClick={() => setShowModal(true)}
          className="flex items-center gap-2 bg-[#E85D26] text-white text-sm font-semibold px-5 py-2.5 rounded-xl hover:bg-[#c44d1e] transition-colors shadow-sm shadow-[#E85D26]/30"
        >
          <Plus size={16} />
          Novo Assunto
        </button>
      </div>

      {/* Thread list */}
      {filtered.length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          <MessageSquare size={40} className="mx-auto mb-3 opacity-30" />
          <p className="font-medium text-gray-500 mb-1">Nenhuma conversa aqui</p>
          <p className="text-sm">Clique em "Novo Assunto" para falar com a administração</p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {filtered.map(thread => (
            <ThreadCard
              key={thread.id}
              thread={thread}
              onClick={() => setSelectedThread(thread)}
            />
          ))}
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <NewThreadModal
          onClose={() => setShowModal(false)}
          onCreated={handleCreated}
          userId={userId}
          condoId={condoId}
        />
      )}
    </div>
  )
}
