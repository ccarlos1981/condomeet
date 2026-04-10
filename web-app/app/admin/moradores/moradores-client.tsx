'use client'

import { useState, useMemo } from 'react'
import { Search, X, Home, Lock, Users, Shield, Building2, ChevronLeft, ChevronRight } from 'lucide-react'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

type Morador = {
  id: string
  nome_completo: string | null
  bloco_txt: string | null
  apto_txt: string | null
  status_aprovacao: string | null
  papel_sistema: string | null
  created_at: string
  email: string | null
  whatsapp: string | null
}

const ROLE_CONFIG: Record<string, { bg: string; text: string; border: string; icon: string }> = {
  'Morador (a)':  { bg: 'bg-sky-50',    text: 'text-sky-700',    border: 'border-sky-200',    icon: '🏠' },
  'Portaria':     { bg: 'bg-violet-50',  text: 'text-violet-700', border: 'border-violet-200', icon: '🚪' },
  'Porteiro (a)': { bg: 'bg-violet-50',  text: 'text-violet-700', border: 'border-violet-200', icon: '🚪' },
  'Síndico (a)':  { bg: 'bg-amber-50',   text: 'text-amber-700',  border: 'border-amber-200',  icon: '⭐' },
  'síndico':      { bg: 'bg-amber-50',   text: 'text-amber-700',  border: 'border-amber-200',  icon: '⭐' },
  'Admin':        { bg: 'bg-rose-50',    text: 'text-rose-700',   border: 'border-rose-200',   icon: '🔐' },
}
const defaultRole = { bg: 'bg-gray-50', text: 'text-gray-600', border: 'border-gray-200', icon: '👤' }

function getInitials(name: string | null) {
  if (!name) return '?'
  const parts = name.trim().split(/\s+/)
  if (parts.length >= 2) return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
  return parts[0].substring(0, 2).toUpperCase()
}

const AVATAR_COLORS = [
  'from-orange-400 to-rose-500',
  'from-blue-400 to-indigo-500',
  'from-emerald-400 to-teal-500',
  'from-purple-400 to-fuchsia-500',
  'from-amber-400 to-orange-500',
  'from-cyan-400 to-blue-500',
  'from-pink-400 to-rose-500',
  'from-lime-400 to-emerald-500',
]

function getAvatarColor(id: string) {
  let hash = 0
  for (let i = 0; i < id.length; i++) hash = id.charCodeAt(i) + ((hash << 5) - hash)
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length]
}

