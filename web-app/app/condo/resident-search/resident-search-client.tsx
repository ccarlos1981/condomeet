'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Search, X, Phone, Mail, MessageCircle, Users, UserSearch,
  Building2, Home, Shield, ChevronRight, ExternalLink
} from 'lucide-react'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

interface Resident {
  id: string
  nome_completo: string | null
  email: string | null
  whatsapp: string | null
  bloco_txt: string | null
  apto_txt: string | null
  papel_sistema: string | null
  tipo_morador: string | null
  status_aprovacao: string | null
  created_at: string
}

interface Props {
  condoId: string
  tipoEstrutura?: string
}

// ── Normalize accents for fuzzy matching ─────────────────────
const ACCENTED = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ'
const PLAIN    = 'aaaaaeeeeiiiioooooouuuucnAAAAEEEEIIIIOOOOOUUUUCN'

function normalize(str: string): string {
  let result = str.toLowerCase()
  for (let i = 0; i < ACCENTED.length; i++) {
    result = result.replaceAll(ACCENTED[i], PLAIN[i])
  }
  return result
}

const ROLE_CONFIG: Record<string, { bg: string; text: string; border: string; icon: string }> = {
  'Morador (a)':  { bg: 'bg-sky-50',    text: 'text-sky-700',    border: 'border-sky-200',    icon: '🏠' },
  'Portaria':     { bg: 'bg-violet-50',  text: 'text-violet-700', border: 'border-violet-200', icon: '🚪' },
  'Porteiro (a)': { bg: 'bg-violet-50',  text: 'text-violet-700', border: 'border-violet-200', icon: '🚪' },
  'Síndico (a)':  { bg: 'bg-amber-50',   text: 'text-amber-700',  border: 'border-amber-200',  icon: '⭐' },
  'síndico':      { bg: 'bg-amber-50',   text: 'text-amber-700',  border: 'border-amber-200',  icon: '⭐' },
  'Sub Síndico':  { bg: 'bg-orange-50',  text: 'text-orange-700', border: 'border-orange-200', icon: '🌟' },
  'Admin':        { bg: 'bg-rose-50',    text: 'text-rose-700',   border: 'border-rose-200',   icon: '🔐' },
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

export default function ResidentSearchClient({ condoId, tipoEstrutura }: Props) {
  const supabase = createClient()
  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)

  const [query, setQuery] = useState('')
  const [residents, setResidents] = useState<Resident[]>([])
  const [loading, setLoading] = useState(false)
  const [selectedResident, setSelectedResident] = useState<Resident | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  // ── Debounced search ──────────────────────────────────
  const searchResidents = useCallback(async (q: string) => {
    if (!q.trim()) {
      setResidents([])
      setLoading(false)
      return
    }

    setLoading(true)
    const sanitized = `%${q.toLowerCase()}%`

    const { data, error } = await supabase
      .from('perfil')
      .select('id, nome_completo, email, whatsapp, bloco_txt, apto_txt, papel_sistema, tipo_morador, status_aprovacao, created_at')
      .eq('condominio_id', condoId)
      .or('status_aprovacao.eq.aprovado')
      .or(`nome_completo.ilike.${sanitized},apto_txt.ilike.${sanitized},bloco_txt.ilike.${sanitized}`)
      .limit(40)

    if (error) {
      console.error('Search error:', error)
      setLoading(false)
      return
    }

    // Client-side accent-normalized re-filter
    const normalizedQ = normalize(q)
    const filtered = (data ?? []).filter(r => {
      const name = normalize(r.nome_completo ?? '')
      const unit = (r.apto_txt ?? '').toLowerCase()
      const block = (r.bloco_txt ?? '').toLowerCase()
      return name.includes(normalizedQ) ||
        unit.includes(q.toLowerCase()) ||
        block.includes(q.toLowerCase())
    })

    setResidents(filtered)
    setLoading(false)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [condoId])

  useEffect(() => {
    const timer = setTimeout(() => {
      searchResidents(query)
    }, 300)
    return () => clearTimeout(timer)
  }, [query, searchResidents])

  // Focus on mount
  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  const hasQuery = query.trim().length > 0

  return (
    <div className="max-w-3xl mx-auto">
      {/* ── Header ─────────────────────────────────────── */}
      <div className="mb-6">
        <div className="flex items-center gap-3 mb-1">
          <div className="w-10 h-10 bg-linear-to-br from-[#FC5931] to-[#D42F1D] rounded-xl flex items-center justify-center shadow-sm">
            <UserSearch size={20} className="text-white" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Busca Moradores</h1>
            <p className="text-gray-400 text-xs">Digite o nome ou número da unidade para buscar</p>
          </div>
        </div>
      </div>

      {/* ── Search Input ──────────────────────────────── */}
      <div className="relative mb-6">
        <Search size={20} className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          ref={inputRef}
          type="text"
          value={query}
          onChange={e => setQuery(e.target.value)}
          placeholder={`Buscar por nome, ${blocoLabel.toLowerCase()}, ${aptoLabel.toLowerCase()}...`}
          className="w-full pl-12 pr-12 py-4 rounded-2xl border border-gray-200 text-base focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] bg-white shadow-sm transition-all placeholder:text-gray-400"
        />
        {query && (
          <button
            onClick={() => { setQuery(''); inputRef.current?.focus() }}
            className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 bg-gray-100 hover:bg-gray-200 p-1 rounded-full transition-colors"
            title="Limpar busca"
          >
            <X size={16} />
          </button>
        )}

        {/* Loading indicator */}
        {loading && (
          <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#FC5931]/20 rounded-b-2xl overflow-hidden">
            <div className="h-full bg-[#FC5931] rounded-full animate-pulse w-1/2" />
          </div>
        )}
      </div>

      {/* ── Results ───────────────────────────────────── */}
      {!hasQuery ? (
        /* Empty state — no query */
        <div className="text-center py-16">
          <div className="w-20 h-20 bg-gray-50 rounded-full mx-auto mb-4 flex items-center justify-center">
            <UserSearch size={36} className="text-gray-300" />
          </div>
          <h3 className="text-lg font-semibold text-gray-600 mb-2">Buscar Morador</h3>
          <p className="text-gray-400 text-sm max-w-sm mx-auto">
            Digite o nome, {blocoLabel.toLowerCase()} ou {aptoLabel.toLowerCase()} para encontrar moradores do condomínio.
          </p>
          <div className="flex flex-wrap justify-center gap-2 mt-5">
            {['João', '101', 'B', 'Maria'].map(term => (
              <button
                key={term}
                onClick={() => { setQuery(term); inputRef.current?.focus() }}
                className="px-3 py-1.5 text-xs font-medium bg-gray-100 hover:bg-[#FC5931]/10 text-gray-500 hover:text-[#FC5931] rounded-full transition-colors"
              >
                &quot;{term}&quot;
              </button>
            ))}
          </div>
        </div>
      ) : residents.length === 0 && !loading ? (
        /* Empty state — no results */
        <div className="text-center py-16">
          <div className="w-20 h-20 bg-orange-50 rounded-full mx-auto mb-4 flex items-center justify-center">
            <Search size={36} className="text-orange-300" />
          </div>
          <h3 className="text-lg font-semibold text-gray-600 mb-2">Nenhum morador encontrado</h3>
          <p className="text-gray-400 text-sm max-w-sm mx-auto">
            Tente buscar por outro nome, número do {aptoLabel.toLowerCase()} ou {blocoLabel.toLowerCase()}.
          </p>
        </div>
      ) : residents.length > 0 ? (
        /* Results list */
        <div>
          <p className="text-xs text-gray-400 font-medium mb-3">
            {residents.length} resultado{residents.length !== 1 ? 's' : ''} encontrado{residents.length !== 1 ? 's' : ''}
          </p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm divide-y divide-gray-100 overflow-hidden">
            {residents.map(r => {
              const role = ROLE_CONFIG[r.papel_sistema ?? ''] ?? defaultRole
              const initials = getInitials(r.nome_completo)
              const avatarGrad = getAvatarColor(r.id)
              const isBlocked = r.status_aprovacao === 'bloqueado'

              return (
                <button
                  key={r.id}
                  onClick={() => setSelectedResident(r)}
                  className="w-full text-left px-4 py-3.5 flex items-center gap-3 hover:bg-gray-50/80 transition-colors group"
                >
                  {/* Avatar */}
                  <div className={`w-11 h-11 rounded-full flex items-center justify-center shrink-0 shadow-sm bg-linear-to-br ${avatarGrad}`}>
                    <span className="text-white text-sm font-bold">{initials}</span>
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <p className={`font-semibold text-sm text-gray-900 truncate ${isBlocked ? 'line-through opacity-50' : ''}`}>
                      {r.nome_completo || '—'}
                    </p>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="text-xs text-gray-500 flex items-center gap-1">
                        <Home size={11} className="text-gray-400" />
                        {r.bloco_txt ? `${blocoLabel} ${r.bloco_txt}` : '–'}
                        {r.apto_txt ? ` · ${aptoLabel} ${r.apto_txt}` : ''}
                      </span>
                      {r.papel_sistema && (
                        <span className={`text-[10px] px-1.5 py-0.5 rounded-full font-semibold border ${role.bg} ${role.text} ${role.border}`}>
                          {role.icon} {r.papel_sistema}
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Arrow */}
                  <ChevronRight size={16} className="text-gray-300 group-hover:text-[#FC5931] transition-colors shrink-0" />
                </button>
              )
            })}
          </div>
        </div>
      ) : null}

      {/* ═══════════════════════════════════════════════════ */}
      {/* ── RESIDENT DETAIL MODAL ─────────────────────── */}
      {/* ═══════════════════════════════════════════════════ */}
      {selectedResident && (
        <div
          className="fixed inset-0 bg-black/40 z-50 flex items-end sm:items-center justify-center backdrop-blur-sm"
          onClick={() => setSelectedResident(null)}
        >
          <div
            className="bg-white rounded-t-2xl sm:rounded-2xl w-full max-w-md shadow-2xl animate-in slide-in-from-bottom-4 duration-300"
            onClick={e => e.stopPropagation()}
          >
            {/* Close handle (mobile) */}
            <div className="flex justify-center pt-3 pb-1 sm:hidden">
              <div className="w-10 h-1 rounded-full bg-gray-300" />
            </div>

            <div className="px-6 pb-6 pt-4">
              {/* Avatar + Name */}
              <div className="text-center mb-5">
                <div className={`w-16 h-16 rounded-full mx-auto mb-3 flex items-center justify-center shadow-md bg-linear-to-br ${getAvatarColor(selectedResident.id)}`}>
                  <span className="text-white text-xl font-bold">{getInitials(selectedResident.nome_completo)}</span>
                </div>
                <h2 className="text-lg font-bold text-gray-900">{selectedResident.nome_completo || '—'}</h2>
                <p className="text-sm text-gray-500 mt-0.5 flex items-center justify-center gap-1">
                  <Building2 size={13} />
                  {selectedResident.bloco_txt ? `${blocoLabel} ${selectedResident.bloco_txt}` : '–'}
                  {selectedResident.apto_txt ? ` · ${aptoLabel} ${selectedResident.apto_txt}` : ''}
                </p>
                {selectedResident.tipo_morador && (
                  <p className="text-xs text-gray-400 mt-0.5">{selectedResident.tipo_morador}</p>
                )}

                {/* Role badge */}
                {selectedResident.papel_sistema && (() => {
                  const role = ROLE_CONFIG[selectedResident.papel_sistema ?? ''] ?? defaultRole
                  return (
                    <span className={`inline-flex items-center gap-1 text-xs px-3 py-1 rounded-full font-semibold border mt-2 ${role.bg} ${role.text} ${role.border}`}>
                      {role.icon} {selectedResident.papel_sistema}
                    </span>
                  )
                })()}
              </div>

              <div className="h-px bg-gray-100 mb-4" />

              {/* Detail rows */}
              <div className="space-y-3">
                {selectedResident.whatsapp && (
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-lg bg-gray-50 flex items-center justify-center">
                      <Phone size={16} className="text-gray-500" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-[11px] text-gray-400 font-medium">Telefone</p>
                      <p className="text-sm font-semibold text-gray-800 truncate">{selectedResident.whatsapp}</p>
                    </div>
                  </div>
                )}

                {selectedResident.email && (
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-lg bg-gray-50 flex items-center justify-center">
                      <Mail size={16} className="text-gray-500" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-[11px] text-gray-400 font-medium">Email</p>
                      <p className="text-sm font-semibold text-gray-800 truncate">{selectedResident.email}</p>
                    </div>
                  </div>
                )}

                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-lg bg-gray-50 flex items-center justify-center">
                    <Shield size={16} className="text-gray-500" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[11px] text-gray-400 font-medium">Perfil</p>
                    <p className="text-sm font-semibold text-gray-800">{selectedResident.papel_sistema || 'Morador'}</p>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-lg bg-gray-50 flex items-center justify-center">
                    <Users size={16} className="text-gray-500" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[11px] text-gray-400 font-medium">Status</p>
                    <p className="text-sm font-semibold text-gray-800 capitalize">{selectedResident.status_aprovacao || 'aprovado'}</p>
                  </div>
                </div>
              </div>

              {/* Action buttons */}
              {(selectedResident.whatsapp || selectedResident.email) && (
                <>
                  <div className="h-px bg-gray-100 my-4" />
                  <div className="flex gap-3">
                    {selectedResident.whatsapp && (
                      <>
                        <a
                          href={`tel:${selectedResident.whatsapp}`}
                          className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl border-2 border-[#FC5931] text-[#FC5931] font-semibold text-sm hover:bg-[#FC5931]/5 transition-colors"
                        >
                          <Phone size={16} />
                          Ligar
                        </a>
                        <a
                          href={`https://wa.me/55${selectedResident.whatsapp.replace(/\D/g, '')}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl bg-[#25D366] text-white font-semibold text-sm hover:bg-[#20BD5A] transition-colors"
                        >
                          <MessageCircle size={16} />
                          WhatsApp
                          <ExternalLink size={12} />
                        </a>
                      </>
                    )}
                    {selectedResident.email && !selectedResident.whatsapp && (
                      <a
                        href={`mailto:${selectedResident.email}`}
                        className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl border-2 border-blue-500 text-blue-600 font-semibold text-sm hover:bg-blue-50 transition-colors"
                      >
                        <Mail size={16} />
                        Enviar Email
                      </a>
                    )}
                  </div>
                </>
              )}

              {/* Close button */}
              <button
                onClick={() => setSelectedResident(null)}
                className="w-full mt-4 py-2.5 rounded-xl text-gray-500 font-medium text-sm hover:bg-gray-50 transition-colors border border-gray-200"
              >
                Fechar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
