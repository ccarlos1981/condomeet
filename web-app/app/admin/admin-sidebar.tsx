'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  Home, UserCheck, Users, Bell, FileText, MessageSquare,
  CalendarDays, MapPin, ClipboardList, Settings, Package,
  ChevronLeft, ChevronRight, ChevronDown, Menu, X, LogOut, Megaphone,
  AlertCircle, SlidersHorizontal, ArrowRight, BarChart3, Building2, Camera, ShoppingBag, Wallet, ShoppingCart, Store, Car, ClipboardCheck, Wrench, Briefcase, Gavel, PlusCircle, DollarSign, DoorOpen, UserSearch
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

type NavItem = {
  label: string
  href: string
  icon: React.ReactNode
  children?: { label: string; href: string; icon: React.ReactNode }[]
}

type NavSectionTyped = {
  title: string
  items: NavItem[]
}

export default function AdminSidebar({
  condoName,
  userName,
  role,
  isSuperAdmin,
}: {
  condoName: string
  userName: string
  role: string
  isSuperAdmin: boolean
}) {
  const pathname = usePathname()
  const router = useRouter()
  const supabase = createClient()
  const [collapsed, setCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [expandedMenus, setExpandedMenus] = useState<Record<string, boolean>>({})

  const toggleSubmenu = (label: string) => {
    setExpandedMenus(prev => ({ ...prev, [label]: !prev[label] }))
  }

  const sections: NavSectionTyped[] = [
    {
      title: 'Geral',
      items: [
        { label: 'Dashboard',  href: '/admin',           icon: <Home size={18} /> },
        { label: 'Aprovações', href: '/admin/aprovacoes', icon: <UserCheck size={18} /> },
        { label: 'Moradores',  href: '/admin/moradores',  icon: <Users size={18} /> },
        { label: 'Busca Moradores', href: '/condo/resident-search', icon: <UserSearch size={18} /> },
      ],
    },
    {
      title: 'Comunicação',
      items: [
        { label: 'Avisos',       href: '/admin/avisos',       icon: <Bell size={18} /> },
        { label: 'Fale Conosco', href: '/admin/fale-conosco', icon: <MessageSquare size={18} /> },
        { label: 'Ocorrências',  href: '/admin/ocorrencias',  icon: <AlertCircle size={18} /> },
        { label: 'Enquetes',     href: '/admin/enquetes',     icon: <BarChart3 size={18} /> },
        { label: 'Álbum de Fotos', href: '/admin/album-fotos', icon: <Camera size={18} /> },
      ],
    },
    {
      title: 'Gestão',
      items: [
        { label: 'Encomendas do Cond.', href: '/admin/encomendas', icon: <Package size={18} /> },
        { label: 'Autorização Visitante', href: '/admin/autorizar-visitante-portaria', icon: <UserCheck size={18} /> },
        { label: 'Documentos',      href: '/admin/documentos',      icon: <FileText size={18} /> },
        { label: 'Manutenção',      href: '/admin/manutencao',      icon: <Wrench size={18} /> },
        { label: 'Contratos',       href: '/admin/contratos',       icon: <FileText size={18} /> },
        { label: 'Áreas Comuns',    href: '/admin/areas-comuns',    icon: <MapPin size={18} /> },
        { label: 'Reservas',        href: '/admin/reservas',        icon: <CalendarDays size={18} /> },
        { label: 'Registro Turno',  href: '/admin/registro-turno',  icon: <ClipboardList size={18} /> },
        { label: 'Estrutura',       href: '/admin/estrutura',       icon: <Building2 size={18} /> },
        { label: 'Classificados',   href: '/admin/classificados',   icon: <ShoppingBag size={18} /> },
        { label: 'Fornecedores',    href: '/admin/fornecedores',    icon: <Briefcase size={18} /> },
        { label: 'Funcionários',    href: '/admin/funcionarios',    icon: <UserCheck size={18} /> },
        { label: 'Visita Proprietário', href: '/admin/visita-proprietario', icon: <DoorOpen size={18} /> },
        {
          label: 'Assembleias',
          href: '#',
          icon: <Gavel size={18} />,
          children: [
            { label: 'Passo a Passo', href: '/admin/assembleias/guia', icon: <ClipboardList size={18} /> },
            { label: 'Configurações', href: '/admin/assembleias/unidades', icon: <Building2 size={18} /> },
            { label: 'Nova Assembleia', href: '/admin/assembleias?nova=1', icon: <PlusCircle size={18} /> },
            { label: 'Assembleias', href: '/admin/assembleias', icon: <Gavel size={18} /> },
            { label: 'Dashboard', href: '/admin/assembleias/dashboard', icon: <BarChart3 size={18} /> },
            { label: 'Procurações', href: '/admin/assembleias/procuracoes', icon: <FileText size={18} /> },
          ],
        },
      ],
    },
    {
      title: 'Configuração',
      items: [
        { label: 'Configurar Acesso', href: '/admin/configurar-acesso', icon: <Settings size={18} /> },
        { label: 'Configurar Ordem',  href: '/admin/configurar-ordem',  icon: <SlidersHorizontal size={18} /> },
        ...(isSuperAdmin
          ? [
              { label: 'Push Universal', href: '/admin/push-universal', icon: <Megaphone size={18} /> },
              { label: 'Suporte Usuário', href: '/admin/suporte', icon: <MessageSquare size={18} /> },
              { label: 'Faturamento', href: '/super-admin/faturamento', icon: <DollarSign size={18} /> },
            ]
          : []),
      ],
    },
    ...(isSuperAdmin
      ? [
          {
            title: 'Empresas Parceiras',
            items: [
              { label: 'Propaganda', href: '/admin/propaganda', icon: <ShoppingBag size={18} /> },
              { label: 'Meu Bolso', href: '/admin/dinglo', icon: <Wallet size={18} /> },
              {
                label: 'Lista Inteligente',
                href: '/admin/lista-inteligente',
                icon: <ShoppingCart size={18} />,
                children: [
                  { label: 'B2B Mercados', href: '/admin/lista-b2b', icon: <Store size={18} /> },
                  { label: 'Analytics', href: '/admin/lista-analytics', icon: <BarChart3 size={18} /> },
                ],
              },
              { label: 'Garagem', href: '/admin/garagem', icon: <Car size={18} /> },
              { label: 'Checklist Parceiros', href: '/admin/checklist', icon: <ClipboardCheck size={18} /> },
            ] as NavItem[],
          },
        ]
      : []),
  ]

  async function handleLogout() {
    await supabase.auth.signOut()
    router.push('/login')
  }

  const sidebarContent = (
    <div className="flex flex-col h-full bg-[#111827] text-white">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-5 border-b border-white/10">
        <div className={`flex items-center gap-3 overflow-hidden transition-all duration-300 ${collapsed ? 'w-0 opacity-0' : 'w-full opacity-100'}`}>
          <div className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 overflow-hidden">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/logo.png" alt="Condomeet" className="w-9 h-9 object-cover" />
          </div>
          <div className="min-w-0">
            <p className="font-bold text-sm truncate">{condoName}</p>
            <p className="text-xs text-white/40 truncate">Painel Admin</p>
          </div>
        </div>
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="p-1.5 rounded-lg hover:bg-white/10 transition-colors flex-shrink-0 hidden lg:flex"
        >
          {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
        </button>
      </div>

      {/* User info */}
      {!collapsed && (
        <div className="px-4 py-3 border-b border-white/5">
          <p className="text-sm font-medium text-white/80 truncate">{userName}</p>
          <span className="inline-block mt-1 text-[10px] uppercase tracking-wider font-bold bg-[#FC5931]/20 text-[#FC5931] px-2 py-0.5 rounded-full">
            {role}
          </span>
        </div>
      )}

      {/* Nav sections */}
      <nav className="flex-1 overflow-y-auto py-3 space-y-4">
        {sections.map(section => (
          <div key={section.title}>
            {!collapsed && (
              <p className="px-5 mb-1.5 text-[10px] uppercase tracking-[0.12em] font-bold text-white/30">
                {section.title}
              </p>
            )}
            <div className="space-y-0.5 px-2">
              {section.items.map(item => {
                const isActive = pathname === item.href
                const hasChildren = item.children && item.children.length > 0
                const isChildActive = hasChildren && item.children!.some(c => pathname === c.href)
                const isExpanded = expandedMenus[item.label] || isChildActive

                return (
                  <div key={item.href}>
                    {/* Parent item */}
                    <div className="flex items-center">
                      <Link
                        href={item.href}
                        onClick={() => setMobileOpen(false)}
                        title={collapsed ? item.label : undefined}
                        className={`flex-1 flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-150 ${
                          isActive
                            ? 'bg-[#FC5931] text-white shadow-lg shadow-[#FC5931]/20'
                            : 'text-white/60 hover:bg-white/[0.06] hover:text-white'
                        }`}
                      >
                        <span className="shrink-0">{item.icon}</span>
                        {!collapsed && <span className="truncate">{item.label}</span>}
                      </Link>
                      {hasChildren && !collapsed && (
                        <button
                          onClick={() => toggleSubmenu(item.label)}
                          className="p-1.5 rounded-lg hover:bg-white/10 text-white/40 hover:text-white transition-colors"
                          title={`Expandir ${item.label}`}
                        >
                          <ChevronDown
                            size={14}
                            className={`transition-transform duration-200 ${isExpanded ? 'rotate-180' : ''}`}
                          />
                        </button>
                      )}
                    </div>

                    {/* Children sub-items */}
                    {hasChildren && isExpanded && !collapsed && (
                      <div className="ml-5 mt-0.5 space-y-0.5 border-l border-white/10 pl-2">
                        {item.children!.map(child => {
                          const isChildItemActive = pathname === child.href
                          return (
                            <Link
                              key={child.href}
                              href={child.href}
                              onClick={() => setMobileOpen(false)}
                              className={`flex items-center gap-2.5 px-3 py-2 rounded-lg text-xs font-medium transition-all duration-150 ${
                                isChildItemActive
                                  ? 'bg-[#FC5931]/80 text-white'
                                  : 'text-white/50 hover:bg-white/[0.06] hover:text-white'
                              }`}
                            >
                              <span className="shrink-0">{child.icon}</span>
                              <span className="truncate">{child.label}</span>
                            </Link>
                          )
                        })}
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          </div>
        ))}
      </nav>

      {/* Footer */}
      <div className="border-t border-white/10 px-2 py-2 space-y-0.5">
        <Link
          href="/condo"
          className="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-white/50 hover:bg-white/[0.06] hover:text-white transition-all"
        >
          <ArrowRight size={18} className="flex-shrink-0" />
          {!collapsed && <span>Portal do Morador</span>}
        </Link>
        <button
          onClick={handleLogout}
          className="flex items-center gap-3 w-full px-3 py-2.5 rounded-xl text-sm text-white/40 hover:bg-white/[0.06] hover:text-white transition-all"
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
        className="print:hidden lg:hidden fixed top-4 left-4 z-50 p-2.5 bg-[#111827] text-white rounded-xl shadow-lg shadow-black/20"
        onClick={() => setMobileOpen(!mobileOpen)}
      >
        {mobileOpen ? <X size={20} /> : <Menu size={20} />}
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div className="lg:hidden fixed inset-0 bg-black/50 z-40 backdrop-blur-sm" onClick={() => setMobileOpen(false)} />
      )}

      {/* Mobile sidebar */}
      <div className={`print:hidden lg:hidden fixed top-0 left-0 h-full w-64 z-50 transition-transform duration-300 ${mobileOpen ? 'translate-x-0' : '-translate-x-full'}`}>
        {sidebarContent}
      </div>

      {/* Desktop sidebar */}
      <div className={`print:hidden hidden lg:flex flex-col h-screen sticky top-0 transition-all duration-300 ${collapsed ? 'w-[68px]' : 'w-60'} shrink-0`}>
        {sidebarContent}
      </div>
    </>
  )
}
