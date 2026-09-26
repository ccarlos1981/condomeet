'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import {
  ArrowLeft,
  User,
  Home,
  Car,
  Heart,
  Users,
  KeyRound,
  Clock,
  Mail,
  Phone,
  Shield,
  Building2,
  Calendar,
  CheckCircle,
  AlertCircle,
  XCircle,
  Lock,
  Unlock,
  ExternalLink,
  ChevronRight,
  Info,
  UserX,
  History,
  PlusCircle,
  Edit2,
  RefreshCw,
  PawPrint,
  ArrowRightLeft,
  Camera,
  Trash2,
  Eye,
} from 'lucide-react'
import { getBlocoLabel, getAptoLabel, formatUnitDisplay, isTechnicalAdminUnit } from '@/lib/labels'
import { isTechnicalAdminRole } from '@/lib/roles'
import BlockConfirmModal from '../block-confirm-modal'
import ApproveConfirmModal from '../approve-confirm-modal'
import RejectConfirmModal from '../reject-confirm-modal'
import InactivateConfirmModal from '../inactivate-confirm-modal'
import CreateResidentLinkModal from '../create-resident-link-modal'
import VehicleModal from '../vehicle-modal'
import VehiclePlateModal from '../vehicle-plate-modal'
import VehicleInactivateModal from '../vehicle-inactivate-modal'
import VehicleReactivateModal from '../vehicle-reactivate-modal'
import PetModal from '../pet-modal'
import PetInactivateModal from '../pet-inactivate-modal'
import PetReactivateModal from '../pet-reactivate-modal'
import PetUnitModal from '../pet-unit-modal'
import { PhotoUploadModal, PhotoRemoveModal, PhotoViewerModal } from '../photo-modal'
import DependentModal from '../dependent-modal'
import DependentInactivateModal from '../dependent-inactivate-modal'
import DependentReactivateModal from '../dependent-reactivate-modal'
import DependentResponsibleModal from '../dependent-responsible-modal'
import EditGeneralDataModal from './edit-general-data-modal'
import {
  adminToggleBlockStatus,
  adminApproveResident,
  adminRejectResident,
  adminGetResidentInvitesPage,
  adminGetUnitAccessPage,
} from '@/app/admin/actions'

export interface ResidentData {
  id: string
  condominio_id: string
  nome_completo: string | null
  email: string | null
  whatsapp: string | null
  whatsapp_msg_consent: boolean | null
  bloqueado: boolean | null
  status_aprovacao: string | null
  tipo_morador: string | null
  papel_sistema: string | null
  bloco_txt: string | null
  apto_txt: string | null
  foto_url: string | null
  foto_signed_url?: string | null
  notificacoes_whatsapp: boolean | null
  needs_password_setup: boolean | null
  last_interaction_at: string | null
  created_at: string
  updated_at: string | null
}

export interface UnitLinkData {
  id: string
  status: string | null
  data_entrada: string | null
  data_saida: string | null
  created_at: string | null
  unidade_id: string
  fracao_ideal?: string | number | null
  bloqueada?: boolean | null
  bloco_nome?: string | null
  apto_numero?: string | null
}

export interface CoResidentData {
  id: string
  nome_completo: string | null
  email: string | null
  whatsapp: string | null
  papel_sistema: string | null
  tipo_morador: string | null
  status_aprovacao: string | null
  foto_url: string | null
  dataEntrada?: string | null
}

export interface ConviteData {
  id: string
  resident_id?: string | null
  guest_name: string | null
  visitor_type: string | null
  status: string | null
  validity_date: string | null
  valid_until?: string | null
  qr_data: string | null
  created_at: string
  visitante_compareceu: boolean | null
  liberado_em?: string | null
  liberado_por?: string | null
  documento?: string | null
  placa?: string | null
  whatsapp?: string | null
  observacao?: string | null
  cracha_referencia?: string | null
  bloco_destino?: string | null
  apto_destino?: string | null
  criado_por_portaria?: boolean | null
}

export interface PortariaRegistroData {
  id: string
  nome: string | null
  tipo_visitante: string | null
  entrada_at: string | null
  saida_at: string | null
  status: string | null
  created_at: string | null
  placa?: string | null
  documento?: string | null
  observacao?: string | null
}

export interface AuditLogData {
  id: string
  acao: string
  motivo: string | null
  estado_anterior: any
  estado_posterior: any
  created_at: string
  operador_nome: string
  operador_papel?: string
  unidade_bloco?: string | null
  unidade_apto?: string | null
}

interface Props {
  resident: ResidentData
  condoNome: string
  condoTipoEstrutura: string
  unitLinks: UnitLinkData[]
  coResidents: CoResidentData[]
  convites: ConviteData[]
  portariaRegistros: PortariaRegistroData[]
  auditLogs?: AuditLogData[]
  veiculos?: VehicleData[]
  veiculosError?: string | null
  pets?: PetData[]
  petsError?: string | null
  dependentes?: DependenteData[]
  dependentesError?: string | null
}

export interface VehicleData {
  id: string
  condominio_id: string
  perfil_id: string
  unidade_id: string
  placa: string
  tipo: string
  marca: string
  modelo: string
  cor: string
  ano?: number | null
  vaga_numero?: string | null
  observacao?: string | null
  status: 'ativo' | 'inativo'
  foto_path?: string | null
  foto_signed_url?: string | null
  created_at: string
  updated_at?: string | null
  unidade_bloco?: string | null
  unidade_apto?: string | null
}

export interface PetData {
  id: string
  condominio_id: string
  perfil_id: string
  unidade_id: string
  nome: string
  especie: 'cao' | 'gato' | 'ave' | 'roedor' | 'reptil' | 'peixe' | 'outro'
  raca?: string | null
  sexo?: 'macho' | 'femea' | null
  porte?: 'pequeno' | 'medio' | 'grande' | 'nao_se_aplica' | null
  cor?: string | null
  data_nascimento?: string | null
  castrado?: boolean | null
  vacinado?: boolean | null
  observacao?: string | null
  status: 'ativo' | 'inativo'
  foto_path?: string | null
  foto_signed_url?: string | null
  created_at: string
  updated_at?: string | null
  unidade_bloco?: string | null
  unidade_apto?: string | null
}

export interface DependenteData {
  id: string
  condominio_id: string
  unidade_id: string | null
  responsavel_perfil_id: string
  nome_completo: string
  parentesco: string | null
  data_nascimento: string | null
  foto_path: string | null
  foto_signed_url?: string | null
  observacao: string | null
  status: 'ativo' | 'inativo'
  perfil_convertido_id: string | null
  created_at: string
  updated_at: string | null
}

export function formatEspecie(especie?: string | null): string {
  if (!especie) return '—'
  const map: Record<string, string> = {
    cao: 'Cão',
    gato: 'Gato',
    ave: 'Ave',
    roedor: 'Roedor',
    reptil: 'Réptil',
    peixe: 'Peixe',
    outro: 'Outro',
  }
  return map[especie] || especie
}

export function formatPorte(porte?: string | null): string {
  if (!porte) return 'Não informado'
  const map: Record<string, string> = {
    pequeno: 'Pequeno',
    medio: 'Médio',
    grande: 'Grande',
    nao_se_aplica: 'Não se aplica',
  }
  return map[porte] || porte
}

export function formatPlateDisplay(plate?: string | null): string {
  if (!plate) return '—'
  const clean = plate.toUpperCase().replace(/[^A-Z0-9]/g, '')
  if (/^[A-Z]{3}[0-9]{4}$/.test(clean)) {
    return `${clean.slice(0, 3)}-${clean.slice(3)}`
  }
  return clean
}

type TabKey = 'dados-gerais' | 'unidade' | 'veiculos' | 'pets' | 'familia' | 'acessos' | 'historico'

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

function getInitials(name: string | null) {
  if (!name) return '?'
  const parts = name.trim().split(/\s+/)
  if (parts.length >= 2) return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
  return parts[0].substring(0, 2).toUpperCase()
}

function formatDate(iso?: string | null): string {
  if (!iso) return '—'
  try {
    const d = new Date(iso)
    if (isNaN(d.getTime())) return '—'
    return d.toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    })
  } catch {
    return '—'
  }
}

/**
 * Formata campo PostgreSQL DATE (dia civil YYYY-MM-DD) sem conversão para UTC ou objeto Date.
 * Previne retrocessos indevidos de fuso horário (ex: 2000-01-01 -> 31/12/1999).
 */
export function formatDateCivil(dateStr?: string | null): string {
  if (!dateStr) return '—'
  const clean = dateStr.trim().split(/[T ]/)[0]
  const parts = clean.split('-')
  if (parts.length === 3) {
    const [year, month, day] = parts
    if (year.length === 4 && month.length === 2 && day.length === 2) {
      return `${day}/${month}/${year}`
    }
  }
  return clean
}

function formatDateTime(iso?: string | null): string {
  if (!iso) return '—'
  try {
    const d = new Date(iso)
    if (isNaN(d.getTime())) return '—'
    return d.toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return '—'
  }
}

const PORTARIA_PAGE_SIZE = 5
const CONVITES_PAGE_SIZE = 5

