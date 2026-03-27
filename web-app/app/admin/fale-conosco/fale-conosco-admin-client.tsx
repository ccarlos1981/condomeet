'use client'

import { useState, useEffect, useRef, useMemo } from 'react'
import { createClient } from '@/lib/supabase/client'
import { MessageSquare, Send, Search, CheckCircle, Layers } from 'lucide-react'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

type AdminThread = {
  id: string
  tipo: string
  assunto: string
  status: string
  ultima_mensagem_em: string
  created_at: string
  resident_id: string
  perfil: {
    nome_completo: string
    bloco_txt: string | null
    apto_txt: string | null
  } | null
}

type Mensagem = {
  id: string
  sender_id: string
  is_admin: boolean
  texto: string
  arquivo_url: string | null
  created_at: string
}

/** A group of threads from the same resident with the same subject */
type ThreadGroup = {
  /** Key: resident_id + assunto (normalized) */
  key: string
  /** All threads in this group */
  threads: AdminThread[]
  /** Thread IDs for quick lookup */
  threadIds: string[]
  /** Display data (from most recent thread) */
  tipo: string
  assunto: string
  resident_id: string
  perfil: AdminThread['perfil']
  /** Most recent message timestamp across all threads */
  ultima_mensagem_em: string
  /** Earliest created_at */
  created_at: string
  /** "Worst" status: aberto > respondido > fechado */
  status: string
}

const TIPO_CONFIG: Record<string, { label: string; emoji: string; color: string; bg: string }> = {
  reclamacao: { label: 'Reclamação',  emoji: '⚠️', color: 'text-red-700',    bg: 'bg-red-50'    },
  elogio:     { label: 'Elogio',      emoji: '👏', color: 'text-green-700',  bg: 'bg-green-50'  },
  pendencia:  { label: 'Pendência',   emoji: '📋', color: 'text-orange-700', bg: 'bg-orange-50' },
  sugestao:   { label: 'Sugestão',    emoji: '💡', color: 'text-blue-700',   bg: 'bg-blue-50'   },
  duvida:     { label: 'Dúvida',      emoji: '❓', color: 'text-purple-700', bg: 'bg-purple-50' },
}

const STATUS_CONFIG: Record<string, { label: string; dot: string; badge: string }> = {
  aberto:     { label: 'Aguardando', dot: 'bg-amber-400',   badge: 'bg-amber-50 text-amber-700 border-amber-200' },
  respondido: { label: 'Respondido', dot: 'bg-emerald-500', badge: 'bg-emerald-50 text-emerald-700 border-emerald-200' },
  fechado:    { label: 'Fechado',    dot: 'bg-gray-400',    badge: 'bg-gray-50 text-gray-600 border-gray-200' },
}

const STATUS_PRIORITY: Record<string, number> = { aberto: 0, respondido: 1, fechado: 2 }

function formatTime(dateStr: string) {
  const d = new Date(dateStr)
  const diff = Date.now() - d.getTime()
  if (diff < 86400000) return d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
  if (diff < 604800000) return d.toLocaleDateString('pt-BR', { weekday: 'short' })
  return d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' })
}

function formatFull(dateStr: string) {
  return new Date(dateStr).toLocaleString('pt-BR', {
    day: '2-digit', month: '2-digit', year: '2-digit',
    hour: '2-digit', minute: '2-digit',
  })
}

/** Normalize assunto for grouping: lowercase, trimmed, remove extra spaces */
function normalizeAssunto(assunto: string): string {
  return assunto.trim().toLowerCase().replace(/\s+/g, ' ')
}

/** Get the "worst" status across threads (aberto > respondido > fechado) */
function worstStatus(threads: AdminThread[]): string {
  let worst = 'fechado'
  let worstPriority = STATUS_PRIORITY[worst]
  for (const t of threads) {
    const p = STATUS_PRIORITY[t.status] ?? 0
    if (p < worstPriority) {
      worst = t.status
      worstPriority = p
    }
  }
  return worst
}

