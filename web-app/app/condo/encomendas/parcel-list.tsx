'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Package, CheckCircle2, Clock, X, Loader2,
  Box, Mail, ShoppingBag, FileText, ChevronDown, UserCheck, RefreshCw,
  Camera, PenTool, PackageCheck, AlertTriangle
} from 'lucide-react'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

// ── Types ────────────────────────────────────────────────────────────────────

interface Perfil {
  id: string
  nome_completo: string
  bloco_txt: string | null
  apto_txt: string | null
}

interface Parcel {
  id: string
  resident_id: string | null
  status: string
  arrival_time: string
  delivery_time: string | null
  tipo: string | null
  tracking_code: string | null
  observacao: string | null
  photo_url: string | null
  pickup_proof_url: string | null
  picked_up_by_id: string | null
  picked_up_by_name: string | null
  condominio_id: string
  bloco: string | null
  apto: string | null
  perfil: Perfil | null
}

interface Props {
  initialParcels: Parcel[]
  isPorter: boolean
  userId: string
  condoId: string
  tipoEstrutura?: string
  allBlocos?: string[]
  allAptosMap?: Record<string, string[]>
}

// ── Helpers ──────────────────────────────────────────────────────────────────

const TIPO_LABELS: Record<string, { label: string; icon: React.ElementType; color: string }> = {
  caixa:          { label: 'Caixa',           icon: Box,         color: 'bg-blue-100 text-blue-700' },
  envelope:       { label: 'Envelope',        icon: Mail,        color: 'bg-gray-100 text-gray-700' },
  pacote:         { label: 'Pacote',          icon: ShoppingBag, color: 'bg-purple-100 text-purple-700' },
  notif_judicial: { label: 'Notif. Judicial', icon: FileText,    color: 'bg-red-100 text-red-700' },
}

