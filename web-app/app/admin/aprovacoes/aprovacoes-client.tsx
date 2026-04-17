'use client'

import { useState, useMemo } from 'react'
import { User, Clock, CheckCircle, XCircle, Lock, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight, Edit } from 'lucide-react'
import ApproveButton from './approve-button'
import EditProfileModal from '@/components/edit-profile-modal'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

type Profile = {
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

type Filter = 'pendente' | 'aprovado' | 'bloqueado' | 'rejeitado' | 'todos'

const PAGE_SIZE = 20

export default function AprovacoesClient({ profiles, tipoEstrutura }: { profiles: Profile[]; tipoEstrutura?: string }) {
  const [filter, setFilter] = useState<Filter>('pendente')
  const [filterBloco, setFilterBloco] = useState<string>('')
  const [filterApto, setFilterApto] = useState<string>('')
  const [page, setPage] = useState(1)
  const [editingProfile, setEditingProfile] = useState<Profile | null>(null)

  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)

  const blocos = Array.from(new Set(profiles.map(p => p.bloco_txt).filter(Boolean) as string[]))
  blocos.sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))

  const aptos = Array.from(new Set(
    profiles
      .filter(p => !filterBloco || p.bloco_txt === filterBloco)
      .map(p => p.apto_txt)
      .filter(Boolean) as string[]
  ))
  aptos.sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))

  function isPending(p: Profile)  { return !p.status_aprovacao || p.status_aprovacao === 'pendente' }
  function isApproved(p: Profile) { return p.status_aprovacao === 'aprovado' }
  function isBlocked(p: Profile)  { return p.status_aprovacao === 'bloqueado' }
  function isRejected(p: Profile) { return p.status_aprovacao === 'rejeitado' }

  const profilesByLocation = profiles.filter(p => {
    if (filterBloco && p.bloco_txt !== filterBloco) return false
    if (filterApto && p.apto_txt !== filterApto) return false
    return true
  })

  const counts = {
    todos:     profilesByLocation.length,
    pendente:  profilesByLocation.filter(isPending).length,
    aprovado:  profilesByLocation.filter(isApproved).length,
    bloqueado: profilesByLocation.filter(isBlocked).length,
    rejeitado: profilesByLocation.filter(isRejected).length,
  }

  const filtered = profilesByLocation.filter(p => {
    if (filter === 'todos')     return true
    if (filter === 'pendente')  return isPending(p)
    if (filter === 'aprovado')  return isApproved(p)
    if (filter === 'bloqueado') return isBlocked(p)
    if (filter === 'rejeitado') return isRejected(p)
    return true
  })

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const safePage = Math.min(page, totalPages)
  const paged = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE)

  const pageNumbers = useMemo(() => {
    const pages: number[] = []
    const start = Math.max(1, safePage - 2)
    const end = Math.min(totalPages, safePage + 2)
    for (let i = start; i <= end; i++) pages.push(i)
    return pages
  }, [safePage, totalPages])

  const FILTERS: { key: Filter; label: string; color: string; activeColor: string }[] = [
    { key: 'pendente',  label: 'Pendentes',  color: 'text-amber-600 bg-amber-50',   activeColor: 'bg-amber-500 text-white'  },
    { key: 'aprovado',  label: 'Liberados',  color: 'text-green-600 bg-green-50',   activeColor: 'bg-green-500 text-white'  },
    { key: 'bloqueado', label: 'Bloqueados', color: 'text-red-600 bg-red-50',       activeColor: 'bg-red-500 text-white'    },
    { key: 'rejeitado', label: 'Rejeitados', color: 'text-gray-600 bg-gray-100',    activeColor: 'bg-gray-600 text-white'   },
    { key: 'todos',     label: 'Todos',      color: 'text-gray-500 bg-gray-50 border border-gray-200', activeColor: 'bg-gray-700 text-white' },
  ]

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Aprovações</h1>
        <p className="text-gray-500 text-sm mt-1">Gerencie os cadastros do condomínio.</p>
      </div>

      <div className="flex flex-col md:flex-row gap-4 mb-5 justify-between">
        {/* Filter tabs */}
        <div className="flex gap-2 flex-wrap">
          {FILTERS.map(f => (
            <button
              key={f.key}
              onClick={() => { setFilter(f.key); setPage(1) }}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold transition-all ${
                filter === f.key ? f.activeColor : f.color
              }`}
            >
              {f.label}
              <span className={`text-xs px-1.5 py-0.5 rounded-full font-bold ${
                filter === f.key ? 'bg-white/30' : 'bg-white/60'
              }`}>
                {counts[f.key]}
              </span>
            </button>
          ))}
        </div>

        {/* Bloco/Apto Selects */}
        <div className="flex gap-2">
          <select
            aria-label={`Filtrar por ${blocoLabel}`}
            title={`Filtrar por ${blocoLabel}`}
            value={filterBloco}
            onChange={(e) => {
              setFilterBloco(e.target.value)
              setFilterApto('')
              setPage(1)
            }}
            className="px-3 py-2 border border-gray-200 rounded-xl text-sm font-medium text-gray-700 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931]"
          >
            <option value="">Todos {blocoLabel}s</option>
            {blocos.map(b => (
              <option key={b} value={b}>{blocoLabel} {b}</option>
            ))}
          </select>

          <select
            aria-label={`Filtrar por ${aptoLabel}`}
            title={`Filtrar por ${aptoLabel}`}
            value={filterApto}
            onChange={(e) => { setFilterApto(e.target.value); setPage(1) }}
            className="px-3 py-2 border border-gray-200 rounded-xl text-sm font-medium text-gray-700 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931]"
          >
            <option value="">Todos {aptoLabel}s</option>
            {aptos.map(a => (
              <option key={a} value={a}>{aptoLabel} {a}</option>
            ))}
          </select>
        </div>
      </div>

      {/* List */}
      {filtered.length === 0 ? (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-12 text-center">
          <CheckCircle size={40} className="mx-auto text-green-400 mb-3" />
          <p className="font-semibold text-gray-700">Nenhum cadastro nesta categoria.</p>
        </div>
      ) : (
        <>
        <div className="grid gap-3">
          {paged.map(p => {
            const pending   = isPending(p)
            const approved  = isApproved(p)
            const blocked   = isBlocked(p)
            const rejected  = isRejected(p)

            return (
              <div key={p.id} className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
                <div className="flex flex-col sm:flex-row sm:items-center gap-4">
                  {/* Avatar */}
                  <div className={`w-12 h-12 rounded-xl flex items-center justify-center shrink-0 ${
                    blocked ? 'bg-red-100' : 'bg-[#FC5931]/10'
                  }`}>
                    {blocked
                      ? <Lock size={20} className="text-red-500" />
                      : <User size={22} className="text-[#FC5931]" />}
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <p className={`font-semibold ${blocked ? 'text-gray-400 line-through' : 'text-gray-900'}`}>
                      {p.nome_completo ?? '—'}
                    </p>
                    
                    <div className="flex flex-wrap gap-x-3 gap-y-1 mt-1">
                      {p.email && (
                        <span className="text-xs text-gray-600">
                          📧 {p.email}
                        </span>
                      )}
                      {p.whatsapp && (
                        <span className="text-xs text-gray-600">
                          📱 {p.whatsapp}
                        </span>
                      )}
                    </div>

                    <div className="flex flex-wrap gap-x-3 gap-y-1 mt-1.5">
                      {p.papel_sistema && (
                        <span className="text-xs px-2 py-0.5 bg-gray-100 text-gray-600 rounded-full">
                          {p.papel_sistema}
                        </span>
                      )}
                      {p.bloco_txt && (
                        <span className="text-xs text-gray-500">
                          🏠 {blocoLabel} {p.bloco_txt}{p.apto_txt ? ` / ${aptoLabel} ${p.apto_txt}` : ''}
                        </span>
                      )}
                      <span className="text-xs text-gray-400 flex items-center gap-1">
                        📅 {new Date(p.created_at).toLocaleDateString('pt-BR', {
                          day: '2-digit', month: '2-digit', year: 'numeric'
                        })}
                      </span>
                    </div>
                  </div>

                  {/* Status badge */}
                  <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold shrink-0 ${
                    approved  ? 'bg-green-100 text-green-700'  :
                    blocked   ? 'bg-red-100 text-red-700'      :
                    rejected  ? 'bg-gray-100 text-gray-600'    :
                                'bg-amber-100 text-amber-700'
                  }`}>
                    {approved  ? <><CheckCircle size={12} /> Liberado</>  :
                     blocked   ? <><Lock size={12} /> Bloqueado</>        :
                     rejected  ? <><XCircle size={12} /> Rejeitado</>     :
                                 <><Clock size={12} /> Pendente</>}
                  </span>

                  {/* Action buttons — context sensitive */}
                  <div className="flex gap-2 shrink-0 flex-wrap items-center">
                    <button
                      onClick={() => setEditingProfile(p)}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold bg-blue-50 text-blue-600 border border-blue-100 hover:bg-blue-100 transition-colors"
                      title="Editar cadastro"
                    >
                      <Edit size={14} /> Editar
                    </button>
                    {pending && (
                      <>
                        <ApproveButton profileId={p.id} action="approve" />
                        <ApproveButton profileId={p.id} action="reject" />
                      </>
                    )}
                    {approved && (
                      <ApproveButton profileId={p.id} action="block" />
                    )}
                    {(blocked || rejected) && (
                      <ApproveButton profileId={p.id} action="unblock" />
                    )}
                  </div>
                </div>
              </div>
            )
          })}
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex flex-col sm:flex-row items-center justify-between gap-3 mt-4 px-1">
            <p className="text-sm text-gray-500">
              Mostrando {((safePage - 1) * PAGE_SIZE) + 1}–{Math.min(safePage * PAGE_SIZE, filtered.length)} de {filtered.length}
            </p>
            <div className="flex items-center gap-1">
              <button
                onClick={() => setPage(1)}
                disabled={safePage === 1}
                className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
                title="Primeira página"
              >
                <ChevronsLeft size={16} />
              </button>
              <button
                onClick={() => setPage(p => Math.max(1, p - 1))}
                disabled={safePage === 1}
                className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
                title="Página anterior"
              >
                <ChevronLeft size={16} />
              </button>
              {pageNumbers[0] > 1 && (
                <span className="px-1 text-gray-400 text-sm">…</span>
              )}
              {pageNumbers.map(n => (
                <button
                  key={n}
                  onClick={() => setPage(n)}
                  className={`w-9 h-9 rounded-lg text-sm font-semibold transition-colors ${
                    n === safePage
                      ? 'bg-[#FC5931] text-white shadow-sm'
                      : 'hover:bg-gray-100 text-gray-600'
                  }`}
                >
                  {n}
                </button>
              ))}
              {pageNumbers[pageNumbers.length - 1] < totalPages && (
                <span className="px-1 text-gray-400 text-sm">…</span>
              )}
              <button
                onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                disabled={safePage === totalPages}
                className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
                title="Próxima página"
              >
                <ChevronRight size={16} />
              </button>
              <button
                onClick={() => setPage(totalPages)}
                disabled={safePage === totalPages}
                className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
                title="Última página"
              >
                <ChevronsRight size={16} />
              </button>
            </div>
          </div>
        )}
        </>
      )}

      {editingProfile && (
        <EditProfileModal
          profile={editingProfile}
          blocoLabel={blocoLabel}
          aptoLabel={aptoLabel}
          onClose={() => setEditingProfile(null)}
        />
      )}
    </div>
  )
}