/** Group threads by resident_id + normalized assunto */
function groupThreads(threads: AdminThread[]): ThreadGroup[] {
  const map = new Map<string, AdminThread[]>()

  for (const t of threads) {
    const key = `${t.resident_id}::${normalizeAssunto(t.assunto)}`
    const existing = map.get(key)
    if (existing) {
      existing.push(t)
    } else {
      map.set(key, [t])
    }
  }

  const groups: ThreadGroup[] = []
  for (const [key, groupThreads] of map) {
    // Sort by ultima_mensagem_em descending within group
    groupThreads.sort((a, b) =>
      new Date(b.ultima_mensagem_em).getTime() - new Date(a.ultima_mensagem_em).getTime()
    )
    const mostRecent = groupThreads[0]
    const oldest = groupThreads[groupThreads.length - 1]

    groups.push({
      key,
      threads: groupThreads,
      threadIds: groupThreads.map(t => t.id),
      tipo: mostRecent.tipo,
      assunto: mostRecent.assunto,
      resident_id: mostRecent.resident_id,
      perfil: mostRecent.perfil,
      ultima_mensagem_em: mostRecent.ultima_mensagem_em,
      created_at: oldest.created_at,
      status: worstStatus(groupThreads),
    })
  }

  // Sort groups by most recent message
  groups.sort((a, b) =>
    new Date(b.ultima_mensagem_em).getTime() - new Date(a.ultima_mensagem_em).getTime()
  )

  return groups
}

// ─── Thread Group List Item (Admin sidebar) ─────────────────────────────────

