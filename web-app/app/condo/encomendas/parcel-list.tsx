'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Package, CheckCircle2, Clock, Eye, X, Loader2,
  Box, Mail, ShoppingBag, FileText, ChevronDown, UserCheck, RefreshCw
} from 'lucide-react'

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
  picked_up_by_id: string | null
  picked_up_by_name: string | null
  condominio_id: string
  perfil: Perfil | null
}

interface Props {
  initialParcels: Parcel[]
  isPorter: boolean
  userId: string
  condoId: string
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

// ── Delivery Modal ────────────────────────────────────────────────────────────

interface DeliveryModalProps {
  parcel: Parcel
  condoId: string
  onClose: () => void
  onConfirm: (parcel: Parcel, pickedById: string | null, pickedByName: string) => Promise<void>
}

function DeliveryModal({ parcel, condoId, onClose, onConfirm }: DeliveryModalProps) {
  const supabase = createClient()
  const [residents, setResidents] = useState<Perfil[]>([])
  const [loadingResidents, setLoadingResidents] = useState(true)
  const [pickedById, setPickedById] = useState<string | null>(null)
  const [thirdPartyName, setThirdPartyName] = useState('')
  const [isThirdParty, setIsThirdParty] = useState(false)
  const [confirming, setConfirming] = useState(false)

  const bloco = parcel.perfil?.bloco_txt ?? null
  const apto  = parcel.perfil?.apto_txt  ?? null

  // Fetch residents of this unit
  useEffect(() => {
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
      setResidents(data ?? [])
      if (data && data.length === 1) setPickedById(data[0].id)
      setLoadingResidents(false)
    }
    load()
  }, [bloco, apto, condoId])

  const tipoInfo = TIPO_LABELS[parcel.tipo ?? ''] ?? TIPO_LABELS['pacote']
  const TipoIcon = tipoInfo.icon

