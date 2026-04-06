import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import {
  Building2, DoorOpen, AlertCircle, Users, Package, Bell, FileText, CalendarDays
} from 'lucide-react'
import AdminCharts from './charts'
import { getEstruturaLabel } from '@/lib/labels'
import MetricCardsClient from './metric-cards-client'

export default async function AdminDashboard() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, nome_completo')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo_estrutura, nome')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condoData?.tipo_estrutura ?? 'predio'

  // ── Fetch all metrics in parallel ──────────────────────────
  const now = new Date()
  const startOfMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01T00:00:00`
  const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
  const startOfDay = `${todayStr}T00:00:00`
  const endOfDay = `${todayStr}T23:59:59`

  const [
    { count: totalResidents },
    { count: pendingApprovals },
    { data: invitations },
    { count: ocorrenciasAbertas },
    { count: ocorrenciasTotal },
    { count: reservasHoje },
    { count: reservasMes },
    { count: encomendasPendentes },
    { count: encomendasMes },
    { count: avisosAtivos },
    { count: manutencoesAbertas },
    { count: visitasHoje },
    { count: faleConoscoAbertos },
    { count: classificadosAtivos },
    { data: recentOcorrencias },
    { data: recentVisitas },
  ] = await Promise.all([
    // Moradores aprovados
    supabase.from('perfil').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).eq('status_aprovacao', 'aprovado'),
    // Pendentes
    supabase.from('perfil').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).eq('status_aprovacao', 'pendente'),
    // Convites (últimos 200 para gráficos)
    supabase.from('convites').select('created_at, visitante_compareceu')
      .eq('condominio_id', condoId).order('created_at', { ascending: false }).limit(200),
    // Ocorrências abertas
    supabase.from('ocorrencias').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).neq('status', 'resolvido'),
    // Ocorrências total do mês
    supabase.from('ocorrencias').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).gte('created_at', startOfMonth),
    // Reservas hoje
    supabase.from('reservas').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).eq('data', todayStr),
    // Reservas no mês
    supabase.from('reservas').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).gte('data', todayStr.substring(0, 7) + '-01'),
    // Encomendas pendentes
    supabase.from('encomendas').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).eq('status', 'pendente'),
    // Encomendas mês
    supabase.from('encomendas').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).gte('created_at', startOfMonth),
    // Avisos ativos
    supabase.from('avisos').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).eq('ativo', true),
    // Manutenções abertas
    supabase.from('manutencoes').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).neq('status', 'concluida'),
    // Visitas hoje
    supabase.from('visita_proprietario').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).gte('created_at', startOfDay).lte('created_at', endOfDay),
    // Fale Conosco abertos
    supabase.from('fale_sindico_threads').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).eq('status', 'aberto'),
    // Classificados ativos
    supabase.from('classificados').select('*', { count: 'exact', head: true })
      .eq('condominio_id', condoId).eq('ativo', true),
    // Atividade recente — últimas 5 ocorrências
    supabase.from('ocorrencias').select('id, titulo, status, created_at')
      .eq('condominio_id', condoId).order('created_at', { ascending: false }).limit(5),
    // Atividade recente — últimas 5 visitas
    supabase.from('visita_proprietario').select('id, nome_morador, tipo, bloco, apto, created_at')
      .eq('condominio_id', condoId).order('created_at', { ascending: false }).limit(5),
  ])

  // ── Data for charts ────────────────────────────────────────
  // Monthly ocorrencias (last 6 months)
  const sixMonthsAgo = new Date()
  sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6)
  const { data: ocorrenciasMensal } = await supabase
    .from('ocorrencias')
    .select('created_at, status')
    .eq('condominio_id', condoId)
    .gte('created_at', sixMonthsAgo.toISOString())

  // Monthly reservas
  const { data: reservasMensal } = await supabase
    .from('reservas')
    .select('data, status')
    .eq('condominio_id', condoId)
    .gte('data', sixMonthsAgo.toISOString().substring(0, 10))

  // Monthly fale conosco
  const { data: faleConoscoMensal } = await supabase
    .from('fale_sindico_threads')
    .select('created_at, status')
    .eq('condominio_id', condoId)
    .gte('created_at', sixMonthsAgo.toISOString())

  // Monthly moradores
  const { data: moradoresMensal } = await supabase
    .from('perfil')
    .select('created_at, status_aprovacao')
    .eq('condominio_id', condoId)
    .gte('created_at', sixMonthsAgo.toISOString())

  // Monthly encomendas
  const { data: encomendasMensal } = await supabase
    .from('encomendas')
    .select('created_at, status')
    .eq('condominio_id', condoId)
    .gte('created_at', sixMonthsAgo.toISOString())

  const colorMap: Record<string, { iconBg: string; iconColor: string; alertBorder: string }> = {
    blue:    { iconBg: 'bg-blue-50',    iconColor: 'text-blue-500',    alertBorder: 'border-blue-200' },
    amber:   { iconBg: 'bg-amber-50',   iconColor: 'text-amber-500',   alertBorder: 'border-amber-200' },
    red:     { iconBg: 'bg-red-50',     iconColor: 'text-red-500',     alertBorder: 'border-red-200' },
    purple:  { iconBg: 'bg-purple-50',  iconColor: 'text-purple-500',  alertBorder: 'border-purple-200' },
    indigo:  { iconBg: 'bg-indigo-50',  iconColor: 'text-indigo-500',  alertBorder: 'border-indigo-200' },
    orange:  { iconBg: 'bg-orange-50',  iconColor: 'text-orange-500',  alertBorder: 'border-orange-200' },
    teal:    { iconBg: 'bg-teal-50',    iconColor: 'text-teal-500',    alertBorder: 'border-teal-200' },
    slate:   { iconBg: 'bg-slate-50',   iconColor: 'text-slate-500',   alertBorder: 'border-slate-200' },
    emerald: { iconBg: 'bg-emerald-50', iconColor: 'text-emerald-500', alertBorder: 'border-emerald-200' },
    cyan:    { iconBg: 'bg-cyan-50',    iconColor: 'text-cyan-500',    alertBorder: 'border-cyan-200' },
    pink:    { iconBg: 'bg-pink-50',    iconColor: 'text-pink-500',    alertBorder: 'border-pink-200' },
    violet:  { iconBg: 'bg-violet-50',  iconColor: 'text-violet-500',  alertBorder: 'border-violet-200' },
  }

  function fmtTime(iso: string) {
    return new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) + 'h'
  }

  function fmtDate(iso: string) {
    return new Date(iso).toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' })
  }

  return (
    <div>
      {/* ── Header ──────────────────────────────────────────── */}
      <div className="mb-8 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-2">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-gray-500 text-sm mt-0.5">
            {condoData?.nome ?? 'Condomínio'} — {fmtDate(now.toISOString())}
          </p>
        </div>
        <p className="text-xs text-gray-400">
          Olá, <span className="font-semibold text-gray-600">{profile?.nome_completo?.split(' ')[0] ?? 'Admin'}</span>
        </p>
      </div>

      <MetricCardsClient counts={{
        totalResidents: totalResidents ?? 0,
        pendingApprovals: pendingApprovals ?? 0,
        ocorrenciasAbertas: ocorrenciasAbertas ?? 0,
        faleConoscoAbertos: faleConoscoAbertos ?? 0,
        reservasHoje: reservasHoje ?? 0,
        reservasMes: reservasMes ?? 0,
        encomendasPendentes: encomendasPendentes ?? 0,
        encomendasMes: encomendasMes ?? 0,
        visitasHoje: visitasHoje ?? 0,
        manutencoesAbertas: manutencoesAbertas ?? 0,
        invitationsLength: invitations?.length ?? 0,
        avisosAtivos: avisosAtivos ?? 0,
        classificadosAtivos: classificadosAtivos ?? 0,
        ocorrenciasTotal: ocorrenciasTotal ?? 0
      }} />

      {/* ── Charts ──────────────────────────────────────────── */}
      <AdminCharts
        invitations={invitations ?? []}
        ocorrencias={ocorrenciasMensal ?? []}
        reservas={reservasMensal ?? []}
        faleConosco={faleConoscoMensal ?? []}
        moradores={moradoresMensal ?? []}
        encomendas={encomendasMensal ?? []}
      />

      {/* ── Recent Activity + Quick Actions ─────────────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
        {/* Recent Activity */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
          <div className="px-5 py-4 border-b border-gray-100">
            <h3 className="font-semibold text-gray-800">Atividade Recente</h3>
          </div>
          <div className="divide-y divide-gray-50">
            {(recentVisitas ?? []).slice(0, 5).map(v => (
              <div key={v.id} className="px-5 py-3 flex items-center gap-3">
                <div className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 ${v.tipo === 'entrada' ? 'bg-emerald-50 text-emerald-600' : 'bg-orange-50 text-orange-600'}`}>
                  <DoorOpen size={15} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-800 truncate">{v.nome_morador}</p>
                  <p className="text-[11px] text-gray-400">
                    {v.tipo === 'entrada' ? 'Entrada' : 'Saída'} · {v.bloco ? `Bl ${v.bloco}` : ''} {v.apto ? `Ap ${v.apto}` : ''}
                  </p>
                </div>
                <span className="text-[11px] text-gray-400 shrink-0">{fmtTime(v.created_at)}</span>
              </div>
            ))}
            {(recentOcorrencias ?? []).slice(0, 3).map(o => (
              <div key={o.id} className="px-5 py-3 flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-red-50 flex items-center justify-center shrink-0">
                  <AlertCircle size={15} className="text-red-500" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-800 truncate">{o.titulo}</p>
                  <p className="text-[11px] text-gray-400 capitalize">{o.status}</p>
                </div>
                <span className="text-[11px] text-gray-400 shrink-0">{fmtDate(o.created_at)}</span>
              </div>
            ))}
            {(recentVisitas ?? []).length === 0 && (recentOcorrencias ?? []).length === 0 && (
              <div className="px-5 py-8 text-center text-gray-400 text-sm">Nenhuma atividade recente</div>
            )}
          </div>
        </div>

        {/* Quick Actions */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
          <div className="px-5 py-4 border-b border-gray-100">
            <h3 className="font-semibold text-gray-800">Acessos Rápidos</h3>
          </div>
          <div className="p-4 grid grid-cols-2 gap-3">
            {[
              { label: 'Estrutura', desc: getEstruturaLabel(tipoEstrutura), icon: Building2, color: 'indigo', href: '/admin/estrutura' },
              { label: 'Moradores', desc: 'Gestão de perfis', icon: Users, color: 'blue', href: '/admin/moradores' },
              { label: 'Encomendas', desc: 'Histórico e gestão', icon: Package, color: 'orange', href: '/admin/encomendas' },
              { label: 'Avisos', desc: 'Criar e gerenciar', icon: Bell, color: 'cyan', href: '/admin/avisos' },
              { label: 'Documentos', desc: 'Pastas e arquivos', icon: FileText, color: 'slate', href: '/admin/documentos' },
              { label: 'Reservas', desc: 'Áreas comuns', icon: CalendarDays, color: 'emerald', href: '/admin/reservas' },
            ].map(q => {
              const c = colorMap[q.color] || colorMap.blue
              const Icon = q.icon
              return (
                <a
                  key={q.label}
                  href={q.href}
                  className="flex items-center gap-3 p-3 rounded-xl border border-gray-100 hover:shadow-md hover:-translate-y-0.5 transition-all"
                >
                  <div className={`w-9 h-9 rounded-lg ${c.iconBg} flex items-center justify-center shrink-0`}>
                    <Icon size={18} className={c.iconColor} />
                  </div>
                  <div className="min-w-0">
                    <p className="font-semibold text-gray-900 text-sm">{q.label}</p>
                    <p className="text-[11px] text-gray-400">{q.desc}</p>
                  </div>
                </a>
              )
            })}
          </div>
        </div>
      </div>

      {/* ── Pending Approvals Alert ──────────────────────────── */}
      {(pendingApprovals ?? 0) > 0 && (
        <div className="mt-6 bg-amber-50 border border-amber-200 rounded-2xl p-5 flex items-center justify-between">
          <div>
            <p className="font-semibold text-amber-800">{pendingApprovals} morador{(pendingApprovals ?? 0) > 1 ? 'es' : ''} aguardando aprovação</p>
            <p className="text-sm text-amber-600 mt-0.5">Revise e aprove os cadastros pendentes</p>
          </div>
          <a href="/admin/aprovacoes" className="px-4 py-2 bg-amber-500 text-white rounded-xl text-sm font-semibold hover:bg-amber-600 transition-colors whitespace-nowrap">
            Ver Aprovações
          </a>
        </div>
      )}
    </div>
  )
}