function ThreadGroupListItem({
  group,
  isSelected,
  onClick,
}: {
  group: ThreadGroup
  isSelected: boolean
  onClick: () => void
}) {
  const tipo = TIPO_CONFIG[group.tipo] ?? TIPO_CONFIG.duvida
  const status = STATUS_CONFIG[group.status] ?? STATUS_CONFIG.aberto
  const residentName = group.perfil?.nome_completo?.split(' ')[0] ?? 'Morador'
  const unidade = group.perfil?.bloco_txt
    ? `${group.perfil.bloco_txt} / ${group.perfil.apto_txt}`
    : ''
  const count = group.threads.length

  return (
    <button
      onClick={onClick}
      className={`w-full text-left px-4 py-3.5 border-b border-gray-100 transition-all hover:bg-orange-50/50 ${
        isSelected ? 'bg-[#FC5931]/8 border-l-2 border-l-[#FC5931]' : 'border-l-2 border-l-transparent'
      }`}
    >
      <div className="flex items-start gap-3">
        <div className={`w-9 h-9 rounded-xl flex items-center justify-center text-base flex-shrink-0 ${tipo.bg}`}>
          {tipo.emoji}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between gap-2 mb-0.5">
            <span className="font-semibold text-sm text-gray-800 truncate">{residentName}</span>
            <div className="flex items-center gap-1.5 shrink-0">
              {count > 1 && (
                <span className="flex items-center gap-0.5 text-[10px] font-semibold text-gray-500 bg-gray-100 px-1.5 py-0.5 rounded-full">
                  <Layers size={10} />
                  {count}
                </span>
              )}
              <span className="text-[10px] text-gray-400">{formatTime(group.ultima_mensagem_em)}</span>
            </div>
          </div>
          <p className="text-xs text-gray-500 truncate mb-1">{group.assunto}</p>
          <div className="flex items-center gap-2">
            <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-full border ${status.badge}`}>
              {status.label}
            </span>
            {unidade && <span className="text-[10px] text-gray-400">{unidade}</span>}
          </div>
        </div>
      </div>
    </button>
  )
}

// ─── Main Admin Component ─────────────────────────────────────────────────────

export default function FaleConoscoAdminClient({
  initialThreads,
  adminId,
  adminName,
  condoId,
  tipoEstrutura,
}: {
  initialThreads: AdminThread[]
  adminId: string
  adminName: string
  condoId: string
  tipoEstrutura?: string
}) {
  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)
  const [threads, setThreads] = useState<AdminThread[]>(initialThreads)
  const [selectedGroup, setSelectedGroup] = useState<ThreadGroup | null>(null)
  const [mensagens, setMensagens] = useState<Mensagem[]>([])
  const [loadingMsgs, setLoadingMsgs] = useState(false)
  const [text, setText] = useState('')
  const [sending, setSending] = useState(false)
  const [search, setSearch] = useState('')
  const [filterStatus, setFilterStatus] = useState<'todos' | 'aberto' | 'respondido'>('todos')
  const bottomRef = useRef<HTMLDivElement>(null)

  // Compute groups from threads
  const allGroups = useMemo(() => groupThreads(threads), [threads])

  // Auto-select first group on initial render
  useEffect(() => {
    if (!selectedGroup && allGroups.length > 0) {
      setSelectedGroup(allGroups[0])
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [allGroups.length])

  // Load messages for ALL threads in the selected group
  useEffect(() => {
    if (selectedGroup) {
      loadGroupMessages(selectedGroup.threadIds)

      const supabase = createClient()
      // Subscribe to realtime for all threads in group
      const channels = selectedGroup.threadIds.map((threadId) =>
        supabase
          .channel(`admin-chat-${threadId}`)
          .on(
            'postgres_changes',
            {
              event: 'INSERT',
              schema: 'public',
              table: 'fale_sindico_mensagens',
              filter: `thread_id=eq.${threadId}`,
            },
            (payload) => {
              const nova = payload.new as Mensagem
              setMensagens(prev => {
                if (prev.find(m => m.id === nova.id)) return prev
                const updated = [...prev, nova]
                updated.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
                return updated
              })
            }
          )
          .subscribe()
      )

      return () => {
        channels.forEach(ch => supabase.removeChannel(ch))
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedGroup?.key])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [mensagens])

  async function loadGroupMessages(threadIds: string[]) {
    setLoadingMsgs(true)
    const supabase = createClient()
    const { data } = await supabase
      .from('fale_sindico_mensagens')
      .select('id, sender_id, is_admin, texto, arquivo_url, created_at')
      .in('thread_id', threadIds)
      .order('created_at', { ascending: true })
    setMensagens(data ?? [])
    setLoadingMsgs(false)
  }

  async function handleSend() {
    if (!text.trim() || sending || !selectedGroup) return
    setSending(true)
    const supabase = createClient()
    const now = new Date().toISOString()

    // Send message to the most recent thread in the group
    const mainThreadId = selectedGroup.threadIds[0]

    const { data: inserted, error } = await supabase
      .from('fale_sindico_mensagens')
      .insert({
        thread_id: mainThreadId,
        sender_id: adminId,
        is_admin: true,
        texto: text.trim(),
      })
      .select()
      .single()

    if (!error && inserted) {
      // Update ALL threads in the group → respondido
      await supabase
        .from('fale_sindico_threads')
        .update({ status: 'respondido', ultima_mensagem_em: now })
        .in('id', selectedGroup.threadIds)

      setMensagens(prev => [...prev, inserted])
      setThreads(prev => prev.map(t =>
        selectedGroup.threadIds.includes(t.id)
          ? { ...t, status: 'respondido', ultima_mensagem_em: now }
          : t
      ))
      // Update selected group
      setSelectedGroup(prev => prev ? { ...prev, status: 'respondido' } : prev)
      setText('')
    }
    setSending(false)
  }

  async function handleClose() {
    if (!selectedGroup) return
    const supabase = createClient()
    // Close ALL threads in the group
    await supabase
      .from('fale_sindico_threads')
      .update({ status: 'fechado' })
      .in('id', selectedGroup.threadIds)
    setThreads(prev => prev.map(t =>
      selectedGroup.threadIds.includes(t.id)
        ? { ...t, status: 'fechado' }
        : t
    ))
    setSelectedGroup(prev => prev ? { ...prev, status: 'fechado' } : prev)
  }

  async function handleReopen() {
    if (!selectedGroup) return
    const supabase = createClient()
    await supabase
      .from('fale_sindico_threads')
      .update({ status: 'aberto' })
      .in('id', selectedGroup.threadIds)
    setThreads(prev => prev.map(t =>
      selectedGroup.threadIds.includes(t.id)
        ? { ...t, status: 'aberto' }
        : t
    ))
    setSelectedGroup(prev => prev ? { ...prev, status: 'aberto' } : prev)
  }

  const filteredGroups = allGroups.filter(g => {
    const matchStatus = filterStatus === 'todos' || g.status === filterStatus
    const residentName = g.perfil?.nome_completo?.toLowerCase() ?? ''
    const matchSearch = !search || g.assunto.toLowerCase().includes(search.toLowerCase()) || residentName.includes(search.toLowerCase())
    return matchStatus && matchSearch
  })

  const pendingCount = allGroups.filter(g => g.status === 'aberto').length

  const selectedTipo = selectedGroup ? (TIPO_CONFIG[selectedGroup.tipo] ?? TIPO_CONFIG.duvida) : null
  const selectedStatus = selectedGroup ? (STATUS_CONFIG[selectedGroup.status] ?? STATUS_CONFIG.aberto) : null

  return (
    <div className="flex h-screen overflow-hidden bg-gray-50">
      {/* LEFT: Thread group list */}
      <div className="w-80 flex-shrink-0 bg-white border-r border-gray-100 flex flex-col">
        {/* Header */}
        <div className="px-4 py-4 border-b border-gray-100">
          <div className="flex items-center justify-between mb-3">
            <div>
              <h1 className="text-base font-bold text-gray-900">Fale Conosco</h1>
              <p className="text-xs text-gray-400">{allGroups.length} conversa{allGroups.length !== 1 ? 's' : ''}</p>
            </div>
            {pendingCount > 0 && (
              <span className="bg-amber-400 text-white text-xs font-bold px-2 py-0.5 rounded-full">
                {pendingCount}
              </span>
            )}
          </div>

          {/* Search */}
          <div className="relative mb-3">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Buscar conversas..."
              className="w-full pl-9 pr-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all bg-gray-50"
            />
          </div>

          {/* Filter tabs */}
          <div className="flex gap-1">
            {[
              { key: 'todos',      label: 'Todos' },
              { key: 'aberto',     label: 'Pendentes' },
              { key: 'respondido', label: 'Respondidos' },
            ].map(({ key, label }) => (
              <button
                key={key}
                onClick={() => setFilterStatus(key as typeof filterStatus)}
                className={`flex-1 text-xs font-medium py-1.5 rounded-lg transition-all ${
                  filterStatus === key
                    ? 'bg-[#FC5931] text-white'
                    : 'text-gray-500 hover:bg-gray-100'
                }`}
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        {/* Thread group list */}
        <div className="flex-1 overflow-y-auto">
          {filteredGroups.length === 0 ? (
            <div className="text-center py-12 text-gray-400">
              <MessageSquare size={28} className="mx-auto mb-2 opacity-30" />
              <p className="text-sm">Nenhuma conversa</p>
            </div>
          ) : (
            filteredGroups.map(g => (
              <ThreadGroupListItem
                key={g.key}
                group={g}
                isSelected={selectedGroup?.key === g.key}
                onClick={() => setSelectedGroup(g)}
              />
            ))
          )}
        </div>
      </div>

      {/* RIGHT: Chat area */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {selectedGroup && selectedTipo && selectedStatus ? (
          <>
            {/* Chat header */}
            <div className="bg-white border-b border-gray-100 px-6 py-4 flex items-center gap-3">
              <div className={`w-10 h-10 rounded-xl flex items-center justify-center text-lg ${selectedTipo.bg}`}>
                {selectedTipo.emoji}
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-2 flex-wrap">
                  <p className="font-bold text-gray-900">{selectedGroup.assunto}</p>
                  <span className={`text-xs font-semibold px-2 py-0.5 rounded-full border ${selectedStatus.badge}`}>
                    {selectedStatus.label}
                  </span>
                  {selectedGroup.threads.length > 1 && (
                    <span className="flex items-center gap-1 text-[10px] font-semibold text-gray-500 bg-gray-100 px-2 py-0.5 rounded-full">
                      <Layers size={10} />
                      {selectedGroup.threads.length} conversas agrupadas
                    </span>
                  )}
                </div>
                <p className="text-xs text-gray-500">
                  {selectedGroup.perfil?.nome_completo ?? 'Morador'}
                  {selectedGroup.perfil?.bloco_txt ? ` · ${blocoLabel} ${selectedGroup.perfil.bloco_txt} / ${aptoLabel} ${selectedGroup.perfil.apto_txt}` : ''}
                  {' · '}{selectedTipo.label}
                </p>
              </div>
              {selectedGroup.status === 'fechado' ? (
                <button
                  onClick={handleReopen}
                  className="flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-gray-700 px-3 py-1.5 rounded-xl border border-gray-200 hover:bg-gray-50 transition-all"
                >
                  Reabrir
                </button>
              ) : (
                <button
                  onClick={handleClose}
                  className="flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-gray-700 px-3 py-1.5 rounded-xl border border-gray-200 hover:bg-gray-50 transition-all"
                >
                  <CheckCircle size={13} />
                  Fechar conversa
                </button>
              )}
            </div>

            {/* Messages */}
            <div
              className="flex-1 overflow-y-auto px-6 py-5 space-y-3"
              style={{ background: 'linear-gradient(180deg, #f9fafb 0%, #f3f4f6 100%)' }}
            >
              {loadingMsgs ? (
                <div className="flex items-center justify-center h-full">
                  <div className="w-6 h-6 border-2 border-[#FC5931]/30 border-t-[#FC5931] rounded-full animate-spin" />
                </div>
              ) : mensagens.length === 0 ? (
                <div className="text-center py-12">
                  <p className="text-4xl mb-3">💬</p>
                  <p className="text-sm text-gray-400">Nenhuma mensagem nesta conversa</p>
                </div>
              ) : (
                mensagens.map(msg => {
                  const isAdmin = msg.is_admin
                  return (
                    <div key={msg.id} className={`flex ${isAdmin ? 'justify-end' : 'justify-start'}`}>
                      <div
                        className={`max-w-[70%] rounded-2xl px-4 py-2.5 shadow-sm ${
                          isAdmin
                            ? 'bg-[#FC5931] text-white rounded-br-sm'
                            : 'bg-white text-gray-800 rounded-bl-sm border border-gray-100'
                        }`}
                      >
                        {!isAdmin && (
                          <p className="text-xs font-semibold text-[#FC5931] mb-1">
                            {selectedGroup.perfil?.nome_completo?.split(' ')[0] ?? 'Morador'}
                          </p>
                        )}
                        <p className="text-sm leading-relaxed">{msg.texto}</p>
                        <p className={`text-[10px] mt-1 ${isAdmin ? 'text-white/60' : 'text-gray-400'}`}>
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
              <div className="bg-white border-t border-gray-100 px-5 py-3 flex items-end gap-2">
                <textarea
                  value={text}
                  onChange={e => setText(e.target.value)}
                  onKeyDown={e => {
                    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSend() }
                  }}
                  placeholder="Digite sua resposta como síndico..."
                  rows={1}
                  className="flex-1 resize-none border border-gray-200 rounded-2xl px-4 py-2.5 text-sm text-gray-700 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all max-h-32 overflow-y-auto"
                />
                <button
                  onClick={handleSend}
                  disabled={sending || !text.trim()}
                  className="w-10 h-10 bg-[#FC5931] text-white rounded-2xl flex items-center justify-center hover:bg-[#D42F1D] transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex-shrink-0 shadow-sm shadow-[#FC5931]/30"
                >
                  {sending
                    ? <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    : <Send size={16} />
                  }
                </button>
              </div>
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center text-gray-400">
            <div className="text-center">
              <MessageSquare size={48} className="mx-auto mb-3 opacity-20" />
              <p className="font-medium text-gray-500">Selecione uma conversa</p>
              <p className="text-sm mt-1">Escolha um assunto da lista ao lado para responder</p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
