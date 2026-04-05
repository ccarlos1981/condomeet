'use client'

import { useState, useMemo, useEffect, useCallback } from 'react'
import { Plus, Search, Info, Edit, Trash2, ChevronLeft, ChevronRight, UploadCloud, MessageSquare } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

// simple utils for calendar
const getDaysInMonth = (year: number, month: number) => new Date(year, month + 1, 0).getDate()
const getFirstDayOfMonth = (year: number, month: number) => new Date(year, month, 1).getDay()

const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro']

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
  fornecedor_id?: string
}

interface FornecedorRow {
  id: string
  nome: string
  documento: string | null
}

export default function ManutencaoClient({ manutencoes, fornecedores, condoId }: { manutencoes: ManutencaoRow[], fornecedores: FornecedorRow[], condoId: string }) {
  const router = useRouter()
  const supabase = createClient()
  
  const [currentDate, setCurrentDate] = useState(new Date())
  const [selectedDate, setSelectedDate] = useState<Date | null>(null)
  
  const [searchTerm, setSearchTerm] = useState('')
  const [filterStatus, setFilterStatus] = useState('Todos')
  const [filterTipo, setFilterTipo] = useState('Todos')
  
  const [isInserting, setIsInserting] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [viewingId, setViewingId] = useState<string | null>(null)

  // Calender generation
  const year = currentDate.getFullYear()
  const month = currentDate.getMonth()
  const daysInMonth = getDaysInMonth(year, month)
  const firstDay = getFirstDayOfMonth(year, month)
  
  const handlePrevMonth = () => setCurrentDate(new Date(year, month - 1, 1))
  const handleNextMonth = () => setCurrentDate(new Date(year, month + 1, 1))

  // Find out what days have maintenance (for drawing the red circle)
  // Generating occurrences based on their rule is complex in-browser for all types; 
  // currently we track the data_inicio for simplicity of calendar markings as requested.
  const activeDays = useMemo(() => {
    const days = new Set<number>()
    // For visual simplicity in this MVP, we map exact start date.
    // If user specified weekly, we can dynamically add those days.
    manutencoes.forEach(m => {
      if (!m.data_inicio) return;
      const d = new Date(m.data_inicio)
      if (d.getFullYear() === year && d.getMonth() === month) {
        days.add(d.getDate())
      }
      
      // Repetição Visual Simplificada
      if (m.recorrencia === 'Semanalmente') {
        const current = new Date(d)
        while (current.getFullYear() <= year && current.getMonth() <= month) {
           if (current.getFullYear() === year && current.getMonth() === month) {
             days.add(current.getDate())
           }
           current.setDate(current.getDate() + 7)
        }
      } else if (m.recorrencia === 'Mensalmente') {
         if (d.getFullYear() <= year) {
           days.add(d.getDate())
         }
      }
    })
    return days
  }, [manutencoes, year, month])

  const filteredList = manutencoes.filter(m => {
    if (searchTerm && !m.titulo.toLowerCase().includes(searchTerm.toLowerCase())) return false;
    if (filterStatus !== 'Todos' && m.status !== filterStatus) return false;
    if (filterTipo !== 'Todos' && m.tipo !== filterTipo) return false;
    
    if (selectedDate) {
      if (!m.data_inicio) return false;
      const d = new Date(m.data_inicio)
      // Checks for exact match or visual repetition.
      if (m.recorrencia === 'Nenhuma') {
        if (d.toDateString() !== selectedDate.toDateString()) return false;
      } else if (m.recorrencia === 'Semanalmente') {
         // rough check
         if (d.getDay() !== selectedDate.getDay() || d.getTime() > selectedDate.getTime()) return false;
      } else if (m.recorrencia === 'Mensalmente') {
         if (d.getDate() !== selectedDate.getDate() || d.getTime() > selectedDate.getTime()) return false;
      }
    }
    return true
  })

  // Delete simple handler
  const handleDelete = async (id: string) => {
    if(!confirm('Tem certeza?')) return
    await supabase.from('manutencoes').delete().eq('id', id)
    router.refresh()
  }

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 min-h-[500px]">
      
      {/* HEADER & FILTERS */}
      <div className="p-6 border-b border-gray-100">
        <div className="flex flex-col lg:flex-row gap-4 justify-between items-center">
          <button 
            onClick={() => setIsInserting(true)}
            className="bg-[#FC5931] text-white px-5 py-2.5 rounded-xl font-medium flex items-center justify-center gap-2 hover:bg-[#FC5931]/90 transition-all w-full lg:w-auto"
          >
            <Plus size={18} />
            Insira Manutenção
          </button>

          <div className="flex items-center gap-3 w-full lg:w-auto">
            <div className="relative flex-1 lg:w-64">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
              <input 
                type="text" 
                placeholder="Manutenção" 
                value={searchTerm}
                onChange={e => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-[#FC5931]/20 outline-none"
              />
            </div>
            <select 
              title="Filtrar por Status"
              value={filterStatus}
              onChange={e => setFilterStatus(e.target.value)}
              className="px-4 py-2 bg-gray-50 border-none rounded-xl text-sm outline-none w-32"
            >
              <option value="Todos">Status</option>
              <option value="Agendada">Agendada</option>
              <option value="Em Andamento">Em Andamento</option>
              <option value="Concluída">Concluída</option>
            </select>
            <select 
              title="Filtrar por Tipo"
              value={filterTipo}
              onChange={e => setFilterTipo(e.target.value)}
              className="px-4 py-2 bg-gray-50 border-none rounded-xl text-sm outline-none w-32"
            >
              <option value="Todos">Tipo</option>
              <option value="Preventiva">Preventiva</option>
              <option value="Corretiva">Corretiva</option>
              <option value="Urgente">Urgente</option>
              <option value="Outros">Outros</option>
            </select>
          </div>
        </div>
      </div>

      {/* BODY (CALENDAR + TABLE) */}
      <div className="flex flex-col xl:flex-row gap-6 p-6">
        
        {/* Left: Calendar */}
        <div className="w-full xl:w-80 shrink-0">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-bold text-gray-900 text-lg">
              {months[month]} {year}
            </h3>
            <div className="flex gap-1">
              <button title="Mês anterior" onClick={handlePrevMonth} className="p-1 hover:bg-gray-100 rounded-lg text-gray-400 hover:text-gray-800 transition-all font-bold">
                <ChevronLeft size={20} />
              </button>
              <button title="Próximo mês" onClick={handleNextMonth} className="p-1 hover:bg-gray-100 rounded-lg text-gray-400 hover:text-gray-800 transition-all font-bold">
                <ChevronRight size={20} />
              </button>
            </div>
          </div>
          
          <div className="grid grid-cols-7 gap-1 text-center mb-2">
            {['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab'].map(d => (
              <div key={d} className="text-xs text-gray-400 font-medium py-1">{d}</div>
            ))}
          </div>
          
          <div className="grid grid-cols-7 gap-1">
            {Array.from({ length: firstDay }).map((_, i) => (
              <div key={`empty-${i}`} className="h-10"></div>
            ))}
            {Array.from({ length: daysInMonth }).map((_, i) => {
              const day = i + 1
              const hasMaintenance = activeDays.has(day)
              const isSelected = selectedDate?.getDate() === day && selectedDate?.getMonth() === month && selectedDate?.getFullYear() === year

              return (
                <button
                  key={day}
                  onClick={() => setSelectedDate(isSelected ? null : new Date(year, month, day))}
                  className={`relative flex items-center justify-center font-medium h-10 w-full rounded-full transition-all text-sm
                    ${isSelected ? 'bg-gray-100 text-[#FC5931]' : 'hover:bg-gray-50 text-gray-700'}
                  `}
                >
                  <span className="z-10">{day.toString().padStart(2, '0')}</span>
                  {hasMaintenance && !isSelected && (
                    <span className="absolute inset-2 border-2 border-[#FC5931] rounded-full z-0 opacity-80" />
                  )}
                  {hasMaintenance && isSelected && (
                    <span className="absolute inset-2 bg-[#FC5931] rounded-full z-0" />
                  )}
                  {hasMaintenance && isSelected && (
                     <span className="absolute inset-0 flex items-center justify-center text-white z-10 font-medium">{day.toString().padStart(2, '0')}</span>
                  )}
                </button>
              )
            })}
          </div>

          {selectedDate && (
            <button onClick={() => setSelectedDate(null)} className="w-full mt-4 text-sm text-gray-500 hover:text-gray-800 flex items-center justify-center gap-2">
              <Trash2 size={14} /> Limpar seleção da data
            </button>
          )}
        </div>

        {/* Right: Table */}
        <div className="flex-1 overflow-x-auto">
          <table className="w-full min-w-[600px] text-left">
             <thead className="bg-gray-100/60 rounded-xl text-gray-600 text-sm">
                <tr>
                   <th className="font-semibold py-3 px-4 w-28 text-center rounded-l-xl">Ações</th>
                   <th className="font-semibold py-3 px-4">Manutenção</th>
                   <th className="font-semibold py-3 px-4">Data de início</th>
                   <th className="font-semibold py-3 px-4">Data do Fim</th>
                   <th className="font-semibold py-3 px-4 rounded-r-xl">Status</th>
                </tr>
             </thead>
             <tbody>
                {filteredList.map(m => (
                  <tr key={m.id} className="border-b border-gray-50 last:border-0 hover:bg-gray-50/50">
                     <td className="py-4 px-4 flex justify-center gap-3 text-gray-400">
                        <button title="Ver informações" onClick={() => setViewingId(m.id)} className="hover:text-[#FC5931] bg-gray-100 p-1.5 rounded-lg text-[#FC5931] hover:bg-[#fc5931]/10">
                          <Info size={16} />
                        </button>
                        <button title="Editar" onClick={() => setEditingId(m.id)} className="hover:text-amber-500 bg-gray-100 p-1.5 rounded-lg text-amber-500 hover:bg-amber-100/50">
                          <Edit size={16} />
                        </button>
                        <button title="Excluir" onClick={() => handleDelete(m.id)} className="hover:text-red-500 bg-gray-100 p-1.5 rounded-lg text-red-500 hover:bg-red-100/50">
                          <Trash2 size={16} />
                        </button>
                     </td>
                     <td className="py-4 px-4 text-sm text-gray-700 font-medium">
                       {m.titulo}
                     </td>
                     <td className="py-4 px-4 text-sm text-gray-500">
                       {m.data_inicio ? new Date(m.data_inicio).toLocaleString('pt-BR', { dateStyle: 'medium', timeStyle: 'short' }) : '-'}
                     </td>
                     <td className="py-4 px-4 text-sm text-gray-500">
                       {m.data_fim ? new Date(m.data_fim).toLocaleString('pt-BR', { dateStyle: 'medium', timeStyle: 'short' }) : '-'}
                     </td>
                     <td className="py-4 px-4">
                        <span className="inline-block px-2.5 py-1 text-xs border border-green-500 text-green-600 rounded">
                           {m.status}
                        </span>
                     </td>
                  </tr>
                ))}
             </tbody>
          </table>
          {filteredList.length === 0 && (
             <div className="py-12 text-center text-gray-400 text-sm">
                Nenhuma manutenção encontrada.
             </div>
          )}
        </div>

      </div>

      {/* Insert/Edit Modal */}
      {(isInserting || editingId) && (
        <InsertModal 
          onClose={() => { setIsInserting(false); setEditingId(null) }} 
          condoId={condoId} 
          manutencaoToEdit={editingId ? manutencoes.find(m => m.id === editingId) : undefined}
          fornecedores={fornecedores}
        />
      )}

      {/* View Modal with Tabs */}
      {viewingId && (
        <ViewModal 
          manutencao={manutencoes.find(m => m.id === viewingId)!}
          fornecedores={fornecedores}
          onClose={() => setViewingId(null)} 
        />
      )}
    </div>
  )
}

function InsertModal({ onClose, condoId, manutencaoToEdit, fornecedores }: { onClose: () => void, condoId: string, manutencaoToEdit?: ManutencaoRow, fornecedores: FornecedorRow[] }) {
  const router = useRouter()
  const supabase = createClient()
  
  const formatForInput = (dateString?: string | null) => {
    if (!dateString) return ''
    const d = new Date(dateString)
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset())
    return d.toISOString().slice(0, 16)
  }

  const [titulo, setTitulo] = useState(manutencaoToEdit?.titulo || '')
  const [descricao, setDescricao] = useState(manutencaoToEdit?.descricao || '')
  const [tipo, setTipo] = useState(manutencaoToEdit?.tipo || '')
  const [status, setStatus] = useState(manutencaoToEdit?.status || '')
  const [inicio, setInicio] = useState<string>(formatForInput(manutencaoToEdit?.data_inicio))
  const [fim, setFim] = useState<string>(formatForInput(manutencaoToEdit?.data_fim))
  const [visivel, setVisivel] = useState(manutencaoToEdit ? manutencaoToEdit.visivel_moradores : false)
  const [valor, setValor] = useState(manutencaoToEdit?.valor?.toString() || '')
  const [recorrencia, setRecorrencia] = useState(manutencaoToEdit?.recorrencia || 'Nenhuma')
  const [fornecedorId, setFornecedorId] = useState(manutencaoToEdit?.fornecedor_id || '')

  const isEditing = !!manutencaoToEdit

  const handleSave = async () => {
    if(!titulo || !tipo || !status) return alert("Preencha título, tipo e status.")
    
    const payload = {
      condominio_id: condoId,
      titulo, descricao, tipo, status, 
      data_inicio: inicio || null, 
      data_fim: fim || null,
      visivel_moradores: visivel,
      valor: valor ? parseFloat(valor) : null,
      recorrencia,
      fornecedor_id: fornecedorId || null
    }

    if (isEditing) {
      await supabase.from('manutencoes').update(payload).eq('id', manutencaoToEdit.id)
    } else {
      await supabase.from('manutencoes').insert(payload)
      
      if (visivel) {
        // Disparar notificação automática
        supabase.functions.invoke('universal-push-notify', {
          body: {
            titulo: '🛠 Nova Manutenção Agendada',
            corpo: `A manutenção "${titulo}" foi agendada. Acesse o app para mais detalhes.`,
            condominio_id: condoId
          }
        }).catch(err => console.error('Erro ao enviar push:', err))
      }
    }

    router.refresh()
    onClose()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
      <div className="bg-white w-full max-w-2xl rounded-2xl shadow-xl flex flex-col max-h-[90vh]">
        
        {/* Header */}
        <div className="p-6 pb-4 border-b shrink-0 relative flex items-center justify-center">
          <h2 className="text-center font-bold text-gray-800 text-xl">
            {manutencaoToEdit ? 'Editar manutenção' : 'Inserir manutenção'}
          </h2>
          <button onClick={onClose} className="absolute right-4 text-red-500 font-bold hover:bg-red-50 p-1 px-3 rounded text-lg">X</button>
        </div>
        
        {/* Body */}
        <div className="p-6 overflow-y-auto flex-1 custom-scrollbar space-y-4">
            <div className="flex flex-col md:flex-row gap-4 items-start md:items-center">
              <span className="font-semibold text-gray-700 w-44">Fornecedor:</span>
              <div className="flex-1 flex gap-2 w-full">
                <select 
                  title="Fornecedor" 
                  value={fornecedorId}
                  onChange={e => setFornecedorId(e.target.value)}
                  className="w-full bg-gray-50 border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-700 outline-none focus:ring-1 focus:ring-[#fc5931]"
                >
                  <option value="">Nenhum fornecedor selecionado</option>
                  {fornecedores.map(f => (
                    <option key={f.id} value={f.id}>
                      {f.nome} {f.documento ? `(${f.documento})` : ''}
                    </option>
                  ))}
                </select>
                <button
                  type="button"
                  title="Cadastrar Fornecedor"
                  onClick={() => {
                    onClose();
                    router.push('/admin/fornecedores?action=new');
                  }}
                  className="bg-[#fc5931] text-white p-2 rounded-lg hover:bg-orange-600 transition flex items-center justify-center font-bold"
                >
                  <Plus size={20} />
                </button>
              </div>
            </div>

            <div className="flex flex-col md:flex-row gap-4 items-start md:items-center">
              <span className="font-semibold text-gray-700 w-44">Título:</span>
              <input value={titulo} onChange={e=>setTitulo(e.target.value)} type="text" placeholder="Titulo" className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm w-full outline-none focus:ring-1 focus:ring-[#fc5931]"/>
            </div>

            <div className="flex flex-col md:flex-row gap-4 items-start">
              <span className="font-semibold text-gray-700 w-44 pt-2">Descrição:</span>
              <textarea value={descricao} onChange={e=>setDescricao(e.target.value)} placeholder="Escreva aqui uma descrição" className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm min-h-[100px] w-full outline-none focus:ring-1 focus:ring-[#fc5931]"></textarea>
            </div>

            <div className="flex flex-col md:flex-row gap-4 items-start md:items-center">
              <span className="font-semibold text-gray-700 w-44">Tipo:</span>
              <div className="flex-1 flex gap-4 w-full">
                <select title="Tipo" value={tipo} onChange={e=>setTipo(e.target.value)} className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none">
                  <option value="">Selecione</option>
                  <option value="Preventiva">Preventiva</option>
                  <option value="Corretiva">Corretiva</option>
                  <option value="Urgente">Urgente</option>
                  <option value="Outros">Outros</option>
                </select>
                <span className="font-semibold text-gray-700 self-center">Status:</span>
                <select title="Status" value={status} onChange={e=>setStatus(e.target.value)} className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none">
                  <option value="">Selecione</option>
                  <option value="Agendada">Agendada</option>
                  <option value="Em Andamento">Em Andamento</option>
                  <option value="Concluída">Concluída</option>
                </select>
              </div>
            </div>

            <div className="flex flex-col md:flex-row gap-4 items-start md:items-center">
              <span className="font-semibold text-gray-700 w-44">Início:</span>
              <div className="flex-1 flex gap-4 w-full">
                <input title="Data de Início" aria-label="Data de Início" type="datetime-local" value={inicio} onChange={e=>setInicio(e.target.value)} className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none"/>
                <span className="font-semibold text-gray-700 self-center">Fim:</span>
                <input title="Data de Fim" aria-label="Data de Fim" type="datetime-local" value={fim} onChange={e=>setFim(e.target.value)} className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none"/>
              </div>
            </div>

            <div className="flex flex-col md:flex-row gap-4 items-start md:items-center">
              <span className="font-semibold text-gray-700 w-44">Visível ao moradores?:</span>
              <div className="flex gap-4 items-center">
                 <label className="flex items-center gap-2 cursor-pointer font-medium text-sm">
                   <input type="radio" checked={!visivel} onChange={() => setVisivel(false)} className="accent-[#FC5931] w-4 h-4"/> Não
                 </label>
                 <label className="flex items-center gap-2 cursor-pointer font-medium text-sm">
                   <input type="radio" checked={visivel} onChange={() => setVisivel(true)} className="accent-[#FC5931] w-4 h-4"/> Sim
                 </label>
              </div>
            </div>

            <div className="flex flex-col md:flex-row gap-4 items-start md:items-center">
              <span className="font-semibold text-gray-700 w-44">Valor:</span>
              <input value={valor} onChange={e=>setValor(e.target.value)} type="number" placeholder="Valor" className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm w-full outline-none focus:ring-1 focus:ring-[#fc5931]"/>
            </div>

            <div className="flex flex-col md:flex-row gap-4 items-start md:items-center">
              <span className="font-semibold text-gray-700 w-44">Recorrência:</span>
              <select title="Recorrência" value={recorrencia} onChange={e=>setRecorrencia(e.target.value)} className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none w-full shadow-sm">
                <option value="Nenhuma">Nenhuma</option>
                <option value="Semanalmente">Semanalmente</option>
                <option value="Mensalmente">Mensalmente</option>
                <option value="Trimestralmente">Trimestralmente</option>
                <option value="Semestralmente">Semestralmente</option>
                <option value="Anualmente">Anualmente</option>
              </select>
            </div>
            
        </div>
        
        {/* Footer */}
        <div className="p-6 border-t shrink-0 flex justify-center gap-4 bg-white rounded-b-2xl">
          <button onClick={handleSave} className="bg-[#fc5931] text-white px-10 py-2.5 rounded-full font-bold shadow hover:bg-orange-600 transition-all">Salvar</button>
          <button onClick={onClose} className="bg-white border-2 border-gray-200 text-gray-600 px-10 py-2.5 rounded-full font-bold shadow-sm hover:bg-gray-50 transition-all">Voltar</button>
        </div>
        
      </div>
    </div>
  )
}

type Foto = {
  id: string
  url: string
  created_at: string
}

type Comentario = {
  id: string
  texto: string
  created_at: string
  perfil: {
    nome: string
    papel_sistema: string
  } | null
}

function ViewModal({ manutencao, fornecedores, onClose }: { manutencao: ManutencaoRow, fornecedores?: FornecedorRow[], onClose: () => void }) {
  const [tab, setTab] = useState<'geral'|'fotos'|'comentarios'>('geral')
  const supabase = createClient()
  
  // Fotos State
  const [fotos, setFotos] = useState<Foto[]>([])
  const [loadingFotos, setLoadingFotos] = useState(false)
  const [uploading, setUploading] = useState(false)

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
       // @ts-expect-error type assertion
      setComentarios(data as Comentario[])
    }
    setLoadingComments(false)
  }, [manutencao.id, supabase])

  // Fetch logic
  useEffect(() => {
    if (tab === 'fotos') fetchFotos()
    if (tab === 'comentarios') fetchComentarios()
  }, [tab, fetchFotos, fetchComentarios])

  async function handlePhotoUpload(e: React.ChangeEvent<HTMLInputElement>) {
    if (!e.target.files || e.target.files.length === 0) return
    const file = e.target.files[0]
    
    setUploading(true)
    const fileExt = file.name.split('.').pop()
    const fileName = `${manutencao.id}-${Date.now()}.${fileExt}`
    
    const { error: uploadError } = await supabase.storage
      .from('manutencoes')
      .upload(`fotos/${fileName}`, file, { upsert: false })
      
    if (uploadError) {
      alert('Erro ao fazer upload da foto')
      setUploading(false)
      return
    }

    const { data: publicUrlData } = supabase.storage
      .from('manutencoes')
      .getPublicUrl(`fotos/${fileName}`)
      
    const { error: insertError } = await supabase
      .from('manutencao_fotos')
      .insert({
        manutencao_id: manutencao.id,
        url: publicUrlData.publicUrl,
      })

    if (!insertError) {
      fetchFotos()
    }
    setUploading(false)
  }

  async function handlePhotoDelete(fotoId: string) {
    if (!confirm('Deseja excluir esta foto?')) return
    await supabase.from('manutencao_fotos').delete().eq('id', fotoId)
    fetchFotos()
  }

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
      <div className="bg-white w-full max-w-2xl rounded-2xl shadow-xl overflow-hidden flex flex-col min-h-[60vh] max-h-[90vh]">
        
        <div className="p-4 border-b relative">
           <div className="text-center font-bold text-gray-800 text-xl">Ver manutenção</div>
           <button onClick={onClose} className="absolute right-4 top-4 text-red-500 font-bold hover:bg-red-50 p-1 px-3 rounded text-lg">X</button>
        </div>

        <div className="flex border-b">
           <button onClick={() => setTab('geral')} className={`flex-1 py-3 text-sm font-bold transition-all ${tab === 'geral' ? 'text-[#fc5931] border-b-2 border-[#fc5931]' : 'text-gray-500'}`}>Geral</button>
           <button onClick={() => setTab('fotos')} className={`flex-1 py-3 text-sm font-bold transition-all ${tab === 'fotos' ? 'text-[#fc5931] border-b-2 border-[#fc5931]' : 'text-gray-500'}`}>Fotos</button>
           <button onClick={() => setTab('comentarios')} className={`flex-1 py-3 text-sm font-bold transition-all ${tab === 'comentarios' ? 'text-[#fc5931] border-b-2 border-[#fc5931]' : 'text-gray-500'}`}>Comentários</button>
        </div>

        <div className="p-6 flex-1 overflow-y-auto custom-scrollbar">
           {tab === 'geral' && (
              <div className="space-y-4">
                 <div className="flex gap-4 items-baseline">
                   <strong className="text-gray-700 w-32">Título:</strong>
                   <span className="text-gray-600 font-medium">{manutencao.titulo}</span>
                 </div>
                 <div className="flex gap-4 items-baseline">
                   <strong className="text-gray-700 w-32">Descrição:</strong>
                   <span className="text-gray-600">{manutencao.descricao || '-'}</span>
                 </div>
                 <div className="flex gap-4 items-baseline">
                   <strong className="text-gray-700 w-32">Tipo:</strong>
                   <span className="text-gray-600">{manutencao.tipo}</span>
                 </div>
                 <div className="flex gap-4 items-baseline">
                   <strong className="text-gray-700 w-32">Status:</strong>
                   <span className="inline-block px-2.5 py-1 text-xs border border-gray-300 text-gray-600 rounded">
                     {manutencao.status}
                   </span>
                 </div>
                 <div className="flex gap-4 items-baseline">
                   <strong className="text-gray-700 w-32">Data de Início:</strong>
                   <span className="text-gray-600">{manutencao.data_inicio ? new Date(manutencao.data_inicio).toLocaleString('pt-BR') : '-'}</span>
                 </div>
                 <div className="flex gap-4 items-baseline">
                   <strong className="text-gray-700 w-32">Data do Fim:</strong>
                   <span className="text-gray-600">{manutencao.data_fim ? new Date(manutencao.data_fim).toLocaleString('pt-BR') : '-'}</span>
                 </div>
                 <div className="flex gap-4 items-baseline">
                   <strong className="text-gray-700 w-32">Fornecedor:</strong>
                   <span className="text-gray-600">
                     {manutencao.fornecedor_id 
                       ? (fornecedores?.find(f => f.id === manutencao.fornecedor_id)?.nome || 'Fornecedor não encontrado')
                       : 'Nenhum'
                     }
                   </span>
                 </div>
                 <div className="flex gap-4 items-baseline">
                   <strong className="text-gray-700 w-32">Visível?:</strong>
                   <span className="text-gray-600">{manutencao.visivel_moradores ? 'Sim' : 'Não'}</span>
                 </div>
                 <div className="flex gap-4 items-baseline">
                   <strong className="text-gray-700 w-32">Valor:</strong>
                   <span className="text-gray-600">{manutencao.valor ? `R$ ${manutencao.valor.toFixed(2)}` : '-'}</span>
                 </div>
                 <div className="flex gap-4 items-baseline">
                   <strong className="text-gray-700 w-32">Recorrência:</strong>
                   <span className="text-gray-600">{manutencao.recorrencia}</span>
                 </div>
              </div>
           )}
           {tab === 'fotos' && (
              <div className="flex flex-col">
                 <div className="flex justify-between items-center mb-6">
                    <h3 className="text-xl font-bold text-gray-800">Fotos anexadas</h3>
                    <div className="relative">
                       <input 
                         title="Anexar foto"
                         type="file" 
                         accept="image/*" 
                         onChange={handlePhotoUpload} 
                         className="absolute inset-0 opacity-0 cursor-pointer"
                       />
                       <button className="bg-[#fc5931] text-white px-6 py-2 rounded-xl font-bold flex items-center gap-2 hover:bg-[#fc5931]/90">
                          {uploading ? <div className="w-5 h-5 border-2 border-t-white border-white/30 rounded-full animate-spin" /> : <UploadCloud size={20} />}
                          {uploading ? 'Enviando...' : '+ Anexar Foto'}
                       </button>
                    </div>
                 </div>

                 {loadingFotos ? (
                    <div className="flex justify-center p-8"><div className="w-8 h-8 rounded-full border-4 border-[#fc5931] border-t-transparent animate-spin"></div></div>
                 ) : fotos.length === 0 ? (
                    <div className="border border-dashed border-gray-300 w-full bg-gray-50 rounded-xl min-h-[200px] flex items-center justify-center text-gray-400">
                       Nenhuma foto adicionada
                    </div>
                 ) : (
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                       {fotos.map(f => (
                          <div key={f.id} className="relative group rounded-xl overflow-hidden shadow">
                             <img src={f.url} alt="Manutenção" className="w-full h-32 object-cover" />
                             <button aria-label="Deletar foto" title="Deletar foto" onClick={() => handlePhotoDelete(f.id)} className="absolute top-2 right-2 bg-red-500 text-white p-1.5 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity">
                                <Trash2 size={16} />
                             </button>
                          </div>
                       ))}
                    </div>
                 )}
              </div>
           )}
           {tab === 'comentarios' && (
              <div className="flex flex-col h-full">
                 <div className="flex-1 space-y-4 mb-4 lg:mb-6 custom-scrollbar pr-2 min-h-[250px]">
                    {loadingComments ? (
                       <div className="flex justify-center p-8"><div className="w-8 h-8 rounded-full border-4 border-[#fc5931] border-t-transparent animate-spin"></div></div>
                    ) : comentarios.length === 0 ? (
                       <div className="flex flex-col items-center justify-center h-full text-gray-400 gap-2">
                          <MessageSquare size={32} className="opacity-50" />
                          <span>Nenhum comentário na manutenção</span>
                       </div>
                    ) : (
                       comentarios.map(c => (
                          <div key={c.id} className="bg-gray-50 p-4 rounded-xl">
                             <div className="flex justify-between items-baseline mb-2">
                                <strong className="text-gray-800">{c.perfil?.nome || 'Usuário Desconhecido'} <span className="text-xs font-normal text-gray-500 ml-2 bg-gray-200 px-2 py-0.5 rounded-full">{c.perfil?.papel_sistema || ''}</span></strong>
                                <span className="text-xs text-gray-400">{new Date(c.created_at).toLocaleString('pt-BR')}</span>
                             </div>
                             <p className="text-gray-600 text-sm whitespace-pre-wrap">{c.texto}</p>
                          </div>
                       ))
                    )}
                 </div>
                 
                 <div className="flex gap-2 relative">
                    <textarea 
                       title="Adicionar comentário"
                       value={newComment}
                       onChange={e => setNewComment(e.target.value)}
                       placeholder="Escreva um comentário..."
                       className="flex-1 border border-gray-200 rounded-xl px-4 py-3 text-sm outline-none resize-none h-14"
                    />
                    <button 
                       title="Enviar Comentário"
                       disabled={submittingComment || !newComment.trim()}
                       onClick={handleAddComment}
                       className="bg-[#fc5931] text-white px-6 rounded-xl font-bold hover:bg-[#fc5931]/90 transition-colors disabled:opacity-50"
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