  async function handleConfirm() {
    if (!isThirdParty && !pickedById) return
    if (isThirdParty && !thirdPartyName.trim()) return
    setConfirming(true)
    await onConfirm(
      parcel,
      isThirdParty ? null : pickedById,
      isThirdParty ? thirdPartyName.trim() : (residents.find(r => r.id === pickedById)?.nome_completo ?? '')
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
          <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors">
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
                Bloco {bloco ?? '?'} / Apto {apto ?? '?'}
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
                  onChange={e => {
                    setPickedById(e.target.value || null)
                    setIsThirdParty(false)
                  }}
                  disabled={isThirdParty}
                  className="w-full px-4 py-3 pr-10 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26] appearance-none bg-white disabled:opacity-50"
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
                  setIsThirdParty(e.target.checked)
                  if (e.target.checked) setPickedById(null)
                }}
                className="rounded border-gray-300 text-[#E85D26] focus:ring-[#E85D26]"
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
                className="w-full px-4 py-3 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26] bg-gray-50"
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

// ── Main List ─────────────────────────────────────────────────────────────────

export default function ParcelList({ initialParcels, isPorter, condoId }: Props) {
  const supabase = createClient()

  const [parcels, setParcels] = useState<Parcel[]>(initialParcels)
  const [statusFilter, setStatusFilter] = useState<'all' | 'pending' | 'delivered'>('all')
  const [blocoFilter, setBlocoFilter] = useState('')
  const [aptoFilter, setAptoFilter] = useState('')
  const [page, setPage] = useState(1)
  const [photoModal, setPhotoModal] = useState<string | null>(null)
  const [deliveryModal, setDeliveryModal] = useState<Parcel | null>(null)

  const PER_PAGE = 10

  // Derived
  const uniqueBlocos = [...new Set(
    parcels.map(p => p.perfil?.bloco_txt).filter(Boolean) as string[]
  )].sort()
  const uniqueAptos = [...new Set(
    parcels
      .filter(p => !blocoFilter || p.perfil?.bloco_txt === blocoFilter)
      .map(p => p.perfil?.apto_txt)
      .filter(Boolean) as string[]
  )].sort((a, b) => a.localeCompare(b, 'pt', { numeric: true }))

  const filtered = parcels.filter(p => {
    if (statusFilter === 'pending'   && p.status !== 'pending')   return false
    if (statusFilter === 'delivered' && p.status !== 'delivered') return false
    if (blocoFilter && p.perfil?.bloco_txt !== blocoFilter) return false
    if (aptoFilter  && p.perfil?.apto_txt  !== aptoFilter)  return false
    return true
  })

  const totalPages = Math.max(1, Math.ceil(filtered.length / PER_PAGE))
  const paginated  = filtered.slice((page - 1) * PER_PAGE, page * PER_PAGE)

  const pending   = parcels.filter(p => p.status === 'pending').length
  const delivered = parcels.filter(p => p.status === 'delivered').length

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
        delivery_time: now,
        picked_up_by_id: pickedById,
        picked_up_by_name: pickedByName || null,
      })
      .eq('id', parcel.id)

    if (error) {
      alert('Erro ao dar baixa: ' + error.message)
      return
    }

    setParcels(prev => prev.map(p =>
      p.id === parcel.id
        ? { ...p, status: 'delivered', delivery_time: now, picked_up_by_id: pickedById, picked_up_by_name: pickedByName }
        : p
    ))
    setDeliveryModal(null)
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <>
      {/* Photo lightbox */}
      {photoModal && (
        <div className="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4" onClick={() => setPhotoModal(null)}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={photoModal} alt="Foto da encomenda" className="max-w-full max-h-full rounded-2xl shadow-2xl" />
          <button className="absolute top-4 right-4 text-white p-2 bg-white/10 rounded-xl hover:bg-white/20" onClick={() => setPhotoModal(null)}>
            <X size={22} />
          </button>
        </div>
      )}

      {/* Delivery modal */}
      {deliveryModal && (
        <DeliveryModal
          parcel={deliveryModal}
          condoId={condoId}
          onClose={() => setDeliveryModal(null)}
          onConfirm={handleDeliveryConfirm}
        />
      )}

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        {[
          { label: 'Total', value: parcels.length, color: 'text-gray-900' },
          { label: 'Aguardando', value: pending, color: 'text-[#E85D26]' },
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
                statusFilter === f ? 'bg-[#E85D26] text-white' : 'text-gray-500 hover:bg-gray-50'
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
              className="px-3 py-2 border border-gray-200 rounded-xl text-sm bg-white shadow-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26]"
            >
              <option value="">Bloco</option>
              {uniqueBlocos.map(b => <option key={b} value={b}>{b}</option>)}
            </select>
            <select
              value={aptoFilter}
              onChange={e => { setAptoFilter(e.target.value); setPage(1) }}
              className="px-3 py-2 border border-gray-200 rounded-xl text-sm bg-white shadow-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26]"
            >
              <option value="">Apto</option>
              {uniqueAptos.map(a => <option key={a} value={a}>{a}</option>)}
            </select>
          </>
        )}

        <div className="ml-auto flex items-center gap-2 text-xs text-gray-400">
          <RefreshCw size={12} />
          {filtered.length} encomenda{filtered.length !== 1 ? 's' : ''}
        </div>
      </div>

      {/* List */}
      {paginated.length === 0 ? (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-12 text-center">
          <Package size={40} className="text-gray-200 mx-auto mb-3" />
          <p className="text-gray-400 text-sm">Nenhuma encomenda encontrada.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {paginated.map(p => {
            const info = TIPO_LABELS[p.tipo ?? ''] ?? TIPO_LABELS['pacote']
            const Icon = info.icon
            const delivered = p.status === 'delivered'

            return (
              <div
                key={p.id}
                className={`bg-white rounded-2xl border shadow-sm overflow-hidden transition-all ${
                  delivered ? 'border-gray-100 opacity-80' : 'border-gray-100 hover:shadow-md'
                }`}
              >
                {/* Card header */}
                <div className={`flex items-center justify-between px-5 py-3 ${
                  delivered ? 'bg-green-50' : 'bg-[#E85D26]'
                }`}>
                  <div className="flex items-center gap-3">
                    <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${
                      delivered ? 'bg-green-100' : 'bg-white/15'
                    }`}>
                      <Icon size={17} className={delivered ? 'text-green-600' : 'text-white'} />
                    </div>
                    <div>
                      <p className={`font-bold text-sm ${delivered ? 'text-gray-900' : 'text-white'}`}>
                        Bloco {p.perfil?.bloco_txt ?? '?'} / Apto {p.perfil?.apto_txt ?? '?'}
                      </p>
                      <p className={`text-xs ${delivered ? 'text-gray-500' : 'text-white/70'}`}>
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
                  <div className="grid grid-cols-2 gap-x-6 gap-y-2 text-sm mb-3">
                    <div>
                      <p className="text-xs text-gray-400 mb-0.5">Chegada</p>
                      <p className="font-medium text-gray-700">{fmt(p.arrival_time)}</p>
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

                  {/* Status row */}
                  <div className="flex items-end justify-between gap-3 mt-1">
                    <div className="flex-1">
                      {delivered ? (
                        <div className="space-y-1.5">
                          <div className="flex items-center gap-1.5 text-green-600 text-sm font-medium">
                            <CheckCircle2 size={15} />
                            <span>Retirado {p.delivery_time ? fmt(p.delivery_time) : ''}</span>
                          </div>
                          {(p.picked_up_by_name) && (
                            <div className="inline-flex items-center gap-1.5 bg-green-50 border border-green-200 rounded-lg px-2.5 py-1">
                              <UserCheck size={13} className="text-green-600 flex-shrink-0" />
                              <span className="text-xs font-semibold text-green-700">{p.picked_up_by_name}</span>
                            </div>
                          )}
                        </div>
                      ) : (
                        <div className="flex items-center gap-1.5 text-[#E85D26] text-sm font-medium">
                          <Clock size={15} />
                          <span>Aguardando retirada</span>
                        </div>
                      )}
                    </div>

                    {/* Right side: photo thumbnail + dar baixa */}
                    <div className="flex items-center gap-2 flex-shrink-0">
                      {p.photo_url && (
                        <button
                          onClick={() => setPhotoModal(p.photo_url!)}
                          className="w-14 h-14 rounded-xl overflow-hidden border-2 border-gray-200 hover:border-[#E85D26] transition-colors shadow-sm flex-shrink-0"
                          title="Ver foto da encomenda"
                        >
                          {/* eslint-disable-next-line @next/next/no-img-element */}
                          <img
                            src={p.photo_url}
                            alt="Foto"
                            className="w-full h-full object-cover"
                          />
                        </button>
                      )}
                      {!delivered && isPorter && (
                        <button
                          onClick={() => setDeliveryModal(p)}
                          className="flex items-center gap-1.5 bg-green-600 hover:bg-green-700 text-white text-xs font-semibold px-4 py-2 rounded-xl transition-colors shadow-sm"
                        >
                          <UserCheck size={14} />
                          Dar Baixa
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2 mt-6">
          <button
            disabled={page === 1}
            onClick={() => setPage(p => p - 1)}
            className="px-4 py-2 border border-gray-200 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-40 transition-colors"
          >
            Anterior
          </button>
          <span className="text-sm text-gray-500">{page} / {totalPages}</span>
          <button
            disabled={page === totalPages}
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
