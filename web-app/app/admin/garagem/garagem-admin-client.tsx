'use client'

import { useState, useMemo } from 'react'
import { Car, Clock, Star, DollarSign, Building2, Calendar, CheckCircle, XCircle, AlertCircle, Search, Filter, TrendingUp, HelpCircle, X, Route } from 'lucide-react'

/* eslint-disable @typescript-eslint/no-explicit-any */

type Tab = 'overview' | 'garages' | 'reservations' | 'trials' | 'earnings'

export default function GaragemAdminClient({
  garages,
  reservations,
  trials,
  earnings,
}: {
  garages: any[]
  reservations: any[]
  trials: any[]
  earnings: any[]
}) {
  const [tab, setTab] = useState<Tab>('overview')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [showGuide, setShowGuide] = useState(() => {
    if (typeof window !== 'undefined') {
      return localStorage.getItem('garagem_admin_guide_dismissed') !== 'true'
    }
    return true
  })

  // ── Stats ─────────────────────────────────────────────
  const stats = useMemo(() => {
    const totalGarages = garages.length
    const activeGarages = garages.filter(g => g.status === 'available').length
    const totalReservations = reservations.length
    const activeReservations = reservations.filter(r => r.status === 'confirmed' || r.status === 'active').length
    const totalCondos = new Set(garages.map(g => g.condominio_id)).size
    const activeTrials = trials.filter(t => {
      const end = new Date(t.trial_end)
      return end > new Date()
    }).length
    const totalEarnings = earnings.reduce((sum: number, e: any) => sum + Number(e.platform_fee || 0), 0)

    return { totalGarages, activeGarages, totalReservations, activeReservations, totalCondos, activeTrials, totalEarnings }
  }, [garages, reservations, trials, earnings])

  // ── Filters ─────────────────────────────────────────────
  const filteredGarages = useMemo(() => {
    let list = garages
    if (search) {
      const s = search.toLowerCase()
      list = list.filter((g: any) =>
        g.spot_identifier?.toLowerCase().includes(s) ||
        g.perfil?.nome_completo?.toLowerCase().includes(s) ||
        g.condominios?.nome?.toLowerCase().includes(s)
      )
    }
    if (statusFilter !== 'all') list = list.filter((g: any) => g.status === statusFilter)
    return list
  }, [garages, search, statusFilter])

  const filteredReservations = useMemo(() => {
    let list = reservations
    if (search) {
      const s = search.toLowerCase()
      list = list.filter((r: any) =>
        r.renter?.nome_completo?.toLowerCase().includes(s) ||
        r.garage?.spot_identifier?.toLowerCase().includes(s) ||
        r.vehicle_plate?.toLowerCase().includes(s)
      )
    }
    if (statusFilter !== 'all') list = list.filter((r: any) => r.status === statusFilter)
    return list
  }, [reservations, search, statusFilter])

  const tabs: { id: Tab; label: string; icon: React.ReactNode }[] = [
    { id: 'overview', label: 'Visão Geral', icon: <TrendingUp size={16} /> },
    { id: 'garages', label: `Vagas (${garages.length})`, icon: <Car size={16} /> },
    { id: 'reservations', label: `Reservas (${reservations.length})`, icon: <Calendar size={16} /> },
    { id: 'trials', label: `Trials (${trials.length})`, icon: <Building2 size={16} /> },
    { id: 'earnings', label: `Ganhos (${earnings.length})`, icon: <DollarSign size={16} /> },
  ]

  const statusColor: Record<string, string> = {
    available: 'bg-emerald-100 text-emerald-700',
    rented: 'bg-blue-100 text-blue-700',
    unavailable: 'bg-gray-100 text-gray-600',
    pending: 'bg-yellow-100 text-yellow-700',
    confirmed: 'bg-blue-100 text-blue-700',
    active: 'bg-emerald-100 text-emerald-700',
    completed: 'bg-gray-100 text-gray-600',
    cancelled: 'bg-red-100 text-red-700',
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-3">
            <Car className="text-purple-600" size={28} />
            Garagem Inteligente
          </h1>
          <p className="text-sm text-gray-500 mt-1">Painel administrativo — visão global de vagas e reservas</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => {
              localStorage.removeItem('garagem_admin_guide_dismissed')
              setShowGuide(true)
            }}
            className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-purple-600 hover:bg-purple-50 rounded-lg transition-colors"
          >
            <HelpCircle size={16} /> Como começar
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
        {tabs.map(t => (
          <button
            key={t.id}
            onClick={() => { setTab(t.id); setSearch(''); setStatusFilter('all') }}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium whitespace-nowrap transition-all ${
              tab === t.id
                ? 'bg-white text-purple-700 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {/* Overview */}
      {tab === 'overview' && (
        <div className="space-y-6">
          {/* Step Guide */}
          {showGuide && (
            <div className="bg-linear-to-r from-purple-50 to-violet-50 border border-purple-200 rounded-xl p-5">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Route size={18} className="text-purple-600" />
                  <span className="font-semibold text-purple-900 text-sm">Como começar com a Garagem Inteligente</span>
                </div>
                <button
                  onClick={() => {
                    localStorage.setItem('garagem_admin_guide_dismissed', 'true')
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
                  { step: 1, title: 'Cadastre vagas', desc: 'Moradores cadastram suas vagas no app', done: garages.length > 0 },
                  { step: 2, title: 'Gerencie reservas', desc: 'Acompanhe as reservas realizadas', done: reservations.length > 0 },
                  { step: 3, title: 'Acompanhe ganhos', desc: 'Monitore a receita da plataforma', done: earnings.length > 0 },
                ].map(s => (
                  <div key={s.step} className={`flex items-start gap-3 p-3 rounded-lg ${s.done ? 'bg-white/60' : 'bg-white'}`}>
                    <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold shrink-0 ${
                      s.done ? 'bg-green-500 text-white' : 'bg-white border-2 border-purple-300 text-purple-500'
                    }`}>
                      {s.done ? <CheckCircle size={16} /> : s.step}
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

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: 'Total Vagas', value: stats.totalGarages, icon: <Car size={20} />, color: 'text-purple-600 bg-purple-50' },
              { label: 'Vagas Ativas', value: stats.activeGarages, icon: <CheckCircle size={20} />, color: 'text-emerald-600 bg-emerald-50' },
              { label: 'Total Reservas', value: stats.totalReservations, icon: <Calendar size={20} />, color: 'text-blue-600 bg-blue-50' },
              { label: 'Reservas Ativas', value: stats.activeReservations, icon: <Clock size={20} />, color: 'text-orange-600 bg-orange-50' },
              { label: 'Condomínios', value: stats.totalCondos, icon: <Building2 size={20} />, color: 'text-gray-600 bg-gray-50' },
              { label: 'Trials Ativos', value: stats.activeTrials, icon: <AlertCircle size={20} />, color: 'text-yellow-600 bg-yellow-50' },
              { label: 'Receita Plataforma', value: `R$ ${stats.totalEarnings.toFixed(2)}`, icon: <DollarSign size={20} />, color: 'text-green-600 bg-green-50' },
              { label: 'Média Avaliação', value: '—', icon: <Star size={20} />, color: 'text-amber-600 bg-amber-50' },
            ].map((s, i) => (
              <div key={i} className="bg-white rounded-xl border border-gray-200 p-4">
                <div className={`w-10 h-10 rounded-lg flex items-center justify-center mb-3 ${s.color}`}>
                  {s.icon}
                </div>
                <p className="text-2xl font-bold text-gray-900">{s.value}</p>
                <p className="text-xs text-gray-500 mt-1">{s.label}</p>
              </div>
            ))}
          </div>

          {/* Recent activity */}
          <div className="bg-white rounded-xl border border-gray-200 p-6">
            <h3 className="font-semibold text-gray-900 mb-4">Últimas Reservas</h3>
            {reservations.length === 0 ? (
              <p className="text-sm text-gray-400">Nenhuma reserva ainda.</p>
            ) : (
              <div className="space-y-3">
                {reservations.slice(0, 5).map((r: any) => (
                  <div key={r.id} className="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
                    <div>
                      <p className="text-sm font-medium text-gray-900">
                        {r.renter?.nome_completo ?? 'Morador'} → Vaga {r.garage?.spot_identifier ?? '?'}
                      </p>
                      <p className="text-xs text-gray-400">
                        {r.vehicle_plate ?? ''} | {new Date(r.start_date).toLocaleDateString('pt-BR')} — {new Date(r.end_date).toLocaleDateString('pt-BR')}
                      </p>
                    </div>
                    <span className={`text-xs font-medium px-2 py-1 rounded-full ${statusColor[r.status] ?? 'bg-gray-100 text-gray-600'}`}>
                      {r.status}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Garages tab */}
      {tab === 'garages' && (
        <div className="space-y-4">
          <div className="flex gap-3 flex-wrap">
            <div className="relative flex-1 min-w-[200px]">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type="text"
                placeholder="Buscar por vaga, morador ou condomínio..."
                value={search}
                onChange={e => setSearch(e.target.value)}
                className="w-full pl-9 pr-4 py-2.5 rounded-lg border border-gray-200 text-sm focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              />
            </div>
            <div className="flex items-center gap-2">
              <Filter size={16} className="text-gray-400" />
              <select
                value={statusFilter}
                onChange={e => setStatusFilter(e.target.value)}
                className="border border-gray-200 rounded-lg px-3 py-2.5 text-sm"
                aria-label="Filtrar por status"
              >
                <option value="all">Todos</option>
                <option value="available">Disponível</option>
                <option value="rented">Alugada</option>
                <option value="unavailable">Indisponível</option>
              </select>
            </div>
          </div>

          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Vaga</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Tipo</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Proprietário</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Condomínio</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Preço/Mensal</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Status</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Criada</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filteredGarages.map((g: any) => (
                  <tr key={g.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium text-gray-900">{g.spot_identifier}</td>
                    <td className="px-4 py-3 text-gray-600 capitalize">{g.spot_type?.replace('_', ' ')}</td>
                    <td className="px-4 py-3">
                      <p className="text-gray-900">{g.perfil?.nome_completo ?? '—'}</p>
                      <p className="text-xs text-gray-400">
                        {g.perfil?.bloco_txt ? `Bl ${g.perfil.bloco_txt}` : ''} {g.perfil?.apto_txt ? `Ap ${g.perfil.apto_txt}` : ''}
                      </p>
                    </td>
                    <td className="px-4 py-3 text-gray-600">{g.condominios?.nome ?? '—'}</td>
                    <td className="px-4 py-3 text-gray-900 font-medium">R$ {Number(g.price_monthly || 0).toFixed(2)}</td>
                    <td className="px-4 py-3">
                      <span className={`text-xs font-medium px-2 py-1 rounded-full ${statusColor[g.status] ?? 'bg-gray-100 text-gray-600'}`}>
                        {g.status}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-400 text-xs">{new Date(g.created_at).toLocaleDateString('pt-BR')}</td>
                  </tr>
                ))}
                {filteredGarages.length === 0 && (
                  <tr><td colSpan={7} className="px-4 py-8 text-center text-gray-400">Nenhuma vaga encontrada.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Reservations tab */}
      {tab === 'reservations' && (
        <div className="space-y-4">
          <div className="flex gap-3 flex-wrap">
            <div className="relative flex-1 min-w-[200px]">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type="text"
                placeholder="Buscar por morador, vaga ou placa..."
                value={search}
                onChange={e => setSearch(e.target.value)}
                className="w-full pl-9 pr-4 py-2.5 rounded-lg border border-gray-200 text-sm focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              />
            </div>
            <select
              value={statusFilter}
              onChange={e => setStatusFilter(e.target.value)}
              className="border border-gray-200 rounded-lg px-3 py-2.5 text-sm"
              aria-label="Filtrar por status da reserva"
            >
              <option value="all">Todos</option>
              <option value="pending">Pendente</option>
              <option value="confirmed">Confirmada</option>
              <option value="active">Ativa</option>
              <option value="completed">Concluída</option>
              <option value="cancelled">Cancelada</option>
            </select>
          </div>

          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Locatário</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Vaga</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Veículo</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Período</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Valor</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filteredReservations.map((r: any) => (
                  <tr key={r.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <p className="text-gray-900 font-medium">{r.renter?.nome_completo ?? '—'}</p>
                      <p className="text-xs text-gray-400">
                        {r.renter?.bloco_txt ? `Bl ${r.renter.bloco_txt}` : ''} {r.renter?.apto_txt ? `Ap ${r.renter.apto_txt}` : ''}
                      </p>
                    </td>
                    <td className="px-4 py-3 text-gray-600">{r.garage?.spot_identifier ?? '—'}</td>
                    <td className="px-4 py-3 text-gray-600">
                      <p>{r.vehicle_plate ?? '—'}</p>
                      <p className="text-xs text-gray-400">{r.vehicle_model ?? ''} {r.vehicle_color ?? ''}</p>
                    </td>
                    <td className="px-4 py-3 text-gray-600 text-xs">
                      {new Date(r.start_date).toLocaleDateString('pt-BR')} — {new Date(r.end_date).toLocaleDateString('pt-BR')}
                    </td>
                    <td className="px-4 py-3 font-medium text-gray-900">R$ {Number(r.total_price || 0).toFixed(2)}</td>
                    <td className="px-4 py-3">
                      <span className={`text-xs font-medium px-2 py-1 rounded-full ${statusColor[r.status] ?? 'bg-gray-100 text-gray-600'}`}>
                        {r.status}
                      </span>
                    </td>
                  </tr>
                ))}
                {filteredReservations.length === 0 && (
                  <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-400">Nenhuma reserva encontrada.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Trials tab */}
      {tab === 'trials' && (
        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Condomínio</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Início Trial</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Fim Trial</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Status</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Plano</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {trials.map((t: any) => {
                  const isActive = new Date(t.trial_end) > new Date()
                  return (
                    <tr key={t.id} className="hover:bg-gray-50">
                      <td className="px-4 py-3 font-medium text-gray-900">{t.condominios?.nome ?? '—'}</td>
                      <td className="px-4 py-3 text-gray-600">{new Date(t.trial_start).toLocaleDateString('pt-BR')}</td>
                      <td className="px-4 py-3 text-gray-600">{new Date(t.trial_end).toLocaleDateString('pt-BR')}</td>
                      <td className="px-4 py-3">
                        {isActive ? (
                          <span className="flex items-center gap-1 text-xs text-emerald-600">
                            <CheckCircle size={14} /> Ativo
                          </span>
                        ) : (
                          <span className="flex items-center gap-1 text-xs text-red-500">
                            <XCircle size={14} /> Expirado
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-gray-600 capitalize">{t.plan_after_trial ?? 'free'}</td>
                    </tr>
                  )
                })}
                {trials.length === 0 && (
                  <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-400">Nenhum trial registrado.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Earnings tab */}
      {tab === 'earnings' && (
        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Proprietário</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Mês</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Receita Total</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Taxa Plataforma</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Líquido</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {earnings.map((e: any) => (
                  <tr key={e.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-gray-900 font-medium">{e.owner_id?.slice(0, 8) ?? '—'}</td>
                    <td className="px-4 py-3 text-gray-600">{e.month}</td>
                    <td className="px-4 py-3 text-gray-600">R$ {Number(e.total_earned || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-purple-600 font-medium">R$ {Number(e.platform_fee || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-emerald-600 font-medium">R$ {Number(e.net_earned || 0).toFixed(2)}</td>
                  </tr>
                ))}
                {earnings.length === 0 && (
                  <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-400">Nenhum registro de ganhos.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
