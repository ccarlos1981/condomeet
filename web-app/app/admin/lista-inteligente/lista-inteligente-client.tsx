'use client'

import { useState, useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Users, TrendingUp, Package,
  Store, PlusCircle, Send, RefreshCw, Trash2,
  Award, BarChart3, HelpCircle, X, Route, CheckCircle2
} from 'lucide-react'

type Stats = {
  total_contributors: number
  total_prices: number
  total_alerts: number
  total_products: number
  total_variants: number
  total_skus: number
  total_supermarkets: number
  total_lists: number
}

type TopUser = {
  user_id: string
  total_points: number
  weekly_points: number
  reports_count: number
  rank_title: string
  confirmations_given: number
  name?: string
}

type RecentPrice = {
  id: string
  price: number
  source: string
  confidence_score: number
  confirmations: number
  created_at: string
  product_name?: string
  variant_name?: string
  emoji?: string
  supermarket_name?: string
}

type Supermarket = {
  id: string
  name: string
  cnpj?: string
  address?: string
}

export default function ListaInteligenteClient() {
  const supabase = createClient()
  const [stats, setStats] = useState<Stats | null>(null)
  const [topUsers, setTopUsers] = useState<TopUser[]>([])
  const [recentPrices, setRecentPrices] = useState<RecentPrice[]>([])
  const [supermarkets, setSupermarkets] = useState<Supermarket[]>([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState<'dashboard' | 'users' | 'prices' | 'products' | 'markets' | 'push'>('dashboard')
  const [showGuide, setShowGuide] = useState(() => {
    if (typeof window !== 'undefined') {
      return localStorage.getItem('lista_admin_guide_dismissed') !== 'true'
    }
    return true
  })

  // Modals
  const [showAddMarket, setShowAddMarket] = useState(false)
  const [showAddProduct, setShowAddProduct] = useState(false)
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const [showPush, setShowPush] = useState(false)
  const [pushTitle, setPushTitle] = useState('🛒 Lista Inteligente')
  const [pushBody, setPushBody] = useState('')
  const [pushSending, setPushSending] = useState(false)
  const [newMarketName, setNewMarketName] = useState('')
  const [newMarketCnpj, setNewMarketCnpj] = useState('')
  const [newMarketAddr, setNewMarketAddr] = useState('')
  const [newProdName, setNewProdName] = useState('')
  const [newProdCategory, setNewProdCategory] = useState('')
  const [newProdEmoji, setNewProdEmoji] = useState('📦')

  const loadData = useCallback(async () => {
    setLoading(true)
    try {
      // Stats
      const [prices, users, alerts, products, variants, skus, markets, lists] = await Promise.all([
        supabase.from('lista_prices_raw').select('id').limit(10000),
        supabase.from('lista_user_points').select('user_id').limit(10000),
        supabase.from('lista_price_alerts').select('id').limit(10000),
        supabase.from('lista_products_base').select('id').limit(10000),
        supabase.from('lista_product_variants').select('id').limit(10000),
        supabase.from('lista_products_sku').select('id').limit(10000),
        supabase.from('lista_supermarkets').select('*').order('name'),
        supabase.from('lista_shopping_lists').select('id').limit(10000),
      ])

      setStats({
        total_contributors: users.data?.length ?? 0,
        total_prices: prices.data?.length ?? 0,
        total_alerts: alerts.data?.length ?? 0,
        total_products: products.data?.length ?? 0,
        total_variants: variants.data?.length ?? 0,
        total_skus: skus.data?.length ?? 0,
        total_supermarkets: markets.data?.length ?? 0,
        total_lists: lists.data?.length ?? 0,
      })

      setSupermarkets((markets.data ?? []) as Supermarket[])

      // Top users
      const { data: topData } = await supabase
        .from('lista_user_points')
        .select('user_id, total_points, weekly_points, reports_count, rank_title, confirmations_given')
        .order('total_points', { ascending: false })
        .limit(20)

      if (topData?.length) {
        const userIds = topData.map(u => u.user_id)
        const { data: profiles } = await supabase
          .from('perfil')
          .select('id, nome_completo')
          .in('id', userIds)

        const nameMap: Record<string, string> = {}
        profiles?.forEach(p => { nameMap[p.id] = p.nome_completo || 'Anônimo' })

        setTopUsers(topData.map(u => ({ ...u, name: nameMap[u.user_id] || 'Anônimo' })))
      }

      // Recent prices
      const { data: priceData } = await supabase
        .from('lista_prices_raw')
        .select('id, price, source, confidence_score, confirmations, created_at, lista_products_sku(brand, weight_label, lista_product_variants(variant_name, lista_products_base(name, icon_emoji))), lista_supermarkets(name)')
        .order('created_at', { ascending: false })
        .limit(20)

      if (priceData) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        type PriceRaw = { id: string; price: number; source: string; confidence_score: number; confirmations: number; created_at: string; lista_products_sku?: any; lista_supermarkets?: any }
        setRecentPrices(priceData.map((p: PriceRaw) => ({
          id: p.id,
          price: p.price,
          source: p.source,
          confidence_score: p.confidence_score,
          confirmations: p.confirmations,
          created_at: p.created_at,
          product_name: p.lista_products_sku?.lista_product_variants?.lista_products_base?.name,
          variant_name: p.lista_products_sku?.lista_product_variants?.variant_name,
          emoji: p.lista_products_sku?.lista_product_variants?.lista_products_base?.icon_emoji,
          supermarket_name: p.lista_supermarkets?.name,
        })))
      }
    } catch (e) {
      console.error('Load error:', e)
    }
    setLoading(false)
  }, [supabase])

  useEffect(() => { ;(async () => { await loadData() })() }, [loadData])

  const handleAddMarket = async () => {
    if (!newMarketName.trim()) return
    await supabase.from('lista_supermarkets').insert({
      name: newMarketName.trim(),
      cnpj: newMarketCnpj.trim() || null,
      address: newMarketAddr.trim() || null,
    })
    setShowAddMarket(false)
    setNewMarketName('')
    setNewMarketCnpj('')
    setNewMarketAddr('')
    loadData()
  }

  const handleAddProduct = async () => {
    if (!newProdName.trim()) return
    await supabase.from('lista_products_base').insert({
      name: newProdName.trim(),
      category: newProdCategory.trim() || 'outros',
      icon_emoji: newProdEmoji,
    })
    setShowAddProduct(false)
    setNewProdName('')
    setNewProdCategory('')
    setNewProdEmoji('📦')
    loadData()
  }

  const handleDeleteMarket = async (id: string) => {
    if (!confirm('Excluir este mercado?')) return
    await supabase.from('lista_supermarkets').delete().eq('id', id)
    loadData()
  }

  const handleSendPush = async () => {
    if (!pushBody.trim()) return
    setPushSending(true)
    try {
      const { data: users } = await supabase.from('lista_user_points').select('user_id')
      const userIds = (users ?? []).map(u => u.user_id)
      if (!userIds.length) { alert('Nenhum usuário ativo'); setPushSending(false); return }

      await supabase.functions.invoke('parcel-push-notify', {
        body: { user_ids: userIds, title: pushTitle, body: pushBody, data: { type: 'lista_mercado_promo' } }
      })
      alert(`✅ Push enviado para ${userIds.length} usuários!`)
      setShowPush(false)
      setPushBody('')
    } catch (e) {
      alert('Erro: ' + e)
    }
    setPushSending(false)
  }

  const emojis = ['🍚', '🫘', '🥛', '🍖', '🍗', '🥩', '🧀', '🍞', '🥚', '🍝', '🥫', '🧈', '☕', '🍺', '🧃', '🧹', '🧼', '📦', '🥬', '🍎', '🍌', '🥕', '🫒']

  const tabs = [
    { id: 'dashboard' as const, label: 'Dashboard', icon: <BarChart3 size={16} /> },
    { id: 'users' as const, label: 'Colaboradores', icon: <Users size={16} /> },
    { id: 'prices' as const, label: 'Preços', icon: <TrendingUp size={16} /> },
    { id: 'products' as const, label: 'Produtos', icon: <Package size={16} /> },
    { id: 'markets' as const, label: 'Mercados', icon: <Store size={16} /> },
    { id: 'push' as const, label: 'Push', icon: <Send size={16} /> },
  ]

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#FC5931]" />
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
            🛒 Lista Inteligente
            <span className="text-sm font-normal bg-green-100 text-green-700 px-2 py-0.5 rounded-full">Admin</span>
          </h1>
          <p className="text-gray-500 text-sm mt-1">Gerenciamento do módulo de comparação de preços</p>
        </div>
        <button onClick={loadData} className="flex items-center gap-2 px-4 py-2 bg-white rounded-xl border border-gray-200 text-gray-600 hover:bg-gray-50 transition-colors text-sm">
          <RefreshCw size={14} /> Atualizar
        </button>
        <button
          onClick={() => {
            localStorage.removeItem('lista_admin_guide_dismissed')
            setShowGuide(true)
          }}
          className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-[#FC5931] hover:bg-orange-50 rounded-lg transition-colors"
        >
          <HelpCircle size={16} /> Como começar
        </button>
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

      {/* Content */}
      {activeTab === 'dashboard' && (
        <div className="space-y-6">
          {/* Step Guide */}
          {showGuide && (
            <div className="bg-linear-to-r from-orange-50 to-amber-50 border border-orange-200 rounded-xl p-5">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Route size={18} className="text-[#FC5931]" />
                  <span className="font-semibold text-orange-900 text-sm">Como começar com a Lista Inteligente</span>
                </div>
                <button
                  onClick={() => {
                    localStorage.setItem('lista_admin_guide_dismissed', 'true')
                    setShowGuide(false)
                  }}
                  className="text-gray-400 hover:text-gray-600"
                  title="Fechar guia"
                >
                  <X size={16} />
                </button>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                {[
                  { step: 1, title: 'Cadastre mercados', desc: 'Adicione os supermercados da região', done: (stats?.total_supermarkets ?? 0) > 0 },
                  { step: 2, title: 'Adicione produtos', desc: 'Cadastre os produtos base para busca', done: (stats?.total_products ?? 0) > 0 },
                  { step: 3, title: 'Acompanhe preços', desc: 'Moradores reportam e você monitora', done: (stats?.total_prices ?? 0) > 0 },
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
          <DashboardTab stats={stats!} />
        </div>
      )}
      {activeTab === 'users' && <UsersTab users={topUsers} />}
      {activeTab === 'prices' && <PricesTab prices={recentPrices} />}
      {activeTab === 'products' && (
        <ProductsTab
          stats={stats!}
          onAdd={() => setShowAddProduct(true)}
        />
      )}
      {activeTab === 'markets' && (
        <MarketsTab
          markets={supermarkets}
          onAdd={() => setShowAddMarket(true)}
          onDelete={handleDeleteMarket}
        />
      )}
      {activeTab === 'push' && (
        <PushTab
          title={pushTitle}
          body={pushBody}
          sending={pushSending}
          userCount={topUsers.length}
          onTitleChange={setPushTitle}
          onBodyChange={setPushBody}
          onSend={handleSendPush}
        />
      )}

      {/* Add Market Modal */}
      {showAddMarket && (
        <Modal onClose={() => setShowAddMarket(false)} title="🏪 Novo Mercado">
          <input placeholder="Nome do mercado" value={newMarketName} onChange={e => setNewMarketName(e.target.value)}
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm" />
          <input placeholder="CNPJ (opcional)" value={newMarketCnpj} onChange={e => setNewMarketCnpj(e.target.value)}
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm mt-3" />
          <input placeholder="Endereço (opcional)" value={newMarketAddr} onChange={e => setNewMarketAddr(e.target.value)}
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm mt-3" />
          <button onClick={handleAddMarket}
            className="w-full mt-4 px-4 py-2.5 bg-[#FC5931] text-white rounded-xl font-medium hover:bg-[#e04e28] transition-colors">
            Salvar
          </button>
        </Modal>
      )}

      {/* Add Product Modal */}
      {showAddProduct && (
        <Modal onClose={() => setShowAddProduct(false)} title="📦 Novo Produto Base">
          <input placeholder="Nome do produto" value={newProdName} onChange={e => setNewProdName(e.target.value)}
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm" />
          <input placeholder="Categoria (ex: grãos)" value={newProdCategory} onChange={e => setNewProdCategory(e.target.value)}
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm mt-3" />
          <div className="mt-3">
            <p className="text-xs text-gray-500 mb-2">Ícone</p>
            <div className="flex flex-wrap gap-1.5">
              {emojis.map(e => (
                <button key={e} onClick={() => setNewProdEmoji(e)}
                  className={`w-9 h-9 rounded-lg text-lg flex items-center justify-center transition-all ${
                    newProdEmoji === e ? 'bg-[#FC5931]/10 ring-2 ring-[#FC5931]' : 'bg-gray-100 hover:bg-gray-200'
                  }`}
                >{e}</button>
              ))}
            </div>
          </div>
          <button onClick={handleAddProduct}
            className="w-full mt-4 px-4 py-2.5 bg-[#FC5931] text-white rounded-xl font-medium hover:bg-[#e04e28] transition-colors">
            Salvar
          </button>
        </Modal>
      )}
    </div>
  )
}

// ─── Sub-components ─────────────────────────────────

function StatCard({ emoji, value, label }: { emoji: string; value: number; label: string }) {
  return (
    <div className="bg-white rounded-2xl p-5 border border-gray-100 shadow-sm">
      <div className="text-2xl mb-2">{emoji}</div>
      <p className="text-3xl font-bold text-gray-800">{value}</p>
      <p className="text-sm text-gray-400 mt-1">{label}</p>
    </div>
  )
}

function DashboardTab({ stats }: { stats: Stats }) {
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
      <StatCard emoji="👥" value={stats.total_contributors} label="Colaboradores" />
      <StatCard emoji="💰" value={stats.total_prices} label="Preços Cadastrados" />
      <StatCard emoji="🔔" value={stats.total_alerts} label="Alertas Ativos" />
      <StatCard emoji="📋" value={stats.total_lists} label="Listas Criadas" />
      <StatCard emoji="📦" value={stats.total_products} label="Produtos Base" />
      <StatCard emoji="📋" value={stats.total_variants} label="Variantes" />
      <StatCard emoji="🏷️" value={stats.total_skus} label="SKUs" />
      <StatCard emoji="🏪" value={stats.total_supermarkets} label="Mercados" />
    </div>
  )
}

function UsersTab({ users }: { users: TopUser[] }) {
  const getRankColor = (rank: string) => {
    const m: Record<string, string> = {
      'Mestre do Preço': 'bg-yellow-100 text-yellow-700',
      'Caçador de Oferta': 'bg-purple-100 text-purple-700',
      'Fiscal de Preço': 'bg-orange-100 text-orange-700',
      'Colaborador': 'bg-blue-100 text-blue-700',
      'Iniciante': 'bg-gray-100 text-gray-600',
    }
    return m[rank] || m['Iniciante']
  }

  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
      <div className="p-5 border-b border-gray-100">
        <h2 className="font-semibold text-gray-800 flex items-center gap-2"><Award size={18} /> Top Colaboradores</h2>
      </div>
      <table className="w-full">
        <thead>
          <tr className="text-xs text-gray-400 uppercase tracking-wider">
            <th className="text-left px-5 py-3">#</th>
            <th className="text-left px-5 py-3">Nome</th>
            <th className="text-left px-5 py-3">Rank</th>
            <th className="text-right px-5 py-3">Pontos</th>
            <th className="text-right px-5 py-3">Semana</th>
            <th className="text-right px-5 py-3">Reportes</th>
          </tr>
        </thead>
        <tbody>
          {users.map((u, i) => (
            <tr key={u.user_id} className="border-t border-gray-50 hover:bg-gray-50/50">
              <td className="px-5 py-3 text-sm font-bold text-gray-400">{i < 3 ? ['🥇', '🥈', '🥉'][i] : `#${i + 1}`}</td>
              <td className="px-5 py-3 text-sm font-medium text-gray-700">{u.name}</td>
              <td className="px-5 py-3"><span className={`text-xs font-medium px-2 py-0.5 rounded-full ${getRankColor(u.rank_title)}`}>{u.rank_title}</span></td>
              <td className="px-5 py-3 text-right text-sm font-bold text-green-600">{u.total_points}</td>
              <td className="px-5 py-3 text-right text-sm text-gray-500">{u.weekly_points}</td>
              <td className="px-5 py-3 text-right text-sm text-gray-500">{u.reports_count}</td>
            </tr>
          ))}
          {users.length === 0 && (
            <tr><td colSpan={6} className="px-5 py-10 text-center text-gray-400 text-sm">Nenhum colaborador ainda</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}

function PricesTab({ prices }: { prices: RecentPrice[] }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
      <div className="p-5 border-b border-gray-100">
        <h2 className="font-semibold text-gray-800 flex items-center gap-2"><TrendingUp size={18} /> Últimos Preços Reportados</h2>
      </div>
      <table className="w-full">
        <thead>
          <tr className="text-xs text-gray-400 uppercase tracking-wider">
            <th className="w-10"></th>
            <th className="text-left px-5 py-3">Produto</th>
            <th className="text-left px-5 py-3">Mercado</th>
            <th className="text-right px-5 py-3">Preço</th>
            <th className="text-center px-5 py-3">Fonte</th>
            <th className="text-center px-5 py-3">Confirmações</th>
            <th className="text-right px-5 py-3">Data</th>
          </tr>
        </thead>
        <tbody>
          {prices.map(p => (
            <tr key={p.id} className="border-t border-gray-50 hover:bg-gray-50/50">
              <td className="pl-5 text-lg">{p.emoji || '📦'}</td>
              <td className="px-5 py-3 text-sm text-gray-700">{p.product_name} {p.variant_name}</td>
              <td className="px-5 py-3 text-sm text-gray-500">{p.supermarket_name || '—'}</td>
              <td className="px-5 py-3 text-right text-sm font-bold text-green-600">R$ {p.price.toFixed(2)}</td>
              <td className="px-5 py-3 text-center"><span className="text-xs bg-gray-100 text-gray-500 px-2 py-0.5 rounded-full">{p.source}</span></td>
              <td className="px-5 py-3 text-center text-sm text-gray-500">{p.confirmations}x</td>
              <td className="px-5 py-3 text-right text-xs text-gray-400">{new Date(p.created_at).toLocaleDateString('pt-BR')}</td>
            </tr>
          ))}
          {prices.length === 0 && (
            <tr><td colSpan={7} className="px-5 py-10 text-center text-gray-400 text-sm">Nenhum preço cadastrado</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}

function ProductsTab({ stats, onAdd }: { stats: Stats; onAdd: () => void }) {
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-3 gap-4">
        <StatCard emoji="📦" value={stats.total_products} label="Produtos Base" />
        <StatCard emoji="📋" value={stats.total_variants} label="Variantes" />
        <StatCard emoji="🏷️" value={stats.total_skus} label="SKUs" />
      </div>
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="font-semibold text-gray-800 flex items-center gap-2"><Package size={18} /> Gerenciar Produtos</h2>
          <button onClick={onAdd}
            className="flex items-center gap-2 px-4 py-2 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04e28] transition-colors">
            <PlusCircle size={14} /> Novo Produto
          </button>
        </div>
        <p className="text-sm text-gray-400">Hierarquia: Produto Base → Variantes → SKUs (marcas/pesos)</p>
        <p className="text-sm text-gray-400 mt-1">Produtos base servem como vínculo do autocomplete no app mobile.</p>
      </div>
    </div>
  )
}

function MarketsTab({ markets, onAdd, onDelete }: { markets: Supermarket[]; onAdd: () => void; onDelete: (id: string) => void }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
      <div className="p-5 border-b border-gray-100 flex items-center justify-between">
        <h2 className="font-semibold text-gray-800 flex items-center gap-2"><Store size={18} /> Mercados ({markets.length})</h2>
        <button onClick={onAdd}
          className="flex items-center gap-2 px-4 py-2 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04e28] transition-colors">
          <PlusCircle size={14} /> Novo Mercado
        </button>
      </div>
      <table className="w-full">
        <thead>
          <tr className="text-xs text-gray-400 uppercase tracking-wider">
            <th className="text-left px-5 py-3">Nome</th>
            <th className="text-left px-5 py-3">CNPJ</th>
            <th className="text-left px-5 py-3">Endereço</th>
            <th className="text-right px-5 py-3">Ações</th>
          </tr>
        </thead>
        <tbody>
          {markets.map(m => (
            <tr key={m.id} className="border-t border-gray-50 hover:bg-gray-50/50">
              <td className="px-5 py-3 text-sm font-medium text-gray-700">🏪 {m.name}</td>
              <td className="px-5 py-3 text-sm text-gray-400">{m.cnpj || '—'}</td>
              <td className="px-5 py-3 text-sm text-gray-400">{m.address || '—'}</td>
              <td className="px-5 py-3 text-right">
                <button onClick={() => onDelete(m.id)} className="p-1.5 text-gray-400 hover:text-red-500 transition-colors" title="Excluir">
                  <Trash2 size={14} />
                </button>
              </td>
            </tr>
          ))}
          {markets.length === 0 && (
            <tr><td colSpan={4} className="px-5 py-10 text-center text-gray-400 text-sm">Nenhum mercado cadastrado</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}

function PushTab({ title, body, sending, userCount, onTitleChange, onBodyChange, onSend }: {
  title: string; body: string; sending: boolean; userCount: number
  onTitleChange: (v: string) => void; onBodyChange: (v: string) => void; onSend: () => void
}) {
  return (
    <div className="max-w-xl mx-auto">
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 space-y-4">
        <h2 className="font-semibold text-gray-800 flex items-center gap-2"><Send size={18} /> Push Segmentado</h2>
        <p className="text-sm text-gray-400">
          Envia notificação apenas para <strong>{userCount}</strong> usuários que já reportaram preços no módulo.
        </p>

        <div>
          <label className="text-xs text-gray-500 font-medium mb-1 block">Título</label>
          <input value={title} onChange={e => onTitleChange(e.target.value)} title="Título da Mensagem" placeholder="Ex: Aviso Importante"
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm" />
        </div>

        <div>
          <label className="text-xs text-gray-500 font-medium mb-1 block">Mensagem</label>
          <textarea value={body} onChange={e => onBodyChange(e.target.value)} rows={4}
            placeholder="Ex: Novas promoções detectadas na sua região! Abra o app."
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] outline-none text-sm resize-none" />
        </div>

        <button onClick={onSend} disabled={sending || !body.trim()}
          className="w-full px-4 py-3 bg-[#FC5931] text-white rounded-xl font-medium hover:bg-[#e04e28] transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2">
          {sending ? <RefreshCw size={16} className="animate-spin" /> : <Send size={16} />}
          {sending ? 'Enviando...' : `Enviar Push para ${userCount} usuários`}
        </button>
      </div>
    </div>
  )
}

function Modal({ onClose, title, children }: { onClose: () => void; title: string; children: React.ReactNode }) {
  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-xl max-w-md w-full p-6" onClick={e => e.stopPropagation()}>
        <h3 className="font-semibold text-gray-800 text-lg mb-4">{title}</h3>
        {children}
      </div>
    </div>
  )
}
