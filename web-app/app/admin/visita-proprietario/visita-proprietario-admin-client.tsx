'use client'

import { useState, useEffect, useTransition, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  LogIn, LogOut as LogOutIcon, Plus, X, Search, Filter, Trash2,
  CheckCircle, AlertCircle, Clock, Users, ChevronDown, ChevronLeft, ChevronRight,
  Download, DoorOpen, CalendarDays, BarChart3, TrendingUp
} from 'lucide-react'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

interface Visita {
  id: string
  condominio_id: string
  tipo: 'entrada' | 'saida'
  morador_id: string | null
  nome_morador: string
  bloco: string | null
  apto: string | null
  cracha_referencia: string | null
  registrado_por: string | null
  created_at: string
}

interface Morador {
  id: string
  nome: string
}

interface Props {
  condoId: string
  currentUserId: string
  currentUserName: string
  tipoEstrutura?: string
  blocos: string[]
  aptosMap: Record<string, string[]>
  moradoresMap: Record<string, Morador[]>
}

export default function VisitaProprietarioAdminClient({
  condoId,
  currentUserId,
  tipoEstrutura,
  blocos,
  aptosMap,
  moradoresMap,
}: Props) {
  const supabase = createClient()
  const [isPending, startTransition] = useTransition()

  // ── Pagination ──────────────────────────────────────────
  const PAGE_SIZE = 15
  const [page, setPage] = useState(0)
  const [totalCount, setTotalCount] = useState(0)
  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE))

  // List state
  const [visitas, setVisitas] = useState<Visita[]>([])
  const [loading, setLoading] = useState(true)

  // Filter state
  const now = new Date()
  const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
  const [filterTipo, setFilterTipo] = useState<'todos' | 'entrada' | 'saida'>('todos')
  const [filterBloco, setFilterBloco] = useState('')
  const [filterApto, setFilterApto] = useState('')
  const [filterNome, setFilterNome] = useState('')
  const [nameInput, setNameInput] = useState('')
  const [filterData, setFilterData] = useState(todayStr)
  const [showFilters, setShowFilters] = useState(false)

  // Stats
  const [statsEntrada, setStatsEntrada] = useState(0)
  const [statsSaida, setStatsSaida] = useState(0)
  const [statsTotal, setStatsTotal] = useState(0)

  // Modal state
  const [showModal, setShowModal] = useState(false)
  const [modalTipo, setModalTipo] = useState<'entrada' | 'saida'>('entrada')
  const [modalBloco, setModalBloco] = useState('')
  const [modalApto, setModalApto] = useState('')
  const [modalMoradorId, setModalMoradorId] = useState<string | null>(null)
  const [modalNome, setModalNome] = useState('')
  const [modalCracha, setModalCracha] = useState('')
  const [saved, setSaved] = useState(false)
  const [error, setError] = useState('')

  // Available in modals
  const modalAvailableAptos = modalBloco ? (aptosMap[modalBloco] ?? []) : []
  const unitKey = `${modalBloco}|${modalApto}`
  const unitMoradores = moradoresMap[unitKey] ?? []
  const filterAvailableAptos = filterBloco ? (aptosMap[filterBloco] ?? []) : []

  // ── Fetch visitas from DB ─────────────────────────────────
  const fetchVisitas = useCallback(async (currentPage = 0) => {
    setLoading(true)
    const from = currentPage * PAGE_SIZE
    const to = from + PAGE_SIZE - 1

    let query = supabase
      .from('visita_proprietario')
      .select('*', { count: 'exact' })
      .eq('condominio_id', condoId)
      .order('created_at', { ascending: false })
      .range(from, to)

    if (filterTipo !== 'todos') query = query.eq('tipo', filterTipo)
    if (filterBloco) query = query.eq('bloco', filterBloco)
    if (filterApto) query = query.eq('apto', filterApto)
    if (filterNome) query = query.ilike('nome_morador', `%${filterNome}%`)
    if (filterData) {
      query = query.gte('created_at', `${filterData}T00:00:00`).lte('created_at', `${filterData}T23:59:59`)
    }

    const { data, count } = await query
    setVisitas(data ?? [])
    setTotalCount(count ?? 0)
    setLoading(false)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [condoId, filterTipo, filterBloco, filterApto, filterNome, filterData])

  // Fetch stats for the selected day (all types)
  const fetchStats = useCallback(async () => {
    if (!filterData) return

    const [entradaRes, saidaRes] = await Promise.all([
      supabase
        .from('visita_proprietario')
        .select('id', { count: 'exact', head: true })
        .eq('condominio_id', condoId)
        .eq('tipo', 'entrada')
        .gte('created_at', `${filterData}T00:00:00`)
        .lte('created_at', `${filterData}T23:59:59`),
      supabase
        .from('visita_proprietario')
        .select('id', { count: 'exact', head: true })
        .eq('condominio_id', condoId)
        .eq('tipo', 'saida')
        .gte('created_at', `${filterData}T00:00:00`)
        .lte('created_at', `${filterData}T23:59:59`),
    ])

    const entrada = entradaRes.count ?? 0
    const saida = saidaRes.count ?? 0
    setStatsEntrada(entrada)
    setStatsSaida(saida)
    setStatsTotal(entrada + saida)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [condoId, filterData])

  // Re-fetch whenever filters or page change
  useEffect(() => {
    fetchVisitas(page)
    fetchStats()
  }, [fetchVisitas, fetchStats, page])

  // Debounce name filter
  useEffect(() => {
    const timer = setTimeout(() => {
      if (filterNome !== nameInput) {
        setPage(0)
        setFilterNome(nameInput)
      }
    }, 500)
    return () => clearTimeout(timer)
  }, [nameInput, filterNome])

  function applyFilter<T>(setter: React.Dispatch<React.SetStateAction<T>>, value: T) {
    setPage(0)
    setter(value)
  }

  // ── Handle save ───────────────────────────────────────────
  async function handleSave() {
    const nome = modalNome.trim()
    if (!nome) { setError('Informe o nome do morador.'); return }
    if (!modalBloco || !modalApto) {
      setError(`Selecione o ${getBlocoLabel(tipoEstrutura).toLowerCase()} e ${getAptoLabel(tipoEstrutura).toLowerCase()}.`)
      return
    }
    setError('')

    startTransition(async () => {
      const { error: insertError } = await supabase
        .from('visita_proprietario')
        .insert({
          condominio_id: condoId,
          tipo: modalTipo,
          morador_id: modalMoradorId,
          nome_morador: nome,
          bloco: modalBloco,
          apto: modalApto,
          cracha_referencia: modalCracha.trim() || null,
          registrado_por: currentUserId,
        })

      if (insertError) {
        setError('Erro ao registrar: ' + insertError.message)
        return
      }

      // Push notification (fire-and-forget)
      try {
        const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
        const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
        if (supabaseUrl && supabaseAnonKey) {
          fetch(`${supabaseUrl}/functions/v1/visita-proprietario-push-notify`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${supabaseAnonKey}`,
            },
            body: JSON.stringify({
              condominio_id: condoId,
              bloco: modalBloco,
              apto: modalApto,
              tipo: modalTipo,
              nome_morador: nome,
            }),
          }).catch(() => {})
        }
      } catch {}

      setSaved(true)
      setTimeout(async () => {
        setSaved(false)
        resetModal()
        await fetchVisitas(page)
        await fetchStats()
      }, 1500)
    })
  }

  function resetModal() {
    setShowModal(false)
    setModalTipo('entrada')
    setModalBloco('')
    setModalApto('')
    setModalMoradorId(null)
    setModalNome('')
    setModalCracha('')
    setError('')
  }

  async function handleDelete(id: string) {
    if (!confirm('Deseja realmente excluir este registro?')) return
    const { error } = await supabase.from('visita_proprietario').delete().eq('id', id)
    if (error) {
      alert('Erro ao excluir: ' + error.message)
    } else {
      await fetchVisitas(page)
      await fetchStats()
    }
  }

  async function handleExportCSV() {
    let query = supabase
      .from('visita_proprietario')
      .select('*')
      .eq('condominio_id', condoId)
      .order('created_at', { ascending: false })

    if (filterTipo !== 'todos') query = query.eq('tipo', filterTipo)
    if (filterBloco) query = query.eq('bloco', filterBloco)
    if (filterApto) query = query.eq('apto', filterApto)
    if (filterNome) query = query.ilike('nome_morador', `%${filterNome}%`)
    if (filterData) {
      query = query.gte('created_at', `${filterData}T00:00:00`).lte('created_at', `${filterData}T23:59:59`)
    }

    const { data } = await query.limit(5000)
    if (!data || data.length === 0) {
      alert('Nenhum registro para exportar.')
      return
    }

    const blocoLbl = getBlocoLabel(tipoEstrutura)
    const aptoLbl = getAptoLabel(tipoEstrutura)
    const header = `Tipo,Nome Morador,${blocoLbl},${aptoLbl},Crachá,Data/Hora\n`
    const rows = data.map((v: Visita) => {
      const dt = new Date(v.created_at)
      const dateStr = dt.toLocaleDateString('pt-BR') + ' ' + dt.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
      return `${v.tipo === 'entrada' ? 'Entrada' : 'Saída'},"${v.nome_morador}",${v.bloco || ''},${v.apto || ''},${v.cracha_referencia || ''},${dateStr}`
    }).join('\n')

    const blob = new Blob([header + rows], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `visitas-proprietario-${filterData || 'todas'}.csv`
    link.click()
    URL.revokeObjectURL(url)
  }

  function selectMorador(m: Morador) {
    setModalMoradorId(m.id)
    setModalNome(m.nome)
  }

  function fmtTime(iso: string) {
    const d = new Date(iso)
    return d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) + 'h'
  }

  function fmtDate(iso: string) {
    return new Date(iso).toLocaleDateString('pt-BR')
  }

  function fmtFilterDate(dateStr: string) {
    if (!dateStr) return ''
    const [y, m, d] = dateStr.split('-')
    return `${d}/${m}/${y}`
  }

  // ── Render ─────────────────────────────────────────────────
  return (
    <div className="p-4 md:p-8 max-w-6xl mx-auto">
      {/* ── Header ───────────────────────────────────────── */}
      <div className="mb-8 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
            <DoorOpen size={28} className="text-[#FC5931]" />
            Visita Proprietário
          </h1>
          <p className="text-gray-500 mt-1">
            Controle administrativo de entrada e saída de moradores
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={handleExportCSV}
            className="flex items-center gap-2 border border-gray-200 text-gray-600 hover:bg-gray-50 px-4 py-2.5 rounded-xl font-medium text-sm transition-colors"
            title="Exportar CSV"
          >
            <Download size={16} />
            Exportar
          </button>
          <button
            onClick={() => setShowModal(true)}
            className="flex items-center gap-2 bg-[#FC5931] text-white px-5 py-2.5 rounded-xl font-semibold text-sm hover:bg-[#D42F1D] transition-all shadow-lg shadow-[#FC5931]/20 hover:shadow-[#FC5931]/40"
          >
            <Plus size={18} />
            Registrar Visita
          </button>
        </div>
      </div>

      {/* ── Stats Cards ─────────────────────────────────── */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
        <div className="bg-white rounded-2xl border border-gray-100 p-5 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gray-100 flex items-center justify-center">
              <BarChart3 size={20} className="text-gray-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-gray-800">{statsTotal}</p>
              <p className="text-xs text-gray-500 font-medium">Total do dia</p>
            </div>
          </div>
        </div>
        <div className="bg-linear-to-br from-emerald-50 to-emerald-100/50 rounded-2xl border border-emerald-200/50 p-5">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-200/50 flex items-center justify-center">
              <LogIn size={20} className="text-emerald-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-emerald-700">{statsEntrada}</p>
              <p className="text-xs text-emerald-600 font-medium">Entradas</p>
            </div>
          </div>
        </div>
        <div className="bg-linear-to-br from-orange-50 to-orange-100/50 rounded-2xl border border-orange-200/50 p-5">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-orange-200/50 flex items-center justify-center">
              <LogOutIcon size={20} className="text-orange-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-orange-700">{statsSaida}</p>
              <p className="text-xs text-orange-600 font-medium">Saídas</p>
            </div>
          </div>
        </div>
        <div className="bg-linear-to-br from-blue-50 to-indigo-50 rounded-2xl border border-blue-200/50 p-5">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-200/50 flex items-center justify-center">
              <TrendingUp size={20} className="text-blue-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-blue-700">
                {statsEntrada > 0 ? Math.round((statsEntrada / statsTotal) * 100) : 0}%
              </p>
              <p className="text-xs text-blue-600 font-medium">Taxa entrada</p>
            </div>
          </div>
        </div>
      </div>

      {/* ── Date indicator ───────────────────────────────── */}
      <div className="flex items-center gap-2 mb-4 text-sm text-gray-500">
        <CalendarDays size={16} className="text-[#FC5931]" />
        <span className="font-medium">
          Visualizando: <span className="text-gray-800">{filterData ? fmtFilterDate(filterData) : 'Todas as datas'}</span>
        </span>
      </div>

      {/* ── Type Filter Tabs ─────────────────────────────── */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm mb-4">
        <div className="flex">
          {(['todos', 'entrada', 'saida'] as const).map(tipo => {
            const isActive = filterTipo === tipo
            const labels = { todos: 'Todos', entrada: 'Entrada', saida: 'Saída' }
            const icons = {
              todos: <Users size={16} />,
              entrada: <LogIn size={16} />,
              saida: <LogOutIcon size={16} />,
            }
            return (
              <button
                key={tipo}
                onClick={() => applyFilter(setFilterTipo, tipo)}
                className={`flex-1 flex items-center justify-center gap-2 py-3.5 text-sm font-semibold transition-all border-b-2 ${
                  isActive
                    ? 'border-[#FC5931] text-[#FC5931] bg-[#FC5931]/5'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'
                }`}
              >
                {icons[tipo]}
                {labels[tipo]}
              </button>
            )
          })}
        </div>
      </div>

      {/* ── Expandable Filters ───────────────────────────── */}
      <button
        onClick={() => setShowFilters(!showFilters)}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 mb-3 font-medium transition-colors"
      >
        <Filter size={15} />
        Filtros avançados
        <ChevronDown size={14} className={`transition-transform ${showFilters ? 'rotate-180' : ''}`} />
      </button>

      {showFilters && (
        <div className="bg-white rounded-2xl border border-gray-100 p-5 mb-5 shadow-sm">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1.5">{getBlocoLabel(tipoEstrutura)}</label>
              <select
                value={filterBloco}
                onChange={e => { applyFilter(setFilterBloco, e.target.value); setFilterApto('') }}
                title={`Filtrar por ${getBlocoLabel(tipoEstrutura).toLowerCase()}`}
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white"
              >
                <option value="">Todos</option>
                {blocos.map(b => <option key={b} value={b}>{b}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1.5">{getAptoLabel(tipoEstrutura)}</label>
              <select
                value={filterApto}
                onChange={e => applyFilter(setFilterApto, e.target.value)}
                disabled={!filterBloco}
                title={`Filtrar por ${getAptoLabel(tipoEstrutura).toLowerCase()}`}
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white disabled:bg-gray-50 disabled:text-gray-400"
              >
                <option value="">Todos</option>
                {filterAvailableAptos.map(a => <option key={a} value={a}>{a}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1.5">Nome</label>
              <div className="relative">
                <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type="text"
                  value={nameInput}
                  onChange={e => setNameInput(e.target.value)}
                  placeholder="Buscar nome..."
                  className="w-full border border-gray-200 rounded-xl pl-8 pr-3 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                />
              </div>
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1.5">Data</label>
              <input
                type="date"
                value={filterData}
                onChange={e => applyFilter(setFilterData, e.target.value)}
                title="Selecionar data"
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
              />
            </div>
          </div>
          {(filterBloco || filterApto || filterNome || filterData !== todayStr) && (
            <button
              onClick={() => { setPage(0); setFilterBloco(''); setFilterApto(''); setNameInput(''); setFilterNome(''); setFilterData(todayStr) }}
              className="mt-4 text-xs text-[#FC5931] hover:underline font-semibold"
            >
              ✕ Limpar filtros
            </button>
          )}
        </div>
      )}

      {/* ── Visitas Table ────────────────────────────────── */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        {loading ? (
          <div className="p-16 text-center">
            <div className="animate-spin text-4xl mb-3">⏳</div>
            <p className="text-gray-400 font-medium">Carregando...</p>
          </div>
        ) : visitas.length === 0 ? (
          <div className="p-16 text-center">
            <div className="w-16 h-16 bg-[#FC5931]/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <DoorOpen size={32} className="text-[#FC5931]" />
            </div>
            <h3 className="text-lg font-semibold text-gray-800 mb-2">Nenhum registro encontrado</h3>
            <p className="text-gray-500 max-w-sm mx-auto mb-6 text-sm">
              {filterData ? `Não há registros para ${fmtFilterDate(filterData)}.` : 'Registre a primeira entrada ou saída.'}
            </p>
            <button
              onClick={() => setShowModal(true)}
              className="text-[#FC5931] border border-[#FC5931] hover:bg-[#FC5931] hover:text-white px-6 py-2.5 rounded-xl font-medium transition-colors"
            >
              Registrar agora
            </button>
          </div>
        ) : (
          <>
            {/* Desktop table */}
            <div className="hidden md:block overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50/80">
                    <th className="text-left px-5 py-3 font-semibold text-gray-600">Tipo</th>
                    <th className="text-left px-5 py-3 font-semibold text-gray-600">Nome Morador</th>
                    <th className="text-left px-5 py-3 font-semibold text-gray-600">{getBlocoLabel(tipoEstrutura)}</th>
                    <th className="text-left px-5 py-3 font-semibold text-gray-600">{getAptoLabel(tipoEstrutura)}</th>
                    <th className="text-left px-5 py-3 font-semibold text-gray-600">Crachá</th>
                    <th className="text-left px-5 py-3 font-semibold text-gray-600">Horário</th>
                    <th className="text-left px-5 py-3 font-semibold text-gray-600">Data</th>
                    <th className="text-center px-5 py-3 font-semibold text-gray-600 w-16"></th>
                  </tr>
                </thead>
                <tbody>
                  {visitas.map(v => {
                    const isEntrada = v.tipo === 'entrada'
                    return (
                      <tr key={v.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                        <td className="px-5 py-3.5">
                          <span className={`inline-flex items-center gap-1.5 text-xs font-bold px-2.5 py-1 rounded-full ${
                            isEntrada
                              ? 'bg-emerald-100 text-emerald-700'
                              : 'bg-orange-100 text-orange-700'
                          }`}>
                            {isEntrada ? <LogIn size={12} /> : <LogOutIcon size={12} />}
                            {isEntrada ? 'ENTRADA' : 'SAÍDA'}
                          </span>
                        </td>
                        <td className="px-5 py-3.5 font-medium text-gray-800">{v.nome_morador}</td>
                        <td className="px-5 py-3.5 text-gray-600">{v.bloco || '–'}</td>
                        <td className="px-5 py-3.5 text-gray-600">{v.apto || '–'}</td>
                        <td className="px-5 py-3.5">
                          {v.cracha_referencia ? (
                            <span className="inline-flex items-center gap-1 bg-amber-100 text-amber-800 px-2 py-0.5 rounded-lg text-xs font-bold">
                              🪪 {v.cracha_referencia}
                            </span>
                          ) : (
                            <span className="text-gray-300">–</span>
                          )}
                        </td>
                        <td className="px-5 py-3.5 text-gray-600 font-medium">{fmtTime(v.created_at)}</td>
                        <td className="px-5 py-3.5 text-gray-400 text-xs">{fmtDate(v.created_at)}</td>
                        <td className="px-5 py-3.5 text-center">
                          <button
                            onClick={() => handleDelete(v.id)}
                            className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                            title="Excluir registro"
                          >
                            <Trash2 size={16} />
                          </button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>

            {/* Mobile cards */}
            <div className="md:hidden divide-y divide-gray-100">
              {visitas.map(v => {
                const isEntrada = v.tipo === 'entrada'
                return (
                  <div key={v.id} className="p-4 flex items-center gap-3">
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${
                      isEntrada ? 'bg-emerald-100 text-emerald-600' : 'bg-orange-100 text-orange-600'
                    }`}>
                      {isEntrada ? <LogIn size={18} /> : <LogOutIcon size={18} />}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <p className="font-bold text-gray-800 text-sm truncate">{v.nome_morador}</p>
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0 ${
                          isEntrada ? 'bg-emerald-100 text-emerald-700' : 'bg-orange-100 text-orange-700'
                        }`}>
                          {isEntrada ? 'E' : 'S'}
                        </span>
                      </div>
                      <p className="text-xs text-gray-500 mt-0.5">
                        {getBlocoLabel(tipoEstrutura)} {v.bloco || '–'} / {getAptoLabel(tipoEstrutura)} {v.apto || '–'}
                        {v.cracha_referencia && <span className="ml-2">🪪 {v.cracha_referencia}</span>}
                      </p>
                    </div>
                    <div className="text-right shrink-0">
                      <p className="text-sm font-semibold text-gray-700">{fmtTime(v.created_at)}</p>
                      <p className="text-[10px] text-gray-400">{fmtDate(v.created_at)}</p>
                    </div>
                    <button
                      onClick={() => handleDelete(v.id)}
                      className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors shrink-0"
                      title="Excluir"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                )
              })}
            </div>
          </>
        )}
      </div>

      {/* ── Pagination ──────────────────────────────────── */}
      {totalCount > PAGE_SIZE && (
        <div className="flex items-center justify-between mt-5">
          <p className="text-xs text-gray-400">
            {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, totalCount)} de {totalCount}
          </p>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setPage(p => Math.max(0, p - 1))}
              disabled={page === 0}
              className="flex items-center gap-1 px-3 py-2 text-sm font-medium rounded-lg border border-gray-200 text-gray-600 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronLeft size={14} /> Anterior
            </button>
            <span className="text-sm font-medium text-gray-500 px-2">
              {page + 1} / {totalPages}
            </span>
            <button
              onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))}
              disabled={page >= totalPages - 1}
              className="flex items-center gap-1 px-3 py-2 text-sm font-medium rounded-lg border border-gray-200 text-gray-600 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              Próximo <ChevronRight size={14} />
            </button>
          </div>
        </div>
      )}

      {/* ═══════════════════════════════════════════════════ */}
      {/* ── REGISTRATION MODAL ─────────────────────────── */}
      {/* ═══════════════════════════════════════════════════ */}
      {showModal && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4 backdrop-blur-sm">
          <div className="bg-[#f5f5f5] rounded-2xl w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto animate-in fade-in zoom-in-95 duration-200">
            {/* Modal header */}
            <div className="bg-white border-b border-gray-200 px-6 py-4 rounded-t-2xl flex items-center justify-between shadow-sm">
              <h2 className="text-xl font-bold text-gray-800 flex items-center gap-2">
                <DoorOpen size={24} className="text-[#FC5931]" />
                Registrar Visita
              </h2>
              <button
                onClick={resetModal}
                className="text-gray-400 hover:text-gray-600 bg-gray-50 hover:bg-gray-100 p-1.5 rounded-full transition-colors"
                title="Fechar"
              >
                <X size={20} />
              </button>
            </div>

            <div className="p-6 space-y-5">
              {/* Tipo: Entrada / Saída */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">Tipo de Registro</label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setModalTipo('entrada')}
                    className={`flex items-center justify-center gap-2 py-3.5 rounded-xl font-semibold text-sm transition-all border-2 ${
                      modalTipo === 'entrada'
                        ? 'border-emerald-500 bg-emerald-50 text-emerald-700 shadow-sm'
                        : 'border-gray-200 text-gray-500 hover:border-gray-300'
                    }`}
                  >
                    <LogIn size={18} /> Entrada
                  </button>
                  <button
                    type="button"
                    onClick={() => setModalTipo('saida')}
                    className={`flex items-center justify-center gap-2 py-3.5 rounded-xl font-semibold text-sm transition-all border-2 ${
                      modalTipo === 'saida'
                        ? 'border-orange-500 bg-orange-50 text-orange-700 shadow-sm'
                        : 'border-gray-200 text-gray-500 hover:border-gray-300'
                    }`}
                  >
                    <LogOutIcon size={18} /> Saída
                  </button>
                </div>
              </div>

              {/* Bloco / Apto */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-1">{getBlocoLabel(tipoEstrutura)} *</label>
                  <select
                    value={modalBloco}
                    onChange={e => { setModalBloco(e.target.value); setModalApto(''); setModalMoradorId(null); setModalNome('') }}
                    title={`Selecione o ${getBlocoLabel(tipoEstrutura).toLowerCase()}`}
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white"
                  >
                    <option value="">Selecione</option>
                    {blocos.map(b => <option key={b} value={b}>{b}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-1">{getAptoLabel(tipoEstrutura)} *</label>
                  <select
                    value={modalApto}
                    onChange={e => { setModalApto(e.target.value); setModalMoradorId(null); setModalNome('') }}
                    disabled={!modalBloco}
                    title={`Selecione o ${getAptoLabel(tipoEstrutura).toLowerCase()}`}
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white disabled:bg-gray-50 disabled:text-gray-400"
                  >
                    <option value="">Selecione</option>
                    {modalAvailableAptos.map(a => <option key={a} value={a}>{a}</option>)}
                  </select>
                </div>
              </div>

              {/* Moradores da unidade */}
              {modalBloco && modalApto && unitMoradores.length > 0 && (
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Moradores desta unidade
                  </label>
                  <div className="grid grid-cols-2 gap-2 max-h-40 overflow-y-auto">
                    {unitMoradores.map(m => (
                      <button
                        key={m.id}
                        type="button"
                        onClick={() => selectMorador(m)}
                        className={`text-left px-3 py-2.5 rounded-lg text-sm transition-all border truncate ${
                          modalMoradorId === m.id
                            ? 'border-[#FC5931] bg-[#FC5931]/5 text-[#FC5931] font-semibold'
                            : 'border-gray-200 text-gray-700 hover:border-gray-300 hover:bg-gray-50'
                        }`}
                      >
                        <span className="mr-1">{modalMoradorId === m.id ? '✅' : '👤'}</span>
                        {m.nome}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Nome manual */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-1">
                  Nome do morador *
                  {unitMoradores.length > 0 && (
                    <span className="font-normal text-gray-400 ml-1">(ou digite caso não cadastrado)</span>
                  )}
                </label>
                <input
                  type="text"
                  value={modalNome}
                  onChange={e => { setModalNome(e.target.value); setModalMoradorId(null) }}
                  placeholder="Nome do morador"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                />
              </div>

              {/* Crachá / Referência */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-1">
                  Crachá / Referência
                  <span className="font-normal text-gray-400 ml-1">(opcional)</span>
                </label>
                <input
                  type="text"
                  value={modalCracha}
                  onChange={e => setModalCracha(e.target.value)}
                  placeholder="Nº do crachá ou referência"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                />
              </div>

              {/* Error */}
              {error && (
                <div className="flex items-center gap-2 text-red-600 text-sm bg-red-50 p-3 rounded-xl border border-red-100">
                  <AlertCircle size={16} /> {error}
                </div>
              )}

              {/* Actions */}
              <div className="flex items-center gap-3 pt-2">
                <button
                  onClick={handleSave}
                  disabled={isPending || saved}
                  className={`flex-1 py-3 rounded-xl font-bold text-base transition-all flex items-center justify-center gap-2 shadow-lg ${
                    modalTipo === 'entrada'
                      ? 'bg-emerald-600 hover:bg-emerald-700 text-white shadow-emerald-600/20'
                      : 'bg-orange-500 hover:bg-orange-600 text-white shadow-orange-500/20'
                  } disabled:opacity-60`}
                >
                  {isPending ? (
                    <><Clock size={18} className="animate-spin" /> Registrando...</>
                  ) : saved ? (
                    <><CheckCircle size={18} /> Registrado!</>
                  ) : (
                    <>
                      {modalTipo === 'entrada' ? <LogIn size={18} /> : <LogOutIcon size={18} />}
                      Registrar {modalTipo === 'entrada' ? 'Entrada' : 'Saída'}
                    </>
                  )}
                </button>
                <button
                  onClick={resetModal}
                  className="bg-white border border-gray-300 text-gray-700 hover:bg-gray-50 px-6 py-3 rounded-xl font-medium transition-colors"
                >
                  Cancelar
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
