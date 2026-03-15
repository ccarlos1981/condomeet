'use client'

import { useState, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  FolderOpen, FolderPlus, FilePlus, Download, Pencil, Trash2,
  Eye, Search, ChevronDown, ChevronRight, X, Upload, Loader2, FileText
} from 'lucide-react'

// ─── Types ───────────────────────────────────────────────────────────────────

export type Pasta = {
  id: string
  nome: string
  observacao: string | null
  created_at: string
}

export type Documento = {
  id: string
  pasta_id: string | null
  titulo: string
  categoria: string | null
  tipo: string
  arquivo_url: string | null
  arquivo_nome: string | null
  data_expedicao: string | null
  data_validade: string | null
  lembrar_30: boolean
  lembrar_60: boolean
  lembrar_90: boolean
  avisar_moradores: boolean
  mostrar_moradores: boolean
  descricao: string | null
  updated_at: string
}

const CATEGORIAS = ['Atas', 'Gerador', 'Bombeiro', 'Elevador', 'Financeiro', 'Jurídico', 'Outros']
const TIPOS = [
  { value: 'obrigatorio', label: 'Obrigatório' },
  { value: 'manutencao',  label: 'Manutenção' },
  { value: 'outros',      label: 'Outros' },
]

function formatDate(d: string | null) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('pt-BR')
}

// ─── Modal Criar/Editar Pasta ─────────────────────────────────────────────────

function PastaModal({
  tabelaPastas,
  condoId,
  pasta,
  onClose,
  onSaved,
}: {
  tabelaPastas: string
  condoId: string
  pasta?: Pasta
  onClose: () => void
  onSaved: (p: Pasta) => void
}) {
  const [nome, setNome] = useState(pasta?.nome ?? '')
  const [obs, setObs] = useState(pasta?.observacao ?? '')
  const [saving, setSaving] = useState(false)

  async function handleSave() {
    if (!nome.trim()) return
    setSaving(true)
    const supabase = createClient()
    if (pasta) {
      const { data } = await supabase.from(tabelaPastas).update({ nome: nome.trim(), observacao: obs.trim() || null }).eq('id', pasta.id).select().single()
      if (data) onSaved(data as Pasta)
    } else {
      const { data } = await supabase.from(tabelaPastas).insert({ condominio_id: condoId, nome: nome.trim(), observacao: obs.trim() || null }).select().single()
      if (data) onSaved(data as Pasta)
    }
    setSaving(false)
    onClose()
  }

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6">
        <div className="flex items-center justify-between mb-5">
          <div className="flex items-center gap-2">
            <FileText size={18} className="text-[#FC3951]" />
            <h2 className="text-lg font-bold text-gray-900">
              {pasta ? 'Editar Pasta' : 'Nome da pasta de documento'}
            </h2>
          </div>
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-gray-100 text-gray-400"><X size={18} /></button>
        </div>
        <div className="space-y-3">
          <input
            value={nome}
            onChange={e => setNome(e.target.value)}
            placeholder="Nome da pasta"
            className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951]"
          />
          <textarea
            value={obs}
            onChange={e => setObs(e.target.value)}
            placeholder="Observação sobre a pasta"
            rows={3}
            className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951]"
          />
        </div>
        <div className="flex gap-3 mt-5">
          <button
            onClick={handleSave}
            disabled={saving || !nome.trim()}
            className="flex-1 bg-[#FC3951] text-white rounded-xl py-2.5 text-sm font-semibold hover:bg-[#D4253D] transition disabled:opacity-40"
          >
            {saving ? 'Salvando...' : pasta ? 'Salvar' : 'Criar Pasta'}
          </button>
          <button onClick={onClose} className="flex-1 border border-[#FC3951] text-[#FC3951] rounded-xl py-2.5 text-sm font-semibold hover:bg-orange-50 transition">
            Cancelar
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── Form Inserir/Editar Documento ────────────────────────────────────────────

