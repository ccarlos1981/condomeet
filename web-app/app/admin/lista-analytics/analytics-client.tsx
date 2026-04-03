'use client'

import { useState, useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  TrendingUp, BarChart3, RefreshCw, Calendar,
  Users, DollarSign, Package, Activity, ArrowUpRight, ArrowDownRight
} from 'lucide-react'

type PriceTrend = {
  date: string
  avg_price: number
  count: number
}

type CategoryStats = {
  category: string
  product_count: number
  avg_price: number
  price_reports: number
}

type GrowthMetric = {
  period: string
  new_users: number
  new_prices: number
  new_alerts: number
}

type TopProduct = {
  name: string
  emoji: string
  reports: number
  avg_price: number
  trend: number // % change
}

export default function AnalyticsDashboardClient() {
  const supabase = createClient()
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState<'trends' | 'categories' | 'growth' | 'products'>('trends')
  const [period, setPeriod] = useState<'7d' | '30d' | '90d'>('30d')

  // Data states
  const [priceTrends, setPriceTrends] = useState<PriceTrend[]>([])
  const [categoryStats, setCategoryStats] = useState<CategoryStats[]>([])
  const [growthMetrics, setGrowthMetrics] = useState<GrowthMetric[]>([])
  const [topProducts, setTopProducts] = useState<TopProduct[]>([])

  // Summary KPIs
  const [totalPrices, setTotalPrices] = useState(0)
  const [totalUsers, setTotalUsers] = useState(0)
  const [avgPriceChange, setAvgPriceChange] = useState(0)
  const [activeAlerts, setActiveAlerts] = useState(0)

  const getDaysAgo = (days: number) => {
    const d = new Date()
    d.setDate(d.getDate() - days)
    return d.toISOString()
  }

  const periodDays = period === '7d' ? 7 : period === '30d' ? 30 : 90

  const loadData = useCallback(async () => {
    setLoading(true)
    try {
      const sinceDate = getDaysAgo(periodDays)

      // 1. All prices in period
      const { data: prices } = await supabase
        .from('lista_prices_raw')
        .select('id, price, created_at, user_id, lista_products_sku(brand, lista_product_variants(variant_name, lista_products_base(name, icon_emoji, category)))')
        .gte('created_at', sinceDate)
        .order('created_at', { ascending: true })

      const priceList = prices ?? []

      // 2. All current prices (for product analysis)
      const { data: currentPrices } = await supabase
        .from('lista_prices_current')
        .select('sku_id, current_price, previous_price, lista_products_sku(lista_product_variants(variant_name, lista_products_base(name, icon_emoji, category)))')

      const currentList = currentPrices ?? []

      // 3. Active alerts
      const { count: alertCount } = await supabase
        .from('lista_price_alerts')
        .select('id', { count: 'exact' })
        .eq('status', 'active')

      // 4. Unique users
      const { data: userPoints } = await supabase
        .from('lista_user_points')
        .select('user_id, total_points, reports_count, created_at')

      const userList = userPoints ?? []

      // ── KPIs ──
      setTotalPrices(priceList.length)
      setTotalUsers(userList.length)
      setActiveAlerts(alertCount ?? 0)

      // Average price change from current prices
      let totalChange = 0
      let changeCount = 0
      for (const cp of currentList) {
        const curr = cp.current_price as number
        const prev = cp.previous_price as number
        if (prev && prev > 0) {
          totalChange += ((curr - prev) / prev) * 100
          changeCount++
        }
      }
      setAvgPriceChange(changeCount > 0 ? totalChange / changeCount : 0)

      // ── Price Trends (group by day) ──
      const dayMap: Record<string, { total: number; count: number }> = {}
      for (const p of priceList) {
        const day = (p.created_at as string).slice(0, 10)
        if (!dayMap[day]) dayMap[day] = { total: 0, count: 0 }
        dayMap[day].total += p.price as number
        dayMap[day].count++
      }
      const trends: PriceTrend[] = Object.entries(dayMap)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([date, data]) => ({
          date,
          avg_price: data.total / data.count,
          count: data.count,
        }))
      setPriceTrends(trends)

      // ── Category Stats ──
      const catMap: Record<string, { products: Set<string>; total: number; count: number }> = {}
      for (const p of priceList) {
        const sku = p.lista_products_sku as { lista_product_variants?: { lista_products_base?: { category?: string; name?: string; icon_emoji?: string } } }
        const base = sku?.lista_product_variants?.lista_products_base
        const cat = base?.category ?? 'Outros'
        if (!catMap[cat]) catMap[cat] = { products: new Set(), total: 0, count: 0 }
        catMap[cat].products.add(base?.name ?? 'unknown')
        catMap[cat].total += p.price as number
        catMap[cat].count++
      }
      const cats: CategoryStats[] = Object.entries(catMap)
        .map(([category, data]) => ({
          category,
          product_count: data.products.size,
          avg_price: data.total / data.count,
          price_reports: data.count,
        }))
        .sort((a, b) => b.price_reports - a.price_reports)
      setCategoryStats(cats)

      // ── Growth Metrics (group by week) ──
      const weekMap: Record<string, { users: Set<string>; prices: number; alerts: number }> = {}
      for (const p of priceList) {
        const date = new Date(p.created_at as string)
        const weekStart = new Date(date)
        weekStart.setDate(date.getDate() - date.getDay())
        const key = weekStart.toISOString().slice(0, 10)
        if (!weekMap[key]) weekMap[key] = { users: new Set(), prices: 0, alerts: 0 }
        weekMap[key].prices++
        weekMap[key].users.add(p.user_id as string)
      }
      const growth: GrowthMetric[] = Object.entries(weekMap)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([period, data]) => ({
          period,
          new_users: data.users.size,
          new_prices: data.prices,
          new_alerts: 0,
        }))
      setGrowthMetrics(growth)

      // ── Top Products ──
      const prodMap: Record<string, { name: string; emoji: string; reports: number; total: number; prevTotal: number; prevCount: number }> = {}
      for (const cp of currentList) {
        const sku = cp.lista_products_sku as { lista_product_variants?: { lista_products_base?: { category?: string; name?: string; icon_emoji?: string } } }
        const base = sku?.lista_product_variants?.lista_products_base
        const name = base?.name ?? 'Produto'
        const emoji = base?.icon_emoji ?? '📦'
        if (!prodMap[name]) prodMap[name] = { name, emoji, reports: 0, total: 0, prevTotal: 0, prevCount: 0 }
        prodMap[name].reports++
        prodMap[name].total += cp.current_price as number
        if (cp.previous_price) {
          prodMap[name].prevTotal += cp.previous_price as number
          prodMap[name].prevCount++
        }
      }
      const prods: TopProduct[] = Object.values(prodMap)
        .map(p => ({
          name: p.name,
          emoji: p.emoji,
          reports: p.reports,
          avg_price: p.reports > 0 ? p.total / p.reports : 0,
          trend: p.prevCount > 0 ? (((p.total / p.reports) - (p.prevTotal / p.prevCount)) / (p.prevTotal / p.prevCount)) * 100 : 0,
        }))
        .sort((a, b) => b.reports - a.reports)
        .slice(0, 20)
      setTopProducts(prods)
    } catch (e) {
      console.error('Analytics load error:', e)
    }
    setLoading(false)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [periodDays])

  useEffect(() => { ;(async () => { await loadData() })() }, [loadData])

  const tabs = [
    { id: 'trends' as const, label: 'Tendências', icon: <TrendingUp size={16} /> },
    { id: 'categories' as const, label: 'Categorias', icon: <BarChart3 size={16} /> },
    { id: 'growth' as const, label: 'Crescimento', icon: <Activity size={16} /> },
    { id: 'products' as const, label: 'Top Produtos', icon: <Package size={16} /> },
  ]

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
            📊 Analytics & Trends
            <span className="text-sm font-normal bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full">Lista Inteligente</span>
          </h1>
          <p className="text-gray-500 text-sm mt-1">Inteligência de preços e tendências do mercado</p>
        </div>
        <div className="flex items-center gap-3">
          {/* Period selector */}
          <div className="flex bg-white rounded-xl border border-gray-200 p-0.5">
            {(['7d', '30d', '90d'] as const).map(p => (
              <button key={p} onClick={() => setPeriod(p)}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                  period === p ? 'bg-[#FC5931] text-white' : 'text-gray-400 hover:text-gray-600'
                }`}>
                {p === '7d' ? '7 dias' : p === '30d' ? '30 dias' : '90 dias'}
              </button>
            ))}
          </div>
          <button onClick={loadData} title="Atualizar" className="p-2.5 bg-white rounded-xl border border-gray-200 text-gray-500 hover:bg-gray-50 transition-colors">
            <RefreshCw size={14} />
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KPICard icon={<DollarSign size={20} className="text-green-600" />}
          value={`${totalPrices}`} label={`Preços (${period})`} color="bg-green-50" />
        <KPICard icon={<Users size={20} className="text-blue-600" />}
          value={`${totalUsers}`} label="Colaboradores Total" color="bg-blue-50" />
        <KPICard icon={<TrendingUp size={20} className="text-orange-600" />}
          value={`${avgPriceChange >= 0 ? '+' : ''}${avgPriceChange.toFixed(1)}%`}
          label="Variação Média" color="bg-orange-50"
          trend={avgPriceChange > 0 ? 'Inflação' : avgPriceChange < 0 ? 'Deflação' : 'Estável'} />
        <KPICard icon={<Activity size={20} className="text-purple-600" />}
          value={`${activeAlerts}`} label="Alertas Ativos" color="bg-purple-50" />
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-white rounded-xl p-1 border border-gray-200">
        {tabs.map(tab => (
          <button key={tab.id} onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all ${
              activeTab === tab.id ? 'bg-[#FC5931] text-white shadow-sm' : 'text-gray-500 hover:bg-gray-100'
            }`}>
            {tab.icon} {tab.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#FC5931]" />
        </div>
      ) : (
        <>
          {activeTab === 'trends' && <TrendsTab data={priceTrends} />}
          {activeTab === 'categories' && <CategoriesTab data={categoryStats} />}
          {activeTab === 'growth' && <GrowthTab data={growthMetrics} />}
          {activeTab === 'products' && <ProductsTab data={topProducts} />}
        </>
      )}
    </div>
  )
}

