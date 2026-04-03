'use client'
import { useState, useTransition, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  LogIn, LogOut as LogOutIcon, Plus, X, Search, Filter,
  CheckCircle, AlertCircle, Clock, Users, ChevronDown
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
  visitas: Visita[]
  condoId: string
  currentUserId: string
  currentUserName: string
  tipoEstrutura?: string
  blocos: string[]
  aptosMap: Record<string, string[]>
  moradoresMap: Record<string, Morador[]>
}

export default function VisitaProprietarioClient({
  visitas: initialVisitas,
  condoId,
  currentUserId,
  // currentUserName,
  tipoEstrutura,
  blocos,
  aptosMap,
  moradoresMap,
}: Props) {
  const supabase = createClient()
  const [isPending, startTransition] = useTransition()

  // ── Pagination ──────────────────────────────────────────
  const PAGE_SIZE = 10
  const [page, setPage] = useState(0)
  const [totalCount, setTotalCount] = useState(0)
  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE))

  // List state
  const [visitas, setVisitas] = useState(initialVisitas)
  const [loading, setLoading] = useState(false)

  // Filter state — default date = today (local timezone)
  const now = new Date()
  const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
  const [filterTipo, setFilterTipo] = useState<'todos' | 'entrada' | 'saida'>('todos')
  const [filterBloco, setFilterBloco] = useState('')
  const [filterApto, setFilterApto] = useState('')
  const [filterNome, setFilterNome] = useState('')
  const [nameInput, setNameInput] = useState('')
  const [filterData, setFilterData] = useState(todayStr)
  const [showFilters, setShowFilters] = useState(false)

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

  // Available aptos based on selected bloco in modal
  const modalAvailableAptos = modalBloco ? (aptosMap[modalBloco] ?? []) : []
  const unitKey = `${modalBloco}|${modalApto}`
  const unitMoradores = moradoresMap[unitKey] ?? []

  // Available aptos for filters
  const filterAvailableAptos = filterBloco ? (aptosMap[filterBloco] ?? []) : []

  // ── Fetch visitas from DB ─────────────────────────────────
  async function fetchVisitas(currentPage = 0) {
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
      const startOfDay = `${filterData}T00:00:00`
      const endOfDay = `${filterData}T23:59:59`
      query = query.gte('created_at', startOfDay).lte('created_at', endOfDay)
    }

    const { data, count } = await query
    setVisitas(data ?? [])
    setTotalCount(count ?? 0)
    setLoading(false)
  }

  // Re-fetch whenever filters or page change
  useEffect(() => {
    fetchVisitas(page)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filterTipo, filterBloco, filterApto, filterNome, filterData, page])

  // Reset page to 0 when filters change
  function applyFilter<T>(setter: React.Dispatch<React.SetStateAction<T>>, value: T) {
    setPage(0)
    setter(value)
  }
  // Debounce name filter (500ms)
  useEffect(() => {
    const timer = setTimeout(() => {
      if (filterNome !== nameInput) {
        setPage(0)
        setFilterNome(nameInput)
      }
    }, 500)
    return () => clearTimeout(timer)
  }, [nameInput, filterNome])

  const filteredVisitas = visitas

  // ── Handle save ───────────────────────────────────────────
  async function handleSave() {
    const nome = modalNome.trim()
    if (!nome) { setError('Informe o nome do morador.'); return }
    if (!modalBloco || !modalApto) { setError(`Selecione o ${getBlocoLabel(tipoEstrutura).toLowerCase()} e ${getAptoLabel(tipoEstrutura).toLowerCase()}.`); return }
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
        .select()
        .single()

      if (insertError) {
        setError('Erro ao registrar: ' + insertError.message)
        return
      }

      // Fire-and-forget: send push notification
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
          }).catch(err => console.error('Push notify error:', err))
        }
      } catch (e) {
        console.error('Push notify error:', e)
      }

      // Re-fetch to update list with pagination
      setSaved(true)
      setTimeout(async () => {
        setSaved(false)
        resetModal()
        await fetchVisitas(page)
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

  function selectMorador(m: Morador) {
    setModalMoradorId(m.id)
    setModalNome(m.nome)
  }

  // ── Helpers ────────────────────────────────────────────────
  /* function fmtDate(iso: string) {
    const d = new Date(iso)
    return d.toLocaleDateString('pt-BR') + ' – ' + d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) + 'h'
  } */

  function fmtDateShort(iso: string) {
    const d = new Date(iso)
    return d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) + 'h'
  }

  const countEntrada = visitas.filter(v => v.tipo === 'entrada').length
  const countSaida = visitas.filter(v => v.tipo === 'saida').length

  // ── Render ─────────────────────────────────────────────────
  return (
    <div className="max-w-5xl mx-auto">
      {/* ── Header ─────────────────────────────────────────── */}
      <div className="mb-6 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            🚪 Visita Proprietário
          </h1>
          <p className="text-sm text-gray-500 mt-1">
            Controle de entrada e saída de moradores
          </p>
        </div>
        <button
          onClick={() => setShowModal(true)}
          className="flex items-center gap-2 bg-[#FC5931] text-white px-5 py-2.5 rounded-xl font-semibold text-sm hover:bg-[#D42F1D] transition-all shadow-lg shadow-[#FC5931]/20 hover:shadow-[#FC5931]/40"
        >
          <Plus size={18} />
          Registrar
        </button>
      </div>

      {/* ── Stats Cards ───────────────────────────────────── */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-white rounded-2xl border border-gray-100 p-4 text-center shadow-sm">
          <div className="text-2xl font-bold text-gray-800">{totalCount}</div>
          <div className="text-xs text-gray-500 font-medium mt-1">Total</div>
        </div>
        <div className="bg-linear-to-br from-emerald-50 to-emerald-100/50 rounded-2xl border border-emerald-200/50 p-4 text-center">
          <div className="text-2xl font-bold text-emerald-700">{countEntrada}</div>
          <div className="text-xs text-emerald-600 font-medium mt-1 flex items-center justify-center gap-1">
            <LogIn size={12} /> Entradas
          </div>
        </div>
        <div className="bg-linear-to-br from-orange-50 to-orange-100/50 rounded-2xl border border-orange-200/50 p-4 text-center">
          <div className="text-2xl font-bold text-orange-700">{countSaida}</div>
          <div className="text-xs text-orange-600 font-medium mt-1 flex items-center justify-center gap-1">
            <LogOutIcon size={12} /> Saídas
          </div>
        </div>
      </div>

      {/* ── Radio Filter: Entrada / Saída / Todos ─────────── */}
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
                className={`flex-1 flex items-center justify-center gap-2 py-3 text-sm font-semibold transition-all border-b-2 ${
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

      {/* ── Expandable Filters ────────────────────────────── */}
      <button
        onClick={() => setShowFilters(!showFilters)}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 mb-3 font-medium transition-colors"
      >
        <Filter size={15} />
        Filtros
        <ChevronDown size={14} className={`transition-transform ${showFilters ? 'rotate-180' : ''}`} />
      </button>

      {showFilters && (
        <div className="bg-white rounded-2xl border border-gray-100 p-4 mb-4 shadow-sm">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1">{getBlocoLabel(tipoEstrutura)}</label>
              <select
                value={filterBloco}
                onChange={e => { applyFilter(setFilterBloco, e.target.value); setFilterApto('') }}
                title={`Filtrar por ${getBlocoLabel(tipoEstrutura).toLowerCase()}`}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white"
              >
                <option value="">Todos</option>
                {blocos.map(b => <option key={b} value={b}>{b}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1">{getAptoLabel(tipoEstrutura)}</label>
              <select
                value={filterApto}
                onChange={e => applyFilter(setFilterApto, e.target.value)}
                disabled={!filterBloco}
                title={`Filtrar por ${getAptoLabel(tipoEstrutura).toLowerCase()}`}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white disabled:bg-gray-50 disabled:text-gray-400"
              >
                <option value="">Todos</option>
                {filterAvailableAptos.map(a => <option key={a} value={a}>{a}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1">Nome</label>
              <div className="relative">
                <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type="text"
                  value={nameInput}
                  onChange={e => setNameInput(e.target.value)}
                  placeholder="Buscar nome..."
                  className="w-full border border-gray-200 rounded-lg pl-8 pr-3 py-2 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                />
              </div>
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1">Data</label>
              <input
                type="date"
                value={filterData}
                onChange={e => applyFilter(setFilterData, e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
              />
            </div>
          </div>
          {(filterBloco || filterApto || filterNome || filterData !== todayStr) && (
            <button
              onClick={() => { setPage(0); setFilterBloco(''); setFilterApto(''); setNameInput(''); setFilterNome(''); setFilterData(todayStr) }}
              className="mt-3 text-xs text-[#FC5931] hover:underline font-medium"
            >
              Limpar filtros
            </button>
          )}
        </div>
      )}

      {/* ── Visitas List ──────────────────────────────────── */}
      <div className="space-y-3">
        {loading ? (
          <div className="bg-white rounded-2xl border border-gray-100 p-12 text-center shadow-sm">
            <div className="animate-spin text-4xl mb-3">⏳</div>
            <p className="text-gray-400 font-medium">Carregando...</p>
          </div>
        ) : filteredVisitas.length === 0 ? (
          <div className="bg-white rounded-2xl border border-gray-100 p-12 text-center shadow-sm">
            <div className="text-4xl mb-3">🚪</div>
            <p className="text-gray-400 font-medium">Nenhum registro encontrado</p>
            <p className="text-gray-300 text-sm mt-1">Registre a primeira entrada ou saída</p>
          </div>
        ) : (
          filteredVisitas.map(v => {
            const isEntrada = v.tipo === 'entrada'
            return (
              <div
                key={v.id}
                className="bg-white rounded-xl border border-gray-100 p-4 flex items-center gap-4 shadow-sm hover:shadow-md transition-shadow"
              >
                {/* Type badge */}
                <div className={`w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${
                  isEntrada
                    ? 'bg-emerald-100 text-emerald-600'
                    : 'bg-orange-100 text-orange-600'
                }`}>
                  {isEntrada ? <LogIn size={20} /> : <LogOutIcon size={20} />}
                </div>

                {/* Info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <p className="font-bold text-gray-800 text-sm truncate">{v.nome_morador}</p>
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                      isEntrada
                        ? 'bg-emerald-100 text-emerald-700'
                        : 'bg-orange-100 text-orange-700'
                    }`}>
                      {isEntrada ? 'ENTRADA' : 'SAÍDA'}
                    </span>
                  </div>
                  <div className="flex items-center gap-3 mt-1">
                    {(v.bloco || v.apto) && (
                      <span className="text-xs text-gray-500">
                        {getBlocoLabel(tipoEstrutura)} {v.bloco || '–'} / {getAptoLabel(tipoEstrutura)} {v.apto || '–'}
                      </span>
                    )}
                  </div>
                </div>

                {/* Crachá badge — prominent center */}
                {v.cracha_referencia && (
                  <div className="flex flex-col items-center gap-0.5 shrink-0 px-2">
                    <div className="bg-linear-to-br from-amber-100 to-amber-200 border border-amber-300 rounded-xl px-4 py-2 flex items-center gap-2 shadow-sm">
                      <span className="text-amber-600 text-base">🪪</span>
                      <span className="text-lg font-extrabold text-amber-800 tracking-wide">{v.cracha_referencia}</span>
                    </div>
                    <span className="text-[9px] text-amber-500 font-semibold uppercase tracking-wider">Crachá</span>
                  </div>
                )}

                {/* Time */}
                <div className="text-right shrink-0">
                  <p className="text-sm font-semibold text-gray-700">{fmtDateShort(v.created_at)}</p>
                  <p className="text-[10px] text-gray-400">{new Date(v.created_at).toLocaleDateString('pt-BR')}</p>
                </div>
              </div>
            )
          })
        )}
      </div>

      {/* ── Pagination ────────────────────────────────────── */}
      {totalCount > 0 && (
        <div className="flex items-center justify-between mt-5">
          <p className="text-xs text-gray-400">
            Mostrando {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, totalCount)} de {totalCount} registro{totalCount !== 1 ? 's' : ''}
          </p>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setPage(p => Math.max(0, p - 1))}
              disabled={page === 0}
              className="px-4 py-2 text-sm font-semibold rounded-lg border border-gray-200 text-gray-600 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              ← Anterior
            </button>
            <span className="text-sm font-medium text-gray-500">
              {page + 1} / {totalPages}
            </span>
            <button
              onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))}
              disabled={page >= totalPages - 1}
              className="px-4 py-2 text-sm font-semibold rounded-lg border border-gray-200 text-gray-600 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              Próximo →
            </button>
          </div>
        </div>
      )}

      {/* ══════════════════════════════════════════════════════ */}
      {/* ── REGISTRATION MODAL ──────────────────────────────── */}
      {/* ══════════════════════════════════════════════════════ */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 backdrop-blur-sm">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto">
            {/* Modal header */}
            <div className="bg-[#FC5931] text-white px-6 py-4 rounded-t-2xl flex items-center justify-between">
              <h2 className="text-lg font-bold">Registrar Visita</h2>
              <button onClick={resetModal} className="text-white/80 hover:text-white transition-colors" title="Fechar">
                <X size={22} />
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
                    className={`flex items-center justify-center gap-2 py-3 rounded-xl font-semibold text-sm transition-all border-2 ${
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
                    className={`flex items-center justify-center gap-2 py-3 rounded-xl font-semibold text-sm transition-all border-2 ${
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
                    className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white"
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
                    className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white disabled:bg-gray-50 disabled:text-gray-400"
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
                  className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
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
                  className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                />
              </div>

              {/* Error */}
              {error && (
                <div className="flex items-center gap-2 text-red-600 text-sm bg-red-50 p-3 rounded-lg">
                  <AlertCircle size={16} /> {error}
                </div>
              )}

              {/* Submit */}
              <button
                onClick={handleSave}
                disabled={isPending || saved}
                className={`w-full py-3.5 rounded-xl font-bold text-base transition-all flex items-center justify-center gap-2 shadow-lg ${
                  modalTipo === 'entrada'
                    ? 'bg-emerald-600 hover:bg-emerald-700 text-white shadow-emerald-600/20'
                    : 'bg-orange-500 hover:bg-orange-600 text-white shadow-orange-500/20'
                } disabled:opacity-60`}
              >
                {isPending ? (
                  <><Clock size={20} className="animate-spin" /> Registrando...</>
                ) : saved ? (
                  <><CheckCircle size={20} /> Registrado com sucesso!</>
                ) : (
                  <>
                    {modalTipo === 'entrada' ? <LogIn size={20} /> : <LogOutIcon size={20} />}
                    Registrar {modalTipo === 'entrada' ? 'Entrada' : 'Saída'}
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