function DocumentoForm({
  tabelaDocs,
  tabelaPastas,
  storageBucket,
  condoId,
  pastas,
  doc,
  onClose,
  onSaved,
  tituloLabel = 'Documento',
}: {
  tabelaDocs: string
  tabelaPastas: string
  storageBucket: string
  condoId: string
  pastas: Pasta[]
  doc?: Documento
  onClose: () => void
  onSaved: (d: Documento) => void
  tituloLabel?: string
}) {
  const [tipo, setTipo] = useState(doc?.tipo ?? 'obrigatorio')
  const [titulo, setTitulo] = useState(doc?.titulo ?? '')
  const [categoria, setCategoria] = useState(doc?.categoria ?? '')
  const [pastaId, setPastaId] = useState(doc?.pasta_id ?? '')
  const [dataExp, setDataExp] = useState(doc?.data_expedicao ?? new Date().toISOString().slice(0, 10))
  const [dataVal, setDataVal] = useState(doc?.data_validade ?? new Date(Date.now() + 365 * 86400000).toISOString().slice(0, 10))
  const [lembrar30, setLembrar30] = useState(doc?.lembrar_30 ?? false)
  const [lembrar60, setLembrar60] = useState(doc?.lembrar_60 ?? false)
  const [lembrar90, setLembrar90] = useState(doc?.lembrar_90 ?? false)
  const [avisarMoradores, setAvisarMoradores] = useState(doc?.avisar_moradores ?? false)
  const [mostrarMoradores, setMostrarMoradores] = useState(doc?.mostrar_moradores ?? false)
  const [descricao, setDescricao] = useState(doc?.descricao ?? '')
  const [arquivo, setArquivo] = useState<File | null>(null)
  const [arquivoNomeAtual, setArquivoNomeAtual] = useState(doc?.arquivo_nome ?? '')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const fileRef = useRef<HTMLInputElement>(null)

  async function handleSave() {
    if (!titulo.trim()) { setError(`Informe o título do ${tituloLabel.toLowerCase()}.`); return }
    setSaving(true)
    setError('')
    const supabase = createClient()
    let arquivo_url = doc?.arquivo_url ?? null
    let arquivo_nome = doc?.arquivo_nome ?? null

    if (arquivo) {
      const ext = arquivo.name.split('.').pop()
      const path = `${condoId}/${Date.now()}.${ext}`
      const { error: upErr } = await supabase.storage.from(storageBucket).upload(path, arquivo, { upsert: true })
      if (upErr) { setError(`Erro ao fazer upload: ${upErr.message}`); setSaving(false); return }
      const { data: urlData } = supabase.storage.from(storageBucket).getPublicUrl(path)
      arquivo_url = urlData.publicUrl
      arquivo_nome = arquivo.name
    }

    const payload = {
      condominio_id: condoId,
      pasta_id: pastaId || null,
      titulo: titulo.trim(),
      categoria: categoria || null,
      tipo,
      arquivo_url,
      arquivo_nome,
      data_expedicao: dataExp || null,
      data_validade: dataVal || null,
      lembrar_30: lembrar30,
      lembrar_60: lembrar60,
      lembrar_90: lembrar90,
      avisar_moradores: avisarMoradores,
      mostrar_moradores: mostrarMoradores,
      descricao: descricao.trim() || null,
      updated_at: new Date().toISOString(),
    }

    if (doc) {
      const { data: d, error: e } = await supabase.from(tabelaDocs).update(payload).eq('id', doc.id).select().single()
      if (e || !d) { setError(`Erro ao salvar: ${e?.message ?? 'resposta vazia'}`); setSaving(false); return }
      onSaved(d as Documento)
    } else {
      const { data: d, error: e } = await supabase.from(tabelaDocs).insert(payload).select().single()
      if (e || !d) { setError(`Erro ao inserir: ${e?.message ?? 'resposta vazia'}`); setSaving(false); return }
      onSaved(d as Documento)
    }

    setSaving(false)
    onClose()
  }

  const RadioGroup = ({ label, value, onChange }: { label: string; value: boolean; onChange: (v: boolean) => void }) => (
    <div className="flex items-center justify-between py-1.5 border-b border-gray-50">
      <span className="text-sm text-gray-700">{label}</span>
      <div className="flex gap-4">
        <label className="flex items-center gap-1.5 cursor-pointer text-sm">
          <input type="radio" checked={value} onChange={() => onChange(true)} className="accent-[#FC3951]" /> sim
        </label>
        <label className="flex items-center gap-1.5 cursor-pointer text-sm">
          <input type="radio" checked={!value} onChange={() => onChange(false)} className="accent-[#FC3951]" /> não
        </label>
      </div>
    </div>
  )

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 max-w-2xl mx-auto">
      <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
        <h2 className="text-lg font-bold text-gray-900">
          {doc ? `Editar ${tituloLabel}` : `Inserir ${tituloLabel}`}
        </h2>
        <button onClick={onClose} className="p-1.5 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
      </div>

      <div className="px-6 py-5 space-y-4">
        {/* Tipo */}
        <div>
          <label className="text-sm font-semibold text-gray-700 block mb-2">Tipo de Documento:</label>
          <div className="flex gap-4">
            {TIPOS.map(t => (
              <label key={t.value} className="flex items-center gap-1.5 cursor-pointer text-sm">
                <input type="radio" value={t.value} checked={tipo === t.value} onChange={() => setTipo(t.value)} className="accent-[#FC3951]" />
                {t.label}
              </label>
            ))}
          </div>
        </div>

        {/* Título + Categoria */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Título do documento</label>
            <input value={titulo} onChange={e => setTitulo(e.target.value)} placeholder="Opcional"
              className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951]" />
          </div>
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Categoria do documento</label>
            <select value={categoria} onChange={e => setCategoria(e.target.value)}
              className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951] bg-white">
              <option value="">Selecione</option>
              {CATEGORIAS.map(c => <option key={c} value={c}>{c}</option>)}
            </select>
          </div>
        </div>

        {/* Arquivo */}
        <div>
          <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Arquivo do Documento</label>
          <input ref={fileRef} type="file" accept=".pdf,.doc,.docx,.xls,.xlsx,.jpg,.png" className="hidden"
            onChange={e => setArquivo(e.target.files?.[0] ?? null)} />
          <button onClick={() => fileRef.current?.click()}
            className="w-full border-2 border-dashed border-gray-200 rounded-xl px-4 py-3 text-sm text-gray-400 hover:border-[#FC3951] hover:text-[#FC3951] transition flex items-center gap-2 justify-center">
            <Upload size={16} />
            {arquivo ? arquivo.name : arquivoNomeAtual || 'Clique para importar o Documento'}
          </button>
        </div>

        {/* Pasta */}
        <div>
          <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Pasta de documento</label>
          <select value={pastaId} onChange={e => setPastaId(e.target.value)}
            className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951] bg-white">
            <option value="">Escolha Pasta</option>
            {pastas.map(p => <option key={p.id} value={p.id}>{p.nome}</option>)}
          </select>
        </div>

        {/* Datas */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Data Expedição</label>
            <input type="date" value={dataExp} onChange={e => setDataExp(e.target.value)}
              className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951]" />
          </div>
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Data validade</label>
            <input type="date" value={dataVal} onChange={e => setDataVal(e.target.value)}
              className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951]" />
          </div>
        </div>

        {/* Flags */}
        <div className="bg-gray-50 rounded-xl p-4 space-y-0.5">
          <RadioGroup label="Lembrar com 30 dias de vencer:" value={lembrar30} onChange={setLembrar30} />
          <RadioGroup label="Lembrar com 60 dias de vencer:" value={lembrar60} onChange={setLembrar60} />
          <RadioGroup label="Lembrar com 90 dias de vencer:" value={lembrar90} onChange={setLembrar90} />
          <RadioGroup label="Avisar todos moradores?" value={avisarMoradores} onChange={setAvisarMoradores} />
          <RadioGroup label="Mostrar aos moradores?" value={mostrarMoradores} onChange={setMostrarMoradores} />
        </div>

        {/* Descrição */}
        <div>
          <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Descrição</label>
          <textarea value={descricao} onChange={e => setDescricao(e.target.value)}
            placeholder="Escreva aqui uma descrição" rows={3}
            className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951]" />
        </div>

        {error && <p className="text-red-500 text-sm bg-red-50 px-4 py-2 rounded-xl">{error}</p>}

        <div className="flex gap-3 pt-2">
          <button onClick={handleSave} disabled={saving}
            className="flex items-center gap-2 bg-[#FC3951] text-white px-6 py-2.5 rounded-xl text-sm font-semibold hover:bg-[#D4253D] transition disabled:opacity-40">
            {saving ? <Loader2 size={16} className="animate-spin" /> : null}
            {saving ? 'Salvando...' : doc ? 'Salvar' : `Inserir ${tituloLabel}`}
          </button>
          <button onClick={onClose}
            className="border border-[#FC3951] text-[#FC3951] px-6 py-2.5 rounded-xl text-sm font-semibold hover:bg-orange-50 transition">
            Voltar
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── Main Client Component ────────────────────────────────────────────────────

