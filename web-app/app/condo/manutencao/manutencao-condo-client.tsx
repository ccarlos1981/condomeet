'use client'

import { useState, useCallback, useEffect } from 'react'
import { Wrench, MessageSquare, ChevronRight } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

interface ManutencaoRow {
  id: string
  condominio_id: string
  titulo: string
  descricao: string
  tipo: string
  status: string
  data_inicio: string
  data_fim: string
  visivel_moradores: boolean
  valor: number
  recorrencia: string
}

export default function ManutencaoCondoClient({ manutencoes }: { manutencoes: ManutencaoRow[] }) {
  const [filterTipo, setFilterTipo] = useState('Todos')
  const [filterStatus, setFilterStatus] = useState('Todos')
  const [viewingId, setViewingId] = useState<string | null>(null)

  const filteredList = manutencoes.filter(m => {
    if (filterStatus !== 'Todos' && m.status !== filterStatus) return false;
    if (filterTipo !== 'Todos' && m.tipo !== filterTipo) return false;
    return true
  })

  return (
    <div>
      {/* Filters */}
      <div className="flex gap-3 mb-6">
        <select 
          title="Filtrar por Tipo"
          value={filterTipo}
          onChange={e => setFilterTipo(e.target.value)}
          className="flex-1 bg-white border border-gray-200 rounded-xl px-4 py-2 text-sm text-gray-700 outline-none shadow-sm"
        >
          <option value="Todos">Tipo</option>
          <option value="Preventiva">Preventiva</option>
          <option value="Corretiva">Corretiva</option>
          <option value="Urgente">Urgente</option>
          <option value="Outros">Outros</option>
        </select>

        <select 
          title="Filtrar por Status"
          value={filterStatus}
          onChange={e => setFilterStatus(e.target.value)}
          className="flex-1 bg-white border border-gray-200 rounded-xl px-4 py-2 text-sm text-gray-700 outline-none shadow-sm"
        >
          <option value="Todos">Status</option>
          <option value="Agendada">Agendada</option>
          <option value="Em Andamento">Em Andamento</option>
          <option value="Concluída">Concluída</option>
        </select>
      </div>

      {/* Cards List */}
      <div className="space-y-3">
        {filteredList.map(m => (
          <div 
            key={m.id} 
            onClick={() => setViewingId(m.id)}
            className="bg-white border border-gray-200 rounded-2xl p-4 flex items-center gap-4 cursor-pointer hover:border-[#fc5931] hover:shadow-md transition-all group"
          >
            <div className="w-12 h-12 bg-orange-50 rounded-xl flex items-center justify-center shrink-0">
               <Wrench className="text-[#fc5931]" size={24} />
            </div>
            
            <div className="flex-1 min-w-0">
              <h3 className="font-bold text-gray-900 text-sm truncate">{m.titulo}</h3>
              <p className="text-xs text-gray-500 mt-1 line-clamp-1">
                {m.data_inicio ? new Date(m.data_inicio).toLocaleDateString('pt-BR') : '-'} até {m.data_fim ? new Date(m.data_fim).toLocaleDateString('pt-BR') : '-'}
              </p>
            </div>

            <div className="flex flex-col items-end gap-1">
               <span className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-md border
                  ${m.status === 'Concluída' ? 'text-green-600 border-green-200 bg-green-50' : 
                    m.status === 'Em Andamento' ? 'text-blue-600 border-blue-200 bg-blue-50' : 
                    'text-amber-600 border-amber-200 bg-amber-50'}
               `}>
                 {m.status}
               </span>
               <ChevronRight size={18} className="text-gray-300 group-hover:text-[#fc5931] group-hover:translate-x-1 transition-all mt-1" />
            </div>
          </div>
        ))}

        {filteredList.length === 0 && (
          <div className="py-12 text-center text-gray-400 text-sm">
             Nenhuma manutenção encontrada para os filtros aplicados.
          </div>
        )}
      </div>

      {/* View Modal */}
      {viewingId && (
        <ResidentViewModal 
          manutencao={manutencoes.find(m => m.id === viewingId)!} 
          onClose={() => setViewingId(null)} 
        />
      )}
    </div>
  )
}

// -------------------------------------------------------------------------------- //

type Foto = { id: string; url: string; created_at: string }
type Comentario = {
  id: string
  texto: string
  created_at: string
  perfil: { nome: string; papel_sistema: string } | null
}

function ResidentViewModal({ manutencao, onClose }: { manutencao: ManutencaoRow, onClose: () => void }) {
  const [tab, setTab] = useState<'geral'|'fotos'|'comentarios'>('geral')
  const supabase = createClient()
  
  // Fotos State
  const [fotos, setFotos] = useState<Foto[]>([])
  const [loadingFotos, setLoadingFotos] = useState(false)

  // Comentarios State
  const [comentarios, setComentarios] = useState<Comentario[]>([])
  const [newComment, setNewComment] = useState('')
  const [loadingComments, setLoadingComments] = useState(false)
  const [submittingComment, setSubmittingComment] = useState(false)

  const fetchFotos = useCallback(async () => {
    setLoadingFotos(true)
    const { data } = await supabase
      .from('manutencao_fotos')
      .select('*')
      .eq('manutencao_id', manutencao.id)
      .order('ordem', { ascending: true })
    
    if (data) setFotos(data)
    setLoadingFotos(false)
  }, [manutencao.id, supabase])

  const fetchComentarios = useCallback(async () => {
    setLoadingComments(true)
    const { data } = await supabase
      .from('manutencao_comentarios')
      .select('id, texto, created_at, perfil(nome, papel_sistema)')
      .eq('manutencao_id', manutencao.id)
      .order('created_at', { ascending: true })
    
    if (data) {
       // @ts-expect-error type safety
      setComentarios(data as Comentario[])
    }
    setLoadingComments(false)
  }, [manutencao.id, supabase])

  useEffect(() => {
    if (tab === 'fotos') fetchFotos()
    if (tab === 'comentarios') fetchComentarios()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab])

  async function handleAddComment() {
    if (!newComment.trim()) return
    setSubmittingComment(true)
    
    const { data: sessionData } = await supabase.auth.getSession()
    if (!sessionData.session) return

    const { error } = await supabase
      .from('manutencao_comentarios')
      .insert({
        manutencao_id: manutencao.id,
        perfil_id: sessionData.session.user.id,
        texto: newComment
      })
      
    if (!error) {
      setNewComment('')
      fetchComentarios()
    } else {
      alert('Erro ao enviar comentário')
    }
    setSubmittingComment(false)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
      <div className="bg-white w-full max-w-lg rounded-2xl shadow-xl flex flex-col max-h-[90vh]">
        
        <div className="p-4 border-b relative shrink-0">
           <div className="text-center font-bold text-gray-800 text-lg sm:text-xl">Detalhes</div>
           <button onClick={onClose} className="absolute right-4 top-4 text-red-500 font-bold hover:bg-red-50 p-1 px-3 rounded text-lg">X</button>
        </div>

        <div className="flex border-b shrink-0">
           <button onClick={() => setTab('geral')} className={`flex-1 py-3 text-sm font-bold transition-all ${tab === 'geral' ? 'text-[#fc5931] border-b-2 border-[#fc5931]' : 'text-gray-500'}`}>Geral</button>
           <button onClick={() => setTab('fotos')} className={`flex-1 py-3 text-sm font-bold transition-all ${tab === 'fotos' ? 'text-[#fc5931] border-b-2 border-[#fc5931]' : 'text-gray-500'}`}>Fotos</button>
           <button onClick={() => setTab('comentarios')} className={`flex-1 py-3 text-sm font-bold transition-all ${tab === 'comentarios' ? 'text-[#fc5931] border-b-2 border-[#fc5931]' : 'text-gray-500'}`}>Comentários</button>
        </div>

        <div className="p-5 overflow-y-auto flex-1 custom-scrollbar">
           {tab === 'geral' && (
              <div className="space-y-4">
                 <div>
                   <span className="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1">Manutenção</span>
                   <span className="text-gray-800 font-medium text-base">{manutencao.titulo}</span>
                 </div>
                 <div>
                   <span className="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1">Descrição</span>
                   <span className="text-gray-600 text-sm whitespace-pre-wrap">{manutencao.descricao || '-'}</span>
                 </div>
                 <div className="grid grid-cols-2 gap-4">
                    <div>
                      <span className="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1">Início</span>
                      <span className="text-gray-600 text-sm">{manutencao.data_inicio ? new Date(manutencao.data_inicio).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '-'}</span>
                    </div>
                    <div>
                      <span className="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1">Fim</span>
                      <span className="text-gray-600 text-sm">{manutencao.data_fim ? new Date(manutencao.data_fim).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '-'}</span>
                    </div>
                 </div>
                 <div className="grid grid-cols-2 gap-4">
                    <div>
                      <span className="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1">Status</span>
                      <span className="text-gray-600 text-sm font-semibold">{manutencao.status}</span>
                    </div>
                    <div>
                      <span className="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1">Tipo</span>
                      <span className="text-gray-600 text-sm">{manutencao.tipo}</span>
                    </div>
                 </div>
              </div>
           )}
           
           {tab === 'fotos' && (
              <div className="flex flex-col">
                 <h3 className="text-lg font-bold text-gray-800 mb-4">Registro Fotográfico</h3>
                 {loadingFotos ? (
                    <div className="flex justify-center p-8"><div className="w-8 h-8 rounded-full border-4 border-[#fc5931] border-t-transparent animate-spin"></div></div>
                 ) : fotos.length === 0 ? (
                    <div className="border border-dashed border-gray-300 w-full bg-gray-50 rounded-xl py-12 flex items-center justify-center text-gray-400 text-sm">
                       Nenhuma foto registrada
                    </div>
                 ) : (
                    <div className="grid grid-cols-2 gap-3">
                       {fotos.map(f => (
                          <div key={f.id} className="rounded-xl overflow-hidden shadow border border-gray-100">
                             {/* eslint-disable-next-line @next/next/no-img-element */}
                             <img src={f.url} alt="Manutenção" className="w-full h-32 object-cover" />
                          </div>
                       ))}
                    </div>
                 )}
              </div>
           )}
           
           {tab === 'comentarios' && (
              <div className="flex flex-col h-full min-h-[300px]">
                 <div className="flex-1 space-y-3 mb-4 custom-scrollbar">
                    {loadingComments ? (
                       <div className="flex justify-center p-8"><div className="w-8 h-8 rounded-full border-4 border-[#fc5931] border-t-transparent animate-spin"></div></div>
                    ) : comentarios.length === 0 ? (
                       <div className="flex flex-col items-center justify-center h-full text-gray-400 gap-2 py-10">
                          <MessageSquare size={32} className="opacity-50" />
                          <span className="text-sm">Nenhum comentário</span>
                       </div>
                    ) : (
                       comentarios.map(c => (
                          <div key={c.id} className="bg-gray-50 border border-gray-100 p-3 rounded-xl">
                             <div className="flex justify-between items-baseline mb-1">
                                <strong className="text-gray-800 text-sm">
                                  {c.perfil?.nome || 'Usuário Desconhecido'} 
                                  {c.perfil?.papel_sistema ? <span className="text-[10px] uppercase font-bold text-gray-500 ml-2 bg-gray-200 px-1.5 py-0.5 rounded">{c.perfil.papel_sistema}</span> : null}
                                </strong>
                             </div>
                             <p className="text-gray-600 text-sm whitespace-pre-wrap leading-relaxed">{c.texto}</p>
                             <div className="text-right mt-1">
                                <span className="text-[10px] text-gray-400">{new Date(c.created_at).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}</span>
                             </div>
                          </div>
                       ))
                    )}
                 </div>
                 
                 <div className="flex gap-2 relative mt-auto shrink-0">
                    <textarea 
                       title="Adicionar comentário"
                       value={newComment}
                       onChange={e => setNewComment(e.target.value)}
                       placeholder="Escreva algo..."
                       className="flex-1 border border-gray-200 rounded-xl px-4 py-3 text-sm outline-none resize-none h-14 bg-gray-50 focus:bg-white focus:ring-2 focus:ring-[#fc5931]/20 transition-all"
                    />
                    <button 
                       title="Enviar Comentário"
                       disabled={submittingComment || !newComment.trim()}
                       onClick={handleAddComment}
                       className="bg-[#fc5931] text-white px-5 rounded-xl font-bold hover:bg-[#fc5931]/90 transition-colors disabled:opacity-50 flex items-center justify-center"
                    >
                       Enviar
                    </button>
                 </div>
              </div>
           )}
        </div>
        
      </div>
    </div>
  )
}
