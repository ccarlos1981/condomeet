'use client'

import { useState, useRef, useEffect, useMemo } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  FolderOpen, FolderPlus, FilePlus, Download, Pencil, Trash2,
  Eye, Search, ChevronDown, ChevronRight, X, Upload, Loader2, FileText, Plus,
  Calendar, CheckCircle2, Clock, AlertTriangle, Building2, User, Phone,
  DollarSign, ShieldAlert, ChevronLeft
} from 'lucide-react'
import {
  Contrato,
  Fornecedor,
  ContratoPasta,
  calcularStatusContrato,
  formatMoney,
  StatusContratoInfo,
} from './types'
import FornecedorSelector from './fornecedor-selector'

interface ContratosClientProps {
  initialContratos: Contrato[]
  initialPastas: ContratoPasta[]
  initialFornecedores: Fornecedor[]
  initialCategorias: string[]
  condoId: string
}

const CATEGORIAS_PADRAO = [
  'Manutenção',
  'Limpeza e Portaria',
  'Segurança e Vigilância',
  'Elevadores',
  'Piscina e Lazer',
  'Jardinagem',
  'Dedetização',
  'Contabilidade / Jurídico',
  'Tecnologia / TI',
  'Outros',
]

function formatDate(d: string | null | undefined) {
  if (!d) return '—'
  return new Date(d + 'T12:00:00').toLocaleDateString('pt-BR')
}

