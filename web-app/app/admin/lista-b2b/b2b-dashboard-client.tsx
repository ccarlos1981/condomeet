'use client'

import { useState, useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Store, TrendingUp, TrendingDown, DollarSign, Users,
  BarChart3, RefreshCw, ChevronDown, Package, Target,
  Percent, ArrowUpRight, ArrowDownRight, Minus
} from 'lucide-react'

type Market = { id: string; name: string }

type MarketStats = {
  total_prices: number
  avg_price: number
  total_products: number
  unique_reporters: number
  cheapest_count: number
  most_expensive_count: number
}

type PriceComparison = {
  product_name: string
  variant_name: string
  emoji: string
  my_price: number
  avg_market_price: number
  diff_percent: number
  position: 'cheapest' | 'competitive' | 'expensive'
}

type PromoData = {
  id: string
  product_name: string
  original_price: number
  promo_price: number
  discount_pct: number
  valid_until: string
}

export default function B2BDashboardClient({ supermarkets }: { supermarkets: Market[] }) {
  const supabase = createClient()
  const [selectedMarket, setSelectedMarket] = useState<string>(supermarkets[0]?.id ?? '')
  const [marketStats, setMarketStats] = useState<MarketStats | null>(null)
  const [comparisons, setComparisons] = useState<PriceComparison[]>([])
  const [promotions, setPromotions] = useState<PromoData[]>([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState<'overview' | 'prices' | 'competitive' | 'promos'>('overview')

  // Promo form
  const [showPromoForm, setShowPromoForm] = useState(false)
  const [promoProduct, setPromoProduct] = useState('')
  const [promoOrigPrice, setPromoOrigPrice] = useState('')
  const [promoNewPrice, setPromoNewPrice] = useState('')
  const [promoValidUntil, setPromoValidUntil] = useState('')

  const loadData = useCallback(async () => {
    if (!selectedMarket) return
    setLoading(true)
    try {
      // 1. Get all prices for this supermarket
      const { data: prices } = await supabase
        .from('lista_prices_raw')
        .select('id, price, user_id, sku_id, created_at, lista_products_sku(brand, weight_label, lista_product_variants(variant_name, lista_products_base(name, icon_emoji)))')
        .eq('supermarket_id', selectedMarket)
        .order('created_at', { ascending: false })

      const priceList = prices ?? []

      // 2. Get all current prices across ALL markets for comparison
      const { data: allPrices } = await supabase
        .from('lista_prices_current')
        .select('sku_id, supermarket_id, current_price, lista_products_sku(lista_product_variants(variant_name, lista_products_base(name, icon_emoji)))')

      const allPriceList = allPrices ?? []

      // 3. Compute per-market stats
      const uniqueReporters = new Set(priceList.map(p => p.user_id)).size
      const uniqueProducts = new Set(priceList.map(p => p.sku_id)).size
      const avgPrice = priceList.length > 0
        ? priceList.reduce((sum, p) => sum + (p.price ?? 0), 0) / priceList.length
        : 0

      // Count how many products this market is cheapest for
      const skuPriceMap: Record<string, { myPrice: number; allPrices: number[] }> = {}
      for (const p of allPriceList) {
        const skuId = p.sku_id as string
        if (!skuPriceMap[skuId]) skuPriceMap[skuId] = { myPrice: 0, allPrices: [] }
        skuPriceMap[skuId].allPrices.push(p.current_price as number)
        if (p.supermarket_id === selectedMarket) {
          skuPriceMap[skuId].myPrice = p.current_price as number
        }
      }

      let cheapestCount = 0
      let expensiveCount = 0
      const comparisonList: PriceComparison[] = []

      for (const [skuId, data] of Object.entries(skuPriceMap)) {
        if (data.myPrice === 0) continue
        const avgMarket = data.allPrices.reduce((a, b) => a + b, 0) / data.allPrices.length
        const diffPct = ((data.myPrice - avgMarket) / avgMarket) * 100
        const minPrice = Math.min(...data.allPrices)
        const maxPrice = Math.max(...data.allPrices)

        const position: 'cheapest' | 'competitive' | 'expensive' =
          data.myPrice <= minPrice ? 'cheapest' : data.myPrice >= maxPrice ? 'expensive' : 'competitive'

        if (position === 'cheapest') cheapestCount++
        if (position === 'expensive') expensiveCount++

        // Find product info
        const priceRow = allPriceList.find(p => p.sku_id === skuId && p.supermarket_id === selectedMarket) as any
        const base = priceRow?.lista_products_sku?.lista_product_variants?.lista_products_base
        const variant = priceRow?.lista_products_sku?.lista_product_variants

        comparisonList.push({
          product_name: base?.name ?? 'Produto',
          variant_name: variant?.variant_name ?? '',
          emoji: base?.icon_emoji ?? '📦',
          my_price: data.myPrice,
          avg_market_price: avgMarket,
          diff_percent: diffPct,
          position,
        })
      }

      // Sort: cheapest first
      comparisonList.sort((a, b) => a.diff_percent - b.diff_percent)

      setMarketStats({
        total_prices: priceList.length,
        avg_price: avgPrice,
        total_products: uniqueProducts,
        unique_reporters: uniqueReporters,
        cheapest_count: cheapestCount,
        most_expensive_count: expensiveCount,
      })
      setComparisons(comparisonList)

      // 4. Get promotions
      const { data: promos } = await supabase
        .from('lista_promotions')
        .select('*')
        .eq('supermarket_id', selectedMarket)
        .order('created_at', { ascending: false })
        .limit(20)

      setPromotions((promos ?? []).map((p: any) => ({
        id: p.id,
        product_name: p.product_name ?? p.description ?? 'Promoção',
        original_price: p.original_price ?? 0,
        promo_price: p.promo_price ?? 0,
        discount_pct: p.discount_pct ?? 0,
        valid_until: p.valid_until ?? '',
      })))
    } catch (e) {
      console.error('B2B load error:', e)
    }
    setLoading(false)
  }, [selectedMarket])

  useEffect(() => { loadData() }, [loadData])

  const handleCreatePromo = async () => {
    if (!promoProduct.trim() || !promoNewPrice) return
    const orig = parseFloat(promoOrigPrice) || 0
    const promo = parseFloat(promoNewPrice) || 0
    const discount = orig > 0 ? Math.round(((orig - promo) / orig) * 100) : 0

    await supabase.from('lista_promotions').insert({
      supermarket_id: selectedMarket,
      product_name: promoProduct.trim(),
      description: `${promoProduct.trim()} por R$ ${promo.toFixed(2)}`,
      original_price: orig,
      promo_price: promo,
      discount_pct: discount,
      valid_until: promoValidUntil || null,
      is_active: true,
    })
    setShowPromoForm(false)
    setPromoProduct('')
    setPromoOrigPrice('')
    setPromoNewPrice('')
    setPromoValidUntil('')
    loadData()
  }

  const tabs = [
    { id: 'overview' as const, label: 'Visão Geral', icon: <BarChart3 size={16} /> },
    { id: 'prices' as const, label: 'Meus Preços', icon: <DollarSign size={16} /> },
    { id: 'competitive' as const, label: 'Competitivo', icon: <Target size={16} /> },
    { id: 'promos' as const, label: 'Promoções', icon: <Percent size={16} /> },
  ]

  const selectedName = supermarkets.find(m => m.id === selectedMarket)?.name ?? 'Mercado'

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
            🏪 Dashboard B2B
            <span className="text-sm font-normal bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full">Mercados</span>
          </h1>
          <p className="text-gray-500 text-sm mt-1">Inteligência de preços para supermercados parceiros</p>
        </div>
        <div className="flex items-center gap-3">
          {/* Market selector */}
          <div className="relative">
            <select
              value={selectedMarket}
              onChange={e => setSelectedMarket(e.target.value)}
              title="Selecionar Mercado"
              className="appearance-none bg-white border border-gray-200 rounded-xl px-4 py-2.5 pr-10 text-sm font-medium text-gray-700 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none cursor-pointer"
            >
              {supermarkets.map(m => (
                <option key={m.id} value={m.id}>{m.name}</option>
              ))}
            </select>
            <ChevronDown size={14} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
          </div>
          <button onClick={loadData} className="p-2.5 bg-white rounded-xl border border-gray-200 text-gray-500 hover:bg-gray-50 transition-colors">
            <RefreshCw size={14} />
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-white rounded-xl p-1 border border-gray-200">
        {tabs.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all ${
              activeTab === tab.id ? 'bg-[#FC5931] text-white shadow-sm' : 'text-gray-500 hover:bg-gray-100'
            }`}
          >
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
          {activeTab === 'overview' && <OverviewTab stats={marketStats!} marketName={selectedName} comparisons={comparisons} />}
          {activeTab === 'prices' && <PricesTab comparisons={comparisons} marketName={selectedName} />}
          {activeTab === 'competitive' && <CompetitiveTab comparisons={comparisons} marketName={selectedName} />}
          {activeTab === 'promos' && (
            <PromosTab
              promotions={promotions}
              marketName={selectedName}
              showForm={showPromoForm}
              onToggleForm={() => setShowPromoForm(!showPromoForm)}
              promoProduct={promoProduct}
              onPromoProductChange={setPromoProduct}
              promoOrigPrice={promoOrigPrice}
              onPromoOrigPriceChange={setPromoOrigPrice}
              promoNewPrice={promoNewPrice}
              onPromoNewPriceChange={setPromoNewPrice}
              promoValidUntil={promoValidUntil}
              onPromoValidUntilChange={setPromoValidUntil}
              onCreatePromo={handleCreatePromo}
            />
          )}
        </>
      )}
    </div>
  )
}

// ─── Sub-components ─────────────────────────────────

function KPICard({ icon, value, label, trend, color }: {
  icon: React.ReactNode; value: string; label: string; trend?: string; color: string
}) {
  return (
    <div className="bg-white rounded-2xl p-5 border border-gray-100 shadow-sm">
      <div className="flex items-center justify-between mb-3">
        <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${color}`}>
          {icon}
        </div>
        {trend && (
          <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${
            trend.startsWith('+') ? 'bg-green-100 text-green-600' :
            trend.startsWith('-') ? 'bg-red-100 text-red-600' : 'bg-gray-100 text-gray-500'
          }`}>{trend}</span>
        )}
      </div>
      <p className="text-2xl font-bold text-gray-800">{value}</p>
      <p className="text-sm text-gray-400 mt-1">{label}</p>
    </div>
  )
}

function OverviewTab({ stats, marketName, comparisons }: { stats: MarketStats; marketName: string; comparisons: PriceComparison[] }) {
  const cheapPct = comparisons.length > 0
    ? Math.round((stats.cheapest_count / comparisons.length) * 100)
    : 0

  return (
    <div className="space-y-6">
      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KPICard
          icon={<DollarSign size={20} className="text-green-600" />}
          value={`R$ ${stats.avg_price.toFixed(2)}`}
          label="Preço Médio"
          color="bg-green-50"
        />
        <KPICard
          icon={<Package size={20} className="text-blue-600" />}
          value={`${stats.total_products}`}
          label="Produtos Cotados"
          color="bg-blue-50"
        />
        <KPICard
          icon={<Users size={20} className="text-purple-600" />}
          value={`${stats.unique_reporters}`}
          label="Colaboradores"
          color="bg-purple-50"
        />
        <KPICard
          icon={<Target size={20} className="text-orange-600" />}
          value={`${cheapPct}%`}
          label="Preço Mais Barato"
          trend={cheapPct >= 50 ? '🏆 Líder' : undefined}
          color="bg-orange-50"
        />
      </div>

      {/* Competitive summary */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
        <h3 className="font-semibold text-gray-800 mb-4 flex items-center gap-2">
          <Store size={18} /> Posição Competitiva — {marketName}
        </h3>
        <div className="grid grid-cols-3 gap-4">
          <div className="text-center p-4 bg-green-50 rounded-xl">
            <p className="text-3xl font-bold text-green-600">{stats.cheapest_count}</p>
            <p className="text-sm text-green-700 mt-1">Mais Barato</p>
          </div>
          <div className="text-center p-4 bg-gray-50 rounded-xl">
            <p className="text-3xl font-bold text-gray-600">{comparisons.length - stats.cheapest_count - stats.most_expensive_count}</p>
            <p className="text-sm text-gray-500 mt-1">Competitivo</p>
          </div>
          <div className="text-center p-4 bg-red-50 rounded-xl">
            <p className="text-3xl font-bold text-red-500">{stats.most_expensive_count}</p>
            <p className="text-sm text-red-600 mt-1">Mais Caro</p>
          </div>
        </div>
      </div>

      {/* Top 5 opportunities */}
      {comparisons.filter(c => c.position === 'expensive').length > 0 && (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
          <h3 className="font-semibold text-gray-800 mb-4 flex items-center gap-2">
            <TrendingDown size={18} /> Oportunidades de Desconto
          </h3>
          <p className="text-sm text-gray-400 mb-3">Produtos em que {marketName} está acima da média — baixar preço pode atrair clientes.</p>
          <div className="space-y-2">
            {comparisons.filter(c => c.position === 'expensive').slice(0, 5).map((c, i) => (
              <div key={i} className="flex items-center gap-3 p-3 bg-red-50/50 rounded-xl">
                <span className="text-lg">{c.emoji}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-700 truncate">{c.product_name} {c.variant_name}</p>
                  <p className="text-xs text-gray-400">Média: R$ {c.avg_market_price.toFixed(2)}</p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-bold text-red-600">R$ {c.my_price.toFixed(2)}</p>
                  <p className="text-xs text-red-500 flex items-center gap-0.5 justify-end">
                    <ArrowUpRight size={10} /> +{c.diff_percent.toFixed(1)}%
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function PricesTab({ comparisons, marketName }: { comparisons: PriceComparison[]; marketName: string }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
      <div className="p-5 border-b border-gray-100">
        <h2 className="font-semibold text-gray-800 flex items-center gap-2">
          <DollarSign size={18} /> Preços de {marketName} ({comparisons.length} produtos)
        </h2>
      </div>
      <table className="w-full">
        <thead>
          <tr className="text-xs text-gray-400 uppercase tracking-wider">
            <th className="w-10"></th>
            <th className="text-left px-5 py-3">Produto</th>
            <th className="text-right px-5 py-3">Seu Preço</th>
            <th className="text-right px-5 py-3">Média Mercado</th>
            <th className="text-right px-5 py-3">Diferença</th>
            <th className="text-center px-5 py-3">Posição</th>
          </tr>
        </thead>
        <tbody>
          {comparisons.map((c, i) => (
            <tr key={i} className="border-t border-gray-50 hover:bg-gray-50/50">
              <td className="pl-5 text-lg">{c.emoji}</td>
              <td className="px-5 py-3 text-sm text-gray-700">{c.product_name} {c.variant_name}</td>
              <td className="px-5 py-3 text-right text-sm font-bold text-gray-800">R$ {c.my_price.toFixed(2)}</td>
              <td className="px-5 py-3 text-right text-sm text-gray-400">R$ {c.avg_market_price.toFixed(2)}</td>
              <td className="px-5 py-3 text-right text-sm">
                <span className={`flex items-center gap-0.5 justify-end font-medium ${
                  c.diff_percent < 0 ? 'text-green-600' : c.diff_percent > 0 ? 'text-red-500' : 'text-gray-500'
                }`}>
                  {c.diff_percent < 0 ? <ArrowDownRight size={12} /> : c.diff_percent > 0 ? <ArrowUpRight size={12} /> : <Minus size={12} />}
                  {Math.abs(c.diff_percent).toFixed(1)}%
                </span>
              </td>
              <td className="px-5 py-3 text-center">
                <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                  c.position === 'cheapest' ? 'bg-green-100 text-green-700' :
                  c.position === 'expensive' ? 'bg-red-100 text-red-600' : 'bg-gray-100 text-gray-500'
                }`}>
                  {c.position === 'cheapest' ? '🏆 Mais Barato' : c.position === 'expensive' ? '⚠️ Caro' : '➖ Médio'}
                </span>
              </td>
            </tr>
          ))}
          {comparisons.length === 0 && (
            <tr><td colSpan={6} className="px-5 py-10 text-center text-gray-400 text-sm">Nenhum preço disponível para este mercado</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}

function CompetitiveTab({ comparisons, marketName }: { comparisons: PriceComparison[]; marketName: string }) {
  const cheapest = comparisons.filter(c => c.position === 'cheapest')
  const competitive = comparisons.filter(c => c.position === 'competitive')
  const expensive = comparisons.filter(c => c.position === 'expensive')

  return (
    <div className="space-y-6">
      {/* Summary bar */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
        <h3 className="font-semibold text-gray-800 mb-4">Análise Competitiva de {marketName}</h3>
        {comparisons.length > 0 && (
          <div className="w-full h-8 rounded-full overflow-hidden flex">
            {cheapest.length > 0 && (
              <div className="bg-green-400 h-full flex items-center justify-center text-xs font-bold text-white"
                style={{ width: `${(cheapest.length / comparisons.length) * 100}%` }}>
                {cheapest.length}
              </div>
            )}
            {competitive.length > 0 && (
              <div className="bg-gray-300 h-full flex items-center justify-center text-xs font-bold text-gray-600"
                style={{ width: `${(competitive.length / comparisons.length) * 100}%` }}>
                {competitive.length}
              </div>
            )}
            {expensive.length > 0 && (
              <div className="bg-red-400 h-full flex items-center justify-center text-xs font-bold text-white"
                style={{ width: `${(expensive.length / comparisons.length) * 100}%` }}>
                {expensive.length}
              </div>
            )}
          </div>
        )}
        <div className="flex justify-between mt-2 text-xs text-gray-400">
          <span>🟢 Mais barato ({cheapest.length})</span>
          <span>⚪ Competitivo ({competitive.length})</span>
          <span>🔴 Mais caro ({expensive.length})</span>
        </div>
      </div>

      {/* Strengths */}
      {cheapest.length > 0 && (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
          <h3 className="font-semibold text-green-700 mb-3 flex items-center gap-2"><TrendingDown size={18} /> Pontos Fortes</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            {cheapest.map((c, i) => (
              <div key={i} className="flex items-center gap-3 p-3 bg-green-50/50 rounded-xl">
                <span className="text-lg">{c.emoji}</span>
                <span className="text-sm text-gray-700 flex-1 truncate">{c.product_name} {c.variant_name}</span>
                <span className="text-xs text-green-600 font-bold">{c.diff_percent.toFixed(1)}%</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Weaknesses */}
      {expensive.length > 0 && (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
          <h3 className="font-semibold text-red-600 mb-3 flex items-center gap-2"><TrendingUp size={18} /> Oportunidades</h3>
          <p className="text-sm text-gray-400 mb-3">Reduzir estes preços pode atrair mais clientes da região.</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            {expensive.map((c, i) => (
              <div key={i} className="flex items-center gap-3 p-3 bg-red-50/50 rounded-xl">
                <span className="text-lg">{c.emoji}</span>
                <span className="text-sm text-gray-700 flex-1 truncate">{c.product_name} {c.variant_name}</span>
                <span className="text-xs text-red-500 font-bold">+{c.diff_percent.toFixed(1)}%</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function PromosTab({ promotions, marketName, showForm, onToggleForm, promoProduct, onPromoProductChange, promoOrigPrice, onPromoOrigPriceChange, promoNewPrice, onPromoNewPriceChange, promoValidUntil, onPromoValidUntilChange, onCreatePromo }: {
  promotions: PromoData[]; marketName: string; showForm: boolean
  onToggleForm: () => void
  promoProduct: string; onPromoProductChange: (v: string) => void
  promoOrigPrice: string; onPromoOrigPriceChange: (v: string) => void
  promoNewPrice: string; onPromoNewPriceChange: (v: string) => void
  promoValidUntil: string; onPromoValidUntilChange: (v: string) => void
  onCreatePromo: () => void
}) {
  return (
    <div className="space-y-4">
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold text-gray-800 flex items-center gap-2">
            <Percent size={18} /> Promoções de {marketName}
          </h3>
          <button onClick={onToggleForm}
            className="flex items-center gap-2 px-4 py-2 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04e28] transition-colors">
            + Nova Promoção
          </button>
        </div>

        {showForm && (
          <div className="bg-gray-50 rounded-xl p-4 mb-4 space-y-3">
            <input placeholder="Produto (ex: Arroz Camil 5kg)" value={promoProduct} onChange={e => onPromoProductChange(e.target.value)}
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm" />
            <div className="grid grid-cols-3 gap-3">
              <input placeholder="Preço original" type="number" step="0.01" value={promoOrigPrice} onChange={e => onPromoOrigPriceChange(e.target.value)}
                className="px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm" />
              <input placeholder="Preço promo" type="number" step="0.01" value={promoNewPrice} onChange={e => onPromoNewPriceChange(e.target.value)}
                className="px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm" />
              <input placeholder="Válido até" type="date" value={promoValidUntil} onChange={e => onPromoValidUntilChange(e.target.value)}
                className="px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm" />
            </div>
            <button onClick={onCreatePromo}
              className="px-6 py-2.5 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04e28] transition-colors">
              Criar Promoção
            </button>
          </div>
        )}

        {promotions.length > 0 ? (
          <div className="space-y-2">
            {promotions.map(p => (
              <div key={p.id} className="flex items-center gap-4 p-4 bg-gray-50 rounded-xl">
                <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center text-green-700 font-bold text-sm">
                  {p.discount_pct > 0 ? `-${p.discount_pct}%` : '🏷️'}
                </div>
                <div className="flex-1">
                  <p className="text-sm font-medium text-gray-700">{p.product_name}</p>
                  <div className="flex items-center gap-2 mt-0.5">
                    {p.original_price > 0 && (
                      <span className="text-xs text-gray-400 line-through">R$ {p.original_price.toFixed(2)}</span>
                    )}
                    <span className="text-sm font-bold text-green-600">R$ {p.promo_price.toFixed(2)}</span>
                  </div>
                </div>
                {p.valid_until && (
                  <span className="text-xs text-gray-400">até {new Date(p.valid_until).toLocaleDateString('pt-BR')}</span>
                )}
              </div>
            ))}
          </div>
        ) : (
          <p className="text-center py-8 text-gray-400 text-sm">Nenhuma promoção ativa para {marketName}</p>
        )}
      </div>
    </div>
  )
}
