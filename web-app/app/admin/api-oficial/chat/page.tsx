'use client'

import { useEffect, useState, useRef } from 'react'
import { getConversations, getChatHistory, sendManualMessage, getSuperUserInfo } from '../actions'
import { 
  Search, Filter, Send, MessageSquare, ShieldCheck, 
  AlertTriangle, Clock, RefreshCw, Layers, PhoneCall, Info
} from 'lucide-react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

const TEMPLATES = [
  { name: 'condomeet_encomenda_recebida_v2', category: 'utility', vars: ['Morador', 'Condomínio', 'Tipo', 'Unidade', 'Rastreio', 'Limite'] },
  { name: 'condomeet_visitante_aguardando_v3', category: 'utility', vars: ['Morador', 'Visitante', 'Condomínio'] },
  { name: 'condomeet_reserva_confirmada_v2', category: 'utility', vars: ['Morador', 'Área', 'Data/Hora'] },
  { name: 'condomeet_reserva_cancelada_v2', category: 'utility', vars: ['Morador', 'Área', 'Data/Hora'] },
  { name: 'condomeet_documento_disponivel_v2', category: 'marketing', vars: ['Morador', 'Documento'] },
]

export default function ChatPage() {
  const router = useRouter()
  const supabase = createClient()
  const [loading, setLoading] = useState(true)
  const [authorized, setAuthorized] = useState(false)
  const [conversations, setConversations] = useState<any[]>([])
  const [selectedConv, setSelectedConv] = useState<any>(null)
  const [messages, setMessages] = useState<any[]>([])
  
  // Search & Filters
  const [searchQuery, setSearchQuery] = useState('')
  const [filterType, setFilterType] = useState('all')

  // Send message states
  const [textInput, setTextInput] = useState('')
  const [selectedTemplate, setSelectedTemplate] = useState<any>(null)
  const [templateVars, setTemplateVars] = useState<string[]>([])
  const [manualReason, setManualReason] = useState('')
  const [showTimeline, setShowTimeline] = useState(false)
  const [sending, setSending] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')

  const messagesEndRef = useRef<HTMLDivElement>(null)

  // Auth & Load
  useEffect(() => {
    async function init() {
      try {
        const auth = await getSuperUserInfo()
        if (!auth.authorized) {
          router.push('/admin')
          return
        }

        setAuthorized(true)
        const list = await getConversations(searchQuery, filterType)
        setConversations(list)
      } catch (err) {
        console.error(err)
        router.push('/admin')
      } finally {
        setLoading(false)
      }
    }
    init()
  }, [router, supabase, searchQuery, filterType])

  // Polling for new messages and list refreshes
  useEffect(() => {
    if (!authorized) return
    const interval = setInterval(async () => {
      // Refresh list
      const list = await getConversations(searchQuery, filterType)
      setConversations(list)
      
      // Refresh history if selected
      if (selectedConv) {
        const hist = await getChatHistory(selectedConv.telefone)
        setMessages(hist)
      }
    }, 5000)

    return () => clearInterval(interval)
  }, [authorized, selectedConv, searchQuery, filterType])

  // Load chat history on conversation select
  const selectConversation = async (conv: any) => {
    setSelectedConv(conv)
    setErrorMsg('')
    const hist = await getChatHistory(conv.telefone)
    setMessages(hist)
    
    // Reset inputs
    setTextInput('')
    setSelectedTemplate(null)
    setTemplateVars([])
    setManualReason('')
    
    setTimeout(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
    }, 100)
  }

  // Handle template selection
  const selectTemplate = (name: string) => {
    const t = TEMPLATES.find(x => x.name === name)
    setSelectedTemplate(t || null)
    setTemplateVars(t ? Array(t.vars.length).fill('') : [])
  }

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedConv) return
    
    const isWindowOpen = selectedConv.window_open_until && new Date(selectedConv.window_open_until) >= new Date()
    
    // Validations
    if (!isWindowOpen && !selectedTemplate) {
      setErrorMsg('Janela de 24h fechada. Selecione um template homologado.')
      return
    }
    if (!isWindowOpen && !manualReason.trim()) {
      setErrorMsg('Motivo do envio manual fora da janela é obrigatório para auditoria.')
      return
    }
    if (isWindowOpen && !textInput.trim()) {
      setErrorMsg('Digite a mensagem para enviar.')
      return
    }

    setSending(true)
    setErrorMsg('')

    try {
      let finalMsg = textInput
      if (selectedTemplate) {
        // Preencher mensagem visual para histórico simulando o template
        finalMsg = `[TEMPLATE: ${selectedTemplate.name}]\n` + selectedTemplate.vars.map((v: string, i: number) => `*${v}:* ${templateVars[i]}`).join('\n')
      }

      await sendManualMessage(
        selectedConv.telefone,
        finalMsg,
        selectedTemplate?.name,
        templateVars,
        manualReason
      )

      // Reset
      setTextInput('')
      setSelectedTemplate(null)
      setTemplateVars([])
      setManualReason('')
      
      // Reload history
      const hist = await getChatHistory(selectedConv.telefone)
      setMessages(hist)
      
      setTimeout(() => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
      }, 100)
    } catch (err: any) {
      setErrorMsg(err.message || 'Erro ao enviar mensagem.')
    } finally {
      setSending(false)
    }
  }

  if (loading) {
    return (
      <div className="flex h-[60vh] items-center justify-center">
        <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-[#FC5931]"></div>
      </div>
    )
  }

  if (!authorized) return null

  return (
    <div className="bg-[#f3f4f8] h-[calc(100vh-120px)] flex rounded-2xl overflow-hidden border border-gray-200">
      
      {/* Lado Esquerdo: Lista de Conversas */}
      <div className="w-80 md:w-96 bg-white border-r border-gray-200 flex flex-col flex-shrink-0">
        
        {/* Busca */}
        <div className="p-4 border-b border-gray-100 space-y-3">
          <div className="relative">
            <span className="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
              <Search size={16} />
            </span>
            <input
              type="text"
              placeholder="Buscar morador, apto, condomínio..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-1 focus:ring-[#FC5931]"
            />
          </div>
          
          {/* Filtros Rápidos */}
          <div className="flex flex-wrap gap-1.5">
            {[
              { id: 'all', label: 'Todas' },
              { id: 'janela_aberta', label: 'Janela Aberta' },
              { id: 'janela_fechada', label: 'Janela Fechada' },
              { id: 'nao_lidas', label: 'Não Lidas' },
              { id: 'meta', label: 'Meta' },
              { id: 'botconversa', label: 'BotConversa' }
            ].map(f => (
              <button
                key={f.id}
                onClick={() => setFilterType(f.id)}
                className={`text-[10px] font-bold uppercase tracking-wider px-2 py-1 rounded-full transition-all border ${
                  filterType === f.id
                    ? 'bg-[#FC5931] border-[#FC5931] text-white'
                    : 'bg-gray-50 border-gray-200 text-gray-500 hover:bg-gray-100'
                }`}
              >
                {f.label}
              </button>
            ))}
          </div>
        </div>

        {/* Lista */}
        <div className="flex-1 overflow-y-auto divide-y divide-gray-50">
          {conversations.map(c => {
            const isSelected = selectedConv?.id === c.id
            const isWindowOpen = c.window_open_until && new Date(c.window_open_until) >= new Date()
            return (
              <div
                key={c.id}
                onClick={() => selectConversation(c)}
                className={`p-4 cursor-pointer hover:bg-gray-50 transition-colors flex items-start gap-3 ${
                  isSelected ? 'bg-orange-50/50 border-l-4 border-[#FC5931]' : ''
                }`}
              >
                <div className="bg-gray-100 p-2.5 rounded-xl text-gray-500 flex-shrink-0">
                  <MessageSquare size={18} />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex justify-between items-start">
                    <h4 className="text-sm font-bold text-gray-900 truncate">
                      {c.perfil?.nome_completo || 'Morador Desconhecido'}
                    </h4>
                    <span className="text-[10px] text-gray-400 font-mono">
                      {new Date(c.last_message_at).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </div>
                  <p className="text-xs text-gray-500 mt-0.5 truncate">
                    Unidade: {c.perfil?.bloco_txt && c.perfil?.apto_txt ? `${c.perfil.bloco_txt} - ${c.perfil.apto_txt}` : (c.perfil?.apto_txt || c.perfil?.bloco_txt || '-')} | {c.condominios?.nome || '-'}
                  </p>
                  <p className="text-xs text-gray-400 mt-1 truncate italic">
                    {c.last_message_preview || 'Nenhuma mensagem recente'}
                  </p>
                  
                  {/* Badges e Status */}
                  <div className="flex justify-between items-center mt-2">
                    <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider ${
                      isWindowOpen 
                        ? 'bg-emerald-100 text-emerald-700' 
                        : 'bg-gray-100 text-gray-500'
                    }`}>
                      {isWindowOpen ? 'Janela Aberta' : 'Janela Fechada'}
                    </span>
                    
                    {c.unread_count > 0 && (
                      <span className="h-5 w-5 bg-[#FC5931] text-white text-[10px] font-black rounded-full flex items-center justify-center">
                        {c.unread_count}
                      </span>
                    )}
                  </div>
                </div>
              </div>
            )
          })}
          {conversations.length === 0 && (
            <div className="text-center py-10 text-xs text-gray-400">Nenhuma conversa encontrada.</div>
          )}
        </div>
      </div>

      {/* Lado Direito: Histórico e Envio */}
      <div className="flex-1 bg-gray-50 flex flex-col min-w-0 relative">
        {selectedConv ? (
          <>
            {/* Header Conversa */}
            <div className="bg-white p-4 border-b border-gray-200 flex justify-between items-center flex-shrink-0">
              <div>
                <h3 className="text-sm font-bold text-gray-900">{selectedConv.perfil?.nome_completo || 'Morador'}</h3>
                <p className="text-xs text-gray-500 mt-0.5">Telefone: {selectedConv.telefone}</p>
              </div>
              <div className="flex items-center gap-3">
                <button
                  onClick={() => setShowTimeline(!showTimeline)}
                  className={`p-2 rounded-xl text-gray-400 hover:bg-gray-100 transition-colors ${showTimeline ? 'bg-orange-50 text-[#FC5931]' : ''}`}
                  title="Timeline Operacional"
                >
                  <Info size={18} />
                </button>
                <a
                  href={`https://web.whatsapp.com/send?phone=${selectedConv.telefone}`}
                  target="_blank"
                  rel="noreferrer"
                  className="bg-emerald-500 hover:bg-emerald-600 text-white p-2 rounded-xl transition-colors flex items-center justify-center"
                  title="Abrir no WhatsApp Web"
                >
                  <PhoneCall size={18} />
                </a>
              </div>
            </div>

            {/* Chat Messages */}
            <div className="flex-1 overflow-y-auto p-4 space-y-3 bg-[#efeae2]/40">
              {messages.map(m => {
                const isSystem = m.status !== 'received'
                const statusColor = m.status === 'read' ? 'text-blue-500' : m.status === 'failed' ? 'text-red-500' : 'text-gray-400'
                return (
                  <div key={m.id} className={`flex ${isSystem ? 'justify-end' : 'justify-start'}`}>
                    <div className={`max-w-xs md:max-w-md rounded-2xl px-4 py-2.5 shadow-sm space-y-1 relative ${
                      isSystem 
                        ? 'bg-emerald-50 text-gray-800 rounded-tr-none' 
                        : 'bg-white text-gray-800 rounded-tl-none'
                    }`}>
                      <p className="text-xs leading-relaxed whitespace-pre-wrap">{m.message_content?.value || ''}</p>
                      
                      {/* Meta Footer Info */}
                      <div className="flex justify-between items-center gap-4 text-[9px] text-gray-400 pt-1 border-t border-gray-100">
                        <span className="font-mono">
                          {new Date(m.created_at).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}
                        </span>
                        
                        {isSystem && (
                          <div className="flex items-center gap-1.5">
                            <span className="font-bold uppercase text-[8px] bg-gray-100 px-1 rounded">
                              {m.delivery_result?.provider || 'META'}
                            </span>
                            <span className={`font-semibold capitalize ${statusColor}`}>
                              {m.status}
                            </span>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                )
              })}
              <div ref={messagesEndRef} />
            </div>

            {/* Form de Envio */}
            <form onSubmit={handleSend} className="bg-white p-4 border-t border-gray-200 space-y-3 flex-shrink-0">
              
              {/* Se a janela estiver FECHADA, obriga o preenchimento do template */}
              {!(selectedConv.window_open_until && new Date(selectedConv.window_open_until) >= new Date()) ? (
                <div className="bg-orange-50 border border-orange-100 rounded-xl p-3 space-y-3">
                  <div className="flex items-center gap-2 text-xs text-orange-700 font-semibold">
                    <AlertTriangle size={16} />
                    <span>Janela de 24h fechada. O envio manual exige template aprovado e justificativa.</span>
                  </div>
                  
                  {/* Seleção de Template */}
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <div>
                      <label className="block text-[10px] uppercase font-bold text-gray-500 mb-1">Selecione o Template</label>
                      <select
                        onChange={(e) => selectTemplate(e.target.value)}
                        value={selectedTemplate?.name || ''}
                        className="w-full bg-white border border-gray-200 rounded-lg p-1.5 text-xs focus:outline-none focus:ring-1 focus:ring-[#FC5931]"
                      >
                        <option value="">-- Selecionar --</option>
                        {TEMPLATES.map(t => (
                          <option key={t.name} value={t.name}>{t.name}</option>
                        ))}
                      </select>
                    </div>
                    
                    <div>
                      <label className="block text-[10px] uppercase font-bold text-gray-500 mb-1">Justificativa do Envio</label>
                      <input
                        type="text"
                        placeholder="Ex: Confirmação manual de encomenda urgente"
                        value={manualReason}
                        onChange={(e) => setManualReason(e.target.value)}
                        className="w-full bg-white border border-gray-200 rounded-lg p-1.5 text-xs focus:outline-none focus:ring-1 focus:ring-[#FC5931]"
                      />
                    </div>
                  </div>

                  {/* Variáveis do Template */}
                  {selectedTemplate && (
                    <div className="space-y-2 pt-2 border-t border-orange-100/50">
                      <p className="text-[10px] uppercase font-bold text-gray-500">Parâmetros do Template</p>
                      <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
                        {selectedTemplate.vars.map((v: string, i: number) => (
                          <div key={v}>
                            <label className="block text-[9px] text-gray-400 mb-0.5">{v}</label>
                            <input
                              type="text"
                              value={templateVars[i] || ''}
                              onChange={(e) => {
                                const newVars = [...templateVars]
                                newVars[i] = e.target.value
                                setTemplateVars(newVars)
                              }}
                              className="w-full bg-white border border-gray-200 rounded-md p-1 text-xs focus:outline-none focus:ring-1 focus:ring-[#FC5931]"
                              placeholder={`Valor para ${v}`}
                            />
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              ) : null}

              {/* Input texto livre ou botão de disparo de template */}
              {errorMsg && (
                <p className="text-xs text-red-500 font-semibold">{errorMsg}</p>
              )}

              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder={
                    selectedConv.window_open_until && new Date(selectedConv.window_open_until) >= new Date()
                      ? "Digite a mensagem para enviar..."
                      : "Mensagem será enviada estruturada via template selecionado acima..."
                  }
                  value={textInput}
                  onChange={(e) => setTextInput(e.target.value)}
                  disabled={!(selectedConv.window_open_until && new Date(selectedConv.window_open_until) >= new Date())}
                  className="flex-1 bg-gray-50 border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-1 focus:ring-[#FC5931] disabled:bg-gray-100 disabled:cursor-not-allowed"
                />
                <button
                  type="submit"
                  disabled={sending}
                  className="bg-[#FC5931] hover:bg-[#e04e28] text-white px-5 py-2.5 rounded-xl font-bold flex items-center justify-center gap-1.5 transition-colors disabled:opacity-50"
                >
                  <Send size={16} />
                  <span>{sending ? 'Enviando...' : 'Enviar'}</span>
                </button>
              </div>

            </form>
          </>
        ) : (
          <div className="flex-1 flex flex-col justify-center items-center text-gray-400 p-8 space-y-3">
            <MessageSquare size={48} />
            <p className="text-sm font-semibold">Nenhuma conversa selecionada</p>
            <p className="text-xs text-gray-400">Selecione uma conversa ao lado para acompanhar ou enviar mensagens.</p>
          </div>
        )}

        {/* Timeline Operacional Lateral */}
        {showTimeline && selectedConv && (
          <div className="absolute right-0 top-0 bottom-0 w-80 bg-white border-l border-gray-200 shadow-xl z-20 flex flex-col">
            <div className="p-4 border-b border-gray-200 flex justify-between items-center bg-gray-50">
              <h4 className="text-sm font-bold text-gray-800 flex items-center gap-1.5">
                <Layers size={16} />
                <span>Timeline Operacional</span>
              </h4>
              <button
                onClick={() => setShowTimeline(false)}
                className="text-xs font-bold text-gray-400 hover:text-gray-600"
              >
                Fechar
              </button>
            </div>
            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              <div className="space-y-2">
                <p className="text-[10px] uppercase font-bold text-gray-400">Status da Janela</p>
                <div className="bg-gray-50 rounded-xl p-3 border border-gray-100 text-xs space-y-1.5">
                  <div className="flex justify-between">
                    <span className="text-gray-500">Janela 24h:</span>
                    <span className={`font-bold ${
                      selectedConv.window_open_until && new Date(selectedConv.window_open_until) >= new Date()
                        ? 'text-emerald-600'
                        : 'text-red-500'
                    }`}>
                      {selectedConv.window_open_until && new Date(selectedConv.window_open_until) >= new Date() ? 'Aberta' : 'Fechada'}
                    </span>
                  </div>
                  {selectedConv.window_open_until && (
                    <div className="flex justify-between">
                      <span className="text-gray-500">Expira em:</span>
                      <span className="font-mono text-gray-700">
                        {new Date(selectedConv.window_open_until).toLocaleString('pt-BR')}
                      </span>
                    </div>
                  )}
                </div>
              </div>

              <div className="space-y-2">
                <p className="text-[10px] uppercase font-bold text-gray-400">Provedor Ativo</p>
                <div className="bg-gray-50 rounded-xl p-3 border border-gray-100 text-xs space-y-1">
                  <div className="flex justify-between">
                    <span className="text-gray-500">Provedor Atual:</span>
                    <span className="font-bold text-indigo-600 uppercase">{selectedConv.current_provider}</span>
                  </div>
                </div>
              </div>

              <div className="space-y-2">
                <p className="text-[10px] uppercase font-bold text-gray-400">Histórico de Disparos Manuais</p>
                <div className="space-y-2">
                  {messages.filter(m => m.manual_sent_by).map(m => (
                    <div key={m.id} className="bg-orange-50/50 rounded-xl p-3 border border-orange-100/50 text-xs space-y-1">
                      <div className="flex justify-between text-[10px] text-gray-400">
                        <span>Por: {m.manual_sent_by}</span>
                        <span>{new Date(m.manual_sent_at).toLocaleDateString('pt-BR')}</span>
                      </div>
                      <p className="text-gray-700 mt-1 font-semibold">Motivo: {m.manual_reason}</p>
                    </div>
                  ))}
                  {messages.filter(m => m.manual_sent_by).length === 0 && (
                    <p className="text-xs text-gray-400 text-center py-4">Nenhum envio manual registrado nesta conversa.</p>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

    </div>
  )
}
