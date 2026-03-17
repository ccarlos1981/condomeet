'use client'
import { useState, useMemo } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import {
  Home, UserCheck, Package, QrCode, Bell, LogOut,
  Building2, ChevronLeft, ChevronRight, Menu, X,
  Shield, ClipboardList, Users, CalendarDays, AlertCircle, MessageSquare, FileText, UserCog, BadgeCheck, BarChart3
} from 'lucide-react'

type NavItem = { label: string; href: string; icon: React.ReactNode; fnId?: string }

// Maps function IDs from features_config to web routes
const FN_TO_NAV: Record<string, { label: string; href: string; icon: React.ReactNode }> = {
  authorize_visitor:  { label: 'Autorizar Visitante',     href: '/condo/visitantes',           icon: <UserCheck size={18} /> },
  parcels:            { label: 'Minhas Encomendas',        href: '/condo/encomendas',            icon: <Package size={18} /> },
  guest_checkin:      { label: 'Visitante c/ Autorização', href: '/condo/liberar-visitante',               icon: <QrCode size={18} /> },
  occurrences:        { label: 'Ocorrências',              href: '/condo/ocorrencias',           icon: <AlertCircle size={18} /> },
  bookings:           { label: 'Reservas',                 href: '/condo/reservas',              icon: <CalendarDays size={18} /> },
  documents:          { label: 'Documentos',               href: '/condo/documentos',            icon: <FileText size={18} /> },
  contracts:          { label: 'Contratos',                href: '/condo/contratos',             icon: <FileText size={18} /> },
  parcel_history:     { label: 'Histórico Encomendas',     href: '/condo/encomendas',            icon: <ClipboardList size={18} /> },
  visitor_approval:   { label: 'Liberar Visitante',        href: '/condo/liberar-visitante',     icon: <UserCheck size={18} /> },
  parcel_reg:         { label: 'Registrar Encomenda',      href: '/condo/registrar-encomenda',   icon: <Package size={18} /> },
  pending_del:        { label: 'Entregas Pendentes',       href: '/condo/encomendas',            icon: <Package size={18} /> },
  approvals:          { label: 'Aprovações',               href: '/admin/aprovacoes',            icon: <Users size={18} /> },
  resident_search:    { label: 'Busca Moradores',          href: '/admin/moradores',             icon: <Users size={18} /> },
  condo_structure:    { label: 'Estrutura do Condomínio',  href: '/admin/estrutura',             icon: <Building2 size={18} /> },
  assemblies:         { label: 'Assembleias',              href: '/admin/assembleias',           icon: <Users size={18} /> },
  // Extras
  avisos:             { label: 'Avisos',                   href: '/condo/avisos',                icon: <Bell size={18} /> },
  fale_sindico:       { label: 'Fale com o Síndico',       href: '/condo/fale-sindico',          icon: <MessageSquare size={18} /> },
  registro_turno:     { label: 'Registro de Turno',        href: '/condo/registro-turno',        icon: <ClipboardList size={18} /> },
  visitor_register:   { label: 'Registrar Visitante',      href: '/condo/registrar-visitante',   icon: <BadgeCheck size={18} /> },
  enquetes:           { label: 'Enquetes',                 href: '/condo/enquetes',              icon: <BarChart3 size={18} /> },
  enquete_admin:      { label: 'Enquetes',                 href: '/condo/enquetes',              icon: <BarChart3 size={18} /> },
}

function normalizeRoleKey(role: string): string {
  return role
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, '_')
    .replace(/_+/g, '_')
    .replace(/[^a-z0-9_]/g, '')
    .replace(/^proprietario_nao_morador$/, 'prop_nao_morador')
    .replace(/^sub_sindico$/, 'sub_sindico')
}

// ── Legacy hardcoded menus (fallback when no features_config) ──
const RESIDENT_NAV: NavItem[] = [
  { label: 'Início', href: '/condo', icon: <Home size={18} /> },
  { label: 'Autorizar Visitante', href: '/condo/visitantes', icon: <UserCheck size={18} /> },
  { label: 'Minhas Encomendas', href: '/condo/encomendas', icon: <Package size={18} /> },
  { label: 'Reservas', href: '/condo/reservas', icon: <CalendarDays size={18} /> },
  { label: 'Ocorrências', href: '/condo/ocorrencias', icon: <AlertCircle size={18} /> },
  { label: 'Fale com o Síndico', href: '/condo/fale-sindico', icon: <MessageSquare size={18} /> },
  { label: 'Documentos', href: '/condo/documentos', icon: <FileText size={18} /> },
  { label: 'Contratos', href: '/condo/contratos', icon: <FileText size={18} /> },
  { label: 'Avisos', href: '/condo/avisos', icon: <Bell size={18} /> },
  { label: 'Enquetes', href: '/condo/enquetes', icon: <BarChart3 size={18} /> },
  { label: 'Visitante c/ Autorização', href: '/condo/liberar-visitante', icon: <QrCode size={18} /> },
]

