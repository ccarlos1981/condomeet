'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Plus, Pencil, Trash2, X, Loader2, ClipboardList, Package, ToggleLeft, ToggleRight, ChevronDown, ChevronRight
} from 'lucide-react'

// ─── Types ───────────────────────────────────────────────────────────────────

type Assunto = {
  id: string
  condominio_id: string
  titulo: string
  observacao: string | null
  ativo: boolean
  created_at: string
}

type ItemInventario = {
  id: string
  assunto_id: string
  condominio_id: string
  nome: string
  quantidade: number
  unidade: string
  observacao: string | null
  created_at: string
}

const UNIDADES = ['Unidade', 'Dúzia', 'Cx', 'Kg', 'Litro']

// ─── Assunto Form ────────────────────────────────────────────────────────────

function AssuntoForm({
  condoId,
  assunto,
  onClose,
  onSaved,
}: {
  condoId: string
  assunto?: Assunto
  onClose: () => void
  onSaved: (a: Assunto) => void
}) {
  const [titulo, setTitulo] = useState(assunto?.titulo ?? '')
  const [obs, setObs] = useState(assunto?.observacao ?? '')
  const [saving, setSaving] = useState(false)

  async function handleSave() {
    if (!titulo.trim()) return
    setSaving(true)
    const supabase = createClient()

    if (assunto) {
      const { data } = await supabase
        .from('turno_assuntos')
        .update({ titulo: titulo.trim(), observacao: obs.trim() || null })
        .eq('id', assunto.id)
        .select()
        .single()
      if (data) onSaved(data as Assunto)
    } else {
      const { data } = await supabase
        .from('turno_assuntos')
        .insert({ condominio_id: condoId, titulo: titulo.trim(), observacao: obs.trim() || null })
        .select()
        .single()
      if (data) onSaved(data as Assunto)
    }
    setSaving(false)
    onClose()
  }

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-6 max-w-2xl">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-bold text-gray-900">
          {assunto ? 'Editar Assunto' : 'Cadastrar campo de observação'}
        </h3>
        <button onClick={onClose} className="p-1 rounded-lg hover:bg-gray-100 text-gray-400">
          <X size={18} />
        </button>
      </div>
      <div className="flex gap-4 items-start">
        <input
          value={titulo}
          onChange={e => setTitulo(e.target.value)}
          placeholder="Título do assunto"
          className="flex-1 border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
        />
        <textarea
          value={obs}
          onChange={e => setObs(e.target.value)}
          placeholder="Observação sobre o assunto"
          rows={2}
          className="flex-1 border border-gray-200 rounded-xl px-4 py-2.5 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
        />
      </div>
      <div className="mt-4">
        <button
          onClick={handleSave}
          disabled={saving || !titulo.trim()}
          className="bg-[#FC5931] text-white px-6 py-2.5 rounded-xl text-sm font-semibold hover:bg-[#D42F1D] transition disabled:opacity-40"
        >
          {saving ? 'Salvando...' : 'Salvar'}
        </button>
      </div>
    </div>
  )
}

// ─── Inventário Form ─────────────────────────────────────────────────────────

