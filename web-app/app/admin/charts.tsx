'use client'
import {
  AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend,
  ComposedChart, Line
} from 'recharts'
import { useMemo, useState } from 'react'

interface Invitation {
  created_at: string
  visitante_compareceu: boolean
}

interface Ocorrencia {
  created_at: string
  status: string
}

interface Reserva {
  data: string
  status: string
}

interface FaleConosco {
  created_at: string
  status: string
}

interface Morador {
  created_at: string
  status_aprovacao: string
}

interface Encomenda {
  created_at: string
  status: string
}

// ── Helpers ──────────────────────────────────────────────
function getMonthLabel(date: Date): string {
  return date.toLocaleDateString('pt-BR', { month: 'short', year: '2-digit' })
}

function getLast6Months(): string[] {
  const months: string[] = []
  for (let i = 5; i >= 0; i--) {
    const d = new Date()
    d.setMonth(d.getMonth() - i)
    months.push(getMonthLabel(d))
  }
  return months
}

function groupInvitationsByMonth(invitations: Invitation[]) {
  const months = getLast6Months()
  const groups: Record<string, { total: number; liberados: number }> = {}
  months.forEach(m => { groups[m] = { total: 0, liberados: 0 } })

  invitations.forEach(inv => {
    const month = getMonthLabel(new Date(inv.created_at))
    if (groups[month]) {
      groups[month].total++
      if (inv.visitante_compareceu) groups[month].liberados++
    }
  })

  return months.map(month => ({
    month,
    total: groups[month].total,
    liberados: groups[month].liberados,
    taxa: groups[month].total > 0 ? Math.round((groups[month].liberados / groups[month].total) * 100) : 0,
  }))
}

function groupOcorrenciasByMonth(ocorrencias: Ocorrencia[]) {
  const months = getLast6Months()
  const groups: Record<string, { abertas: number; resolvidas: number }> = {}
  months.forEach(m => { groups[m] = { abertas: 0, resolvidas: 0 } })

  ocorrencias.forEach(o => {
    const month = getMonthLabel(new Date(o.created_at))
    if (groups[month]) {
      if (o.status === 'resolvido') groups[month].resolvidas++
      else groups[month].abertas++
    }
  })

  return months.map(month => ({
    month,
    ...groups[month],
    total: groups[month].abertas + groups[month].resolvidas,
  }))
}

function groupReservasByMonth(reservas: Reserva[]) {
  const months = getLast6Months()
  const groups: Record<string, { confirmadas: number; canceladas: number; pendentes: number }> = {}
  months.forEach(m => { groups[m] = { confirmadas: 0, canceladas: 0, pendentes: 0 } })

  reservas.forEach(r => {
    const month = getMonthLabel(new Date(r.data))
    if (groups[month]) {
      if (r.status === 'cancelada') groups[month].canceladas++
      else if (r.status === 'aprovada' || r.status === 'confirmada') groups[month].confirmadas++
      else groups[month].pendentes++
    }
  })

  return months.map(month => ({
    month,
    ...groups[month],
    total: groups[month].confirmadas + groups[month].canceladas + groups[month].pendentes,
  }))
}

function groupGenericByMonth(items: { created_at: string }[]) {
  const months = getLast6Months()
  const groups: Record<string, number> = {}
  months.forEach(m => { groups[m] = 0 })

  items.forEach(item => {
    const month = getMonthLabel(new Date(item.created_at))
    if (groups[month] !== undefined) {
      groups[month]++
    }
  })

  return months.map(month => ({
    month,
    total: groups[month],
  }))
}

function groupEncomendasByMonth(items: { created_at: string; status: string }[]) {
  const months = getLast6Months()
  const groups: Record<string, { registradas: number; entregues: number }> = {}
  months.forEach(m => { groups[m] = { registradas: 0, entregues: 0 } })

  items.forEach(item => {
    const month = getMonthLabel(new Date(item.created_at))
    if (groups[month]) {
      groups[month].registradas++
      if (item.status === 'delivered') groups[month].entregues++
    }
  })

  return months.map(month => ({
    month,
    ...groups[month],
  }))
}

