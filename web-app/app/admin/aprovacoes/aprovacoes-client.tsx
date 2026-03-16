'use client'

import { useState } from 'react'
import { User, Clock, CheckCircle, XCircle, Lock } from 'lucide-react'
import ApproveButton from './approve-button'

type Profile = {
  id: string
  nome_completo: string | null
  bloco_txt: string | null
  apto_txt: string | null
  status_aprovacao: string | null
  papel_sistema: string | null
  created_at: string
}

type Filter = 'pendente' | 'aprovado' | 'bloqueado' | 'rejeitado' | 'todos'

export default function AprovacoesClient({ profiles }: { profiles: Profile[] }) {
  const [filter, setFilter] = useState<Filter>('pendente')

  function isPending(p: Profile)  { return !p.status_aprovacao || p.status_aprovacao === 'pendente' }
  function isApproved(p: Profile) { return p.status_aprovacao === 'aprovado' }
  function isBlocked(p: Profile)  { return p.status_aprovacao === 'bloqueado' }
  function isRejected(p: Profile) { return p.status_aprovacao === 'rejeitado' }

  const counts = {
    todos:     profiles.length,
    pendente:  profiles.filter(isPending).length,
    aprovado:  profiles.filter(isApproved).length,
    bloqueado: profiles.filter(isBlocked).length,
    rejeitado: profiles.filter(isRejected).length,
  }

  const filtered = profiles.filter(p => {
    if (filter === 'todos')     return true
    if (filter === 'pendente')  return isPending(p)
    if (filter === 'aprovado')  return isApproved(p)
    if (filter === 'bloqueado') return isBlocked(p)
    if (filter === 'rejeitado') return isRejected(p)
    return true
  })

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

      {/* Filter tabs */}
      <div className="flex gap-2 flex-wrap mb-5">
        {FILTERS.map(f => (
          <button
            key={f.key}
            onClick={() => setFilter(f.key)}
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

      {/* List */}
      {filtered.length === 0 ? (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-12 text-center">
          <CheckCircle size={40} className="mx-auto text-green-400 mb-3" />
          <p className="font-semibold text-gray-700">Nenhum cadastro nesta categoria.</p>
        </div>
      ) : (
        <div className="grid gap-3">
          {filtered.map(p => {
            const status = p.status_aprovacao ?? 'pendente'
            const pending   = isPending(p)
            const approved  = isApproved(p)
            const blocked   = isBlocked(p)
            const rejected  = isRejected(p)

            return (
              <div key={p.id} className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
                <div className="flex flex-col sm:flex-row sm:items-center gap-4">
                  {/* Avatar */}
                  <div className={`w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0 ${
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
                    <div className="flex flex-wrap gap-x-3 gap-y-1 mt-1.5">
                      {p.papel_sistema && (
                        <span className="text-xs px-2 py-0.5 bg-gray-100 text-gray-600 rounded-full">
                          {p.papel_sistema}
                        </span>
                      )}
                      {p.bloco_txt && (
                        <span className="text-xs text-gray-500">
                          🏠 Bloco {p.bloco_txt}{p.apto_txt ? ` / Apto ${p.apto_txt}` : ''}
                        </span>
                      )}
                      <span className="text-xs text-gray-400">
                        📅 {new Date(p.created_at).toLocaleDateString('pt-BR', {
                          day: '2-digit', month: '2-digit', year: 'numeric'
                        })}
                      </span>
                    </div>
                  </div>

                  {/* Status badge */}
                  <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold flex-shrink-0 ${
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
                  <div className="flex gap-2 flex-shrink-0 flex-wrap">
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
      )}
    </div>
  )
}