function InventarioForm({
  condoId,
  assuntoId,
  item,
  onSaved,
  onClose,
}: {
  condoId: string
  assuntoId: string
  item?: ItemInventario
  onSaved: (i: ItemInventario) => void
  onClose: () => void
}) {
  const [nome, setNome] = useState(item?.nome ?? '')
  const [qtd, setQtd] = useState(String(item?.quantidade ?? ''))
  const [unidade, setUnidade] = useState(item?.unidade ?? 'Unidade')
  const [obs, setObs] = useState(item?.observacao ?? '')
  const [saving, setSaving] = useState(false)

  async function handleSave() {
    if (!nome.trim()) return
    setSaving(true)
    const supabase = createClient()
    const payload = {
      assunto_id: assuntoId,
      condominio_id: condoId,
      nome: nome.trim(),
      quantidade: Number(qtd) || 0,
      unidade,
      observacao: obs.trim() || null,
    }

    if (item) {
      const { data } = await supabase
        .from('turno_inventario')
        .update(payload)
        .eq('id', item.id)
        .select()
        .single()
      if (data) onSaved(data as ItemInventario)
    } else {
      const { data } = await supabase
        .from('turno_inventario')
        .insert(payload)
        .select()
        .single()
      if (data) onSaved(data as ItemInventario)
    }
    setSaving(false)
    if (!item) {
      setNome('')
      setQtd('')
      setObs('')
      setUnidade('Unidade')
    } else {
      onClose()
    }
  }

  return (
    <div className="flex items-center gap-2 px-5 py-3 bg-gray-50 rounded-xl">
      <input
        value={nome}
        onChange={e => setNome(e.target.value)}
        placeholder="Objeto"
        className="flex-[2] border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
      />
      <input
        value={qtd}
        onChange={e => setQtd(e.target.value)}
        placeholder="Qtd"
        type="number"
        min={0}
        className="w-20 border border-gray-200 rounded-lg px-3 py-2 text-sm text-center focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
      />
      <select
        value={unidade}
        onChange={e => setUnidade(e.target.value)}
        className="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
      >
        {UNIDADES.map(u => <option key={u} value={u}>{u}</option>)}
      </select>
      <input
        value={obs}
        onChange={e => setObs(e.target.value)}
        placeholder="Observação do item"
        className="flex-[2] border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
      />
      <button
        onClick={handleSave}
        disabled={saving || !nome.trim()}
        className="p-2 rounded-lg bg-[#FC5931] text-white hover:bg-[#D42F1D] transition disabled:opacity-40"
        title={item ? 'Salvar' : 'Adicionar'}
      >
        {saving ? <Loader2 size={16} className="animate-spin" /> : <Plus size={16} />}
      </button>
      {item && (
        <button onClick={onClose} className="p-2 rounded-lg text-gray-400 hover:bg-gray-200 transition">
          <X size={16} />
        </button>
      )}
    </div>
  )
}

// ─── Main Component ──────────────────────────────────────────────────────────

