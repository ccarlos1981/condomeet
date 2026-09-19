import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { UserCheck, Package, QrCode, ArrowRight, Bell, Calendar, Clock, Wrench } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { formatUnitDisplay } from '@/lib/labels'
import { isAdminRole, isPorterRole, isFeatureVisible } from '@/lib/roles'

interface RecentInvitationRow {
  id: string
  guest_name: string | null
  validity_date: string
  visitante_compareceu: boolean
}

export default async function CondoDashboard() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('nome_completo, papel_sistema, bloco_txt, apto_txt, condominio_id')
    .eq('id', user.id)
    .single()

  const { data: condo } = await supabase
    .from('condominios')
    .select('tipo_estrutura, features_config')
    .eq('id', profile?.condominio_id ?? '')
    .single()
  const tipoEstrutura = condo?.tipo_estrutura ?? 'predio'
  const featuresConfig = condo?.features_config ?? null

  const role = profile?.papel_sistema ?? 'Morador'
  const firstName = profile?.nome_completo?.split(' ')[0] ?? 'Morador'
  const isPorter = isPorterRole(role)
  const isAdmin = isAdminRole(role)

  // Permissões dinâmicas por funcionalidade baseadas no features_config do condomínio
  const canGuestCheckin = isFeatureVisible('guest_checkin', role, featuresConfig, isPorter)
  const canVisitorApproval = isFeatureVisible('visitor_approval', role, featuresConfig, false)
  const canPendingDel = isFeatureVisible('pending_del', role, featuresConfig, isAdmin)
  const canParcels = isFeatureVisible('parcels', role, featuresConfig, !isPorter)
  const canAuthorizeVisitor = isFeatureVisible('authorize_visitor', role, featuresConfig, !isPorter)
  const canPortariaAuthorize = isFeatureVisible('portaria_authorize', role, featuresConfig, isAdmin)
  const canManutencao = isFeatureVisible('manutencoes', role, featuresConfig, isAdmin)

  // Fetch recent invitations if guest checkin or visitor authorization is relevant
  let recentInvitations: RecentInvitationRow[] | null = null
  let pendingCount = 0
  if (canGuestCheckin || canAuthorizeVisitor || isAdmin) {
    const { data } = await supabase
      .from('convites')
      .select('id, guest_name, validity_date, visitante_compareceu')
      .eq('condominio_id', profile?.condominio_id ?? '')
      .order('created_at', { ascending: false })
      .limit(isPorter || isAdmin ? 10 : 5)

    recentInvitations = data as RecentInvitationRow[] | null
    pendingCount = recentInvitations?.filter(i => !i.visitante_compareceu).length ?? 0
  }

  // Fetch pending parcels count only if the user/role has parcels/pending_del feature enabled
  const shouldQueryParcels = (isPorter || isAdmin) ? (canPendingDel || canParcels) : canParcels
  let pendingParcelsCount = 0

  if (shouldQueryParcels) {
    let pendingParcelsQuery = supabase
      .from('encomendas')
      .select('*', { count: 'exact', head: true })
      .eq('condominio_id', profile?.condominio_id ?? '')
      .eq('status', 'pending')

    if (!isPorter && !isAdmin) {
      pendingParcelsQuery = pendingParcelsQuery
        .eq('bloco', profile?.bloco_txt ?? '')
        .eq('apto', profile?.apto_txt ?? '')
    }

    const { count } = await pendingParcelsQuery
    pendingParcelsCount = count ?? 0
  }

  // Fetch invitations this month count only if not porter and authorized
  let monthInvitationsCount = 0
  if (!isPorter && (canAuthorizeVisitor || isAdmin)) {
    const startOfMonth = new Date()
    startOfMonth.setDate(1)
    startOfMonth.setHours(0, 0, 0, 0)
    const { count } = await supabase
      .from('convites')
      .select('*', { count: 'exact', head: true })
      .eq('condominio_id', profile?.condominio_id ?? '')
      .gte('created_at', startOfMonth.toISOString())
    monthInvitationsCount = count ?? 0
  }

  // Build quick actions strictly according to role and features_config
  const quickActions: {
    label: string
    sub: string
    icon: LucideIcon
    href: string
    iconColor: string
    iconBg: string
  }[] = []

  if (isPorter) {
    if (canGuestCheckin) {
      quickActions.push({
        label: 'Visitante c/ Autorização',
        sub: `${pendingCount} aguardando`,
        icon: QrCode,
        href: '/condo/visitante-checkin',
        iconColor: 'text-emerald-500',
        iconBg: 'bg-emerald-500/10',
      })
    }
    if (canVisitorApproval) {
      quickActions.push({
        label: 'Liberar Visitante',
        sub: 'Visitante cadastrado',
        icon: UserCheck,
        href: '/condo/liberar-visitante',
        iconColor: 'text-orange-500',
        iconBg: 'bg-orange-500/10',
      })
    }
    if (canPendingDel || canParcels) {
      quickActions.push({
        label: 'Registrar Encomenda',
        sub: 'Novo pacote recebido',
        icon: Package,
        href: '/condo/registrar-encomenda',
        iconColor: 'text-blue-500',
        iconBg: 'bg-blue-500/10',
      })
    }
  } else {
    // Morador / Admin / Síndico
    if (isAdmin && canPortariaAuthorize) {
      quickActions.push({
        label: 'Autorização Visit. (Port.)',
        sub: 'Criar pela portaria',
        icon: UserCheck,
        href: '/condo/autorizar-visitante-portaria',
        iconColor: 'text-orange-500',
        iconBg: 'bg-orange-500/10',
      })
    } else if (canAuthorizeVisitor) {
      quickActions.push({
        label: 'Autorizar Visitante',
        sub: 'Gerar autorização',
        icon: UserCheck,
        href: '/condo/visitantes',
        iconColor: 'text-orange-500',
        iconBg: 'bg-orange-500/10',
      })
    }

    if (canParcels) {
      quickActions.push({
        label: 'Minhas Encomendas',
        sub: 'Ver entregas',
        icon: Package,
        href: '/condo/encomendas',
        iconColor: 'text-blue-500',
        iconBg: 'bg-blue-500/10',
      })
    }

    if (canGuestCheckin) {
      quickActions.push({
        label: 'Visitante c/ Autorização',
        sub: 'Check-in QR',
        icon: QrCode,
        href: '/condo/visitante-checkin',
        iconColor: 'text-emerald-500',
        iconBg: 'bg-emerald-500/10',
      })
    }

    if (canManutencao) {
      quickActions.push({
        label: 'Manutenções',
        sub: 'Histórico',
        icon: Wrench,
        href: '/condo/manutencao',
        iconColor: 'text-indigo-500',
        iconBg: 'bg-indigo-500/10',
      })
    }
  }

  // Stats strip data strictly according to enabled permissions
  const statsItems: {
    label: string
    value: number
    icon: LucideIcon
    iconColor: string
    iconBg: string
    accentColor: string
  }[] = []

  if (canGuestCheckin || canAuthorizeVisitor || isAdmin) {
    statsItems.push({
      label: 'Autorizações Pendentes',
      value: pendingCount,
      icon: Clock,
      iconColor: 'text-orange-500',
      iconBg: 'bg-orange-500/10',
      accentColor: 'border-orange-200',
    })
  }

  if (shouldQueryParcels) {
    statsItems.push({
      label: 'Encomendas a Retirar',
      value: pendingParcelsCount,
      icon: Package,
      iconColor: 'text-blue-500',
      iconBg: 'bg-blue-500/10',
      accentColor: 'border-blue-200',
    })
  }

  if (!isPorter && (canAuthorizeVisitor || isAdmin)) {
    statsItems.push({
      label: 'Convites este Mês',
      value: monthInvitationsCount,
      icon: Calendar,
      iconColor: 'text-emerald-500',
      iconBg: 'bg-emerald-500/10',
      accentColor: 'border-emerald-200',
    })
  }

  return (
    <div className="p-6 lg:p-8 max-w-5xl">
      {/* Header */}
      <div className="mb-5">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider">Bem-vindo de volta</p>
        <h1 className="text-3xl font-bold text-gray-900">{firstName} 👋</h1>
        {(() => {
          const unitStr = formatUnitDisplay({
            bloco: profile?.bloco_txt,
            apto: profile?.apto_txt,
            role: profile?.papel_sistema,
            tipoEstrutura,
            hideIfAdmin: true,
          })
          return unitStr ? (
            <p className="text-gray-500 text-sm mt-1">
              Unidade: <span className="font-medium text-gray-700">{unitStr}</span>
            </p>
          ) : (
            <p className="text-gray-500 text-sm mt-1">
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-purple-100 text-purple-700 border border-purple-200">
                Identidade Administrativa ({profile?.papel_sistema || 'Admin'})
              </span>
            </p>
          )
        })()}
      </div>

      {/* Quick Actions */}
      {quickActions.length > 0 && (
        <section className="mb-1">
          <h2 className="text-lg font-semibold text-gray-800 mb-3">Ações Rápidas</h2>
          <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            {quickActions.map(action => (
              <Link key={action.href} href={action.href}>
                <div className="bg-white rounded-2xl p-4 sm:p-5 border border-gray-100 shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 cursor-pointer group flex flex-col h-full">
                  <div className="flex items-start justify-between mb-3 border-b border-transparent">
                    <div className={`w-10 h-10 sm:w-12 sm:h-12 rounded-xl flex items-center justify-center ${action.iconBg}`}>
                      <action.icon size={20} className={action.iconColor} />
                    </div>
                    <ArrowRight size={14} className="text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all" />
                  </div>
                  <p className="font-semibold text-gray-900 text-[13px] sm:text-sm leading-tight grow">{action.label}</p>
                  <p className="text-[11px] sm:text-xs text-gray-500 mt-1 line-clamp-1">{action.sub}</p>
                </div>
              </Link>
            ))}
          </div>
        </section>
      )}

      {/* Summary Stats Strip */}
      {statsItems.length > 0 && (
        <section className="mb-3">
          <div className={`grid grid-cols-1 ${statsItems.length === 1 ? 'sm:grid-cols-1 max-w-xs' : statsItems.length === 2 ? 'grid-cols-2' : 'grid-cols-3'} gap-3`}>
            {statsItems.map(stat => (
              <div
                key={stat.label}
                className={`bg-white rounded-2xl px-4 py-3.5 border border-gray-100 shadow-sm flex items-center gap-3 border-l-[3px] ${stat.accentColor}`}
              >
                <div className={`w-9 h-9 rounded-lg flex items-center justify-center shrink-0 ${stat.iconBg}`}>
                  <stat.icon size={18} className={stat.iconColor} />
                </div>
                <div className="min-w-0">
                  <p className="text-xl font-bold text-gray-900 leading-none">{stat.value}</p>
                  <p className="text-[11px] text-gray-500 mt-0.5 truncate">{stat.label}</p>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

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
