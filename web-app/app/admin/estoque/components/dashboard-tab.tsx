'use client'

import { useMemo, useState } from 'react'
import type { Produto, Emprestimo, Movimentacao, Local, Categoria } from '../estoque-client'
import { Package, AlertTriangle, XCircle, TrendingDown, HandMetal, Search, Filter, DollarSign, CalendarClock } from 'lucide-react'

export default function DashboardTab({
  produtos,
  emprestimos,
  movimentacoes,
  locais,
  categorias,
}: {
  produtos: Produto[]
  emprestimos: Emprestimo[]
  movimentacoes: Movimentacao[]
  locais: Local[]
  categorias: Categoria[]
}) {
  const [search, setSearch] = useState('')
  const [filterCategoria, setFilterCategoria] = useState('')
  const [filterLocal, setFilterLocal] = useState('')
  const [filterStatus, setFilterStatus] = useState<'' | 'ok' | 'critico' | 'zerado'>('')
  const [page, setPage] = useState(1)
  const perPage = 15

  // KPI calculations
  const stats = useMemo(() => {
    const totalProdutos = produtos.filter(p => p.ativo).length
    const criticos = produtos.filter(p => p.ativo && p.quantidade_atual > 0 && p.quantidade_atual <= p.quantidade_minima).length
    const zerados = produtos.filter(p => p.ativo && p.quantidade_atual === 0).length

    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const saidasHoje = movimentacoes.filter(m => {
      const d = new Date(m.created_at)
      d.setHours(0, 0, 0, 0)
      return d.getTime() === today.getTime() && (m.tipo === 'saida' || m.tipo === 'emprestimo')
    }).length

    const emprestados = emprestimos.filter(e => e.status === 'emprestado').length

    // Valor total do estoque
    const valorTotal = produtos
      .filter(p => p.ativo)
      .reduce((acc, p) => acc + (p.quantidade_atual * (p.custo_unitario || 0)), 0)

    // Produtos vencendo em 30 dias
    const em30dias = new Date()
    em30dias.setDate(em30dias.getDate() + 30)
    const vencendo = produtos.filter(p => {
      if (!p.ativo || !p.data_validade) return false
      const validade = new Date(p.data_validade)
      return validade <= em30dias && validade >= today
    }).length

    return { totalProdutos, criticos, zerados, saidasHoje, emprestados, valorTotal, vencendo }
  }, [produtos, movimentacoes, emprestimos])

  // Filtered products
  const filtered = useMemo(() => {
    return produtos.filter(p => {
      if (!p.ativo) return false
      if (search && !p.nome.toLowerCase().includes(search.toLowerCase())) return false
      if (filterCategoria && p.categoria_id !== filterCategoria) return false
      if (filterLocal && p.local_id !== filterLocal) return false
      if (filterStatus === 'ok' && (p.quantidade_atual <= p.quantidade_minima || p.quantidade_atual === 0)) return false
      if (filterStatus === 'critico' && !(p.quantidade_atual > 0 && p.quantidade_atual <= p.quantidade_minima)) return false
      if (filterStatus === 'zerado' && p.quantidade_atual !== 0) return false
      return true
    })
  }, [produtos, search, filterCategoria, filterLocal, filterStatus])

  const totalPages = Math.max(1, Math.ceil(filtered.length / perPage))
  const paginated = filtered.slice((page - 1) * perPage, page * perPage)

  const getStatus = (p: Produto) => {
    if (p.quantidade_atual === 0) return { label: 'Zerado', color: 'bg-gray-800 text-white', dot: 'bg-gray-800' }
    if (p.quantidade_atual <= p.quantidade_minima) return { label: 'Crítico', color: 'bg-red-100 text-red-700', dot: 'bg-red-500' }
    return { label: 'OK', color: 'bg-emerald-100 text-emerald-700', dot: 'bg-emerald-500' }
  }

  const getTipoLabel = (t: string) => {
    if (t === 'consumivel') return '🧴 Consumível'
    if (t === 'retornavel') return '🔄 Retornável'
    return '🔀 Misto'
  }

  return (
    <div className="space-y-6">
      {/* KPI Cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7 gap-3">
        <KpiCard
          label="TT Prod. estoque"
          value={stats.totalProdutos}
          icon={<Package size={20} />}
          color="bg-blue-50 text-blue-600"
          iconBg="bg-blue-100"
        />
        <KpiCard
          label="Estoques críticos"
          value={stats.criticos}
          icon={<AlertTriangle size={20} />}
          color="bg-red-50 text-red-600"
          iconBg="bg-red-100"
          pulse={stats.criticos > 0}
        />
        <KpiCard
          label="Estoque zerado"
          value={stats.zerados}
          icon={<XCircle size={20} />}
          color="bg-gray-50 text-gray-700"
          iconBg="bg-gray-200"
          pulse={stats.zerados > 0}
        />
        <KpiCard
          label="Saídas hoje"
          value={stats.saidasHoje}
          icon={<TrendingDown size={20} />}
          color="bg-orange-50 text-orange-600"
          iconBg="bg-orange-100"
        />
        <KpiCard
          label="Itens emprestados"
          value={stats.emprestados}
          icon={<HandMetal size={20} />}
          color="bg-purple-50 text-purple-600"
          iconBg="bg-purple-100"
        />
        <KpiCard
          label="Valor em estoque"
          value={`R$ ${stats.valorTotal.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`}
          icon={<DollarSign size={20} />}
          color="bg-emerald-50 text-emerald-600"
          iconBg="bg-emerald-100"
        />
        {stats.vencendo > 0 && (
          <KpiCard
            label="Vencendo em 30 dias"
            value={stats.vencendo}
            icon={<CalendarClock size={20} />}
            color="bg-amber-50 text-amber-600"
            iconBg="bg-amber-100"
            pulse
          />
        )}
      </div>

      {/* Table Card */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="p-4 border-b border-gray-100">
          <h2 className="font-bold text-gray-800 text-lg mb-3">Controle de Estoque – Produtos</h2>
          <div className="flex flex-wrap gap-3">
            {/* Search */}
            <div className="relative flex-1 min-w-[200px]">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type="text"
                placeholder="Buscar produto..."
                value={search}
                onChange={e => { setSearch(e.target.value); setPage(1) }}
                className="w-full pl-9 pr-4 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all"
              />
            </div>
            {/* Filter by category */}
            <select
              value={filterCategoria}
              onChange={e => { setFilterCategoria(e.target.value); setPage(1) }}
              title="Filtrar por categoria"
              className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-gray-50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 min-w-[140px]"
            >
              <option value="">Todas Categorias</option>
              {categorias.filter(c => c.ativo).map(c => (
                <option key={c.id} value={c.id}>{c.nome}</option>
              ))}
            </select>
            {/* Filter by local */}
            <select
              value={filterLocal}
              onChange={e => { setFilterLocal(e.target.value); setPage(1) }}
              title="Filtrar por local"
              className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-gray-50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 min-w-[140px]"
            >
              <option value="">Todos Locais</option>
              {locais.filter(l => l.ativo).map(l => (
                <option key={l.id} value={l.id}>{l.nome}</option>
              ))}
            </select>
            {/* Filter by status */}
            <select
              value={filterStatus}
              onChange={e => { setFilterStatus(e.target.value as typeof filterStatus); setPage(1) }}
              title="Filtrar por status"
              className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-gray-50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 min-w-[120px]"
            >
              <option value="">Todos Status</option>
              <option value="ok">✅ OK</option>
              <option value="critico">🔴 Crítico</option>
              <option value="zerado">⚫ Zerado</option>
            </select>
            {(search || filterCategoria || filterLocal || filterStatus) && (
              <button
                onClick={() => { setSearch(''); setFilterCategoria(''); setFilterLocal(''); setFilterStatus(''); setPage(1) }}
                className="flex items-center gap-1.5 text-xs text-gray-500 hover:text-red-500 transition-colors px-3 py-2 border border-gray-200 rounded-xl hover:border-red-200"
              >
                <Filter size={14} />
                Limpar filtros
              </button>
            )}
          </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="bg-gray-50 text-gray-500 text-xs uppercase tracking-wider">
                <th className="px-4 py-3 font-semibold">Produto</th>
                <th className="px-4 py-3 font-semibold">Estoque</th>
                <th className="px-4 py-3 font-semibold hidden lg:table-cell">Categoria</th>
                <th className="px-4 py-3 font-semibold text-center">Quantidade</th>
                <th className="px-4 py-3 font-semibold text-center hidden md:table-cell">Mín / Máx</th>
                <th className="px-4 py-3 font-semibold text-center hidden lg:table-cell">Custo Unit.</th>
                <th className="px-4 py-3 font-semibold hidden xl:table-cell">Tipo</th>
                <th className="px-4 py-3 font-semibold text-center">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {paginated.length === 0 ? (
                <tr>
                  <td colSpan={8} className="px-4 py-12 text-center text-gray-400">
                    <Package size={40} className="mx-auto mb-3 opacity-30" />
                    <p className="font-medium">Nenhum produto encontrado</p>
                    <p className="text-xs mt-1">Cadastre produtos na aba &quot;ADD PRODUTO&quot;</p>
                  </td>
                </tr>
              ) : paginated.map(p => {
                const status = getStatus(p)
                const isCritical = p.quantidade_atual <= p.quantidade_minima && p.quantidade_atual > 0
                const isZero = p.quantidade_atual === 0
                return (
                  <tr
                    key={p.id}
                    className={`hover:bg-gray-50 transition-colors ${
                      isZero ? 'bg-gray-50/80' : isCritical ? 'bg-red-50/40' : ''
                    }`}
                  >
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        {p.foto_url ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={p.foto_url} alt={p.nome} className="w-9 h-9 rounded-lg object-cover border border-gray-200" />
                        ) : (
                          <div className="w-9 h-9 rounded-lg bg-gray-100 flex items-center justify-center">
                            <Package size={16} className="text-gray-400" />
                          </div>
                        )}
                        <div>
                          <p className="font-semibold text-gray-800">{p.nome}</p>
                          {p.marca && <p className="text-xs text-gray-400">{p.marca}</p>}
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-gray-600">{p.estoque_locais?.nome || '—'}</td>
                    <td className="px-4 py-3 text-gray-600 hidden lg:table-cell">{p.estoque_categorias?.nome || '—'}</td>
                    <td className="px-4 py-3 text-center">
                      <span className={`font-bold text-lg ${isZero ? 'text-gray-400' : isCritical ? 'text-red-600' : 'text-gray-800'}`}>
                        {p.quantidade_atual}
                      </span>
                      <span className="text-xs text-gray-400 ml-1">{p.unidade}</span>
                    </td>
                    <td className="px-4 py-3 text-center text-gray-500 hidden md:table-cell">
                      {p.quantidade_minima}{p.quantidade_maxima > 0 ? ` / ${p.quantidade_maxima}` : ''}
                    </td>
                    <td className="px-4 py-3 text-center text-gray-500 hidden lg:table-cell">
                      {p.custo_unitario > 0 ? `R$ ${p.custo_unitario.toFixed(2)}` : '—'}
                    </td>
                    <td className="px-4 py-3 hidden xl:table-cell">
                      <span className="text-xs">{getTipoLabel(p.tipo_controle)}</span>
                    </td>
                    <td className="px-4 py-3 text-center">
                      <div className="flex flex-col items-center gap-1">
                        <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold ${status.color} ${isCritical ? 'animate-pulse' : ''}`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${status.dot}`} />
                          {status.label}
                        </span>
                        {p.data_validade && (() => {
                          const val = new Date(p.data_validade)
                          const now = new Date()
                          const diffDays = Math.ceil((val.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
                          if (diffDays < 0) return <span className="text-[10px] text-red-600 font-bold">⛔ VENCIDO</span>
                          if (diffDays <= 30) return <span className="text-[10px] text-amber-600">⏰ Vence em {diffDays}d</span>
                          return null
                        })()}
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-center gap-2 p-4 border-t border-gray-100">
            <button
              onClick={() => setPage(p => Math.max(1, p - 1))}
              disabled={page === 1}
              className="px-3 py-1.5 text-sm rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              ‹
            </button>
            <span className="text-sm text-gray-500">{page} de {totalPages}</span>
            <button
              onClick={() => setPage(p => Math.min(totalPages, p + 1))}
              disabled={page === totalPages}
              className="px-3 py-1.5 text-sm rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              ›
            </button>
          </div>
        )}
      </div>
    </div>
  )
}

function KpiCard({
  label,
  value,
  icon,
  color,
  iconBg,
  pulse = false,
}: {
  label: string
  value: number | string
  icon: React.ReactNode
  color: string
  iconBg: string
  pulse?: boolean
}) {
  return (
    <div className={`${color} rounded-2xl p-4 transition-all hover:scale-[1.02] ${pulse ? 'ring-2 ring-red-300 ring-offset-2' : ''}`}>
      <div className="flex items-center justify-between mb-2">
        <div className={`${iconBg} p-2 rounded-xl`}>{icon}</div>
      </div>
      <p className={`text-2xl md:text-3xl font-bold ${pulse ? 'animate-pulse' : ''}`}>{value}</p>
      <p className="text-xs font-medium opacity-70 mt-1">{label}</p>
    </div>
  )
}
