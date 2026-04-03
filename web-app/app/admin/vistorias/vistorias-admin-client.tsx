'use client'
import { useState, useMemo, useRef, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import {
  Plus, Search, Edit2, Trash2, X, Camera, ClipboardCheck,
  ChevronRight, CheckCircle2, AlertTriangle, XCircle, MinusCircle,
  FileSignature, ArrowLeft, Share2, FileDown, ArrowRightLeft, GitCompareArrows,
  HelpCircle, Route
} from 'lucide-react'
import { generateVistoriaPDF } from './generate-pdf'
import VistoriaCompare from './vistoria-compare'

/** ───── Types ───── */
interface Perfil { nome_completo: string; bloco_txt: string; apto_txt: string }

interface VistoriaRow {
  id: string; titulo: string; tipo_bem: string; endereco: string
  responsavel_nome: string; proprietario_nome: string; inquilino_nome: string
  status: string; tipo_vistoria: string; cod_interno: string
  link_publico_token: string; plano: string; criado_por: string
  created_at: string; updated_at: string; perfil: Perfil | null
  template_id: string | null; vistoria_referencia_id: string | null
}

interface TemplateItem { id: string; nome: string; posicao: number }
interface TemplateSecao { id: string; nome: string; posicao: number; icone_emoji: string; vistoria_template_itens: TemplateItem[] }
interface Template { id: string; nome: string; tipo_bem: string; descricao: string; icone_emoji: string; vistoria_template_secoes: TemplateSecao[] }

interface VistoriaItem { id: string; secao_id: string; nome: string; status: string; observacao: string; posicao: number }
interface VistoriaFoto { id: string; item_id: string; foto_url: string; legenda: string; posicao: number }
interface VistoriaSecao { id: string; vistoria_id: string; nome: string; posicao: number; icone_emoji: string }
interface VistoriaAssinatura { id: string; vistoria_id: string; nome: string; papel: string; assinatura_url: string | null; assinado_em: string | null }

const TIPOS_BEM: Record<string, string> = {
  apartamento: '🏢 Apartamento', casa: '🏠 Casa', carro: '🚗 Carro',
  moto: '🏍️ Moto', barco: '⛵ Barco', equipamento: '🔧 Equipamento',
  personalizado: '📋 Personalizado',
}
const STATUS_LABELS: Record<string, { label: string; color: string; icon: React.ReactNode }> = {
  rascunho:     { label: 'Rascunho',     color: 'bg-gray-100 text-gray-700',   icon: <Edit2 size={14} /> },
  em_andamento: { label: 'Em andamento', color: 'bg-blue-100 text-blue-700',   icon: <ClipboardCheck size={14} /> },
  concluida:    { label: 'Concluída',    color: 'bg-green-100 text-green-700', icon: <CheckCircle2 size={14} /> },
  assinada:     { label: 'Assinada',     color: 'bg-purple-100 text-purple-700', icon: <FileSignature size={14} /> },
}
const ITEM_STATUS: Record<string, { label: string; color: string; icon: React.ReactNode }> = {
  ok:          { label: 'OK',          color: 'text-green-600 bg-green-50 border-green-200', icon: <CheckCircle2 size={16} /> },
  atencao:     { label: 'Atenção',     color: 'text-yellow-600 bg-yellow-50 border-yellow-200', icon: <AlertTriangle size={16} /> },
  danificado:  { label: 'Danificado',  color: 'text-red-600 bg-red-50 border-red-200', icon: <XCircle size={16} /> },
  nao_existe:  { label: 'Não existe',  color: 'text-gray-500 bg-gray-50 border-gray-200', icon: <MinusCircle size={16} /> },
}

export default function VistoriasAdminClient({
  vistorias: initialVistorias, templates, userId, condominioId,
  // tipoEstrutura is unused here
}: {
  vistorias: VistoriaRow[]; templates: Template[]; userId: string
  condominioId: string; tipoEstrutura: string
}) {
  const supabase = createClient()
  const router = useRouter()
  const [vistorias, setVistorias] = useState(initialVistorias)
  const [searchText, setSearchText] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [view, setView] = useState<'list' | 'create' | 'edit' | 'signatures' | 'compare'>('list')
  const [activeVistoria, setActiveVistoria] = useState<VistoriaRow | null>(null)
  const [saving, setSaving] = useState(false)
  const [compareEntradaId, setCompareEntradaId] = useState('')
  const [compareSaidaId, setCompareSaidaId] = useState('')
  const [showGuide, setShowGuide] = useState(true)

  useEffect(() => {
    const dismissed = localStorage.getItem('vistorias_admin_guide_dismissed')
    if (dismissed === 'true') setShowGuide(false)
  }, [])
  const [compareTitulos, setCompareTitulos] = useState<[string, string]>(['', ''])

  // Create form
  const [formData, setFormData] = useState({ titulo: '', tipo_bem: 'apartamento', endereco: '', responsavel_nome: '', proprietario_nome: '', inquilino_nome: '', tipo_vistoria: 'entrada', template_id: '', plano: 'free' })

  // Edit state
  const [secoes, setSecoes] = useState<VistoriaSecao[]>([])
  const [itens, setItens] = useState<VistoriaItem[]>([])
  const [fotos, setFotos] = useState<VistoriaFoto[]>([])
  const [assinaturas, setAssinaturas] = useState<VistoriaAssinatura[]>([])
  const [activeSecaoId, setActiveSecaoId] = useState<string | null>(null)
  const [expandedItemId, setExpandedItemId] = useState<string | null>(null)
  const [newSecaoName, setNewSecaoName] = useState('')
  const [newItemName, setNewItemName] = useState('')

  // ── Filtered list ──
  const filtered = useMemo(() => {
    let result = vistorias
    if (statusFilter) result = result.filter(v => v.status === statusFilter)
    if (searchText) {
      const q = searchText.toLowerCase()
      result = result.filter(v =>
        v.titulo.toLowerCase().includes(q) ||
        v.endereco?.toLowerCase().includes(q) ||
        v.cod_interno.toLowerCase().includes(q) ||
        v.perfil?.nome_completo.toLowerCase().includes(q)
      )
    }
    return result
  }, [vistorias, statusFilter, searchText])

  // ── Auto-select template when tipo_bem changes ──
  const matchingTemplates = useMemo(() => templates.filter(t => t.tipo_bem === formData.tipo_bem), [templates, formData.tipo_bem])
  useEffect(() => {
    if (matchingTemplates.length > 0 && !formData.template_id) {
      setFormData(p => ({ ...p, template_id: matchingTemplates[0].id }))
    }
  }, [matchingTemplates, formData.template_id])

  // ── Create vistoria ──
  async function handleCreate(e: React.FormEvent) {
    e.preventDefault()
    if (!formData.titulo.trim()) return alert('Título é obrigatório')
    setSaving(true)

    try {
      const { data: newV, error } = await supabase.from('vistorias').insert({
        titulo: formData.titulo.trim(),
        tipo_bem: formData.tipo_bem,
        endereco: formData.endereco.trim() || null,
        responsavel_nome: formData.responsavel_nome.trim() || null,
        proprietario_nome: formData.proprietario_nome.trim() || null,
        inquilino_nome: formData.inquilino_nome.trim() || null,
        tipo_vistoria: formData.tipo_vistoria,
        template_id: formData.template_id || null,
        plano: formData.plano,
        condominio_id: condominioId,
        criado_por: userId,
        status: 'rascunho',
      }).select().single()

      if (error) throw error

      // Create sections and items from template
      const template = templates.find(t => t.id === formData.template_id)
      if (template && newV) {
        for (const secao of template.vistoria_template_secoes.sort((a, b) => a.posicao - b.posicao)) {
          const { data: newSecao } = await supabase.from('vistoria_secoes').insert({
            vistoria_id: newV.id, nome: secao.nome, posicao: secao.posicao, icone_emoji: secao.icone_emoji,
          }).select().single()

          if (newSecao) {
            const itemsToInsert = secao.vistoria_template_itens
              .sort((a, b) => a.posicao - b.posicao)
              .map(item => ({
                secao_id: newSecao.id, nome: item.nome, posicao: item.posicao, status: 'ok',
              }))
            if (itemsToInsert.length > 0) {
              await supabase.from('vistoria_itens').insert(itemsToInsert)
            }
          }
        }
      }

      router.refresh()
      await refreshData()
      if (newV) openEditorFor(newV.id)
    } catch (err) {
      console.error('Error creating vistoria:', err)
      alert('Erro ao criar vistoria')
    } finally {
      setSaving(false)
    }
  }

  // ── Open editor ──
  async function openEditorFor(vistoriaId: string) {
    const v = vistorias.find(vis => vis.id === vistoriaId) ?? (await loadVistoria(vistoriaId))
    if (!v) return

    setActiveVistoria(v)
    await loadVistoriaData(vistoriaId)
    setView('edit')
  }

  async function loadVistoria(id: string) {
    const { data } = await supabase.from('vistorias').select('*').eq('id', id).single()
    return data
  }

  async function loadVistoriaData(vistoriaId: string) {
    const [secoesRes, assinaturasRes] = await Promise.all([
      supabase.from('vistoria_secoes').select('*').eq('vistoria_id', vistoriaId).order('posicao'),
      supabase.from('vistoria_assinaturas').select('*').eq('vistoria_id', vistoriaId),
    ])

    const secoesData = secoesRes.data ?? []
    setSecoes(secoesData)
    setAssinaturas(assinaturasRes.data ?? [])

    if (secoesData.length > 0) {
      setActiveSecaoId(secoesData[0].id)

      // Load all items for all sections
      const secaoIds = secoesData.map(s => s.id)
      const { data: itensData } = await supabase
        .from('vistoria_itens')
        .select('*')
        .in('secao_id', secaoIds)
        .order('posicao')
      setItens(itensData ?? [])

      // Load all photos
      const itemIds = (itensData ?? []).map(i => i.id)
      if (itemIds.length > 0) {
        const { data: fotosData } = await supabase
          .from('vistoria_fotos')
          .select('*')
          .in('item_id', itemIds)
          .order('posicao')
        setFotos(fotosData ?? [])
      } else {
        setFotos([])
      }
    }
  }

  async function refreshData() {
    const { data } = await supabase
      .from('vistorias')
      .select('*')
      .eq('condominio_id', condominioId)
      .order('created_at', { ascending: false })

    const creatorIds = [...new Set((data ?? []).map((v: { criado_por: string }) => v.criado_por))]
    const { data: criadores } = creatorIds.length > 0
      ? await supabase.from('perfil').select('id, nome_completo, bloco_txt, apto_txt').in('id', creatorIds)
      : { data: [] }
    const criadorMap = Object.fromEntries(
      (criadores ?? []).map((c: { id: string }) => [c.id, c])
    )
    setVistorias((data ?? []).map((v: Record<string, unknown>) => ({ ...v, perfil: criadorMap[v.criado_por as string] ?? null })) as unknown as VistoriaRow[])
  }

  // ── Item status update ──
  async function updateItemStatus(itemId: string, status: string) {
    await supabase.from('vistoria_itens').update({ status }).eq('id', itemId)
    setItens(prev => prev.map(i => i.id === itemId ? { ...i, status } : i))
  }

  async function updateItemObs(itemId: string, observacao: string) {
    await supabase.from('vistoria_itens').update({ observacao }).eq('id', itemId)
    setItens(prev => prev.map(i => i.id === itemId ? { ...i, observacao } : i))
  }

  // ── Photo upload ──
  async function handlePhotoUpload(itemId: string, files: FileList) {
    for (let i = 0; i < files.length; i++) {
      const file = files[i]
      const ext = file.name.split('.').pop()
      const path = `${condominioId}/${activeVistoria!.id}/${itemId}/${Date.now()}_${i}.${ext}`

      const { error: upErr } = await supabase.storage.from('vistoria-fotos').upload(path, file, { upsert: true })
      if (upErr) { console.error(upErr); continue }

      const { data: urlData } = supabase.storage.from('vistoria-fotos').getPublicUrl(path)

      const { data: newFoto } = await supabase.from('vistoria_fotos').insert({
        item_id: itemId, foto_url: urlData.publicUrl, posicao: fotos.filter(f => f.item_id === itemId).length,
      }).select().single()

      if (newFoto) setFotos(prev => [...prev, newFoto])
    }
  }

  async function deletePhoto(fotoId: string) {
    await supabase.from('vistoria_fotos').delete().eq('id', fotoId)
    setFotos(prev => prev.filter(f => f.id !== fotoId))
  }

  // ── Add section ──
  async function addSecao() {
    if (!newSecaoName.trim() || !activeVistoria) return
    const { data } = await supabase.from('vistoria_secoes').insert({
      vistoria_id: activeVistoria.id, nome: newSecaoName.trim(), posicao: secoes.length, icone_emoji: '🏠',
    }).select().single()
    if (data) { setSecoes(prev => [...prev, data]); setActiveSecaoId(data.id) }
    setNewSecaoName('')
  }

  // ── Add item ──
  async function addItem() {
    if (!newItemName.trim() || !activeSecaoId) return
    const { data } = await supabase.from('vistoria_itens').insert({
      secao_id: activeSecaoId, nome: newItemName.trim(), posicao: itens.filter(i => i.secao_id === activeSecaoId).length, status: 'ok',
    }).select().single()
    if (data) setItens(prev => [...prev, data])
    setNewItemName('')
  }

  // ── Delete ──
  async function deleteVistoria(id: string) {
    if (!confirm('Tem certeza que deseja excluir esta vistoria?')) return
    await supabase.from('vistorias').delete().eq('id', id)
    setVistorias(prev => prev.filter(v => v.id !== id))
    if (activeVistoria?.id === id) { setActiveVistoria(null); setView('list') }
    router.refresh()
  }

  async function deleteSecao(secaoId: string) {
    if (!confirm('Excluir este ambiente e todos seus itens?')) return
    await supabase.from('vistoria_secoes').delete().eq('id', secaoId)
    setSecoes(prev => prev.filter(s => s.id !== secaoId))
    setItens(prev => prev.filter(i => i.secao_id !== secaoId))
    if (activeSecaoId === secaoId) setActiveSecaoId(secoes.find(s => s.id !== secaoId)?.id ?? null)
  }

  async function deleteItem(itemId: string) {
    await supabase.from('vistoria_itens').delete().eq('id', itemId)
    setItens(prev => prev.filter(i => i.id !== itemId))
    setFotos(prev => prev.filter(f => f.item_id !== itemId))
  }

  // ── Update status ──
  async function updateVistoriaStatus(newStatus: string) {
    if (!activeVistoria) return
    await supabase.from('vistorias').update({ status: newStatus }).eq('id', activeVistoria.id)
    setActiveVistoria(prev => prev ? { ...prev, status: newStatus } : null)
    setVistorias(prev => prev.map(v => v.id === activeVistoria.id ? { ...v, status: newStatus } : v))
  }

  // ── Signatures ──
  async function addSignatureSlot(nome: string, papel: string) {
    if (!activeVistoria) return
    const { data } = await supabase.from('vistoria_assinaturas').insert({
      vistoria_id: activeVistoria.id, nome, papel,
    }).select().single()
    if (data) setAssinaturas(prev => [...prev, data])
  }

  // ── Summary counts ──
  const activeItens = useMemo(() => itens.filter(i => i.secao_id === activeSecaoId), [itens, activeSecaoId])
  const totalItens = itens.length
  const problemCount = itens.filter(i => i.status === 'danificado' || i.status === 'atencao').length

  // ════════════════════════════════════════
  //  VIEW: List
  // ════════════════════════════════════════
  if (view === 'list') {
    return (
      <div className="max-w-7xl mx-auto py-6 px-4">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">📋 Vistorias Digitais</h1>
            <p className="text-sm text-gray-500">Crie e gerencie vistorias de imóveis, veículos e equipamentos</p>
          </div>
          <div className="flex items-center gap-2">
            {!showGuide && (
              <button
                onClick={() => { setShowGuide(true); localStorage.removeItem('vistorias_admin_guide_dismissed') }}
                className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-[#FC5931] hover:bg-orange-50 rounded-lg transition-colors"
              >
                <HelpCircle size={16} /> Como começar
              </button>
            )}
            <button
              onClick={() => { setFormData({ titulo: '', tipo_bem: 'apartamento', endereco: '', responsavel_nome: '', proprietario_nome: '', inquilino_nome: '', tipo_vistoria: 'entrada', template_id: '', plano: 'free' }); setView('create') }}
              className="flex items-center gap-2 px-5 py-2.5 bg-[#FC5931] hover:bg-[#D42F1D] text-white font-bold rounded-xl shadow-lg shadow-[#FC5931]/30 transition-all hover:scale-105"
            >
              <Plus size={18} />
              <span className="hidden sm:inline">Nova Vistoria</span>
            </button>
          </div>
        </div>

        {/* Como começar guide */}
        {showGuide && (
          <div className="bg-gradient-to-r from-orange-50 to-amber-50 border border-orange-200 rounded-xl p-5 mb-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Route size={18} className="text-[#FC5931]" />
                <span className="font-semibold text-orange-900 text-sm">Como começar com Vistorias Digitais</span>
              </div>
              <button
                onClick={() => { localStorage.setItem('vistorias_admin_guide_dismissed', 'true'); setShowGuide(false) }}
                className="text-gray-400 hover:text-gray-600"
                title="Fechar guia"
              >
                <X size={16} />
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
              {[
                { step: 1, title: 'Crie uma vistoria', desc: 'Clique em "Nova Vistoria" e preencha os dados', done: vistorias.length > 0 },
                { step: 2, title: 'Adicione seções e itens', desc: 'Organize câmodos, fotos e status de cada item', done: vistorias.some(v => v.status !== 'rascunho') },
                { step: 3, title: 'Assine e exporte', desc: 'Colete assinaturas digitais e gere o PDF', done: vistorias.some(v => v.status === 'assinada') },
                { step: 4, title: 'Compare entrada/saída', desc: 'Compare duas vistorias para ver diferenças', done: vistorias.filter(v => v.tipo_vistoria === 'saida').length > 0 },
              ].map(s => (
                <div key={s.step} className={`flex items-start gap-3 p-3 rounded-lg ${s.done ? 'bg-white/60' : 'bg-white'}`}>
                  <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold shrink-0 ${
                    s.done ? 'bg-green-500 text-white' : 'bg-white border-2 border-orange-300 text-orange-500'
                  }`}>
                    {s.done ? <CheckCircle2 size={16} /> : s.step}
                  </div>
                  <div>
                    <p className={`text-sm font-medium ${s.done ? 'text-gray-400 line-through' : 'text-gray-800'}`}>{s.title}</p>
                    <p className="text-xs text-gray-400">{s.desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Filters */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4 mb-6">
          <div className="flex flex-wrap gap-3 items-center">
            <div className="flex-1 min-w-[200px] relative">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type="text" placeholder="Buscar vistoria..."
                value={searchText} onChange={e => setSearchText(e.target.value)}
                className="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
              />
            </div>
            <select
              value={statusFilter} onChange={e => setStatusFilter(e.target.value)}
              aria-label="Filtrar por status"
              className="px-4 py-2 border border-gray-200 rounded-xl text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
            >
              <option value="">Todos Status</option>
              {Object.entries(STATUS_LABELS).map(([k, v]) => (<option key={k} value={k}>{v.label}</option>))}
            </select>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
          {Object.entries(STATUS_LABELS).map(([key, def]) => {
            const count = vistorias.filter(v => v.status === key).length
            return (
              <div key={key} className="bg-white rounded-xl border border-gray-100 p-4 text-center shadow-sm">
                <p className="text-2xl font-bold text-gray-900">{count}</p>
                <p className="text-xs text-gray-500 mt-1">{def.label}</p>
              </div>
            )
          })}
        </div>

        {/* Results */}
        <p className="text-sm text-gray-500 mb-4">{filtered.length} vistoria{filtered.length !== 1 ? 's' : ''}</p>

        {filtered.length === 0 ? (
          <div className="text-center py-20 text-gray-400">
            <ClipboardCheck size={56} className="mx-auto mb-4 opacity-40" />
            <p className="text-lg font-medium">Nenhuma vistoria encontrada</p>
            <p className="text-sm mt-1">Crie sua primeira vistoria digital!</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {filtered.map(v => {
              const st = STATUS_LABELS[v.status] ?? STATUS_LABELS.rascunho
              return (
                <div key={v.id}
                  className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 hover:shadow-md transition-all cursor-pointer group"
                  onClick={() => openEditorFor(v.id)}
                >
                  <div className="flex items-start justify-between mb-3">
                    <div>
                      <h3 className="font-bold text-gray-900 text-lg">{v.titulo}</h3>
                      <p className="text-sm text-gray-500">{TIPOS_BEM[v.tipo_bem] ?? v.tipo_bem}</p>
                    </div>
                    <span className={`px-2.5 py-1 rounded-full text-xs font-bold flex items-center gap-1 ${st.color}`}>
                      {st.icon} {st.label}
                    </span>
                  </div>

                  {v.endereco && <p className="text-sm text-gray-500 mb-1">📍 {v.endereco}</p>}

                  <div className="flex items-center gap-3 mt-3 text-xs text-gray-400">
                    <span>#{v.cod_interno}</span>
                    <span>{new Date(v.created_at).toLocaleDateString('pt-BR')}</span>
                    {v.perfil && <span>{v.perfil.nome_completo}</span>}
                    <span className="px-1.5 py-0.5 bg-gray-100 rounded text-[10px] font-medium uppercase">{v.tipo_vistoria}</span>
                  </div>

                  {/* Actions */}
                  <div className="flex gap-2 mt-4 pt-3 border-t border-gray-100">
                    <button
                      onClick={e => { e.stopPropagation(); openEditorFor(v.id) }}
                      className="flex-1 flex items-center justify-center gap-1 py-1.5 bg-blue-500 hover:bg-blue-600 text-white text-xs font-bold rounded-lg transition-colors"
                    >
                      <Edit2 size={12} /> Editar
                    </button>
                    {v.tipo_vistoria === 'entrada' && (v.status === 'concluida' || v.status === 'assinada') && (
                      <button
                        onClick={e => {
                          e.stopPropagation()
                          setFormData({ titulo: v.titulo.replace('Entrada', 'Saída').replace('entrada', 'saída'), tipo_bem: v.tipo_bem, endereco: v.endereco ?? '', responsavel_nome: v.responsavel_nome ?? '', proprietario_nome: v.proprietario_nome ?? '', inquilino_nome: v.inquilino_nome ?? '', tipo_vistoria: 'saida', template_id: v.template_id ?? '', plano: v.plano })
                          setView('create')
                        }}
                        className="flex items-center justify-center gap-1 px-3 py-1.5 bg-orange-500 hover:bg-orange-600 text-white text-xs font-bold rounded-lg transition-colors"
                      >
                        <ArrowRightLeft size={12} /> Saída
                      </button>
                    )}
                    {v.vistoria_referencia_id && (
                      <button
                        onClick={e => {
                          e.stopPropagation()
                          const refV = vistorias.find(vis => vis.id === v.vistoria_referencia_id)
                          setCompareEntradaId(v.vistoria_referencia_id!)
                          setCompareSaidaId(v.id)
                          setCompareTitulos([refV?.titulo ?? 'Entrada', v.titulo])
                          setView('compare')
                        }}
                        className="flex items-center justify-center gap-1 px-3 py-1.5 bg-purple-500 hover:bg-purple-600 text-white text-xs font-bold rounded-lg transition-colors"
                        title="Comparar entrada × saída"
                      >
                        <GitCompareArrows size={12} />
                      </button>
                    )}
                    <button
                      onClick={e => { e.stopPropagation(); deleteVistoria(v.id) }}
                      title="Excluir vistoria"
                      className="flex items-center justify-center gap-1 px-3 py-1.5 bg-red-500 hover:bg-red-600 text-white text-xs font-bold rounded-lg transition-colors"
                    >
                      <Trash2 size={12} />
                    </button>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>
    )
  }

  // ════════════════════════════════════════
  //  VIEW: Create
  // ════════════════════════════════════════
  if (view === 'create') {
    return (
      <div className="max-w-2xl mx-auto py-6 px-4">
        <button onClick={() => setView('list')} className="flex items-center gap-2 text-gray-500 hover:text-gray-700 mb-6 text-sm">
          <ArrowLeft size={16} /> Voltar
        </button>

        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <h2 className="text-xl font-bold text-gray-900 mb-6">📋 Nova Vistoria</h2>

          <form onSubmit={handleCreate} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Título *</label>
              <input type="text" value={formData.titulo}
                onChange={e => setFormData(p => ({ ...p, titulo: e.target.value }))}
                required placeholder="Ex: Vistoria Apto 302 - Entrada"
                className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Tipo de Bem *</label>
                <select value={formData.tipo_bem}
                  onChange={e => setFormData(p => ({ ...p, tipo_bem: e.target.value, template_id: '' }))}
                  aria-label="Tipo de bem"
                  className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                >
                  {Object.entries(TIPOS_BEM).map(([k, v]) => (<option key={k} value={k}>{v}</option>))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Tipo de Vistoria</label>
                <select value={formData.tipo_vistoria}
                  onChange={e => setFormData(p => ({ ...p, tipo_vistoria: e.target.value }))}
                  aria-label="Tipo de vistoria"
                  className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                >
                  <option value="entrada">📥 Entrada</option>
                  <option value="saida">📤 Saída</option>
                  <option value="periodica">🔄 Periódica</option>
                </select>
              </div>
            </div>

            {matchingTemplates.length > 0 && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Template</label>
                <select value={formData.template_id}
                  onChange={e => setFormData(p => ({ ...p, template_id: e.target.value }))}
                  aria-label="Template"
                  className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                >
                  <option value="">Sem template (vazio)</option>
                  {matchingTemplates.map(t => (<option key={t.id} value={t.id}>{t.icone_emoji} {t.nome} — {t.vistoria_template_secoes.length} ambientes</option>))}
                </select>
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Endereço</label>
              <input type="text" value={formData.endereco}
                onChange={e => setFormData(p => ({ ...p, endereco: e.target.value }))}
                placeholder="Rua, número, complemento" className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
              />
            </div>

            <div className="grid grid-cols-3 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Responsável</label>
                <input type="text" value={formData.responsavel_nome}
                  onChange={e => setFormData(p => ({ ...p, responsavel_nome: e.target.value }))}
                  placeholder="Nome" className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Proprietário</label>
                <input type="text" value={formData.proprietario_nome}
                  onChange={e => setFormData(p => ({ ...p, proprietario_nome: e.target.value }))}
                  placeholder="Nome" className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Inquilino</label>
                <input type="text" value={formData.inquilino_nome}
                  onChange={e => setFormData(p => ({ ...p, inquilino_nome: e.target.value }))}
                  placeholder="Nome" className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                />
              </div>
            </div>

            <div className="bg-gradient-to-r from-amber-50 to-orange-50 border border-amber-200 rounded-xl p-4">
              <label className="block text-sm font-bold text-amber-800 mb-2">💰 Plano</label>
              <div className="flex gap-3">
                <label className="flex-1 cursor-pointer">
                  <input type="radio" name="plano" value="free" checked={formData.plano === 'free'}
                    onChange={e => setFormData(p => ({ ...p, plano: e.target.value }))} className="peer sr-only"
                  />
                  <div className="border-2 border-gray-200 peer-checked:border-green-500 peer-checked:bg-green-50 rounded-xl p-3 text-center transition-all">
                    <p className="font-bold text-gray-800">Free</p>
                    <p className="text-xs text-gray-500">2 ambientes, 2 fotos</p>
                    <p className="text-sm font-bold text-green-600 mt-1">Grátis</p>
                  </div>
                </label>
                <label className="flex-1 cursor-pointer">
                  <input type="radio" name="plano" value="plus" checked={formData.plano === 'plus'}
                    onChange={e => setFormData(p => ({ ...p, plano: e.target.value }))} className="peer sr-only"
                  />
                  <div className="border-2 border-gray-200 peer-checked:border-[#FC5931] peer-checked:bg-orange-50 rounded-xl p-3 text-center transition-all">
                    <p className="font-bold text-gray-800">Plus</p>
                    <p className="text-xs text-gray-500">Ilimitado + assinatura + PDF</p>
                    <p className="text-sm font-bold text-[#FC5931] mt-1">R$ 50,00/uso</p>
                  </div>
                </label>
              </div>
            </div>

            <button type="submit" disabled={saving}
              className="w-full py-3 bg-[#FC5931] hover:bg-[#D42F1D] text-white font-bold rounded-xl transition-colors disabled:opacity-50 shadow-lg shadow-[#FC5931]/30"
            >
              {saving ? 'Criando...' : 'Criar Vistoria'}
            </button>
          </form>
        </div>
      </div>
    )
  }

  // ════════════════════════════════════════
  //  VIEW: Edit / Inspection Editor
  // ════════════════════════════════════════
  if (view === 'edit' && activeVistoria) {
    const activeSecao = secoes.find(s => s.id === activeSecaoId)
    const st = STATUS_LABELS[activeVistoria.status] ?? STATUS_LABELS.rascunho

    return (
      <div className="max-w-7xl mx-auto py-4 px-4">
        {/* Top bar */}
        <div className="flex items-center justify-between mb-4">
          <button onClick={() => { setView('list'); setActiveVistoria(null) }} className="flex items-center gap-2 text-gray-500 hover:text-gray-700 text-sm">
            <ArrowLeft size={16} /> Voltar
          </button>
          <div className="flex items-center gap-2">
            <span className={`px-2.5 py-1 rounded-full text-xs font-bold flex items-center gap-1 ${st.color}`}>
              {st.icon} {st.label}
            </span>
            <span className="text-xs text-gray-400">#{activeVistoria.cod_interno}</span>
          </div>
        </div>

        {/* Title and info */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 mb-4">
          <div className="flex items-start justify-between">
            <div>
              <h1 className="text-xl font-bold text-gray-900">{activeVistoria.titulo}</h1>
              <p className="text-sm text-gray-500">{TIPOS_BEM[activeVistoria.tipo_bem]} • {activeVistoria.tipo_vistoria === 'entrada' ? '📥 Entrada' : activeVistoria.tipo_vistoria === 'saida' ? '📤 Saída' : '🔄 Periódica'}</p>
              {activeVistoria.endereco && <p className="text-sm text-gray-400 mt-1">📍 {activeVistoria.endereco}</p>}
            </div>
            <div className="flex gap-2 flex-wrap">
              {activeVistoria.status === 'rascunho' && (
                <button onClick={() => updateVistoriaStatus('em_andamento')}
                  className="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white text-sm font-bold rounded-xl transition-colors">
                  ▶️ Iniciar
                </button>
              )}
              {activeVistoria.status === 'em_andamento' && (
                <button onClick={() => updateVistoriaStatus('concluida')}
                  className="px-4 py-2 bg-green-500 hover:bg-green-600 text-white text-sm font-bold rounded-xl transition-colors">
                  ✅ Concluir
                </button>
              )}
              {activeVistoria.status === 'concluida' && (
                <button onClick={() => setView('signatures')}
                  className="px-4 py-2 bg-purple-500 hover:bg-purple-600 text-white text-sm font-bold rounded-xl transition-colors">
                  <FileSignature size={14} className="inline mr-1" /> Assinaturas
                </button>
              )}
              {/* PDF Download */}
              <button
                onClick={async () => {
                  await generateVistoriaPDF(
                    activeVistoria, secoes, itens, fotos, assinaturas,
                    activeVistoria.plano === 'plus'
                  )
                }}
                className="px-4 py-2 bg-gray-700 hover:bg-gray-800 text-white text-sm font-bold rounded-xl transition-colors flex items-center gap-1.5"
              >
                <FileDown size={14} /> PDF
              </button>
              {/* Share Link */}
              {activeVistoria.link_publico_token && (
                <button
                  onClick={() => {
                    const url = `${window.location.origin}/vistoria/${activeVistoria.link_publico_token}`
                    navigator.clipboard.writeText(url)
                    alert('Link copiado!\n' + url)
                  }}
                  className="px-4 py-2 bg-indigo-500 hover:bg-indigo-600 text-white text-sm font-bold rounded-xl transition-colors flex items-center gap-1.5"
                >
                  <Share2 size={14} /> Compartilhar
                </button>
              )}
              {/* Compare button - if this is a saída with referência */}
              {activeVistoria.vistoria_referencia_id && (
                <button
                  onClick={() => {
                    const refV = vistorias.find(v => v.id === activeVistoria.vistoria_referencia_id)
                    setCompareEntradaId(activeVistoria.vistoria_referencia_id!)
                    setCompareSaidaId(activeVistoria.id)
                    setCompareTitulos([refV?.titulo ?? 'Entrada', activeVistoria.titulo])
                    setView('compare')
                  }}
                  className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white text-sm font-bold rounded-xl transition-colors flex items-center gap-1.5"
                >
                  <GitCompareArrows size={14} /> Comparar
                </button>
              )}
              {/* Create saída from entrada */}
              {activeVistoria.tipo_vistoria === 'entrada' && (activeVistoria.status === 'concluida' || activeVistoria.status === 'assinada') && (
                <button
                  onClick={() => {
                    setFormData({
                      titulo: activeVistoria.titulo.replace('Entrada', 'Saída').replace('entrada', 'saída'),
                      tipo_bem: activeVistoria.tipo_bem,
                      endereco: activeVistoria.endereco ?? '',
                      responsavel_nome: activeVistoria.responsavel_nome ?? '',
                      proprietario_nome: activeVistoria.proprietario_nome ?? '',
                      inquilino_nome: activeVistoria.inquilino_nome ?? '',
                      tipo_vistoria: 'saida',
                      template_id: activeVistoria.template_id ?? '',
                      plano: activeVistoria.plano,
                    })
                    setView('create')
                  }}
                  className="px-4 py-2 bg-orange-500 hover:bg-orange-600 text-white text-sm font-bold rounded-xl transition-colors flex items-center gap-1.5"
                >
                  <ArrowRightLeft size={14} /> Criar Saída
                </button>
              )}
            </div>
          </div>

          {/* Summary bar */}
          <div className="flex gap-4 mt-4 pt-3 border-t border-gray-100 text-sm">
            <span className="text-gray-500">{secoes.length} ambientes</span>
            <span className="text-gray-500">{totalItens} itens</span>
            {problemCount > 0 && <span className="text-red-500 font-bold">⚠️ {problemCount} problema{problemCount !== 1 ? 's' : ''}</span>}
            <span className="text-gray-500">{fotos.length} fotos</span>
          </div>
        </div>

        {/* Editor layout: sidebar + content */}
        <div className="flex gap-4">
          {/* Sidebar: sections */}
          <div className="w-56 flex-shrink-0">
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-3">
              <p className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-3 px-2">Ambientes</p>
              <div className="space-y-1">
                {secoes.map(s => {
                  const secaoItens = itens.filter(i => i.secao_id === s.id)
                  const secaoProblems = secaoItens.filter(i => i.status === 'danificado' || i.status === 'atencao').length
                  return (
                    <button key={s.id}
                      onClick={() => { setActiveSecaoId(s.id); setExpandedItemId(null) }}
                      className={`w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-sm font-medium transition-all ${
                        activeSecaoId === s.id
                          ? 'bg-[#FC5931] text-white shadow-lg shadow-[#FC5931]/20'
                          : 'text-gray-600 hover:bg-gray-50'
                      }`}
                    >
                      <span className="flex items-center gap-2 truncate">
                        <span>{s.icone_emoji}</span> {s.nome}
                      </span>
                      <span className="flex items-center gap-1">
                        {secaoProblems > 0 && (
                          <span className={`w-5 h-5 rounded-full text-[10px] font-bold flex items-center justify-center ${
                            activeSecaoId === s.id ? 'bg-white/30 text-white' : 'bg-red-100 text-red-600'
                          }`}>{secaoProblems}</span>
                        )}
                        <ChevronRight size={14} className="opacity-40" />
                      </span>
                    </button>
                  )
                })}
              </div>

              {/* Add section */}
              <div className="mt-3 pt-3 border-t border-gray-100">
                <div className="flex gap-1">
                  <input type="text" value={newSecaoName} onChange={e => setNewSecaoName(e.target.value)}
                    placeholder="Novo ambiente" onKeyDown={e => e.key === 'Enter' && addSecao()}
                    className="flex-1 px-2 py-1.5 border border-gray-200 rounded-lg text-xs focus:outline-none focus:ring-1 focus:ring-[#FC5931]/30"
                  />
                  <button onClick={addSecao} disabled={!newSecaoName.trim()} title="Adicionar ambiente"
                    className="px-2 py-1.5 bg-[#FC5931] text-white rounded-lg text-xs font-bold disabled:opacity-30">
                    <Plus size={14} />
                  </button>
                </div>
              </div>

              {/* Delete section */}
              {activeSecaoId && (
                <button onClick={() => deleteSecao(activeSecaoId)}
                  className="w-full mt-2 px-3 py-1.5 text-xs text-red-500 hover:bg-red-50 rounded-lg transition-colors flex items-center justify-center gap-1">
                  <Trash2 size={12} /> Remover ambiente
                </button>
              )}
            </div>
          </div>

          {/* Main content: items */}
          <div className="flex-1">
            {activeSecao ? (
              <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-lg font-bold text-gray-900">
                    {activeSecao.icone_emoji} {activeSecao.nome}
                  </h2>
                  <span className="text-xs text-gray-400">{activeItens.length} itens</span>
                </div>

                {/* Items list */}
                <div className="space-y-3">
                  {activeItens.sort((a, b) => a.posicao - b.posicao).map(item => {
                    const itemFotos = fotos.filter(f => f.item_id === item.id)
                    const isExpanded = expandedItemId === item.id
                    const itemSt = ITEM_STATUS[item.status] ?? ITEM_STATUS.ok

                    return (
                      <div key={item.id} className={`border rounded-xl overflow-hidden transition-all ${isExpanded ? 'border-[#FC5931]/30 shadow-md' : 'border-gray-100'}`}>
                        {/* Item header */}
                        <div className="flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-gray-50 transition-colors"
                          onClick={() => setExpandedItemId(isExpanded ? null : item.id)}
                        >
                          <div className="flex items-center gap-3">
                            <span className={`flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-bold border ${itemSt.color}`}>
                              {itemSt.icon} {itemSt.label}
                            </span>
                            <span className="font-medium text-gray-800">{item.nome}</span>
                            {item.observacao && <span className="text-xs text-gray-400">💬</span>}
                            {itemFotos.length > 0 && <span className="text-xs text-gray-400">📷 {itemFotos.length}</span>}
                          </div>
                          <div className="flex items-center gap-1">
                            <button onClick={e => { e.stopPropagation(); deleteItem(item.id) }} title="Excluir item"
                              className="p-1 hover:bg-red-50 rounded text-red-400 hover:text-red-600 transition-colors">
                              <Trash2 size={14} />
                            </button>
                            <ChevronRight size={16} className={`text-gray-300 transition-transform ${isExpanded ? 'rotate-90' : ''}`} />
                          </div>
                        </div>

                        {/* Expanded content */}
                        {isExpanded && (
                          <div className="px-4 pb-4 border-t border-gray-100 bg-gray-50/50">
                            {/* Status buttons */}
                            <div className="flex gap-2 mt-3 mb-4">
                              {Object.entries(ITEM_STATUS).map(([key, def]) => (
                                <button key={key}
                                  onClick={() => updateItemStatus(item.id, key)}
                                  className={`flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold border transition-all ${
                                    item.status === key
                                      ? `${def.color} ring-2 ring-offset-1 ${key === 'ok' ? 'ring-green-300' : key === 'atencao' ? 'ring-yellow-300' : key === 'danificado' ? 'ring-red-300' : 'ring-gray-300'}`
                                      : 'border-gray-200 text-gray-400 hover:bg-gray-100'
                                  }`}
                                >
                                  {def.icon} {def.label}
                                </button>
                              ))}
                            </div>

                            {/* Observation */}
                            <div className="mb-4">
                              <label className="block text-xs font-medium text-gray-600 mb-1">Observação</label>
                              <textarea value={item.observacao ?? ''}
                                onChange={e => setItens(prev => prev.map(i => i.id === item.id ? { ...i, observacao: e.target.value } : i))}
                                onBlur={e => updateItemObs(item.id, e.target.value)}
                                rows={2} placeholder="Descreva a condição, danos encontrados..."
                                className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 resize-none bg-white"
                              />
                            </div>

                            {/* Photos */}
                            <div>
                              <label className="block text-xs font-medium text-gray-600 mb-2">Fotos</label>
                              <div className="flex flex-wrap gap-2">
                                {itemFotos.map(foto => (
                                  <div key={foto.id} className="relative group w-24 h-24 rounded-xl overflow-hidden border border-gray-200">
                                    {/* eslint-disable-next-line @next/next/no-img-element */}
                                    <img src={foto.foto_url} alt="" className="w-full h-full object-cover" />
                                    <button onClick={() => deletePhoto(foto.id)} title="Remover foto"
                                      className="absolute top-1 right-1 p-0.5 bg-red-500 text-white rounded-full opacity-0 group-hover:opacity-100 transition-opacity">
                                      <X size={12} />
                                    </button>
                                  </div>
                                ))}

                                {/* Upload button */}
                                <label className="w-24 h-24 rounded-xl border-2 border-dashed border-gray-200 flex flex-col items-center justify-center cursor-pointer hover:border-[#FC5931]/50 hover:bg-orange-50/50 transition-colors">
                                  <Camera size={20} className="text-gray-300 mb-1" />
                                  <span className="text-[10px] text-gray-400">Adicionar</span>
                                  <input type="file" accept="image/*" multiple className="hidden"
                                    onChange={e => e.target.files && handlePhotoUpload(item.id, e.target.files)}
                                  />
                                </label>
                              </div>
                            </div>
                          </div>
                        )}
                      </div>
                    )
                  })}
                </div>

                {/* Add item */}
                <div className="mt-4 pt-3 border-t border-gray-100">
                  <div className="flex gap-2">
                    <input type="text" value={newItemName} onChange={e => setNewItemName(e.target.value)}
                      placeholder="Novo item (ex: Piso, Porta, Tomadas...)" onKeyDown={e => e.key === 'Enter' && addItem()}
                      className="flex-1 px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                    />
                    <button onClick={addItem} disabled={!newItemName.trim()} title="Adicionar item"
                      className="px-4 py-2 bg-[#FC5931] hover:bg-[#D42F1D] text-white font-bold rounded-xl text-sm disabled:opacity-30 transition-colors">
                      <Plus size={16} />
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-10 text-center text-gray-400">
                <ClipboardCheck size={48} className="mx-auto mb-3 opacity-40" />
                <p>Selecione um ambiente ou adicione um novo</p>
              </div>
            )}
          </div>
        </div>
      </div>
    )
  }

  // ════════════════════════════════════════
  //  VIEW: Signatures
  // ════════════════════════════════════════
  if (view === 'signatures' && activeVistoria) {
    return (
      <div className="max-w-3xl mx-auto py-6 px-4">
        <button onClick={() => setView('edit')} className="flex items-center gap-2 text-gray-500 hover:text-gray-700 mb-6 text-sm">
          <ArrowLeft size={16} /> Voltar ao Editor
        </button>

        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <h2 className="text-xl font-bold text-gray-900 mb-2">✍️ Assinaturas</h2>
          <p className="text-sm text-gray-500 mb-6">Colete as assinaturas dos envolvidos para validar a vistoria.</p>

          {/* Existing signatures */}
          <div className="space-y-3 mb-6">
            {assinaturas.map(sig => (
              <div key={sig.id} className="flex items-center justify-between p-4 bg-gray-50 rounded-xl border border-gray-100">
                <div>
                  <p className="font-medium text-gray-800">{sig.nome}</p>
                  <p className="text-xs text-gray-400 capitalize">{sig.papel}</p>
                </div>
                {sig.assinatura_url ? (
                  <div className="flex items-center gap-2">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={sig.assinatura_url} alt="Assinatura" className="h-12 border rounded" />
                    <span className="text-xs text-green-600 font-bold">✅ Assinado</span>
                  </div>
                ) : (
                  <SignaturePad
                    onSave={async (dataUrl) => {
                      // Upload signature
                      const blob = await (await fetch(dataUrl)).blob()
                      const path = `${condominioId}/${activeVistoria.id}/${sig.id}.png`
                      await supabase.storage.from('vistoria-assinaturas').upload(path, blob, { upsert: true })
                      const { data: urlData } = supabase.storage.from('vistoria-assinaturas').getPublicUrl(path)

                      await supabase.from('vistoria_assinaturas').update({
                        assinatura_url: urlData.publicUrl, assinado_em: new Date().toISOString(),
                      }).eq('id', sig.id)

                      setAssinaturas(prev => prev.map(s => s.id === sig.id ? { ...s, assinatura_url: urlData.publicUrl, assinado_em: new Date().toISOString() } : s))

                      // Check if all signed
                      const allSigned = assinaturas.every(s => s.id === sig.id ? true : !!s.assinatura_url)
                      if (allSigned) updateVistoriaStatus('assinada')
                    }}
                  />
                )}
              </div>
            ))}
          </div>

          {/* Add signature slot */}
          <div className="border-t border-gray-100 pt-4">
            <p className="text-sm font-medium text-gray-700 mb-3">Adicionar assinante</p>
            <div className="flex gap-2">
              {['proprietario', 'inquilino', 'responsavel', 'corretor', 'vistoriador'].filter(p => !assinaturas.find(a => a.papel === p)).map(papel => (
                <button key={papel} onClick={() => {
                  const nome = prompt(`Nome do ${papel}:`)
                  if (nome) addSignatureSlot(nome, papel)
                }}
                  className="px-3 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 text-xs font-medium rounded-xl transition-colors capitalize"
                >
                  + {papel}
                </button>
              ))}
            </div>
          </div>

          {/* Share link */}
          {activeVistoria.link_publico_token && (
            <div className="mt-6 pt-4 border-t border-gray-100">
              <div className="flex items-center gap-3 bg-blue-50 border border-blue-200 rounded-xl p-4">
                <Share2 size={20} className="text-blue-500 flex-shrink-0" />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-blue-800">Link público da vistoria</p>
                  <p className="text-xs text-blue-500 truncate">condomeet.app/vistoria/{activeVistoria.link_publico_token}</p>
                </div>
                <button onClick={() => {
                  navigator.clipboard.writeText(`condomeet.app/vistoria/${activeVistoria.link_publico_token}`)
                  alert('Link copiado!')
                }} className="px-3 py-1.5 bg-blue-500 text-white text-xs font-bold rounded-lg hover:bg-blue-600 transition-colors">
                  Copiar
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    )
  }

  // ════════════════════════════════════════
  //  VIEW: Compare
  // ════════════════════════════════════════
  if (view === 'compare') {
    return (
      <VistoriaCompare
        entradaId={compareEntradaId}
        saidaId={compareSaidaId}
        entradaTitulo={compareTitulos[0]}
        saidaTitulo={compareTitulos[1]}
        onBack={() => setView('list')}
      />
    )
  }

  return null
}

/** ───── Signature Pad Component ───── */
function SignaturePad({ onSave }: { onSave: (dataUrl: string) => Promise<void> }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [isDrawing, setIsDrawing] = useState(false)
  const [hasDrawn, setHasDrawn] = useState(false)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    ctx.fillStyle = '#ffffff'
    ctx.fillRect(0, 0, canvas.width, canvas.height)
    ctx.strokeStyle = '#1a1a1a'
    ctx.lineWidth = 2
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
  }, [])

  function getPos(e: React.MouseEvent | React.TouchEvent) {
    const canvas = canvasRef.current!
    const rect = canvas.getBoundingClientRect()
    if ('touches' in e) {
      return { x: e.touches[0].clientX - rect.left, y: e.touches[0].clientY - rect.top }
    }
    return { x: (e as React.MouseEvent).clientX - rect.left, y: (e as React.MouseEvent).clientY - rect.top }
  }

  function startDraw(e: React.MouseEvent | React.TouchEvent) {
    e.preventDefault()
    setIsDrawing(true)
    setHasDrawn(true)
    const ctx = canvasRef.current!.getContext('2d')!
    const pos = getPos(e)
    ctx.beginPath()
    ctx.moveTo(pos.x, pos.y)
  }

  function draw(e: React.MouseEvent | React.TouchEvent) {
    if (!isDrawing) return
    e.preventDefault()
    const ctx = canvasRef.current!.getContext('2d')!
    const pos = getPos(e)
    ctx.lineTo(pos.x, pos.y)
    ctx.stroke()
  }

  function endDraw() { setIsDrawing(false) }

  function clear() {
    const canvas = canvasRef.current!
    const ctx = canvas.getContext('2d')!
    ctx.fillStyle = '#ffffff'
    ctx.fillRect(0, 0, canvas.width, canvas.height)
    setHasDrawn(false)
  }

  async function save() {
    if (!hasDrawn) return
    setSaving(true)
    const dataUrl = canvasRef.current!.toDataURL('image/png')
    await onSave(dataUrl)
    setSaving(false)
  }

  return (
    <div className="flex flex-col items-center gap-2">
      <canvas ref={canvasRef} width={280} height={120}
        className="border border-gray-300 rounded-xl cursor-crosshair bg-white touch-none"
        onMouseDown={startDraw} onMouseMove={draw} onMouseUp={endDraw} onMouseLeave={endDraw}
        onTouchStart={startDraw} onTouchMove={draw} onTouchEnd={endDraw}
      />
      <div className="flex gap-2">
        <button onClick={clear} className="px-3 py-1 text-xs text-gray-500 hover:bg-gray-100 rounded-lg transition-colors">Limpar</button>
        <button onClick={save} disabled={!hasDrawn || saving}
          className="px-3 py-1 text-xs bg-green-500 text-white font-bold rounded-lg hover:bg-green-600 disabled:opacity-30 transition-colors">
          {saving ? 'Salvando...' : '✅ Confirmar'}
        </button>
      </div>
    </div>
  )
}
