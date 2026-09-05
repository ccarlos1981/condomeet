'use client'

import { useState, useRef, useEffect, useMemo } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  FolderOpen, FolderPlus, FilePlus, Download, Pencil, Trash2,
  Eye, Search, ChevronDown, ChevronRight, X, Upload, Loader2, FileText, Plus,
  ChevronLeft, Calendar, ShieldAlert, CheckCircle2, Clock, Check
} from 'lucide-react'
import { Pasta, Documento } from './types'
import {
  MOTIVOS_OBRIGATORIOS,
  MOTIVOS_MANUTENCAO,
  TipoDocumentoCanonica,
  normalizeTipoDocumento,
  getCategoriaBadge,
} from './constants'

export type { Pasta, Documento }

function formatDate(d: string | null) {
  if (!d) return '—'
  return new Date(d + 'T12:00:00').toLocaleDateString('pt-BR')
}

const DIAS_SEMANA = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb']
const MESES = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro']

// ─── Calendar Picker ──────────────────────────────────────────────────────────

function CalendarPicker({
  value,
  onChange,
  label,
  disabled = false,
}: {
  value: string
  onChange: (v: string) => void
  label: string
  disabled?: boolean
}) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  const parsed = value ? new Date(value + 'T12:00:00') : new Date()
  const [viewYear, setViewYear] = useState(parsed.getFullYear())
  const [viewMonth, setViewMonth] = useState(parsed.getMonth())

  useEffect(() => {
    if (value) {
      const d = new Date(value + 'T12:00:00')
      setViewYear(d.getFullYear())
      setViewMonth(d.getMonth())
    }
  }, [value])

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    if (open) document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [open])

  const firstDay = new Date(viewYear, viewMonth, 1).getDay()
  const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
  const daysInPrev = new Date(viewYear, viewMonth, 0).getDate()

  const today = new Date()
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

  function dayStr(d: number) {
    return `${viewYear}-${String(viewMonth + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`
  }

  function prevMonth() {
    if (viewMonth === 0) { setViewMonth(11); setViewYear(y => y - 1) }
    else setViewMonth(m => m - 1)
  }
  function nextMonth() {
    if (viewMonth === 11) { setViewMonth(0); setViewYear(y => y + 1) }
    else setViewMonth(m => m + 1)
  }

  const cells: { day: number; current: boolean }[] = []
  for (let i = firstDay - 1; i >= 0; i--) cells.push({ day: daysInPrev - i, current: false })
  for (let d = 1; d <= daysInMonth; d++) cells.push({ day: d, current: true })
  const remaining = 7 - (cells.length % 7)
  if (remaining < 7) for (let d = 1; d <= remaining; d++) cells.push({ day: d, current: false })

  const displayValue = value
    ? new Date(value + 'T12:00:00').toLocaleDateString('pt-BR')
    : 'DD/MM/AAAA'

  return (
    <div className="relative" ref={ref}>
      <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">{label}</label>
      <button
        type="button"
        disabled={disabled}
        onClick={() => !disabled && setOpen(!open)}
        className={`w-full border rounded-xl px-3 py-2.5 text-sm text-left flex items-center justify-between transition ${
          disabled
            ? 'bg-gray-100 border-gray-200 text-gray-400 cursor-not-allowed'
            : 'border-gray-200 bg-white hover:border-gray-300 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]'
        }`}
      >
        <span className={value && !disabled ? 'text-gray-800' : 'text-gray-400'}>{displayValue}</span>
        <Calendar size={16} className="text-gray-400" />
      </button>

      {open && !disabled && (
        <div className="absolute z-50 mt-1 bg-white rounded-xl shadow-2xl border border-gray-200 p-3 w-[280px]" style={{ left: '50%', transform: 'translateX(-50%)' }}>
          <div className="flex items-center justify-between mb-2">
            <button type="button" onClick={prevMonth} className="p-1 rounded-lg hover:bg-gray-100 text-gray-500 transition">
              <ChevronLeft size={18} />
            </button>
            <span className="text-sm font-semibold text-gray-700">
              {MESES[viewMonth]} <span className="text-[#FC5931]">{viewYear}</span>
            </span>
            <button type="button" onClick={nextMonth} className="p-1 rounded-lg hover:bg-gray-100 text-gray-500 transition">
              <ChevronRight size={18} />
            </button>
          </div>

          <div className="grid grid-cols-7 text-center text-xs font-semibold text-gray-400 mb-1">
            {DIAS_SEMANA.map(d => <div key={d} className="py-1">{d}</div>)}
          </div>

          <div className="grid grid-cols-7 text-center text-sm">
            {cells.map((cell, i) => {
              const isSelected = cell.current && dayStr(cell.day) === value
              const isToday = cell.current && dayStr(cell.day) === todayStr
              return (
                <button
                  key={i}
                  type="button"
                  disabled={!cell.current}
                  onClick={() => { if (cell.current) { onChange(dayStr(cell.day)); setOpen(false) } }}
                  className={`py-1.5 rounded-lg transition text-sm ${
                    !cell.current
                      ? 'text-gray-300 cursor-default'
                      : isSelected
                        ? 'bg-[#FC5931] text-white font-bold shadow-sm'
                        : isToday
                          ? 'bg-blue-100 text-blue-700 font-semibold'
                          : 'text-gray-700 hover:bg-gray-100 cursor-pointer'
                  }`}
                >
                  {cell.day}
                </button>
              )
            })}
          </div>

          <div className="flex items-center justify-center gap-4 mt-3 pt-2 border-t border-gray-100">
            <button type="button" onClick={() => { onChange(todayStr); setOpen(false) }}
              className="text-xs font-semibold text-blue-600 hover:text-blue-800 flex items-center gap-1 transition">
              ◀ hoje
            </button>
            <button type="button" onClick={() => { onChange(''); setOpen(false) }}
              className="text-xs font-semibold text-red-500 hover:text-red-700 flex items-center gap-1 transition">
              − limpar
            </button>
            <button type="button" onClick={() => setOpen(false)}
              className="text-xs font-semibold text-gray-500 hover:text-gray-700 flex items-center gap-1 transition">
              ✕ fechar
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Modal Criar/Editar Pasta ─────────────────────────────────────────────────

function PastaModal({
  tabelaPastas,
  condoId,
  pasta,
  onClose,
  onSaved,
  titulo = 'Documento',
}: {
  tabelaPastas: string
  condoId: string
  pasta?: Pasta
  onClose: () => void
  onSaved: (p: Pasta) => void
  titulo?: string
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
            <FileText size={18} className="text-[#FC5931]" />
            <h2 className="text-lg font-bold text-gray-900">
              {pasta ? 'Editar Pasta' : `Nome da pasta de ${titulo.toLowerCase()}`}
            </h2>
          </div>
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-gray-100 text-gray-400"><X size={18} /></button>
        </div>
        <div className="space-y-3">
          <input
            value={nome}
            onChange={e => setNome(e.target.value)}
            placeholder="Nome da pasta"
            className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
          />
          <textarea
            value={obs}
            onChange={e => setObs(e.target.value)}
            placeholder="Observação sobre a pasta"
            rows={3}
            className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
          />
        </div>
        <div className="flex gap-3 mt-5">
          <button
            onClick={handleSave}
            disabled={saving || !nome.trim()}
            className="flex-1 bg-[#FC5931] text-white rounded-xl py-2.5 text-sm font-semibold hover:bg-[#D42F1D] transition disabled:opacity-40"
          >
            {saving ? 'Salvando...' : pasta ? 'Salvar' : 'Criar Pasta'}
          </button>
          <button onClick={onClose} className="flex-1 border border-[#FC5931] text-[#FC5931] rounded-xl py-2.5 text-sm font-semibold hover:bg-orange-50 transition">
            Cancelar
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── RadioGroup helper ────────────────────────────────────────────────────────

function RadioGroup({ label, value, onChange, disabled = false }: { label: string; value: boolean; onChange: (v: boolean) => void; disabled?: boolean }) {
  return (
    <div className={`flex items-center justify-between py-1.5 border-b border-gray-50 ${disabled ? 'opacity-40' : ''}`}>
      <span className="text-sm text-gray-700">{label}</span>
      <div className="flex gap-4">
        <label className={`flex items-center gap-1.5 text-sm ${disabled ? 'cursor-not-allowed' : 'cursor-pointer'}`}>
          <input
            type="radio"
            checked={value}
            disabled={disabled}
            onChange={() => !disabled && onChange(true)}
            className="accent-[#FC5931]"
          /> sim
        </label>
        <label className={`flex items-center gap-1.5 text-sm ${disabled ? 'cursor-not-allowed' : 'cursor-pointer'}`}>
          <input
            type="radio"
            checked={!value}
            disabled={disabled}
            onChange={() => !disabled && onChange(false)}
            className="accent-[#FC5931]"
          /> não
        </label>
      </div>
    </div>
  )
}

// ─── Form Inserir/Editar Documento ────────────────────────────────────────────

function DocumentoForm({
  tabelaDocs,
  storageBucket,
  condoId,
  pastas,
  doc,
  onClose,
  onSaved,
  tituloLabel = 'Documento',
}: {
  tabelaDocs: string
  storageBucket: string
  condoId: string
  pastas: Pasta[]
  doc?: Documento
  onClose: () => void
  onSaved: (d: Documento) => void
  tituloLabel?: string
}) {
  // 1. Categoria (Radio Button)
  const [tipo, setTipo] = useState<TipoDocumentoCanonica>(() => normalizeTipoDocumento(doc?.tipo))

  // 2. Motivo (armazenado na coluna categoria)
  const [motivo, setMotivo] = useState(doc?.categoria ?? '')
  const [customMotivoInput, setCustomMotivoInput] = useState(
    doc?.tipo === 'outros' || doc?.tipo === 'outros_documentos' ? (doc?.categoria ?? '') : ''
  )

  // 3. Título & Pasta
  const [titulo, setTitulo] = useState(doc?.titulo ?? '')
  const [pastaId, setPastaId] = useState(doc?.pasta_id ?? '')
  const [dataExp, setDataExp] = useState(doc?.data_expedicao ?? new Date().toISOString().slice(0, 10))

  // 4. Validade & Sem Validade
  const [semValidade, setSemValidade] = useState(doc?.sem_validade ?? false)
  const [dataVal, setDataVal] = useState<string>(() => {
    if (doc?.sem_validade) return ''
    if (doc?.data_validade) return doc.data_validade
    const d = new Date()
    d.setFullYear(d.getFullYear() + 1)
    return d.toISOString().slice(0, 10)
  })

  // 5. Lembretes e Notificações
  const [lembrar30, setLembrar30] = useState(doc?.sem_validade ? false : (doc?.lembrar_30 ?? false))
  const [lembrar60, setLembrar60] = useState(doc?.sem_validade ? false : (doc?.lembrar_60 ?? false))
  const [lembrar90, setLembrar90] = useState(doc?.sem_validade ? false : (doc?.lembrar_90 ?? false))
  const [avisarMoradores, setAvisarMoradores] = useState(doc?.avisar_moradores ?? false)
  const [mostrarMoradores, setMostrarMoradores] = useState(doc?.mostrar_moradores ?? false)
  const [descricao, setDescricao] = useState(doc?.descricao ?? '')

  // 6. Arquivo
  const [arquivo, setArquivo] = useState<File | null>(null)
  const [arquivoNomeAtual] = useState(doc?.arquivo_nome ?? '')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const fileRef = useRef<HTMLInputElement>(null)

  // Handler de troca de Categoria
  function handleSelectCategoria(newTipo: TipoDocumentoCanonica) {
    if (newTipo === tipo) return
    setTipo(newTipo)

    // Regra: "Ao alterar a Categoria durante a edição, limpar o Motivo anterior caso ele não pertença à nova categoria."
    if (newTipo === 'obrigatorio') {
      const match = (MOTIVOS_OBRIGATORIOS as readonly string[]).includes(motivo)
      if (!match) setMotivo('')
    } else if (newTipo === 'manutencao') {
      const match = (MOTIVOS_MANUTENCAO as readonly string[]).includes(motivo)
      if (!match) setMotivo('')
    } else if (newTipo === 'outros') {
      setMotivo(customMotivoInput)
    }
  }

  // Handler de alteração do toggle sem_validade
  function handleToggleSemValidade(checked: boolean) {
    setSemValidade(checked)
    if (checked) {
      setDataVal('')
      setLembrar30(false)
      setLembrar60(false)
      setLembrar90(false)
    } else {
      const d = new Date()
      d.setFullYear(d.getFullYear() + 1)
      setDataVal(d.toISOString().slice(0, 10))
    }
  }

  async function handleSave() {
    if (!titulo.trim()) {
      setError(`Informe o título do ${tituloLabel.toLowerCase()}.`)
      return
    }

    const finalMotivo = tipo === 'outros' ? customMotivoInput.trim() : motivo.trim()
    if (!finalMotivo) {
      setError('Informe o motivo do documento.')
      return
    }

    setSaving(true)
    setError('')
    const supabase = createClient()
    let arquivo_url = doc?.arquivo_url ?? null
    let arquivo_nome = doc?.arquivo_nome ?? null

    if (arquivo) {
      const ext = arquivo.name.split('.').pop()
      const path = `${condoId}/${Date.now()}.${ext}`
      const { error: upErr } = await supabase.storage.from(storageBucket).upload(path, arquivo, { upsert: true })
      if (upErr) {
        setError(`Erro ao fazer upload: ${upErr.message}`)
        setSaving(false)
        return
      }
      const { data: urlData } = supabase.storage.from(storageBucket).getPublicUrl(path)
      arquivo_url = urlData.publicUrl
      arquivo_nome = arquivo.name
    }

    const payload: Record<string, unknown> = {
      condominio_id: condoId,
      pasta_id: pastaId || null,
      titulo: titulo.trim(),
      categoria: finalMotivo || null,
      tipo: tipo,
      // Para novos documentos: tipo_id = null. Para documentos existentes: preservar o existente.
      tipo_id: doc?.tipo_id ?? null,
      arquivo_url,
      arquivo_nome,
      data_expedicao: dataExp || null,
      data_validade: semValidade ? null : (dataVal || null),
      sem_validade: semValidade,
      lembrar_30: semValidade ? false : lembrar30,
      lembrar_60: semValidade ? false : lembrar60,
      lembrar_90: semValidade ? false : lembrar90,
      avisar_moradores: avisarMoradores,
      mostrar_moradores: mostrarMoradores,
      descricao: descricao.trim() || null,
      updated_at: new Date().toISOString(),
    }

    if (doc) {
      const { data: d, error: e } = await supabase.from(tabelaDocs).update(payload).eq('id', doc.id).select().single()
      if (e || !d) {
        setError(`Erro ao salvar: ${e?.message ?? 'resposta vazia'}`)
        setSaving(false)
        return
      }
      onSaved(d as Documento)
    } else {
      const { data: d, error: e } = await supabase.from(tabelaDocs).insert(payload).select().single()
      if (e || !d) {
        setError(`Erro ao inserir: ${e?.message ?? 'resposta vazia'}`)
        setSaving(false)
        return
      }
      onSaved(d as Documento)
    }

    setSaving(false)
    onClose()
  }

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 max-w-2xl mx-auto">
      <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
        <h2 className="text-lg font-bold text-gray-900">
          {doc ? `Editar ${tituloLabel}` : `Novo ${tituloLabel}`}
        </h2>
        <button onClick={onClose} className="p-1.5 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
      </div>

      <div className="px-6 py-5 space-y-5">
        {/* ── 1. Categoria (Radio Button) ── */}
        <div>
          <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-2">
            Categoria do Documento *
          </label>
          <div className="grid grid-cols-3 gap-3">
            {[
              { id: 'obrigatorio' as const, label: 'Obrigatório', badge: 'bg-blue-50 text-blue-700 border-blue-200' },
              { id: 'manutencao' as const, label: 'Manutenção', badge: 'bg-amber-50 text-amber-700 border-amber-200' },
              { id: 'outros' as const, label: 'Outros', badge: 'bg-purple-50 text-purple-700 border-purple-200' },
            ].map(cat => {
              const isSelected = tipo === cat.id
              return (
                <button
                  key={cat.id}
                  type="button"
                  onClick={() => handleSelectCategoria(cat.id)}
                  className={`flex items-center justify-between p-3.5 rounded-xl border-2 text-left transition ${
                    isSelected
                      ? 'border-[#FC5931] bg-orange-50/50 shadow-xs'
                      : 'border-gray-200 bg-white hover:border-gray-300'
                  }`}
                >
                  <div className="flex items-center gap-2.5">
                    <div className={`w-4 h-4 rounded-full border flex items-center justify-center ${
                      isSelected ? 'border-[#FC5931] bg-[#FC5931]' : 'border-gray-300 bg-white'
                    }`}>
                      {isSelected && <div className="w-1.5 h-1.5 rounded-full bg-white" />}
                    </div>
                    <span className={`text-sm font-semibold ${isSelected ? 'text-[#FC5931]' : 'text-gray-700'}`}>
                      {cat.label}
                    </span>
                  </div>
                </button>
              )
            })}
          </div>
        </div>

        {/* ── 2. Motivo do Documento (Dinâmico) ── */}
        <div>
          <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">
            Motivo do Documento *
          </label>

          {tipo === 'obrigatorio' && (
            <select
              value={motivo}
              onChange={e => setMotivo(e.target.value)}
              className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
            >
              <option value="">Selecione o motivo obrigatório</option>
              {MOTIVOS_OBRIGATORIOS.map(m => (
                <option key={m} value={m}>{m}</option>
              ))}
            </select>
          )}

          {tipo === 'manutencao' && (
            <select
              value={motivo}
              onChange={e => setMotivo(e.target.value)}
              className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
            >
              <option value="">Selecione o motivo de manutenção</option>
              {MOTIVOS_MANUTENCAO.map(m => (
                <option key={m} value={m}>{m}</option>
              ))}
            </select>
          )}

          {tipo === 'outros' && (
            <div>
              <input
                type="text"
                value={customMotivoInput}
                onChange={e => {
                  setCustomMotivoInput(e.target.value)
                  setMotivo(e.target.value)
                }}
                placeholder="Informe o motivo livremente (ex: Seguro da academia, Comunicado piscina...)"
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
              />
            </div>
          )}
        </div>

        {/* ── 3. Título ── */}
        <div>
          <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">
            Título do {tituloLabel.toLowerCase()} <span className="text-red-500">*</span>
          </label>
          <input
            value={titulo}
            onChange={e => setTitulo(e.target.value)}
            placeholder="Ex: Balancete de Março, AVCB 2026, Laudo Bombeiros..."
            className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
          />
        </div>

        {/* ── 4. Pasta de Armazenamento ── */}
        <div>
          <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">
            Pasta de {tituloLabel.toLowerCase()} (Opcional)
          </label>
          <select
            value={pastaId}
            onChange={e => setPastaId(e.target.value)}
            className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
          >
            <option value="">Escolha Pasta (Opcional)</option>
            {pastas.map(p => <option key={p.id} value={p.id}>{p.nome}</option>)}
          </select>
        </div>

        {/* ── 5. Arquivo / Anexo ── */}
        <div>
          <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">
            Arquivo do {tituloLabel}
          </label>
          <input
            ref={fileRef}
            type="file"
            accept=".pdf,.doc,.docx,.xls,.xlsx,.jpg,.jpeg,.png"
            className="hidden"
            onChange={e => setArquivo(e.target.files?.[0] ?? null)}
          />
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            className="w-full border-2 border-dashed border-gray-200 rounded-xl px-4 py-3 text-sm text-gray-400 hover:border-[#FC5931] hover:text-[#FC5931] transition flex items-center gap-2 justify-center"
          >
            <Upload size={16} />
            {arquivo ? arquivo.name : arquivoNomeAtual || `Clique para importar o arquivo de ${tituloLabel.toLowerCase()}`}
          </button>
        </div>

        {/* ── 6. Datas e Sem Validade ── */}
        <div className="space-y-2">
          <div className="grid grid-cols-2 gap-4">
            <CalendarPicker label="Data Emissão" value={dataExp} onChange={setDataExp} />
            <div>
              <CalendarPicker
                label="Data Validade"
                value={dataVal}
                onChange={setDataVal}
                disabled={semValidade}
              />
            </div>
          </div>

          <div className="flex items-center gap-2 pt-1">
            <label className="flex items-center gap-2 text-xs font-medium text-gray-700 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={semValidade}
                onChange={e => handleToggleSemValidade(e.target.checked)}
                className="w-4 h-4 rounded border-gray-300 text-[#FC5931] focus:ring-[#FC5931] accent-[#FC5931]"
              />
              <span>Documento sem validade (permanente / indeterminado)</span>
            </label>
          </div>
        </div>

        {/* ── 7. Lembretes e Notificações ── */}
        <div className="bg-gray-50 rounded-xl p-4 space-y-0.5 border border-gray-100">
          <div className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">
            Configurações de Notificação e Lembretes
          </div>
          <RadioGroup
            label="Lembrar com 30 dias de vencer:"
            value={lembrar30}
            onChange={setLembrar30}
            disabled={semValidade}
          />
          <RadioGroup
            label="Lembrar com 60 dias de vencer:"
            value={lembrar60}
            onChange={setLembrar60}
            disabled={semValidade}
          />
          <RadioGroup
            label="Lembrar com 90 dias de vencer:"
            value={lembrar90}
            onChange={setLembrar90}
            disabled={semValidade}
          />
          <RadioGroup
            label="Avisar todos moradores (Push na publicação)?"
            value={avisarMoradores}
            onChange={setAvisarMoradores}
          />
          <RadioGroup
            label="Mostrar aos moradores (Portal/App)?"
            value={mostrarMoradores}
            onChange={setMostrarMoradores}
          />
        </div>

        {/* ── 8. Descrição ── */}
        <div>
          <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Descrição (Opcional)</label>
          <textarea
            value={descricao}
            onChange={e => setDescricao(e.target.value)}
            placeholder="Escreva aqui observações, notas ou detalhes sobre este documento"
            rows={3}
            className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
          />
        </div>

        {error && <p className="text-red-500 text-sm bg-red-50 px-4 py-2 rounded-xl">{error}</p>}

        <div className="flex gap-3 pt-2">
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex items-center gap-2 bg-[#FC5931] text-white px-6 py-2.5 rounded-xl text-sm font-semibold hover:bg-[#D42F1D] transition disabled:opacity-40"
          >
            {saving ? <Loader2 size={16} className="animate-spin" /> : null}
            {saving ? 'Salvando...' : doc ? 'Salvar Alterações' : `Inserir ${tituloLabel}`}
          </button>
          <button
            onClick={onClose}
            className="border border-[#FC5931] text-[#FC5931] px-6 py-2.5 rounded-xl text-sm font-semibold hover:bg-orange-50 transition"
          >
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
  initialCategorias?: string[]
  initialTipos?: unknown[]
  initialPrioridades?: unknown[]
}) {
  const [pastas, setPastas] = useState<Pasta[]>(initialPastas)
  const [docs, setDocs] = useState<Documento[]>(initialDocs)

  const [expandedPasta, setExpandedPasta] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [filterTipo, setFilterTipo] = useState<string>('')
  const [filterValidade, setFilterValidade] = useState<'todas' | 'vigente' | 'vencer' | 'vencido' | 'sem_validade'>('todas')

  const [showPastaModal, setShowPastaModal] = useState(false)
  const [editPasta, setEditPasta] = useState<Pasta | undefined>()
  const [showDocForm, setShowDocForm] = useState(false)
  const [editDoc, setEditDoc] = useState<Documento | undefined>()

  const [deletingPasta, setDeletingPasta] = useState<string | null>(null)
  const [deletingDoc, setDeletingDoc] = useState<string | null>(null)

  const supabase = createClient()

  // Helper para verificar status de validade
  function getValidadeStatus(doc: Documento) {
    if (doc.sem_validade || !doc.data_validade) return 'sem_validade'
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const val = new Date(doc.data_validade + 'T12:00:00')
    const diffDays = Math.ceil((val.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))

    if (diffDays < 0) return 'vencido'
    if (diffDays <= 30) return 'vencer'
    return 'vigente'
  }

  function docsInPasta(pastaId: string) {
    return docs.filter(d => d.pasta_id === pastaId)
  }

  function filteredDocs(pastaId: string) {
    return docsInPasta(pastaId).filter(d => {
      const matchSearch = !search ||
        d.titulo.toLowerCase().includes(search.toLowerCase()) ||
        (d.categoria && d.categoria.toLowerCase().includes(search.toLowerCase())) ||
        (d.descricao && d.descricao.toLowerCase().includes(search.toLowerCase())) ||
        (d.arquivo_nome && d.arquivo_nome.toLowerCase().includes(search.toLowerCase()))

      const docTipoNorm = normalizeTipoDocumento(d.tipo)
      const matchTipo = !filterTipo || docTipoNorm === filterTipo

      const status = getValidadeStatus(d)
      const matchValidade =
        filterValidade === 'todas' ||
        (filterValidade === 'vigente' && status === 'vigente') ||
        (filterValidade === 'vencer' && status === 'vencer') ||
        (filterValidade === 'vencido' && status === 'vencido') ||
        (filterValidade === 'sem_validade' && status === 'sem_validade')

      return matchSearch && matchTipo && matchValidade
    })
  }

  async function deletePasta(id: string) {
    if (!confirm(`Deletar pasta? Os ${titulo.toLowerCase()}s dentro serão desvinculados.`)) return
    setDeletingPasta(id)
    await supabase.from(tabelaPastas).delete().eq('id', id)
    setPastas(prev => prev.filter(p => p.id !== id))
    setDeletingPasta(null)
  }

  async function deleteDoc(id: string) {
    if (!confirm(`Deletar ${titulo.toLowerCase()}?`)) return
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
          storageBucket={storageBucket}
          condoId={condoId}
          pastas={pastas}
          doc={editDoc}
          tituloLabel={titulo}
          onClose={() => { setShowDocForm(false); setEditDoc(undefined) }}
          onSaved={d => {
            setDocs(prev => editDoc ? prev.map(x => x.id === d.id ? d : x) : [d, ...prev])
            if (d.pasta_id) setExpandedPasta(d.pasta_id)
          }}
        />
      </div>
    )
  }

  return (
    <div className="p-6 space-y-6">
      {/* Header Actions & Filters */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-3">
        <div className="flex items-center gap-2.5 flex-wrap">
          <button
            onClick={() => { setEditDoc(undefined); setShowDocForm(true) }}
            className="flex items-center gap-2 bg-[#FC5931] hover:bg-[#D42F1D] text-white px-4 py-2.5 rounded-xl text-sm font-semibold shadow-xs transition"
          >
            <FilePlus size={16} />
            Novo {titulo}
          </button>
          <button
            onClick={() => { setEditPasta(undefined); setShowPastaModal(true) }}
            className="flex items-center gap-2 bg-white border border-gray-200 hover:border-[#FC5931] text-gray-700 hover:text-[#FC5931] px-4 py-2.5 rounded-xl text-sm font-semibold shadow-xs transition"
          >
            <FolderPlus size={16} className="text-[#FC5931]" />
            Criar pasta
          </button>
        </div>

        {/* Search & Filters */}
        <div className="flex items-center gap-2 flex-wrap w-full md:w-auto">
          <div className="relative flex-1 md:w-56">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Buscar por título ou motivo..."
              className="w-full pl-8 pr-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-white"
            />
          </div>

          <select
            value={filterTipo}
            onChange={e => setFilterTipo(e.target.value)}
            className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
          >
            <option value="">Todas as Categorias</option>
            <option value="obrigatorio">Obrigatórios</option>
            <option value="manutencao">Manutenções</option>
            <option value="outros">Outros</option>
          </select>

          <select
            value={filterValidade}
            onChange={e => setFilterValidade(e.target.value as typeof filterValidade)}
            className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
          >
            <option value="todas">Todas Validades</option>
            <option value="vigente">Vigentes</option>
            <option value="vencer">A Vencer (≤30d)</option>
            <option value="vencido">Vencidos</option>
            <option value="sem_validade">Sem Validade</option>
          </select>
        </div>
      </div>

      {/* Pastas Grid */}
      {pastas.length === 0 ? (
        <div className="text-center py-20 text-gray-400 bg-white rounded-2xl border border-gray-100 p-8">
          <FolderPlus size={40} className="mx-auto mb-3 opacity-30 text-[#FC5931]" />
          <p className="font-medium text-gray-700">Nenhuma pasta criada</p>
          <p className="text-sm text-gray-400 mt-1">{`Clique em "Criar pasta" para organizar seus ${titulo.toLowerCase()}s`}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {pastas.map(pasta => {
            const expanded = expandedPasta === pasta.id
            const docsDaPasta = filteredDocs(pasta.id)
            const totalDaPasta = docsInPasta(pasta.id).length

            return (
              <div
                key={pasta.id}
                className={`bg-white rounded-2xl shadow-xs border border-gray-100 overflow-hidden transition ${
                  expanded ? 'col-span-1 md:col-span-2' : ''
                }`}
              >
                {/* Pasta header */}
                <div className="flex items-center gap-3 px-5 py-4">
                  <button
                    onClick={() => setExpandedPasta(expanded ? null : pasta.id)}
                    className="flex items-center gap-2 flex-1 text-left"
                  >
                    {expanded ? <ChevronDown size={16} className="text-gray-400" /> : <ChevronRight size={16} className="text-gray-400" />}
                    <FolderOpen size={20} className="text-[#FC5931]" />
                    <span className="font-semibold text-gray-800">{pasta.nome}</span>
                    {!expanded && (
                      <span className="text-xs text-gray-400 ml-1">
                        ({totalDaPasta} {totalDaPasta === 1 ? 'doc' : 'docs'})
                      </span>
                    )}
                  </button>
                  <div className="flex items-center gap-1.5 text-gray-400">
                    <button
                      onClick={() => { setEditPasta(pasta); setShowPastaModal(true) }}
                      className="p-1.5 rounded-lg hover:bg-orange-50 hover:text-[#FC5931] transition"
                    >
                      <Pencil size={14} />
                    </button>
                    <button
                      onClick={() => deletePasta(pasta.id)}
                      disabled={deletingPasta === pasta.id}
                      className="p-1.5 rounded-lg hover:bg-red-50 hover:text-red-500 transition"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>

                {/* Expanded: table */}
                {expanded && (
                  <div className="border-t border-gray-100 overflow-x-auto">
                    {docsDaPasta.length === 0 ? (
                      <p className="text-center py-8 text-sm text-gray-400">
                        {`Nenhum ${titulo.toLowerCase()} encontrado nesta pasta com os filtros selecionados`}
                      </p>
                    ) : (
                      <table className="w-full text-sm">
                        <thead>
                          <tr className="bg-gray-50 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                            <th className="px-5 py-3 text-left">{`Nome do ${titulo.toLowerCase()}`}</th>
                            <th className="px-3 py-3 text-left">Categoria</th>
                            <th className="px-3 py-3 text-left">Motivo</th>
                            <th className="px-3 py-3 text-left">Vigência</th>
                            <th className="px-3 py-3 text-left">Última modificação</th>
                            <th className="px-3 py-3"></th>
                          </tr>
                        </thead>
                        <tbody>
                          {docsDaPasta.map(doc => {
                            const badge = getCategoriaBadge(doc.tipo)
                            const valStatus = getValidadeStatus(doc)

                            return (
                              <tr key={doc.id} className="border-t border-gray-50 hover:bg-gray-50/50 transition">
                                <td className="px-5 py-3 font-medium text-gray-800 flex items-center gap-2">
                                  <FileText size={15} className="text-[#FC5931] flex-shrink-0" />
                                  <div className="min-w-0">
                                    <div className="truncate font-semibold">{doc.titulo}</div>
                                    {doc.arquivo_nome && (
                                      <div className="text-[11px] text-gray-400 truncate">{doc.arquivo_nome}</div>
                                    )}
                                  </div>
                                </td>

                                {/* Coluna Categoria (Badge) */}
                                <td className="px-3 py-3">
                                  <span className={`inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-semibold border ${badge.bg} ${badge.text} ${badge.border}`}>
                                    {badge.label}
                                  </span>
                                </td>

                                {/* Coluna Motivo */}
                                <td className="px-3 py-3 text-gray-700 font-medium">
                                  {doc.categoria ?? '—'}
                                </td>

                                {/* Validade com Badge */}
                                <td className="px-3 py-3">
                                  {doc.sem_validade ? (
                                    <span className="inline-flex items-center gap-1 text-xs text-gray-500 bg-gray-100 px-2 py-0.5 rounded">
                                      <CheckCircle2 size={12} className="text-gray-400" />
                                      Sem validade
                                    </span>
                                  ) : doc.data_validade ? (
                                    <div className="flex items-center gap-1.5">
                                      {valStatus === 'vencido' && (
                                        <span className="inline-flex items-center gap-1 text-xs text-red-700 bg-red-50 px-2 py-0.5 rounded font-medium">
                                          <ShieldAlert size={12} />
                                          Venceu ({formatDate(doc.data_validade)})
                                        </span>
                                      )}
                                      {valStatus === 'vencer' && (
                                        <span className="inline-flex items-center gap-1 text-xs text-amber-700 bg-amber-50 px-2 py-0.5 rounded font-medium">
                                          <Clock size={12} />
                                          Vence em breve ({formatDate(doc.data_validade)})
                                        </span>
                                      )}
                                      {valStatus === 'vigente' && (
                                        <span className="text-xs text-gray-600">
                                          {formatDate(doc.data_validade)}
                                        </span>
                                      )}
                                    </div>
                                  ) : (
                                    <span className="text-xs text-gray-400">Não informada</span>
                                  )}
                                </td>

                                <td className="px-3 py-3 text-gray-500 text-xs">{formatDate(doc.updated_at)}</td>

                                <td className="px-3 py-3 text-right">
                                  <div className="flex items-center justify-end gap-1">
                                    {/* Download */}
                                    {doc.arquivo_url ? (
                                      <a
                                        href={doc.arquivo_url}
                                        download={doc.arquivo_nome ?? doc.titulo}
                                        title="Baixar arquivo"
                                        className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC5931] hover:bg-orange-50 transition"
                                      >
                                        <Download size={14} />
                                      </a>
                                    ) : (
                                      <span title="Sem arquivo" className="p-1.5 rounded-lg text-gray-200 cursor-not-allowed">
                                        <Download size={14} />
                                      </span>
                                    )}
                                    {/* Editar */}
                                    <button
                                      onClick={() => { setEditDoc(doc); setShowDocForm(true) }}
                                      title="Editar"
                                      className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC5931] hover:bg-orange-50 transition"
                                    >
                                      <Pencil size={14} />
                                    </button>
                                    {/* Deletar */}
                                    <button
                                      onClick={() => deleteDoc(doc.id)}
                                      disabled={deletingDoc === doc.id}
                                      title="Excluir"
                                      className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition"
                                    >
                                      <Trash2 size={14} />
                                    </button>
                                    {/* Visualizar */}
                                    {doc.arquivo_url ? (
                                      <a
                                        href={doc.arquivo_url}
                                        target="_blank"
                                        rel="noreferrer"
                                        title="Visualizar arquivo"
                                        className="p-1.5 rounded-lg text-gray-400 hover:text-blue-500 hover:bg-blue-50 transition"
                                      >
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
                            )
                          })}
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
    </div>
  )
}