function fmt(iso: string) {
  return new Date(iso).toLocaleString('pt-BR', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

const PARCEL_FIELDS = 'id, resident_id, status, arrival_time, delivery_time, tipo, tracking_code, observacao, photo_url, pickup_proof_url, condominio_id, picked_up_by_id, picked_up_by_name, bloco, apto, created_at'

// ── Delivery Modal ────────────────────────────────────────────────────────────

interface DeliveryModalProps {
  parcel: Parcel
  condoId: string
  tipoEstrutura?: string
  onClose: () => void
  onConfirm: (parcel: Parcel, pickedById: string | null, pickedByName: string) => Promise<void>
}

function DeliveryModal({ parcel, condoId, tipoEstrutura, onClose, onConfirm }: DeliveryModalProps) {
  const supabase = createClient()
  const [residents, setResidents] = useState<Perfil[]>([])
  const [loadingResidents, setLoadingResidents] = useState(true)
  const [pickedById, setPickedById] = useState<string | null>(null)
  const [thirdPartyName, setThirdPartyName] = useState('')
  const [isThirdParty, setIsThirdParty] = useState(false)
  const [confirming, setConfirming] = useState(false)

  const isThirdPartyRef = useRef(isThirdParty)
  isThirdPartyRef.current = isThirdParty

  const bloco = parcel.bloco ?? parcel.perfil?.bloco_txt ?? null
  const apto  = parcel.apto ?? parcel.perfil?.apto_txt  ?? null

  // Fetch residents of this unit with race condition guard
  useEffect(() => {
    let cancelled = false
    async function load() {
      setLoadingResidents(true)
      if (!bloco || !apto) {
        setLoadingResidents(false)
        return
      }
      const { data } = await supabase
        .from('perfil')
        .select('id, nome_completo, bloco_txt, apto_txt')
        .eq('condominio_id', condoId)
        .eq('bloco_txt', bloco)
        .eq('apto_txt', apto)
        .not('nome_completo', 'is', null)
        .eq('status_aprovacao', 'aprovado')
        .neq('bloqueado', true)

      if (cancelled) return
      setResidents(data ?? [])
      if (data && data.length === 1 && !isThirdPartyRef.current) {
        setPickedById(data[0].id)
      }
      setLoadingResidents(false)
    }
    load()
    return () => {
      cancelled = true
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bloco, apto, condoId])

  const tipoInfo = TIPO_LABELS[parcel.tipo ?? ''] ?? TIPO_LABELS['pacote']
  const TipoIcon = tipoInfo.icon

  async function handleConfirm() {
    if (!isThirdParty && !pickedById) return
    const cleanThirdParty = thirdPartyName.trim()
    if (isThirdParty && !cleanThirdParty) return

    setConfirming(true)
    await onConfirm(
      parcel,
      isThirdParty ? null : pickedById,
      isThirdParty ? cleanThirdParty : (residents.find(r => r.id === pickedById)?.nome_completo ?? '')
    )
  }

  const canConfirm = isThirdParty ? thirdPartyName.trim().length > 0 : pickedById !== null

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h2 className="font-bold text-gray-900 text-base">Registro de retirada de encomenda</h2>
          <button onClick={onClose} title="Fechar" className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors">
            <X size={18} className="text-gray-500" />
          </button>
        </div>

        <div className="px-6 py-5 space-y-5">

          {/* Parcel info */}
          <div className="flex items-center gap-3 bg-gray-50 rounded-xl p-4">
            <div className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${tipoInfo.color}`}>
              <TipoIcon size={20} />
            </div>
            <div className="min-w-0">
              <p className="font-semibold text-gray-900">{tipoInfo.label}</p>
              <p className="text-sm text-gray-500">
                {getBlocoLabel(tipoEstrutura)} {bloco ?? '?'} / {getAptoLabel(tipoEstrutura)} {apto ?? '?'}
                {parcel.tracking_code && <span className="ml-2 font-mono text-xs">· {parcel.tracking_code}</span>}
              </p>
              {parcel.observacao && (
                <p className="text-xs text-gray-400 mt-0.5 truncate">{parcel.observacao}</p>
              )}
            </div>
          </div>

          {/* Resident select */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-2">Entregue á:</label>
            {loadingResidents ? (
              <div className="flex items-center gap-2 text-sm text-gray-400">
                <Loader2 size={14} className="animate-spin" /> Carregando moradores...
              </div>
            ) : residents.length === 0 ? (
              <p className="text-sm text-gray-400 italic">Nenhum morador cadastrado nesta unidade.</p>
            ) : (
              <div className="relative">
                <select
                  value={pickedById ?? ''}
                  aria-label="Selecione o morador"
                  onChange={e => {
                    setPickedById(e.target.value || null)
                    setIsThirdParty(false)
                    setThirdPartyName('')
                  }}
                  disabled={isThirdParty}
                  className="w-full px-4 py-3 pr-10 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931] appearance-none bg-white disabled:opacity-50"
                >
                  <option value="">Selecione o morador</option>
                  {residents.map(r => (
                    <option key={r.id} value={r.id}>{r.nome_completo}</option>
                  ))}
                </select>
                <ChevronDown size={16} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
              </div>
            )}
          </div>

          {/* Third party toggle + input */}
          <div>
            <label className="flex items-center gap-2 cursor-pointer select-none mb-2">
              <input
                type="checkbox"
                checked={isThirdParty}
                onChange={e => {
                  const checked = e.target.checked
                  setIsThirdParty(checked)
                  if (checked) {
                    setPickedById(null)
                  } else {
                    setThirdPartyName('')
                    if (residents.length === 1) setPickedById(residents[0].id)
                  }
                }}
                className="rounded border-gray-300 text-[#FC5931] focus:ring-[#FC5931]"
              />
              <span className="text-sm font-semibold text-gray-700">Entregando a terceiro(a):</span>
            </label>

            {isThirdParty && (
              <input
                type="text"
                value={thirdPartyName}
                onChange={e => setThirdPartyName(e.target.value)}
                placeholder="Nome completo do terceiro"
                autoFocus
                className="w-full px-4 py-3 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50"
              />
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="flex gap-3 px-6 pb-6">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-3 border border-gray-200 rounded-xl text-sm font-semibold text-gray-600 hover:bg-gray-50 transition-colors"
          >
            Fechar
          </button>
          <button
            onClick={handleConfirm}
            disabled={!canConfirm || confirming}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-green-600 text-white rounded-xl text-sm font-semibold hover:bg-green-700 disabled:opacity-50 transition-colors shadow-sm"
          >
            {confirming ? (
              <><Loader2 size={14} className="animate-spin" /> Confirmando...</>
            ) : (
              <><UserCheck size={16} /> Confirmar Retirada</>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Silent Discharge Confirmation Modal ───────────────────────────────────────

interface SilentDischargeModalProps {
  parcel: Parcel
  tipoEstrutura?: string
  onClose: () => void
  onConfirm: (parcel: Parcel) => Promise<void>
}

function SilentDischargeModal({ parcel, tipoEstrutura, onClose, onConfirm }: SilentDischargeModalProps) {
  const [confirming, setConfirming] = useState(false)
  const tipoInfo = TIPO_LABELS[parcel.tipo ?? ''] ?? TIPO_LABELS['pacote']
  const TipoIcon = tipoInfo.icon
  const bloco = parcel.bloco ?? parcel.perfil?.bloco_txt ?? '?'
  const apto  = parcel.apto ?? parcel.perfil?.apto_txt  ?? '?'

  async function handleConfirm() {
    setConfirming(true)
    await onConfirm(parcel)
  }

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-end sm:items-center justify-center" onClick={onClose}>
      <div
        className="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden animate-slide-up"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h2 className="font-bold text-gray-900 text-base">Baixa Silenciosa</h2>
          <button onClick={onClose} title="Fechar" className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors">
            <X size={18} className="text-gray-500" />
          </button>
        </div>

        <div className="px-6 py-5 space-y-4">
          {/* Parcel info */}
          <div className="flex items-center gap-3 bg-gray-50 rounded-xl p-3">
            <div className={`w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 ${tipoInfo.color}`}>
              <TipoIcon size={18} />
            </div>
            <div className="min-w-0">
              <p className="font-semibold text-gray-900 text-sm">
                {getBlocoLabel(tipoEstrutura)} {bloco} / {getAptoLabel(tipoEstrutura)} {apto}
              </p>
              <p className="text-xs text-gray-500">{parcel.perfil?.nome_completo ?? 'Sem morador'}</p>
            </div>
          </div>

          {/* Warning */}
          <div className="flex items-start gap-3 bg-amber-50 border border-amber-200 rounded-xl p-4">
            <AlertTriangle size={20} className="text-amber-500 flex-shrink-0 mt-0.5" />
            <div>
              <p className="font-semibold text-amber-800 text-sm">Tem certeza que quer dar baixa nessa encomenda?</p>
              <p className="text-xs text-amber-600 mt-1">Não iremos disparar mensagem e Push para o morador.</p>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="flex gap-3 px-6 pb-6">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-3 border border-gray-200 rounded-xl text-sm font-semibold text-gray-600 hover:bg-gray-50 transition-colors"
          >
            Cancelar
          </button>
          <button
            onClick={handleConfirm}
            disabled={confirming}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-gray-700 text-white rounded-xl text-sm font-semibold hover:bg-gray-800 disabled:opacity-50 transition-colors shadow-sm"
          >
            {confirming ? (
              <><Loader2 size={14} className="animate-spin" /> Processando...</>
            ) : (
              <><PackageCheck size={16} /> Dar Baixa</>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Main List ─────────────────────────────────────────────────────────────────

export default function ParcelList({ initialParcels, isPorter, userId, condoId, tipoEstrutura, allBlocos, allAptosMap }: Props) {
  const supabase = createClient()

  const [parcels, setParcels] = useState<Parcel[]>(initialParcels)
  const [statusFilter, setStatusFilter] = useState<'all' | 'pending' | 'delivered'>('all')
  const [blocoFilter, setBlocoFilter] = useState('')
  const [aptoFilter, setAptoFilter] = useState('')
  const [page, setPage] = useState(1)
  const [photoModal, setPhotoModal] = useState<string | null>(null)
  const [deliveryModal, setDeliveryModal] = useState<Parcel | null>(null)
  const [silentDischargeModal, setSilentDischargeModal] = useState<Parcel | null>(null)
  const [mounted, setMounted] = useState(false)

  // Server-side fetch state (porter/admin mode)
  const [loading, setLoading] = useState(isPorter)
  const [totalFiltered, setTotalFiltered] = useState(0)
  const [totalKnown, setTotalKnown] = useState(false)
  const [hasMore, setHasMore] = useState(false)
  const [pendingStat, setPendingStat] = useState(0)
  const [deliveredStat, setDeliveredStat] = useState(0)
  const [fetchError, setFetchError] = useState<string | null>(null)
  const fetchIdRef = useRef(0)

  useEffect(() => { requestAnimationFrame(() => setMounted(true)) }, [])

  const PER_PAGE = 10
  const numSort = (a: string, b: string) => a.localeCompare(b, 'pt', { numeric: true })

  // Use server-provided blocos/aptos when available, fallback to parcel-derived
  const uniqueBlocos = (allBlocos && allBlocos.length > 0) ? allBlocos : [...new Set(
    parcels.map(p => p.bloco ?? p.perfil?.bloco_txt).filter(Boolean) as string[]
  )].sort(numSort)
  const uniqueAptos = (blocoFilter && allAptosMap?.[blocoFilter] && allAptosMap[blocoFilter].length > 0)
    ? allAptosMap[blocoFilter]
    : [...new Set(
        parcels
          .filter(p => !blocoFilter || (p.bloco ?? p.perfil?.bloco_txt) === blocoFilter)
          .map(p => p.apto ?? p.perfil?.apto_txt)
          .filter(Boolean) as string[]
      )].sort(numSort)

  // ── Server-side fetch (porter/admin mode) ───────────────────────────────────

  const fetchParcels = useCallback(async (
    status: 'all' | 'pending' | 'delivered',
    bloco: string,
    apto: string,
    pageNum: number,
    fetchStats: boolean = true
  ) => {
    const fetchId = ++fetchIdRef.current
    setLoading(true)
    setFetchError(null)

    try {
      const from = (pageNum - 1) * PER_PAGE
      const to = from + PER_PAGE - 1

      // Main data query WITHOUT count:exact (eliminates timeout under RLS)
      let query = supabase
        .from('encomendas')
        .select(PARCEL_FIELDS)
        .eq('condominio_id', condoId)
        .order('created_at', { ascending: false })

      if (status !== 'all') query = query.eq('status', status)
      if (bloco) query = query.eq('bloco', bloco)
      if (apto) query = query.eq('apto', apto)

      // ── 1. Fetch data first (fast: ~283ms even on cold start) ────────────
      const { data, error } = await query.range(from, to)

      // Race condition guard
      if (fetchId !== fetchIdRef.current) return

      if (error) {
        console.error('❌ fetch parcels error:', {
          code: error.code,
          message: error.message,
          details: error.details,
          hint: error.hint,
        })
        setFetchError('Não foi possível carregar as encomendas. Tente novamente.')
        return
      }

      // Resolve resident names
      const parcelsData = (data ?? []) as Record<string, unknown>[]

      // If the page returned empty but pageNum > 1, the page ceased to exist on the server (e.g. concurrent discharge)
      if (parcelsData.length === 0 && pageNum > 1) {
        setPage(p => Math.max(1, p - 1))
        return
      }
      const isUUID = (str: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str)
      const validResidentUUIDs = [...new Set(parcelsData.map(p => p.resident_id as string).filter(id => id && isUUID(id)))]
      const perfilMap: Record<string, Perfil> = {}

      if (validResidentUUIDs.length > 0) {
        const { data: perfis } = await supabase
          .from('perfil')
          .select('id, nome_completo, bloco_txt, apto_txt')
          .in('id', validResidentUUIDs)
        ;(perfis ?? []).forEach((p: Perfil) => { perfilMap[p.id] = p })
      }

      // Race condition guard
      if (fetchId !== fetchIdRef.current) return

      const parcelsWithResident = parcelsData.map(p => {
        const resId = p.resident_id as string | undefined
        const perfil = resId && perfilMap[resId] ? perfilMap[resId] : null
        return {
          ...p,
          perfil: perfil ?? (resId && !isUUID(resId) ? { id: resId, nome_completo: resId, bloco_txt: (p.bloco as string) || null, apto_txt: (p.apto as string) || null } : null),
        }
      }) as Parcel[]

      setParcels(parcelsWithResident)
      // Infer hasMore: if we got exactly PER_PAGE items, there are likely more pages
      setHasMore(parcelsWithResident.length === PER_PAGE)

      // ── 2. Stats RPC (background, non-blocking) ─────────────────────────
      // Data is already rendered. Stats update counters asynchronously.
      // On cold start, the RPC may take 3-22s; on warm cache, 196ms.
      if (fetchStats) {
        supabase.rpc('get_encomendas_stats', {
          p_condominio_id: condoId,
          p_bloco: bloco || null,
          p_apto: apto || null,
        }).then(({ data: statsData, error: statsError }) => {
          // Race condition guard
          if (fetchId !== fetchIdRef.current) return

          if (statsError) {
            console.error('❌ stats RPC error:', {
              code: statsError.code,
              message: statsError.message,
              details: statsError.details,
              hint: statsError.hint,
            })
            // Stats failure is non-fatal: data already loaded, pagination uses hasMore fallback
            setTotalKnown(false)
            return
          }

          const s = statsData?.[0]
          if (s) {
            const rpcPending = Number(s.pending) || 0
            const rpcDelivered = Number(s.delivered) || 0
            const rpcTotal = Number(s.total) || 0

            setPendingStat(rpcPending)
            setDeliveredStat(rpcDelivered)

            // Derive totalFiltered based on active status filter
            switch (status) {
              case 'pending':  setTotalFiltered(rpcPending); break
              case 'delivered': setTotalFiltered(rpcDelivered); break
              default:         setTotalFiltered(rpcTotal); break
            }
            setTotalKnown(true)
          }
        })
      }
    } catch (err) {
      console.error('❌ fetchParcels unexpected error:', err instanceof Error ? err.message : err)
      setFetchError('Erro inesperado ao carregar encomendas. Tente novamente.')
    } finally {
      if (fetchId === fetchIdRef.current) setLoading(false)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [condoId])

  // Track previous filter values to detect structural changes vs page-only changes
  const prevFiltersRef = useRef({ status: statusFilter, bloco: blocoFilter, apto: aptoFilter })

  // Fetch on mount and filter change (porter/admin mode)
  useEffect(() => {
    if (isPorter) {
      const prev = prevFiltersRef.current
      const filtersChanged = prev.status !== statusFilter || prev.bloco !== blocoFilter || prev.apto !== aptoFilter
      prevFiltersRef.current = { status: statusFilter, bloco: blocoFilter, apto: aptoFilter }

      // Fetch stats on initial load or filter change; skip stats on page-only change
      const needStats = filtersChanged || page === 1
      fetchParcels(statusFilter, blocoFilter, aptoFilter, page, needStats)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [statusFilter, blocoFilter, aptoFilter, page, isPorter])

  // ── Compute display data ──────────────────────────────────────────────────

  // Porter mode: parcels state already contains server-filtered + paginated results
  // Resident mode: client-side filtering from initialParcels
  const filtered = isPorter
    ? parcels
    : parcels.filter(p => {
        if (statusFilter === 'pending'   && p.status !== 'pending')   return false
        if (statusFilter === 'delivered' && p.status !== 'delivered') return false
        if (blocoFilter && (p.bloco ?? p.perfil?.bloco_txt) !== blocoFilter) return false
        if (aptoFilter  && (p.apto ?? p.perfil?.apto_txt)  !== aptoFilter)  return false
        return true
      })

  // Pagination: when totalKnown, use exact count; otherwise use hasMore heuristic
  const totalPages = isPorter
    ? (totalKnown ? Math.max(1, Math.ceil(totalFiltered / PER_PAGE)) : (hasMore ? page + 1 : page))
    : Math.max(1, Math.ceil(filtered.length / PER_PAGE))

  // Clamp page if totalFiltered drops below current page (e.g. stats updated or concurrent changes)
  useEffect(() => {
    if (isPorter && totalKnown && totalPages > 0 && page > totalPages) {
      setPage(totalPages)
    }
  }, [isPorter, totalKnown, totalPages, page])

  const paginated = isPorter
    ? filtered  // Already paginated from server
    : filtered.slice((page - 1) * PER_PAGE, page * PER_PAGE)

  const pending   = isPorter ? pendingStat   : parcels.filter(p => p.status === 'pending').length
  const delivered  = isPorter ? deliveredStat : parcels.filter(p => p.status === 'delivered').length
  const total      = isPorter ? (pendingStat + deliveredStat) : parcels.length

  // ── Post-discharge page recalculation & refresh ───────────────────────────

  function refreshAfterDischarge() {
    if (!isPorter) return

    let targetPage = page
    if (statusFilter === 'pending') {
      const currentCount = totalKnown ? totalFiltered : ((page - 1) * PER_PAGE + parcels.length)
      const newTotal = Math.max(0, currentCount - 1)
      const maxValidPage = Math.max(1, Math.ceil(newTotal / PER_PAGE))
      if (page > maxValidPage) {
        targetPage = maxValidPage
      }
    }

    if (targetPage !== page) {
      setPage(targetPage)
    } else {
      fetchParcels(statusFilter, blocoFilter, aptoFilter, targetPage)
    }
  }

  // ── Dar Baixa confirm ──────────────────────────────────────────────────────

  async function handleDeliveryConfirm(
    parcel: Parcel,
    pickedById: string | null,
    pickedByName: string
  ) {
    const now = new Date().toISOString()
    const { error } = await supabase
      .from('encomendas')
      .update({
        status: 'delivered',
        picked_up_by_id: pickedById,
        picked_up_by_name: pickedByName || null,
        discharged_by: userId,
      })
      .eq('id', parcel.id)

    if (error) {
      alert('Erro ao dar baixa: ' + error.message)
      return
    }

    // Optimistic update in local state + refresh from server for porter mode
    setParcels(prev => prev.map(p =>
      p.id === parcel.id
        ? { ...p, status: 'delivered', delivery_time: now, picked_up_by_id: pickedById, picked_up_by_name: pickedByName }
        : p
    ))
    setDeliveryModal(null)

    // Refresh stats from server in porter mode with page validation
    if (isPorter) {
      refreshAfterDischarge()
    }
  }

  // ── Silent Discharge (Baixa Silenciosa) ─────────────────────────────────────

  async function handleSilentDischarge(parcel: Parcel) {
    const now = new Date().toISOString()
    const { error } = await supabase
      .from('encomendas')
      .update({
        status: 'delivered',
        silent_discharge: true,
        discharged_by: userId,
      })
      .eq('id', parcel.id)

    if (error) {
      alert('Erro ao dar baixa silenciosa: ' + error.message)
      return
    }

    // Optimistic update
    setParcels(prev => prev.map(p =>
      p.id === parcel.id
        ? { ...p, status: 'delivered', delivery_time: now }
        : p
    ))
    setSilentDischargeModal(null)

    if (isPorter) {
      refreshAfterDischarge()
    }
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <>
      {/* Photo lightbox */}
      {photoModal && (
        <div className="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4" onClick={() => setPhotoModal(null)}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={photoModal} alt="Foto da encomenda" className="max-w-full max-h-full rounded-2xl shadow-2xl" />
          <button className="absolute top-4 right-4 text-white p-2 bg-white/10 rounded-xl hover:bg-white/20" title="Fechar foto" onClick={() => setPhotoModal(null)}>
            <X size={22} />
          </button>
        </div>
      )}

      {/* Delivery modal */}
      {deliveryModal && (
        <DeliveryModal
          parcel={deliveryModal}
          condoId={condoId}
          tipoEstrutura={tipoEstrutura}
          onClose={() => setDeliveryModal(null)}
          onConfirm={handleDeliveryConfirm}
        />
      )}

      {/* Silent discharge confirmation modal */}
      {silentDischargeModal && (
        <SilentDischargeModal
          parcel={silentDischargeModal}
          tipoEstrutura={tipoEstrutura}
          onClose={() => setSilentDischargeModal(null)}
          onConfirm={handleSilentDischarge}
        />
      )}

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        {[
          { label: 'Total', value: total, color: 'text-gray-900' },
          { label: 'Aguardando', value: pending, color: 'text-[#FC5931]' },
          { label: 'Entregues', value: delivered, color: 'text-green-600' },
        ].map(s => (
          <div key={s.label} className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 text-center">
            <p className="text-xs text-gray-500 mb-1">{s.label}</p>
            <p className={`text-2xl font-bold ${s.color}`}>{s.value}</p>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 mb-5">
        <div className="flex rounded-xl border border-gray-200 overflow-hidden bg-white shadow-sm">
          {(['all', 'pending', 'delivered'] as const).map(f => (
            <button
              key={f}
              onClick={() => { setStatusFilter(f); setPage(1) }}
              className={`px-4 py-2 text-sm font-medium transition-colors ${
                statusFilter === f ? 'bg-[#FC5931] text-white' : 'text-gray-500 hover:bg-gray-50'
              }`}
            >
              {f === 'all' ? '• Todos' : f === 'pending' ? 'Aguardando' : 'Entregues'}
            </button>
          ))}
        </div>

        {isPorter && (
          <>
            <select
              value={blocoFilter}
              onChange={e => { setBlocoFilter(e.target.value); setAptoFilter(''); setPage(1) }}
              aria-label="Filtrar por bloco"
              className="px-3 py-2 border border-gray-200 rounded-xl text-sm bg-white shadow-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]"
            >
              <option value="">{getBlocoLabel(tipoEstrutura)}</option>
              {[...uniqueBlocos].sort((a, b) => a.localeCompare(b, 'pt', { numeric: true })).map(b => <option key={b} value={b}>{b}</option>)}
            </select>
            <select
              value={aptoFilter}
              onChange={e => { setAptoFilter(e.target.value); setPage(1) }}
              aria-label="Filtrar por apartamento"
              className="px-3 py-2 border border-gray-200 rounded-xl text-sm bg-white shadow-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]"
            >
              <option value="">{getAptoLabel(tipoEstrutura)}</option>
              {[...uniqueAptos].sort((a, b) => a.localeCompare(b, 'pt', { numeric: true })).map(a => <option key={a} value={a}>{a}</option>)}
            </select>
          </>
        )}

        <div className="ml-auto flex items-center gap-2 text-xs text-gray-400">
          {loading ? (
            <Loader2 size={12} className="animate-spin" />
          ) : (
            <RefreshCw size={12} />
          )}
          {isPorter ? totalFiltered : filtered.length} encomenda{(isPorter ? totalFiltered : filtered.length) !== 1 ? 's' : ''}
        </div>
      </div>

      {/* Loading overlay */}
      {loading ? (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-12 text-center">
          <Loader2 size={32} className="text-[#FC5931] mx-auto mb-3 animate-spin" />
          <p className="text-gray-400 text-sm">Carregando encomendas...</p>
        </div>
      ) : fetchError ? (
        <div className="bg-white rounded-2xl border border-red-100 shadow-sm p-12 text-center">
          <AlertTriangle size={40} className="text-red-300 mx-auto mb-3" />
          <p className="text-red-500 text-sm font-medium">{fetchError}</p>
          <button
            onClick={() => fetchParcels(statusFilter, blocoFilter, aptoFilter, page, true)}
            className="mt-4 px-4 py-2 text-xs font-medium text-[#FC5931] border border-[#FC5931] rounded-xl hover:bg-orange-50 transition-colors"
          >
            Tentar novamente
          </button>
        </div>
      ) : paginated.length === 0 ? (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-12 text-center">
          <Package size={40} className="text-gray-200 mx-auto mb-3" />
          <p className="text-gray-400 text-sm">Nenhuma encomenda encontrada.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {paginated.map(p => {
            const info = TIPO_LABELS[p.tipo ?? ''] ?? TIPO_LABELS['pacote']
            const Icon = info.icon
            const isDelivered = p.status === 'delivered'

            return (
              <div
                key={p.id}
                className={`bg-white rounded-2xl border shadow-sm overflow-hidden transition-all ${
                  isDelivered ? 'border-gray-100 opacity-80' : 'border-gray-100 hover:shadow-md'
                }`}
              >
                {/* Card header */}
                <div className={`flex items-center justify-between px-5 py-3 ${
                  isDelivered ? 'bg-green-50' : 'bg-[#FC5931]'
                }`}>
                  <div className="flex items-center gap-3">
                    <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${
                      isDelivered ? 'bg-green-100' : 'bg-white/15'
                    }`}>
                      <Icon size={17} className={isDelivered ? 'text-green-600' : 'text-white'} />
                    </div>
                    <div>
                      <p className={`font-bold text-sm ${isDelivered ? 'text-gray-900' : 'text-white'}`}>
                        {getBlocoLabel(tipoEstrutura)} {p.bloco ?? p.perfil?.bloco_txt ?? '?'} / {getAptoLabel(tipoEstrutura)} {p.apto ?? p.perfil?.apto_txt ?? '?'}
                      </p>
                      <p className={`text-xs ${isDelivered ? 'text-gray-500' : 'text-white/70'}`}>
                        {p.perfil?.nome_completo ?? 'Sem morador'}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${info.color}`}>
                      {info.label}
                    </span>
                  </div>
                </div>

                {/* Card body */}
                <div className="px-5 py-4">
                  {/* Top row: info on left, photos on right */}
                  <div className="flex gap-4">
                    {/* Left: arrival info, tracking, obs */}
                    <div className="flex-1 grid grid-cols-2 gap-x-6 gap-y-2 text-sm">
                      <div>
                        <p className="text-xs text-gray-400 mb-0.5">Chegada</p>
                        <p suppressHydrationWarning className="font-medium text-gray-700">{mounted ? fmt(p.arrival_time) : '—'}</p>
                      </div>
                      {p.tracking_code && (
                        <div>
                          <p className="text-xs text-gray-400 mb-0.5">Rastreio</p>
                          <p className="font-mono text-gray-700 text-xs">{p.tracking_code}</p>
                        </div>
                      )}
                      {p.observacao && (
                        <div className="col-span-2">
                          <p className="text-xs text-gray-400 mb-0.5">Observação</p>
                          <p className="text-gray-700">{p.observacao}</p>
                        </div>
                      )}
                    </div>

                    {/* Right: photo + signature thumbnails – stacked on mobile, side by side on ≥860px */}
                    <div className="flex flex-col min-[860px]:flex-row gap-1.5 shrink-0">
                      {/* Photo thumbnail */}
                      <button
                        onClick={() => p.photo_url ? setPhotoModal(p.photo_url) : null}
                        className={`w-14 h-14 rounded-xl overflow-hidden border-2 transition-colors shadow-sm flex items-center justify-center ${
                          p.photo_url ? 'border-gray-200 hover:border-[#FC5931]' : 'border-dashed border-gray-200 bg-gray-50'
                        }`}
                        title={p.photo_url ? 'Ver foto da encomenda' : 'Sem foto'}
                      >
                        {p.photo_url ? (
                          /* eslint-disable-next-line @next/next/no-img-element */
                          <img src={p.photo_url} alt="Foto" className="w-full h-full object-cover" />
                        ) : (
                          <Camera size={18} className="text-gray-300" />
                        )}
                      </button>

                      {/* Signature thumbnail (only for delivered) */}
                      {isDelivered && (
                        <button
                          onClick={() => p.pickup_proof_url ? setPhotoModal(p.pickup_proof_url) : null}
                          className={`w-14 h-14 rounded-xl overflow-hidden border-2 transition-colors shadow-sm flex items-center justify-center ${
                            p.pickup_proof_url ? 'border-green-200 hover:border-green-500' : 'border-dashed border-gray-200 bg-gray-50'
                          }`}
                          title={p.pickup_proof_url ? 'Ver assinatura' : 'Sem assinatura'}
                        >
                          {p.pickup_proof_url ? (
                            /* eslint-disable-next-line @next/next/no-img-element */
                            <img src={p.pickup_proof_url} alt="Assinatura" className="w-full h-full object-cover" />
                          ) : (
                            <PenTool size={18} className="text-gray-300" />
                          )}
                        </button>
                      )}
                    </div>
                  </div>

                  {/* Bottom row: status + buttons */}
                  <div className="flex items-end justify-between gap-3 mt-3">
                    <div className="flex-1">
                      {isDelivered ? (
                        <div className="space-y-1.5">
                          <div className="flex items-center gap-1.5 text-green-600 text-sm font-medium">
                            <CheckCircle2 size={15} />
                            <span suppressHydrationWarning>Retirado {mounted && p.delivery_time ? fmt(p.delivery_time) : ''}</span>
                          </div>
                          {(p.picked_up_by_name || p.picked_up_by_id) && (
                            <div className="inline-flex items-center gap-1.5 bg-green-50 border border-green-200 rounded-lg px-2.5 py-1">
                              <UserCheck size={13} className="text-green-600 shrink-0" />
                              <span className="text-xs font-semibold text-green-700">
                                {p.picked_up_by_id
                                  ? (p.picked_up_by_name ? `Morador: ${p.picked_up_by_name}` : 'Morador')
                                  : `Terceiro: ${p.picked_up_by_name}`}
                              </span>
                            </div>
                          )}
                        </div>
                      ) : (
                        <div className="flex items-center gap-1.5 text-[#FC5931] text-sm font-medium">
                          <Clock size={15} />
                          <span>Aguardando retirada</span>
                        </div>
                      )}
                    </div>

                    {/* Buttons stacked vertically (same width) */}
                    {!isDelivered && isPorter && (
                      <div className="flex flex-col gap-1.5 shrink-0" style={{ minWidth: '140px' }}>
                        <button
                          onClick={() => setDeliveryModal(p)}
                          className="flex items-center justify-center gap-1.5 bg-green-600 hover:bg-green-700 text-white text-xs font-semibold w-full py-2 rounded-xl transition-colors shadow-sm"
                        >
                          <UserCheck size={14} />
                          Dar Baixa
                        </button>
                        <button
                          onClick={() => setSilentDischargeModal(p)}
                          title="Baixa silenciosa (sem notificar morador)"
                          className="flex items-center justify-center gap-1.5 bg-amber-500 hover:bg-amber-600 text-white text-xs font-semibold w-full py-2 rounded-xl transition-colors shadow-sm"
                        >
                          <PackageCheck size={14} />
                          Baixa Silenciosa
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Pagination */}
      {(isPorter ? (totalKnown ? totalPages > 1 : hasMore || page > 1) : totalPages > 1) && (
        <div className="flex items-center justify-center gap-2 mt-6">
          <button
            disabled={page === 1}
            onClick={() => setPage(p => p - 1)}
            className="px-4 py-2 border border-gray-200 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-40 transition-colors"
          >
            Anterior
          </button>
          <span className="text-sm text-gray-500">
            {isPorter && !totalKnown ? `Página ${page}` : `${page} / ${totalPages}`}
          </span>
          <button
            disabled={isPorter ? (!totalKnown ? !hasMore : page >= totalPages) : page >= totalPages}
            onClick={() => setPage(p => p + 1)}
            className="px-4 py-2 border border-gray-200 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-40 transition-colors"
          >
            Próxima
          </button>
        </div>
      )}
    </>
  )
}
