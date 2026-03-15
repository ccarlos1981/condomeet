'use client'
import { AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { useMemo } from 'react'

interface Invitation {
  created_at: string
  visitante_compareceu: boolean
}

function groupByMonth(invitations: Invitation[]) {
  const groups: Record<string, { total: number; liberados: number }> = {}
  invitations.forEach(inv => {
    const month = new Date(inv.created_at).toLocaleDateString('pt-BR', { month: 'short', year: '2-digit' })
    if (!groups[month]) groups[month] = { total: 0, liberados: 0 }
    groups[month].total++
    if (inv.visitante_compareceu) groups[month].liberados++
  })
  return Object.entries(groups).map(([month, data]) => ({ month, ...data })).slice(-6)
}

export default function AdminCharts({ invitations }: { invitations: Invitation[] }) {
  const chartData = useMemo(() => groupByMonth(invitations), [invitations])

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* Total authorizations per month */}
      <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm">
        <h3 className="font-semibold text-gray-800 mb-1">Autorizações de Acesso</h3>
        <p className="text-xs text-gray-400 mb-5">Últimos 6 meses</p>
        <ResponsiveContainer width="100%" height={200}>
          <AreaChart data={chartData}>
            <defs>
              <linearGradient id="colorTotal" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#FC3951" stopOpacity={0.18} />
                <stop offset="95%" stopColor="#FC3951" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="month" tick={{ fontSize: 11 }} />
            <YAxis tick={{ fontSize: 11 }} width={28} />
            <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} />
            <Area type="monotone" dataKey="total" name="Total" stroke="#FC3951" fill="url(#colorTotal)" strokeWidth={2} />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Liberados per month */}
      <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm">
        <h3 className="font-semibold text-gray-800 mb-1">Visitantes Liberados</h3>
        <p className="text-xs text-gray-400 mb-5">Últimos 6 meses</p>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="month" tick={{ fontSize: 11 }} />
            <YAxis tick={{ fontSize: 11 }} width={28} />
            <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} />
            <Bar dataKey="liberados" name="Liberados" fill="#10B981" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