export default function DocumentosClient({
  initialPastas,
  initialDocs,
  condoId,
  tabelaPastas,
  tabelaDocs,
  storageBucket,
  titulo,
}: {
  initialPastas: Pasta[]
  initialDocs: Documento[]
  condoId: string
  tabelaPastas: string
  tabelaDocs: string
  storageBucket: string
  titulo: string
}) {
  const [pastas, setPastas] = useState<Pasta[]>(initialPastas)
  const [docs, setDocs] = useState<Documento[]>(initialDocs)
  const [expandedPasta, setExpandedPasta] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [filterCat, setFilterCat] = useState('')
  const [showPastaModal, setShowPastaModal] = useState(false)
  const [editPasta, setEditPasta] = useState<Pasta | undefined>()
  const [showDocForm, setShowDocForm] = useState(false)
  const [editDoc, setEditDoc] = useState<Documento | undefined>()
  const [deletingPasta, setDeletingPasta] = useState<string | null>(null)
  const [deletingDoc, setDeletingDoc] = useState<string | null>(null)

  const supabase = createClient()

  function docsInPasta(pastaId: string) {
    return docs.filter(d => d.pasta_id === pastaId)
  }

  function filteredDocs(pastaId: string) {
    return docsInPasta(pastaId).filter(d => {
      const matchSearch = !search || d.titulo.toLowerCase().includes(search.toLowerCase())
      const matchCat = !filterCat || d.categoria === filterCat
      return matchSearch && matchCat
    })
  }

  async function deletePasta(id: string) {
    if (!confirm('Deletar pasta? Os documentos dentro serão desvinculados.')) return
    setDeletingPasta(id)
    await supabase.from(tabelaPastas).delete().eq('id', id)
    setPastas(prev => prev.filter(p => p.id !== id))
    setDeletingDoc(null)
  }

  async function deleteDoc(id: string) {
    if (!confirm('Deletar documento?')) return
    setDeletingDoc(id)
    await supabase.from(tabelaDocs).delete().eq('id', id)
    setDocs(prev => prev.filter(d => d.id !== id))
    setDeletingDoc(null)
  }

  if (showDocForm) {
    return (
      <div className="p-6 max-w-3xl mx-auto">
        <DocumentoForm
          tabelaDocs={tabelaDocs}
          tabelaPastas={tabelaPastas}
          storageBucket={storageBucket}
          condoId={condoId}
          pastas={pastas}
          doc={editDoc}
          tituloLabel={titulo}
          onClose={() => { setShowDocForm(false); setEditDoc(undefined) }}
          onSaved={d => {
            setDocs(prev => editDoc ? prev.map(x => x.id === d.id ? d : x) : [d, ...prev])
            // Expande automaticamente a pasta do documento salvo
            if (d.pasta_id) setExpandedPasta(d.pasta_id)
          }}
        />
      </div>
    )
  }

  return (
    <div className="p-6">
      {/* Header actions */}
      <div className="flex items-center gap-3 mb-6 flex-wrap">
        <button
          onClick={() => { setEditDoc(undefined); setShowDocForm(true) }}
          className="flex items-center gap-2 bg-white border border-gray-200 hover:border-[#FC3951] text-gray-700 hover:text-[#FC3951] px-4 py-2.5 rounded-xl text-sm font-semibold shadow-sm transition"
        >
          <FilePlus size={16} className="text-[#FC3951]" />
          Inserir {titulo}
        </button>
        <button
          onClick={() => { setEditPasta(undefined); setShowPastaModal(true) }}
          className="flex items-center gap-2 bg-white border border-gray-200 hover:border-[#FC3951] text-gray-700 hover:text-[#FC3951] px-4 py-2.5 rounded-xl text-sm font-semibold shadow-sm transition"
        >
          <FolderPlus size={16} className="text-[#FC3951]" />
          Criar pasta
        </button>
        <div className="relative ml-auto">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Buscar..."
            className="pl-8 pr-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951] bg-white" />
        </div>
        <select value={filterCat} onChange={e => setFilterCat(e.target.value)}
          className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951]">
          <option value="">Categoria</option>
          {CATEGORIAS.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
      </div>

      {/* Pastas */}
      {pastas.length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          <FolderPlus size={40} className="mx-auto mb-3 opacity-30" />
          <p className="font-medium text-gray-500">Nenhuma pasta criada</p>
          <p className="text-sm">Clique em "Criar pasta" para organizar seus documentos</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-3">
          {pastas.map(pasta => {
            const expanded = expandedPasta === pasta.id
            const docsDaPasta = filteredDocs(pasta.id)
            const totalDaPasta = docsInPasta(pasta.id).length

            return (
              <div key={pasta.id} className={`bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden ${expanded ? 'col-span-2' : ''}`}>
                {/* Pasta header */}
                <div className="flex items-center gap-3 px-5 py-4">
                  <button
                    onClick={() => setExpandedPasta(expanded ? null : pasta.id)}
                    className="flex items-center gap-2 flex-1 text-left"
                  >
                    {expanded ? <ChevronDown size={16} className="text-gray-400" /> : <ChevronRight size={16} className="text-gray-400" />}
                    <FolderOpen size={20} className="text-[#FC3951]" />
                    <span className="font-semibold text-gray-800">{pasta.nome}</span>
                    {!expanded && (
                      <span className="text-xs text-gray-400 ml-1">
                        ({totalDaPasta} {totalDaPasta === 1 ? 'doc' : 'docs'})
                      </span>
                    )}
                  </button>
                  <div className="flex items-center gap-2 text-gray-400">
                    <button onClick={() => { setEditPasta(pasta); setShowPastaModal(true) }}
                      className="p-1.5 rounded-lg hover:bg-orange-50 hover:text-[#FC3951] transition">
                      <Pencil size={14} />
                    </button>
                    <button onClick={() => deletePasta(pasta.id)}
                      disabled={deletingPasta === pasta.id}
                      className="p-1.5 rounded-lg hover:bg-red-50 hover:text-red-500 transition">
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>

                {/* Expanded: table */}
                {expanded && (
                  <div className="border-t border-gray-50">
                    {docsDaPasta.length === 0 ? (
                      <p className="text-center py-8 text-sm text-gray-400">Nenhum documento nesta pasta</p>
                    ) : (
                      <table className="w-full text-sm">
                        <thead>
                          <tr className="bg-gray-50 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                            <th className="px-5 py-3 text-left">Nome do documento</th>
                            <th className="px-3 py-3 text-left">Pasta</th>
                            <th className="px-3 py-3 text-left">Categoria</th>
                            <th className="px-3 py-3 text-left">Vencimento</th>
                            <th className="px-3 py-3 text-left">Última modificação</th>
                            <th className="px-3 py-3"></th>
                          </tr>
                        </thead>
                        <tbody>
                          {docsDaPasta.map(doc => (
                            <tr key={doc.id} className="border-t border-gray-50 hover:bg-gray-50/50 transition">
                              <td className="px-5 py-3 font-medium text-gray-800 flex items-center gap-2">
                                <FileText size={14} className="text-[#FC3951] flex-shrink-0" />
                                {doc.titulo}
                              </td>
                              <td className="px-3 py-3 text-gray-500">{pasta.nome}</td>
                              <td className="px-3 py-3 text-gray-500">{doc.categoria ?? '—'}</td>
                              <td className="px-3 py-3 text-gray-500">{formatDate(doc.data_validade)}</td>
                              <td className="px-3 py-3 text-gray-500">{formatDate(doc.updated_at)}</td>
                              <td className="px-3 py-3">
                                <div className="flex items-center gap-1">
                                  {/* Download */}
                                  {doc.arquivo_url ? (
                                    <a href={doc.arquivo_url} download={doc.arquivo_nome ?? doc.titulo}
                                      title="Baixar arquivo"
                                      className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC3951] hover:bg-orange-50 transition">
                                      <Download size={14} />
                                    </a>
                                  ) : (
                                    <span title="Sem arquivo" className="p-1.5 rounded-lg text-gray-200 cursor-not-allowed">
                                      <Download size={14} />
                                    </span>
                                  )}
                                  {/* Editar */}
                                  <button onClick={() => { setEditDoc(doc); setShowDocForm(true) }}
                                    title="Editar"
                                    className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC3951] hover:bg-orange-50 transition">
                                    <Pencil size={14} />
                                  </button>
                                  {/* Deletar */}
                                  <button onClick={() => deleteDoc(doc.id)} disabled={deletingDoc === doc.id}
                                    title="Excluir"
                                    className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition">
                                    <Trash2 size={14} />
                                  </button>
                                  {/* Visualizar */}
                                  {doc.arquivo_url ? (
                                    <a href={doc.arquivo_url} target="_blank" rel="noreferrer"
                                      title="Visualizar arquivo"
                                      className="p-1.5 rounded-lg text-gray-400 hover:text-blue-500 hover:bg-blue-50 transition">
                                      <Eye size={14} />
                                    </a>
                                  ) : (
                                    <span title="Sem arquivo" className="p-1.5 rounded-lg text-gray-200 cursor-not-allowed">
                                      <Eye size={14} />
                                    </span>
                                  )}
                                </div>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    )}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}

      {/* Modals */}
      {showPastaModal && (
        <PastaModal
          tabelaPastas={tabelaPastas}
          condoId={condoId}
          pasta={editPasta}
          onClose={() => { setShowPastaModal(false); setEditPasta(undefined) }}
          onSaved={p => {
            setPastas(prev => editPasta ? prev.map(x => x.id === p.id ? p : x) : [...prev, p])
          }}
        />
      )}
    </div>
  )
}