export default function Resident360Client({
  resident: initialResident,
  condoNome,
  condoTipoEstrutura,
  unitLinks,
  coResidents,
  convites,
  portariaRegistros = [],
  auditLogs = [],
  veiculos: initialVeiculos = [],
  veiculosError = null,
  pets: initialPets = [],
  petsError = null,
  dependentes = [],
  dependentesError = null,
}: Props) {
  const router = useRouter()
  const [activeTab, setActiveTab] = useState<TabKey>('dados-gerais')

  // Paginação de Convites (Gate 3H.2-B4)
  const [convitesPage, setConvitesPage] = useState(1)
  const [serverConvites, setServerConvites] = useState(convites)
  const [serverConvitesTotal, setServerConvitesTotal] = useState(convites.length)
  const [serverConvitesTotalPages, setServerConvitesTotalPages] = useState(
    Math.ceil(convites.length / CONVITES_PAGE_SIZE)
  )
  const paginatedConvites = serverConvites

  // Paginação da Portaria (Gate 3H.2-B3)
  const [portariaPage, setPortariaPage] = useState(1)
  const [serverPortariaRegistros, setServerPortariaRegistros] = useState(portariaRegistros)
  const [serverPortariaTotal, setServerPortariaTotal] = useState(portariaRegistros.length)
  const [serverPortariaTotalPages, setServerPortariaTotalPages] = useState(
    Math.ceil(portariaRegistros.length / PORTARIA_PAGE_SIZE)
  )
  const paginatedPortariaRegistros = serverPortariaRegistros

  // Synced local state for immediate reactive status changes
  const [resident, setResident] = useState<ResidentData>(initialResident)
  useEffect(() => {
    setResident(initialResident)
  }, [initialResident])

  useEffect(() => {
    adminGetResidentInvitesPage(resident.id, convitesPage).then((result) => {
      if (result.success) {
        setServerConvites(result.data)
        setServerConvitesTotal(result.total)
        setServerConvitesTotalPages(result.totalPages)
      }
    })
  }, [resident.id, convitesPage])

  useEffect(() => {
    if (
      !initialResident.condominio_id ||
      !initialResident.bloco_txt ||
      !initialResident.apto_txt
    ) {
      return
    }

    adminGetUnitAccessPage(
      initialResident.condominio_id,
      initialResident.bloco_txt,
      initialResident.apto_txt,
      portariaPage
    ).then((result) => {
      if (result.success) {
        setServerPortariaRegistros(result.data)
        setServerPortariaTotal(result.total)
        setServerPortariaTotalPages(result.totalPages)
      }
    })
  }, [
    initialResident.condominio_id,
    initialResident.bloco_txt,
    initialResident.apto_txt,
    portariaPage,
  ])

  const [veiculos, setVeiculos] = useState<VehicleData[]>(initialVeiculos)
  useEffect(() => {
    setVeiculos(initialVeiculos)
  }, [initialVeiculos])

  // Vehicle Modals State
  const [isVehicleModalOpen, setIsVehicleModalOpen] = useState(false)
  const [editingVehicle, setEditingVehicle] = useState<VehicleData | null>(null)
  const [correctingVehicle, setCorrectingVehicle] = useState<VehicleData | null>(null)
  const [inactivatingVehicle, setInactivatingVehicle] = useState<VehicleData | null>(null)
  const [reactivatingVehicle, setReactivatingVehicle] = useState<VehicleData | null>(null)

  // Pets State (Gate 3E.2-B)
  const [pets, setPets] = useState<PetData[]>(initialPets)
  useEffect(() => {
    setPets(initialPets)
  }, [initialPets])

  // Pet Modals State
  const [isPetModalOpen, setIsPetModalOpen] = useState(false)
  const [editingPet, setEditingPet] = useState<PetData | null>(null)
  const [transferringPet, setTransferringPet] = useState<PetData | null>(null)
  const [inactivatingPet, setInactivatingPet] = useState<PetData | null>(null)
  const [reactivatingPet, setReactivatingPet] = useState<PetData | null>(null)

  // Dependentes State (Gate 3G.3-B4)
  const [isDependentModalOpen, setIsDependentModalOpen] = useState(false)
  const [editingDependente, setEditingDependente] = useState<DependenteData | null>(null)
  const [inactivatingDependente, setInactivatingDependente] = useState<DependenteData | null>(null)
  const [reactivatingDependente, setReactivatingDependente] = useState<DependenteData | null>(null)
  const [transferringDependente, setTransferringDependente] = useState<DependenteData | null>(null)

  // Photo Modals State (Gate 3F.2-B, Gate 3J & Gate 3K)
  const [photoUploadTarget, setPhotoUploadTarget] = useState<{
    type: 'pet' | 'veiculo' | 'morador' | 'dependente'
    id: string
    name: string
    condoId: string
    currentPhotoPath?: string | null
  } | null>(null)

  const [photoRemoveTarget, setPhotoRemoveTarget] = useState<{
    type: 'pet' | 'veiculo' | 'morador' | 'dependente'
    id: string
    name: string
    condoId: string
    currentPhotoPath: string
  } | null>(null)

  const [viewingPhoto, setViewingPhoto] = useState<{
    url: string
    title: string
  } | null>(null)

  // Block / Unblock Modal State
  const [confirmAction, setConfirmAction] = useState<'block' | 'unblock' | null>(null)
  const [actionLoading, setActionLoading] = useState(false)
  const [actionError, setActionError] = useState<string | null>(null)

  // Gate 3L: Approve / Reject Modal State
  const [isApproveModalOpen, setIsApproveModalOpen] = useState(false)
  const [isRejectModalOpen, setIsRejectModalOpen] = useState(false)
  const [approvalLoading, setApprovalLoading] = useState(false)
  const [approvalError, setApprovalError] = useState<string | null>(null)
  const [rejectionLoading, setRejectionLoading] = useState(false)
  const [rejectionError, setRejectionError] = useState<string | null>(null)

  async function handleConfirmApprove(motivo?: string) {
    setApprovalLoading(true)
    setApprovalError(null)

    const res = await adminApproveResident({
      residentId: resident.id,
      motivo,
    })

    if (res.error) {
      setApprovalError(res.error)
      setApprovalLoading(false)
      return
    }

    setResident(prev => ({
      ...prev,
      status_aprovacao: 'aprovado',
    }))

    setApprovalLoading(false)
    setIsApproveModalOpen(false)
    router.refresh()
  }

  async function handleConfirmReject(motivo: string) {
    setRejectionLoading(true)
    setRejectionError(null)

    const res = await adminRejectResident({
      residentId: resident.id,
      motivo,
    })

    if (res.error) {
      setRejectionError(res.error)
      setRejectionLoading(false)
      return
    }

    setResident(prev => ({
      ...prev,
      status_aprovacao: 'rejeitado',
    }))

    setRejectionLoading(false)
    setIsRejectModalOpen(false)
    router.refresh()
  }

  // Inactivate Modal State
  const [isInactivateModalOpen, setIsInactivateModalOpen] = useState(false)

  // Create Resident Link Modal State (Gate 3C.7)
  const [isCreateLinkModalOpen, setIsCreateLinkModalOpen] = useState(false)

  // Edit General Data Modal State (Gate 3I.4)
  const [editGeneralDataOpen, setEditGeneralDataOpen] = useState(false)

  async function handleConfirmBlockAction() {
    if (!confirmAction) return
    setActionLoading(true)
    setActionError(null)

    const res = await adminToggleBlockStatus({
      profileId: resident.id,
      action: confirmAction,
    })

    if (res.error) {
      setActionError(res.error)
      setActionLoading(false)
      return
    }

    setResident(prev => ({
      ...prev,
      status_aprovacao: res.newStatus!,
      bloqueado: res.newBloqueado!,
    }))

    setActionLoading(false)
    setConfirmAction(null)
    router.refresh()
  }

  const blocoLabel = getBlocoLabel(condoTipoEstrutura)
  const aptoLabel = getAptoLabel(condoTipoEstrutura)

  // Status computation consistent with Moradores rule
  const isInactive = resident.status_aprovacao === 'inativo'
  const isBlocked = resident.status_aprovacao === 'bloqueado' || resident.bloqueado === true
  const isApproved = resident.status_aprovacao === 'aprovado' && !resident.bloqueado
  const isPending = resident.status_aprovacao === 'pendente'
  const isRejected = resident.status_aprovacao === 'rejeitado' || resident.status_aprovacao === 'reprovado'

  const role = ROLE_CONFIG[resident.papel_sistema ?? ''] ?? defaultRole
  const initials = getInitials(resident.nome_completo)
  const avatarGrad = getAvatarColor(resident.id)

  const activeUnit = unitLinks.find(u => u.status === 'ativo')
  const inactiveUnits = unitLinks.filter(u => u.status === 'inativo')

  // ── Gate 3G.4-D1: Ocupação da unidade (limite canônico de 4 pessoas) ──
  const MAX_OCUPANTES_UNIDADE = 4

  // Moradores ativos na unidade: o morador atual (se aprovado e ativo) + co-residentes
  const currentResidentIsActive = isApproved && activeUnit != null
  const moradoresAtivosUnidade = (currentResidentIsActive ? 1 : 0) + coResidents.length

  // Dependentes ativos não-convertidos (convertidos já contam como moradores)
  const dependentesAtivosNaoConvertidos = dependentes.filter(
    d => d.status === 'ativo' && d.perfil_convertido_id == null
  ).length

  const ocupacaoAtual = moradoresAtivosUnidade + dependentesAtivosNaoConvertidos
  const limiteAtingido = ocupacaoAtual >= MAX_OCUPANTES_UNIDADE

  const formattedUnit = formatUnitDisplay({
    bloco: activeUnit?.bloco_nome || resident.bloco_txt,
    apto: activeUnit?.apto_numero || resident.apto_txt,
    role: resident.papel_sistema,
    tipoEstrutura: condoTipoEstrutura,
    fallback: 'Administrativo',
  })

  const TABS: { key: TabKey; label: string; icon: React.ReactNode; count?: number }[] = [
    { key: 'dados-gerais', label: 'Dados Gerais', icon: <User size={16} /> },
    { key: 'unidade', label: 'Unidade', icon: <Home size={16} />, count: unitLinks.filter(u => u.status === 'ativo').length },
    { key: 'veiculos', label: 'Veículos', icon: <Car size={16} />, count: veiculosError ? undefined : veiculos.length },
    { key: 'pets', label: 'Pets', icon: <PawPrint size={16} />, count: petsError ? undefined : pets.length },
    { key: 'familia', label: 'Família', icon: <Users size={16} />, count: ((dependentes?.length ?? 0) + (coResidents.length > 0 ? coResidents.length + 1 : 0)) || undefined },
    { key: 'acessos', label: 'Acessos', icon: <KeyRound size={16} />, count: serverConvitesTotal + serverPortariaTotal },
    { key: 'historico', label: 'Histórico 🔒', icon: <Clock size={16} />, count: auditLogs.length > 0 ? auditLogs.length : undefined },
  ]

  return (
    <div className="space-y-6 max-w-7xl mx-auto">
      {/* ── Top Bar ────────────────────────────────────────────── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <Link
          href="/admin/moradores"
          className="inline-flex items-center gap-2 text-sm font-semibold text-gray-600 hover:text-[#FC5931] transition-colors w-fit group"
        >
          <div className="w-8 h-8 rounded-lg bg-white border border-gray-200 flex items-center justify-center group-hover:border-[#FC5931] group-hover:bg-[#FC5931]/5 transition-colors">
            <ArrowLeft size={16} />
          </div>
          <span>Voltar para Moradores</span>
        </Link>

        {/* Cleaned Top Bar Badge (Sem referência a Gate técnico) */}
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-700 border border-gray-200">
          <Shield size={12} className="text-gray-500" />
          <span>Base Cadastral 360º</span>
        </div>
      </div>

      {/* ── Header 360 Hero ────────────────────────────────────── */}
      <div className={`bg-white rounded-2xl border shadow-sm p-6 sm:p-8 transition-all ${
        isInactive ? 'border-zinc-200 bg-zinc-50/20' : 'border-gray-100'
      }`}>
        <div className="flex flex-col md:flex-row md:items-center gap-6 justify-between">
          {/* Avatar + Main Info */}
          <div className="flex items-start sm:items-center gap-5">
            <div className="relative shrink-0 group">
              {resident.foto_signed_url || resident.foto_url ? (
                <button
                  type="button"
                  onClick={() => setViewingPhoto({
                    url: resident.foto_signed_url || resident.foto_url!,
                    title: `Foto do Morador: ${resident.nome_completo || 'Sem nome'}`
                  })}
                  className="block relative overflow-hidden rounded-2xl shadow-sm border-2 border-gray-100 hover:border-[#FC5931] transition-all cursor-pointer group"
                  title="Clique para ampliar a foto"
                >
                  <img
                    src={resident.foto_signed_url || resident.foto_url!}
                    alt={resident.nome_completo || 'Morador'}
                    className="w-20 h-20 rounded-2xl object-cover"
                  />
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-white rounded-2xl">
                    <Eye size={20} />
                  </div>
                </button>
              ) : (
                <div
                  className={`w-20 h-20 rounded-2xl flex items-center justify-center shadow-md ${
                    isInactive ? 'bg-zinc-200 text-zinc-600' : `bg-gradient-to-br ${avatarGrad} text-white`
                  }`}
                >
                  {isBlocked ? (
                    <Lock size={32} className="text-white/90" />
                  ) : isInactive ? (
                    <UserX size={32} className="text-zinc-600" />
                  ) : (
                    <span className="text-white text-2xl font-bold tracking-tight">{initials}</span>
                  )}
                </div>
              )}

              {/* Botão de câmera sobre o avatar */}
              <button
                type="button"
                onClick={() => {
                  if (isInactive) return
                  setPhotoUploadTarget({
                    type: 'morador',
                    id: resident.id,
                    name: resident.nome_completo || 'Morador',
                    condoId: resident.condominio_id,
                    currentPhotoPath: resident.foto_url,
                  })
                }}
                disabled={isInactive}
                title={
                  isInactive
                    ? 'Morador inativo — cadastro histórico protegido'
                    : (resident.foto_signed_url || resident.foto_url)
                    ? 'Alterar foto do morador'
                    : 'Adicionar foto do morador'
                }
                className={`absolute -bottom-1 -right-1 p-1.5 rounded-full shadow-md border-2 border-white transition-all ${
                  isInactive
                    ? 'bg-zinc-300 text-zinc-500 cursor-not-allowed opacity-60'
                    : 'bg-[#FC5931] hover:bg-[#e04820] text-white cursor-pointer hover:scale-105 active:scale-95'
                }`}
              >
                <Camera size={13} />
              </button>
            </div>

            <div className="min-w-0">
              <div className="flex items-center gap-2.5 flex-wrap">
                <h1 className={`text-2xl font-bold tracking-tight ${
                  isBlocked ? 'line-through text-gray-500' : isInactive ? 'text-zinc-700' : 'text-gray-900'
                }`}>
                  {resident.nome_completo || 'Sem nome cadastrado'}
                </h1>
                
                {/* Status Badge */}
                {isInactive ? (
                  <span className="inline-flex items-center gap-1 text-xs px-2.5 py-0.5 rounded-full font-bold bg-zinc-100 text-zinc-700 border border-zinc-300">
                    <UserX size={11} /> INATIVO
                  </span>
                ) : isBlocked ? (
                  <span className="inline-flex items-center gap-1 text-xs px-2.5 py-0.5 rounded-full font-bold bg-red-100 text-red-700 border border-red-200">
                    <Lock size={11} /> BLOQUEADO
                  </span>
                ) : isApproved ? (
                  <span className="inline-flex items-center gap-1 text-xs px-2.5 py-0.5 rounded-full font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                    <CheckCircle size={11} /> ATIVO
                  </span>
                ) : isPending ? (
                  <span className="inline-flex items-center gap-1 text-xs px-2.5 py-0.5 rounded-full font-bold bg-amber-50 text-amber-700 border border-amber-200">
                    <AlertCircle size={11} /> PENDENTE
                  </span>
                ) : isRejected ? (
                  <span className="inline-flex items-center gap-1 text-xs px-2.5 py-0.5 rounded-full font-bold bg-gray-100 text-gray-700 border border-gray-200">
                    REJEITADO
                  </span>
                ) : (
                  <span className="text-xs px-2.5 py-0.5 rounded-full font-bold bg-gray-100 text-gray-600">
                    {resident.status_aprovacao || 'Pendente'}
                  </span>
                )}
              </div>

              {/* Sub-identity row */}
              <div className="flex items-center gap-3 mt-2 flex-wrap text-sm text-gray-600">
                {isInactive ? (
                  <span className="font-semibold text-gray-800 flex items-center gap-1.5 flex-wrap">
                    <Home size={14} className="text-zinc-500" />
                    <span>
                      Última unidade: {inactiveUnits[0]?.bloco_nome || unitLinks[0]?.bloco_nome ? `${blocoLabel} ${inactiveUnits[0]?.bloco_nome || unitLinks[0]?.bloco_nome} · ` : ''}{aptoLabel} {inactiveUnits[0]?.apto_numero || unitLinks[0]?.apto_numero || '—'}
                    </span>
                    {(inactiveUnits[0] || unitLinks[0]) && (
                      <span className="text-xs font-normal text-zinc-600 bg-zinc-100 px-2 py-0.5 rounded-md border border-zinc-200">
                        {formatDate(inactiveUnits[0]?.data_entrada || unitLinks[0]?.data_entrada)} até {formatDate(inactiveUnits[0]?.data_saida || unitLinks[0]?.data_saida || resident.updated_at)}
                      </span>
                    )}
                  </span>
                ) : (
                  <span className="font-semibold text-gray-800 flex items-center gap-1">
                    <Home size={14} className="text-[#FC5931]" />
                    {formattedUnit}
                  </span>
                )}

                <span className="text-gray-300">•</span>

                {resident.papel_sistema && (
                  <span className={`inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full font-semibold border ${role.bg} ${role.text} ${role.border}`}>
                    {role.icon} {resident.papel_sistema}
                  </span>
                )}

                {resident.tipo_morador && (
                  <span className="text-xs px-2 py-0.5 rounded-full font-medium bg-gray-100 text-gray-700">
                    {resident.tipo_morador}
                  </span>
                )}
              </div>

              {/* Timestamp info */}
              <p className="text-xs text-gray-400 mt-2 flex items-center gap-1">
                <Calendar size={12} />
                Cadastrado em {formatDateTime(resident.created_at)} no condomínio {condoNome}
              </p>
            </div>
          </div>

          {/* Administrative and Contact Actions */}
          <div className="flex items-center gap-2 flex-wrap self-end md:self-center">
            {/* Gate 3L: Ações Contextuais de Morador Pendente */}
            {isPending && (
              <>
                <button
                  type="button"
                  onClick={() => {
                    setApprovalError(null)
                    setIsApproveModalOpen(true)
                  }}
                  className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-emerald-50 text-emerald-700 hover:bg-emerald-100 transition-colors border border-emerald-200 shadow-2xs"
                  title="Aprovar cadastro deste morador"
                >
                  <CheckCircle size={13} />
                  Aprovar
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setRejectionError(null)
                    setIsRejectModalOpen(true)
                  }}
                  className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-red-50 text-red-600 hover:bg-red-100 transition-colors border border-red-200 shadow-2xs"
                  title="Rejeitar cadastro deste morador"
                >
                  <XCircle size={13} />
                  Rejeitar
                </button>
              </>
            )}

            {/* Gate 3L: Ação de Reconsideração de Morador Rejeitado */}
            {isRejected && (
              <button
                type="button"
                onClick={() => {
                  setApprovalError(null)
                  setIsApproveModalOpen(true)
                }}
                className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-emerald-50 text-emerald-700 hover:bg-emerald-100 transition-colors border border-emerald-200 shadow-2xs"
                title="Aprovar cadastro previamente rejeitado"
              >
                <CheckCircle size={13} />
                Aprovar cadastro
              </button>
            )}

            {/* Contextual Administrative Action: Bloquear / Reativar */}
            {isApproved && (
              <button
                type="button"
                onClick={() => {
                  setActionError(null)
                  setConfirmAction('block')
                }}
                className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-red-50 text-red-600 hover:bg-red-100 transition-colors border border-red-200 shadow-2xs"
                title="Bloquear acesso do morador"
              >
                <Lock size={13} />
                Bloquear
              </button>
            )}

            {isBlocked && (
              <button
                type="button"
                onClick={() => {
                  setActionError(null)
                  setConfirmAction('unblock')
                }}
                className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-emerald-50 text-emerald-700 hover:bg-emerald-100 transition-colors border border-emerald-200 shadow-2xs"
                title="Reativar acesso do morador"
              >
                <Unlock size={13} />
                Reativar
              </button>
            )}

            {/* Inativar Vínculo de Morador (Gate 3C.5) */}
            {activeUnit && (isApproved || isBlocked) && (
              <button
                type="button"
                onClick={() => setIsInactivateModalOpen(true)}
                className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-zinc-100 text-zinc-700 hover:bg-zinc-200 transition-colors border border-zinc-300 shadow-2xs"
                title="Inativar vínculo imobiliário deste morador"
              >
                <UserX size={13} />
                Inativar
              </button>
            )}

            {/* Novo Vínculo Residencial (Gate 3C.7) */}
            {isInactive && (
              <button
                type="button"
                onClick={() => setIsCreateLinkModalOpen(true)}
                className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-emerald-50 text-emerald-700 hover:bg-emerald-100 transition-colors border border-emerald-200 shadow-2xs"
                title="Atribuir novo vínculo residencial para este morador"
              >
                <PlusCircle size={13} />
                Novo vínculo
              </button>
            )}

            {resident.whatsapp && (
              <a
                href={`https://wa.me/55${resident.whatsapp.replace(/\D/g, '')}`}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-semibold bg-[#25D366]/10 text-[#128C7E] hover:bg-[#25D366]/20 transition-colors border border-[#25D366]/30"
              >
                <Phone size={13} />
                WhatsApp
                <ExternalLink size={11} />
              </a>
            )}
            {resident.email && (
              <a
                href={`mailto:${resident.email}`}
                className="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-semibold bg-blue-50 text-blue-700 hover:bg-blue-100 transition-colors border border-blue-200"
              >
                <Mail size={13} />
                E-mail
              </a>
            )}
          </div>
        </div>
      </div>

      {/* ── Tabs Navigation ────────────────────────────────────── */}
      <div className="border-b border-gray-200 overflow-x-auto scrollbar-none">
        <nav className="flex space-x-2 sm:space-x-4 min-w-max pb-px" aria-label="Abas">
          {TABS.map(tab => {
            const isActive = activeTab === tab.key
            return (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`flex items-center gap-2 py-3 px-3 sm:px-4 rounded-t-xl text-sm font-semibold transition-all border-b-2 ${
                  isActive
                    ? 'border-[#FC5931] text-[#FC5931] bg-white shadow-xs'
                    : 'border-transparent text-gray-500 hover:text-gray-800 hover:border-gray-300'
                }`}
              >
                {tab.icon}
                <span>{tab.label}</span>
                {tab.count !== undefined && (
                  <span
                    className={`text-[11px] px-1.5 py-0.2 rounded-full font-bold ${
                      isActive ? 'bg-[#FC5931]/10 text-[#FC5931]' : 'bg-gray-100 text-gray-500'
                    }`}
                  >
                    {tab.count}
                  </span>
                )}
              </button>
            )
          })}
        </nav>
      </div>

      {/* ── Tab Content ────────────────────────────────────────── */}
      <div className="mt-4">
        {/* 1. DADOS GERAIS */}
        {activeTab === 'dados-gerais' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {/* Card 1: Identificação Pessoal */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
                  <User size={18} className="text-[#FC5931]" />
                  Identificação Pessoal
                </h2>
                <button
                  type="button"
                  onClick={() => setEditGeneralDataOpen(true)}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 transition-colors"
                >
                  <Edit2 size={13} className="text-gray-500" />
                  Editar dados
                </button>
              </div>
              <dl className="space-y-3.5 text-sm">
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Nome Completo</dt>
                  <dd className="font-medium text-gray-900 mt-0.5">{resident.nome_completo || '—'}</dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1.5">Foto do Perfil</dt>
                  <dd className="mt-1">
                    {resident.foto_signed_url || resident.foto_url ? (
                      <div className="flex items-center gap-3.5">
                        {/* Miniatura com clique para ampliar */}
                        <button
                          type="button"
                          onClick={() => setViewingPhoto({
                            url: resident.foto_signed_url || resident.foto_url!,
                            title: `Foto do Morador: ${resident.nome_completo || 'Sem nome'}`
                          })}
                          className="relative w-14 h-14 rounded-xl overflow-hidden border border-gray-200 shadow-xs cursor-pointer hover:border-[#FC5931] transition-all group shrink-0"
                          title="Clique para ampliar a foto"
                        >
                          <img
                            src={resident.foto_signed_url || resident.foto_url!}
                            alt={resident.nome_completo || 'Foto do Morador'}
                            className="w-full h-full object-cover"
                          />
                          <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-white">
                            <Eye size={16} />
                          </div>
                        </button>

                        <div className="flex flex-col gap-1.5">
                          {isInactive ? (
                            <p className="text-xs text-zinc-500 font-medium">
                              Morador inativo — cadastro histórico protegido.
                            </p>
                          ) : (
                            <div className="flex items-center gap-2">
                              <button
                                type="button"
                                onClick={() => setPhotoUploadTarget({
                                  type: 'morador',
                                  id: resident.id,
                                  name: resident.nome_completo || 'Morador',
                                  condoId: resident.condominio_id,
                                  currentPhotoPath: resident.foto_url,
                                })}
                                className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 transition-colors cursor-pointer"
                              >
                                <Camera size={13} className="text-gray-500" />
                                Alterar foto
                              </button>
                              <button
                                type="button"
                                onClick={() => setPhotoRemoveTarget({
                                  type: 'morador',
                                  id: resident.id,
                                  name: resident.nome_completo || 'Morador',
                                  condoId: resident.condominio_id,
                                  currentPhotoPath: resident.foto_url!,
                                })}
                                className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-semibold text-red-600 bg-red-50 hover:bg-red-100 transition-colors cursor-pointer"
                              >
                                <Trash2 size={13} className="text-red-500" />
                                Remover foto
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    ) : (
                      <div className="flex flex-col gap-2">
                        <div className="flex items-center gap-3">
                          <span className="text-sm text-gray-500 font-normal">Não cadastrada</span>
                          {!isInactive && (
                            <button
                              type="button"
                              onClick={() => setPhotoUploadTarget({
                                type: 'morador',
                                id: resident.id,
                                name: resident.nome_completo || 'Morador',
                                condoId: resident.condominio_id,
                                currentPhotoPath: null,
                              })}
                              className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-semibold text-[#FC5931] bg-orange-50 hover:bg-orange-100 transition-colors cursor-pointer"
                            >
                              <Camera size={13} />
                              Adicionar foto
                            </button>
                          )}
                        </div>
                        {isInactive && (
                          <p className="text-xs text-zinc-500 font-medium">
                            Morador inativo — cadastro histórico protegido.
                          </p>
                        )}
                      </div>
                    )}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Data de Cadastro</dt>
                  <dd className="font-medium text-gray-900 mt-0.5">{formatDateTime(resident.created_at)}</dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Última Interação Registrada</dt>
                  <dd className="font-medium text-gray-700 mt-0.5">
                    {resident.last_interaction_at ? formatDateTime(resident.last_interaction_at) : 'Nenhum registro recente'}
                  </dd>
                </div>
              </dl>
            </div>

            {/* Card 2: Comunicação & Canais */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <h2 className="text-base font-bold text-gray-900 mb-4 flex items-center gap-2">
                <Phone size={18} className="text-[#FC5931]" />
                Comunicação & Notificações
              </h2>
              <dl className="space-y-3.5 text-sm">
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">E-mail Cadastrado</dt>
                  <dd className="font-medium text-gray-900 mt-0.5">{resident.email || '—'}</dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Telefone / WhatsApp</dt>
                  <dd className="font-medium text-gray-900 mt-0.5">{resident.whatsapp || '—'}</dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Notificações por WhatsApp</dt>
                  <dd className="font-medium mt-0.5">
                    {resident.notificacoes_whatsapp ? (
                      <span className="text-emerald-700 flex items-center gap-1">
                        <CheckCircle size={14} /> Ativadas
                      </span>
                    ) : (
                      <span className="text-gray-500">Desativadas</span>
                    )}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Consentimento Mensageria (LGPD)</dt>
                  <dd className="text-gray-700 mt-0.5">
                    {resident.whatsapp_msg_consent ? 'Consentimento formal registrado' : 'Não registrado formalmente'}
                  </dd>
                </div>
              </dl>
            </div>

            {/* Card 3: Perfil & Sistema */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <h2 className="text-base font-bold text-gray-900 mb-4 flex items-center gap-2">
                <Shield size={18} className="text-[#FC5931]" />
                Perfil & Papel no Condomínio
              </h2>
              <dl className="space-y-3.5 text-sm">
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Papel no Sistema</dt>
                  <dd className="mt-0.5">
                    <span className={`inline-flex items-center gap-1 text-xs px-2.5 py-0.5 rounded-full font-semibold border ${role.bg} ${role.text} ${role.border}`}>
                      {role.icon} {resident.papel_sistema || 'Morador'}
                    </span>
                  </dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tipo de Morador</dt>
                  <dd className="font-medium text-gray-900 mt-0.5">{resident.tipo_morador || 'Não informado'}</dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Status Cadastral</dt>
                  <dd className="font-medium text-gray-900 mt-0.5 capitalize">{resident.status_aprovacao || 'pendente'}</dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Restrição de Acesso (Bloqueio)</dt>
                  <dd className="font-medium mt-0.5">
                    {isBlocked ? (
                      <span className="text-red-700 font-semibold flex items-center gap-1">
                        <Lock size={14} /> Usuário bloqueado no sistema
                      </span>
                    ) : (
                      <span className="text-emerald-700 font-semibold flex items-center gap-1">
                        <CheckCircle size={14} /> Acesso liberado
                      </span>
                    )}
                  </dd>
                </div>
              </dl>
            </div>

            {/* Card 4: Segurança & Conformidade */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <h2 className="text-base font-bold text-gray-900 mb-4 flex items-center gap-2">
                <KeyRound size={18} className="text-[#FC5931]" />
                Segurança & Autenticação
              </h2>
              <dl className="space-y-3.5 text-sm">
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Configuração de Senha</dt>
                  <dd className="font-medium mt-0.5">
                    {resident.needs_password_setup ? (
                      <span className="text-amber-700 font-semibold flex items-center gap-1">
                        <AlertCircle size={14} /> Pendente de configuração de senha
                      </span>
                    ) : (
                      <span className="text-emerald-700 font-semibold flex items-center gap-1">
                        <CheckCircle size={14} /> Senha ativa
                      </span>
                    )}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">ID Canônico do Perfil</dt>
                  <dd className="font-mono text-xs text-gray-500 break-all mt-0.5">{resident.id}</dd>
                </div>
                <div className="pt-2 border-t border-gray-100">
                  <div className="bg-gray-50 rounded-xl p-3 text-xs text-gray-500 flex items-start gap-2">
                    <Info size={14} className="text-gray-400 shrink-0 mt-0.5" />
                    <span>
                      Campos de CPF/RG e data de nascimento não constam no cadastro oficial e serão integrados em conformidade legal em etapas futuras.
                    </span>
                  </div>
                </div>
              </dl>
            </div>
          </div>
        )}

        {/* 2. UNIDADE */}
        {activeTab === 'unidade' && (
          <div className="space-y-6">
            {/* Active Units */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
                  <Home size={18} className="text-[#FC5931]" />
                  Unidade Ativa
                </h2>
                <span className="text-xs px-2.5 py-0.5 rounded-full font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                  Vínculo Vigente
                </span>
              </div>

              {activeUnit ? (
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 pt-2">
                  <div className="p-4 rounded-xl bg-gray-50 border border-gray-100">
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">{blocoLabel}</p>
                    <p className="text-lg font-bold text-gray-900 mt-1">{activeUnit.bloco_nome || resident.bloco_txt || '—'}</p>
                  </div>

                  <div className="p-4 rounded-xl bg-gray-50 border border-gray-100">
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">{aptoLabel}</p>
                    <p className="text-lg font-bold text-gray-900 mt-1">{activeUnit.apto_numero || resident.apto_txt || '—'}</p>
                  </div>

                  <div className="p-4 rounded-xl bg-gray-50 border border-gray-100">
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Data de Ingresso</p>
                    <p className="text-lg font-bold text-gray-900 mt-1">{formatDate(activeUnit.data_entrada || resident.created_at)}</p>
                  </div>

                  {activeUnit.fracao_ideal && (
                    <div className="p-4 rounded-xl bg-gray-50 border border-gray-100">
                      <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Fração Ideal</p>
                      <p className="text-base font-semibold text-gray-900 mt-1">{String(activeUnit.fracao_ideal)}</p>
                    </div>
                  )}

                  <div className="p-4 rounded-xl bg-gray-50 border border-gray-100 md:col-span-2">
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Situação da Unidade</p>
                    <p className="text-sm font-medium text-gray-800 mt-1 flex items-center gap-1.5">
                      {activeUnit.bloqueada ? (
                        <span className="text-amber-700 flex items-center gap-1">
                          <AlertCircle size={14} /> Unidade com restrição administrativa
                        </span>
                      ) : (
                        <span className="text-emerald-700 flex items-center gap-1">
                          <CheckCircle size={14} /> Unidade regular
                        </span>
                      )}
                    </p>
                  </div>
                </div>
              ) : (
                <div className="p-6 rounded-xl bg-gray-50 text-center">
                  <Home size={32} className="mx-auto text-gray-300 mb-2" />
                  <p className="font-semibold text-gray-700">Vínculo relacional não associado</p>
                  <p className="text-xs text-gray-500 mt-1">
                    Unidade registrada apenas em texto plano: {blocoLabel} {resident.bloco_txt || '—'} · {aptoLabel} {resident.apto_txt || '—'}
                  </p>
                </div>
              )}
            </div>

            {/* Inactive Historical Units */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <h3 className="text-sm font-bold text-gray-800 mb-3 flex items-center gap-2">
                <Clock size={16} className="text-gray-400" />
                Histórico de Unidades Anteriores
              </h3>
              {inactiveUnits.length > 0 ? (
                <div className="divide-y divide-gray-100">
                  {inactiveUnits.map(unit => (
                    <div key={unit.id} className="py-3 flex items-center justify-between">
                      <div>
                        <p className="font-semibold text-sm text-gray-800">
                          {blocoLabel} {unit.bloco_nome || '—'} · {aptoLabel} {unit.apto_numero || '—'}
                        </p>
                        <p className="text-xs text-gray-400 mt-0.5">
                          Período: {formatDate(unit.data_entrada)} até {formatDate(unit.data_saida)}
                        </p>
                      </div>
                      <span className="text-xs px-2.5 py-0.5 rounded-full font-medium bg-gray-100 text-gray-600">
                        Inativo
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-gray-400 py-3">
                  Nenhum histórico anterior de troca de unidade registrado para este morador.
                </p>
              )}
            </div>
          </div>
        )}

        {/* 3. VEÍCULOS */}
        {activeTab === 'veiculos' && (
          <div className="space-y-6">
            {/* Aviso discreto caso o morador esteja com acesso bloqueado */}
            {isBlocked && (
              <div className="bg-amber-50/80 border border-amber-200/90 rounded-xl p-3.5 flex items-center gap-3">
                <Lock size={16} className="text-amber-700 shrink-0" />
                <p className="text-xs text-amber-800">
                  <strong className="font-semibold">Morador com acesso administrativo bloqueado:</strong> Os veículos cadastrados permanecem vinculados e visíveis para a administração do condomínio.
                </p>
              </div>
            )}

            {/* Aviso para morador inativo */}
            {isInactive && (
              <div className="bg-zinc-100 border border-zinc-200 rounded-xl p-3.5 flex items-center gap-3">
                <Info size={16} className="text-zinc-600 shrink-0" />
                <p className="text-xs text-zinc-700">
                  <strong className="font-semibold">Morador inativo:</strong> Exibindo veículos históricos cadastrados. Para cadastrar novos veículos, o morador deve possuir um vínculo residencial ativo.
                </p>
              </div>
            )}

            {/* Erro de consulta na base de veículos */}
            {veiculosError && (
              <div className="bg-red-50 border border-red-200 rounded-xl p-3.5 flex items-center gap-3">
                <AlertCircle size={16} className="text-red-600 shrink-0" />
                <p className="text-xs text-red-700 font-medium">
                  {veiculosError}
                </p>
              </div>
            )}

            {/* Cabeçalho da aba de veículos */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                  <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
                    <Car size={18} className="text-[#FC5931]" />
                    Veículos {veiculosError ? '' : `(${veiculos.length})`}
                  </h2>
                  <p className="text-xs text-gray-500 mt-1">
                    Veículos cadastrados e vinculados a este morador para controle patrimonial e de vagas.
                  </p>
                </div>

                <button
                  onClick={() => {
                    setEditingVehicle(null)
                    setIsVehicleModalOpen(true)
                  }}
                  className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-semibold bg-[#FC5931] text-white hover:bg-[#e04820] shadow-sm transition-all self-start sm:self-auto cursor-pointer"
                >
                  <PlusCircle size={15} />
                  + Adicionar veículo
                </button>
              </div>

              {/* Lista ou Estado Vazio / Erro */}
              {veiculosError ? (
                <div className="py-12 text-center max-w-md mx-auto">
                  <div className="w-16 h-16 rounded-2xl bg-red-50 mx-auto flex items-center justify-center mb-4">
                    <AlertCircle size={32} className="text-red-500" />
                  </div>
                  <h3 className="text-base font-bold text-gray-900 mb-1">Erro na consulta de veículos</h3>
                  <p className="text-xs text-gray-500">
                    Ocorreu uma falha ao consultar o banco de dados. Recarregue a página ou contate o administrador do sistema.
                  </p>
                </div>
              ) : veiculos.length === 0 ? (
                <div className="py-12 text-center max-w-md mx-auto">
                  <div className="w-16 h-16 rounded-2xl bg-orange-50 mx-auto flex items-center justify-center mb-4">
                    <Car size={32} className="text-[#FC5931]" />
                  </div>
                  <h3 className="text-base font-bold text-gray-900 mb-1">Nenhum veículo cadastrado.</h3>
                  <p className="text-xs text-gray-500 mb-6">
                    Cadastre os veículos deste morador para facilitar a identificação e a gestão de vagas do condomínio.
                  </p>
                  <button
                    onClick={() => {
                      setEditingVehicle(null)
                      setIsVehicleModalOpen(true)
                    }}
                    className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-semibold bg-[#FC5931] text-white hover:bg-[#e04820] shadow-sm transition-all cursor-pointer"
                  >
                    <PlusCircle size={15} />
                    + Adicionar veículo
                  </button>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mt-6">
                  {veiculos.map((veiculo) => {
                    const isAtivo = veiculo.status === 'ativo'

                    return (
                      <div
                        key={veiculo.id}
                        className={`rounded-2xl border p-5 transition-all flex flex-col justify-between ${
                          isAtivo
                            ? 'bg-white border-gray-200/90 shadow-sm hover:border-[#FC5931]/30 hover:shadow-md'
                            : 'bg-zinc-50/80 border-zinc-200 text-zinc-500 shadow-none'
                        }`}
                      >
                        <div className="space-y-3">
                          {/* Linha Superior: Placa e Badge de Status */}
                          <div className="flex items-center justify-between gap-2">
                            {/* Placa estilizada */}
                            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-zinc-900 text-white font-mono font-extrabold tracking-widest text-sm shadow-xs border border-zinc-800">
                              <span className="text-[9px] font-sans font-semibold tracking-normal text-zinc-400 uppercase">BR</span>
                              <span>{formatPlateDisplay(veiculo.placa)}</span>
                            </div>

                            {/* Status */}
                            {isAtivo ? (
                              <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                                ATIVO
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-zinc-100 text-zinc-600 border border-zinc-200">
                                <span className="w-1.5 h-1.5 rounded-full bg-zinc-400" />
                                INATIVO
                              </span>
                            )}
                          </div>

                          {/* Foto e Informações Principais do Veículo */}
                          <div className="flex items-start gap-3.5 pt-1">
                            {/* Miniatura ou Fallback */}
                            <div className="relative shrink-0 group">
                              {veiculo.foto_signed_url ? (
                                <button
                                  type="button"
                                  onClick={() => setViewingPhoto({ url: veiculo.foto_signed_url!, title: `Veículo: ${formatPlateDisplay(veiculo.placa)}` })}
                                  className="block relative overflow-hidden rounded-xl border border-gray-200 shadow-xs cursor-pointer hover:border-[#FC5931] transition-all group"
                                  title="Clique para ampliar a foto do veículo"
                                >
                                  <img
                                    src={veiculo.foto_signed_url}
                                    alt={`Veículo ${veiculo.placa}`}
                                    className="w-20 h-20 object-cover"
                                  />
                                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-white">
                                    <Eye size={16} />
                                  </div>
                                </button>
                              ) : veiculo.foto_path ? (
                                <div
                                  className="w-20 h-20 rounded-xl bg-amber-50 border border-amber-200 text-amber-600 flex flex-col items-center justify-center p-1 text-center"
                                  title="Foto vinculada no banco mas temporariamente inacessível"
                                >
                                  <AlertCircle size={18} />
                                  <span className="text-[9px] font-semibold mt-0.5 leading-tight">Foto indisponível</span>
                                </div>
                              ) : (
                                <div className="w-20 h-20 rounded-xl bg-gray-50 border border-dashed border-gray-200 flex flex-col items-center justify-center text-gray-400">
                                  <Car size={24} className="text-gray-300" />
                                  <span className="text-[9px] font-medium text-gray-400 mt-0.5">Sem foto</span>
                                </div>
                              )}
                            </div>

                            {/* Marca, Modelo e Ações de Mídia */}
                            <div className="min-w-0 flex-1">
                              <h3 className={`font-bold text-base leading-tight truncate ${isAtivo ? 'text-gray-900' : 'text-zinc-600'}`}>
                                {veiculo.marca} {veiculo.modelo}
                              </h3>
                              <p className="text-xs text-gray-500 mt-1 capitalize">
                                {veiculo.cor} · {veiculo.tipo} {veiculo.ano ? `· ${veiculo.ano}` : ''}
                              </p>

                              {/* Ações contextuais de foto (apenas para veículo ativo) */}
                              {isAtivo && (
                                <div className="flex items-center gap-2 mt-2 pt-1 border-t border-gray-100/60">
                                  {!veiculo.foto_path ? (
                                    <button
                                      type="button"
                                      onClick={() => setPhotoUploadTarget({
                                        type: 'veiculo',
                                        id: veiculo.id,
                                        name: formatPlateDisplay(veiculo.placa),
                                        condoId: veiculo.condominio_id,
                                        currentPhotoPath: null,
                                      })}
                                      className="inline-flex items-center gap-1 text-[11px] font-semibold text-[#FC5931] hover:text-[#e04820] hover:underline cursor-pointer"
                                    >
                                      <Camera size={12} />
                                      Adicionar foto
                                    </button>
                                  ) : (
                                    <>
                                      <button
                                        type="button"
                                        onClick={() => setPhotoUploadTarget({
                                          type: 'veiculo',
                                          id: veiculo.id,
                                          name: formatPlateDisplay(veiculo.placa),
                                          condoId: veiculo.condominio_id,
                                          currentPhotoPath: veiculo.foto_path,
                                        })}
                                        className="inline-flex items-center gap-1 text-[11px] font-semibold text-gray-600 hover:text-gray-900 hover:underline cursor-pointer"
                                      >
                                        <Camera size={12} />
                                        Alterar foto
                                      </button>
                                      <span className="text-gray-300 text-xs">·</span>
                                      <button
                                        type="button"
                                        onClick={() => setPhotoRemoveTarget({
                                          type: 'veiculo',
                                          id: veiculo.id,
                                          name: formatPlateDisplay(veiculo.placa),
                                          condoId: veiculo.condominio_id,
                                          currentPhotoPath: veiculo.foto_path!,
                                        })}
                                        className="inline-flex items-center gap-1 text-[11px] font-semibold text-red-600 hover:text-red-700 hover:underline cursor-pointer"
                                      >
                                        <Trash2 size={12} />
                                        Remover foto
                                      </button>
                                    </>
                                  )}
                                </div>
                              )}
                            </div>
                          </div>

                          {/* Vaga e Unidade */}
                          <div className="space-y-1 pt-1">
                            {veiculo.vaga_numero && (
                              <div className="text-xs text-gray-600 font-medium">
                                Vaga: <span className="font-semibold text-gray-900">{veiculo.vaga_numero}</span>
                              </div>
                            )}

                            {(veiculo.unidade_bloco || veiculo.unidade_apto) && (
                              <div className="text-[11px] text-gray-400">
                                Unidade: {blocoLabel} {veiculo.unidade_bloco || '—'} · {aptoLabel} {veiculo.unidade_apto || '—'}
                              </div>
                            )}
                          </div>

                          {/* Observação se houver */}
                          {veiculo.observacao && (
                            <p className="text-xs text-gray-500 italic bg-gray-50/80 p-2.5 rounded-xl border border-gray-100 line-clamp-2">
                              "{veiculo.observacao}"
                            </p>
                          )}
                        </div>

                        {/* Ações Administrativas */}
                        <div className="pt-4 mt-4 border-t border-gray-100 flex items-center justify-between gap-2 flex-wrap">
                          {isAtivo ? (
                            <>
                              <div className="flex items-center gap-1.5">
                                <button
                                  onClick={() => {
                                    setEditingVehicle(veiculo)
                                    setIsVehicleModalOpen(true)
                                  }}
                                  className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-gray-100 text-gray-700 hover:bg-gray-200 transition-colors cursor-pointer"
                                >
                                  Editar
                                </button>
                                <button
                                  onClick={() => setCorrectingVehicle(veiculo)}
                                  className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-amber-50 text-amber-700 border border-amber-200 hover:bg-amber-100 transition-colors cursor-pointer"
                                  title="Corrigir erro material de digitação na placa"
                                >
                                  Corrigir placa
                                </button>
                              </div>

                              <div>
                                <button
                                  onClick={() => setInactivatingVehicle(veiculo)}
                                  className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-red-50 text-red-700 border border-red-200 hover:bg-red-100 transition-colors cursor-pointer"
                                >
                                  Inativar
                                </button>
                              </div>
                            </>
                          ) : (
                            <div className="w-full flex justify-end">
                              <button
                                onClick={() => setReactivatingVehicle(veiculo)}
                                className="px-3 py-1.5 text-xs font-semibold rounded-lg bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors cursor-pointer"
                              >
                                Reativar
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>
          </div>
        )}

        {/* 4. PETS */}
        {activeTab === 'pets' && (
          <div className="space-y-6">
            {/* Aviso discreto caso o morador esteja com acesso bloqueado */}
            {isBlocked && (
              <div className="bg-amber-50/80 border border-amber-200/90 rounded-xl p-3.5 flex items-center gap-3">
                <Lock size={16} className="text-amber-700 shrink-0" />
                <p className="text-xs text-amber-800">
                  <strong className="font-semibold">Morador com acesso administrativo bloqueado:</strong> Os pets cadastrados permanecem vinculados e visíveis para a administração do condomínio.
                </p>
              </div>
            )}

            {/* Aviso para morador inativo */}
            {isInactive && (
              <div className="bg-zinc-100 border border-zinc-200 rounded-xl p-3.5 flex items-center gap-3">
                <Info size={16} className="text-zinc-600 shrink-0" />
                <p className="text-xs text-zinc-700">
                  <strong className="font-semibold">Morador inativo:</strong> Exibindo pets históricos cadastrados. Para cadastrar novos pets, o morador deve possuir um vínculo residencial ativo.
                </p>
              </div>
            )}

            {/* Erro de consulta na base de pets */}
            {petsError && (
              <div className="bg-red-50 border border-red-200 rounded-xl p-3.5 flex items-center gap-3">
                <AlertCircle size={16} className="text-red-600 shrink-0" />
                <p className="text-xs text-red-700 font-medium">
                  {petsError}
                </p>
              </div>
            )}

            {/* Cabeçalho da aba de pets */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                  <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
                    <PawPrint size={18} className="text-[#FC5931]" />
                    Animais de Estimação (Pets) {petsError ? '' : `(${pets.length})`}
                  </h2>
                  <p className="text-xs text-gray-500 mt-1">
                    Animais de estimação cadastrados e vinculados a este morador para identificação e convivência.
                  </p>
                </div>

                <button
                  onClick={() => {
                    setEditingPet(null)
                    setIsPetModalOpen(true)
                  }}
                  className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-semibold bg-[#FC5931] text-white hover:bg-[#e04820] shadow-sm transition-all self-start sm:self-auto cursor-pointer"
                >
                  <PlusCircle size={15} />
                  + Adicionar Pet
                </button>
              </div>

              {/* Lista ou Estado Vazio / Erro */}
              {petsError ? (
                <div className="py-12 text-center max-w-md mx-auto">
                  <div className="w-16 h-16 rounded-2xl bg-red-50 mx-auto flex items-center justify-center mb-4">
                    <AlertCircle size={32} className="text-red-500" />
                  </div>
                  <h3 className="text-base font-bold text-gray-900 mb-1">Erro na consulta de pets</h3>
                  <p className="text-xs text-gray-500">
                    Ocorreu uma falha ao consultar o banco de dados. Recarregue a página ou contate o administrador do sistema.
                  </p>
                </div>
              ) : pets.length === 0 ? (
                <div className="py-12 text-center max-w-md mx-auto">
                  <div className="w-16 h-16 rounded-2xl bg-orange-50 mx-auto flex items-center justify-center mb-4">
                    <PawPrint size={32} className="text-[#FC5931]" />
                  </div>
                  <h3 className="text-base font-bold text-gray-900 mb-1">Nenhum pet cadastrado.</h3>
                  <p className="text-xs text-gray-500 mb-6">
                    Cadastre os animais de estimação deste morador para identificação e controle no condomínio.
                  </p>
                  <button
                    onClick={() => {
                      setEditingPet(null)
                      setIsPetModalOpen(true)
                    }}
                    className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-semibold bg-[#FC5931] text-white hover:bg-[#e04820] shadow-sm transition-all cursor-pointer"
                  >
                    <PlusCircle size={15} />
                    + Adicionar Pet
                  </button>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mt-6">
                  {pets.map((pet) => {
                    const isAtivo = pet.status === 'ativo'
                    const activeUnitsCount = unitLinks.filter(u => u.status === 'ativo').length
                    const canTransfer = isAtivo && activeUnitsCount > 1

                    return (
                      <div
                        key={pet.id}
                        className={`rounded-2xl border p-5 transition-all flex flex-col justify-between ${
                          isAtivo
                            ? 'bg-white border-gray-200/90 shadow-sm hover:border-[#FC5931]/30 hover:shadow-md'
                            : 'bg-zinc-50/80 border-zinc-200 text-zinc-500 shadow-none'
                        }`}
                      >
                        <div className="space-y-3">
                          {/* Linha Superior: Nome e Badge de Status */}
                          <div className="flex items-center justify-between gap-2">
                            <h3 className={`font-bold text-base leading-tight flex items-center gap-1.5 ${isAtivo ? 'text-gray-900' : 'text-zinc-600'}`}>
                              <span>🐾</span>
                              <span>{pet.nome}</span>
                            </h3>

                            {/* Status */}
                            {isAtivo ? (
                              <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                                ATIVO
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-zinc-100 text-zinc-600 border border-zinc-200">
                                <span className="w-1.5 h-1.5 rounded-full bg-zinc-400" />
                                INATIVO
                              </span>
                            )}
                          </div>

                          {/* Foto e Informações Principais do Pet */}
                          <div className="flex items-start gap-3.5 pt-1">
                            {/* Miniatura ou Fallback */}
                            <div className="relative shrink-0 group">
                              {pet.foto_signed_url ? (
                                <button
                                  type="button"
                                  onClick={() => setViewingPhoto({ url: pet.foto_signed_url!, title: `Pet: ${pet.nome}` })}
                                  className="block relative overflow-hidden rounded-xl border border-gray-200 shadow-xs cursor-pointer hover:border-[#FC5931] transition-all group"
                                  title="Clique para ampliar a foto do pet"
                                >
                                  <img
                                    src={pet.foto_signed_url}
                                    alt={`Pet ${pet.nome}`}
                                    className="w-20 h-20 object-cover"
                                  />
                                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-white">
                                    <Eye size={16} />
                                  </div>
                                </button>
                              ) : pet.foto_path ? (
                                <div
                                  className="w-20 h-20 rounded-xl bg-amber-50 border border-amber-200 text-amber-600 flex flex-col items-center justify-center p-1 text-center"
                                  title="Foto vinculada no banco mas temporariamente inacessível"
                                >
                                  <AlertCircle size={18} />
                                  <span className="text-[9px] font-semibold mt-0.5 leading-tight">Foto indisponível</span>
                                </div>
                              ) : (
                                <div className="w-20 h-20 rounded-xl bg-gray-50 border border-dashed border-gray-200 flex flex-col items-center justify-center text-gray-400">
                                  <PawPrint size={24} className="text-gray-300" />
                                  <span className="text-[9px] font-medium text-gray-400 mt-0.5">Sem foto</span>
                                </div>
                              )}
                            </div>

                            {/* Espécie, Raça e Ações de Mídia */}
                            <div className="min-w-0 flex-1">
                              <p className="text-xs font-semibold text-gray-700">
                                {formatEspecie(pet.especie)} {pet.raca ? `• ${pet.raca}` : '• SRD'}
                              </p>
                              <p className="text-xs text-gray-500 mt-0.5">
                                {pet.sexo === 'macho' ? 'Macho' : pet.sexo === 'femea' ? 'Fêmea' : 'Sexo: Não informado'}
                                {' • '}
                                {formatPorte(pet.porte)}
                              </p>
                              {pet.cor && (
                                <p className="text-xs text-gray-500 mt-0.5 truncate">
                                  Cor: {pet.cor}
                                </p>
                              )}

                              {/* Ações contextuais de foto (apenas para pet ativo) */}
                              {isAtivo && (
                                <div className="flex items-center gap-2 mt-2 pt-1 border-t border-gray-100/60">
                                  {!pet.foto_path ? (
                                    <button
                                      type="button"
                                      onClick={() => setPhotoUploadTarget({
                                        type: 'pet',
                                        id: pet.id,
                                        name: pet.nome,
                                        condoId: pet.condominio_id,
                                        currentPhotoPath: null,
                                      })}
                                      className="inline-flex items-center gap-1 text-[11px] font-semibold text-[#FC5931] hover:text-[#e04820] hover:underline cursor-pointer"
                                    >
                                      <Camera size={12} />
                                      Adicionar foto
                                    </button>
                                  ) : (
                                    <>
                                      <button
                                        type="button"
                                        onClick={() => setPhotoUploadTarget({
                                          type: 'pet',
                                          id: pet.id,
                                          name: pet.nome,
                                          condoId: pet.condominio_id,
                                          currentPhotoPath: pet.foto_path,
                                        })}
                                        className="inline-flex items-center gap-1 text-[11px] font-semibold text-gray-600 hover:text-gray-900 hover:underline cursor-pointer"
                                      >
                                        <Camera size={12} />
                                        Alterar foto
                                      </button>
                                      <span className="text-gray-300 text-xs">·</span>
                                      <button
                                        type="button"
                                        onClick={() => setPhotoRemoveTarget({
                                          type: 'pet',
                                          id: pet.id,
                                          name: pet.nome,
                                          condoId: pet.condominio_id,
                                          currentPhotoPath: pet.foto_path!,
                                        })}
                                        className="inline-flex items-center gap-1 text-[11px] font-semibold text-red-600 hover:text-red-700 hover:underline cursor-pointer"
                                      >
                                        <Trash2 size={12} />
                                        Remover foto
                                      </button>
                                    </>
                                  )}
                                </div>
                              )}
                            </div>
                          </div>

                          {/* Informações Complementares */}
                          <div className="p-2.5 rounded-xl bg-gray-50/80 border border-gray-100/80 text-[11px] space-y-1 text-gray-600">
                            <div>
                              Nascimento: <span className="font-medium text-gray-800">{pet.data_nascimento ? formatDateCivil(pet.data_nascimento) : 'Não informado'}</span>
                            </div>
                            <div className="flex items-center gap-3">
                              <span>
                                Vacinado: <strong className={pet.vacinado === true ? 'text-emerald-700' : pet.vacinado === false ? 'text-amber-700' : 'text-gray-500'}>
                                  {pet.vacinado === true ? 'Sim' : pet.vacinado === false ? 'Não' : 'Não informado'}
                                </strong>
                              </span>
                              <span>•</span>
                              <span>
                                Castrado: <strong className={pet.castrado === true ? 'text-emerald-700' : pet.castrado === false ? 'text-amber-700' : 'text-gray-500'}>
                                  {pet.castrado === true ? 'Sim' : pet.castrado === false ? 'Não' : 'Não informado'}
                                </strong>
                              </span>
                            </div>
                          </div>

                          {/* Unidade */}
                          {(pet.unidade_bloco || pet.unidade_apto) && (
                            <div className="text-[11px] text-gray-500">
                              Unidade: <span className="font-semibold text-gray-700">{blocoLabel} {pet.unidade_bloco || '—'} · {aptoLabel} {pet.unidade_apto || '—'}</span>
                            </div>
                          )}

                          {/* Observação se houver */}
                          {pet.observacao && (
                            <p className="text-xs text-gray-500 italic bg-gray-50/80 p-2.5 rounded-xl border border-gray-100 line-clamp-2">
                              "{pet.observacao}"
                            </p>
                          )}
                        </div>

                        {/* Ações Administrativas */}
                        <div className="pt-4 mt-4 border-t border-gray-100 flex items-center justify-between gap-2 flex-wrap">
                          {isAtivo ? (
                            <>
                              <div className="flex items-center gap-1.5 flex-wrap">
                                <button
                                  onClick={() => {
                                    setEditingPet(pet)
                                    setIsPetModalOpen(true)
                                  }}
                                  className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-gray-100 text-gray-700 hover:bg-gray-200 transition-colors cursor-pointer"
                                >
                                  Editar
                                </button>
                                {canTransfer && (
                                  <button
                                    onClick={() => setTransferringPet(pet)}
                                    className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-orange-50 text-[#FC5931] border border-orange-200 hover:bg-orange-100 transition-colors cursor-pointer"
                                    title="Alterar unidade residencial do pet"
                                  >
                                    Alterar unidade
                                  </button>
                                )}
                              </div>

                              <div>
                                <button
                                  onClick={() => setInactivatingPet(pet)}
                                  className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-red-50 text-red-700 border border-red-200 hover:bg-red-100 transition-colors cursor-pointer"
                                >
                                  Inativar
                                </button>
                              </div>
                            </>
                          ) : (
                            <div className="w-full flex justify-end">
                              <button
                                onClick={() => setReactivatingPet(pet)}
                                className="px-3 py-1.5 text-xs font-semibold rounded-lg bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors cursor-pointer"
                              >
                                Reativar
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>
          </div>
        )}

        {/* 5. FAMÍLIA */}
        {activeTab === 'familia' && (
          <div className="space-y-6">
            {/* ── DEPENDENTES ── */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
                    <Heart size={18} className="text-[#FC5931]" />
                    Dependentes
                  </h2>
                  <p className="text-xs text-gray-500 mt-1">
                    Pessoas vinculadas como dependentes deste morador.
                  </p>
                  {/* Gate 3G.4-D1: Indicador de ocupação da unidade */}
                  {activeUnit?.unidade_id && (
                    <div className="flex items-center gap-2 mt-2">
                      <span className={`text-xs font-semibold px-2.5 py-1 rounded-lg ${
                        limiteAtingido
                          ? 'bg-red-50 text-red-700 border border-red-200'
                          : ocupacaoAtual >= 3
                            ? 'bg-amber-50 text-amber-700 border border-amber-200'
                            : 'bg-gray-50 text-gray-600 border border-gray-200'
                      }`}>
                        Ocupação da unidade: {ocupacaoAtual} / {MAX_OCUPANTES_UNIDADE} pessoas
                      </span>
                      {limiteAtingido && (
                        <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-red-100 text-red-700 border border-red-200">
                          Limite atingido
                        </span>
                      )}
                    </div>
                  )}
                </div>
                {activeUnit?.unidade_id && (
                  <button
                    onClick={() => {
                      if (limiteAtingido) return
                      setEditingDependente(null)
                      setIsDependentModalOpen(true)
                    }}
                    disabled={limiteAtingido}
                    title={limiteAtingido ? 'Esta unidade já atingiu o limite de 4 pessoas.' : 'Adicionar um novo dependente'}
                    className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold transition-all shadow-sm ${
                      limiteAtingido
                        ? 'text-gray-400 bg-gray-100 border border-gray-200 cursor-not-allowed'
                        : 'text-white bg-[#FC5931] hover:bg-[#FC5931]/90'
                    }`}
                  >
                    <PlusCircle size={14} />
                    Adicionar dependente
                  </button>
                )}
              </div>

              {dependentesError ? (
                <div className="p-3.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2.5 text-xs text-red-700">
                  <AlertCircle size={16} className="text-red-500 shrink-0 mt-0.5" />
                  <div className="flex-1 font-medium">{dependentesError}</div>
                </div>
              ) : !activeUnit?.unidade_id ? (
                <div className="p-3.5 bg-amber-50 border border-amber-200 rounded-xl flex items-start gap-2.5 text-xs text-amber-800">
                  <AlertCircle size={16} className="text-amber-600 shrink-0 mt-0.5" />
                  <div>
                    <strong>Sem unidade ativa.</strong> Este morador não possui vínculo residencial ativo no condomínio. Cadastre ou aprove um vínculo de moradia antes de adicionar dependentes.
                  </div>
                </div>
              ) : dependentes.length === 0 ? (
                <div className="text-center py-8 text-gray-400 text-xs">
                  <Heart size={28} className="mx-auto mb-2 text-gray-300" />
                  Nenhum dependente cadastrado.
                </div>
              ) : (
                <div className="space-y-3">
                  {dependentes.map(dep => {
                    const parentescoMap: Record<string, string> = {
                      filho: 'Filho(a)',
                      conjuge_companheiro: 'Cônjuge / Companheiro(a)',
                      pai_mae: 'Pai / Mãe',
                      enteado: 'Enteado(a)',
                      outro_familiar: 'Outro familiar',
                      outro_dependente: 'Outro dependente',
                    }
                    const parentescoLabel = dep.parentesco ? (parentescoMap[dep.parentesco] || dep.parentesco) : '—'

                    // Format date of birth as pt-BR civil date (avoid timezone shift)
                    let dataNascFormatted = '—'
                    let idadeStr = ''
                    if (dep.data_nascimento) {
                      const parts = dep.data_nascimento.split('T')[0].split('-')
                      if (parts.length === 3) {
                        const [yearStr, monthStr, dayStr] = parts
                        const year = parseInt(yearStr, 10)
                        const month = parseInt(monthStr, 10)
                        const day = parseInt(dayStr, 10)
                        dataNascFormatted = `${String(day).padStart(2, '0')}/${String(month).padStart(2, '0')}/${year}`

                        // Calculate age
                        const today = new Date()
                        let age = today.getFullYear() - year
                        const monthDiff = (today.getMonth() + 1) - month
                        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < day)) {
                          age--
                        }
                        if (age >= 0) {
                          idadeStr = age === 1 ? '1 ano' : `${age} anos`
                        }
                      }
                    }

                    const isDepActive = dep.status === 'ativo'
                    const isDepConverted = dep.perfil_convertido_id != null
                    const canEdit = isDepActive && !isDepConverted
                    const isRespInactive = resident.status_aprovacao === 'inativo'
                    const hasActiveUnit = Boolean(activeUnit?.unidade_id)
                    const canManagePhoto = isDepActive && !isRespInactive && hasActiveUnit

                    const depInitials = (dep.nome_completo || 'D')
                      .split(' ')
                      .filter(Boolean)
                      .slice(0, 2)
                      .map(n => n[0])
                      .join('')
                      .toUpperCase()

                    return (
                      <div
                        key={dep.id}
                        className={`p-4 rounded-xl border transition-all ${
                          isDepActive
                            ? 'border-gray-100 bg-white'
                            : 'border-gray-100 bg-gray-50/50 opacity-75'
                        }`}
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex items-start gap-3.5 min-w-0 flex-1">
                            {/* Avatar / Miniatura da Foto à Esquerda */}
                            <div className="relative shrink-0">
                              {dep.foto_signed_url ? (
                                <button
                                  type="button"
                                  onClick={() => setViewingPhoto({
                                    url: dep.foto_signed_url!,
                                    title: `Dependente: ${dep.nome_completo}`
                                  })}
                                  className="block relative w-14 h-14 rounded-xl overflow-hidden border border-gray-200 shadow-xs cursor-pointer hover:border-[#FC5931] transition-all group"
                                  title="Clique para ampliar a foto do dependente"
                                >
                                  <img
                                    src={dep.foto_signed_url}
                                    alt={dep.nome_completo}
                                    className="w-full h-full object-cover"
                                  />
                                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-white">
                                    <Eye size={16} />
                                  </div>
                                </button>
                              ) : (
                                <div className="w-14 h-14 rounded-xl bg-orange-50/60 border border-dashed border-orange-200 text-[#FC5931] flex flex-col items-center justify-center shrink-0">
                                  {depInitials ? (
                                    <span className="text-xs font-bold text-[#FC5931]">{depInitials}</span>
                                  ) : (
                                    <Users size={18} className="text-[#FC5931]" />
                                  )}
                                  <span className="text-[8px] font-medium text-gray-400 mt-0.5">Sem foto</span>
                                </div>
                              )}
                            </div>

                            {/* Informações Principais do Dependente */}
                            <div className="min-w-0 flex-1">
                              <div className="flex items-center gap-2 flex-wrap">
                                <p className="font-semibold text-sm text-gray-900">
                                  {dep.nome_completo}
                                </p>
                                <span className={`text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full ${
                                  isDepActive
                                    ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                    : 'bg-gray-100 text-gray-500 border border-gray-200'
                                }`}>
                                  {isDepActive ? 'Ativo' : 'Inativo'}
                                </span>
                                {isDepConverted && (
                                  <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 border border-blue-200">
                                    Cadastro convertido
                                  </span>
                                )}
                              </div>
                              <p className="text-xs text-gray-500 mt-1">
                                {parentescoLabel}
                                {dataNascFormatted !== '—' && (
                                  <> · Nascimento: {dataNascFormatted}{idadeStr && <> ({idadeStr})</>}</>
                                )}
                              </p>
                              {dep.observacao && (
                                <p className="text-xs text-gray-400 mt-1 italic truncate max-w-md">
                                  {dep.observacao}
                                </p>
                              )}

                              {/* Ações contextuais de foto */}
                              <div className="flex items-center gap-2 mt-2 pt-1.5 border-t border-gray-100">
                                {canManagePhoto ? (
                                  !dep.foto_path ? (
                                    <button
                                      type="button"
                                      onClick={() => setPhotoUploadTarget({
                                        type: 'dependente',
                                        id: dep.id,
                                        name: dep.nome_completo,
                                        condoId: dep.condominio_id,
                                        currentPhotoPath: null,
                                      })}
                                      className="inline-flex items-center gap-1 text-[11px] font-semibold text-[#FC5931] hover:text-[#e04820] hover:underline cursor-pointer"
                                    >
                                      <Camera size={12} />
                                      Adicionar foto
                                    </button>
                                  ) : (
                                    <>
                                      <button
                                        type="button"
                                        onClick={() => setPhotoUploadTarget({
                                          type: 'dependente',
                                          id: dep.id,
                                          name: dep.nome_completo,
                                          condoId: dep.condominio_id,
                                          currentPhotoPath: dep.foto_path,
                                        })}
                                        className="inline-flex items-center gap-1 text-[11px] font-semibold text-gray-600 hover:text-gray-900 hover:underline cursor-pointer"
                                      >
                                        <Camera size={12} />
                                        Alterar foto
                                      </button>
                                      <span className="text-gray-300">·</span>
                                      <button
                                        type="button"
                                        onClick={() => setPhotoRemoveTarget({
                                          type: 'dependente',
                                          id: dep.id,
                                          name: dep.nome_completo,
                                          condoId: dep.condominio_id,
                                          currentPhotoPath: dep.foto_path!,
                                        })}
                                        className="inline-flex items-center gap-1 text-[11px] font-semibold text-red-600 hover:text-red-700 hover:underline cursor-pointer"
                                      >
                                        <Trash2 size={12} />
                                        Remover foto
                                      </button>
                                    </>
                                  )
                                ) : (
                                  <span className="text-[11px] text-zinc-400 font-medium">
                                    Cadastro histórico protegido.
                                  </span>
                                )}
                              </div>
                            </div>
                          </div>
                          {canEdit && (
                            <div className="flex items-center gap-1.5 shrink-0">
                              <button
                                onClick={() => {
                                  setEditingDependente(dep)
                                  setIsDependentModalOpen(true)
                                }}
                                className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[11px] font-semibold text-gray-600 hover:text-[#FC5931] hover:bg-orange-50 transition-colors border border-gray-200 hover:border-[#FC5931]/30"
                              >
                                <Edit2 size={12} />
                                Editar
                              </button>
                              <button
                                onClick={() => setInactivatingDependente(dep)}
                                className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[11px] font-semibold text-gray-600 hover:text-red-600 hover:bg-red-50 transition-colors border border-gray-200 hover:border-red-300"
                              >
                                Inativar
                              </button>
                              <button
                                onClick={() => setTransferringDependente(dep)}
                                className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[11px] font-semibold text-gray-600 hover:text-blue-600 hover:bg-blue-50 transition-colors border border-gray-200 hover:border-blue-300"
                              >
                                <ArrowRightLeft size={12} />
                                Trocar responsável
                              </button>
                            </div>
                          )}
                          {!isDepConverted && !isDepActive && (
                            <button
                              onClick={() => {
                                if (limiteAtingido) return
                                setReactivatingDependente(dep)
                              }}
                              disabled={limiteAtingido}
                              title={limiteAtingido ? 'Sem vaga disponível na unidade.' : 'Reativar este dependente'}
                              className={`inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[11px] font-semibold transition-colors border shrink-0 ${
                                limiteAtingido
                                  ? 'text-gray-400 bg-gray-50 border-gray-200 cursor-not-allowed'
                                  : 'text-gray-600 hover:text-emerald-600 hover:bg-emerald-50 border-gray-200 hover:border-emerald-300'
                              }`}
                            >
                              <RefreshCw size={12} />
                              Reativar
                            </button>
                          )}
                        </div>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>

            {/* ── MORADORES DA MESMA UNIDADE ── */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <div className="mb-4">
                <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
                  <Users size={18} className="text-[#FC5931]" />
                  Moradores da Mesma Unidade
                </h2>
                <p className="text-xs text-gray-500 mt-1">
                  Exibindo cadastros que compartilham a mesma unidade física ({formattedUnit}).
                </p>
              </div>

              {/* Grid of co-residents */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                {/* Current resident card */}
                <div className="p-4 rounded-xl border-2 border-[#FC5931]/30 bg-orange-50/20 relative">
                  <span className="absolute top-3 right-3 text-[10px] font-bold uppercase tracking-wider text-[#FC5931] bg-[#FC5931]/10 px-2 py-0.5 rounded-full">
                    Este Cadastro
                  </span>
                  <div className="flex items-center gap-3">
                    <div className={`w-11 h-11 rounded-full flex items-center justify-center shadow-xs bg-gradient-to-br ${avatarGrad}`}>
                      <span className="text-white text-sm font-bold">{initials}</span>
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="font-semibold text-sm text-gray-900 truncate">{resident.nome_completo}</p>
                      <p className="text-xs text-gray-500 mt-0.5">{resident.tipo_morador || resident.papel_sistema || 'Morador'}</p>
                    </div>
                  </div>
                </div>

                {/* Other residents in same unit */}
                {coResidents.map(co => {
                  const coInitials = getInitials(co.nome_completo)
                  const coGrad = getAvatarColor(co.id)
                  return (
                    <div
                      key={co.id}
                      onClick={() => router.push(`/admin/moradores/${co.id}`)}
                      className="p-4 rounded-xl border border-gray-100 hover:border-gray-300 hover:shadow-sm transition-all bg-white cursor-pointer group"
                    >
                      <div className="flex items-center gap-3">
                        <div className={`w-11 h-11 rounded-full flex items-center justify-center shadow-xs bg-gradient-to-br ${coGrad}`}>
                          <span className="text-white text-sm font-bold">{coInitials}</span>
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="font-semibold text-sm text-gray-900 truncate group-hover:text-[#FC5931] transition-colors">
                            {co.nome_completo || 'Sem nome'}
                          </p>
                          <p className="text-xs text-gray-500 mt-0.5">{co.tipo_morador || co.papel_sistema || 'Morador'}</p>
                        </div>
                        <ChevronRight size={16} className="text-gray-300 group-hover:text-[#FC5931] transition-colors" />
                      </div>
                    </div>
                  )
                })}
              </div>

              {coResidents.length === 0 && (
                <p className="text-xs text-gray-400 mt-4 text-center">
                  Nenhum outro morador está atualmente associado a esta mesma unidade no sistema.
                </p>
              )}
            </div>
          </div>
        )}

        {/* 6. ACESSOS */}
        {activeTab === 'acessos' && (
          <div className="space-y-6">
            {/* Convites Emitidos */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <h2 className="text-base font-bold text-gray-900 mb-4 flex items-center gap-2">
                <KeyRound size={18} className="text-[#FC5931]" />
                Convites Emitidos pelo Morador
              </h2>

              {convites.length > 0 ? (
                <>
                  <div className="space-y-3">
                    {paginatedConvites.map(c => {
                      const validadeFormatted = c.validity_date
                        ? (/^\d{4}-\d{2}-\d{2}$/.test(c.validity_date.trim())
                            ? formatDateCivil(c.validity_date)
                            : formatDateTime(c.validity_date))
                        : c.valid_until
                        ? formatDateTime(c.valid_until)
                        : null

                      return (
                        <div
                          key={c.id}
                          className="p-4 rounded-xl border border-gray-100 bg-white hover:border-gray-200 transition-all space-y-3"
                        >
                          {/* Header: Visitante Name, Visitor Type, Comparecimento & Status */}
                          <div className="flex items-start justify-between gap-3 flex-wrap">
                            <div className="min-w-0">
                              <div className="flex items-center gap-2 flex-wrap">
                                <p className="font-semibold text-sm text-gray-900">
                                  {c.guest_name || 'Visitante sem nome'}
                                </p>
                                {c.visitor_type && (
                                  <span className="text-[11px] font-medium px-2 py-0.5 rounded-md bg-gray-100 text-gray-600">
                                    {c.visitor_type}
                                  </span>
                                )}
                              </div>
                            </div>

                            {/* Badges de Status e Comparecimento */}
                            <div className="flex items-center gap-2 flex-wrap">
                              {c.visitante_compareceu === true && (
                                <span className="inline-flex items-center gap-1 text-[11px] font-semibold px-2.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                                  <CheckCircle size={12} />
                                  Compareceu
                                </span>
                              )}
                              {c.visitante_compareceu === false && (
                                <span className="text-[11px] font-medium px-2.5 py-0.5 rounded-full bg-gray-100 text-gray-600 border border-gray-200">
                                  Não compareceu
                                </span>
                              )}
                              {c.status && (
                                <span className="text-xs px-2.5 py-0.5 rounded-full font-medium bg-gray-100 text-gray-700 border border-gray-200">
                                  {c.status}
                                </span>
                              )}
                            </div>
                          </div>

                          {/* Datas: Criação, Validade, Liberação */}
                          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-2 text-xs text-gray-500 pt-1">
                            {c.created_at && (
                              <div className="flex items-center gap-1.5">
                                <Clock size={13} className="text-gray-400 shrink-0" />
                                <span>Criado: <strong className="text-gray-700 font-medium">{formatDateTime(c.created_at)}</strong></span>
                              </div>
                            )}
                            {validadeFormatted && (
                              <div className="flex items-center gap-1.5">
                                <Calendar size={13} className="text-gray-400 shrink-0" />
                                <span>Validade: <strong className="text-gray-700 font-medium">{validadeFormatted}</strong></span>
                              </div>
                            )}
                            {c.liberado_em && (
                              <div className="flex items-center gap-1.5">
                                <CheckCircle size={13} className="text-emerald-500 shrink-0" />
                                <span>Liberado: <strong className="text-gray-700 font-medium">{formatDateTime(c.liberado_em)}</strong></span>
                              </div>
                            )}
                          </div>

                          {/* Dados adicionais se disponíveis: Placa, Documento, WhatsApp, Crachá/Ref */}
                          {(c.placa || c.documento || c.whatsapp || c.cracha_referencia) && (
                            <div className="flex items-center gap-4 flex-wrap text-xs text-gray-600 pt-1 border-t border-gray-50">
                              {c.placa && (
                                <div className="flex items-center gap-1.5">
                                  <Car size={13} className="text-gray-400 shrink-0" />
                                  <span>Placa: <strong className="text-gray-800 font-semibold">{c.placa}</strong></span>
                                </div>
                              )}
                              {c.documento && (
                                <div className="flex items-center gap-1.5">
                                  <Shield size={13} className="text-gray-400 shrink-0" />
                                  <span>Documento: <strong className="text-gray-800 font-medium">{c.documento}</strong></span>
                                </div>
                              )}
                              {c.whatsapp && (
                                <div className="flex items-center gap-1.5">
                                  <Phone size={13} className="text-gray-400 shrink-0" />
                                  <span>WhatsApp: <strong className="text-gray-800 font-medium">{c.whatsapp}</strong></span>
                                </div>
                              )}
                              {c.cracha_referencia && (
                                <div className="flex items-center gap-1.5">
                                  <KeyRound size={13} className="text-gray-400 shrink-0" />
                                  <span>Crachá / Ref: <strong className="text-gray-800 font-medium">{c.cracha_referencia}</strong></span>
                                </div>
                              )}
                            </div>
                          )}

                          {/* Observação se houver */}
                          {c.observacao && (
                            <p className="text-xs text-gray-500 italic bg-gray-50/80 p-2.5 rounded-xl border border-gray-100">
                              "{c.observacao}"
                            </p>
                          )}
                        </div>
                      )
                    })}
                  </div>

                  {/* Controle de Paginação (quando houver mais de 5 convites) */}
                  {convites.length > CONVITES_PAGE_SIZE && (
                    <div className="flex items-center justify-between pt-4 mt-2 border-t border-gray-100 text-xs">
                      <button
                        type="button"
                        onClick={() => setConvitesPage(prev => Math.max(1, prev - 1))}
                        disabled={convitesPage <= 1}
                        className={`px-3 py-1.5 rounded-lg font-semibold transition-all ${
                          convitesPage <= 1
                            ? 'bg-gray-100 text-gray-400 cursor-not-allowed border border-gray-200'
                            : 'bg-white text-gray-700 hover:bg-gray-50 border border-gray-200 shadow-sm hover:text-[#FC5931]'
                        }`}
                      >
                        Anterior
                      </button>

                      <span className="text-gray-500 font-medium">
                        Página {convitesPage} de {serverConvitesTotalPages}
                      </span>

                      <button
                        type="button"
                        onClick={() => setConvitesPage(prev => Math.min(serverConvitesTotalPages, prev + 1))}
                        disabled={convitesPage >= serverConvitesTotalPages}
                        className={`px-3 py-1.5 rounded-lg font-semibold transition-all ${
                          convitesPage >= serverConvitesTotalPages
                            ? 'bg-gray-100 text-gray-400 cursor-not-allowed border border-gray-200'
                            : 'bg-white text-gray-700 hover:bg-gray-50 border border-gray-200 shadow-sm hover:text-[#FC5931]'
                        }`}
                      >
                        Próxima
                      </button>
                    </div>
                  )}
                </>
              ) : (
                <div className="text-center py-8 text-gray-400 text-xs">
                  <KeyRound size={28} className="mx-auto mb-2 text-gray-300" />
                  Nenhum convite emitido recentemente por este morador.
                </div>
              )}
            </div>

            {/* Registros de Portaria */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <h2 className="text-base font-bold text-gray-900 mb-4 flex items-center gap-2">
                <Building2 size={18} className="text-[#FC5931]" />
                Registros de Entrada na Portaria para a Unidade
              </h2>

              {portariaRegistros.length > 0 ? (
                <>
                  <div className="space-y-3">
                    {paginatedPortariaRegistros.map(r => {
                      const isPresente = !r.saida_at

                      return (
                        <div
                          key={r.id}
                          className="p-4 rounded-xl border border-gray-100 bg-white hover:border-gray-200 transition-all space-y-3"
                        >
                          {/* Header: Visitante Name, Visitor Type, Presente/Saída & Status */}
                          <div className="flex items-start justify-between gap-3 flex-wrap">
                            <div className="min-w-0">
                              <div className="flex items-center gap-2 flex-wrap">
                                <p className="font-semibold text-sm text-gray-900">
                                  {r.nome || 'Visitante'}
                                </p>
                                {r.tipo_visitante && (
                                  <span className="text-[11px] font-medium px-2 py-0.5 rounded-md bg-gray-100 text-gray-600">
                                    {r.tipo_visitante}
                                  </span>
                                )}
                              </div>
                            </div>

                            {/* Badges de Presença e Status */}
                            <div className="flex items-center gap-2 flex-wrap">
                              {isPresente ? (
                                <span className="inline-flex items-center gap-1 text-[11px] font-semibold px-2.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                                  Presente
                                </span>
                              ) : (
                                <span className="text-[11px] font-medium px-2.5 py-0.5 rounded-full bg-gray-100 text-gray-600 border border-gray-200">
                                  Saída registrada
                                </span>
                              )}
                              {r.status && (
                                <span className="text-xs px-2.5 py-0.5 rounded-full font-medium bg-gray-100 text-gray-700 border border-gray-200">
                                  {r.status}
                                </span>
                              )}
                            </div>
                          </div>

                          {/* Datas: Entrada e Saída */}
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs text-gray-500 pt-1">
                            {r.entrada_at && (
                              <div className="flex items-center gap-1.5">
                                <Clock size={13} className="text-gray-400 shrink-0" />
                                <span>Entrada: <strong className="text-gray-700 font-medium">{formatDateTime(r.entrada_at)}</strong></span>
                              </div>
                            )}
                            {r.saida_at && (
                              <div className="flex items-center gap-1.5">
                                <Clock size={13} className="text-gray-400 shrink-0" />
                                <span>Saída: <strong className="text-gray-700 font-medium">{formatDateTime(r.saida_at)}</strong></span>
                              </div>
                            )}
                          </div>

                          {/* Dados adicionais se disponíveis: Placa e Documento */}
                          {(r.placa || r.documento) && (
                            <div className="flex items-center gap-4 flex-wrap text-xs text-gray-600 pt-1 border-t border-gray-50">
                              {r.placa && (
                                <div className="flex items-center gap-1.5">
                                  <Car size={13} className="text-gray-400 shrink-0" />
                                  <span>Placa: <strong className="text-gray-800 font-semibold">{r.placa}</strong></span>
                                </div>
                              )}
                              {r.documento && (
                                <div className="flex items-center gap-1.5">
                                  <Shield size={13} className="text-gray-400 shrink-0" />
                                  <span>Documento: <strong className="text-gray-800 font-medium">{r.documento}</strong></span>
                                </div>
                              )}
                            </div>
                          )}

                          {/* Observação se houver */}
                          {r.observacao && (
                            <p className="text-xs text-gray-500 italic bg-gray-50/80 p-2.5 rounded-xl border border-gray-100">
                              "{r.observacao}"
                            </p>
                          )}
                        </div>
                      )
                    })}
                  </div>

                  {/* Controle de Paginação (quando houver mais de 5 registros) */}
                  {portariaRegistros.length > PORTARIA_PAGE_SIZE && (
                    <div className="flex items-center justify-between pt-4 mt-2 border-t border-gray-100 text-xs">
                      <button
                        type="button"
                        onClick={() => setPortariaPage(prev => Math.max(1, prev - 1))}
                        disabled={portariaPage <= 1}
                        className={`px-3 py-1.5 rounded-lg font-semibold transition-all ${
                          portariaPage <= 1
                            ? 'bg-gray-100 text-gray-400 cursor-not-allowed border border-gray-200'
                            : 'bg-white text-gray-700 hover:bg-gray-50 border border-gray-200 shadow-sm hover:text-[#FC5931]'
                        }`}
                      >
                        Anterior
                      </button>

                      <span className="text-gray-500 font-medium">
                        Página {portariaPage} de {serverPortariaTotalPages}
                      </span>

                      <button
                        type="button"
                        onClick={() => setPortariaPage(prev => Math.min(serverPortariaTotalPages, prev + 1))}
                        disabled={portariaPage >= serverPortariaTotalPages}
                        className={`px-3 py-1.5 rounded-lg font-semibold transition-all ${
                          portariaPage >= serverPortariaTotalPages
                            ? 'bg-gray-100 text-gray-400 cursor-not-allowed border border-gray-200'
                            : 'bg-white text-gray-700 hover:bg-gray-50 border border-gray-200 shadow-sm hover:text-[#FC5931]'
                        }`}
                      >
                        Próxima
                      </button>
                    </div>
                  )}
                </>
              ) : (
                <div className="text-center py-8 text-gray-400 text-xs">
                  <Building2 size={28} className="mx-auto mb-2 text-gray-300" />
                  Nenhum registro de acesso na portaria direcionado a esta unidade no período.
                </div>
              )}
            </div>
          </div>
        )}

        {/* 7. HISTÓRICO */}
        {activeTab === 'historico' && (
          <div className="space-y-6">
            {/* Ocupação */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <h2 className="text-base font-bold text-gray-900 mb-4 flex items-center gap-2">
                <Clock size={18} className="text-[#FC5931]" />
                Histórico de Ocupação de Unidades
              </h2>

              {unitLinks.length > 0 ? (
                <div className="space-y-3">
                  {unitLinks.map((link, idx) => (
                    <div key={link.id} className="flex items-start gap-3 p-3 rounded-xl bg-gray-50 border border-gray-100">
                      <div className="w-8 h-8 rounded-full bg-white border border-gray-200 flex items-center justify-center text-xs font-bold text-gray-600 shrink-0">
                        {idx + 1}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <p className="font-semibold text-sm text-gray-800">
                            {blocoLabel} {link.bloco_nome || '—'} · {aptoLabel} {link.apto_numero || '—'}
                          </p>
                          <span
                            className={`text-xs px-2 py-0.5 rounded-full font-semibold ${
                              link.status === 'ativo'
                                ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                : 'bg-gray-100 text-gray-600'
                            }`}
                          >
                            {link.status === 'ativo' ? 'Ocupação Atual' : 'Ocupação Anterior'}
                          </span>
                        </div>
                        <p className="text-xs text-gray-500 mt-1">
                          Entrada: {formatDate(link.data_entrada || link.created_at)}
                          {link.data_saida ? ` • Saída: ${formatDate(link.data_saida)}` : ' • Presente'}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-gray-400">Nenhum histórico registrado.</p>
              )}
            </div>

            {/* Audit Log Histórico Administrativo */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Shield size={18} className="text-[#FC5931]" />
                  <h3 className="text-base font-bold text-gray-900">Histórico Administrativo de Alterações</h3>
                </div>
                {auditLogs.length > 0 && (
                  <span className="text-xs font-semibold text-gray-500 bg-gray-100 px-2.5 py-0.5 rounded-full">
                    {auditLogs.length} registro{auditLogs.length !== 1 ? 's' : ''}
                  </span>
                )}
              </div>

              {auditLogs.length > 0 ? (
                <div className="space-y-3">
                  {auditLogs.map((log) => {
                    const post = log.estado_posterior || {}
                    const ant = log.estado_anterior || {}
                    const isResidentApproved = log.acao === 'RESIDENT_APPROVED'
                    const isResidentRejected = log.acao === 'RESIDENT_REJECTED'
                    const isUnitInactivation = log.acao === 'UNIT_INACTIVATED'
                    const isUnitLinkCreated = log.acao === 'UNIT_LINK_CREATED'
                    const isDateCorrected = log.acao === 'UNIT_LINK_ENTRY_DATE_CORRECTED'
                    const isTypeChange = log.acao === 'RESIDENT_TYPE_CHANGED'
                    const isVehicleCreated = log.acao === 'VEHICLE_CREATED'
                    const isVehicleUpdated = log.acao === 'VEHICLE_UPDATED'
                    const isVehiclePlateCorrected = log.acao === 'VEHICLE_PLATE_CORRECTED'
                    const isVehicleInactivated = log.acao === 'VEHICLE_INACTIVATED'
                    const isVehicleReactivated = log.acao === 'VEHICLE_REACTIVATED'
                    const isPetCreated = log.acao === 'PET_CREATED'
                    const isPetUpdated = log.acao === 'PET_UPDATED'
                    const isPetInactivated = log.acao === 'PET_INACTIVATED'
                    const isPetReactivated = log.acao === 'PET_REACTIVATED'
                    const isPetUnitChanged = log.acao === 'PET_UNIT_CHANGED'
                    const isVehiclePhotoUpdated = log.acao === 'VEHICLE_PHOTO_UPDATED'
                    const isVehiclePhotoRemoved = log.acao === 'VEHICLE_PHOTO_REMOVED'
                    const isPetPhotoUpdated = log.acao === 'PET_PHOTO_UPDATED'
                    const isPetPhotoRemoved = log.acao === 'PET_PHOTO_REMOVED'

                    return (
                      <div
                        key={log.id}
                        className="p-4 rounded-xl bg-zinc-50 border border-zinc-200/80 space-y-2.5 transition-all hover:bg-zinc-50/90"
                      >
                        <div className="flex items-start justify-between gap-3 flex-wrap">
                          <div className="flex items-center gap-2">
                            {isResidentApproved ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-emerald-50 text-emerald-700 border-emerald-200">
                                <CheckCircle size={12} />
                                Cadastro aprovado
                              </span>
                            ) : isResidentRejected ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-red-50 text-red-700 border-red-200">
                                <XCircle size={12} />
                                Cadastro rejeitado
                              </span>
                            ) : isUnitInactivation ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-red-50 text-red-700 border-red-200">
                                <UserX size={12} />
                                Morador inativado
                              </span>
                            ) : isUnitLinkCreated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-emerald-50 text-emerald-700 border-emerald-200">
                                <PlusCircle size={12} />
                                Novo vínculo residencial
                              </span>
                            ) : isDateCorrected ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-amber-50 text-amber-700 border-amber-200">
                                <Calendar size={12} />
                                Data de entrada corrigida
                              </span>
                            ) : isTypeChange ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-blue-50 text-blue-700 border-blue-200">
                                <Home size={12} />
                                Tipo de morador alterado
                              </span>
                            ) : isVehicleCreated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-emerald-50 text-emerald-700 border-emerald-200">
                                <Car size={12} />
                                Veículo cadastrado
                              </span>
                            ) : isVehicleUpdated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-blue-50 text-blue-700 border-blue-200">
                                <Edit2 size={12} />
                                Dados do veículo atualizados
                              </span>
                            ) : isVehiclePlateCorrected ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-amber-50 text-amber-700 border-amber-200">
                                <KeyRound size={12} />
                                Placa corrigida
                              </span>
                            ) : isVehicleInactivated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-zinc-100 text-zinc-700 border-zinc-200">
                                <Car size={12} />
                                Veículo inativado
                              </span>
                            ) : isVehicleReactivated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-teal-50 text-teal-700 border-teal-200">
                                <RefreshCw size={12} />
                                Veículo reativado
                              </span>
                            ) : isVehiclePhotoUpdated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-teal-50 text-teal-700 border-teal-200">
                                <Camera size={12} />
                                Foto do veículo atualizada
                              </span>
                            ) : isVehiclePhotoRemoved ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-zinc-100 text-zinc-700 border-zinc-200">
                                <Trash2 size={12} />
                                Foto do veículo removida
                              </span>
                            ) : isPetCreated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-emerald-50 text-emerald-700 border-emerald-200">
                                <PawPrint size={12} />
                                Pet cadastrado
                              </span>
                            ) : isPetUpdated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-blue-50 text-blue-700 border-blue-200">
                                <Edit2 size={12} />
                                Dados do pet atualizados
                              </span>
                            ) : isPetInactivated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-zinc-100 text-zinc-700 border-zinc-200">
                                <PawPrint size={12} />
                                Pet inativado
                              </span>
                            ) : isPetReactivated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-teal-50 text-teal-700 border-teal-200">
                                <RefreshCw size={12} />
                                Pet reativado
                              </span>
                            ) : isPetUnitChanged ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-orange-50 text-orange-700 border-orange-200">
                                <ArrowRightLeft size={12} />
                                Unidade do pet alterada
                              </span>
                            ) : isPetPhotoUpdated ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-teal-50 text-teal-700 border-teal-200">
                                <Camera size={12} />
                                Foto do pet atualizada
                              </span>
                            ) : isPetPhotoRemoved ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-zinc-100 text-zinc-700 border-zinc-200">
                                <Trash2 size={12} />
                                Foto do pet removida
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold border bg-zinc-100 text-zinc-700 border-zinc-200">
                                <History size={12} />
                                {log.acao}
                              </span>
                            )}

                            {(log.unidade_bloco || log.unidade_apto) && (
                              <span className="text-xs font-semibold text-gray-700">
                                {blocoLabel} {log.unidade_bloco || '—'} · {aptoLabel} {log.unidade_apto || '—'}
                              </span>
                            )}
                          </div>
                          <span className="text-xs text-gray-400">
                            {formatDateTime(log.created_at)}
                          </span>
                        </div>

                        {/* Motivo amigável */}
                        {log.motivo && (
                          <p className="text-xs text-gray-700">
                            <span className="font-semibold text-gray-800">Motivo:</span> {log.motivo}
                          </p>
                        )}

                        {/* Detalhes específicos amigáveis sem expor JSON bruto */}
                        {isResidentApproved && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Status alterado para: <strong className="text-emerald-700">Aprovado</strong>
                            </p>
                            {ant.status_aprovacao && (
                              <p className="text-gray-500 text-[11px]">
                                • Status anterior: <span className="capitalize">{ant.status_aprovacao}</span>
                              </p>
                            )}
                          </div>
                        )}

                        {isResidentRejected && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Status alterado para: <strong className="text-red-700">Rejeitado</strong>
                            </p>
                            {ant.status_aprovacao && (
                              <p className="text-gray-500 text-[11px]">
                                • Status anterior: <span className="capitalize">{ant.status_aprovacao}</span>
                              </p>
                            )}
                          </div>
                        )}

                        {isUnitInactivation && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            {post.link_data_saida && (
                              <p>
                                • Data de saída registrada: <strong>{formatDate(post.link_data_saida)}</strong>
                              </p>
                            )}
                            <p>
                              • Status resultante do perfil: <strong className="capitalize">{post.status_aprovacao || 'Inativo'}</strong>
                            </p>
                            {post.bloco_txt && post.apto_txt ? (
                              <p>
                                • Vínculo remanescente sincronizado para: <strong>{blocoLabel} {post.bloco_txt} · {aptoLabel} {post.apto_txt}</strong>
                              </p>
                            ) : (
                              <p className="text-gray-400 text-[11px]">
                                • Desocupação de unidade sem vínculo residencial remanescente ativo.
                              </p>
                            )}
                          </div>
                        )}

                        {isUnitLinkCreated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            {post.data_entrada && (
                              <p>
                                • Data de entrada registrada: <strong>{formatDate(post.data_entrada)}</strong>
                              </p>
                            )}
                            {post.tipo_morador && (
                              <p>
                                • Tipo de morador: <strong>{post.tipo_morador}</strong>
                              </p>
                            )}
                            {post.bloco_txt && post.apto_txt && (
                              <p>
                                • Unidade vinculada: <strong>{blocoLabel} {post.bloco_txt} · {aptoLabel} {post.apto_txt}</strong>
                              </p>
                            )}
                            <p>
                              • Status resultante do perfil: <strong className="capitalize">{post.status_aprovacao || 'Aprovado'}</strong>
                            </p>
                          </div>
                        )}

                        {isDateCorrected && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Data anterior: <span className="line-through text-gray-400">{formatDate(log.estado_anterior?.data_entrada)}</span>
                              {' '} ➔ Nova data: <strong className="text-emerald-700">{formatDate(post.data_entrada)}</strong>
                            </p>
                            {post.bloco_txt && post.apto_txt && (
                              <p>
                                • Unidade vinculada: <strong>{blocoLabel} {post.bloco_txt} · {aptoLabel} {post.apto_txt}</strong>
                              </p>
                            )}
                            <p className="text-gray-500 text-[11px]">
                              • Ajuste de data durante a homologação do Gate 3C.7-B.
                            </p>
                          </div>
                        )}

                        {isTypeChange && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Novo tipo de morador: <strong>{post.tipo_morador || 'Proprietário não morador'}</strong>
                            </p>
                            <p className="text-[11px] text-gray-500">
                              • Vínculo ativo mantido no imóvel preservando permissões de proprietário não-residente.
                            </p>
                          </div>
                        )}

                        {/* Eventos de Veículos (Gate 3D.2-B) */}
                        {isVehicleCreated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Placa: <strong className="font-mono font-bold text-gray-900">{formatPlateDisplay(post.placa)}</strong>
                              {post.marca && post.modelo && ` • ${post.marca} ${post.modelo}`}
                              {post.cor && ` (${post.cor})`}
                              {post.tipo && ` • Tipo: ${post.tipo}`}
                            </p>
                            {post.vaga_numero && (
                              <p>• Vaga designada: <strong>{post.vaga_numero}</strong></p>
                            )}
                            {post.ano && (
                              <p>• Ano de fabricação: <strong>{post.ano}</strong></p>
                            )}
                          </div>
                        )}

                        {isVehicleUpdated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Placa: <strong className="font-mono font-bold text-gray-900">{formatPlateDisplay(post.placa || ant.placa)}</strong>
                            </p>
                            <p>
                              • Dados atualizados: <strong>{post.marca} {post.modelo}</strong> ({post.cor}) • Tipo: {post.tipo}
                              {post.vaga_numero ? ` • Vaga: ${post.vaga_numero}` : ''}
                              {post.ano ? ` • Ano: ${post.ano}` : ''}
                            </p>
                          </div>
                        )}

                        {isVehiclePlateCorrected && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Placa anterior: <span className="line-through text-gray-400 font-mono">{formatPlateDisplay(ant.placa)}</span>
                              {' '} ➔ Nova placa: <strong className="font-mono font-bold text-amber-700">{formatPlateDisplay(post.placa)}</strong>
                            </p>
                            <p className="text-[11px] text-gray-500">
                              • Retificação controlada de erro material de digitação com auditoria.
                            </p>
                          </div>
                        )}

                        {isVehicleInactivated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Placa: <strong className="font-mono font-bold text-gray-900">{formatPlateDisplay(post.placa || ant.placa)}</strong>
                              {' '} • Status resultante: <strong className="text-zinc-600">Inativo</strong>
                            </p>
                          </div>
                        )}

                        {isVehicleReactivated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Placa: <strong className="font-mono font-bold text-gray-900">{formatPlateDisplay(post.placa || ant.placa)}</strong>
                              {' '} • Status resultante: <strong className="text-emerald-700">Ativo</strong>
                            </p>
                          </div>
                        )}

                        {/* Eventos de Pets (Gate 3E.2-B) */}
                        {isPetCreated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Pet: <strong className="font-bold text-gray-900">🐾 {post.nome}</strong>
                              {post.especie && ` • Espécie: ${formatEspecie(post.especie)}`}
                              {post.raca && ` • Raça: ${post.raca}`}
                              {post.cor && ` (${post.cor})`}
                            </p>
                            <p>
                              {post.sexo && `• Sexo: ${post.sexo === 'macho' ? 'Macho' : 'Fêmea'} • `}
                              {post.porte && `Porte: ${formatPorte(post.porte)} • `}
                              {post.data_nascimento && `Nascimento: ${formatDateCivil(post.data_nascimento)} • `}
                              Vacinado: {post.vacinado === true ? 'Sim' : post.vacinado === false ? 'Não' : 'Não informado'} • Castrado: {post.castrado === true ? 'Sim' : post.castrado === false ? 'Não' : 'Não informado'}
                            </p>
                          </div>
                        )}

                        {isPetUpdated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Pet: <strong className="font-bold text-gray-900">🐾 {post.nome || ant.nome}</strong>
                              {post.especie && ` • Espécie: ${formatEspecie(post.especie)}`}
                              {post.raca && ` • Raça: ${post.raca}`}
                              {post.cor && ` (${post.cor})`}
                            </p>
                            <p>
                              • Atualização cadastral registrada no histórico de auditoria.
                            </p>
                          </div>
                        )}

                        {isPetInactivated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Pet: <strong className="font-bold text-gray-900">🐾 {post.nome || ant.nome}</strong>
                              {' '} • Status resultante: <strong className="text-zinc-600">Inativo</strong>
                            </p>
                          </div>
                        )}

                        {isPetReactivated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Pet: <strong className="font-bold text-gray-900">🐾 {post.nome || ant.nome}</strong>
                              {' '} • Status resultante: <strong className="text-emerald-700">Ativo</strong>
                            </p>
                          </div>
                        )}

                        {isPetUnitChanged && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Pet: <strong className="font-bold text-gray-900">🐾 {post.nome || ant.nome}</strong>
                            </p>
                            {(log.unidade_bloco || log.unidade_apto) && (
                              <p>
                                • Nova unidade residencial: <strong>{blocoLabel} {log.unidade_bloco || '—'} · {aptoLabel} {log.unidade_apto || '—'}</strong>
                              </p>
                            )}
                          </div>
                        )}

                        {/* Eventos de Foto de Veículo (Gate 3F.2-B) */}
                        {isVehiclePhotoUpdated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Veículo: <strong className="font-mono font-bold text-gray-900">{formatPlateDisplay(post.placa || ant.placa)}</strong>
                            </p>
                            <p className="text-gray-500">
                              • Foto atualizada com sucesso no cadastro do veículo.
                            </p>
                          </div>
                        )}

                        {isVehiclePhotoRemoved && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Veículo: <strong className="font-mono font-bold text-gray-900">{formatPlateDisplay(post.placa || ant.placa)}</strong>
                            </p>
                            <p className="text-gray-500">
                              • Foto removida do cadastro do veículo.
                            </p>
                          </div>
                        )}

                        {/* Eventos de Foto de Pet (Gate 3F.2-B) */}
                        {isPetPhotoUpdated && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Pet: <strong className="font-bold text-gray-900">🐾 {post.nome || ant.nome || 'Pet'}</strong>
                            </p>
                            <p className="text-gray-500">
                              • Foto atualizada com sucesso no cadastro do pet.
                            </p>
                          </div>
                        )}

                        {isPetPhotoRemoved && (
                          <div className="text-xs text-gray-600 bg-white p-3 rounded-lg border border-gray-100 space-y-1">
                            <p>
                              • Pet: <strong className="font-bold text-gray-900">🐾 {post.nome || ant.nome || 'Pet'}</strong>
                            </p>
                            <p className="text-gray-500">
                              • Foto removida do cadastro do pet.
                            </p>
                          </div>
                        )}

                        {/* Operador responsável */}
                        <div className="text-[11px] text-gray-400 pt-1 border-t border-gray-100 flex items-center justify-between">
                          <span>Operador responsável: <strong className="text-gray-600">{log.operador_nome}</strong> ({log.operador_papel || 'Admin'})</span>
                        </div>
                      </div>
                    )
                  })}
                </div>
              ) : (
                <div className="text-center py-8 text-gray-400 text-xs">
                  <Shield size={28} className="mx-auto mb-2 text-gray-300" />
                  Nenhum registro de auditoria administrativa encontrado para este morador.
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Block / Unblock Modal */}
      {confirmAction && (
        <BlockConfirmModal
          isOpen={!!confirmAction}
          onClose={() => {
            if (!actionLoading) {
              setConfirmAction(null)
              setActionError(null)
            }
          }}
          residentName={resident.nome_completo || 'Morador'}
          action={confirmAction}
          loading={actionLoading}
          error={actionError}
          onConfirm={handleConfirmBlockAction}
        />
      )}

      {/* Approve Modal (Gate 3L) */}
      {isApproveModalOpen && (
        <ApproveConfirmModal
          isOpen={isApproveModalOpen}
          onClose={() => {
            if (!approvalLoading) {
              setIsApproveModalOpen(false)
              setApprovalError(null)
            }
          }}
          onConfirm={handleConfirmApprove}
          residentName={resident.nome_completo || 'Morador'}
          isReapproval={isRejected}
          loading={approvalLoading}
          error={approvalError}
        />
      )}

      {/* Reject Modal (Gate 3L) */}
      {isRejectModalOpen && (
        <RejectConfirmModal
          isOpen={isRejectModalOpen}
          onClose={() => {
            if (!rejectionLoading) {
              setIsRejectModalOpen(false)
              setRejectionError(null)
            }
          }}
          onConfirm={handleConfirmReject}
          residentName={resident.nome_completo || 'Morador'}
          loading={rejectionLoading}
          error={rejectionError}
        />
      )}

      {/* Inactivate Modal (Gate 3C.5) */}
      {isInactivateModalOpen && (
        <InactivateConfirmModal
          isOpen={isInactivateModalOpen}
          onClose={() => setIsInactivateModalOpen(false)}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          tipoEstrutura={condoTipoEstrutura}
          initialActiveUnits={activeUnit ? [{
            id: activeUnit.id,
            bloco: activeUnit.bloco_nome,
            apto: activeUnit.apto_numero,
            data_entrada: activeUnit.data_entrada,
          }] : undefined}
          onSuccess={(res) => {
            if (res) {
              setResident(prev => ({
                ...prev,
                status_aprovacao: res.profile_status || prev.status_aprovacao,
                tipo_morador: res.resident_type || prev.tipo_morador,
                bloco_txt: res.profile_status === 'inativo' ? null : prev.bloco_txt,
                apto_txt: res.profile_status === 'inativo' ? null : prev.apto_txt,
              }))
            }
            router.refresh()
          }}
        />
      )}

      {isCreateLinkModalOpen && (
        <CreateResidentLinkModal
          isOpen={isCreateLinkModalOpen}
          onClose={() => setIsCreateLinkModalOpen(false)}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          tipoEstrutura={condoTipoEstrutura}
          onSuccess={(res) => {
            if (res) {
              setResident(prev => ({
                ...prev,
                status_aprovacao: res.profile_status || 'aprovado',
                bloqueado: false,
                bloco_txt: res.block ?? prev.bloco_txt,
                apto_txt: res.apartment ?? prev.apto_txt,
                tipo_morador: res.resident_type ?? prev.tipo_morador,
              }))
            }
            setIsCreateLinkModalOpen(false)
            router.refresh()
          }}
        />
      )}

      {/* Edit General Data Modal (Gate 3I.4) */}
      <EditGeneralDataModal
        open={editGeneralDataOpen}
        onClose={() => setEditGeneralDataOpen(false)}
        residentId={initialResident.id}
        nomeCompleto={initialResident.nome_completo || ''}
        whatsapp={initialResident.whatsapp || ''}
        tipoMorador={initialResident.tipo_morador || ''}
        papelSistema={initialResident.papel_sistema || ''}
        onSaved={() => {
          setEditGeneralDataOpen(false)
          router.refresh()
        }}
      />

      {/* Vehicle Add / Edit Modal */}
      {isVehicleModalOpen && (
        <VehicleModal
          isOpen={isVehicleModalOpen}
          onClose={() => {
            setIsVehicleModalOpen(false)
            setEditingVehicle(null)
          }}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          activeUnits={unitLinks
            .filter(u => u.status === 'ativo')
            .map(u => ({
              id: u.id,
              unidade_id: u.unidade_id,
              bloco_nome: u.bloco_nome,
              apto_numero: u.apto_numero,
            }))}
          editingVehicle={editingVehicle}
          onSuccess={() => {
            setIsVehicleModalOpen(false)
            setEditingVehicle(null)
            router.refresh()
          }}
        />
      )}

      {/* Vehicle Plate Correction Modal */}
      {correctingVehicle && (
        <VehiclePlateModal
          isOpen={Boolean(correctingVehicle)}
          onClose={() => setCorrectingVehicle(null)}
          vehicle={correctingVehicle}
          profileId={resident.id}
          onSuccess={() => {
            setCorrectingVehicle(null)
            router.refresh()
          }}
        />
      )}

      {/* Vehicle Inactivate Modal */}
      {inactivatingVehicle && (
        <VehicleInactivateModal
          isOpen={Boolean(inactivatingVehicle)}
          onClose={() => setInactivatingVehicle(null)}
          vehicle={inactivatingVehicle}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          onSuccess={() => {
            setInactivatingVehicle(null)
            router.refresh()
          }}
        />
      )}

      {/* Vehicle Reactivate Modal */}
      {reactivatingVehicle && (
        <VehicleReactivateModal
          isOpen={Boolean(reactivatingVehicle)}
          onClose={() => setReactivatingVehicle(null)}
          vehicle={reactivatingVehicle}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          onSuccess={() => {
            setReactivatingVehicle(null)
            router.refresh()
          }}
        />
      )}

      {/* Pet Add / Edit Modal */}
      {isPetModalOpen && (
        <PetModal
          isOpen={isPetModalOpen}
          onClose={() => {
            setIsPetModalOpen(false)
            setEditingPet(null)
          }}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          activeUnits={unitLinks
            .filter(u => u.status === 'ativo')
            .map(u => ({
              id: u.id,
              unidade_id: u.unidade_id,
              bloco_nome: u.bloco_nome,
              apto_numero: u.apto_numero,
            }))}
          editingPet={editingPet}
          onSuccess={() => {
            setIsPetModalOpen(false)
            setEditingPet(null)
            router.refresh()
          }}
        />
      )}

      {/* Pet Transfer Unit Modal */}
      {transferringPet && (
        <PetUnitModal
          isOpen={Boolean(transferringPet)}
          onClose={() => setTransferringPet(null)}
          pet={transferringPet}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          activeUnits={unitLinks
            .filter(u => u.status === 'ativo')
            .map(u => ({
              id: u.id,
              unidade_id: u.unidade_id,
              bloco_nome: u.bloco_nome,
              apto_numero: u.apto_numero,
            }))}
          onSuccess={() => {
            setTransferringPet(null)
            router.refresh()
          }}
        />
      )}

      {/* Pet Inactivate Modal */}
      {inactivatingPet && (
        <PetInactivateModal
          isOpen={Boolean(inactivatingPet)}
          onClose={() => setInactivatingPet(null)}
          pet={inactivatingPet}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          onSuccess={() => {
            setInactivatingPet(null)
            router.refresh()
          }}
        />
      )}

      {/* Pet Reactivate Modal */}
      {reactivatingPet && (
        <PetReactivateModal
          isOpen={Boolean(reactivatingPet)}
          onClose={() => setReactivatingPet(null)}
          pet={reactivatingPet}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          onSuccess={() => {
            setReactivatingPet(null)
            router.refresh()
          }}
        />
      )}

      {/* Photo Upload / Substitution Modal (Gate 3F.2-B) */}
      {photoUploadTarget && (
        <PhotoUploadModal
          isOpen={Boolean(photoUploadTarget)}
          onClose={() => setPhotoUploadTarget(null)}
          type={photoUploadTarget.type}
          entityId={photoUploadTarget.id}
          entityName={photoUploadTarget.name}
          condominioId={photoUploadTarget.condoId}
          currentPhotoPath={photoUploadTarget.currentPhotoPath}
          profileId={resident.id}
          onSuccess={() => {
            setPhotoUploadTarget(null)
            router.refresh()
          }}
        />
      )}

      {/* Photo Removal Confirmation Modal (Gate 3F.2-B) */}
      {photoRemoveTarget && (
        <PhotoRemoveModal
          isOpen={Boolean(photoRemoveTarget)}
          onClose={() => setPhotoRemoveTarget(null)}
          type={photoRemoveTarget.type}
          entityId={photoRemoveTarget.id}
          entityName={photoRemoveTarget.name}
          condominioId={photoRemoveTarget.condoId}
          currentPhotoPath={photoRemoveTarget.currentPhotoPath}
          profileId={resident.id}
          onSuccess={() => {
            setPhotoRemoveTarget(null)
            router.refresh()
          }}
        />
      )}

      {/* Photo Fullscreen Viewer Lightbox (Gate 3F.2-B) */}
      {viewingPhoto && (
        <PhotoViewerModal
          isOpen={Boolean(viewingPhoto)}
          onClose={() => setViewingPhoto(null)}
          imageUrl={viewingPhoto.url}
          title={viewingPhoto.title}
        />
      )}

      {/* Dependent Create/Edit Modal (Gate 3G.3-B4) */}
      <DependentModal
        isOpen={isDependentModalOpen}
        onClose={() => {
          setIsDependentModalOpen(false)
          setEditingDependente(null)
        }}
        profileId={resident.id}
        unitId={activeUnit?.unidade_id || ''}
        residentName={resident.nome_completo || 'Morador'}
        editingDependente={editingDependente}
        onSuccess={() => {
          setIsDependentModalOpen(false)
          setEditingDependente(null)
          router.refresh()
        }}
      />

      {/* Dependent Inactivate Modal (Gate 3G.3-B5A) */}
      {inactivatingDependente && (
        <DependentInactivateModal
          isOpen={Boolean(inactivatingDependente)}
          onClose={() => setInactivatingDependente(null)}
          dependente={inactivatingDependente}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          onSuccess={() => {
            setInactivatingDependente(null)
            router.refresh()
          }}
        />
      )}

      {/* Dependent Reactivate Modal (Gate 3G.3-B5A) */}
      {reactivatingDependente && (
        <DependentReactivateModal
          isOpen={Boolean(reactivatingDependente)}
          onClose={() => setReactivatingDependente(null)}
          dependente={reactivatingDependente}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          onSuccess={() => {
            setReactivatingDependente(null)
            router.refresh()
          }}
        />
      )}

      {/* Dependent Responsible Transfer Modal (Gate 3G.3-B5B) */}
      {transferringDependente && (
        <DependentResponsibleModal
          isOpen={Boolean(transferringDependente)}
          onClose={() => setTransferringDependente(null)}
          dependente={transferringDependente}
          profileId={resident.id}
          residentName={resident.nome_completo || 'Morador'}
          coResidents={coResidents}
          onSuccess={() => {
            setTransferringDependente(null)
            router.refresh()
          }}
        />
      )}
    </div>
  )
}
