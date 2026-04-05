'use client'

import { useState, useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { SuporteChat } from './page'
import { CheckCheck, Send } from 'lucide-react'

type Message = {
  id: string
  chat_id: string
  sender_id: string
  is_admin: boolean
  texto: string
  created_at: string
}

type Props = {
  initialChats: SuporteChat[]
  adminId: string
}

function timeAgo(dateString: string) {
  const date = new Date(dateString)
  const now = new Date()
  const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000)

  if (diffInSeconds < 60) return 'agora'
  if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)} m atrás`
  if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)} h atrás`
  if (diffInSeconds < 2592000) return `${Math.floor(diffInSeconds / 86400)} d atrás`
  return `${Math.floor(diffInSeconds / 2592000)} meses atrás`
}

export default function SuporteAdminClient({ initialChats, adminId }: Props) {
  const supabase = createClient()
  const [chats, setChats] = useState<SuporteChat[]>(initialChats)
  const [activeChatId, setActiveChatId] = useState<string | null>(null)
  
  const [messages, setMessages] = useState<Message[]>([])
  const [loadingMessages, setLoadingMessages] = useState(false)
  const [inputText, setInputText] = useState('')
  
  const messagesEndRef = useRef<HTMLDivElement>(null)

  const activeChat = chats.find(c => c.id === activeChatId)

  useEffect(() => {
    // Escuta novas mensagens para dar um efeito em tempo real global
    const channel = supabase.channel('suporte_admin_global')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'suporte_sistema_mensagens' },
        (payload) => {
          const newMsg = payload.new as Message
          // Update message list if chat is active
          if (newMsg && activeChatId === newMsg.chat_id && payload.eventType === 'INSERT') {
             setMessages(prev => {
                // Previne duplicação caso já tenhamos inserido na mão antes da subscription chegar
                if (prev.find(m => m.id === newMsg.id)) return prev
                return [...prev, newMsg]
             })
             
             // Marcar admin como lido se estiver com a tela do chat aberta e quem mandou for o user
             if (!newMsg.is_admin) {
                supabase.from('suporte_sistema_chats').update({ unread_admin: 0 }).eq('id', activeChatId).then()
             }
          }
          
          // Re-fetch lista de chats para atualizar "last_message" no painel esquerdo
          fetchChats()
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'suporte_sistema_chats' },
        () => {
           // Atualizar lista para pegar as mudanças de "unread_user" (para colorir azuis)
           fetchChats()
        }
      )
      .subscribe()
      
    return () => {
      supabase.removeChannel(channel)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeChatId])

  const fetchChats = async () => {
    const { data: fetchResult } = await supabase
      .from('suporte_sistema_chats')
      .select('id, resident_id, condominio_id, last_message, unread_admin, unread_user, updated_at, created_at')
      .order('updated_at', { ascending: false })

    if (fetchResult) {
      // Re-hydrate relationships from the initial list (or let Next router handle full refresh)
      // For simplicity, we just merge local state profiles
      setChats(prev => {
        return fetchResult.map((t: { id: string }) => {
            const existing = prev.find(p => p.id === t.id)
            return {
                ...t,
                perfil: existing?.perfil || null,
                condominio: existing?.condominio || null
            }
        }) as SuporteChat[]
      })
    }
  }

  useEffect(() => {
    const fetchMessages = async () => {
      if (!activeChatId) return
      setLoadingMessages(true)
      
      // Zera não-lidas quando o admin abre
      await supabase.from('suporte_sistema_chats').update({ unread_admin: 0 }).eq('id', activeChatId)
      
      setChats(prev => prev.map(c => c.id === activeChatId ? { ...c, unread_admin: 0 } : c))

      const { data } = await supabase
        .from('suporte_sistema_mensagens')
        .select('*')
        .eq('chat_id', activeChatId)
        .order('created_at', { ascending: true })

      if (data) setMessages(data as Message[])
      setLoadingMessages(false)
      scrollToBottom()
    }
    
    fetchMessages()
  }, [activeChatId, supabase])

  useEffect(() => {
    scrollToBottom()
  }, [messages])

  const scrollToBottom = () => {
    setTimeout(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
    }, 100)
  }

  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!inputText.trim() || !activeChatId) return

    const tempText = inputText
    setInputText('')

    // Opcional: Inserção otimista aqui

    const { error } = await supabase
      .from('suporte_sistema_mensagens')
      .insert({
        chat_id: activeChatId,
        sender_id: adminId,
        texto: tempText,
        is_admin: true
      })

    if (error) {
      alert('Erro ao enviar mensagem: ' + error.message)
      setInputText(tempText)
    }
  }

  return (
    <div className="flex h-full flex-grow overflow-hidden bg-gray-50 flex-1">
      {/* LEFT COLUMN: Chat List */}
      <div className="w-1/3 flex flex-col border-r border-gray-200 bg-white">
        <div className="p-4 border-b border-gray-200 bg-gray-100 font-semibold text-gray-700">
          Chamados Abertos
        </div>
        
        <div className="flex-1 overflow-y-auto">
          {chats.length === 0 ? (
            <div className="p-8 text-center text-sm text-gray-500">Nenhum chamado recebido.</div>
          ) : (
            chats.map(chat => {
              const isActive = chat.id === activeChatId
              const isUnread = chat.unread_admin > 0
              
              const displayName = chat.perfil?.nome_completo || 'Sem Nome'
              const aptTxt = chat.perfil?.apto_txt ? `Apto ${chat.perfil.apto_txt}` : ''
              const blcTxt = chat.perfil?.bloco_txt ? `Bl ${chat.perfil.bloco_txt}` : ''
              const detailLine = [aptTxt, blcTxt].filter(Boolean).join(' - ')

              return (
                <div
                  key={chat.id}
                  onClick={() => setActiveChatId(chat.id)}
                  className={`
                    p-4 border-b border-gray-100 cursor-pointer transition flex flex-col gap-1
                    ${isActive ? 'bg-primary-50 border-primary-200' : 'hover:bg-gray-50'}
                    ${isUnread ? 'bg-blue-50/50' : ''}
                  `}
                >
                  <div className="flex justify-between items-start">
                     <span className={`text-sm ${isUnread ? 'font-bold text-gray-900' : 'font-medium text-gray-800'} truncate`}>
                         {displayName}
                     </span>
                     {isUnread && (
                       <span className="bg-red-500 text-white text-xs font-bold w-5 h-5 flex items-center justify-center rounded-full">
                          {chat.unread_admin}
                       </span>
                     )}
                  </div>
                  <div className="flex flex-col text-xs text-gray-500">
                    <span className="font-semibold text-indigo-700">{chat.condominio?.nome}</span>
                    <span>{detailLine}</span>
                  </div>
                  <div className="mt-2 text-sm text-gray-600 truncate opacity-80">
                    {chat.last_message || 'Nova conversa...'}
                  </div>
                  <div className="text-[10px] text-gray-400 text-right mt-1">
                    {chat.updated_at ? timeAgo(chat.updated_at) : ''}
                  </div>
                </div>
              )
            })
          )}
        </div>
      </div>

      {/* RIGHT COLUMN: Chat Area */}
      <div className="w-2/3 flex flex-col bg-[#e5ddd5] relative">
         {!activeChatId ? (
            <div className="flex-1 flex flex-col items-center justify-center text-gray-400">
               <svg className="w-24 h-24 mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1" d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a1.994 1.994 0 01-1.414-.586m0 0L11 14h4a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2v4l.586-.586z"></path></svg>
               <p className="text-lg">Suporte Condomeet</p>
               <p className="text-sm mt-2 max-w-md text-center">Selecione um usuário ao lado para visualizar a conversa e responder.</p>
            </div>
         ) : (
             <>
               {/* Chat Header */}
               <div className="bg-white px-6 py-3 border-b flex items-center shadow-sm z-10 space-x-4">
                  <div className="h-10 w-10 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-700 font-bold">
                     {activeChat?.perfil?.nome_completo?.charAt(0).toUpperCase() || 'U'}
                  </div>
                  <div className="flex flex-col">
                     <span className="font-semibold text-gray-800">{activeChat?.perfil?.nome_completo}</span>
                     <span className="text-xs text-gray-500 font-medium">
                         Condomínio: {activeChat?.condominio?.nome} 
                         {activeChat?.perfil?.bloco_txt && ` | Bloco ${activeChat.perfil.bloco_txt}`}
                         {activeChat?.perfil?.apto_txt && ` | Apto ${activeChat.perfil.apto_txt}`}
                     </span>
                  </div>
               </div>

               {/* Messages Area */}
               <div className="flex-1 overflow-y-auto p-6 flex flex-col space-y-4 relative">
                 {/* WhatsApp default web background pattern simulation below */}
                 <div className="absolute inset-0 opacity-10 pointer-events-none" style={{ backgroundImage: 'radial-gradient(#000 1px, transparent 1px)', backgroundSize: '16px 16px'}}></div>

                 {loadingMessages && <div className="text-center p-4"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-700 mx-auto"></div></div>}
                 
                 {!loadingMessages && (() => {
                    const adminMessagesCount = messages.filter(m => m.is_admin).length;
                    const unreadUserCount = activeChat?.unread_user || 0;
                    const readThreshold = adminMessagesCount - unreadUserCount;
                    let currentAdminMessageIndex = 0;

                    return messages.map(msg => {
                       const isAdmin = msg.is_admin
                       let isRead = false;
                       if (isAdmin) {
                          isRead = currentAdminMessageIndex < readThreshold;
                          currentAdminMessageIndex++;
                       }

                       return (
                          <div key={msg.id} className={`flex ${isAdmin ? 'justify-end' : 'justify-start'}`}>
                             <div className={`
                                max-w-[70%] rounded-lg px-3 py-1.5 shadow-sm relative text-sm min-w-[90px]
                                ${isAdmin ? 'bg-[#d9fdd3] text-gray-900 rounded-tr-none' : 'bg-white text-gray-800 rounded-tl-none'}
                             `}>
                                {!isAdmin && (
                                   <div className="text-[11px] font-bold text-gray-400 mb-0.5 mt-0.5">
                                      Morador
                                   </div>
                                )}
                                <div className="whitespace-pre-wrap mix-blend-multiply text-[14px] leading-relaxed pb-3">{msg.texto}</div>
                                <div className="absolute right-2 bottom-1.5 text-[10px] text-gray-500 flex items-center justify-end gap-1 opacity-80">
                                   <span>{new Date(msg.created_at).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}</span>
                                   {isAdmin && (
                                      isRead ? (
                                         <CheckCheck size={14} className="text-blue-500" strokeWidth={2.5} />
                                      ) : (
                                         <CheckCheck size={14} className="text-gray-400" strokeWidth={2.5} />
                                      )
                                   )}
                                </div>
                             </div>
                          </div>
                       )
                    })
                 })()}
                 <div ref={messagesEndRef} />
               </div>

               {/* Chat Input */}
               <div className="bg-[#f0f2f5] p-4 flex items-center gap-4 z-10">
                  <form onSubmit={sendMessage} className="flex-1 flex gap-2">
                     <input
                        type="text"
                        value={inputText}
                        onChange={(e) => setInputText(e.target.value)}
                        placeholder="Digite uma mensagem..."
                        className="flex-1 bg-white border-0 rounded-full px-6 py-3 focus:outline-none focus:ring-1 focus:ring-primary-500 shadow-sm"
                     />
                     <button
                        type="submit"
                        disabled={!inputText.trim()}
                        className="h-12 w-12 rounded-full bg-teal-600 hover:bg-teal-700 text-white flex items-center justify-center disabled:opacity-50 transition shadow-sm"
                        title="Enviar mensagem"
                     >
                        <Send size={20} className="-mr-1 rotate-45 transform fill-white" />
                     </button>
                  </form>
               </div>
             </>
         )}
      </div>
    </div>
  )
}