const DIAS_SEMANA = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb']
const MESES = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro']

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
      // eslint-disable-next-line react-hooks/set-state-in-effect
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
          disabled ? 'bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed' : 'bg-white text-gray-800 border-gray-200 hover:border-[#FC5931]'
        }`}
      >
        <span className={value ? 'text-gray-900 font-medium' : 'text-gray-400'}>
          {disabled ? 'Sem validade' : displayValue}
        </span>
        <Calendar size={16} className={disabled ? 'text-gray-300' : 'text-gray-400'} />
      </button>

      {open && (
        <div className="absolute top-full left-0 mt-1 bg-white rounded-2xl shadow-xl border border-gray-100 p-4 z-50 w-72 animate-in fade-in zoom-in-95 duration-100">
          <div className="flex items-center justify-between mb-3">
            <button type="button" onClick={prevMonth} className="p-1 rounded-lg hover:bg-gray-100 text-gray-500"><ChevronLeft size={16} /></button>
            <span className="text-sm font-semibold text-gray-800 capitalize">{MESES[viewMonth]} {viewYear}</span>
            <button type="button" onClick={nextMonth} className="p-1 rounded-lg hover:bg-gray-100 text-gray-500"><ChevronRight size={16} /></button>
          </div>

          <div className="grid grid-cols-7 gap-1 text-center mb-1">
            {DIAS_SEMANA.map(d => (
              <span key={d} className="text-[11px] font-semibold text-gray-400 uppercase">{d}</span>
            ))}
          </div>

          <div className="grid grid-cols-7 gap-1">
            {cells.map((c, i) => {
              if (!c.current) {
                return <span key={i} className="text-xs text-gray-300 py-1.5 text-center">{c.day}</span>
              }
              const s = dayStr(c.day)
              const isSel = s === value
              const isTod = s === todayStr
              return (
                <button
                  key={i}
                  type="button"
                  onClick={() => { onChange(s); setOpen(false) }}
                  className={`text-xs py-1.5 rounded-lg text-center transition font-medium ${
                    isSel ? 'bg-[#FC5931] text-white font-bold' : isTod ? 'border border-[#FC5931] text-[#FC5931]' : 'hover:bg-gray-100 text-gray-700'
                  }`}
                >
                  {c.day}
                </button>
              )
            })}
          </div>

          <div className="flex items-center justify-between pt-3 mt-2 border-t border-gray-100">
            <button
              type="button"
              onClick={() => { onChange(todayStr); setOpen(false) }}
              className="text-xs text-[#FC5931] font-semibold hover:underline"
            >
              Hoje
            </button>
            {value && (
              <button
                type="button"
                onClick={() => { onChange(''); setOpen(false) }}
                className="text-xs text-gray-400 hover:text-gray-600"
              >
                Limpar
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

function StatusBadge({ info }: { info: StatusContratoInfo }) {
  switch (info.color) {
    case 'emerald':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
          <CheckCircle2 size={12} className="text-emerald-500" />
          {info.label}
        </span>
      )
    case 'amber':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-50 text-amber-700 border border-amber-200">
          <Clock size={12} className="text-amber-500" />
          {info.label}
        </span>
      )
    case 'orange':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-orange-50 text-orange-700 border border-orange-200">
          <AlertTriangle size={12} className="text-orange-500" />
          {info.label}
        </span>
      )
    case 'red':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-red-50 text-red-700 border border-red-200">
          <ShieldAlert size={12} className="text-red-500" />
          {info.label}
        </span>
      )
    default:
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-600 border border-gray-200">
          {info.label}
        </span>
      )
  }
}

export default function ContratosClient({
  initialContratos,
  initialPastas,
  initialFornecedores,
  initialCategorias,
  condoId,
}: ContratosClientProps) {
  const supabase = createClient()

  const [contratos, setContratos] = useState<Contrato[]>(initialContratos)
  const [pastas, setPastas] = useState<ContratoPasta[]>(initialPastas)
  const [fornecedores, setFornecedores] = useState<Fornecedor[]>(initialFornecedores)
  const [categorias, setCategorias] = useState<string[]>(
    Array.from(new Set([...CATEGORIAS_PADRAO, ...initialCategorias])).sort()
  )

  // Filtros e busca
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('TODOS')
  const [pastaFilter, setPastaFilter] = useState<string>('TODAS')

  // Drawer / Form state
  const [showForm, setShowForm] = useState(false)
  const [editingContrato, setEditingContrato] = useState<Contrato | null>(null)

  // Form fields
  const [fornecedorId, setFornecedorId] = useState<string | null>(null)
  const [fornecedorNomeAvulso, setFornecedorNomeAvulso] = useState<string>('')
  const [tituloServico, setTituloServico] = useState('')
  const [valorMensalStr, setValorMensalStr] = useState('')
  const [dataInicio, setDataInicio] = useState('')
  const [dataTermino, setDataTermino] = useState('')
  const [semValidade, setSemValidade] = useState(false)
  const [pastaId, setPastaId] = useState<string>('')
  const [categoria, setCategoria] = useState<string>('')
  const [descricao, setDescricao] = useState('')
  const [mostrarMoradores, setMostrarMoradores] = useState(false)
  const [lembrar30, setLembrar30] = useState(false)
  const [lembrar60, setLembrar60] = useState(false)
  const [lembrar90, setLembrar90] = useState(false)
  const [file, setFile] = useState<File | null>(null)
  const [showOpcoesAdicionais, setShowOpcoesAdicionais] = useState(false)

  const [isSaving, setIsSaving] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')

  // Pasta Modal
  const [showPastaModal, setShowPastaModal] = useState(false)
  const [editingPasta, setEditingPasta] = useState<ContratoPasta | null>(null)
  const [nomePasta, setNomePasta] = useState('')

  // Métricas do Topo
  const metricas = useMemo(() => {
    let ativosCount = 0
    let vencendoCount = 0
    let vencidosCount = 0
    let custoMensalAtivo = 0
    let custoMensalVencido = 0

    contratos.forEach(c => {
      const status = calcularStatusContrato(c)
      const valor = c.valor_mensal ?? 0

      if (status.type === 'PERMANENTE' || status.type === 'VIGENTE' || status.type === 'VENCENDO' || status.type === 'VENCE_HOJE') {
        ativosCount++
        custoMensalAtivo += valor
      }
      if (status.type === 'VENCENDO' || status.type === 'VENCE_HOJE') {
        vencendoCount++
      }
      if (status.type === 'VENCIDO') {
        vencidosCount++
        custoMensalVencido += valor
      }
    })

    return {
      ativosCount,
      vencendoCount,
      vencidosCount,
      custoMensalAtivo,
      custoMensalVencido,
    }
  }, [contratos])

  // Contratos Filtrados e Ordenados por prioridade de atenção
  const contratosFiltrados = useMemo(() => {
    return contratos
      .filter(c => {
        const q = search.toLowerCase()
        const fNome = c.fornecedores?.nome?.toLowerCase() ?? c.fornecedor_nome?.toLowerCase() ?? ''
        const matchesSearch =
          q === '' ||
          c.titulo.toLowerCase().includes(q) ||
          fNome.includes(q) ||
          (c.categoria?.toLowerCase().includes(q) ?? false) ||
          (c.contrato_pastas?.nome.toLowerCase().includes(q) ?? false)

        const status = calcularStatusContrato(c)
        let matchesStatus = true
        if (statusFilter === 'VIGENTES') matchesStatus = status.type === 'VIGENTE'
        else if (statusFilter === 'VENCENDO') matchesStatus = status.type === 'VENCENDO' || status.type === 'VENCE_HOJE'
        else if (statusFilter === 'VENCIDOS') matchesStatus = status.type === 'VENCIDO'
        else if (statusFilter === 'SEM_VALIDADE') matchesStatus = status.type === 'PERMANENTE'

        const matchesPasta = pastaFilter === 'TODAS' || (c.pasta_id === pastaFilter)

        return matchesSearch && matchesStatus && matchesPasta
      })
      .sort((a, b) => {
        const statusA = calcularStatusContrato(a)
        const statusB = calcularStatusContrato(b)

        const prioridadeOrder: Record<string, number> = {
          VENCIDO: 1,
          VENCE_HOJE: 2,
          VENCENDO: 3,
          VIGENTE: 4,
          PERMANENTE: 5,
          INDETERMINADO: 6,
        }

        const diffPrio = (prioridadeOrder[statusA.type] ?? 99) - (prioridadeOrder[statusB.type] ?? 99)
        if (diffPrio !== 0) return diffPrio

        // Secundário: mais próximos do vencimento
        const valA = a.data_validade ? new Date(a.data_validade).getTime() : 9999999999999
        const valB = b.data_validade ? new Date(b.data_validade).getTime() : 9999999999999
        return valA - valB
      })
  }, [contratos, search, statusFilter, pastaFilter])

  function openNewContrato() {
    setEditingContrato(null)
    setFornecedorId(null)
    setFornecedorNomeAvulso('')
    setTituloServico('')
    setValorMensalStr('')
    setDataInicio(new Date().toISOString().slice(0, 10))
    setDataTermino('')
    setSemValidade(false)
    setPastaId('')
    setCategoria('Manutenção')
    setDescricao('')
    setMostrarMoradores(false)
    setLembrar30(false)
    setLembrar60(false)
    setLembrar90(false)
    setFile(null)
    setShowOpcoesAdicionais(false)
    setErrorMsg('')
    setShowForm(true)
  }

  function openEditContrato(c: Contrato) {
    setEditingContrato(c)
    setFornecedorId(c.fornecedor_id ?? null)
    setFornecedorNomeAvulso(c.fornecedor_nome ?? '')
    setTituloServico(c.titulo ?? '')
    setValorMensalStr(c.valor_mensal !== null && c.valor_mensal !== undefined ? String(c.valor_mensal) : '')
    setDataInicio(c.data_expedicao ?? '')
    setDataTermino(c.data_validade ?? '')
    setSemValidade(c.sem_validade ?? false)
    setPastaId(c.pasta_id ?? '')
    setCategoria(c.categoria ?? '')
    setDescricao(c.descricao ?? '')
    setMostrarMoradores(c.mostrar_moradores ?? false)
    setLembrar30(c.lembrar_30 ?? false)
    setLembrar60(c.lembrar_60 ?? false)
    setLembrar90(c.lembrar_90 ?? false)
    setFile(null)
    setShowOpcoesAdicionais(Boolean(c.pasta_id || c.descricao || c.mostrar_moradores || c.lembrar_30))
    setErrorMsg('')
    setShowForm(true)
  }

  async function handleSaveContrato(e: React.FormEvent) {
    e.preventDefault()

    if (!tituloServico.trim()) {
      setErrorMsg('Informe o serviço ou objeto do contrato.')
      return
    }

    if (!semValidade && !dataTermino && !editingContrato) {
      setErrorMsg('Informe a data de término do contrato ou marque como "Contrato sem validade".')
      return
    }

    setIsSaving(true)
    setErrorMsg('')

    let valorMensalNum: number | null = null
    if (valorMensalStr.trim()) {
      const parsed = parseFloat(valorMensalStr.replace(',', '.'))
      if (isNaN(parsed) || parsed < 0) {
        setErrorMsg('Informe um valor mensal válido e positivo.')
        setIsSaving(false)
        return
      }
      valorMensalNum = parsed
    }

    let arquivoUrl = editingContrato?.arquivo_url ?? null
    let arquivoNome = editingContrato?.arquivo_nome ?? null

    // Upload de novo arquivo se selecionado
    if (file) {
      const ext = file.name.split('.').pop()
      const filePath = `${condoId}/${Date.now()}.${ext}`
      const { error: uploadError } = await supabase.storage.from('contratos').upload(filePath, file)
      if (uploadError) {
        setErrorMsg('Erro no upload do arquivo: ' + uploadError.message)
        setIsSaving(false)
        return
      }
      const { data: urlData } = supabase.storage.from('contratos').getPublicUrl(filePath)
      arquivoUrl = urlData.publicUrl
      arquivoNome = file.name
    }

    // Regra canônica de fornecedor:
    // Se fornecedor_id estiver preenchido -> fornecedor_nome DEVE ser null.
    // Se fornecedor_id for null -> fornecedor_nome recebe o texto avulso (ou null se vazio).
    const fId = fornecedorId || null
    const fNome = fId ? null : (fornecedorNomeAvulso.trim() || null)

    const payload = {
      condominio_id: condoId,
      fornecedor_id: fId,
      fornecedor_nome: fNome,
      titulo: tituloServico.trim(),
      categoria: categoria.trim() || null,
      pasta_id: pastaId || null,
      valor_mensal: valorMensalNum,
      data_expedicao: dataInicio || null,
      data_validade: semValidade ? null : (dataTermino || null),
      sem_validade: semValidade,
      lembrar_30: semValidade ? false : lembrar30,
      lembrar_60: semValidade ? false : lembrar60,
      lembrar_90: semValidade ? false : lembrar90,
      arquivo_url: arquivoUrl,
      arquivo_nome: arquivoNome,
      mostrar_moradores: mostrarMoradores,
      descricao: descricao.trim() || null,
      tipo: 'obrigatorio',
      updated_at: new Date().toISOString(),
    }

    try {
      if (editingContrato) {
        const { data, error } = await supabase
          .from('contratos')
          .update(payload)
          .eq('id', editingContrato.id)
          .select('*, fornecedores(id, nome, telefone, documento, tipo), contrato_pastas(id, nome)')
          .single()

        if (error) throw error

        setContratos(prev => prev.map(c => c.id === editingContrato.id ? (data as Contrato) : c))
      } else {
        const { data, error } = await supabase
          .from('contratos')
          .insert(payload)
          .select('*, fornecedores(id, nome, telefone, documento, tipo), contrato_pastas(id, nome)')
          .single()

        if (error) throw error

        setContratos(prev => [data as Contrato, ...prev])
      }

      setShowForm(false)
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Erro ao salvar contrato.'
      setErrorMsg(msg)
    } finally {
      setIsSaving(false)
    }
  }

  async function handleDeleteContrato(c: Contrato) {
    if (!confirm(`Deseja realmente excluir o contrato "${c.titulo}"?`)) return

    try {
      const { error } = await supabase.from('contratos').delete().eq('id', c.id)
      if (error) throw error
      setContratos(prev => prev.filter(x => x.id !== c.id))
    } catch (err: unknown) {
      alert('Erro ao excluir contrato: ' + (err instanceof Error ? err.message : String(err)))
    }
  }

  async function handleSavePasta(e: React.FormEvent) {
    e.preventDefault()
    if (!nomePasta.trim()) return

    try {
      if (editingPasta) {
        const { data, error } = await supabase
          .from('contrato_pastas')
          .update({ nome: nomePasta.trim() })
          .eq('id', editingPasta.id)
          .select()
          .single()
        if (error) throw error
        setPastas(prev => prev.map(p => p.id === editingPasta.id ? (data as ContratoPasta) : p))
      } else {
        const { data, error } = await supabase
          .from('contrato_pastas')
          .insert({ condominio_id: condoId, nome: nomePasta.trim() })
          .select()
          .single()
        if (error) throw error
        setPastas(prev => [...prev, data as ContratoPasta].sort((a, b) => a.nome.localeCompare(b.nome)))
      }
      setShowPastaModal(false)
      setNomePasta('')
    } catch (err: unknown) {
      alert('Erro ao salvar pasta: ' + (err instanceof Error ? err.message : String(err)))
    }
  }

  async function handleDeletePasta(p: ContratoPasta) {
    if (!confirm(`Deseja remover a pasta "${p.nome}"? Os contratos vinculados serão desvinculados da pasta.`)) return

    try {
      const { error } = await supabase.from('contrato_pastas').delete().eq('id', p.id)
      if (error) throw error
      setPastas(prev => prev.filter(x => x.id !== p.id))
    } catch (err: unknown) {
      alert('Erro ao excluir pasta: ' + (err instanceof Error ? err.message : String(err)))
    }
  }

  return (
    <div className="space-y-6">
      {/* ── 1. Topo: Visão Executiva / Cards Indicadores ── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Contratos Ativos */}
        <div className="bg-white rounded-2xl p-5 border border-gray-100 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Contratos Ativos</p>
            <p className="text-2xl font-black text-gray-900 mt-1">{metricas.ativosCount}</p>
            <span className="text-[11px] text-emerald-600 font-medium">Vigentes ou permanentes</span>
          </div>
          <div className="w-12 h-12 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
            <CheckCircle2 size={24} />
          </div>
        </div>

        {/* Card 2: Vencendo em breve */}
        <div className="bg-white rounded-2xl p-5 border border-gray-100 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Vencendo em ≤ 30 dias</p>
            <p className="text-2xl font-black text-amber-600 mt-1">{metricas.vencendoCount}</p>
            <span className="text-[11px] text-amber-600 font-medium">Exigem renovação</span>
          </div>
          <div className="w-12 h-12 rounded-2xl bg-amber-50 text-amber-600 flex items-center justify-center">
            <Clock size={24} />
          </div>
        </div>

        {/* Card 3: Vencidos */}
        <div className="bg-white rounded-2xl p-5 border border-gray-100 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Contratos Vencidos</p>
            <p className="text-2xl font-black text-red-600 mt-1">{metricas.vencidosCount}</p>
            <span className="text-[11px] text-red-500 font-medium">
              {metricas.custoMensalVencido > 0
                ? `${formatMoney(metricas.custoMensalVencido)} a regularizar`
                : 'Expirados'}
            </span>
          </div>
          <div className="w-12 h-12 rounded-2xl bg-red-50 text-red-600 flex items-center justify-center">
            <ShieldAlert size={24} />
          </div>
        </div>

        {/* Card 4: Custo Mensal Ativo */}
        <div className="bg-white rounded-2xl p-5 border border-gray-100 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Custo Mensal Ativo</p>
            <p className="text-xl font-black text-gray-900 mt-1 truncate">
              {formatMoney(metricas.custoMensalAtivo)}
            </p>
            <span className="text-[11px] text-gray-400 font-medium">Total em contratos ativos</span>
          </div>
          <div className="w-12 h-12 rounded-2xl bg-orange-50 text-[#FC5931] flex items-center justify-center">
            <DollarSign size={24} />
          </div>
        </div>
      </div>

      {/* ── 2. Ações e Barra de Filtros ── */}
      <div className="bg-white rounded-2xl p-4 border border-gray-100 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row gap-3 items-center justify-between">
          {/* Busca */}
          <div className="relative w-full sm:w-96">
            <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Buscar por fornecedor, serviço, categoria..."
              className="w-full pl-9 pr-8 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
            />
            {search && (
              <button
                onClick={() => setSearch('')}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
              >
                <X size={14} />
              </button>
            )}
          </div>

          {/* Botões de Ação */}
          <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
            <button
              onClick={() => {
                setEditingPasta(null)
                setNomePasta('')
                setShowPastaModal(true)
              }}
              className="px-3 py-2 border border-gray-200 rounded-xl text-xs font-semibold text-gray-700 hover:bg-gray-50 flex items-center gap-1.5 transition"
            >
              <FolderPlus size={15} className="text-gray-500" />
              Pastas
            </button>
            <button
              onClick={openNewContrato}
              className="px-4 py-2 bg-[#FC5931] hover:bg-[#e04820] text-white rounded-xl text-xs font-bold flex items-center gap-1.5 shadow-sm shadow-[#FC5931]/30 transition"
            >
              <Plus size={16} />
              Inserir Contrato
            </button>
          </div>
        </div>

        {/* Pílulas de Status e Filtro de Pasta */}
        <div className="flex flex-wrap items-center justify-between gap-2 pt-2 border-t border-gray-50">
          <div className="flex flex-wrap items-center gap-1.5">
            {[
              { id: 'TODOS', label: 'Todos' },
              { id: 'VIGENTES', label: 'Vigentes' },
              { id: 'VENCENDO', label: 'Vencendo (≤30d)' },
              { id: 'VENCIDOS', label: 'Vencidos' },
              { id: 'SEM_VALIDADE', label: 'Permanentes' },
            ].map(tab => (
              <button
                key={tab.id}
                onClick={() => setStatusFilter(tab.id)}
                className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition ${
                  statusFilter === tab.id
                    ? 'bg-gray-900 text-white shadow-sm'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {pastas.length > 0 && (
            <div className="flex items-center gap-1.5 text-xs text-gray-500">
              <FolderOpen size={14} className="text-gray-400" />
              <select
                value={pastaFilter}
                onChange={e => setPastaFilter(e.target.value)}
                className="border border-gray-200 rounded-lg px-2 py-1 text-xs bg-white text-gray-700 focus:outline-none"
              >
                <option value="TODAS">Todas as Pastas</option>
                {pastas.map(p => (
                  <option key={p.id} value={p.id}>{p.nome}</option>
                ))}
              </select>
            </div>
          )}
        </div>
      </div>

      {/* ── 3. Tabela Comercial de Contratos ── */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        {contratosFiltrados.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <FileText size={48} className="mx-auto mb-3 opacity-25" />
            <p className="font-semibold text-gray-700 text-base">Nenhum contrato encontrado</p>
            <p className="text-xs text-gray-400 mt-1 max-w-sm mx-auto">
              {search || statusFilter !== 'TODOS' || pastaFilter !== 'TODAS'
                ? 'Tente ajustar os filtros ou termo de busca.'
                : 'Cadastre os contratos de prestadores de serviços do condomínio.'}
            </p>
            {!search && statusFilter === 'TODOS' && (
              <button
                onClick={openNewContrato}
                className="mt-4 px-4 py-2 bg-[#FC5931] text-white text-xs font-bold rounded-xl inline-flex items-center gap-1.5 hover:bg-[#e04820] transition"
              >
                <Plus size={14} /> Cadastrar Primeiro Contrato
              </button>
            )}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left">
              <thead>
                <tr className="bg-gray-50/80 text-[11px] font-bold text-gray-400 uppercase tracking-wider border-b border-gray-100">
                  <th className="px-5 py-3.5">Fornecedor</th>
                  <th className="px-4 py-3.5">Serviço / Objeto</th>
                  <th className="px-4 py-3.5 text-right">Valor Mensal</th>
                  <th className="px-4 py-3.5">Vigência / Término</th>
                  <th className="px-4 py-3.5">Status</th>
                  <th className="px-5 py-3.5 text-right">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {contratosFiltrados.map(contrato => {
                  const statusInfo = calcularStatusContrato(contrato)
                  const fornecedorNomeFinal =
                    contrato.fornecedores?.nome ||
                    contrato.fornecedor_nome ||
                    'Fornecedor não informado'
                  const fornecedorDoc = contrato.fornecedores?.documento
                  const fornecedorTel = contrato.fornecedores?.telefone

                  return (
                    <tr key={contrato.id} className="hover:bg-gray-50/60 transition group">
                      {/* Fornecedor */}
                      <td className="px-5 py-4">
                        <div className="flex items-center gap-2.5">
                          <div className="w-8 h-8 rounded-xl bg-orange-50 text-[#FC5931] flex items-center justify-center shrink-0">
                            {contrato.fornecedores?.tipo === 'Pessoa Jurídica' ? (
                              <Building2 size={16} />
                            ) : (
                              <User size={16} />
                            )}
                          </div>
                          <div>
                            <p className="font-bold text-gray-900 text-sm">{fornecedorNomeFinal}</p>
                            <p className="text-[11px] text-gray-400">
                              {fornecedorTel ? `📞 ${fornecedorTel}` : ''}
                              {fornecedorDoc ? ` • Doc: ${fornecedorDoc}` : ''}
                            </p>
                          </div>
                        </div>
                      </td>

                      {/* Serviço / Objeto */}
                      <td className="px-4 py-4">
                        <p className="font-semibold text-gray-800 text-sm">{contrato.titulo}</p>
                        <div className="flex items-center gap-2 mt-0.5">
                          {contrato.categoria && (
                            <span className="text-[10px] font-medium text-[#FC5931] bg-orange-50 px-2 py-0.5 rounded-md">
                              {contrato.categoria}
                            </span>
                          )}
                          {contrato.contrato_pastas && (
                            <span className="text-[11px] text-gray-400 flex items-center gap-1">
                              <FolderOpen size={11} /> {contrato.contrato_pastas.nome}
                            </span>
                          )}
                        </div>
                      </td>

                      {/* Valor Mensal */}
                      <td className="px-4 py-4 text-right">
                        <span className="font-bold text-gray-900 text-sm">
                          {formatMoney(contrato.valor_mensal)}
                        </span>
                        {contrato.valor_mensal && (
                          <span className="text-[11px] text-gray-400 block">/ mês</span>
                        )}
                      </td>

                      {/* Vencimento */}
                      <td className="px-4 py-4">
                        {contrato.sem_validade ? (
                          <span className="text-xs text-gray-600 font-medium">Permanente</span>
                        ) : contrato.data_validade ? (
                          <div>
                            <p className="text-xs font-semibold text-gray-800">
                              {formatDate(contrato.data_validade)}
                            </p>
                            {contrato.data_expedicao && (
                              <p className="text-[10px] text-gray-400">
                                Início: {formatDate(contrato.data_expedicao)}
                              </p>
                            )}
                          </div>
                        ) : (
                          <span className="text-xs text-gray-400 italic">Não informado</span>
                        )}
                      </td>

                      {/* Status */}
                      <td className="px-4 py-4">
                        <StatusBadge info={statusInfo} />
                      </td>

                      {/* Ações */}
                      <td className="px-5 py-4 text-right">
                        <div className="flex items-center justify-end gap-1">
                          {contrato.arquivo_url ? (
                            <>
                              <a
                                href={contrato.arquivo_url}
                                download={contrato.arquivo_nome ?? contrato.titulo}
                                title="Baixar Contrato"
                                className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC5931] hover:bg-orange-50 transition"
                              >
                                <Download size={15} />
                              </a>
                              <a
                                href={contrato.arquivo_url}
                                target="_blank"
                                rel="noreferrer"
                                title="Visualizar Contrato"
                                className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition"
                              >
                                <Eye size={15} />
                              </a>
                            </>
                          ) : (
                            <span title="Sem anexo" className="p-1.5 text-gray-200 cursor-not-allowed">
                              <FileText size={15} />
                            </span>
                          )}
                          <button
                            onClick={() => openEditContrato(contrato)}
                            title="Editar Contrato"
                            className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition"
                          >
                            <Pencil size={15} />
                          </button>
                          <button
                            onClick={() => handleDeleteContrato(contrato)}
                            title="Excluir Contrato"
                            className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition"
                          >
                            <Trash2 size={15} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ── 4. Drawer / Modal de Inclusão e Edição de Contrato ── */}
      {showForm && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-end p-0">
          <div className="bg-white h-full w-full max-w-xl shadow-2xl flex flex-col animate-in slide-in-from-right duration-200">
            {/* Header do Drawer */}
            <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between bg-white shrink-0">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-orange-50 text-[#FC5931] flex items-center justify-center font-bold">
                  <FileText size={20} />
                </div>
                <div>
                  <h2 className="text-base font-bold text-gray-900">
                    {editingContrato ? 'Editar Contrato' : 'Novo Contrato'}
                  </h2>
                  <p className="text-xs text-gray-400">Controle comercial e vigência de prestadores</p>
                </div>
              </div>
              <button
                onClick={() => setShowForm(false)}
                className="p-2 rounded-xl hover:bg-gray-100 text-gray-400 transition"
              >
                <X size={18} />
              </button>
            </div>

            {/* Corpo do Formulário */}
            <form onSubmit={handleSaveContrato} className="flex-1 overflow-y-auto p-6 space-y-5">
              {errorMsg && (
                <div className="p-3 rounded-xl bg-red-50 text-red-700 text-xs border border-red-100 font-medium">
                  {errorMsg}
                </div>
              )}

              {/* 1. SEÇÃO PRINCIPAL */}
              <div className="space-y-4">
                {/* Fornecedor Selector */}
                <FornecedorSelector
                  condoId={condoId}
                  fornecedores={fornecedores}
                  selectedFornecedorId={fornecedorId}
                  fornecedorNomeAvulso={fornecedorNomeAvulso}
                  onSelectFornecedor={f => {
                    setFornecedorId(f?.id ?? null)
                    if (f) setFornecedorNomeAvulso('')
                  }}
                  onChangeNomeAvulso={nome => {
                    setFornecedorNomeAvulso(nome)
                    setFornecedorId(null)
                  }}
                  onFornecedorCreated={novo => {
                    setFornecedores(prev => [...prev, novo].sort((a, b) => a.nome.localeCompare(b.nome)))
                    setFornecedorId(novo.id)
                    setFornecedorNomeAvulso('')
                  }}
                />

                {/* Serviço / Objeto */}
                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">
                    Serviço / Objeto do Contrato <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={tituloServico}
                    onChange={e => setTituloServico(e.target.value)}
                    placeholder="Ex: Manutenção Preventiva dos Elevadores, Portaria 24h..."
                    className="w-full border border-gray-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                    required
                  />
                </div>

                {/* Valor Mensal (R$) */}
                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">
                    Valor Mensal Recorrente (R$)
                  </label>
                  <div className="relative">
                    <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 font-semibold text-sm">
                      R$
                    </span>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={valorMensalStr}
                      onChange={e => setValorMensalStr(e.target.value)}
                      placeholder="0,00"
                      className="w-full pl-10 pr-3.5 py-2.5 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                    />
                  </div>
                </div>
              </div>

              {/* 2. SEÇÃO DE VIGÊNCIA */}
              <div className="p-4 rounded-2xl bg-gray-50 border border-gray-100 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-gray-700 uppercase tracking-wide">
                    Vigência e Prazos
                  </span>
                  <label className="flex items-center gap-2 cursor-pointer text-xs text-gray-700 font-medium">
                    <input
                      type="checkbox"
                      checked={semValidade}
                      onChange={e => {
                        const checked = e.target.checked
                        setSemValidade(checked)
                        if (checked) {
                          setDataTermino('')
                          setLembrar30(false)
                          setLembrar60(false)
                          setLembrar90(false)
                        }
                      }}
                      className="rounded text-[#FC5931] focus:ring-[#FC5931] w-4 h-4"
                    />
                    Contrato sem validade (prazo indeterminado)
                  </label>
                </div>

                <div className="grid grid-cols-2 gap-3 pt-1">
                  <CalendarPicker
                    label="Data de Início"
                    value={dataInicio}
                    onChange={setDataInicio}
                  />
                  <CalendarPicker
                    label="Data de Término"
                    value={dataTermino}
                    onChange={setDataTermino}
                    disabled={semValidade}
                  />
                </div>
              </div>

              {/* 3. SEÇÃO DE ARQUIVO */}
              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">
                  Arquivo do Contrato (PDF, DOC ou Imagem)
                </label>
                <div className="border border-dashed border-gray-200 rounded-2xl p-4 text-center bg-gray-50/50 hover:bg-gray-50 transition">
                  <input
                    type="file"
                    id="contrato-file-input"
                    className="hidden"
                    accept=".pdf,.doc,.docx,.png,.jpg,.jpeg"
                    onChange={e => {
                      if (e.target.files && e.target.files[0]) {
                        setFile(e.target.files[0])
                      }
                    }}
                  />
                  <label htmlFor="contrato-file-input" className="cursor-pointer">
                    <Upload size={20} className="mx-auto text-gray-400 mb-1.5" />
                    <p className="text-xs font-semibold text-gray-700">
                      {file ? file.name : (editingContrato?.arquivo_nome ?? 'Clique para selecionar o contrato assinado')}
                    </p>
                    <p className="text-[11px] text-gray-400 mt-0.5">PDF, DOC, PNG ou JPG até 10MB</p>
                  </label>
                </div>
              </div>

              {/* 4. OPÇÕES ADICIONAIS (Colapsável) */}
              <div className="border border-gray-100 rounded-2xl overflow-hidden">
                <button
                  type="button"
                  onClick={() => setShowOpcoesAdicionais(!showOpcoesAdicionais)}
                  className="w-full p-3.5 bg-gray-50/80 text-left text-xs font-bold text-gray-700 flex items-center justify-between hover:bg-gray-100 transition"
                >
                  <span>Opções Adicionais (Pasta, Categoria, Lembretes...)</span>
                  <ChevronDown
                    size={16}
                    className={`text-gray-400 transition-transform ${showOpcoesAdicionais ? 'rotate-180' : ''}`}
                  />
                </button>

                {showOpcoesAdicionais && (
                  <div className="p-4 space-y-4 bg-white border-t border-gray-100">
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">
                          Categoria
                        </label>
                        <select
                          value={categoria}
                          onChange={e => setCategoria(e.target.value)}
                          className="w-full border border-gray-200 rounded-xl px-3 py-2 text-xs bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                        >
                          <option value="">Selecione</option>
                          {categorias.map(cat => (
                            <option key={cat} value={cat}>{cat}</option>
                          ))}
                        </select>
                      </div>
                      <div>
                        <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">
                          Pasta
                        </label>
                        <select
                          value={pastaId}
                          onChange={e => setPastaId(e.target.value)}
                          className="w-full border border-gray-200 rounded-xl px-3 py-2 text-xs bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                        >
                          <option value="">Sem pasta</option>
                          {pastas.map(p => (
                            <option key={p.id} value={p.id}>{p.nome}</option>
                          ))}
                        </select>
                      </div>
                    </div>

                    {!semValidade && (
                      <div className="space-y-1.5 pt-1 border-t border-gray-100">
                        <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block">
                          Lembretes de Vencimento
                        </label>
                        <div className="flex flex-wrap gap-4 text-xs text-gray-700">
                          <label className="flex items-center gap-1.5 cursor-pointer">
                            <input
                              type="checkbox"
                              checked={lembrar30}
                              onChange={e => setLembrar30(e.target.checked)}
                              className="rounded text-[#FC5931] focus:ring-[#FC5931]"
                            />
                            30 dias antes
                          </label>
                          <label className="flex items-center gap-1.5 cursor-pointer">
                            <input
                              type="checkbox"
                              checked={lembrar60}
                              onChange={e => setLembrar60(e.target.checked)}
                              className="rounded text-[#FC5931] focus:ring-[#FC5931]"
                            />
                            60 dias antes
                          </label>
                          <label className="flex items-center gap-1.5 cursor-pointer">
                            <input
                              type="checkbox"
                              checked={lembrar90}
                              onChange={e => setLembrar90(e.target.checked)}
                              className="rounded text-[#FC5931] focus:ring-[#FC5931]"
                            />
                            90 dias antes
                          </label>
                        </div>
                      </div>
                    )}

                    <div className="pt-2 border-t border-gray-100">
                      <label className="flex items-center gap-2 cursor-pointer text-xs text-gray-700 font-medium">
                        <input
                          type="checkbox"
                          checked={mostrarMoradores}
                          onChange={e => setMostrarMoradores(e.target.checked)}
                          className="rounded text-[#FC5931] focus:ring-[#FC5931] w-4 h-4"
                        />
                        Disponibilizar aos moradores no aplicativo (Portal de Transparência)
                      </label>
                      <span className="text-[11px] text-gray-400 block mt-0.5 ml-6">
                        Por padrão desativado (visível apenas para administradores).
                      </span>
                    </div>

                    <div>
                      <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">
                        Observações / Cláusulas Relevantes
                      </label>
                      <textarea
                        rows={3}
                        value={descricao}
                        onChange={e => setDescricao(e.target.value)}
                        placeholder="Detalhes sobre escopo, reajuste ou contatos de emergência..."
                        className="w-full border border-gray-200 rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                      />
                    </div>
                  </div>
                )}
              </div>

              {/* Botões do Rodapé */}
              <div className="pt-4 flex gap-3 border-t border-gray-100">
                <button
                  type="button"
                  onClick={() => setShowForm(false)}
                  className="flex-1 py-3 text-xs font-bold text-gray-700 hover:bg-gray-100 rounded-xl transition"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  disabled={isSaving}
                  className="flex-1 py-3 bg-[#FC5931] hover:bg-[#e04820] text-white rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 shadow-sm shadow-[#FC5931]/30 transition disabled:opacity-50"
                >
                  {isSaving ? <Loader2 size={16} className="animate-spin" /> : null}
                  {editingContrato ? 'Salvar Alterações' : 'Cadastrar Contrato'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── 5. Modal de Criação / Edição de Pastas ── */}
      {showPastaModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-bold text-gray-900 text-base">
                {editingPasta ? 'Editar Pasta' : 'Nova Pasta'}
              </h3>
              <button
                onClick={() => setShowPastaModal(false)}
                className="text-gray-400 hover:text-gray-600 p-1"
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSavePasta} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">
                  Nome da Pasta
                </label>
                <input
                  type="text"
                  value={nomePasta}
                  onChange={e => setNomePasta(e.target.value)}
                  placeholder="Ex: Manutenção 2026, Portaria, Obras..."
                  className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                  autoFocus
                />
              </div>

              {pastas.length > 0 && !editingPasta && (
                <div className="space-y-1.5 max-h-40 overflow-y-auto">
                  <p className="text-[11px] font-semibold text-gray-400 uppercase">Pastas existentes:</p>
                  {pastas.map(p => (
                    <div key={p.id} className="flex items-center justify-between text-xs p-1.5 bg-gray-50 rounded-lg">
                      <span className="text-gray-700">{p.nome}</span>
                      <div className="flex items-center gap-1">
                        <button
                          type="button"
                          onClick={() => {
                            setEditingPasta(p)
                            setNomePasta(p.nome)
                          }}
                          className="p-1 text-gray-400 hover:text-gray-700"
                        >
                          <Pencil size={12} />
                        </button>
                        <button
                          type="button"
                          onClick={() => handleDeletePasta(p)}
                          className="p-1 text-gray-400 hover:text-red-600"
                        >
                          <Trash2 size={12} />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <div className="flex gap-2 justify-end pt-2">
                <button
                  type="button"
                  onClick={() => setShowPastaModal(false)}
                  className="px-4 py-2 text-xs font-medium text-gray-600 hover:bg-gray-100 rounded-xl transition"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 text-xs font-bold text-white bg-[#FC5931] hover:bg-[#e04820] rounded-xl transition"
                >
                  {editingPasta ? 'Salvar' : 'Criar Pasta'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