function getOcorrenciaStatusPie(ocorrencias: Ocorrencia[]) {
  const statusMap: Record<string, number> = {}
  ocorrencias.forEach(o => {
    const s = o.status ?? 'pendente'
    statusMap[s] = (statusMap[s] || 0) + 1
  })
  return Object.entries(statusMap).map(([name, value]) => ({ name: statusLabel(name), value }))
}

function statusLabel(s: string): string {
  const map: Record<string, string> = {
    pendente: 'Pendente',
    em_andamento: 'Em Andamento',
    resolvido: 'Resolvido',
    fechado: 'Fechado',
  }
  return map[s] || s.charAt(0).toUpperCase() + s.slice(1)
}

const PIE_COLORS = ['#f59e0b', '#3b82f6', '#10b981', '#6366f1', '#ef4444', '#ec4899']

// ── Custom Tooltip ──────────────────────────────────────
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function CustomTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null
  return (
    <div className="bg-gray-900 text-white px-3 py-2 rounded-lg shadow-xl text-xs">
      <p className="font-semibold mb-1">{label}</p>
      {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
      {payload.map((p: any, i: number) => (
        <p key={i} className="flex items-center gap-1.5">
          <span className="w-2 h-2 rounded-full" style={{ background: p.color }} />
          {p.name}: <span className="font-bold">{p.value}</span>
        </p>
      ))}
    </div>
  )
}

// ── Tabs ────────────────────────────────────────────────
type ChartTab = 'autorizacoes' | 'ocorrencias' | 'reservas' | 'faleConosco' | 'moradores' | 'encomendas'

const TABS: { id: ChartTab; label: string }[] = [
  { id: 'autorizacoes', label: 'Autorizações' },
  { id: 'ocorrencias',  label: 'Ocorrências' },
  { id: 'faleConosco',  label: 'Fale Conosco' },
  { id: 'moradores',    label: 'Moradores' },
  { id: 'encomendas',   label: 'Encomendas' },
  { id: 'reservas',     label: 'Reservas' },
]

// ═══════════════════════════════════════════════════════════
interface Props {
  invitations: Invitation[]
  ocorrencias: Ocorrencia[]
  reservas: Reserva[]
  faleConosco: FaleConosco[]
  moradores: Morador[]
  encomendas: Encomenda[]
}

