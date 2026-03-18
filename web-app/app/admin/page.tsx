import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { Users, ClipboardCheck, Package, UserCheck, Building2 } from 'lucide-react'
import AdminCharts from './charts'

export default async function AdminDashboard() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id

  // Fetch metrics
  const [{ count: totalResidents }, { count: pendingApprovals }, { data: invitations }] = await Promise.all([
    supabase.from('perfil').select('*', { count: 'exact', head: true }).eq('condominio_id', condoId ?? '').eq('status_aprovacao', 'aprovado'),
    supabase.from('perfil').select('*', { count: 'exact', head: true }).eq('condominio_id', condoId ?? '').eq('status_aprovacao', 'pendente'),
    supabase.from('convites').select('created_at, visitante_compareceu').eq('condominio_id', condoId ?? '').order('created_at', { ascending: false }).limit(100),
  ])

  const metrics = [
    { label: 'Moradores', value: totalResidents ?? 0, icon: Users, iconColor: 'text-blue-500', iconBg: 'bg-blue-500/10' },
    { label: 'Aprovações Pendentes', value: pendingApprovals ?? 0, icon: ClipboardCheck, iconColor: 'text-amber-500', iconBg: 'bg-amber-500/10', alert: (pendingApprovals ?? 0) > 0 },
    { label: 'Autorizações (total)', value: invitations?.length ?? 0, icon: UserCheck, iconColor: 'text-orange-500', iconBg: 'bg-orange-500/10' },
    { label: 'Liberados', value: invitations?.filter(i => i.visitante_compareceu).length ?? 0, icon: Package, iconColor: 'text-emerald-500', iconBg: 'bg-emerald-500/10' },
  ]

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-500 text-sm mt-1">Visão geral do condomínio</p>
      </div>

      {/* Metric cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {metrics.map(m => (
          <div key={m.label} className={`bg-white rounded-2xl p-5 border shadow-sm ${m.alert ? 'border-amber-200 bg-amber-50' : 'border-gray-100'}`}>
            <div className="flex items-center justify-between mb-3">
              <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${m.iconBg}`}>
                <m.icon size={20} className={m.iconColor} />
              </div>
              {m.alert && <span className="w-2 h-2 bg-amber-400 rounded-full animate-pulse" />}
            </div>
            <p className="text-2xl font-bold text-gray-900">{m.value}</p>
            <p className="text-xs text-gray-500 mt-1">{m.label}</p>
          </div>
        ))}
      </div>

      {/* Quick Actions */}
      <div className="mb-8">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">Acessos Rápidos</h2>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <a href="/admin/estrutura" className="bg-white rounded-2xl p-4 border border-gray-100 shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all group flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-indigo-50 flex items-center justify-center">
              <Building2 size={20} className="text-indigo-500" />
            </div>
            <div>
              <p className="font-semibold text-gray-900 text-sm">Estrutura</p>
              <p className="text-xs text-gray-500">Blocos e Aptos</p>
            </div>
          </a>
          <a href="/admin/moradores" className="bg-white rounded-2xl p-4 border border-gray-100 shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all group flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center">
              <Users size={20} className="text-blue-500" />
            </div>
            <div>
              <p className="font-semibold text-gray-900 text-sm">Moradores</p>
              <p className="text-xs text-gray-500">Gestão de perfis</p>
            </div>
          </a>
          <a href="/admin/encomendas" className="bg-white rounded-2xl p-4 border border-gray-100 shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all group flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-orange-50 flex items-center justify-center">
              <Package size={20} className="text-orange-500" />
            </div>
            <div>
              <p className="font-semibold text-gray-900 text-sm">Encomendas</p>
              <p className="text-xs text-gray-500">Histórico e gestão</p>
            </div>
          </a>
        </div>
      </div>

      {/* Charts */}
      <AdminCharts invitations={invitations ?? []} />

      {/* Pending Approvals Alert */}
      {(pendingApprovals ?? 0) > 0 && (
        <div className="mt-6 bg-amber-50 border border-amber-200 rounded-2xl p-5 flex items-center justify-between">
          <div>
            <p className="font-semibold text-amber-800">{pendingApprovals} morador{(pendingApprovals ?? 0) > 1 ? 'es' : ''} aguardando aprovação</p>
            <p className="text-sm text-amber-600 mt-0.5">Revise e aprove os cadastros pendentes</p>
          </div>
          <a href="/admin/aprovacoes" className="px-4 py-2 bg-amber-500 text-white rounded-xl text-sm font-semibold hover:bg-amber-600 transition-colors">
            Ver Aprovações
          </a>
        </div>
      )}
    </div>
  )
}
