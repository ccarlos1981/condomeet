'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Plus, Pencil, Trash2, X, FileText, Loader2, Search } from 'lucide-react'

export type Regra = {
  id: string
  condominio_id: string
  categoria: string
  titulo: string
  conteudo: string
  created_at: string
}

const CATEGORIAS_REGRAS = [
  'Silêncio',
  'Mudanças',
  'Animais de Estimação',
  'Lixo e Reciclagem',
  'Áreas Comuns & Piscina',
  'Estacionamento & Vagas',
  'Obras & Reformas',
  'Segurança & Portaria',
  'Outros'
]

export default function RegrasClient({
  initialRegras,
  condoId
}: {
  initialRegras: Regra[]
  condoId: string
}) {
  const [regras, setRegras] = useState<Regra[]>(initialRegras)
  const [search, setSearch] = useState('')
  const [showModal, setShowModal] = useState(false)
  const [editRegra, setEditRegra] = useState<Regra | null>(null)
  
  // Form fields
  const [categoria, setCategoria] = useState('')
  const [titulo, setTitulo] = useState('')
  const [conteudo, setConteudo] = useState('')
  const [saving, setSaving] = useState(false)
  const [deletingId, setDeletingId] = useState<string | null>(null)
  const [error, setError] = useState('')

  const supabase = createClient()

  function openCreate() {
    setEditRegra(null)
    setCategoria(CATEGORIAS_REGRAS[0])
    setTitulo('')
    setConteudo('')
    setError('')
    setShowModal(true)
  }

  function openEdit(regra: Regra) {
    setEditRegra(regra)
    setCategoria(regra.categoria)
    setTitulo(regra.titulo)
    setConteudo(regra.conteudo)
    setError('')
    setShowModal(true)
  }

  async function handleSave() {
    if (!categoria.trim() || !titulo.trim() || !conteudo.trim()) {
      setError('Preencha todos os campos obrigatórios.')
      return
    }
    setSaving(true)
    setError('')

    try {
      const payload = {
        condominio_id: condoId,
        categoria: categoria.trim(),
        titulo: titulo.trim(),
        conteudo: conteudo.trim()
      }

      if (editRegra) {
        const { data, error: err } = await supabase
          .from('condominio_regras')
          .update(payload)
          .eq('id', editRegra.id)
          .select()
          .single()

        if (err) throw err
        setRegras(prev => prev.map(r => r.id === editRegra.id ? (data as Regra) : r))
      } else {
        const { data, error: err } = await supabase
          .from('condominio_regras')
          .insert(payload)
          .select()
          .single()

        if (err) throw err
        setRegras(prev => [data as Regra, ...prev])
      }
      setShowModal(false)
    } catch (err: any) {
      console.error(err)
      setError(err.message || 'Erro ao salvar regra.')
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete(id: string) {
    if (!confirm('Tem certeza que deseja excluir esta regra? O chatbot de IA não poderá mais usá-la como referência.')) return
    setDeletingId(id)
    try {
      const { error: err } = await supabase.from('condominio_regras').delete().eq('id', id)
      if (err) throw err
      setRegras(prev => prev.filter(r => r.id !== id))
    } catch (err) {
      console.error(err)
      alert('Erro ao excluir regra.')
    } finally {
      setDeletingId(null)
    }
  }

  const filteredRegras = regras.filter(r => {
    const query = search.toLowerCase()
    return (
      r.titulo.toLowerCase().includes(query) ||
      r.conteudo.toLowerCase().includes(query) ||
      r.categoria.toLowerCase().includes(query)
    )
  })

  // Group by category
  const categoriesPresent = Array.from(new Set(filteredRegras.map(r => r.categoria))).sort()

  return (
    <div className="space-y-6">
      {/* Action Bar */}
      <div className="flex items-center gap-3 flex-wrap">
        <button
          onClick={openCreate}
          className="flex items-center gap-2 bg-[#FC5931] hover:bg-[#D42F1D] text-white px-4 py-2.5 rounded-xl text-sm font-semibold shadow-sm transition"
        >
          <Plus size={16} />
          Adicionar Regra
        </button>
        
        <div className="relative ml-auto w-72">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Buscar nas regras do regimento..."
            className="w-full pl-8 pr-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
          />
        </div>
      </div>

      {/* Rules list grouped by Category */}
      {filteredRegras.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-2xl border border-gray-100 shadow-sm text-gray-400">
          <FileText size={40} className="mx-auto mb-3 opacity-30" />
          <p className="font-medium text-gray-500">Nenhuma regra cadastrada</p>
          <p className="text-sm">Cadastre as principais normas do regimento interno para que o Chatbot do WhatsApp possa responder aos moradores.</p>
        </div>
      ) : (
        <div className="space-y-6">
          {categoriesPresent.map(cat => {
            const rulesInCat = filteredRegras.filter(r => r.categoria === cat)
            return (
              <div key={cat} className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
                <div className="bg-gray-50/50 px-5 py-3 border-b border-gray-100">
                  <h3 className="font-bold text-gray-700 text-sm uppercase tracking-wider">{cat}</h3>
                </div>
                <div className="divide-y divide-gray-100">
                  {rulesInCat.map(reg => (
                    <div key={reg.id} className="p-5 flex gap-4 hover:bg-gray-50/30 transition">
                      <div className="flex-1 space-y-1">
                        <h4 className="font-semibold text-gray-900 text-base">{reg.titulo}</h4>
                        <p className="text-gray-600 text-sm whitespace-pre-line leading-relaxed">{reg.conteudo}</p>
                      </div>
                      <div className="flex items-start gap-1 text-gray-400">
                        <button
                          onClick={() => openEdit(reg)}
                          className="p-2 rounded-xl hover:bg-orange-50 hover:text-[#FC5931] transition"
                          title="Editar"
                        >
                          <Pencil size={14} />
                        </button>
                        <button
                          onClick={() => handleDelete(reg.id)}
                          disabled={deletingId === reg.id}
                          className="p-2 rounded-xl hover:bg-red-50 hover:text-red-500 transition"
                          title="Excluir"
                        >
                          {deletingId === reg.id ? <Loader2 size={14} className="animate-spin" /> : <Trash2 size={14} />}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Create/Edit Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-xl p-6">
            <div className="flex items-center justify-between mb-5">
              <div className="flex items-center gap-2">
                <FileText size={18} className="text-[#FC5931]" />
                <h2 className="text-lg font-bold text-gray-900">
                  {editRegra ? 'Editar Regra' : 'Adicionar Nova Regra'}
                </h2>
              </div>
              <button onClick={() => setShowModal(false)} className="p-1 rounded-lg hover:bg-gray-100 text-gray-400">
                <X size={18} />
              </button>
            </div>
            
            <div className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Categoria</label>
                <select
                  value={categoria}
                  onChange={e => setCategoria(e.target.value)}
                  className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
                >
                  {CATEGORIAS_REGRAS.map(cat => (
                    <option key={cat} value={cat}>{cat}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Título / Tópico</label>
                <input
                  value={titulo}
                  onChange={e => setTitulo(e.target.value)}
                  placeholder="Ex: Mudança aos sábados, Horário da piscina"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Descrição da Regra / Normativa</label>
                <textarea
                  value={conteudo}
                  onChange={e => setConteudo(e.target.value)}
                  placeholder="Escreva detalhadamente a regra. O chatbot usará este texto exato como referência para tirar dúvidas dos moradores no WhatsApp."
                  rows={6}
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] leading-relaxed"
                />
              </div>

              {error && <p className="text-red-500 text-sm bg-red-50 px-4 py-2 rounded-xl">{error}</p>}
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleSave}
                disabled={saving || !titulo.trim() || !conteudo.trim()}
                className="flex-1 bg-[#FC5931] text-white rounded-xl py-2.5 text-sm font-semibold hover:bg-[#D42F1D] transition disabled:opacity-40 flex items-center justify-center gap-2"
              >
                {saving && <Loader2 size={16} className="animate-spin" />}
                {saving ? 'Salvando...' : 'Salvar Regra'}
              </button>
              <button
                onClick={() => setShowModal(false)}
                className="flex-1 border border-[#FC5931] text-[#FC5931] rounded-xl py-2.5 text-sm font-semibold hover:bg-orange-50 transition"
              >
                Cancelar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
