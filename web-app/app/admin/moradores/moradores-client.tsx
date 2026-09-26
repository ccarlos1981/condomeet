'use client'

import { useState, useMemo, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import {
  Search,
  X,
  Home,
  Lock,
  Unlock,
  Users,
  Shield,
  Building2,
  ChevronLeft,
  ChevronRight,
  Edit,
  SlidersHorizontal,
  Filter,
  RotateCcw,
  CheckCircle,
  XCircle,
  Clock,
  UserX,
  PlusCircle,
} from 'lucide-react'
import { getBlocoLabel, getAptoLabel, isTechnicalAdminUnit, filterResidentialBlocos, formatUnitDisplay } from '@/lib/labels'
import EditProfileModal from '@/components/edit-profile-modal'
import BlockConfirmModal from './block-confirm-modal'
import InactivateConfirmModal from './inactivate-confirm-modal'
import CreateResidentLinkModal from './create-resident-link-modal'
import { adminToggleBlockStatus } from '@/app/admin/actions'
import { isTechnicalAdminRole } from '@/lib/roles'

type Morador = {
  id: string
  nome_completo: string | null
  bloco_txt: string | null
  apto_txt: string | null
  status_aprovacao: string | null
  papel_sistema: string | null
  tipo_morador?: string | null
  created_at: string
  email: string | null
  whatsapp: string | null
  bloqueado?: boolean | null
}

export type CadastralStatus = 'ativo' | 'pendente' | 'bloqueado' | 'rejeitado' | 'inativo'
export type FilterStatus = 'todos' | CadastralStatus

interface AdvancedFilters {
  bloco: string
  apto: string
  perfil: string
  whatsapp: string
  tipoMorador: string
  status: FilterStatus
  dataInicio: string
  dataFim: string
}

const INITIAL_FILTERS: AdvancedFilters = {
  bloco: '',
  apto: '',
  perfil: '',
  whatsapp: '',
  tipoMorador: '',
  status: 'todos',
  dataInicio: '',
  dataFim: '',
}

export function getCadastralStatus(m: Morador): CadastralStatus {
  if (m.bloqueado === true || m.status_aprovacao === 'bloqueado') {
    return 'bloqueado'
  }
  if (m.status_aprovacao === 'inativo') {
    return 'inativo'
  }
  if (m.status_aprovacao === 'pendente') {
    return 'pendente'
  }
  if (m.status_aprovacao === 'rejeitado' || m.status_aprovacao === 'reprovado') {
    return 'rejeitado'
  }
  if (m.status_aprovacao === 'aprovado') {
    return 'ativo'
  }
  return 'pendente'
}

const STATUS_BADGE: Record<CadastralStatus, {
  label: string
  bg: string
  text: string
  border: string
  icon: typeof CheckCircle
}> = {
  ativo: {
    label: 'ATIVO',
    bg: 'bg-emerald-50',
    text: 'text-emerald-700',
    border: 'border-emerald-200',
    icon: CheckCircle,
  },
  pendente: {
    label: 'PENDENTE',
    bg: 'bg-amber-50',
    text: 'text-amber-700',
    border: 'border-amber-200',
    icon: Clock,
  },
  bloqueado: {
    label: 'BLOQUEADO',
    bg: 'bg-red-50',
    text: 'text-red-700',
    border: 'border-red-200',
    icon: Lock,
  },
  rejeitado: {
    label: 'REJEITADO',
    bg: 'bg-gray-100',
    text: 'text-gray-700',
    border: 'border-gray-300',
    icon: XCircle,
  },
  inativo: {
    label: 'INATIVO',
    bg: 'bg-zinc-100',
    text: 'text-zinc-600',
    border: 'border-zinc-300',
    icon: UserX,
  },
}

function cleanDigits(val?: string | null): string {
  return (val ?? '').replace(/\D/g, '')
}

const ROLE_CONFIG: Record<string, { bg: string; text: string; border: string; icon: string }> = {
  'Morador (a)':  { bg: 'bg-sky-50',    text: 'text-sky-700',    border: 'border-sky-200',    icon: '🏠' },
  'Morador':      { bg: 'bg-sky-50',    text: 'text-sky-700',    border: 'border-sky-200',    icon: '🏠' },
  'morador':      { bg: 'bg-sky-50',    text: 'text-sky-700',    border: 'border-sky-200',    icon: '🏠' },
  'Portaria':     { bg: 'bg-violet-50',  text: 'text-violet-700', border: 'border-violet-200', icon: '🚪' },
  'Porteiro (a)': { bg: 'bg-violet-50',  text: 'text-violet-700', border: 'border-violet-200', icon: '🚪' },
  'Porteiro':     { bg: 'bg-violet-50',  text: 'text-violet-700', border: 'border-violet-200', icon: '🚪' },
  'Síndico (a)':  { bg: 'bg-amber-50',   text: 'text-amber-700',  border: 'border-amber-200',  icon: '⭐' },
  'Síndico':      { bg: 'bg-amber-50',   text: 'text-amber-700',  border: 'border-amber-200',  icon: '⭐' },
  'síndico':      { bg: 'bg-amber-50',   text: 'text-amber-700',  border: 'border-amber-200',  icon: '⭐' },
  'Admin':        { bg: 'bg-rose-50',    text: 'text-rose-700',   border: 'border-rose-200',   icon: '🔐' },
  'Administrador':{ bg: 'bg-rose-50',    text: 'text-rose-700',   border: 'border-rose-200',   icon: '🔐' },
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

export default function MoradoresClient({
  moradores: initialMoradores,
  tipoEstrutura,
  currentUserRole,
  blocosCadastrados = [],
}: {
  moradores: Morador[]
  tipoEstrutura?: string
  currentUserRole?: string | null
  blocosCadastrados?: string[]
}) {
  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)
  const router = useRouter()

  // Local synced state for immediate reactive UI updates
  const [items, setItems] = useState<Morador[]>(initialMoradores)
  useEffect(() => {
    setItems(initialMoradores)
  }, [initialMoradores])

  // Alias moradores to items for all computed stats and filters
  const moradores = items
  
  // Existing Search States
  const [search, setSearch] = useState('')
  const [emailSearch, setEmailSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState<string | null>(null)
  const [currentPage, setCurrentPage] = useState(1)
  const [editingProfile, setEditingProfile] = useState<Morador | null>(null)
  const ITEMS_PER_PAGE = 9

  // Block / Unblock Modal State
  const [confirmAction, setConfirmAction] = useState<{ profile: Morador; action: 'block' | 'unblock' } | null>(null)
  const [actionLoading, setActionLoading] = useState(false)
  const [actionError, setActionError] = useState<string | null>(null)

  async function handleConfirmBlockAction() {
    if (!confirmAction) return
    setActionLoading(true)
    setActionError(null)

    const res = await adminToggleBlockStatus({
      profileId: confirmAction.profile.id,
      action: confirmAction.action,
    })

    if (res.error) {
      setActionError(res.error)
      setActionLoading(false)
      return
    }

    // Immediate reactive local state update
    setItems(prev => prev.map(m => {
      if (m.id === confirmAction.profile.id) {
        return {
          ...m,
          status_aprovacao: res.newStatus!,
          bloqueado: res.newBloqueado!,
        }
      }
      return m
    }))

    setActionLoading(false)
    setConfirmAction(null)
    router.refresh()
  }

  // Inactivate Resident Modal State
  const [inactivateTarget, setInactivateTarget] = useState<Morador | null>(null)

  function handleInactivationSuccess(result: any) {
    if (!result || !inactivateTarget) return
    const targetId = inactivateTarget.id

    setItems(prev => prev.map(m => {
      if (m.id === targetId) {
        const updated = { ...m }
        if (result.profile_status) {
          updated.status_aprovacao = result.profile_status
        }
        if (result.resident_type) {
          updated.tipo_morador = result.resident_type
        }
        if (result.profile_status === 'inativo') {
          updated.bloqueado = false
          updated.bloco_txt = null
          updated.apto_txt = null
        }
        return updated
      }
      return m
    }))

    setInactivateTarget(null)
    router.refresh()
  }

  // Create Resident Link Modal State (Gate 3C.7)
  const [createLinkTarget, setCreateLinkTarget] = useState<Morador | null>(null)

  function handleCreateLinkSuccess(result: any) {
    if (!result || !createLinkTarget) return
    const targetId = createLinkTarget.id

    setItems(prev => prev.map(m => {
      if (m.id === targetId) {
        return {
          ...m,
          status_aprovacao: result.profile_status || 'aprovado',
          bloqueado: false,
          bloco_txt: result.block ?? m.bloco_txt,
          apto_txt: result.apartment ?? m.apto_txt,
          tipo_morador: result.resident_type ?? m.tipo_morador,
        }
      }
      return m
    }))

    setCreateLinkTarget(null)
    router.refresh()
  }

  // Advanced Filters State (Starts CLOSED)
  const [isFiltersOpen, setIsFiltersOpen] = useState(false)
  const [draftFilters, setDraftFilters] = useState<AdvancedFilters>(INITIAL_FILTERS)
  const [appliedFilters, setAppliedFilters] = useState<AdvancedFilters>(INITIAL_FILTERS)

  // Options for Bloco dropdown: combine distinct perfil.bloco_txt + public.blocos, exclude Admin, natural sort
  const availableBlocos = useMemo(() => {
    const set = new Set<string>()
    blocosCadastrados.forEach(b => {
      const trimmed = b?.trim()
      if (trimmed && trimmed.toLowerCase() !== 'admin') {
        set.add(trimmed)
      }
    })
    moradores.forEach(m => {
      const trimmed = m.bloco_txt?.trim()
      if (trimmed && trimmed.toLowerCase() !== 'admin') {
        set.add(trimmed)
      }
    })
    return Array.from(set).sort((a, b) =>
      a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' })
    )
  }, [blocosCadastrados, moradores])

  // Options for Tipo de Morador dropdown
  const availableTiposMorador = useMemo(() => {
    const set = new Set<string>()
    const standard = [
      'Proprietário (a)',
      'Inquilino (a)',
      'Morador(a)',
      'Família',
      'Cônjuge',
      'Dependente',
      'Locatário',
      'Proprietário não morador',
      'Locador',
      'Funcionário (a)',
    ]
    moradores.forEach(m => {
      const t = m.tipo_morador?.trim()
      if (t) set.add(t)
    })
    standard.forEach(s => {
      if (moradores.some(m => m.tipo_morador?.toLowerCase() === s.toLowerCase())) {
        set.add(s)
      }
    })
    return Array.from(set).sort((a, b) =>
      a.localeCompare(b, undefined, { sensitivity: 'base' })
    )
  }, [moradores])

  // Count active applied advanced filters
  const activeFilterCount = useMemo(() => {
    let count = 0
    if (appliedFilters.bloco) count++
    if (appliedFilters.apto) count++
    if (appliedFilters.perfil) count++
    if (appliedFilters.whatsapp) count++
    if (appliedFilters.tipoMorador) count++
    if (appliedFilters.status && appliedFilters.status !== 'todos') count++
    if (appliedFilters.dataInicio) count++
    if (appliedFilters.dataFim) count++
    return count
  }, [appliedFilters])

  // Indicator Cards computed on the full dataset of the condo
  const stats = useMemo(() => {
    const total = moradores.length
    let ativosCount = 0
    let pendentesCount = 0
    let bloqueadosCount = 0
    let rejeitadosCount = 0
    let inativosCount = 0

    moradores.forEach(m => {
      const st = getCadastralStatus(m)
      if (st === 'ativo') ativosCount++
      else if (st === 'pendente') pendentesCount++
      else if (st === 'bloqueado') bloqueadosCount++
      else if (st === 'rejeitado') rejeitadosCount++
      else if (st === 'inativo') inativosCount++
    })

    const moradorCount = moradores.filter(m => m.papel_sistema?.includes('Morador')).length
    const portariaCount = moradores.filter(m => m.papel_sistema?.includes('Port')).length
    const sindicoCount = moradores.filter(m => m.papel_sistema?.toLowerCase().includes('sínd') || m.papel_sistema?.toLowerCase().includes('sind')).length
    const blocosCount = filterResidentialBlocos(moradores.map(m => m.bloco_txt)).length

    return {
      total,
      ativosCount,
      pendentesCount,
      bloqueadosCount,
      rejeitadosCount,
      inativosCount,
      moradorCount,
      portariaCount,
      sindicoCount,
      blocosCount,
    }
  }, [moradores])

  // Unified Filtering in AND logic across all criteria
  const filtered = useMemo(() => {
    return moradores.filter(m => {
      // 1. Role Filter from Stats Cards
      if (roleFilter && !(m.papel_sistema ?? '').toLowerCase().includes(roleFilter.toLowerCase())) {
        return false
      }
      
      // 2. Existing Quick Search (name, role, bloco, apto)
      if (search) {
        const q = search.toLowerCase()
        const isTech = isTechnicalAdminRole(m.papel_sistema) || isTechnicalAdminUnit(m.bloco_txt, m.apto_txt)
        const matchesSearch = (
          (m.nome_completo ?? '').toLowerCase().includes(q) ||
          (m.papel_sistema ?? '').toLowerCase().includes(q) ||
          (!isTech && (
            (m.bloco_txt ?? '').toLowerCase().includes(q) ||
            (m.apto_txt ?? '').toLowerCase().includes(q)
          ))
        )
        if (!matchesSearch) return false
      }

      // 3. Existing Email Search
      if (emailSearch) {
        const qEmail = emailSearch.toLowerCase()
        if (!(m.email ?? '').toLowerCase().includes(qEmail)) return false
      }

      // 4. Advanced Filter: Bloco (perfil.bloco_txt)
      if (appliedFilters.bloco) {
        const filterBloco = appliedFilters.bloco.trim().toLowerCase()
        const moradorBloco = (m.bloco_txt ?? '').trim().toLowerCase()
        if (moradorBloco !== filterBloco) return false
      }

      // 5. Advanced Filter: Apartamento / Unidade (apto_txt)
      if (appliedFilters.apto) {
        const filterApto = appliedFilters.apto.trim().toLowerCase()
        const moradorApto = (m.apto_txt ?? '').trim().toLowerCase()
        if (!moradorApto.includes(filterApto)) return false
      }

      // 6. Advanced Filter: Perfil (papel_sistema)
      if (appliedFilters.perfil) {
        const pFilter = appliedFilters.perfil.toLowerCase()
        const mPapel = (m.papel_sistema ?? '').toLowerCase()
        if (pFilter === 'morador') {
          if (!mPapel.includes('morador')) return false
        } else if (pFilter === 'sindico') {
          if (!mPapel.includes('sínd') && !mPapel.includes('sind')) return false
        } else if (pFilter === 'porteiro') {
          if (!mPapel.includes('port')) return false
        } else if (pFilter === 'admin') {
          if (!mPapel.includes('admin')) return false
        } else if (pFilter === 'outros') {
          const isStandard =
            mPapel.includes('morador') ||
            mPapel.includes('sínd') ||
            mPapel.includes('sind') ||
            mPapel.includes('port') ||
            mPapel.includes('admin')
          if (isStandard) return false
        }
      }

      // 7. Advanced Filter: Celular / WhatsApp (ignora formatação de caracteres)
      if (appliedFilters.whatsapp) {
        const filterDigits = cleanDigits(appliedFilters.whatsapp)
        if (filterDigits) {
          const userDigits = cleanDigits(m.whatsapp)
          if (!userDigits.includes(filterDigits)) return false
        }
      }

      // 8. Advanced Filter: Tipo de Morador
      if (appliedFilters.tipoMorador) {
        const tmFilter = appliedFilters.tipoMorador.trim().toLowerCase()
        const mTipo = (m.tipo_morador ?? '').trim().toLowerCase()
        if (mTipo !== tmFilter) return false
      }

      // 9. Advanced Filter / Quick Filter: Status Cadastral
      if (appliedFilters.status && appliedFilters.status !== 'todos') {
        const itemStatus = getCadastralStatus(m)
        if (itemStatus !== appliedFilters.status) return false
      }

      // 10. Advanced Filter: Data de Cadastro Inicial (created_at)
      if (appliedFilters.dataInicio) {
        const [year, month, day] = appliedFilters.dataInicio.split('-').map(Number)
        const dStart = new Date(year, month - 1, day, 0, 0, 0, 0).getTime()
        const dCreated = new Date(m.created_at).getTime()
        if (dCreated < dStart) return false
      }

      // 11. Advanced Filter: Data de Cadastro Final (created_at inclui o dia inteiro até 23:59:59.999)
      if (appliedFilters.dataFim) {
        const [year, month, day] = appliedFilters.dataFim.split('-').map(Number)
        const dEnd = new Date(year, month - 1, day, 23, 59, 59, 999).getTime()
        const dCreated = new Date(m.created_at).getTime()
        if (dCreated > dEnd) return false
      }

      return true
    })
  }, [moradores, search, emailSearch, roleFilter, appliedFilters])

  // Pagination (9 items per page)
  const totalPages = Math.max(1, Math.ceil(filtered.length / ITEMS_PER_PAGE))
  const safePage = Math.min(currentPage, totalPages)
  const paginatedItems = filtered.slice((safePage - 1) * ITEMS_PER_PAGE, safePage * ITEMS_PER_PAGE)

  const getPaginationItems = () => {
    const items: (number | string)[] = []
    if (totalPages <= 5) {
      for (let i = 1; i <= totalPages; i++) items.push(i)
    } else {
      if (safePage <= 3) {
        items.push(1, 2, 3, 4, '...', totalPages)
      } else if (safePage >= totalPages - 2) {
        items.push(1, '...', totalPages - 3, totalPages - 2, totalPages - 1, totalPages)
      } else {
        items.push(1, '...', safePage - 1, safePage, safePage + 1, '...', totalPages)
      }
    }
    return items
  }

  // Search and Filter Handlers
  const handleSearch = (val: string) => { setSearch(val); setCurrentPage(1) }
  const handleEmailSearch = (val: string) => { setEmailSearch(val); setCurrentPage(1) }
  const handleRoleFilter = (val: string | null) => { setRoleFilter(val); setCurrentPage(1) }

  const handleQuickStatusChange = (newStatus: FilterStatus) => {
    setAppliedFilters(prev => ({ ...prev, status: newStatus }))
    setDraftFilters(prev => ({ ...prev, status: newStatus }))
    setCurrentPage(1)
  }

  const handleApplyFilters = () => {
    setAppliedFilters({ ...draftFilters })
    setCurrentPage(1)
  }

  const handleClearFilters = () => {
    setDraftFilters(INITIAL_FILTERS)
    setAppliedFilters(INITIAL_FILTERS)
    setRoleFilter(null)
    setCurrentPage(1)
  }

  return (
    <div className="max-w-6xl space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <div className="w-10 h-10 bg-gradient-to-br from-[#FC5931] to-[#D42F1D] rounded-xl flex items-center justify-center shadow-sm flex-shrink-0">
              <Users size={20} className="text-white" />
            </div>
            <div>
              <div className="flex items-center gap-2.5 flex-wrap">
                <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Base Cadastral</h1>
                {stats.pendentesCount > 0 && (
                  <button
                    type="button"
                    onClick={() => handleQuickStatusChange('pendente')}
                    className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-amber-50 text-amber-700 border border-amber-200 hover:bg-amber-100 transition-colors"
                    title="Filtrar cadastros pendentes de aprovação"
                  >
                    <span className="w-2 h-2 rounded-full bg-amber-500" />
                    {stats.pendentesCount} {stats.pendentesCount === 1 ? 'pendente de aprovação' : 'pendentes de aprovação'}
                  </button>
                )}
              </div>
              <p className="text-gray-400 text-xs">Gestão unificada dos moradores e usuários do condomínio.</p>
            </div>
          </div>
        </div>

        {/* Searches and Filter Trigger */}
        <div className="flex flex-col sm:flex-row gap-2 w-full sm:w-auto items-stretch sm:items-center">
          <div className="relative w-full sm:w-64">
            <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              value={search}
              onChange={e => handleSearch(e.target.value)}
              placeholder={`Buscar por nome, ${blocoLabel.toLowerCase()}...`}
              className="w-full pl-10 pr-9 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] bg-white shadow-sm transition-all"
            />
            {search && (
              <button onClick={() => handleSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600" title="Limpar busca">
                <X size={14} />
              </button>
            )}
          </div>
          
          <div className="relative w-full sm:w-56">
            <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              value={emailSearch}
              onChange={e => handleEmailSearch(e.target.value)}
              placeholder="Buscar por e-mail..."
              className="w-full pl-10 pr-9 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] bg-white shadow-sm transition-all"
            />
            {emailSearch && (
              <button onClick={() => handleEmailSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600" title="Limpar busca">
                <X size={14} />
              </button>
            )}
          </div>

          {/* Botão [Filtros] */}
          <button
            type="button"
            onClick={() => setIsFiltersOpen(prev => !prev)}
            className={`flex items-center justify-center gap-1.5 px-3.5 py-2.5 rounded-xl border text-sm font-medium transition-all shadow-sm flex-shrink-0 ${
              isFiltersOpen || activeFilterCount > 0
                ? 'bg-orange-50 border-[#FC5931] text-[#FC5931]'
                : 'bg-white border-gray-200 text-gray-700 hover:bg-gray-50'
            }`}
            title={isFiltersOpen ? 'Ocultar filtros avançados' : 'Exibir filtros avançados'}
          >
            <SlidersHorizontal size={15} />
            <span>Filtros</span>
            {activeFilterCount > 0 && (
              <span className="w-5 h-5 flex items-center justify-center text-[11px] font-bold bg-[#FC5931] text-white rounded-full">
                {activeFilterCount}
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Painel Expansível de Filtros Avançados (Inicia FECHADO) */}
      {isFiltersOpen && (
        <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-4 sm:p-5 transition-all space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-gray-100">
            <div className="flex items-center gap-2">
              <SlidersHorizontal size={16} className="text-[#FC5931]" />
              <h3 className="text-sm font-bold text-gray-900">Filtros Avançados</h3>
              {activeFilterCount > 0 && (
                <span className="text-xs text-[#FC5931] font-semibold bg-orange-50 px-2 py-0.5 rounded-full border border-orange-100">
                  {activeFilterCount} critério{activeFilterCount !== 1 ? 's' : ''} ativo{activeFilterCount !== 1 ? 's' : ''}
                </span>
              )}
            </div>
            <button
              type="button"
              onClick={() => setIsFiltersOpen(false)}
              className="text-gray-400 hover:text-gray-600 text-xs flex items-center gap-1"
            >
              <X size={14} /> Fechar
            </button>
          </div>

          {/* Grid dos 8 Filtros */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            {/* 1. Bloco */}
            <div>
              <label className="text-[11px] font-semibold text-gray-600 block mb-1">
                {blocoLabel}
              </label>
              <select
                value={draftFilters.bloco}
                onChange={e => setDraftFilters(prev => ({ ...prev, bloco: e.target.value }))}
                onKeyDown={e => e.key === 'Enter' && handleApplyFilters()}
                className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] shadow-sm"
              >
                <option value="">Todos os {blocoLabel.toLowerCase()}s</option>
                {availableBlocos.map(b => (
                  <option key={b} value={b}>{blocoLabel} {b}</option>
                ))}
              </select>
            </div>

            {/* 2. Apartamento / Unidade */}
            <div>
              <label className="text-[11px] font-semibold text-gray-600 block mb-1">
                {aptoLabel} / Unidade
              </label>
              <input
                type="text"
                value={draftFilters.apto}
                onChange={e => setDraftFilters(prev => ({ ...prev, apto: e.target.value }))}
                onKeyDown={e => e.key === 'Enter' && handleApplyFilters()}
                placeholder="Ex: 304, 102..."
                className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] shadow-sm"
              />
            </div>

            {/* 3. Perfil */}
            <div>
              <label className="text-[11px] font-semibold text-gray-600 block mb-1">
                Perfil no Sistema
              </label>
              <select
                value={draftFilters.perfil}
                onChange={e => setDraftFilters(prev => ({ ...prev, perfil: e.target.value }))}
                onKeyDown={e => e.key === 'Enter' && handleApplyFilters()}
                className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] shadow-sm"
              >
                <option value="">Todos os perfis</option>
                <option value="morador">🏠 Morador(a)</option>
                <option value="sindico">⭐ Síndico(a)</option>
                <option value="porteiro">🚪 Portaria / Porteiro</option>
                <option value="admin">🔐 Administrador</option>
                <option value="outros">👤 Outros / Histórico</option>
              </select>
            </div>

            {/* 4. Celular / WhatsApp */}
            <div>
              <label className="text-[11px] font-semibold text-gray-600 block mb-1">
                Celular / WhatsApp
              </label>
              <input
                type="text"
                value={draftFilters.whatsapp}
                onChange={e => setDraftFilters(prev => ({ ...prev, whatsapp: e.target.value }))}
                onKeyDown={e => e.key === 'Enter' && handleApplyFilters()}
                placeholder="Ex: (31) 99999-9999"
                className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] shadow-sm"
              />
            </div>

            {/* 5. Tipo de Morador */}
            <div>
              <label className="text-[11px] font-semibold text-gray-600 block mb-1">
                Tipo de Morador
              </label>
              <select
                value={draftFilters.tipoMorador}
                onChange={e => setDraftFilters(prev => ({ ...prev, tipoMorador: e.target.value }))}
                onKeyDown={e => e.key === 'Enter' && handleApplyFilters()}
                className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] shadow-sm"
              >
                <option value="">Todos os tipos</option>
                {availableTiposMorador.map(tm => (
                  <option key={tm} value={tm}>{tm}</option>
                ))}
              </select>
            </div>

            {/* 6. Status Cadastral */}
            <div>
              <label className="text-[11px] font-semibold text-gray-600 block mb-1">
                Status Cadastral
              </label>
              <select
                value={draftFilters.status}
                onChange={e => setDraftFilters(prev => ({ ...prev, status: e.target.value as FilterStatus }))}
                onKeyDown={e => e.key === 'Enter' && handleApplyFilters()}
                className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] shadow-sm"
              >
                <option value="todos">Todos os status</option>
                <option value="ativo">✅ Ativos / Liberados</option>
                <option value="pendente">⏱ Pendentes de Aprovação</option>
                <option value="bloqueado">🔒 Bloqueados</option>
                <option value="inativo">👤 Inativos</option>
                <option value="rejeitado">✕ Rejeitados</option>
              </select>
            </div>

            {/* 7. Data de Cadastro Inicial */}
            <div>
              <label className="text-[11px] font-semibold text-gray-600 block mb-1">
                Cadastro a partir de
              </label>
              <input
                type="date"
                value={draftFilters.dataInicio}
                onChange={e => setDraftFilters(prev => ({ ...prev, dataInicio: e.target.value }))}
                onKeyDown={e => e.key === 'Enter' && handleApplyFilters()}
                className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] shadow-sm"
              />
            </div>

            {/* 8. Data de Cadastro Final */}
            <div>
              <label className="text-[11px] font-semibold text-gray-600 block mb-1">
                Cadastro até
              </label>
              <input
                type="date"
                value={draftFilters.dataFim}
                onChange={e => setDraftFilters(prev => ({ ...prev, dataFim: e.target.value }))}
                onKeyDown={e => e.key === 'Enter' && handleApplyFilters()}
                className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] shadow-sm"
              />
            </div>
          </div>

          {/* Ações do Painel */}
          <div className="flex flex-col-reverse sm:flex-row sm:items-center sm:justify-between gap-2 pt-2 border-t border-gray-100">
            <p className="text-xs text-gray-400">
              * Todos os critérios preenchidos funcionam combinados em regra <span className="font-semibold text-gray-600">AND</span>.
            </p>
            <div className="flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={handleClearFilters}
                className="px-3 py-2 rounded-xl text-xs font-semibold text-gray-600 hover:bg-gray-100 border border-gray-200 transition-colors flex items-center gap-1.5"
              >
                <RotateCcw size={13} /> Limpar filtros
              </button>
              <button
                type="button"
                onClick={handleApplyFilters}
                className="px-4 py-2 rounded-xl text-xs font-semibold bg-[#FC5931] hover:bg-[#E04823] text-white transition-colors shadow-sm flex items-center gap-1.5"
              >
                <Filter size={13} /> Aplicar filtros
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Indicadores Principais (KPIs Cadastrais) */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        {[
          {
            key: 'todos' as FilterStatus,
            label: 'Total de Cadastros',
            value: stats.total,
            icon: Users,
            color: 'from-gray-700 to-gray-900',
            activeRing: 'ring-2 ring-gray-700 border-gray-700',
          },
          {
            key: 'ativo' as FilterStatus,
            label: 'Ativos / Liberados',
            value: stats.ativosCount,
            icon: CheckCircle,
            color: 'from-emerald-500 to-teal-600',
            activeRing: 'ring-2 ring-emerald-500 border-emerald-500',
          },
          {
            key: 'pendente' as FilterStatus,
            label: 'Pendentes',
            value: stats.pendentesCount,
            icon: Clock,
            color: 'from-amber-400 to-amber-600',
            activeRing: 'ring-2 ring-amber-500 border-amber-500',
          },
          {
            key: 'bloqueado' as FilterStatus,
            label: 'Bloqueados',
            value: stats.bloqueadosCount,
            icon: Lock,
            color: 'from-red-500 to-rose-600',
            activeRing: 'ring-2 ring-red-500 border-red-500',
          },
          {
            key: 'inativo' as FilterStatus,
            label: 'Inativos',
            value: stats.inativosCount,
            icon: UserX,
            color: 'from-zinc-500 to-zinc-700',
            activeRing: 'ring-2 ring-zinc-500 border-zinc-500',
          },
          {
            key: 'rejeitado' as FilterStatus,
            label: 'Rejeitados',
            value: stats.rejeitadosCount,
            icon: XCircle,
            color: 'from-gray-500 to-slate-700',
            activeRing: 'ring-2 ring-gray-600 border-gray-600',
          },
        ].map(kpi => {
          const Icon = kpi.icon
          const isSelected = appliedFilters.status === kpi.key
          return (
            <button
              key={kpi.key}
              type="button"
              onClick={() => handleQuickStatusChange(kpi.key)}
              className={`bg-white rounded-2xl border shadow-sm p-4 text-left transition-all group cursor-pointer hover:shadow-md ${
                isSelected ? kpi.activeRing : 'border-gray-100 hover:border-gray-200'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <div className={`w-8 h-8 rounded-lg bg-gradient-to-br ${kpi.color} flex items-center justify-center shadow-sm`}>
                  <Icon size={15} className="text-white" />
                </div>
                {isSelected && (
                  <span className="text-[9px] font-bold text-[#FC5931] bg-[#FC5931]/10 px-2 py-0.5 rounded-full">
                    FILTRADO
                  </span>
                )}
              </div>
              <p className="text-2xl font-bold text-gray-900 tracking-tight">{kpi.value.toLocaleString('pt-BR')}</p>
              <p className="text-xs text-gray-400 font-medium truncate">{kpi.label}</p>
            </button>
          )
        })}
      </div>

      {/* Indicadores Complementares (Censo Físico & Funções) */}
      <div className="flex flex-wrap items-center gap-2 pt-0.5 text-xs text-gray-500 font-medium">
        <span className="text-gray-400 text-[11px] font-semibold uppercase tracking-wider mr-1">Censo Físico:</span>
        <button
          type="button"
          onClick={() => handleRoleFilter(roleFilter === 'Morador' ? null : 'Morador')}
          className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-lg border text-xs font-semibold transition-all ${
            roleFilter === 'Morador'
              ? 'bg-sky-50 border-sky-300 text-sky-800 ring-1 ring-sky-200'
              : 'bg-white border-gray-200 text-gray-700 hover:bg-gray-50 shadow-2xs'
          }`}
          title="Filtrar moradores"
        >
          <span>🏠</span> <strong>{stats.moradorCount.toLocaleString('pt-BR')}</strong> Moradores
          {roleFilter === 'Morador' && <X size={11} className="ml-0.5 text-sky-600" />}
        </button>

        <button
          type="button"
          onClick={() => handleRoleFilter(roleFilter === 'Port' ? null : 'Port')}
          className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-lg border text-xs font-semibold transition-all ${
            roleFilter === 'Port'
              ? 'bg-violet-50 border-violet-300 text-violet-800 ring-1 ring-violet-200'
              : 'bg-white border-gray-200 text-gray-700 hover:bg-gray-50 shadow-2xs'
          }`}
          title="Filtrar portaria"
        >
          <span>🚪</span> <strong>{stats.portariaCount.toLocaleString('pt-BR')}</strong> Portaria / Equipe
          {roleFilter === 'Port' && <X size={11} className="ml-0.5 text-violet-600" />}
        </button>

        <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-white border border-gray-200 rounded-lg text-xs font-semibold text-gray-700 shadow-2xs">
          <span>🏢</span> <strong>{stats.blocosCount.toLocaleString('pt-BR')}</strong> {blocoLabel}s habitados
        </span>
      </div>

      {/* Quick Status Tabs (Pílulas de Status acima da listagem) */}
      <div className="flex gap-2 flex-wrap items-center pt-2">
        {[
          {
            key: 'todos' as FilterStatus,
            label: 'Todos',
            count: stats.total,
            cls: 'bg-gray-50 text-gray-700 hover:bg-gray-100 border border-gray-200',
            activeCls: 'bg-gray-800 text-white border-gray-800',
          },
          {
            key: 'ativo' as FilterStatus,
            label: 'Ativos',
            count: stats.ativosCount,
            cls: 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border border-emerald-200',
            activeCls: 'bg-emerald-600 text-white border-emerald-600',
          },
          {
            key: 'pendente' as FilterStatus,
            label: 'Pendentes',
            count: stats.pendentesCount,
            cls: stats.pendentesCount > 0 ? 'bg-amber-100 text-amber-800 hover:bg-amber-200 border border-amber-300 font-bold' : 'bg-amber-50 text-amber-700 hover:bg-amber-100 border border-amber-200',
            activeCls: 'bg-amber-500 text-white border-amber-500',
          },
          {
            key: 'bloqueado' as FilterStatus,
            label: 'Bloqueados',
            count: stats.bloqueadosCount,
            cls: 'bg-red-50 text-red-700 hover:bg-red-100 border border-red-200',
            activeCls: 'bg-red-500 text-white border-red-500',
          },
          {
            key: 'inativo' as FilterStatus,
            label: 'Inativos',
            count: stats.inativosCount,
            cls: 'bg-zinc-100 text-zinc-700 hover:bg-zinc-200 border border-zinc-300',
            activeCls: 'bg-zinc-700 text-white border-zinc-700',
          },
          {
            key: 'rejeitado' as FilterStatus,
            label: 'Rejeitados',
            count: stats.rejeitadosCount,
            cls: 'bg-gray-100 text-gray-600 hover:bg-gray-200 border border-gray-200',
            activeCls: 'bg-gray-600 text-white border-gray-600',
          },
        ].map(tab => {
          const isSelected = appliedFilters.status === tab.key
          return (
            <button
              key={tab.key}
              type="button"
              onClick={() => handleQuickStatusChange(tab.key)}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all shadow-2xs ${
                isSelected ? tab.activeCls : tab.cls
              }`}
            >
              <span>{tab.label}</span>
              <span className={`text-[11px] px-1.5 py-0.5 rounded-full font-bold ${
                isSelected ? 'bg-white/30 text-white' : 'bg-white/80 text-gray-700 border border-gray-200/50'
              }`}>
                {tab.count.toLocaleString('pt-BR')}
              </span>
            </button>
          )
        })}
      </div>

      {/* Active filters chips bar */}
      {(roleFilter || activeFilterCount > 0) && (
        <div className="flex items-center gap-2 flex-wrap text-xs bg-gray-50/80 border border-gray-200/80 rounded-xl px-3 py-2">
          <span className="text-gray-500 font-medium">Filtros ativos:</span>
          {roleFilter && (
            <button
              type="button"
              onClick={() => handleRoleFilter(null)}
              className="flex items-center gap-1 font-semibold bg-white border border-gray-200 text-gray-700 px-2.5 py-1 rounded-full hover:bg-gray-100 transition-colors shadow-2xs"
            >
              Papel: {roleFilter} <X size={11} />
            </button>
          )}
          {appliedFilters.bloco && (
            <button
              type="button"
              onClick={() => {
                const next = { ...appliedFilters, bloco: '' }
                setAppliedFilters(next)
                setDraftFilters(prev => ({ ...prev, bloco: '' }))
                setCurrentPage(1)
              }}
              className="flex items-center gap-1 font-semibold bg-orange-50 text-[#FC5931] border border-orange-200 px-2.5 py-1 rounded-full hover:bg-orange-100 transition-colors shadow-2xs"
            >
              {blocoLabel}: {appliedFilters.bloco} <X size={11} />
            </button>
          )}
          {appliedFilters.apto && (
            <button
              type="button"
              onClick={() => {
                const next = { ...appliedFilters, apto: '' }
                setAppliedFilters(next)
                setDraftFilters(prev => ({ ...prev, apto: '' }))
                setCurrentPage(1)
              }}
              className="flex items-center gap-1 font-semibold bg-orange-50 text-[#FC5931] border border-orange-200 px-2.5 py-1 rounded-full hover:bg-orange-100 transition-colors shadow-2xs"
            >
              {aptoLabel}: {appliedFilters.apto} <X size={11} />
            </button>
          )}
          {appliedFilters.perfil && (
            <button
              type="button"
              onClick={() => {
                const next = { ...appliedFilters, perfil: '' }
                setAppliedFilters(next)
                setDraftFilters(prev => ({ ...prev, perfil: '' }))
                setCurrentPage(1)
              }}
              className="flex items-center gap-1 font-semibold bg-orange-50 text-[#FC5931] border border-orange-200 px-2.5 py-1 rounded-full hover:bg-orange-100 transition-colors shadow-2xs"
            >
              Perfil: {appliedFilters.perfil} <X size={11} />
            </button>
          )}
          {appliedFilters.whatsapp && (
            <button
              type="button"
              onClick={() => {
                const next = { ...appliedFilters, whatsapp: '' }
                setAppliedFilters(next)
                setDraftFilters(prev => ({ ...prev, whatsapp: '' }))
                setCurrentPage(1)
              }}
              className="flex items-center gap-1 font-semibold bg-orange-50 text-[#FC5931] border border-orange-200 px-2.5 py-1 rounded-full hover:bg-orange-100 transition-colors shadow-2xs"
            >
              Tel: {appliedFilters.whatsapp} <X size={11} />
            </button>
          )}
          {appliedFilters.tipoMorador && (
            <button
              type="button"
              onClick={() => {
                const next = { ...appliedFilters, tipoMorador: '' }
                setAppliedFilters(next)
                setDraftFilters(prev => ({ ...prev, tipoMorador: '' }))
                setCurrentPage(1)
              }}
              className="flex items-center gap-1 font-semibold bg-orange-50 text-[#FC5931] border border-orange-200 px-2.5 py-1 rounded-full hover:bg-orange-100 transition-colors shadow-2xs"
            >
              Tipo: {appliedFilters.tipoMorador} <X size={11} />
            </button>
          )}
          {appliedFilters.status && appliedFilters.status !== 'todos' && (
            <button
              type="button"
              onClick={() => handleQuickStatusChange('todos')}
              className="flex items-center gap-1 font-semibold bg-orange-50 text-[#FC5931] border border-orange-200 px-2.5 py-1 rounded-full hover:bg-orange-100 transition-colors shadow-2xs"
            >
              Status: {
                appliedFilters.status === 'ativo' ? 'Ativos' :
                appliedFilters.status === 'pendente' ? 'Pendentes' :
                appliedFilters.status === 'bloqueado' ? 'Bloqueados' :
                appliedFilters.status === 'inativo' ? 'Inativos' :
                appliedFilters.status === 'rejeitado' ? 'Rejeitados' : appliedFilters.status
              } <X size={11} />
            </button>
          )}
          {(appliedFilters.dataInicio || appliedFilters.dataFim) && (
            <button
              type="button"
              onClick={() => {
                const next = { ...appliedFilters, dataInicio: '', dataFim: '' }
                setAppliedFilters(next)
                setDraftFilters(prev => ({ ...prev, dataInicio: '', dataFim: '' }))
                setCurrentPage(1)
              }}
              className="flex items-center gap-1 font-semibold bg-orange-50 text-[#FC5931] border border-orange-200 px-2.5 py-1 rounded-full hover:bg-orange-100 transition-colors shadow-2xs"
            >
              Data: {appliedFilters.dataInicio || '...'} até {appliedFilters.dataFim || '...'} <X size={11} />
            </button>
          )}
          <button
            type="button"
            onClick={() => {
              handleRoleFilter(null)
              handleClearFilters()
            }}
            className="text-xs text-gray-400 hover:text-gray-600 underline ml-1"
          >
            Limpar todos
          </button>
          <span className="text-gray-400 ml-auto font-medium">
            {filtered.length} morador{filtered.length !== 1 ? 'es' : ''} encontrado{filtered.length !== 1 ? 's' : ''}
          </span>
        </div>
      )}

      {/* Empty State */}
      {filtered.length === 0 ? (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-16 text-center">
          <div className="w-16 h-16 bg-gray-50 rounded-2xl mx-auto mb-4 flex items-center justify-center">
            <Users size={28} className="text-gray-300" />
          </div>
          <p className="font-semibold text-gray-600 mb-1">Nenhum morador encontrado</p>
          {(search || emailSearch || activeFilterCount > 0 || roleFilter) && (
            <p className="text-sm text-gray-400">
              Nenhum registro atende aos filtros combinados. Tente ajustar ou limpar os filtros.
            </p>
          )}
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
              const status = getCadastralStatus(m)
              const statusBadge = STATUS_BADGE[status]
              const StatusIcon = statusBadge.icon
              const initials = getInitials(m.nome_completo)
              const avatarGrad = getAvatarColor(m.id)

              return (
                <div
                  key={m.id}
                  onClick={() => router.push(`/admin/moradores/${m.id}`)}
                  className={`bg-white rounded-xl border shadow-sm overflow-hidden transition-all cursor-pointer ${
                    status === 'bloqueado'
                      ? 'border-red-200 opacity-65 bg-red-50/10 hover:opacity-85'
                      : status === 'inativo'
                      ? 'border-zinc-200 bg-zinc-50/30 opacity-80 hover:opacity-100'
                      : status === 'pendente'
                      ? 'border-amber-200 bg-amber-50/10 hover:shadow-md hover:border-amber-400/50 hover:ring-1 hover:ring-amber-400/20'
                      : status === 'rejeitado'
                      ? 'border-gray-200 opacity-75 bg-gray-50/30 hover:opacity-90'
                      : 'border-gray-100 hover:shadow-md hover:border-[#FC5931]/30 hover:ring-1 hover:ring-[#FC5931]/20'
                  }`}
                >
                  <div className="p-4">
                    <div className="flex items-center gap-3">
                      {/* Avatar */}
                      <div className={`w-11 h-11 rounded-full flex items-center justify-center flex-shrink-0 shadow-sm ${
                        status === 'bloqueado'
                          ? 'bg-red-100 text-red-600'
                          : status === 'inativo'
                          ? 'bg-zinc-200 text-zinc-600 font-bold'
                          : status === 'pendente'
                          ? 'bg-amber-100 text-amber-700 font-bold'
                          : status === 'rejeitado'
                          ? 'bg-gray-200 text-gray-600 font-bold'
                          : `bg-gradient-to-br ${avatarGrad} text-white font-bold`
                      }`}>
                        {status === 'bloqueado' ? (
                          <Lock size={16} className="text-red-500" />
                        ) : status === 'inativo' ? (
                          <UserX size={16} className="text-zinc-600" />
                        ) : status === 'pendente' ? (
                          <span className="text-amber-800 text-sm font-bold">{initials}</span>
                        ) : status === 'rejeitado' ? (
                          <span className="text-gray-700 text-sm font-bold">{initials}</span>
                        ) : (
                          <span className="text-white text-sm font-bold">{initials}</span>
                        )}
                      </div>

                      {/* Info */}
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <p className={`font-semibold text-sm leading-tight truncate ${
                            status === 'bloqueado' ? 'line-through text-gray-500' : status === 'inativo' ? 'text-zinc-600' : 'text-gray-900'
                          }`}>
                            {m.nome_completo || '—'}
                          </p>
                          <span className={`flex-shrink-0 text-[9px] font-bold px-1.5 py-0.5 rounded-md border flex items-center gap-1 ${
                            statusBadge.bg
                          } ${statusBadge.text} ${statusBadge.border}`}>
                            <StatusIcon size={9} />
                            {statusBadge.label}
                          </span>
                        </div>
                        
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

                        <div className="flex items-center gap-1.5 mt-1.5 flex-wrap">
                          {m.papel_sistema && (
                            <span className={`text-[10px] px-2 py-0.5 rounded-full font-semibold border ${role.bg} ${role.text} ${role.border}`}>
                              {role.icon} {m.papel_sistema}
                            </span>
                          )}
                          {m.tipo_morador && (
                            <span className="text-[10px] px-2 py-0.5 rounded-full font-medium bg-gray-50 text-gray-600 border border-gray-200">
                              {m.tipo_morador}
                            </span>
                          )}
                          <div className="flex items-center gap-1.5 ml-auto">
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation()
                                setEditingProfile(m)
                              }}
                              className="flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-blue-50 text-blue-600 border border-blue-100 hover:bg-blue-100 transition-colors"
                              title="Editar cadastro"
                            >
                              <Edit size={12} /> Editar
                            </button>

                            {status === 'ativo' && (
                              <>
                                <button
                                  type="button"
                                  onClick={(e) => {
                                    e.stopPropagation()
                                    setActionError(null)
                                    setConfirmAction({ profile: m, action: 'block' })
                                  }}
                                  className="flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-red-50 text-red-600 border border-red-200 hover:bg-red-100 transition-colors"
                                  title="Bloquear acesso do morador"
                                >
                                  <Lock size={11} /> Bloquear
                                </button>
                                <button
                                  type="button"
                                  onClick={(e) => {
                                    e.stopPropagation()
                                    setInactivateTarget(m)
                                  }}
                                  className="flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-zinc-100 text-zinc-700 border border-zinc-200 hover:bg-zinc-200 transition-colors"
                                  title="Inativar vínculo de moradia"
                                >
                                  <UserX size={11} /> Inativar
                                </button>
                              </>
                            )}

                            {status === 'bloqueado' && (
                              <>
                                <button
                                  type="button"
                                  onClick={(e) => {
                                    e.stopPropagation()
                                    setActionError(null)
                                    setConfirmAction({ profile: m, action: 'unblock' })
                                  }}
                                  className="flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors"
                                  title="Reativar acesso do morador"
                                >
                                  <Unlock size={11} /> Reativar
                                </button>
                                <button
                                  type="button"
                                  onClick={(e) => {
                                    e.stopPropagation()
                                    setInactivateTarget(m)
                                  }}
                                  className="flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-zinc-100 text-zinc-700 border border-zinc-200 hover:bg-zinc-200 transition-colors"
                                  title="Inativar vínculo de moradia"
                                >
                                  <UserX size={11} /> Inativar
                                </button>
                              </>
                            )}

                            {status === 'inativo' && (
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.stopPropagation()
                                  setCreateLinkTarget(m)
                                }}
                                className="flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors"
                                title="Criar novo vínculo residencial"
                              >
                                <PlusCircle size={11} /> Novo vínculo
                              </button>
                            )}
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Footer */}
                  <div className="px-4 py-2.5 bg-gray-50/80 border-t border-gray-100 flex items-center justify-between">
                    <div className="flex items-center gap-1.5 text-xs text-gray-500">
                      {isTechnicalAdminRole(m.papel_sistema) || isTechnicalAdminUnit(m.bloco_txt, m.apto_txt) ? (
                        <span className="text-amber-700 font-medium flex items-center gap-1">
                          <Shield size={12} className="text-amber-500" /> Identidade Administrativa
                        </span>
                      ) : (
                        <>
                          <Home size={12} className="text-gray-400" />
                          <span>{formatUnitDisplay({ bloco: m.bloco_txt, apto: m.apto_txt, role: m.papel_sistema, tipoEstrutura, fallback: '—' })}</span>
                        </>
                      )}
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
              {getPaginationItems().map((item, index) => {
                if (item === '...') {
                  return <span key={`ellipsis-${index}`} className="px-2 text-gray-400 select-none">...</span>
                }
                const page = item as number
                return (
                  <button
                    key={page}
                    onClick={() => setCurrentPage(page)}
                    className={`w-9 h-9 flex-shrink-0 rounded-xl text-sm font-bold transition-all ${
                      page === safePage
                        ? 'bg-[#FC5931] text-white shadow-sm'
                        : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
                    }`}
                  >
                    {page}
                  </button>
                )
              })}

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

      {editingProfile && (
        <EditProfileModal
          profile={editingProfile}
          blocoLabel={blocoLabel}
          aptoLabel={aptoLabel}
          currentUserRole={currentUserRole}
          onClose={() => setEditingProfile(null)}
        />
      )}

      {confirmAction && (
        <BlockConfirmModal
          isOpen={!!confirmAction}
          onClose={() => {
            if (!actionLoading) {
              setConfirmAction(null)
              setActionError(null)
            }
          }}
          residentName={confirmAction.profile.nome_completo || 'Morador'}
          action={confirmAction.action}
          loading={actionLoading}
          error={actionError}
          onConfirm={handleConfirmBlockAction}
        />
      )}

      {inactivateTarget && (
        <InactivateConfirmModal
          isOpen={!!inactivateTarget}
          onClose={() => setInactivateTarget(null)}
          profileId={inactivateTarget.id}
          residentName={inactivateTarget.nome_completo || 'Morador'}
          tipoEstrutura={tipoEstrutura}
          onSuccess={handleInactivationSuccess}
        />
      )}

      {createLinkTarget && (
        <CreateResidentLinkModal
          isOpen={!!createLinkTarget}
          onClose={() => setCreateLinkTarget(null)}
          profileId={createLinkTarget.id}
          residentName={createLinkTarget.nome_completo || 'Morador'}
          tipoEstrutura={tipoEstrutura}
          onSuccess={handleCreateLinkSuccess}
        />
      )}
    </div>
  )
}