const PORTER_NAV: NavItem[] = [
  { label: 'Início', href: '/condo', icon: <Home size={18} /> },
  { label: 'Liberar Visitante', href: '/condo/liberar-visitante', icon: <UserCheck size={18} /> },
  { label: 'Registrar Encomenda', href: '/condo/registrar-encomenda', icon: <Package size={18} /> },
  { label: 'Ver Encomendas', href: '/condo/encomendas', icon: <ClipboardList size={18} /> },
  { label: 'Reservas', href: '/condo/reservas', icon: <CalendarDays size={18} /> },
  { label: 'Registro de Turno', href: '/condo/registro-turno', icon: <ClipboardList size={18} /> },
]

const ADMIN_NAV: NavItem[] = [
  { label: 'Início', href: '/condo', icon: <Home size={18} /> },
  { label: 'Autorizar Visitante', href: '/condo/visitantes', icon: <UserCheck size={18} /> },
  { label: 'Minhas Encomendas', href: '/condo/encomendas', icon: <Package size={18} /> },
  { label: 'Reservas', href: '/condo/reservas', icon: <CalendarDays size={18} /> },
  { label: 'Ocorrências', href: '/condo/ocorrencias', icon: <AlertCircle size={18} /> },
  { label: 'Fale com o Síndico', href: '/condo/fale-sindico', icon: <MessageSquare size={18} /> },
  { label: 'Documentos', href: '/condo/documentos', icon: <FileText size={18} /> },
  { label: 'Contratos', href: '/condo/contratos', icon: <FileText size={18} /> },
  { label: 'Avisos', href: '/condo/avisos', icon: <Bell size={18} /> },
  { label: 'Enquetes', href: '/condo/enquetes', icon: <BarChart3 size={18} /> },
  { label: 'Visitante c/ Autorização', href: '/condo/liberar-visitante', icon: <QrCode size={18} /> },
  { label: 'Registro de Turno', href: '/condo/registro-turno', icon: <ClipboardList size={18} /> },
  { label: 'Painel Admin', href: '/admin', icon: <Shield size={18} /> },
]

