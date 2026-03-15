'use client'

import { useState } from 'react'
import { Bell, BellOff, ChevronDown, ChevronUp, Megaphone } from 'lucide-react'

interface Aviso {
  id: string
  titulo: string
  corpo: string
  created_at: string
}

interface Props {
  naoLidos: Aviso[]
  lidos: Aviso[]
}

export default function AvisosCondoClient({ naoLidos: initialNaoLidos, lidos: initialLidos }: Props) {
  const [naoLidos, setNaoLidos] = useState<Aviso[]>(initialNaoLidos)
  const [lidos, setLidos] = useState<Aviso[]>(initialLidos)
  const [expanded, setExpanded] = useState<string | null>(null)
  const [marking, setMarking] = useState<string | null>(null)

  function toggle(id: string) {
    setExpanded(prev => prev === id ? null : id)
  }

  async function markAsRead(aviso: Aviso) {
    if (marking) return
    setMarking(aviso.id)
    await fetch('/api/avisos-lidos', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ aviso_id: aviso.id }),
    })
    setNaoLidos(prev => prev.filter(a => a.id !== aviso.id))
    setLidos(prev => [aviso, ...prev])
    setMarking(null)
  }

  const fmtDate = (d: string) =>
    new Date(d).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })

  return (
    <div className="max-w-3xl">
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-1">
          <Bell size={22} className="text-[#FC3951]" />
          <h1 className="text-2xl font-bold text-gray-900">Avisos do Condomínio</h1>
        </div>
        <p className="text-sm text-gray-500">Comunicados enviados pelo condomínio.</p>
      </div>

      {/* Não lidos */}
      <section className="mb-8">
        <div className="flex items-center gap-2 mb-3">
          <Bell size={16} className="text-[#FC3951]" />
          <h2 className="text-base font-semibold text-gray-800">Não lidos</h2>
          {naoLidos.length > 0 && (
            <span className="bg-[#FC3951] text-white text-xs font-bold px-2 py-0.5 rounded-full">
              {naoLidos.length}
            </span>
          )}
        </div>

        {naoLidos.length === 0 ? (
          <div className="bg-gray-50 rounded-2xl border border-gray-100 py-8 text-center text-gray-400">
            <Bell size={28} className="mx-auto mb-2 opacity-30" />
            <p className="text-sm">Nenhum aviso pendente 🎉</p>
          </div>
        ) : (
          <div className="space-y-3">
            {naoLidos.map(aviso => (
              <div
                key={aviso.id}
                className="bg-white rounded-2xl border-l-4 border-l-[#FC3951] border-y border-r border-gray-100 shadow-sm overflow-hidden"
              >
                <button
                  className="w-full text-left px-5 py-4 flex items-start justify-between gap-3 hover:bg-gray-50 transition-colors"
                  onClick={() => { toggle(aviso.id); markAsRead(aviso) }}
                >
                  <div>
                    <p className="font-semibold text-gray-900 text-sm">{aviso.titulo}</p>
                    <p className="text-xs text-gray-400 mt-0.5">{fmtDate(aviso.created_at)}</p>
                  </div>
                  {expanded === aviso.id ? <ChevronUp size={16} className="text-gray-400 mt-1 shrink-0" /> : <ChevronDown size={16} className="text-gray-400 mt-1 shrink-0" />}
                </button>
                {expanded === aviso.id && (
                  <div
                    className="px-5 pb-4 text-sm text-gray-700 leading-relaxed border-t border-gray-50"
                    dangerouslySetInnerHTML={{ __html: aviso.corpo }}
                  />
                )}
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Lidos */}
      {lidos.length > 0 && (
        <section>
          <div className="flex items-center gap-2 mb-3">
            <BellOff size={16} className="text-gray-400" />
            <h2 className="text-base font-semibold text-gray-500">Lidos</h2>
            <span className="text-xs text-gray-400">({lidos.length})</span>
          </div>
          <div className="space-y-2">
            {lidos.map(aviso => (
              <div
                key={aviso.id}
                className="bg-gray-50 rounded-2xl border border-gray-100 overflow-hidden"
              >
                <button
                  className="w-full text-left px-5 py-3.5 flex items-start justify-between gap-3 hover:bg-gray-100 transition-colors"
                  onClick={() => toggle(aviso.id)}
                >
                  <div>
                    <p className="font-medium text-gray-500 text-sm">{aviso.titulo}</p>
                    <p className="text-xs text-gray-400 mt-0.5">{fmtDate(aviso.created_at)}</p>
                  </div>
                  {expanded === aviso.id ? <ChevronUp size={16} className="text-gray-400 mt-1 shrink-0" /> : <ChevronDown size={16} className="text-gray-400 mt-1 shrink-0" />}
                </button>
                {expanded === aviso.id && (
                  <div
                    className="px-5 pb-4 text-sm text-gray-500 leading-relaxed border-t border-gray-100"
                    dangerouslySetInnerHTML={{ __html: aviso.corpo }}
                  />
                )}
              </div>
            ))}
          </div>
        </section>
      )}

      {naoLidos.length === 0 && lidos.length === 0 && (
        <div className="text-center py-16 text-gray-400">
          <Megaphone size={40} className="mx-auto mb-3 opacity-20" />
          <p className="text-sm">Nenhum aviso do condomínio ainda</p>
        </div>
      )}
    </div>
  )
}
