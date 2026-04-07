'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import type { Produto, Local, Categoria, Fornecedor } from '../estoque-client'
import { ShoppingCart, Plus, X, Save, PlusCircle } from 'lucide-react'

const UNIDADES = [
  'unidade', 'litro', 'kg', 'metro', 'caixa', 'rolo', 'pacote', 'par', 'galão', 'saco', 'frasco', 'lata', 'balde', 'pote',
]

export default function ProdutosTab({
  produtos,
  setProdutos,
  locais,
  setLocais,
  categorias,
  setCategorias,
  fornecedores,
  condominioId,
}: {
  produtos: Produto[]
  setProdutos: React.Dispatch<React.SetStateAction<Produto[]>>
  locais: Local[]
  setLocais: React.Dispatch<React.SetStateAction<Local[]>>
  categorias: Categoria[]
  setCategorias: React.Dispatch<React.SetStateAction<Categoria[]>>
  fornecedores: Fornecedor[]
  condominioId: string
}) {
  const supabase = createClient()
  const router = useRouter()
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [isSaving, setIsSaving] = useState(false)
  const [error, setError] = useState('')

  // Quick-add modals
  const [showQuickLocal, setShowQuickLocal] = useState(false)
  const [quickLocalNome, setQuickLocalNome] = useState('')
  const [showQuickCategoria, setShowQuickCategoria] = useState(false)
  const [quickCategoriaNome, setQuickCategoriaNome] = useState('')

  const emptyForm = {
    local_id: '',
    categoria_id: '',
    fornecedor_id: '',
    nome: '',
    descricao: '',
    unidade: 'unidade',
    tipo_controle: 'consumivel' as 'consumivel' | 'retornavel' | 'misto',
    marca: '',
    quantidade_atual: '0',
    quantidade_minima: '0',
    quantidade_maxima: '0',
    custo_unitario: '0',
    data_validade: '',
  }
  const [form, setForm] = useState(emptyForm)

  const openNew = () => {
    setForm(emptyForm)
    setError('')
    setIsModalOpen(true)
  }

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.nome.trim()) { setError('Nome do produto é obrigatório'); return }
    if (!form.local_id) { setError('Selecione um espaço físico'); return }
    if (!form.categoria_id) { setError('Selecione uma categoria'); return }
    setIsSaving(true)
    setError('')

    try {
      // Generate next code
      const maxCode = produtos.length > 0
        ? Math.max(...produtos.map(p => parseInt(p.codigo) || 0))
        : 100
      const nextCode = String(maxCode + 1)

      const { data, error: insertError } = await supabase
        .from('estoque_produtos')
        .insert({
          condominio_id: condominioId,
          local_id: form.local_id,
          categoria_id: form.categoria_id,
          fornecedor_id: form.fornecedor_id || null,
          codigo: nextCode,
          nome: form.nome.trim(),
          descricao: form.descricao.trim() || null,
          unidade: form.unidade,
          tipo_controle: form.tipo_controle,
          marca: form.marca.trim() || null,
          quantidade_minima: parseInt(form.quantidade_minima) || 0,
          quantidade_maxima: parseInt(form.quantidade_maxima) || 0,
          quantidade_atual: parseInt(form.quantidade_atual) || 0,
          custo_unitario: parseFloat(form.custo_unitario) || 0,
          data_validade: form.data_validade || null,
        })
        .select('*, estoque_locais(nome), estoque_categorias(nome), fornecedores(nome)')
        .single()

      if (insertError) throw insertError
      if (data) setProdutos(prev => [...prev, data].sort((a, b) => a.nome.localeCompare(b.nome)))
      setIsModalOpen(false)
      router.refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao salvar.')
    } finally {
      setIsSaving(false)
    }
  }

  const handleQuickAddLocal = async () => {
    if (!quickLocalNome.trim()) return
    const nextCode = String((locais.length > 0 ? Math.max(...locais.map(l => parseInt(l.codigo) || 0)) : 0) + 1)
    const { data, error } = await supabase
      .from('estoque_locais')
      .insert({ condominio_id: condominioId, codigo: nextCode, nome: quickLocalNome.trim() })
      .select()
      .single()
    if (!error && data) {
      setLocais(prev => [...prev, data].sort((a, b) => a.nome.localeCompare(b.nome)))
      setForm(f => ({ ...f, local_id: data.id }))
    }
    setQuickLocalNome('')
    setShowQuickLocal(false)
  }

  const handleQuickAddCategoria = async () => {
    if (!quickCategoriaNome.trim()) return
    const nextCode = String((categorias.length > 0 ? Math.max(...categorias.map(c => parseInt(c.codigo) || 0)) : 0) + 1)
    const { data, error } = await supabase
      .from('estoque_categorias')
      .insert({ condominio_id: condominioId, codigo: nextCode, nome: quickCategoriaNome.trim() })
      .select()
      .single()
    if (!error && data) {
      setCategorias(prev => [...prev, data].sort((a, b) => a.nome.localeCompare(b.nome)))
      setForm(f => ({ ...f, categoria_id: data.id }))
    }
    setQuickCategoriaNome('')
    setShowQuickCategoria(false)
  }

  return (
    <div>
      {/* Header */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-6">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-xl font-bold text-gray-800 flex items-center gap-2">
              <ShoppingCart size={22} className="text-[#FC5931]" />
              Cadastrar Produto
            </h2>
            <p className="text-gray-500 text-sm mt-1">Cadastre os produtos do estoque do condomínio.</p>
          </div>
          <button
            onClick={openNew}
            className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-4 py-2.5 rounded-xl font-medium shadow-sm flex items-center gap-2 transition-colors"
          >
            <Plus size={18} />
            Novo Produto
          </button>
        </div>
      </div>

      {/* Products Grid */}
      {produtos.filter(p => p.ativo).length === 0 ? (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-12 flex flex-col items-center justify-center text-center">
          <div className="w-16 h-16 bg-[#FC5931]/10 rounded-full flex items-center justify-center mb-4">
            <ShoppingCart size={32} className="text-[#FC5931]" />
          </div>
          <h3 className="text-lg font-semibold text-gray-800 mb-2">Nenhum produto cadastrado</h3>
          <p className="text-gray-500 max-w-sm mb-6 text-sm">Cadastre os produtos para controlar o estoque.</p>
          <button onClick={openNew} className="text-[#FC5931] border border-[#FC5931] hover:bg-[#FC5931] hover:text-white px-6 py-2.5 rounded-xl font-medium transition-colors">
            Cadastrar Primeiro
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {produtos.filter(p => p.ativo).map(p => {
            const isCritical = p.quantidade_atual > 0 && p.quantidade_atual <= p.quantidade_minima
            const isZero = p.quantidade_atual === 0
            return (
              <div key={p.id} className={`bg-white rounded-2xl shadow-sm border ${isCritical ? 'border-red-200 bg-red-50/30' : isZero ? 'border-gray-300 bg-gray-50/50' : 'border-gray-100'} p-5 hover:shadow-md transition-all`}>
                <div className="flex items-start gap-3 mb-3">
                  <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${isCritical ? 'bg-red-100' : isZero ? 'bg-gray-200' : 'bg-blue-50'}`}>
                    <ShoppingCart size={18} className={isCritical ? 'text-red-500' : isZero ? 'text-gray-500' : 'text-blue-500'} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <h3 className="font-bold text-gray-800 truncate">{p.nome}</h3>
                    <p className="text-xs text-gray-400">Cód: {p.codigo} · {p.marca || 'Sem marca'}</p>
                  </div>
                  <div className="text-right">
                    <p className={`text-2xl font-bold ${isCritical ? 'text-red-600' : isZero ? 'text-gray-400' : 'text-gray-800'}`}>{p.quantidade_atual}</p>
                    <p className="text-xs text-gray-400">{p.unidade}</p>
                  </div>
                </div>
                <div className="flex flex-wrap gap-1.5 text-xs">
                  {p.estoque_locais?.nome && (
                    <span className="bg-blue-50 text-blue-600 px-2 py-0.5 rounded-full">📍 {p.estoque_locais.nome}</span>
                  )}
                  {p.estoque_categorias?.nome && (
                    <span className="bg-amber-50 text-amber-600 px-2 py-0.5 rounded-full">🏷️ {p.estoque_categorias.nome}</span>
                  )}
                  <span className={`px-2 py-0.5 rounded-full ${
                    p.tipo_controle === 'consumivel' ? 'bg-orange-50 text-orange-600' :
                    p.tipo_controle === 'retornavel' ? 'bg-purple-50 text-purple-600' :
                    'bg-teal-50 text-teal-600'
                  }`}>
                    {p.tipo_controle === 'consumivel' ? '🧴 Consumível' : p.tipo_controle === 'retornavel' ? '🔄 Retornável' : '🔀 Misto'}
                  </span>
                </div>
                {isCritical && (
                  <div className="mt-3 flex items-center gap-1.5 text-xs text-red-600 bg-red-50 px-3 py-1.5 rounded-lg animate-pulse">
                    ⚠️ Estoque crítico (mín: {p.quantidade_minima})
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}

      {/* Modal — Cadastrar Produto */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
          <div className="bg-[#f5f5f5] w-full max-w-2xl rounded-2xl shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200 max-h-[90vh] flex flex-col">
            <div className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between shadow-sm shrink-0">
              <h2 className="text-xl font-bold text-gray-800">Cadastrar Produto</h2>
              <button onClick={() => setIsModalOpen(false)} className="text-gray-400 hover:text-gray-600 bg-gray-50 hover:bg-gray-100 p-1.5 rounded-full transition-colors" title="Fechar">
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleSave} className="p-6 space-y-4 overflow-y-auto flex-1">
              {/* Espaço Físico */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Espaço físico:</label>
                <div className="flex gap-2">
                  <select
                    value={form.local_id}
                    onChange={e => setForm({ ...form, local_id: e.target.value })}
                    title="Espaço Físico"
                    className="flex-1 border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                  >
                    <option value="">Escolha o espaço físico</option>
                    {locais.filter(l => l.ativo).map(l => (
                      <option key={l.id} value={l.id}>{l.nome}</option>
                    ))}
                  </select>
                  <button type="button" onClick={() => setShowQuickLocal(true)} className="p-2 text-[#FC5931] hover:bg-[#FC5931]/10 rounded-xl transition-colors" title="Adicionar local">
                    <PlusCircle size={22} />
                  </button>
                </div>
              </div>

              {/* Categoria */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Categoria:</label>
                <div className="flex gap-2">
                  <select
                    value={form.categoria_id}
                    onChange={e => setForm({ ...form, categoria_id: e.target.value })}
                    title="Categoria"
                    className="flex-1 border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                  >
                    <option value="">Escolha a categoria</option>
                    {categorias.filter(c => c.ativo).map(c => (
                      <option key={c.id} value={c.id}>{c.nome}</option>
                    ))}
                  </select>
                  <button type="button" onClick={() => setShowQuickCategoria(true)} className="p-2 text-[#FC5931] hover:bg-[#FC5931]/10 rounded-xl transition-colors" title="Adicionar categoria">
                    <PlusCircle size={22} />
                  </button>
                </div>
              </div>

              {/* Nome */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Nome do produto:</label>
                <input type="text" required value={form.nome} onChange={e => setForm({ ...form, nome: e.target.value })} placeholder="Digite o nome do produto" className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all" />
              </div>

              {/* Tipo de Controle */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Tipo de controle:</label>
                <div className="flex gap-2">
                  {([
                    { value: 'consumivel', label: '🧴 Consumível', desc: 'Sai e não volta (detergente, saco de lixo)' },
                    { value: 'retornavel', label: '🔄 Retornável', desc: 'Sai e volta (vassoura, furadeira)' },
                    { value: 'misto', label: '🔀 Misto', desc: 'Pode ser ambos' },
                  ] as const).map(opt => (
                    <button
                      key={opt.value}
                      type="button"
                      onClick={() => setForm({ ...form, tipo_controle: opt.value })}
                      className={`flex-1 p-3 rounded-xl border-2 text-left transition-all ${
                        form.tipo_controle === opt.value
                          ? 'border-[#FC5931] bg-[#FC5931]/5'
                          : 'border-gray-200 hover:border-gray-300'
                      }`}
                    >
                      <p className="text-sm font-semibold">{opt.label}</p>
                      <p className="text-[10px] text-gray-400 mt-0.5">{opt.desc}</p>
                    </button>
                  ))}
                </div>
              </div>

              {/* Unidade */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Unidade:</label>
                <select value={form.unidade} onChange={e => setForm({ ...form, unidade: e.target.value })} title="Unidade de medida" className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all">
                  {UNIDADES.map(u => (
                    <option key={u} value={u}>{u.charAt(0).toUpperCase() + u.slice(1)}</option>
                  ))}
                </select>
              </div>

              {/* Estoque Mínimo */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Estoque mínimo:</label>
                <input type="number" min="0" title="Estoque mínimo" value={form.quantidade_minima} onChange={e => setForm({ ...form, quantidade_minima: e.target.value })} className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all" />
              </div>

              {/* Estoque Máximo */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Estoque máximo:</label>
                <input type="number" min="0" title="Estoque máximo" value={form.quantidade_maxima} onChange={e => setForm({ ...form, quantidade_maxima: e.target.value })} className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all" />
              </div>

              {/* Quantidade Atual */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Qtd. inicial:</label>
                <input type="number" min="0" title="Quantidade inicial" value={form.quantidade_atual} onChange={e => setForm({ ...form, quantidade_atual: e.target.value })} className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all" />
              </div>

              {/* Custo Unitário */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Custo unitário (R$):</label>
                <input type="number" min="0" step="0.01" title="Custo unitário" value={form.custo_unitario} onChange={e => setForm({ ...form, custo_unitario: e.target.value })} placeholder="0.00" className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all" />
              </div>

              {/* Data de Validade */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Validade:</label>
                <input type="date" title="Data de validade" value={form.data_validade} onChange={e => setForm({ ...form, data_validade: e.target.value })} className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all" />
              </div>

              {/* Marca */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Marca:</label>
                <input type="text" value={form.marca} onChange={e => setForm({ ...form, marca: e.target.value })} placeholder="Digite a marca do produto" className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all" />
              </div>

              {/* Fornecedor */}
              <div className="grid grid-cols-[160px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Fornecedor:</label>
                <select value={form.fornecedor_id} onChange={e => setForm({ ...form, fornecedor_id: e.target.value })} title="Fornecedor" className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all">
                  <option value="">Nenhum fornecedor selecionado</option>
                  {fornecedores.map(f => (
                    <option key={f.id} value={f.id}>{f.nome}</option>
                  ))}
                </select>
              </div>

              {/* Descrição */}
              <div className="grid grid-cols-[160px_1fr] items-start gap-4">
                <label className="text-gray-600 font-medium mt-2">Descrição:</label>
                <textarea value={form.descricao} onChange={e => setForm({ ...form, descricao: e.target.value })} placeholder="Escreva aqui uma descrição" rows={3} className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all resize-none" />
              </div>

              {error && <div className="p-3 bg-red-50 text-red-600 border border-red-100 rounded-xl text-sm">{error}</div>}

              <div className="flex items-center justify-center gap-4 mt-6">
                <button type="submit" disabled={isSaving} className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-8 py-2.5 rounded-2xl font-medium shadow-sm transition-colors flex items-center gap-2 disabled:opacity-50">
                  <Save size={16} />
                  {isSaving ? 'Salvando...' : 'Salvar'}
                </button>
                <button type="button" onClick={() => setIsModalOpen(false)} className="bg-white border border-gray-300 text-gray-700 hover:bg-gray-50 px-8 py-2.5 rounded-2xl font-medium shadow-sm transition-colors">
                  Voltar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Quick-add Local Modal */}
      {showQuickLocal && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/30">
          <div className="bg-white w-full max-w-sm rounded-2xl shadow-xl p-6">
            <h3 className="font-bold text-gray-800 mb-4">Adicionar Local Rápido</h3>
            <input type="text" value={quickLocalNome} onChange={e => setQuickLocalNome(e.target.value)} placeholder="Nome do local" className="w-full border border-gray-300 rounded-xl px-4 py-2 mb-4 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30" autoFocus />
            <div className="flex gap-3 justify-end">
              <button onClick={() => setShowQuickLocal(false)} className="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded-xl transition-colors">Cancelar</button>
              <button onClick={handleQuickAddLocal} className="px-4 py-2 bg-[#FC5931] text-white rounded-xl hover:bg-[#D42F1D] transition-colors">Adicionar</button>
            </div>
          </div>
        </div>
      )}

      {/* Quick-add Categoria Modal */}
      {showQuickCategoria && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/30">
          <div className="bg-white w-full max-w-sm rounded-2xl shadow-xl p-6">
            <h3 className="font-bold text-gray-800 mb-4">Adicionar Categoria Rápida</h3>
            <input type="text" value={quickCategoriaNome} onChange={e => setQuickCategoriaNome(e.target.value)} placeholder="Nome da categoria" className="w-full border border-gray-300 rounded-xl px-4 py-2 mb-4 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30" autoFocus />
            <div className="flex gap-3 justify-end">
              <button onClick={() => setShowQuickCategoria(false)} className="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded-xl transition-colors">Cancelar</button>
              <button onClick={handleQuickAddCategoria} className="px-4 py-2 bg-[#FC5931] text-white rounded-xl hover:bg-[#D42F1D] transition-colors">Adicionar</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
