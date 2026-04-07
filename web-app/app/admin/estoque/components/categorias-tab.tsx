'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import type { Categoria } from '../estoque-client'
import { Tag, Plus, Edit2, Trash2, X, Save } from 'lucide-react'

export default function CategoriasTab({
  categorias,
  setCategorias,
  condominioId,
}: {
  categorias: Categoria[]
  setCategorias: React.Dispatch<React.SetStateAction<Categoria[]>>
  condominioId: string
}) {
  const supabase = createClient()
  const router = useRouter()
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState({ nome: '', observacoes: '' })
  const [isSaving, setIsSaving] = useState(false)
  const [error, setError] = useState('')

  const openNew = () => {
    setEditingId(null)
    setForm({ nome: '', observacoes: '' })
    setError('')
    setIsModalOpen(true)
  }

  const openEdit = (c: Categoria) => {
    setEditingId(c.id)
    setForm({ nome: c.nome, observacoes: c.observacoes || '' })
    setError('')
    setIsModalOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Deseja realmente excluir esta categoria?')) return
    const { error } = await supabase.from('estoque_categorias').delete().eq('id', id)
    if (error) {
      alert('Erro ao excluir: ' + error.message)
    } else {
      setCategorias(prev => prev.filter(c => c.id !== id))
      router.refresh()
    }
  }

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.nome.trim()) { setError('Nome é obrigatório'); return }
    setIsSaving(true)
    setError('')

    try {
      if (editingId) {
        const { error } = await supabase
          .from('estoque_categorias')
          .update({ nome: form.nome.trim(), observacoes: form.observacoes.trim() || null, updated_at: new Date().toISOString() })
          .eq('id', editingId)
        if (error) throw error
        setCategorias(prev => prev.map(c => c.id === editingId ? { ...c, nome: form.nome.trim(), observacoes: form.observacoes.trim() || null } : c))
      } else {
        const nextCode = String((categorias.length > 0 ? Math.max(...categorias.map(c => parseInt(c.codigo) || 0)) : 0) + 1)
        const { data, error } = await supabase
          .from('estoque_categorias')
          .insert({
            condominio_id: condominioId,
            codigo: nextCode,
            nome: form.nome.trim(),
            observacoes: form.observacoes.trim() || null,
          })
          .select()
          .single()
        if (error) throw error
        if (data) setCategorias(prev => [...prev, data].sort((a, b) => a.nome.localeCompare(b.nome)))
      }
      setIsModalOpen(false)
      router.refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao salvar.')
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <div>
      {/* Header */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-6">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-xl font-bold text-gray-800 flex items-center gap-2">
              <Tag size={22} className="text-[#FC5931]" />
              Categorias de Estoque
            </h2>
            <p className="text-gray-500 text-sm mt-1">Organize os produtos por categorias para facilitar a gestão.</p>
          </div>
          <button
            onClick={openNew}
            className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-4 py-2.5 rounded-xl font-medium shadow-sm flex items-center gap-2 transition-colors"
          >
            <Plus size={18} />
            Nova Categoria
          </button>
        </div>
      </div>

      {/* List */}
      {categorias.length === 0 ? (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-12 flex flex-col items-center justify-center text-center">
          <div className="w-16 h-16 bg-[#FC5931]/10 rounded-full flex items-center justify-center mb-4">
            <Tag size={32} className="text-[#FC5931]" />
          </div>
          <h3 className="text-lg font-semibold text-gray-800 mb-2">Nenhuma categoria cadastrada</h3>
          <p className="text-gray-500 max-w-sm mb-6 text-sm">Ex: Material de Limpeza, Ferramentas, Elétrica, Jardinagem</p>
          <button onClick={openNew} className="text-[#FC5931] border border-[#FC5931] hover:bg-[#FC5931] hover:text-white px-6 py-2.5 rounded-xl font-medium transition-colors">
            Cadastrar Primeira
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {categorias.filter(c => c.ativo).map(c => (
            <div key={c.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 hover:shadow-md transition-shadow">
              <div className="flex justify-between items-start mb-2">
                <div className="flex items-center gap-3">
                  <div className="bg-amber-50 p-2 rounded-lg">
                    <Tag size={18} className="text-amber-500" />
                  </div>
                  <div>
                    <h3 className="font-bold text-gray-800">{c.nome}</h3>
                    <p className="text-xs text-gray-400">Código: {c.codigo}</p>
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  <button onClick={() => openEdit(c)} className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors" title="Editar">
                    <Edit2 size={16} />
                  </button>
                  <button onClick={() => handleDelete(c.id)} className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors" title="Excluir">
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
              {c.observacoes && <p className="text-sm text-gray-500 mt-2">{c.observacoes}</p>}
            </div>
          ))}
        </div>
      )}

      {/* Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
          <div className="bg-[#f5f5f5] w-full max-w-lg rounded-2xl shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between shadow-sm">
              <h2 className="text-xl font-bold text-gray-800">
                {editingId ? 'Editar Categoria' : 'Cadastrar Categoria'}
              </h2>
              <button onClick={() => setIsModalOpen(false)} className="text-gray-400 hover:text-gray-600 bg-gray-50 hover:bg-gray-100 p-1.5 rounded-full transition-colors" title="Fechar">
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleSave} className="p-6 space-y-4">
              <div className="grid grid-cols-[140px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Nome:</label>
                <input
                  type="text"
                  required
                  value={form.nome}
                  onChange={e => setForm({ ...form, nome: e.target.value })}
                  placeholder="Ex: Material de Limpeza..."
                  className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                />
              </div>
              <div className="grid grid-cols-[140px_1fr] items-start gap-4">
                <label className="text-gray-600 font-medium mt-2">Observação:</label>
                <textarea
                  value={form.observacoes}
                  onChange={e => setForm({ ...form, observacoes: e.target.value })}
                  placeholder="Escreva aqui uma descrição"
                  rows={3}
                  className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all resize-none"
                />
              </div>
              {error && <div className="p-3 bg-red-50 text-red-600 border border-red-100 rounded-xl text-sm">{error}</div>}
              <div className="flex items-center justify-center gap-4 mt-6">
                <button type="submit" disabled={isSaving} className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-8 py-2.5 rounded-2xl font-medium shadow-sm transition-colors flex items-center gap-2 disabled:opacity-50">
                  <Save size={16} />
                  {isSaving ? 'Salvando...' : editingId ? 'Salvar' : 'Adicionar'}
                </button>
                <button type="button" onClick={() => setIsModalOpen(false)} className="bg-white border border-gray-300 text-gray-700 hover:bg-gray-50 px-8 py-2.5 rounded-2xl font-medium shadow-sm transition-colors">
                  Voltar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