export default function MoradoresClient({ moradores, tipoEstrutura }: { moradores: Morador[]; tipoEstrutura?: string }) {
  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState<string | null>(null)
  const [currentPage, setCurrentPage] = useState(1)
  const ITEMS_PER_PAGE = 9

  const stats = useMemo(() => {
    const total = moradores.length
    const moradorCount = moradores.filter(m => m.papel_sistema?.includes('Morador')).length
    const portariaCount = moradores.filter(m => m.papel_sistema?.includes('Port')).length
    const sindicoCount = moradores.filter(m => m.papel_sistema?.toLowerCase().includes('sínd') || m.papel_sistema?.toLowerCase().includes('sind')).length
    const blocosCount = new Set(moradores.map(m => m.bloco_txt).filter(Boolean)).size
    return { total, moradorCount, portariaCount, sindicoCount, blocosCount }
  }, [moradores])

  const filtered = useMemo(() => {
    return moradores.filter(m => {
      if (roleFilter && !(m.papel_sistema ?? '').toLowerCase().includes(roleFilter.toLowerCase())) return false
      if (!search) return true
      const q = search.toLowerCase()
      return (
        (m.nome_completo ?? '').toLowerCase().includes(q) ||
        (m.papel_sistema ?? '').toLowerCase().includes(q) ||
        (m.bloco_txt ?? '').toLowerCase().includes(q) ||
        (m.apto_txt ?? '').toLowerCase().includes(q)
      )
    })
  }, [moradores, search, roleFilter])

  // Pagination
  const totalPages = Math.max(1, Math.ceil(filtered.length / ITEMS_PER_PAGE))
  const safePage = Math.min(currentPage, totalPages)
  const paginatedItems = filtered.slice((safePage - 1) * ITEMS_PER_PAGE, safePage * ITEMS_PER_PAGE)

  // Reset to page 1 when filters change
  const handleSearch = (val: string) => { setSearch(val); setCurrentPage(1) }
  const handleRoleFilter = (val: string | null) => { setRoleFilter(val); setCurrentPage(1) }

  return (
    <div className="max-w-6xl space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <div className="w-10 h-10 bg-gradient-to-br from-[#FC5931] to-[#D42F1D] rounded-xl flex items-center justify-center shadow-sm">
              <Users size={20} className="text-white" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Moradores</h1>
              <p className="text-gray-400 text-xs">Gestão de usuários do condomínio</p>
            </div>
          </div>
        </div>
        {/* Search */}
        <div className="relative w-full sm:w-80">
          <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={e => handleSearch(e.target.value)}
            placeholder={`Buscar por nome, ${blocoLabel.toLowerCase()}, ${aptoLabel.toLowerCase()}...`}
            className="w-full pl-10 pr-9 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] bg-white shadow-sm transition-all"
          />
          {search && (
            <button onClick={() => handleSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600" title="Limpar busca">
              <X size={14} />
            </button>
          )}
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {[
          { label: 'Total', value: stats.total, icon: Users, color: 'from-gray-600 to-gray-800', filter: null },
          { label: 'Moradores', value: stats.moradorCount, icon: Home, color: 'from-sky-500 to-blue-600', filter: 'Morador' },
          { label: 'Portaria', value: stats.portariaCount, icon: Shield, color: 'from-violet-500 to-purple-600', filter: 'Port' },
          { label: `${blocoLabel}s`, value: stats.blocosCount, icon: Building2, color: 'from-emerald-500 to-teal-600', filter: null },
        ].map(s => {
          const Icon = s.icon
          const isActive = roleFilter === s.filter && s.filter !== null
          return (
            <button
              key={s.label}
              onClick={() => s.filter ? handleRoleFilter(roleFilter === s.filter ? null : s.filter) : null}
              className={`bg-white rounded-2xl border shadow-sm p-4 text-left transition-all group ${
                isActive ? 'border-[#FC5931] ring-2 ring-[#FC5931]/20' : 'border-gray-100 hover:shadow-md'
              } ${s.filter ? 'cursor-pointer' : 'cursor-default'}`}
            >
              <div className="flex items-center justify-between mb-2">
                <div className={`w-8 h-8 rounded-lg bg-gradient-to-br ${s.color} flex items-center justify-center shadow-sm`}>
                  <Icon size={15} className="text-white" />
                </div>
                {isActive && (
                  <span className="text-[10px] font-bold text-[#FC5931] bg-[#FC5931]/10 px-2 py-0.5 rounded-full">FILTRO ATIVO</span>
                )}
              </div>
              <p className="text-2xl font-bold text-gray-900">{s.value}</p>
              <p className="text-xs text-gray-400 font-medium">{s.label}</p>
            </button>
          )
        })}
      </div>

      {/* Role filter chips */}
      {roleFilter && (
        <div className="flex items-center gap-2">
          <span className="text-xs text-gray-500">Filtrando por:</span>
          <button
            onClick={() => handleRoleFilter(null)}
            className="flex items-center gap-1.5 text-xs font-semibold bg-[#FC5931]/10 text-[#FC5931] px-3 py-1.5 rounded-full hover:bg-[#FC5931]/20 transition-colors"
          >
            {roleFilter}
            <X size={12} />
          </button>
          <span className="text-xs text-gray-400">{filtered.length} encontrado{filtered.length !== 1 ? 's' : ''}</span>
        </div>
      )}

      {/* Empty State */}
      {filtered.length === 0 ? (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-16 text-center">
          <div className="w-16 h-16 bg-gray-50 rounded-2xl mx-auto mb-4 flex items-center justify-center">
            <Users size={28} className="text-gray-300" />
          </div>
          <p className="font-semibold text-gray-600 mb-1">Nenhum morador encontrado</p>
          {search && <p className="text-sm text-gray-400">Tente outro termo de busca.</p>}
        </div>
      ) : (
        /* Paginated Cards */
        <>
          {/* Info bar */}
          <div className="flex items-center justify-between">
            <p className="text-xs text-gray-400">
              Mostrando {(safePage - 1) * ITEMS_PER_PAGE + 1}–{Math.min(safePage * ITEMS_PER_PAGE, filtered.length)} de {filtered.length}
            </p>
            <p className="text-xs text-gray-400">
              Página {safePage} de {totalPages}
            </p>
          </div>

          {/* Cards grid — 3 cols × 3 rows = 9 per page */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {paginatedItems.map(m => {
              const role = ROLE_CONFIG[m.papel_sistema ?? ''] ?? defaultRole
              const isBlocked = m.status_aprovacao === 'bloqueado'
              const initials = getInitials(m.nome_completo)
              const avatarGrad = getAvatarColor(m.id)

              return (
                <div
                  key={m.id}
                  className={`bg-white rounded-xl border shadow-sm overflow-hidden transition-all ${
                    isBlocked ? 'border-red-200 opacity-50' : 'border-gray-100 hover:shadow-md hover:border-gray-200'
                  }`}
                >
                  <div className="p-4">
                    <div className="flex items-center gap-3">
                      {/* Avatar */}
                      <div className={`w-11 h-11 rounded-full flex items-center justify-center flex-shrink-0 shadow-sm ${
                        isBlocked
                          ? 'bg-red-100'
                          : `bg-gradient-to-br ${avatarGrad}`
                      }`}>
                        {isBlocked
                          ? <Lock size={16} className="text-red-400" />
                          : <span className="text-white text-sm font-bold">{initials}</span>}
                      </div>

                      {/* Info */}
                      <div className="min-w-0 flex-1">
                        <p className={`font-semibold text-sm leading-tight truncate ${
                          isBlocked ? 'line-through text-gray-400' : 'text-gray-900'
                        }`}>
                          {m.nome_completo || '—'}
                        </p>
                        
                        <div className="mt-1 flex flex-col gap-0.5">
                          {m.email && (
                            <span className="text-xs text-gray-500 truncate" title={m.email}>
                              📧 {m.email}
                            </span>
                          )}
                          {m.whatsapp && (
                            <span className="text-xs text-gray-500 truncate" title={m.whatsapp}>
                              📱 {m.whatsapp}
                            </span>
                          )}
                        </div>

                        <div className="flex items-center gap-2 mt-1.5">
                          {m.papel_sistema && (
                            <span className={`text-[10px] px-2 py-0.5 rounded-full font-semibold border ${role.bg} ${role.text} ${role.border}`}>
                              {role.icon} {m.papel_sistema}
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Footer */}
                  <div className="px-4 py-2.5 bg-gray-50/80 border-t border-gray-100 flex items-center justify-between">
                    <div className="flex items-center gap-1.5 text-xs text-gray-500">
                      <Home size={12} className="text-gray-400" />
                      <span>{m.bloco_txt ? `${blocoLabel} ${m.bloco_txt}` : '—'}{m.apto_txt ? ` · ${aptoLabel} ${m.apto_txt}` : ''}</span>
                    </div>
                    <span className="text-[10px] text-gray-400">
                      {new Date(m.created_at).toLocaleDateString('pt-BR', { month: 'short', year: '2-digit' })}
                    </span>
                  </div>
                </div>
              )
            })}
          </div>

          {/* Pagination Controls */}
          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-1.5 pt-2">
              {/* Prev */}
              <button
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                disabled={safePage <= 1}
                className="flex items-center gap-1 px-3 py-2 rounded-xl text-sm font-medium border border-gray-200 bg-white hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed transition-all"
              >
                <ChevronLeft size={14} />
                Anterior
              </button>

              {/* Page numbers */}
              {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => (
                <button
                  key={page}
                  onClick={() => setCurrentPage(page)}
                  className={`w-9 h-9 rounded-xl text-sm font-bold transition-all ${
                    page === safePage
                      ? 'bg-[#FC5931] text-white shadow-sm'
                      : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  {page}
                </button>
              ))}

              {/* Next */}
              <button
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                disabled={safePage >= totalPages}
                className="flex items-center gap-1 px-3 py-2 rounded-xl text-sm font-medium border border-gray-200 bg-white hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed transition-all"
              >
                Próximo
                <ChevronRight size={14} />
              </button>
            </div>
          )}
        </>
      )}
    </div>
  )
}
