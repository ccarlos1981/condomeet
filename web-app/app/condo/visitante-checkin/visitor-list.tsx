'use client'
import { useState, useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'

import { RefreshCw, Filter, ChevronLeft, ChevronRight, CheckCircle2 } from 'lucide-react'
import { QRCodeSVG } from 'qrcode.react'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

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
  criado_por_portaria?: boolean
  bloco_destino?: string | null
  apto_destino?: string | null
  morador_nome_manual?: string | null
}

interface Props {
  initialInvitations: Invitation[]
  initialTotal: number
  condoId: string
  userId: string
  tipoEstrutura?: string
}

const PAGE_SIZE = 10

export default function VisitorList({ initialInvitations, initialTotal, condoId, userId, tipoEstrutura }: Props) {
  const [invitations, setInvitations] = useState<Invitation[]>(initialInvitations)
  const [total, setTotal] = useState(initialTotal)
  const [approving, setApproving] = useState<string | null>(null)
    const [loading, setLoading] = useState(false)
    const supabase = createClient()

  // Filters
  const [fCode, setFCode] = useState('')
  const [fBloco, setFBloco] = useState('')
  const [fApto, setFApto] = useState('')
  const [fDate, setFDate] = useState('')
  const [fStatus, setFStatus] = useState<null | boolean>(false)

  // Pagination
  const [page, setPage] = useState(1)
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  // Fetch from database with filters and pagination
  const fetchData = useCallback(async (currentPage: number) => {
    setLoading(true)
    try {
      // Build count query first
      let countQuery = supabase
        .from('convites')
        .select('id', { count: 'exact', head: true })
        .eq('condominio_id', condoId)

      // Build data query
      let dataQuery = supabase
        .from('convites')
        .select('id, qr_data, guest_name, visitor_type, visitante_compareceu, validity_date, created_at, liberado_em, resident_id, status, criado_por_portaria, bloco_destino, apto_destino, morador_nome_manual')
        .eq('condominio_id', condoId)
        .order('created_at', { ascending: false })
        .range((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE - 1)

      // Apply filters
      if (fCode) {
        countQuery = countQuery.ilike('qr_data', `%${fCode}%`)
        dataQuery = dataQuery.ilike('qr_data', `%${fCode}%`)
      }
      if (fDate) {
        countQuery = countQuery.gte('validity_date', `${fDate}T00:00:00`).lte('validity_date', `${fDate}T23:59:59`)
        dataQuery = dataQuery.gte('validity_date', `${fDate}T00:00:00`).lte('validity_date', `${fDate}T23:59:59`)
      }
      if (fStatus !== null) {
        countQuery = countQuery.eq('visitante_compareceu', fStatus)
        dataQuery = dataQuery.eq('visitante_compareceu', fStatus)
      }

      // Note: bloco/apto filters need special handling since they can be in perfil or bloco_destino
      // We filter by bloco_destino/apto_destino for portaria-created, and join for resident-created
      if (fBloco) {
        countQuery = countQuery.or(`bloco_destino.ilike.%${fBloco}%`)
        dataQuery = dataQuery.or(`bloco_destino.ilike.%${fBloco}%`)
      }
      if (fApto) {
        countQuery = countQuery.or(`apto_destino.ilike.%${fApto}%`)
        dataQuery = dataQuery.or(`apto_destino.ilike.%${fApto}%`)
      }

      const [{ count }, { data: convites }] = await Promise.all([countQuery, dataQuery])

      if (convites) {
        // Fetch perfil for residents
        const residentIds = [...new Set(convites.map((c: { resident_id: string }) => c.resident_id).filter(Boolean))]
        const perfilMap: Record<string, PerfilJoin> = {}
        if (residentIds.length > 0) {
          const { data: perfis } = await supabase
            .from('perfil')
            .select('id, nome_completo, bloco_txt, apto_txt')
            .in('id', residentIds)
          ;(perfis ?? []).forEach((p: { id: string; nome_completo: string; bloco_txt: string | null; apto_txt: string | null }) => { perfilMap[p.id] = p })
        }
        const merged = convites.map((c: Omit<Invitation, 'perfil'> & { resident_id: string }) => ({ ...c, perfil: perfilMap[c.resident_id] ?? null }))

        // Client-side filter by bloco/apto from perfil for non-portaria convites
        let finalResults = merged
        if (fBloco) {
          finalResults = finalResults.filter((i: Invitation) => {
            const b = i.criado_por_portaria ? i.bloco_destino : i.perfil?.bloco_txt
            return b?.toLowerCase().includes(fBloco.toLowerCase()) ?? false
          })
        }
        if (fApto) {
          finalResults = finalResults.filter((i: Invitation) => {
            const a = i.criado_por_portaria ? i.apto_destino : i.perfil?.apto_txt
            return a?.toLowerCase().includes(fApto.toLowerCase()) ?? false
          })
        }

        setInvitations(finalResults)
        setTotal(count ?? finalResults.length)
      }
    } catch (err) {
      console.error('Fetch error:', err)
    } finally {
      setLoading(false)
    }
  }, [condoId, fCode, fBloco, fApto, fDate, fStatus, supabase])

  // Debounced fetch on filter/page change
  useEffect(() => {
    const timer = setTimeout(() => {
      fetchData(page)
    }, 300)
    return () => clearTimeout(timer)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, fCode, fBloco, fApto, fDate, fStatus])

  // Reset page when filters change
  useEffect(() => {
    setPage(1)
  }, [fCode, fBloco, fApto, fDate, fStatus])

  // Supabase Realtime: auto-refresh when convites change
  useEffect(() => {
    const channel = supabase
      .channel('realtime_convites_web')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'convites',
          filter: `condominio_id=eq.${condoId}`,
        },
        () => {
          fetchData(page)
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [condoId, page, fCode, fBloco, fApto, fDate, fStatus])

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
    // Optimistic update local state
    setInvitations(prev =>
      prev.map(i => i.id === inv.id ? { ...i, visitante_compareceu: 1, liberado_em: new Date().toISOString() } : i)
    )
    setApproving(null)
  }

  const handleRefresh = () => {
    fetchData(page)
  }

  const isLiberado = (inv: Invitation) => Boolean(inv.visitante_compareceu)
  const statusOptions: { value: null | boolean; label: string }[] = [
    { value: null, label: '● Todos' },
    { value: false, label: '⏳ Pendentes' },
    { value: true, label: '✓ Liberados' },
  ]
  const hasFilters = fCode || fBloco || fApto || fDate || fStatus !== null
  const clearFilters = () => { setFCode(''); setFBloco(''); setFApto(''); setFDate(''); setFStatus(null) }

  return (
    <>
      <p className="text-gray-500 text-sm mb-4">
        {total} autorização{total !== 1 ? 'ões' : ''} encontrada{total !== 1 ? 's' : ''}
        {loading && <RefreshCw size={12} className="inline-block ml-2 animate-spin text-[#FC5931]" />}
      </p>

      {/* Filter bar */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 mb-5">
        <div className="flex flex-wrap gap-2 mb-3">
          {[
            { placeholder: 'Código', value: fCode, set: setFCode, width: 'w-24' },
            { placeholder: getBlocoLabel(tipoEstrutura), value: fBloco, set: setFBloco, width: 'w-24' },
            { placeholder: getAptoLabel(tipoEstrutura), value: fApto, set: setFApto, width: 'w-24' },
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
            <div className="flex rounded-xl border border-gray-200 overflow-hidden bg-white shadow-sm">
              {statusOptions.map(opt => (
                <button
                  key={String(opt.value)}
                  onClick={() => setFStatus(opt.value)}
                  className={`px-3 py-1.5 text-xs font-semibold transition-colors ${
                    fStatus === opt.value
                      ? opt.value === null
                        ? 'bg-gray-600 text-white'
                        : opt.value === false
                          ? 'bg-orange-500 text-white'
                          : 'bg-green-600 text-white'
                      : 'text-gray-500 hover:bg-gray-50'
                  }`}
                >
                  {opt.label}
                </button>
              ))}
            </div>
            {hasFilters && (
              <button onClick={clearFilters} className="text-xs text-gray-400 hover:text-red-500 transition-colors ml-1">
                Limpar
              </button>
            )}
          </div>
          <button
            onClick={handleRefresh}
            disabled={loading}
            className="p-2 text-[#FC5931] hover:bg-[#FC5931]/10 rounded-lg transition-colors"
            title="Atualizar"
          >
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
          </button>
        </div>
      </div>

      {/* Cards */}
      {invitations.length === 0 && !loading ? (
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
          {invitations.map(inv => {
            const liberado = isLiberado(inv)
            const isPortaria = inv.criado_por_portaria === true
            const bloco = isPortaria ? (inv.bloco_destino ?? '—') : (inv.perfil?.bloco_txt ?? '—')
            const apto = isPortaria ? (inv.apto_destino ?? '—') : (inv.perfil?.apto_txt ?? '—')
            const residentName = isPortaria
              ? (inv.perfil?.nome_completo ?? inv.morador_nome_manual ?? 'Não identificado')
              : (inv.perfil?.nome_completo ?? '—')
            const solicitadoPor = isPortaria ? 'Portaria' : residentName

            // Check if visit date allows confirmation
            // Rule: allow only if visit date >= yesterday at 18:00
            const visitDateExpired = (() => {
              if (!inv.validity_date) return false
              const visitDateStr = inv.validity_date.includes('T') ? inv.validity_date.split('T')[0] : inv.validity_date
              // Visit day end = visit date at 23:59:59
              const visitDayEnd = new Date(visitDateStr + 'T23:59:59')
              // Cutoff = yesterday at 18:00 (i.e., now minus the hours since yesterday 18h)
              const now = new Date()
              const cutoff = new Date(now)
              cutoff.setDate(cutoff.getDate() - 1)
              cutoff.setHours(18, 0, 0, 0)
              return visitDayEnd < cutoff
            })()

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
                        {getBlocoLabel(tipoEstrutura)}: {bloco} / {getAptoLabel(tipoEstrutura)}: {apto}
                      </p>
                      <p className="text-white/80 text-xs">
                        {isPortaria ? `Solicitado por: ${solicitadoPor}` : `Morador(a): ${residentName}`}
                      </p>
                    </div>
                  </div>
                  <span className="text-xs font-bold px-3 py-1 rounded-full bg-white/20 text-white">
                    {isPortaria ? 'Registrado via Portaria' : 'Acesso para Unidade'}
                  </span>
                </div>

                {/* Body */}
                <div className="px-5 py-4">
                  <div className="flex gap-4">
                    <div className="flex-1 grid grid-cols-2 gap-x-8 gap-y-2 mb-4 text-sm">
                      <div>
                        <span className="text-xs text-gray-400 block">Data da visita</span>
                        <span className="font-medium text-gray-800">
                          {inv.validity_date ? new Date((inv.validity_date.includes('T') ? inv.validity_date.split('T')[0] : inv.validity_date) + 'T00:00:00').toLocaleDateString('pt-BR') : '—'}
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
                    {/* QR Code */}
                    {inv.qr_data && (
                      <div className="flex flex-col items-center justify-center flex-shrink-0">
                        <div className="bg-white border border-gray-200 rounded-xl p-2 shadow-sm">
                          <QRCodeSVG value={inv.qr_data} size={80} />
                        </div>
                        <span className="text-[10px] text-gray-400 mt-1 font-mono tracking-wider">
                          {inv.qr_data.length > 6 ? inv.qr_data.slice(-3).toUpperCase() : inv.qr_data.toUpperCase()}
                        </span>
                      </div>
                    )}
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
                      ) : visitDateExpired ? (
                        <span className="text-xs text-red-400 font-medium px-3 py-1.5 bg-red-50 rounded-xl border border-red-100">
                          Expirado — data da visita ultrapassada
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

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-4 mt-6">
          <button
            onClick={() => setPage(p => Math.max(1, p - 1))}
            disabled={page === 1 || loading}
            aria-label="Página anterior"
            title="Página anterior"
            className="p-2 rounded-xl border border-gray-200 text-gray-500 hover:bg-gray-50 disabled:opacity-40 transition-colors"
          >
            <ChevronLeft size={16} />
          </button>
          <span className="text-sm text-gray-600 font-medium">{page} de {totalPages}</span>
          <button
            onClick={() => setPage(p => Math.min(totalPages, p + 1))}
            disabled={page === totalPages || loading}
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
