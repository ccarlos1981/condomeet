'use client'

import { useState } from 'react'
import { User, Search, X, Home, Lock } from 'lucide-react'

type Morador = {
  id: string
  nome_completo: string | null
  bloco_txt: string | null
  apto_txt: string | null
  status_aprovacao: string | null
  papel_sistema: string | null
  created_at: string
}

const ROLE_COLORS: Record<string, string> = {
  'Morador (a)': 'bg-blue-100 text-blue-700',
  'Portaria':    'bg-purple-100 text-purple-700',
  'Porteiro (a)':'bg-purple-100 text-purple-700',
  'Síndico (a)': 'bg-orange-100 text-orange-700',
  'síndico':     'bg-orange-100 text-orange-700',
  'Admin':       'bg-red-100 text-red-700',
}
const defaultRoleColor = 'bg-gray-100 text-gray-600'

export default function MoradoresClient({ moradores }: { moradores: Morador[] }) {
  const [search, setSearch] = useState('')

  const filtered = moradores.filter(m => {
    if (!search) return true
    const q = search.toLowerCase()
    return (
      (m.nome_completo ?? '').toLowerCase().includes(q) ||
      (m.papel_sistema ?? '').toLowerCase().includes(q) ||
      (m.bloco_txt ?? '').toLowerCase().includes(q) ||
      (m.apto_txt ?? '').toLowerCase().includes(q)
    )
  })

  return (
    <div>
      {/* Header */}
      <div className="mb-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Moradores</h1>
          <p className="text-gray-500 text-sm mt-1">
            {moradores.length} usuário{moradores.length !== 1 ? 's' : ''} ativo{moradores.length !== 1 ? 's' : ''} no condomínio.
          </p>
        </div>
        {/* Search */}
        <div className="relative w-full sm:w-72">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Buscar por nome, bloco, apto..."
            className="w-full pl-9 pr-8 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26]/30 focus:border-[#E85D26] bg-white"
          />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
              <X size={14} />
            </button>
          )}
        </div>
      </div>

      {/* Grid */}
      {filtered.length === 0 ? (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-12 text-center">
          <User size={40} className="mx-auto text-gray-300 mb-3" />
          <p className="font-semibold text-gray-600">Nenhum morador encontrado.</p>
          {search && <p className="text-sm text-gray-400 mt-1">Tente outro termo de busca.</p>}
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map(m => {
            const roleColor = ROLE_COLORS[m.papel_sistema ?? ''] ?? defaultRoleColor
            const isBlocked = m.status_aprovacao === 'bloqueado'
            return (
              <div
                key={m.id}
                className={`bg-white rounded-2xl border shadow-sm p-5 flex flex-col gap-3 transition-all ${
                  isBlocked ? 'border-red-100 opacity-60' : 'border-gray-100 hover:shadow-md'
                }`}
              >
                {/* Avatar + name */}
                <div className="flex items-center gap-3">
                  <div className={`w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 ${
                    isBlocked ? 'bg-red-50' : 'bg-[#E85D26]/10'
                  }`}>
                    {isBlocked
                      ? <Lock size={18} className="text-red-400" />
                      : <User size={20} className="text-[#E85D26]" />}
                  </div>
                  <div className="min-w-0">
                    <p className={`font-semibold text-sm leading-tight ${isBlocked ? 'line-through text-gray-400' : 'text-gray-900'}`}>
                      {m.nome_completo ?? '—'}
                    </p>
                    {m.papel_sistema && (
                      <span className={`text-xs px-2 py-0.5 rounded-full font-medium mt-1 inline-block ${roleColor}`}>
                        {m.papel_sistema}
                      </span>
                    )}
                  </div>
                </div>

                {/* Unit info */}
                {m.bloco_txt && (
                  <div className="flex items-center gap-2 text-sm text-gray-500">
                    <Home size={14} className="text-gray-400 flex-shrink-0" />
                    <span>Bloco {m.bloco_txt}{m.apto_txt ? ` / Apto ${m.apto_txt}` : ''}</span>
                  </div>
                )}

                {/* Date */}
                <p className="text-xs text-gray-400">
                  Desde {new Date(m.created_at).toLocaleDateString('pt-BR', {
                    day: '2-digit', month: 'long', year: 'numeric'
                  })}
                </p>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
