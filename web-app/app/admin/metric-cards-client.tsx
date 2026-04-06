'use client'

import { useState } from 'react'
import {
  Users, ClipboardCheck, Package, UserCheck,
  AlertCircle, CalendarDays, Bell, Wrench, DoorOpen,
  MessageSquare, ShoppingBag, TrendingUp, ChevronDown, ChevronUp
} from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import Link from 'next/link'

interface MetricCounts {
  totalResidents: number
  pendingApprovals: number
  ocorrenciasAbertas: number
  faleConoscoAbertos: number
  reservasHoje: number
  reservasMes: number
  encomendasPendentes: number
  encomendasMes: number
  visitasHoje: number
  manutencoesAbertas: number
  invitationsLength: number
  avisosAtivos: number
  classificadosAtivos: number
  ocorrenciasTotal: number
}

interface MetricDef {
  label: string
  value: number
  subtitle?: string
  href?: string
  icon: LucideIcon
  color: string
  alert?: boolean
}

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

export default function MetricCardsClient({ counts }: { counts: MetricCounts }) {
  const [expanded, setExpanded] = useState(false)

  // 1. "Os 4 cards da primeira fileira, seriam: Encomendas pendentes, Pendente de aprovação, Fale conosco, Ocorrencias abertas"
  const top4Metrics: MetricDef[] = [
    { label: 'Encom. Pendentes', value: counts.encomendasPendentes, subtitle: `${counts.encomendasMes} este mês`, icon: Package, color: 'orange', href: '/admin/encomendas' },
    { label: 'Pend. Aprovação', value: counts.pendingApprovals, icon: ClipboardCheck, color: 'amber', alert: counts.pendingApprovals > 0, href: '/admin/aprovacoes' },
    { label: 'Fale Conosco', value: counts.faleConoscoAbertos, icon: MessageSquare, color: 'purple', alert: counts.faleConoscoAbertos > 0, href: '/admin/fale-conosco' },
    { label: 'Ocorrências Abertas', value: counts.ocorrenciasAbertas, icon: AlertCircle, color: 'red', alert: counts.ocorrenciasAbertas > 0, href: '/admin/ocorrencias' },
  ]

  // Default fallback for the rest
  const otherMetrics: MetricDef[] = [
    { label: 'Moradores', value: counts.totalResidents, icon: Users, color: 'blue', href: '/admin/moradores' },
    { label: 'Reservas Hoje', value: counts.reservasHoje, subtitle: `${counts.reservasMes} este mês`, icon: CalendarDays, color: 'indigo', href: '/admin/reservas' },
    { label: 'Visitas Hoje', value: counts.visitasHoje, icon: DoorOpen, color: 'teal', href: '/admin/visita-proprietario' },
    { label: 'Manu. Abertas', value: counts.manutencoesAbertas, icon: Wrench, color: 'slate', href: '/admin/manutencao' },
    { label: 'Autorizações', value: counts.invitationsLength, icon: UserCheck, color: 'emerald' },
    { label: 'Avisos Ativos', value: counts.avisosAtivos, icon: Bell, color: 'cyan', href: '/admin/avisos' },
    { label: 'Classificados', value: counts.classificadosAtivos, icon: ShoppingBag, color: 'pink', href: '/admin/classificados' },
    { label: 'Ocorr. este mês', value: counts.ocorrenciasTotal, icon: TrendingUp, color: 'violet' },
  ]

  function renderCard(m: MetricDef) {
    const c = colorMap[m.color] || colorMap.blue
    const Icon = m.icon
    const cardContent = (
      <div className={`bg-white rounded-2xl p-5 border shadow-sm transition-all hover:shadow-md h-full ${m.alert ? `${c.alertBorder} ring-1 ring-inset ring-amber-100` : 'border-gray-100'}`}>
        <div className="flex items-center justify-between mb-3">
          <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${c.iconBg}`}>
            <Icon size={20} className={c.iconColor} />
          </div>
          {m.alert && <span className="w-2.5 h-2.5 bg-amber-400 rounded-full animate-pulse" />}
        </div>
        <p className="text-2xl font-bold text-gray-900">{m.value}</p>
        <p className="text-xs text-gray-500 mt-1 font-medium">{m.label}</p>
        {m.subtitle && <p className="text-[10px] text-gray-400 mt-0.5">{m.subtitle}</p>}
      </div>
    )

    if (m.href) {
      return (
        <Link key={m.label} href={m.href} className="block transition-transform hover:-translate-y-0.5">
          {cardContent}
        </Link>
      )
    }
    return <div key={m.label} className="h-full">{cardContent}</div>
  }

  return (
    <div className="mb-8">
      {/* Primeiros 4 Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {top4Metrics.map(renderCard)}
      </div>

      {/* Outros Cards (Collapsible) */}
      <div 
        className={`grid grid-cols-2 lg:grid-cols-4 gap-4 overflow-hidden transition-all duration-300 ease-in-out ${expanded ? 'mt-4 max-h-[1000px] opacity-100' : 'max-h-0 opacity-0'}`}
      >
        {otherMetrics.map(renderCard)}
      </div>

      {/* Botão de Expansão */}
      <div className="flex justify-center mt-3">
        <button
          onClick={() => setExpanded(!expanded)}
          className="flex items-center gap-1.5 px-4 py-2 bg-white border border-gray-200 hover:border-gray-300 hover:bg-gray-50 text-gray-500 text-xs font-medium rounded-full transition-all shadow-sm"
        >
          {expanded ? (
            <>
              Ocultar outros cards <ChevronUp size={14} />
            </>
          ) : (
            <>
              Mostrar todos os cards <ChevronDown size={14} />
            </>
          )}
        </button>
      </div>
    </div>
  )
}