function getLegacyNavForRole(role: string): NavItem[] {
  const r = role.toLowerCase()
  if (r.includes('portaria') || r.includes('porteiro')) return PORTER_NAV
  if (r.includes('síndico') || r.includes('sindico') || r === 'admin') return ADMIN_NAV
  return RESIDENT_NAV
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function buildNavFromConfig(role: string, config: any): NavItem[] | null {
  if (!config || !Array.isArray(config.functions) || config.functions.length === 0) return null

  const roleKey = normalizeRoleKey(role)
  const items: NavItem[] = [{ label: 'Início', href: '/condo', icon: <Home size={18} /> }]

  // Sort functions by order
  const sortedFns = [...config.functions].sort(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (a: any, b: any) => (a.order ?? 99) - (b.order ?? 99)
  )

  for (const fn of sortedFns) {
    const roles = fn.roles ?? {}
    const roleData = roles[roleKey]
    if (!roleData || !roleData.visible) continue

    const navEntry = FN_TO_NAV[fn.id]
    if (navEntry) {
      // Avoid duplicates by href
      if (!items.some(i => i.href === navEntry.href)) {
        items.push({ ...navEntry, fnId: fn.id })
      }
    }
  }

  // Always add Painel Admin for admin roles
  const r = role.toLowerCase()
  if (r.includes('síndico') || r.includes('sindico') || r === 'admin') {
    items.push({ label: 'Painel Admin', href: '/admin', icon: <Shield size={18} /> })
  }

  return items.length > 1 ? items : null
}

interface SidebarProps {
  role: string
  userName: string
  condoName: string
  unidade: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  featuresConfig?: any
}

export default function Sidebar({ role, userName, condoName, unidade, featuresConfig }: SidebarProps) {
  const pathname = usePathname()
  const router = useRouter()
  const supabase = createClient()
  const [collapsed, setCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const navItems = useMemo(() => {
    return buildNavFromConfig(role, featuresConfig) ?? getLegacyNavForRole(role)
  }, [role, featuresConfig])

  async function handleLogout() {
    await supabase.auth.signOut()
    router.push('/login')
  }

  const SidebarContent = () => (
    <div className="flex flex-col h-full bg-[#1a2535] text-white">
      {/* Logo + toggle */}
      <div className="flex items-center justify-between px-4 py-5 border-b border-white/10">
        <div className={`flex items-center gap-3 overflow-hidden transition-all ${collapsed ? 'w-0' : 'w-full'}`}>
          <img src="/logo.png" alt="Condomeet" className="w-9 h-9 rounded-xl object-cover flex-shrink-0" />
          <div className="min-w-0">
            <p className="font-bold text-sm truncate">{condoName}</p>
            <p className="text-xs text-white/50 truncate">{userName} · {unidade}</p>
          </div>
        </div>
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="p-1.5 rounded-lg hover:bg-white/10 transition-colors flex-shrink-0 hidden lg:flex"
        >
          {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
        </button>
      </div>

      {/* Role badge + Painel Admin shortcut */}
      {!collapsed && (
        <div className="px-4 py-2 flex flex-col gap-1.5">
          <span className="text-xs bg-[#FC5931]/20 text-[#FC5931] px-2 py-1 rounded-full font-medium self-start">{role}</span>
          {(role.toLowerCase().includes('síndico') || role.toLowerCase().includes('sindico') || role === 'admin' || role === 'ADMIN') && (
            <a
              href="/admin"
              className="flex items-center gap-2 bg-[#FC5931] hover:bg-[#D42F1D] transition-colors text-white text-xs font-bold px-3 py-1.5 rounded-xl shadow-sm shadow-[#FC5931]/40"
            >
              <Shield size={12} />
              Painel Admin
            </a>
          )}
        </div>
      )}

      {/* Nav items */}
      <nav className="flex-1 px-2 py-3 space-y-1 overflow-y-auto">
        {navItems.map(item => {
          const isActive = pathname === item.href
          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={() => setMobileOpen(false)}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-150 ${
                isActive
                  ? 'bg-[#FC5931] text-white shadow-lg shadow-[#FC5931]/30'
                  : 'text-white/70 hover:bg-white/10 hover:text-white'
              }`}
            >
              <span className="flex-shrink-0">{item.icon}</span>
              {!collapsed && <span className="truncate">{item.label}</span>}
            </Link>
          )
        })}
      </nav>

      {/* Editar Perfil */}
        <div className="px-2 pb-1">
          <Link
            href="/condo/perfil"
            onClick={() => setMobileOpen(false)}
            className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-150 ${
              pathname === '/condo/perfil'
                ? 'bg-[#FC5931] text-white shadow-lg shadow-[#FC5931]/30'
                : 'text-white/70 hover:bg-white/10 hover:text-white'
            }`}
          >
            <UserCog size={18} className="flex-shrink-0" />
            {!collapsed && <span>Editar Perfil</span>}
          </Link>
        </div>

      {/* Logout */}
      <div className="px-2 py-3 border-t border-white/10">
        <button
          onClick={handleLogout}
          className="flex items-center gap-3 w-full px-3 py-2.5 rounded-xl text-sm text-white/60 hover:bg-white/10 hover:text-white transition-all"
        >
          <LogOut size={18} className="flex-shrink-0" />
          {!collapsed && <span>Sair</span>}
        </button>
      </div>
    </div>
  )

  return (
    <>
      {/* Mobile menu button */}
      <button
        className="lg:hidden fixed top-4 left-4 z-50 p-2 bg-[#FC5931] text-white rounded-xl shadow-lg"
        onClick={() => setMobileOpen(!mobileOpen)}
      >
        {mobileOpen ? <X size={20} /> : <Menu size={20} />}
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div className="lg:hidden fixed inset-0 bg-black/40 z-40" onClick={() => setMobileOpen(false)} />
      )}

      {/* Mobile sidebar */}
      <div className={`lg:hidden fixed top-0 left-0 h-full w-64 z-50 transition-transform duration-300 ${mobileOpen ? 'translate-x-0' : '-translate-x-full'}`}>
        <SidebarContent />
      </div>

      {/* Desktop sidebar */}
      <div className={`hidden lg:flex flex-col h-screen sticky top-0 transition-all duration-300 ${collapsed ? 'w-16' : 'w-60'} flex-shrink-0`}>
        <SidebarContent />
      </div>
    </>
  )
}
