import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { UserCheck, Package, QrCode, ArrowRight, Bell } from 'lucide-react'

export default async function CondoDashboard() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('nome_completo, papel_sistema, bloco_txt, apto_txt, condominio_id')
    .eq('id', user.id)
    .single()

  const role = profile?.papel_sistema ?? 'Morador'
  const firstName = profile?.nome_completo?.split(' ')[0] ?? 'Morador'
  const isPorter = role.toLowerCase().includes('portaria') || role.toLowerCase().includes('porteiro')
  const isAdmin = role.toLowerCase().includes('síndico') || role.toLowerCase().includes('sindico') || role === 'admin'

  // Fetch recent invitations
  const { data: recentInvitations } = await supabase
    .from('convites')
    .select('id, guest_name, validity_date, visitante_compareceu')
    .eq('condominio_id', profile?.condominio_id ?? '')
    .order('created_at', { ascending: false })
    .limit(isPorter || isAdmin ? 10 : 5)

  // Count pending
  const pendingCount = recentInvitations?.filter(i => !i.visitante_compareceu).length ?? 0

  const quickActions = isPorter ? [
    { label: 'Liberar Visitante', sub: `${pendingCount} aguardando`, icon: UserCheck, href: '/condo/liberar-visitante', iconColor: 'text-orange-500', iconBg: 'bg-orange-500/10' },
    { label: 'Registrar Encomenda', sub: 'Novo pacote recebido', icon: Package, href: '/condo/registrar-encomenda', iconColor: 'text-blue-500', iconBg: 'bg-blue-500/10' },
  ] : [
    { label: 'Autorizar Visitante', sub: 'Gerar autorização', icon: UserCheck, href: '/condo/visitantes', iconColor: 'text-orange-500', iconBg: 'bg-orange-500/10' },
    { label: 'Minhas Encomendas', sub: 'Ver entregas', icon: Package, href: '/condo/encomendas', iconColor: 'text-blue-500', iconBg: 'bg-blue-500/10' },
    { label: 'Visitante c/ Autorização', sub: 'Check-in QR', icon: QrCode, href: '/condo/liberar-visitante', iconColor: 'text-emerald-500', iconBg: 'bg-emerald-500/10' },
  ]

  return (
    <div className="p-6 lg:p-8 max-w-5xl">
      {/* Header */}
      <div className="mb-8">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider">Bem-vindo de volta</p>
        <h1 className="text-3xl font-bold text-gray-900">{firstName} 👋</h1>
        {profile?.bloco_txt && (
          <p className="text-gray-500 text-sm mt-1">
            Unidade: <span className="font-medium text-gray-700">Bloco {profile.bloco_txt} / Apto {profile.apto_txt}</span>
          </p>
        )}
      </div>

      {/* Quick Actions */}
      <section className="mb-8">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">Ações Rápidas</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {quickActions.map(action => (
            <Link key={action.href} href={action.href}>
              <div className="bg-white rounded-2xl p-5 border border-gray-100 shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 cursor-pointer group">
                <div className="flex items-start justify-between mb-4">
                  <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${action.iconBg}`}>
                    <action.icon size={22} className={action.iconColor} />
                  </div>
                  <ArrowRight size={16} className="text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all" />
                </div>
                <p className="font-semibold text-gray-900 text-sm">{action.label}</p>
                <p className="text-xs text-gray-500 mt-0.5">{action.sub}</p>
              </div>
            </Link>
          ))}
        </div>
      </section>

      {/* Recent authorizations */}
      <section>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-800">
            {isPorter || isAdmin ? 'Autorizações Recentes' : 'Minhas Autorizações'}
          </h2>
          {pendingCount > 0 && (
            <span className="flex items-center gap-1.5 text-xs font-semibold text-[#FC5931] bg-[#FC5931]/10 px-3 py-1.5 rounded-full">
              <Bell size={12} />
              {pendingCount} pendente{pendingCount !== 1 ? 's' : ''}
            </span>
          )}
        </div>

        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
          {recentInvitations?.length ? (
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50/50">
                  <th className="text-left px-5 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">Visitante</th>
                  <th className="text-left px-5 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wider hidden sm:table-cell">Validade</th>
                  <th className="text-left px-5 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">Status</th>
                </tr>
              </thead>
              <tbody>
                {recentInvitations.map((inv, i) => (
                  <tr key={inv.id} className={`border-b border-gray-50 ${i % 2 === 0 ? '' : 'bg-gray-50/30'}`}>
                    <td className="px-5 py-3.5 font-medium text-gray-900">{inv.guest_name || '—'}</td>
                    <td className="px-5 py-3.5 text-gray-500 hidden sm:table-cell">
                      {new Date(inv.validity_date).toLocaleDateString('pt-BR')}
                    </td>
                    <td className="px-5 py-3.5">
                      <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold ${
                        inv.visitante_compareceu
                          ? 'bg-green-100 text-green-700'
                          : 'bg-orange-100 text-orange-700'
                      }`}>
                        {inv.visitante_compareceu ? '✓ Liberado' : '⏳ Aguardando'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <div className="py-12 text-center text-gray-400">
              <UserCheck size={32} className="mx-auto mb-2 opacity-30" />
              <p className="text-sm">Nenhuma autorização ainda</p>
            </div>
          )}
        </div>
      </section>
    </div>
  )
}
