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
} from 'lucide-react'
import { getBlocoLabel, getAptoLabel, formatUnitDisplay, isTechnicalAdminUnit } from '@/lib/labels'
import { isTechnicalAdminRole } from '@/lib/roles'
import BlockConfirmModal from '../block-confirm-modal'
import InactivateConfirmModal from '../inactivate-confirm-modal'
import CreateResidentLinkModal from '../create-resident-link-modal'
import VehicleModal from '../vehicle-modal'
import VehiclePlateModal from '../vehicle-plate-modal'
import VehicleInactivateModal from '../vehicle-inactivate-modal'
import VehicleReactivateModal from '../vehicle-reactivate-modal'
import { adminToggleBlockStatus } from '@/app/admin/actions'

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
  guest_name: string | null
  visitor_type: string | null
  status: string | null
  validity_date: string | null
  qr_data: string | null
  created_at: string
  visitante_compareceu: boolean | null
}

export interface PortariaRegistroData {
  id: string
  nome: string | null
  tipo_visitante: string | null
  entrada_at: string | null
  saida_at: string | null
  status: string | null
  created_at: string | null
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
  created_at: string
  updated_at?: string | null
  unidade_bloco?: string | null
  unidade_apto?: string | null
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
}: Props) {
  const router = useRouter()
  const [activeTab, setActiveTab] = useState<TabKey>('dados-gerais')

  // Synced local state for immediate reactive status changes
  const [resident, setResident] = useState<ResidentData>(initialResident)
  useEffect(() => {
    setResident(initialResident)
  }, [initialResident])

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

  // Block / Unblock Modal State
  const [confirmAction, setConfirmAction] = useState<'block' | 'unblock' | null>(null)
  const [actionLoading, setActionLoading] = useState(false)
  const [actionError, setActionError] = useState<string | null>(null)

  // Inactivate Modal State
  const [isInactivateModalOpen, setIsInactivateModalOpen] = useState(false)

  // Create Resident Link Modal State (Gate 3C.7)
  const [isCreateLinkModalOpen, setIsCreateLinkModalOpen] = useState(false)

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
    { key: 'pets', label: 'Pets', icon: <Heart size={16} /> },
    { key: 'familia', label: 'Família', icon: <Users size={16} />, count: coResidents.length > 0 ? coResidents.length + 1 : undefined },
    { key: 'acessos', label: 'Acessos', icon: <KeyRound size={16} />, count: convites.length + portariaRegistros.length },
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
            {resident.foto_url ? (
              <img
                src={resident.foto_url}
                alt={resident.nome_completo || 'Morador'}
                className="w-20 h-20 rounded-2xl object-cover shadow-sm border-2 border-gray-100 flex-shrink-0"
              />
            ) : (
              <div
                className={`w-20 h-20 rounded-2xl flex items-center justify-center shadow-md flex-shrink-0 ${
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
              <h2 className="text-base font-bold text-gray-900 mb-4 flex items-center gap-2">
                <User size={18} className="text-[#FC5931]" />
                Identificação Pessoal
              </h2>
              <dl className="space-y-3.5 text-sm">
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Nome Completo</dt>
                  <dd className="font-medium text-gray-900 mt-0.5">{resident.nome_completo || '—'}</dd>
                </div>
                <div>
                  <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Foto do Perfil</dt>
                  <dd className="text-gray-700 mt-0.5">
                    {resident.foto_url ? 'Foto personalizada cadastrada' : 'Avatar gerado por iniciais'}
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

                          {/* Marca e Modelo */}
                          <div>
                            <h3 className={`font-bold text-base leading-tight ${isAtivo ? 'text-gray-900' : 'text-zinc-600'}`}>
                              {veiculo.marca} {veiculo.modelo}
                            </h3>
                            <p className="text-xs text-gray-500 mt-1 capitalize">
                              {veiculo.cor} · {veiculo.tipo} {veiculo.ano ? `· ${veiculo.ano}` : ''}
                            </p>
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
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-12 text-center max-w-xl mx-auto">
            <div className="w-16 h-16 rounded-2xl bg-orange-50 mx-auto flex items-center justify-center mb-4">
              <Heart size={32} className="text-[#FC5931]" />
            </div>
            <h2 className="text-lg font-bold text-gray-900 mb-1">Animais de Estimação (Pets)</h2>
            <p className="text-sm text-gray-500 mb-5">
              Nenhum pet cadastrado. O cadastro de pets (foto, nome, espécie, raça, porte e carteira de vacinação) será disponibilizado na próxima etapa.
            </p>
            <button
              disabled
              className="px-4 py-2 rounded-xl text-xs font-semibold bg-gray-100 text-gray-400 border border-gray-200 cursor-not-allowed"
            >
              + Adicionar Pet (Em breve)
            </button>
          </div>
        )}

        {/* 5. FAMÍLIA */}
        {activeTab === 'familia' && (
          <div className="space-y-6">
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
              <div className="mb-4">
                <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
                  <Users size={18} className="text-[#FC5931]" />
                  Pessoas Atualmente Vinculadas à Mesma Unidade
                </h2>
                <p className="text-xs text-gray-500 mt-1">
                  Exibindo cadastros que compartilham a mesma unidade física ({formattedUnit}).
                </p>
              </div>

              {/* Informative notice */}
              <div className="bg-amber-50/70 border border-amber-200/80 rounded-xl p-3.5 mb-5 flex items-start gap-2.5">
                <Info size={16} className="text-amber-600 shrink-0 mt-0.5" />
                <p className="text-xs text-amber-800">
                  <strong className="font-semibold">Relações Familiares em Modelagem:</strong> A estrutura relacional formal (cônjuge, filhos, dependentes e titularidade) será configurada em uma próxima etapa.
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
                <div className="divide-y divide-gray-100">
                  {convites.map(c => (
                    <div key={c.id} className="py-3 flex items-center justify-between flex-wrap gap-2">
                      <div>
                        <p className="font-semibold text-sm text-gray-800">{c.guest_name || 'Visitante sem nome'}</p>
                        <p className="text-xs text-gray-400 mt-0.5">
                          Tipo: {c.visitor_type || 'Visitante'} • Validade: {formatDateTime(c.validity_date)}
                        </p>
                      </div>
                      <div className="flex items-center gap-2">
                        {c.visitante_compareceu && (
                          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                            Compareceu
                          </span>
                        )}
                        <span className="text-xs px-2.5 py-0.5 rounded-full font-medium bg-gray-100 text-gray-700">
                          {c.status}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
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
                <div className="divide-y divide-gray-100">
                  {portariaRegistros.map(r => (
                    <div key={r.id} className="py-3 flex items-center justify-between flex-wrap gap-2">
                      <div>
                        <p className="font-semibold text-sm text-gray-800">{r.nome || 'Visitante'}</p>
                        <p className="text-xs text-gray-400 mt-0.5">
                          Tipo: {r.tipo_visitante || 'Visitante'} • Entrada: {formatDateTime(r.entrada_at)}
                        </p>
                      </div>
                      <span className="text-xs px-2.5 py-0.5 rounded-full font-medium bg-gray-100 text-gray-700">
                        {r.status || 'Registrado'}
                      </span>
                    </div>
                  ))}
                </div>
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
                    const isUnitInactivation = log.acao === 'UNIT_INACTIVATED'
                    const isUnitLinkCreated = log.acao === 'UNIT_LINK_CREATED'
                    const isDateCorrected = log.acao === 'UNIT_LINK_ENTRY_DATE_CORRECTED'
                    const isTypeChange = log.acao === 'RESIDENT_TYPE_CHANGED'
                    const isVehicleCreated = log.acao === 'VEHICLE_CREATED'
                    const isVehicleUpdated = log.acao === 'VEHICLE_UPDATED'
                    const isVehiclePlateCorrected = log.acao === 'VEHICLE_PLATE_CORRECTED'
                    const isVehicleInactivated = log.acao === 'VEHICLE_INACTIVATED'
                    const isVehicleReactivated = log.acao === 'VEHICLE_REACTIVATED'

                    return (
                      <div
                        key={log.id}
                        className="p-4 rounded-xl bg-zinc-50 border border-zinc-200/80 space-y-2.5 transition-all hover:bg-zinc-50/90"
                      >
                        <div className="flex items-start justify-between gap-3 flex-wrap">
                          <div className="flex items-center gap-2">
                            {isUnitInactivation ? (
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
    </div>
  )
}
