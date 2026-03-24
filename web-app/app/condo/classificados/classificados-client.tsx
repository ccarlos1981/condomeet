'use client'
import { useState, useMemo, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import {
  Plus, Heart, Eye, Search, Filter, Edit2, Trash2, Tag,
  X, Image as ImageIcon, ShoppingBag
} from 'lucide-react'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

interface Perfil {
  nome_completo: string
  bloco_txt: string
  apto_txt: string
  whatsapp: string
}

interface Classificado {
  id: string
  titulo: string
  descricao: string
  categoria: string
  marca_modelo: string
  preco: number | null
  condicao: string
  mostrar_telefone: boolean
  foto_url: string | null
  status: string
  cod_interno: string
  visualizacoes: number
  criado_por: string
  created_at: string
  perfil: Perfil | null
}

const CATEGORIAS: Record<string, string> = {
  eletronicos: 'Eletrônicos',
  moveis: 'Móveis',
  roupas: 'Roupas',
  veiculos: 'Veículos',
  servicos: 'Serviços',
  imoveis: 'Imóveis',
  carros_e_pecas: 'Carros e Peças',
  outros: 'Outros',
}

export default function ClassificadosClient({
  classificados: initialClassificados,
  userId,
  condominioId,
  favoritosIds: initialFavoritos,
  tipoEstrutura,
}: {
  classificados: Classificado[]
  userId: string
  condominioId: string
  favoritosIds: string[]
  tipoEstrutura: string
  userName: string
}) {
  const supabase = createClient()
  const router = useRouter()
  const [classificados, setClassificados] = useState(initialClassificados)
  const [favoritos, setFavoritos] = useState<Set<string>>(new Set(initialFavoritos))
  const [searchText, setSearchText] = useState('')
  const [categoriaFilter, setCategoriaFilter] = useState('')
  const [statusTab, setStatusTab] = useState<'aprovados' | 'pendentes'>('aprovados')
  const [showFavorites, setShowFavorites] = useState(false)
  const [showModal, setShowModal] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [selectedAd, setSelectedAd] = useState<Classificado | null>(null)

  // Form state
  const [formData, setFormData] = useState({
    titulo: '',
    descricao: '',
    categoria: 'outros',
    marca_modelo: '',
    preco: '',
    condicao: 'usado',
    mostrar_telefone: true,
  })
  const [foto, setFoto] = useState<File | null>(null)
  const [fotoPreview, setFotoPreview] = useState<string | null>(null)

  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)

  const myPendingCount = useMemo(() => classificados.filter(c => c.criado_por === userId && (c.status === 'pendente' || c.status === 'rejeitado')).length, [classificados, userId])

  const filtered = useMemo(() => {
    let result = classificados
    if (statusTab === 'pendentes') {
      result = result.filter(c => c.criado_por === userId && (c.status === 'pendente' || c.status === 'rejeitado'))
    } else {
      result = result.filter(c => c.status === 'aprovado' || c.status === 'vendido')
    }
    if (showFavorites) result = result.filter(c => favoritos.has(c.id))
    if (categoriaFilter) result = result.filter(c => c.categoria === categoriaFilter)
    if (searchText) {
      const q = searchText.toLowerCase()
      result = result.filter(c =>
        c.titulo.toLowerCase().includes(q) ||
        c.descricao?.toLowerCase().includes(q) ||
        c.marca_modelo?.toLowerCase().includes(q)
      )
    }
    return result
  }, [classificados, statusTab, showFavorites, categoriaFilter, searchText, favoritos, userId])

  const toggleFavorite = useCallback(async (id: string) => {
    const isFav = favoritos.has(id)
    if (isFav) {
      await supabase.from('classificados_favoritos').delete().eq('classificado_id', id).eq('usuario_id', userId)
      setFavoritos(prev => { const n = new Set(prev); n.delete(id); return n })
    } else {
      await supabase.from('classificados_favoritos').insert({ classificado_id: id, usuario_id: userId })
      setFavoritos(prev => new Set([...prev, id]))
    }
  }, [favoritos, supabase, userId])

  function openCreateModal() {
    setEditingId(null)
    setFormData({ titulo: '', descricao: '', categoria: 'outros', marca_modelo: '', preco: '', condicao: 'usado', mostrar_telefone: true })
    setFoto(null)
    setFotoPreview(null)
    setShowModal(true)
  }

  function openEditModal(c: Classificado) {
    setEditingId(c.id)
    setFormData({
      titulo: c.titulo,
      descricao: c.descricao ?? '',
      categoria: c.categoria,
      marca_modelo: c.marca_modelo ?? '',
      preco: c.preco ? String(c.preco) : '',
      condicao: c.condicao ?? 'usado',
      mostrar_telefone: c.mostrar_telefone,
    })
    setFoto(null)
    setFotoPreview(c.foto_url)
    setShowModal(true)
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!formData.titulo.trim()) return alert('Título é obrigatório')
    setSaving(true)

    try {
      let fotoUrl = fotoPreview

      // Upload photo if new
      if (foto) {
        const ext = foto.name.split('.').pop()
        const path = `${condominioId}/${Date.now()}.${ext}`
        const { error: upErr } = await supabase.storage.from('classificados-fotos').upload(path, foto, { upsert: true })
        if (upErr) throw upErr
        const { data: urlData } = supabase.storage.from('classificados-fotos').getPublicUrl(path)
        fotoUrl = urlData.publicUrl
      }

      const record = {
        titulo: formData.titulo.trim(),
        descricao: formData.descricao.trim() || null,
        categoria: formData.categoria,
        marca_modelo: formData.marca_modelo.trim() || null,
        preco: formData.preco ? parseFloat(formData.preco) : null,
        condicao: formData.condicao,
        mostrar_telefone: formData.mostrar_telefone,
        foto_url: fotoUrl,
      }

      if (editingId) {
        // Edit sends back to pendente for re-approval
        const { error } = await supabase.from('classificados').update({ ...record, status: 'pendente' }).eq('id', editingId)
        if (error) throw error
      } else {
        const { error } = await supabase.from('classificados').insert({
          ...record,
          condominio_id: condominioId,
          criado_por: userId,
          status: 'pendente',
        })
        if (error) throw error

        // Trigger notification for new ad (get the newly created row)
        const { data: newAd } = await supabase
          .from('classificados')
          .select('id')
          .eq('criado_por', userId)
          .eq('condominio_id', condominioId)
          .order('created_at', { ascending: false })
          .limit(1)
          .single()

        if (newAd) {
          try {
            await supabase.functions.invoke('classificados-notify', {
              body: { condominio_id: condominioId, classificado_id: newAd.id, action: 'novo' }
            })
          } catch (e) { console.warn('Notification failed:', e) }
        }
      }

      setShowModal(false)
      router.refresh()
      // Refresh data
      const { data: refreshed } = await supabase
        .from('classificados')
        .select('*, perfil:criado_por (nome_completo, bloco_txt, apto_txt, whatsapp)')
        .eq('condominio_id', condominioId)
        .order('created_at', { ascending: false })

      if (refreshed) {
        setClassificados(refreshed.map((c: any) => ({ // eslint-disable-line @typescript-eslint/no-explicit-any
          ...c,
          perfil: Array.isArray(c.perfil) ? c.perfil[0] : c.perfil,
        })))
      }
    } catch (error) {
      console.error('Error saving classificado:', error)
      alert('Erro ao salvar anúncio')
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete(id: string) {
    if (!confirm('Tem certeza que deseja excluir este anúncio?')) return
    await supabase.from('classificados').delete().eq('id', id)
    setClassificados(prev => prev.filter(c => c.id !== id))
    if (selectedAd?.id === id) setSelectedAd(null)
    router.refresh()
  }

  async function handleMarkSold(id: string) {
    await supabase.from('classificados').update({ status: 'vendido' }).eq('id', id)
    setClassificados(prev => prev.map(c => c.id === id ? { ...c, status: 'vendido' } : c))
    router.refresh()
  }

  async function incrementView(c: Classificado) {
    if (c.criado_por !== userId) {
      await supabase.from('classificados').update({ visualizacoes: c.visualizacoes + 1 }).eq('id', c.id)
    }
    setSelectedAd(c)
  }

  function handleFotoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setFoto(file)
    setFotoPreview(URL.createObjectURL(file))
  }

  return (
    <div className="max-w-6xl mx-auto py-6 px-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">🛒 Classificados</h1>
          <p className="text-sm text-gray-500">Compre, venda e troque no condomínio</p>
        </div>
        <button
          onClick={openCreateModal}
          className="flex items-center gap-2 px-5 py-2.5 bg-[#FC5931] hover:bg-[#D42F1D] text-white font-bold rounded-xl shadow-lg shadow-[#FC5931]/30 transition-all hover:scale-105"
        >
          <Plus size={18} />
          <span className="hidden sm:inline">Inserir Anúncio</span>
        </button>
      </div>

      {/* Status tabs */}
      <div className="flex gap-2 mb-4">
        <button
          onClick={() => setStatusTab('aprovados')}
          className={`px-5 py-2 rounded-full text-sm font-bold transition-all ${
            statusTab === 'aprovados'
              ? 'bg-green-500 text-white shadow-md'
              : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          }`}
        >
          ✅ Aprovados
        </button>
        <button
          onClick={() => setStatusTab('pendentes')}
          className={`px-5 py-2 rounded-full text-sm font-bold transition-all ${
            statusTab === 'pendentes'
              ? 'bg-yellow-500 text-white shadow-md'
              : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          }`}
        >
          ⏳ Meus Pendentes
          {myPendingCount > 0 && (
            <span className="ml-1.5 px-1.5 py-0.5 bg-white/30 rounded-full text-xs">{myPendingCount}</span>
          )}
        </button>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4 mb-6">
        <div className="flex flex-wrap gap-3 items-center">
          {/* Search */}
          <div className="flex-1 min-w-[200px] relative">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Buscar produto..."
              value={searchText}
              onChange={e => setSearchText(e.target.value)}
              className="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
            />
          </div>

          {/* Category */}
          <div className="relative">
            <Filter size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <select
              value={categoriaFilter}
              onChange={e => setCategoriaFilter(e.target.value)}
              aria-label="Filtrar por categoria"
              className="pl-8 pr-4 py-2 border border-gray-200 rounded-xl text-sm appearance-none bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
            >
              <option value="">Todas Categorias</option>
              {Object.entries(CATEGORIAS).map(([k, v]) => (
                <option key={k} value={k}>{v}</option>
              ))}
            </select>
          </div>

          {/* Favorites */}
          <label className="flex items-center gap-2 cursor-pointer text-sm">
            <input
              type="checkbox"
              checked={showFavorites}
              onChange={e => setShowFavorites(e.target.checked)}
              className="rounded border-gray-300 text-[#FC5931] focus:ring-[#FC5931]"
            />
            ❤️ Favoritos
          </label>
        </div>
      </div>

      {/* Results count */}
      <p className="text-sm text-gray-500 mb-4">{filtered.length} anúncio{filtered.length !== 1 ? 's' : ''} encontrado{filtered.length !== 1 ? 's' : ''}</p>

      {/* Ads grid */}
      {filtered.length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          <ShoppingBag size={56} className="mx-auto mb-4 opacity-40" />
          <p className="text-lg font-medium">Nenhum anúncio encontrado</p>
          <p className="text-sm mt-1">Seja o primeiro a anunciar!</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map(c => (
            <div
              key={c.id}
              className={`bg-white rounded-2xl shadow-sm border overflow-hidden transition-all hover:shadow-md cursor-pointer group ${
                c.status === 'pendente' ? 'border-yellow-200 bg-yellow-50/30' :
                c.status === 'rejeitado' ? 'border-red-200 bg-red-50/30' :
                c.status === 'vendido' ? 'border-gray-200 opacity-60' :
                'border-gray-100'
              }`}
              onClick={() => incrementView(c)}
            >
              {/* Photo */}
              <div className="relative h-48 bg-gray-100 overflow-hidden">
                {c.foto_url ? (
                  <img src={c.foto_url} alt={c.titulo} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                ) : (
                  <div className="flex items-center justify-center h-full">
                    <ImageIcon size={40} className="text-gray-300" />
                  </div>
                )}

                {/* Status badge */}
                {c.status === 'pendente' && (
                  <div className="absolute top-3 left-3 px-2.5 py-1 bg-yellow-500 text-white text-xs font-bold rounded-full">⏳ Aguardando aprovação</div>
                )}
                {c.status === 'rejeitado' && (
                  <div className="absolute top-3 left-3 px-2.5 py-1 bg-red-500 text-white text-xs font-bold rounded-full">❌ Rejeitado</div>
                )}
                {c.status === 'vendido' && (
                  <div className="absolute top-3 left-3 px-2.5 py-1 bg-gray-700 text-white text-xs font-bold rounded-full">✅ Vendido</div>
                )}

                {/* Favorite button */}
                <button
                  onClick={(e) => { e.stopPropagation(); toggleFavorite(c.id) }}
                  aria-label="Favoritar anúncio"
                  className="absolute top-3 right-3 p-2 bg-white/80 backdrop-blur-sm rounded-full hover:bg-white transition-colors shadow-sm"
                >
                  <Heart
                    size={18}
                    className={favoritos.has(c.id) ? 'fill-red-500 text-red-500' : 'text-gray-400'}
                  />
                </button>
              </div>

              {/* Info */}
              <div className="p-4">
                <h3 className="font-bold text-gray-900 truncate text-lg">{c.titulo}</h3>
                <p className="text-sm text-gray-500 mt-1">
                  {blocoLabel}: {c.perfil?.bloco_txt ?? '?'} / {aptoLabel}: {c.perfil?.apto_txt ?? '?'}
                </p>
                {c.preco && (
                  <p className="text-xl font-bold text-green-600 mt-2">
                    R$ {Number(c.preco).toFixed(2).replace('.', ',')}
                  </p>
                )}
                <div className="flex items-center gap-3 mt-2 text-xs text-gray-400">
                  <span className="flex items-center gap-1"><Eye size={12} /> {c.visualizacoes}</span>
                  <span>{new Date(c.created_at).toLocaleDateString('pt-BR')}</span>
                  <span className="px-1.5 py-0.5 bg-gray-100 rounded text-[10px] font-medium">{CATEGORIAS[c.categoria] ?? c.categoria}</span>
                </div>

                {/* Owner actions */}
                {c.criado_por === userId && c.status !== 'vendido' && (
                  <div className="flex gap-2 mt-3 pt-3 border-t border-gray-100">
                    {c.status === 'aprovado' && (
                      <>
                        <button
                          onClick={(e) => { e.stopPropagation(); openEditModal(c) }}
                          className="flex-1 flex items-center justify-center gap-1 py-1.5 bg-blue-500 hover:bg-blue-600 text-white text-xs font-bold rounded-lg transition-colors"
                        >
                          <Edit2 size={12} /> Editar
                        </button>
                        <button
                          onClick={(e) => { e.stopPropagation(); handleMarkSold(c.id) }}
                          className="flex-1 flex items-center justify-center gap-1 py-1.5 bg-green-500 hover:bg-green-600 text-white text-xs font-bold rounded-lg transition-colors"
                        >
                          <Tag size={12} /> Vendi
                        </button>
                      </>
                    )}
                    <button
                      onClick={(e) => { e.stopPropagation(); handleDelete(c.id) }}
                      className="flex-1 flex items-center justify-center gap-1 py-1.5 bg-red-500 hover:bg-red-600 text-white text-xs font-bold rounded-lg transition-colors"
                    >
                      <Trash2 size={12} /> Excluir
                    </button>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Detail modal */}
      {selectedAd && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setSelectedAd(null)}>
          <div className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
            {selectedAd.foto_url && (
              <img src={selectedAd.foto_url} alt={selectedAd.titulo} className="w-full h-64 object-cover rounded-t-2xl" />
            )}
            <div className="p-6">
              <div className="flex justify-between items-start">
                <h2 className="text-xl font-bold text-gray-900">{selectedAd.titulo}</h2>
                <button onClick={() => setSelectedAd(null)} className="p-1 hover:bg-gray-100 rounded-lg" aria-label="Fechar">
                  <X size={20} />
                </button>
              </div>
              {selectedAd.preco && (
                <p className="text-2xl font-bold text-green-600 mt-2">
                  R$ {Number(selectedAd.preco).toFixed(2).replace('.', ',')}
                </p>
              )}
              <div className="grid grid-cols-2 gap-2 mt-4 text-sm">
                <div><span className="text-gray-500">Categoria:</span> {CATEGORIAS[selectedAd.categoria]}</div>
                <div><span className="text-gray-500">Condição:</span> {selectedAd.condicao === 'novo' ? 'Novo' : 'Usado'}</div>
                {selectedAd.marca_modelo && <div><span className="text-gray-500">Marca/Modelo:</span> {selectedAd.marca_modelo}</div>}
                <div><span className="text-gray-500">Anunciante:</span> {selectedAd.perfil?.nome_completo}</div>
                <div><span className="text-gray-500">{blocoLabel}:</span> {selectedAd.perfil?.bloco_txt}</div>
                <div><span className="text-gray-500">{aptoLabel}:</span> {selectedAd.perfil?.apto_txt}</div>
                {selectedAd.mostrar_telefone && selectedAd.perfil?.whatsapp && (
                  <div><span className="text-gray-500">WhatsApp:</span> {selectedAd.perfil.whatsapp}</div>
                )}
                <div><span className="text-gray-500">Visualizações:</span> {selectedAd.visualizacoes}</div>
              </div>
              {selectedAd.descricao && (
                <div className="mt-4">
                  <p className="text-sm text-gray-500 mb-1">Descrição:</p>
                  <p className="text-sm text-gray-700 whitespace-pre-wrap">{selectedAd.descricao}</p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Create/Edit modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setShowModal(false)}>
          <div className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
            <div className="p-6">
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-bold text-gray-900">
                  {editingId ? 'Editar Anúncio' : 'Novo Anúncio'}
                </h2>
                <button onClick={() => setShowModal(false)} className="p-1 hover:bg-gray-100 rounded-lg" aria-label="Fechar">
                  <X size={20} />
                </button>
              </div>

              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Título do anúncio *</label>
                  <input
                    type="text"
                    value={formData.titulo}
                    onChange={e => setFormData(p => ({ ...p, titulo: e.target.value }))}
                    required
                    className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                    placeholder="Ex: iPhone 15, Mesa de Escritório..."
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Categoria *</label>
                  <select
                    value={formData.categoria}
                    onChange={e => setFormData(p => ({ ...p, categoria: e.target.value }))}
                    aria-label="Categoria do anúncio"
                    className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                  >
                    {Object.entries(CATEGORIAS).map(([k, v]) => (
                      <option key={k} value={k}>{v}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Marca, modelo ou tipo (opcional)</label>
                  <input
                    type="text"
                    value={formData.marca_modelo}
                    onChange={e => setFormData(p => ({ ...p, marca_modelo: e.target.value }))}
                    className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                    placeholder="Ex: Samsung Galaxy S9..."
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Descrição</label>
                  <textarea
                    value={formData.descricao}
                    onChange={e => setFormData(p => ({ ...p, descricao: e.target.value }))}
                    rows={3}
                    className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 resize-none"
                    placeholder="Descreva o produto..."
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Preço (R$)</label>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={formData.preco}
                      onChange={e => setFormData(p => ({ ...p, preco: e.target.value }))}
                      className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                      placeholder="0,00"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Condição</label>
                    <select
                      value={formData.condicao}
                      onChange={e => setFormData(p => ({ ...p, condicao: e.target.value }))}
                      aria-label="Condição do produto"
                      className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                    >
                      <option value="novo">Novo</option>
                      <option value="usado">Usado</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="flex items-center gap-2 cursor-pointer text-sm">
                    <input
                      type="checkbox"
                      checked={formData.mostrar_telefone}
                      onChange={e => setFormData(p => ({ ...p, mostrar_telefone: e.target.checked }))}
                      className="rounded border-gray-300 text-[#FC5931] focus:ring-[#FC5931]"
                    />
                    Mostrar meu telefone no anúncio
                  </label>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Foto</label>
                  <div className="border-2 border-dashed border-gray-200 rounded-xl p-4 text-center">
                    {fotoPreview ? (
                      <div className="relative inline-block">
                        <img src={fotoPreview} alt="Preview" className="h-32 rounded-lg object-cover" />
                        <button
                          type="button"
                          onClick={() => { setFoto(null); setFotoPreview(null) }}
                          className="absolute -top-2 -right-2 p-1 bg-red-500 text-white rounded-full"
                          aria-label="Remover foto"
                        >
                          <X size={12} />
                        </button>
                      </div>
                    ) : (
                      <label className="cursor-pointer">
                        <ImageIcon size={32} className="mx-auto text-gray-300 mb-2" />
                        <p className="text-sm text-gray-500">Clique para escolher uma foto</p>
                        <input
                          type="file"
                          accept="image/*"
                          onChange={handleFotoChange}
                          className="hidden"
                        />
                      </label>
                    )}
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={saving}
                  className="w-full py-3 bg-[#FC5931] hover:bg-[#D42F1D] text-white font-bold rounded-xl transition-colors disabled:opacity-50 shadow-lg shadow-[#FC5931]/30"
                >
                  {saving ? 'Salvando...' : editingId ? 'Salvar Alterações' : 'Inserir Anúncio'}
                </button>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
