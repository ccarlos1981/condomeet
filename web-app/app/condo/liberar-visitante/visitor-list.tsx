'use client'
import { useState, useEffect, useTransition } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { RefreshCw, Filter, ChevronLeft, ChevronRight, CheckCircle2 } from 'lucide-react'

interface PerfilJoin {
  nome_completo: string
  bloco_txt: string | null
  apto_txt: string | null
}

interface Invitation {
  id: string
  qr_data: string | null
  guest_name: string | null
  visitor_type: string | null
  visitante_compareceu: boolean | number
  validity_date: string
  created_at: string
  liberado_em: string | null
  status: string | null
  perfil: PerfilJoin | null
}

interface Props {
  initialInvitations: Invitation[]
  condoId: string
  userId: string
  initialLimit?: number
}

const PAGE_SIZE = 5

export default function VisitorList({ initialInvitations, condoId, userId, initialLimit }: Props) {
  const [invitations, setInvitations] = useState<Invitation[]>(initialInvitations)
  const [filtered, setFiltered] = useState<Invitation[]>(initialInvitations)
  const [approving, setApproving] = useState<string | null>(null)
  const [isPending, startTransition] = useTransition()
  const [loading, setLoading] = useState(false)
  const [loadedAll, setLoadedAll] = useState(!initialLimit)
  const [loadingMore, setLoadingMore] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  // Filters
  const [fCode, setFCode] = useState('')
  const [fBloco, setFBloco] = useState('')
  const [fApto, setFApto] = useState('')
  const [fDate, setFDate] = useState('')
  const [fStatus, setFStatus] = useState<null | boolean>(null)

  // Pagination
  const [page, setPage] = useState(1)
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const paginated = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  // Apply filters locally
  useEffect(() => {
    let result = invitations
    if (fCode) result = result.filter(i => i.qr_data?.toLowerCase().includes(fCode.toLowerCase()))
    if (fBloco) result = result.filter(i => i.perfil?.bloco_txt?.toLowerCase().includes(fBloco.toLowerCase()))
    if (fApto) result = result.filter(i => i.perfil?.apto_txt?.toLowerCase().includes(fApto.toLowerCase()))
    if (fDate) result = result.filter(i => i.validity_date?.startsWith(fDate))
    if (fStatus !== null) result = result.filter(i => Boolean(i.visitante_compareceu) === fStatus)
    setFiltered(result)
    setPage(1)
  }, [invitations, fCode, fBloco, fApto, fDate, fStatus])

  async function handleApprove(inv: Invitation) {
    if (Boolean(inv.visitante_compareceu)) return
    setApproving(inv.id)
    await supabase
      .from('convites')
      .update({
        visitante_compareceu: 1,
        liberado_por: userId,
        liberado_em: new Date().toISOString(),
      })
      .eq('id', inv.id)
    // Refresh via router (re-fetches server component data)
    startTransition(() => router.refresh())
    // Optimistic update local state
    setInvitations(prev =>
      prev.map(i => i.id === inv.id ? { ...i, visitante_compareceu: 1, liberado_em: new Date().toISOString() } : i)
    )
    setApproving(null)
  }

  const handleRefresh = () => {
    setLoading(true)
    startTransition(() => {
      router.refresh()
      setLoading(false)
    })
  }

  const isLiberado = (inv: Invitation) => Boolean(inv.visitante_compareceu)
  const statusCycle = () => setFStatus(prev => prev === null ? false : prev === false ? true : null)
  const statusLabel = fStatus === null ? '● Todos' : fStatus === false ? '⏳ Pendentes' : '✓ Liberados'
  const statusColor = fStatus === null
    ? 'bg-gray-100 text-gray-600 border-gray-200'
    : fStatus === false
      ? 'bg-orange-100 text-orange-700 border-orange-300'
      : 'bg-green-100 text-green-700 border-green-300'
  const hasFilters = fCode || fBloco || fApto || fDate || fStatus !== null
  const clearFilters = () => { setFCode(''); setFBloco(''); setFApto(''); setFDate(''); setFStatus(null) }

  async function handleLoadAll() {
    setLoadingMore(true)
    const { data: allConvites } = await supabase
      .from('convites')
      .select('id, qr_data, guest_name, visitor_type, visitante_compareceu, validity_date, created_at, liberado_em, resident_id, status')
      .eq('condominio_id', condoId)
      .order('created_at', { ascending: false })

    if (allConvites) {
      // Fetch perfil for all residents
      const residentIds = [...new Set(allConvites.map((c: any) => c.resident_id).filter(Boolean))]
      let perfilMap: Record<string, PerfilJoin> = {}
      if (residentIds.length > 0) {
        const { data: perfis } = await supabase
          .from('perfil')
          .select('id, nome_completo, bloco_txt, apto_txt')
          .in('id', residentIds)
        ;(perfis ?? []).forEach((p: any) => { perfilMap[p.id] = p })
      }
      const merged = allConvites.map((c: any) => ({ ...c, perfil: perfilMap[c.resident_id] ?? null }))
      setInvitations(merged)
    }
    setLoadedAll(true)
    setLoadingMore(false)
  }

  return (
    <>
      <p className="text-gray-500 text-sm mb-4">
        {filtered.length} autorização{filtered.length !== 1 ? 'ões' : ''} encontrada{filtered.length !== 1 ? 's' : ''}
      </p>

      {/* Filter bar */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 mb-5">
        <div className="flex flex-wrap gap-2 mb-3">
          {[
            { placeholder: 'Código', value: fCode, set: setFCode, width: 'w-24' },
            { placeholder: 'Bloco', value: fBloco, set: setFBloco, width: 'w-24' },
            { placeholder: 'Apto', value: fApto, set: setFApto, width: 'w-24' },
          ].map(f => (
            <input
              key={f.placeholder}
              type="text"
              placeholder={f.placeholder}
              value={f.value}
              onChange={e => f.set(e.target.value)}
              className={`${f.width} px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50`}
            />
          ))}
          <input
            type="date"
            value={fDate}
            onChange={e => setFDate(e.target.value)}
            aria-label="Filtrar por data de validade"
            title="Filtrar por data de validade"
            className="px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50"
          />

        </div>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="text-xs text-gray-500 font-medium">Status:</span>
            <button onClick={statusCycle} className={`px-3 py-1.5 text-xs font-semibold rounded-full border transition-all ${statusColor}`}>
              {statusLabel}
            </button>
            {hasFilters && (
              <button onClick={clearFilters} className="text-xs text-gray-400 hover:text-red-500 transition-colors ml-1">
                Limpar
              </button>
            )}
          </div>
          <button
            onClick={handleRefresh}
            disabled={isPending || loading}
            className="p-2 text-[#FC5931] hover:bg-[#FC5931]/10 rounded-lg transition-colors"
            title="Atualizar"
          >
            <RefreshCw size={16} className={isPending || loading ? 'animate-spin' : ''} />
          </button>
        </div>
      </div>

      {/* Cards */}
      {paginated.length === 0 ? (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm py-16 text-center">
          <Filter size={32} className="mx-auto text-gray-300 mb-3" />
          <p className="text-gray-500 font-medium">Nenhuma autorização encontrada</p>
          {hasFilters && (
            <button onClick={clearFilters} className="text-sm text-[#FC5931] hover:underline mt-2">
              Limpar filtros
            </button>
          )}
        </div>
      ) : (
        <div className="space-y-4">
          {paginated.map(inv => {
            const liberado = isLiberado(inv)
            const bloco = inv.perfil?.bloco_txt ?? '—'
            const apto = inv.perfil?.apto_txt ?? '—'
            const residentName = inv.perfil?.nome_completo ?? '—'
            return (
              <div
                key={inv.id}
                className={`bg-white rounded-2xl border shadow-sm overflow-hidden ${
                  liberado ? 'border-green-200' : 'border-orange-100'
                }`}
              >
                {/* Header */}
                <div className={`px-5 py-3 flex items-center justify-between ${liberado ? 'bg-green-500' : 'bg-[#FC5931]'}`}>
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-white/20 rounded-xl flex items-center justify-center flex-shrink-0">
                      <span className="text-white font-bold text-xs leading-tight text-center">
                        {inv.qr_data ? inv.qr_data.slice(-4).toUpperCase() : '—'}
                      </span>
                    </div>
                    <div>
                      <p className="text-white font-semibold text-sm">
                        Bloco: {bloco} / Apto: {apto}
                      </p>
                      <p className="text-white/80 text-xs">Morador(a): {residentName}</p>
                    </div>
                  </div>
                  <span className="text-xs font-bold px-3 py-1 rounded-full bg-white/20 text-white">
                    Acesso para Unidade
                  </span>
                </div>

                {/* Body */}
                <div className="px-5 py-4">
                  <div className="grid grid-cols-2 gap-x-8 gap-y-2 mb-4 text-sm">
                    <div>
                      <span className="text-xs text-gray-400 block">Solicitado para a data</span>
                      <span className="font-medium text-gray-800">
                        {inv.validity_date ? new Date(inv.validity_date + 'T00:00:00').toLocaleDateString('pt-BR') : '—'}
                      </span>
                    </div>
                    <div>
                      <span className="text-xs text-gray-400 block">Tipo de visitante</span>
                      <span className="font-medium text-gray-800">{inv.visitor_type || '—'}</span>
                    </div>
                    <div className="col-span-2">
                      <span className="text-xs text-gray-400 block">Nome Visitante</span>
                      <span className="font-medium text-gray-800">{inv.guest_name || 'Nome não preenchido'}</span>
                    </div>
                  </div>

                  {/* Approve row */}
                  <div className="flex items-center justify-between border-t border-gray-100 pt-3">
                    <div className="flex items-center gap-3">
                      <span className="text-sm text-gray-600">Visitante compareceu</span>
                      {liberado ? (
                        <span className="flex items-center gap-1.5 text-green-600 text-sm font-semibold">
                          <CheckCircle2 size={15} />
                          Confirmado
                        </span>
                      ) : (
                        <button
                          onClick={() => handleApprove(inv)}
                          disabled={approving === inv.id}
                          className="flex items-center gap-2 px-4 py-1.5 bg-[#FC5931] text-white text-sm font-semibold rounded-xl hover:bg-[#D42F1D] transition-colors disabled:opacity-60"
                        >
                          {approving === inv.id && <RefreshCw size={13} className="animate-spin" />}
                          Confirmar Entrada
                        </button>
                      )}
                    </div>
                    <div className="text-right text-xs text-gray-400 space-y-0.5">
                      <p>
                        Criado em: {new Date(inv.created_at).toLocaleDateString('pt-BR')} – {new Date(inv.created_at).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}
                      </p>
                      <p>Solicitado por: {residentName}</p>
                    </div>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Load more / Pagination */}
      {!loadedAll && !hasFilters && (
        <div className="flex justify-center mt-6">
          <button
            onClick={handleLoadAll}
            disabled={loadingMore}
            className="flex items-center gap-2 px-5 py-2.5 text-sm font-semibold text-[#FC5931] bg-[#FC5931]/10 rounded-xl hover:bg-[#FC5931]/20 transition-colors disabled:opacity-50"
          >
            {loadingMore ? (
              <RefreshCw size={14} className="animate-spin" />
            ) : (
              <ChevronRight size={14} />
            )}
            {loadingMore ? 'Carregando...' : 'Ver mais autorizações'}
          </button>
        </div>
      )}

      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-4 mt-6">
          <button
            onClick={() => setPage(p => Math.max(1, p - 1))}
            disabled={page === 1}
            aria-label="Página anterior"
            title="Página anterior"
            className="p-2 rounded-xl border border-gray-200 text-gray-500 hover:bg-gray-50 disabled:opacity-40 transition-colors"
          >
            <ChevronLeft size={16} />
          </button>
          <span className="text-sm text-gray-600 font-medium">{page} de {totalPages}</span>
          <button
            onClick={() => setPage(p => Math.min(totalPages, p + 1))}
            disabled={page === totalPages}
            aria-label="Próxima página"
            title="Próxima página"
            className="p-2 rounded-xl border border-gray-200 text-gray-500 hover:bg-gray-50 disabled:opacity-40 transition-colors"
          >
            <ChevronRight size={16} />
          </button>
        </div>
      )}
    </>
  )
}