// ─── Sub-components ─────────────────────────────

function KPICard({ icon, value, label, color, trend }: { icon: React.ReactNode; value: string; label: string; color: string; trend?: string }) {
  return (
    <div className="bg-white rounded-2xl p-5 border border-gray-100 shadow-sm">
      <div className="flex items-center justify-between mb-3">
        <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${color}`}>{icon}</div>
        {trend && (
          <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${
            trend === 'Inflação' ? 'bg-red-100 text-red-600' : trend === 'Deflação' ? 'bg-green-100 text-green-600' : 'bg-gray-100 text-gray-500'
          }`}>{trend}</span>
        )}
      </div>
      <p className="text-2xl font-bold text-gray-800">{value}</p>
      <p className="text-sm text-gray-400 mt-1">{label}</p>
    </div>
  )
}

function TrendsTab({ data }: { data: PriceTrend[] }) {
  const maxPrice = Math.max(...data.map(d => d.avg_price), 1)
  const maxCount = Math.max(...data.map(d => d.count), 1)

  return (
    <div className="space-y-6">
      {/* Price trend chart (CSS bars) */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
        <h3 className="font-semibold text-gray-800 mb-1 flex items-center gap-2">
          <TrendingUp size={18} /> Tendência de Preços Médios
        </h3>
        <p className="text-sm text-gray-400 mb-4">Preço médio reportado por dia</p>
        {data.length > 0 ? (
          <div className="flex items-end gap-1 h-48 overflow-x-auto pb-2">
            {data.map((d, i) => (
              <div key={i} className="flex flex-col items-center min-w-[32px] group">
                <div className="text-[10px] text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity mb-1">
                  R$ {d.avg_price.toFixed(2)}
                </div>
                <div className="w-6 bg-gradient-to-t from-[#FC5931] to-[#FF8A65] rounded-t-md transition-all group-hover:opacity-80"
                  style={{ height: `${(d.avg_price / maxPrice) * 140}px` }} />
                <div className="text-[8px] text-gray-300 mt-1 rotate-[-45deg] origin-top-left whitespace-nowrap">
                  {d.date.slice(5)}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-center text-gray-400 py-10">Sem dados no período</p>
        )}
      </div>

      {/* Volume chart */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
        <h3 className="font-semibold text-gray-800 mb-1 flex items-center gap-2">
          <BarChart3 size={18} /> Volume de Reportes por Dia
        </h3>
        <p className="text-sm text-gray-400 mb-4">Quantidade de preços reportados</p>
        {data.length > 0 ? (
          <div className="flex items-end gap-1 h-36 overflow-x-auto pb-2">
            {data.map((d, i) => (
              <div key={i} className="flex flex-col items-center min-w-[32px] group">
                <div className="text-[10px] text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity mb-1">
                  {d.count}
                </div>
                <div className="w-6 bg-gradient-to-t from-blue-500 to-blue-300 rounded-t-md transition-all group-hover:opacity-80"
                  style={{ height: `${(d.count / maxCount) * 110}px` }} />
                <div className="text-[8px] text-gray-300 mt-1 rotate-[-45deg] origin-top-left whitespace-nowrap">
                  {d.date.slice(5)}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-center text-gray-400 py-10">Sem dados no período</p>
        )}
      </div>
    </div>
  )
}

function CategoriesTab({ data }: { data: CategoryStats[] }) {
  const maxReports = Math.max(...data.map(d => d.price_reports), 1)

  const catEmojis: Record<string, string> = {
    'Grãos & Cereais': '🌾', 'Laticínios': '🧀', 'Carnes': '🥩', 'Bebidas': '🥤',
    'Frutas': '🍎', 'Verduras': '🥬', 'Limpeza': '🧹', 'Higiene': '🧴',
    'Padaria': '🍞', 'Frios': '🧊', 'Temperos': '🧂', 'Doces': '🍬',
    'Congelados': '❄️', 'Outros': '📦',
  }

  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
      <h3 className="font-semibold text-gray-800 mb-4 flex items-center gap-2">
        <BarChart3 size={18} /> Análise por Categoria
      </h3>
      <div className="space-y-3">
        {data.map((c, i) => (
          <div key={i} className="relative">
            <div className="flex items-center gap-3 mb-1">
              <span className="text-lg w-8 text-center">{catEmojis[c.category] ?? '📦'}</span>
              <span className="text-sm font-medium text-gray-700 flex-1">{c.category}</span>
              <span className="text-xs text-gray-400">{c.product_count} produtos</span>
              <span className="text-xs text-gray-400">{c.price_reports} reportes</span>
              <span className="text-sm font-bold text-gray-700 w-24 text-right">R$ {c.avg_price.toFixed(2)}</span>
            </div>
            <div className="ml-11 h-2 bg-gray-100 rounded-full overflow-hidden">
              <div className="h-full bg-gradient-to-r from-[#FC5931] to-[#FF8A65] rounded-full transition-all"
                style={{ width: `${(c.price_reports / maxReports) * 100}%` }} />
            </div>
          </div>
        ))}
        {data.length === 0 && (
          <p className="text-center text-gray-400 py-10">Sem dados de categorias</p>
        )}
      </div>
    </div>
  )
}

function GrowthTab({ data }: { data: GrowthMetric[] }) {
  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
        <h3 className="font-semibold text-gray-800 mb-4 flex items-center gap-2">
          <Activity size={18} /> Crescimento Semanal
        </h3>
        {data.length > 0 ? (
          <table className="w-full">
            <thead>
              <tr className="text-xs text-gray-400 uppercase tracking-wider">
                <th className="text-left px-4 py-2"><Calendar size={12} className="inline mr-1" />Semana</th>
                <th className="text-right px-4 py-2">Colaboradores</th>
                <th className="text-right px-4 py-2">Preços</th>
                <th className="text-right px-4 py-2">Tendência</th>
              </tr>
            </thead>
            <tbody>
              {data.map((g, i) => {
                const prevPrices = i > 0 ? data[i - 1].new_prices : g.new_prices
                const growthPct = prevPrices > 0 ? ((g.new_prices - prevPrices) / prevPrices) * 100 : 0
                return (
                  <tr key={i} className="border-t border-gray-50 hover:bg-gray-50/50">
                    <td className="px-4 py-3 text-sm text-gray-700">
                      {new Date(g.period).toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' })}
                    </td>
                    <td className="px-4 py-3 text-right text-sm">
                      <span className="bg-blue-50 text-blue-600 px-2 py-0.5 rounded-full font-medium">{g.new_users}</span>
                    </td>
                    <td className="px-4 py-3 text-right text-sm font-bold text-gray-700">{g.new_prices}</td>
                    <td className="px-4 py-3 text-right text-sm">
                      <span className={`flex items-center gap-0.5 justify-end font-medium ${
                        growthPct > 0 ? 'text-green-600' : growthPct < 0 ? 'text-red-500' : 'text-gray-400'
                      }`}>
                        {growthPct > 0 ? <ArrowUpRight size={12} /> : growthPct < 0 ? <ArrowDownRight size={12} /> : null}
                        {growthPct !== 0 ? `${Math.abs(growthPct).toFixed(0)}%` : '—'}
                      </span>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        ) : (
          <p className="text-center text-gray-400 py-10">Sem dados de crescimento</p>
        )}
      </div>
    </div>
  )
}

function ProductsTab({ data }: { data: TopProduct[] }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
      <h3 className="font-semibold text-gray-800 mb-4 flex items-center gap-2">
        <Package size={18} /> Top 20 Produtos Mais Monitorados
      </h3>
      <div className="space-y-2">
        {data.map((p, i) => (
          <div key={i} className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 transition-colors">
            <span className="text-sm font-bold text-gray-300 w-6 text-right">#{i + 1}</span>
            <span className="text-xl w-8 text-center">{p.emoji}</span>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-gray-700 truncate">{p.name}</p>
              <p className="text-xs text-gray-400">{p.reports} variantes monitoradas</p>
            </div>
            <div className="text-right">
              <p className="text-sm font-bold text-gray-800">R$ {p.avg_price.toFixed(2)}</p>
              {p.trend !== 0 && (
                <p className={`text-xs flex items-center gap-0.5 justify-end font-medium ${
                  p.trend > 0 ? 'text-red-500' : 'text-green-600'
                }`}>
                  {p.trend > 0 ? <ArrowUpRight size={10} /> : <ArrowDownRight size={10} />}
                  {Math.abs(p.trend).toFixed(1)}%
                </p>
              )}
            </div>
          </div>
        ))}
        {data.length === 0 && (
          <p className="text-center text-gray-400 py-10">Sem dados de produtos</p>
        )}
      </div>
    </div>
  )
}