export default function AdminCharts({ invitations, ocorrencias, reservas, faleConosco, moradores, encomendas }: Props) {
  const [activeTab, setActiveTab] = useState<ChartTab>('autorizacoes')

  const invData = useMemo(() => groupInvitationsByMonth(invitations), [invitations])
  const occData = useMemo(() => groupOcorrenciasByMonth(ocorrencias), [ocorrencias])
  const resData = useMemo(() => groupReservasByMonth(reservas), [reservas])
  const pieData = useMemo(() => getOcorrenciaStatusPie(ocorrencias), [ocorrencias])

  // Data for new tabs
  const fcData = useMemo(() => groupGenericByMonth(faleConosco), [faleConosco])
  const mrData = useMemo(() => groupGenericByMonth(moradores), [moradores])
  const encData = useMemo(() => groupEncomendasByMonth(encomendas), [encomendas])

  // Summary stats for each tab
  const invTotal = invitations.length
  const invLiberados = invitations.filter(i => i.visitante_compareceu).length
  const invTaxa = invTotal > 0 ? Math.round((invLiberados / invTotal) * 100) : 0

  const occTotal = ocorrencias.length
  const occResolvidas = ocorrencias.filter(o => o.status === 'resolvido').length
  const occTaxaRes = occTotal > 0 ? Math.round((occResolvidas / occTotal) * 100) : 0

  const resTotal = reservas.length
  const resConfirmadas = reservas.filter(r => r.status === 'aprovada' || r.status === 'confirmada').length

  return (
    <div className="space-y-6">
      {/* ── Tab Switcher ──────────────────────────────── */}
      <div className="flex items-center gap-1 bg-gray-100 rounded-xl p-1 w-fit">
        {TABS.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
              activeTab === tab.id
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* ═══ AUTORIZAÇÕES TAB ═══════════════════════ */}
      {activeTab === 'autorizacoes' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Area chart — 2 cols */}
          <div className="lg:col-span-2 bg-white rounded-2xl p-6 border border-gray-100 shadow-sm">
            <div className="flex items-center justify-between mb-5">
              <div>
                <h3 className="font-semibold text-gray-800">Autorizações vs Liberados</h3>
                <p className="text-xs text-gray-400 mt-0.5">Últimos 6 meses</p>
              </div>
              <div className="flex items-center gap-4">
                <span className="flex items-center gap-1.5 text-[11px] text-gray-500">
                  <span className="w-2.5 h-2.5 rounded-full bg-[#FC5931]" /> Autorizações
                </span>
                <span className="flex items-center gap-1.5 text-[11px] text-gray-500">
                  <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" /> Liberados
                </span>
              </div>
            </div>
            <ResponsiveContainer width="100%" height={260}>
              <ComposedChart data={invData}>
                <defs>
                  <linearGradient id="gradTotal" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#FC5931" stopOpacity={0.15} />
                    <stop offset="95%" stopColor="#FC5931" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="gradLib" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#10B981" stopOpacity={0.15} />
                    <stop offset="95%" stopColor="#10B981" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} width={30} axisLine={false} tickLine={false} />
                <Tooltip content={<CustomTooltip />} />
                <Area type="monotone" dataKey="total" name="Autorizações" stroke="#FC5931" fill="url(#gradTotal)" strokeWidth={2.5} dot={false} />
                <Area type="monotone" dataKey="liberados" name="Liberados" stroke="#10B981" fill="url(#gradLib)" strokeWidth={2.5} dot={false} />
                <Line type="monotone" dataKey="taxa" name="Taxa %" stroke="#8B5CF6" strokeWidth={1.5} strokeDasharray="4 4" dot={false} yAxisId="right" />
              </ComposedChart>
            </ResponsiveContainer>
          </div>

          {/* Summary card */}
          <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm flex flex-col justify-between">
            <div>
              <h3 className="font-semibold text-gray-800 mb-4">Resumo Geral</h3>
              <div className="space-y-4">
                <div>
                  <p className="text-xs text-gray-400 font-medium mb-1">Total de Autorizações</p>
                  <p className="text-3xl font-bold text-gray-900">{invTotal}</p>
                </div>
                <div>
                  <p className="text-xs text-gray-400 font-medium mb-1">Visitantes Liberados</p>
                  <p className="text-3xl font-bold text-emerald-600">{invLiberados}</p>
                </div>
              </div>
            </div>
            <div className="mt-6 pt-4 border-t border-gray-100">
              <p className="text-xs text-gray-400 font-medium mb-2">Taxa de Comparecimento</p>
              <div className="flex items-end gap-2">
                <span className="text-4xl font-bold text-[#FC5931]">{invTaxa}%</span>
              </div>
              <div className="w-full h-2 bg-gray-100 rounded-full mt-3 overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-[#FC5931] to-[#FF8A65] rounded-full transition-all duration-700"
                  style={{ width: `${invTaxa}%` }}
                />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ═══ OCORRÊNCIAS TAB ════════════════════════ */}
      {activeTab === 'ocorrencias' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Bar chart — 2 cols */}
          <div className="lg:col-span-2 bg-white rounded-2xl p-6 border border-gray-100 shadow-sm">
            <div className="flex items-center justify-between mb-5">
              <div>
                <h3 className="font-semibold text-gray-800">Evolução de Ocorrências</h3>
                <p className="text-xs text-gray-400 mt-0.5">Abertas vs Resolvidas por mês</p>
              </div>
              <div className="flex items-center gap-4">
                <span className="flex items-center gap-1.5 text-[11px] text-gray-500">
                  <span className="w-2.5 h-2.5 rounded-full bg-red-400" /> Abertas
                </span>
                <span className="flex items-center gap-1.5 text-[11px] text-gray-500">
                  <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" /> Resolvidas
                </span>
              </div>
            </div>
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={occData} barGap={4}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} width={30} axisLine={false} tickLine={false} />
                <Tooltip content={<CustomTooltip />} />
                <Bar dataKey="abertas" name="Abertas" fill="#f87171" radius={[4, 4, 0, 0]} maxBarSize={28} />
                <Bar dataKey="resolvidas" name="Resolvidas" fill="#10B981" radius={[4, 4, 0, 0]} maxBarSize={28} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* Pie chart + stats */}
          <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm">
            <h3 className="font-semibold text-gray-800 mb-1">Status das Ocorrências</h3>
            <p className="text-xs text-gray-400 mb-4">Distribuição atual</p>

            {pieData.length > 0 ? (
              <ResponsiveContainer width="100%" height={180}>
                <PieChart>
                  <Pie
                    data={pieData}
                    cx="50%"
                    cy="50%"
                    innerRadius={45}
                    outerRadius={70}
                    paddingAngle={3}
                    dataKey="value"
                  >
                    {pieData.map((_, i) => (
                      <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                    ))}
                  </Pie>
                  <Legend
                    verticalAlign="bottom"
                    iconSize={8}
                    iconType="circle"
                    formatter={(value) => <span className="text-[11px] text-gray-600">{value}</span>}
                  />
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex items-center justify-center h-[180px] text-gray-400 text-sm">
                Sem dados
              </div>
            )}

            <div className="mt-4 pt-4 border-t border-gray-100 grid grid-cols-2 gap-3">
              <div>
                <p className="text-xs text-gray-400">Total</p>
                <p className="text-xl font-bold text-gray-900">{occTotal}</p>
              </div>
              <div>
                <p className="text-xs text-gray-400">Resolvidas</p>
                <p className="text-xl font-bold text-emerald-600">{occTaxaRes}%</p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ═══ RESERVAS TAB ═══════════════════════════ */}
      {activeTab === 'reservas' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Stacked bar chart — 2 cols */}
          <div className="lg:col-span-2 bg-white rounded-2xl p-6 border border-gray-100 shadow-sm">
            <div className="flex items-center justify-between mb-5">
              <div>
                <h3 className="font-semibold text-gray-800">Reservas por Mês</h3>
                <p className="text-xs text-gray-400 mt-0.5">Confirmadas, pendentes e canceladas</p>
              </div>
              <div className="flex items-center gap-3">
                <span className="flex items-center gap-1.5 text-[11px] text-gray-500">
                  <span className="w-2.5 h-2.5 rounded-full bg-indigo-500" /> Confirmadas
                </span>
                <span className="flex items-center gap-1.5 text-[11px] text-gray-500">
                  <span className="w-2.5 h-2.5 rounded-full bg-amber-400" /> Pendentes
                </span>
                <span className="flex items-center gap-1.5 text-[11px] text-gray-500">
                  <span className="w-2.5 h-2.5 rounded-full bg-gray-300" /> Canceladas
                </span>
              </div>
            </div>
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={resData} barSize={20}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} width={30} axisLine={false} tickLine={false} />
                <Tooltip content={<CustomTooltip />} />
                <Bar dataKey="confirmadas" name="Confirmadas" fill="#6366f1" stackId="stack" radius={[0, 0, 0, 0]} />
                <Bar dataKey="pendentes" name="Pendentes" fill="#fbbf24" stackId="stack" radius={[0, 0, 0, 0]} />
                <Bar dataKey="canceladas" name="Canceladas" fill="#d1d5db" stackId="stack" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* Summary */}
          <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm flex flex-col justify-between">
            <div>
              <h3 className="font-semibold text-gray-800 mb-4">Resumo Reservas</h3>
              <div className="space-y-4">
                <div>
                  <p className="text-xs text-gray-400 font-medium mb-1">Total no período</p>
                  <p className="text-3xl font-bold text-gray-900">{resTotal}</p>
                </div>
                <div>
                  <p className="text-xs text-gray-400 font-medium mb-1">Confirmadas</p>
                  <p className="text-3xl font-bold text-indigo-600">{resConfirmadas}</p>
                </div>
              </div>
            </div>
            <div className="mt-6 pt-4 border-t border-gray-100">
              <p className="text-xs text-gray-400 font-medium mb-2">Taxa de Confirmação</p>
              <div className="flex items-end gap-2">
                <span className="text-4xl font-bold text-indigo-600">
                  {resTotal > 0 ? Math.round((resConfirmadas / resTotal) * 100) : 0}%
                </span>
              </div>
              <div className="w-full h-2 bg-gray-100 rounded-full mt-3 overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-indigo-500 to-violet-500 rounded-full transition-all duration-700"
                  style={{ width: `${resTotal > 0 ? Math.round((resConfirmadas / resTotal) * 100) : 0}%` }}
                />
              </div>
            </div>
          </div>
        </div>
      )}
      {/* ═══ FALE CONOSCO TAB ════════════════════════ */}
      {activeTab === 'faleConosco' && (
        <div className="grid grid-cols-1 gap-6">
          <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm">
            <div className="flex items-center justify-between mb-5">
              <div>
                <h3 className="font-semibold text-gray-800">Evolução Fale Conosco</h3>
                <p className="text-xs text-gray-400 mt-0.5">Tickets abertos por mês</p>
              </div>
            </div>
            <ResponsiveContainer width="100%" height={260}>
              <AreaChart data={fcData}>
                <defs>
                  <linearGradient id="gradFC" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#8b5cf6" stopOpacity={0.15} />
                    <stop offset="95%" stopColor="#8b5cf6" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} width={30} axisLine={false} tickLine={false} />
                <Tooltip content={<CustomTooltip />} />
                <Area type="monotone" dataKey="total" name="Tickets" stroke="#8b5cf6" fill="url(#gradFC)" strokeWidth={2.5} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* ═══ MORADORES TAB ════════════════════════ */}
      {activeTab === 'moradores' && (
        <div className="grid grid-cols-1 gap-6">
          <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm">
            <div className="flex items-center justify-between mb-5">
              <div>
                <h3 className="font-semibold text-gray-800">Evolução de Moradores</h3>
                <p className="text-xs text-gray-400 mt-0.5">Novos cadastros por mês</p>
              </div>
            </div>
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={mrData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} width={30} axisLine={false} tickLine={false} />
                <Tooltip content={<CustomTooltip />} />
                <Bar dataKey="total" name="Cadastros" fill="#3b82f6" radius={[4, 4, 0, 0]} maxBarSize={40} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* ═══ ENCOMENDAS TAB ════════════════════════ */}
      {activeTab === 'encomendas' && (
        <div className="grid grid-cols-1 gap-6">
          <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm">
            <div className="flex items-center justify-between mb-5">
              <div>
                <h3 className="font-semibold text-gray-800">Encomendas: Registradas vs Entregues</h3>
                <p className="text-xs text-gray-400 mt-0.5">Comparativo mensal</p>
              </div>
              <div className="flex items-center gap-3">
                <span className="flex items-center gap-1.5 text-[11px] text-gray-500">
                  <span className="w-2.5 h-2.5 rounded-full bg-amber-500" /> Registradas
                </span>
                <span className="flex items-center gap-1.5 text-[11px] text-gray-500">
                  <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" /> Entregues
                </span>
              </div>
            </div>
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={encData} barGap={4}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} width={30} axisLine={false} tickLine={false} />
                <Tooltip content={<CustomTooltip />} />
                <Bar dataKey="registradas" name="Registradas" fill="#f59e0b" radius={[4, 4, 0, 0]} maxBarSize={28} />
                <Bar dataKey="entregues" name="Entregues" fill="#10b981" radius={[4, 4, 0, 0]} maxBarSize={28} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}
    </div>
  )
}