export default function RegistroTurnoClient({
  initialAssuntos,
  initialInventario,
  condoId,
}: {
  initialAssuntos: Assunto[]
  initialInventario: ItemInventario[]
  condoId: string
}) {
  const [assuntos, setAssuntos] = useState<Assunto[]>(initialAssuntos)
  const [inventario, setInventario] = useState<ItemInventario[]>(initialInventario)
  const [showAssuntoForm, setShowAssuntoForm] = useState(false)
  const [editAssunto, setEditAssunto] = useState<Assunto | undefined>()
  const [expandedAssunto, setExpandedAssunto] = useState<string | null>(null)
  const [editItem, setEditItem] = useState<ItemInventario | undefined>()

  const supabase = createClient()

  function itensDoAssunto(assuntoId: string) {
    return inventario.filter(i => i.assunto_id === assuntoId)
  }

  async function toggleAtivo(assunto: Assunto) {
    const newAtivo = !assunto.ativo
    await supabase.from('turno_assuntos').update({ ativo: newAtivo }).eq('id', assunto.id)
    setAssuntos(prev => prev.map(a => a.id === assunto.id ? { ...a, ativo: newAtivo } : a))
  }

  async function deleteAssunto(id: string) {
    if (!confirm('Excluir assunto? Os itens do inventário vinculados também serão excluídos.')) return
    await supabase.from('turno_assuntos').delete().eq('id', id)
    setAssuntos(prev => prev.filter(a => a.id !== id))
    setInventario(prev => prev.filter(i => i.assunto_id !== id))
  }

  async function deleteItem(id: string) {
    if (!confirm('Excluir item do inventário?')) return
    await supabase.from('turno_inventario').delete().eq('id', id)
    setInventario(prev => prev.filter(i => i.id !== id))
  }

  return (
    <div className="space-y-6">
      {/* Toggle form */}
      <button
        onClick={() => { setShowAssuntoForm(!showAssuntoForm); setEditAssunto(undefined) }}
        className="flex items-center gap-2 text-sm font-semibold text-[#FC5931] hover:text-[#D42F1D] transition"
      >
        <span className="w-6 h-6 rounded-full border-2 border-[#FC5931] flex items-center justify-center">
          {showAssuntoForm ? <X size={12} /> : <Plus size={12} />}
        </span>
        Cadastrar campo de observação
      </button>

      {/* Assunto Form */}
      {showAssuntoForm && (
        <AssuntoForm
          condoId={condoId}
          assunto={editAssunto}
          onClose={() => { setShowAssuntoForm(false); setEditAssunto(undefined) }}
          onSaved={a => {
            setAssuntos(prev => editAssunto ? prev.map(x => x.id === a.id ? a : x) : [...prev, a])
          }}
        />
      )}

      {/* List of Assuntos */}
      {assuntos.length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          <ClipboardList size={40} className="mx-auto mb-3 opacity-30" />
          <p className="font-medium text-gray-500">Nenhum assunto cadastrado</p>
          <p className="text-sm">Clique acima para cadastrar o primeiro campo de observação</p>
        </div>
      ) : (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          {/* Header */}
          <div className="grid grid-cols-[1fr_2fr_80px_80px_80px] gap-2 px-5 py-3 bg-gray-50 text-xs font-semibold text-gray-500 uppercase tracking-wide">
            <span>Assunto</span>
            <span>Observação do assunto</span>
            <span className="text-center">Editar</span>
            <span className="text-center">Ativo</span>
            <span className="text-center">Materiais</span>
          </div>

          {assuntos.map(assunto => {
            const isExpanded = expandedAssunto === assunto.id
            const itens = itensDoAssunto(assunto.id)

            return (
              <div key={assunto.id} className="border-t border-gray-50">
                {/* Assunto row */}
                <div className={`grid grid-cols-[1fr_2fr_80px_80px_80px] gap-2 px-5 py-4 items-center ${!assunto.ativo ? 'opacity-50' : ''}`}>
                  <span className="font-medium text-gray-800 text-sm">{assunto.titulo}</span>
                  <span className="text-gray-500 text-sm">{assunto.observacao || '—'}</span>
                  <div className="flex justify-center gap-1">
                    <button
                      onClick={() => { setEditAssunto(assunto); setShowAssuntoForm(true) }}
                      className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC5931] hover:bg-orange-50 transition"
                      title="Editar assunto"
                    >
                      <Pencil size={14} />
                    </button>
                    <button
                      onClick={() => deleteAssunto(assunto.id)}
                      className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition"
                      title="Excluir assunto"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                  <div className="flex justify-center">
                    <button onClick={() => toggleAtivo(assunto)} title={assunto.ativo ? 'Desativar' : 'Ativar'}>
                      {assunto.ativo
                        ? <ToggleRight size={24} className="text-green-500" />
                        : <ToggleLeft size={24} className="text-gray-300" />
                      }
                    </button>
                  </div>
                  <div className="flex justify-center">
                    <button
                      onClick={() => setExpandedAssunto(isExpanded ? null : assunto.id)}
                      className={`p-1.5 rounded-lg transition ${isExpanded ? 'bg-[#FC5931] text-white' : 'text-gray-400 hover:bg-orange-50 hover:text-[#FC5931]'}`}
                      title="Gerenciar materiais"
                    >
                      {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                    </button>
                  </div>
                </div>

                {/* Expanded: Inventário */}
                {isExpanded && (
                  <div className="border-t border-gray-100 bg-gray-50/50 px-5 py-4 space-y-3">
                    <div className="flex items-center gap-2 mb-3">
                      <Package size={16} className="text-[#FC5931]" />
                      <span className="font-semibold text-gray-700 text-sm">Cadastro do inventário da Portaria</span>
                    </div>

                    {/* Add new item form */}
                    <InventarioForm
                      condoId={condoId}
                      assuntoId={assunto.id}
                      onSaved={i => setInventario(prev => [...prev, i])}
                      onClose={() => {}}
                    />

                    {/* Items list */}
                    {itens.length > 0 && (
                      <div className="space-y-1 mt-3">
                        {itens.map(item => (
                          <div key={item.id}>
                            {editItem?.id === item.id ? (
                              <InventarioForm
                                condoId={condoId}
                                assuntoId={assunto.id}
                                item={item}
                                onSaved={i => {
                                  setInventario(prev => prev.map(x => x.id === i.id ? i : x))
                                  setEditItem(undefined)
                                }}
                                onClose={() => setEditItem(undefined)}
                              />
                            ) : (
                              <div className="flex items-center gap-3 px-5 py-2.5 bg-white rounded-xl border border-gray-100">
                                <span className="flex-[2] font-medium text-gray-800 text-sm">{item.nome}</span>
                                <span className="w-16 text-center font-semibold text-gray-700 text-sm">{item.quantidade}</span>
                                <span className="w-20 text-gray-500 text-sm">{item.unidade}</span>
                                <span className="flex-[2] text-gray-400 text-sm italic">{item.observacao || 'Observação do item'}</span>
                                <button
                                  onClick={() => setEditItem(item)}
                                  className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC5931] hover:bg-orange-50 transition"
                                  title="Editar"
                                >
                                  <Pencil size={14} />
                                </button>
                                <button
                                  onClick={() => deleteItem(item.id)}
                                  className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition"
                                  title="Excluir"
                                >
                                  <Trash2 size={14} />
                                </button>
                              </div>
                            )}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
