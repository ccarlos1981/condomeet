'use client'
import { useState, useTransition } from 'react'
import { createClient } from '@/lib/supabase/client'

import { Clock, CheckCircle, Users, Search, LogOut } from 'lucide-react'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

interface Visitante {
  id: string
  nome: string
  cpf_rg: string | null
  whatsapp: string | null
  tipo_visitante: string | null
  empresa: string | null
  bloco: string | null
  apto: string | null
  observacao: string | null
  foto_url: string | null
  entrada_at: string
  saida_at: string | null
  registrado_por: string | null
  created_at: string
}

type FilterTab = 'pendente' | 'todos' | 'liberados'

interface Props {
  visitantes: Visitante[]
  condoId: string
  userId: string
  tipoEstrutura?: string
}

export default function LiberarVisitanteClient({
  visitantes: initialVisitantes,
  // condoId is not used
  // userId is not used
  tipoEstrutura,
}: Props) {
    const supabase = createClient()
  const [isPending, startTransition] = useTransition()
  const [visitantes, setVisitantes] = useState(initialVisitantes)
  const [activeTab, setActiveTab] = useState<FilterTab>('pendente')
  const [search, setSearch] = useState('')

  // Filter by tab
  const filtered = visitantes.filter(v => {
    if (activeTab === 'pendente') return !v.saida_at
    if (activeTab === 'liberados') return !!v.saida_at
    return true // 'todos'
  }).filter(v => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return (
      v.nome.toLowerCase().includes(q) ||
      (v.cpf_rg && v.cpf_rg.includes(q)) ||
      (v.bloco && v.bloco.toLowerCase().includes(q)) ||
      (v.apto && v.apto.toLowerCase().includes(q))
    )
  })

  const pendentesCount = visitantes.filter(v => !v.saida_at).length
  const liberadosCount = visitantes.filter(v => !!v.saida_at).length

  // Register exit
  async function handleRegistrarSaida(id: string) {
    startTransition(async () => {
      await supabase
        .from('visitante_registros')
        .update({ saida_at: new Date().toISOString() })
        .eq('id', id)
      setVisitantes(prev =>
        prev.map(v => v.id === id ? { ...v, saida_at: new Date().toISOString() } : v)
      )
    })
  }

  function fmtDate(iso: string) {
    const d = new Date(iso)
    return d.toLocaleDateString('pt-BR') + ' – ' + d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) + 'h'
  }

  const tabs: { key: FilterTab; label: string; count: number; icon: React.ReactNode; color: string }[] = [
    { key: 'pendente', label: 'Pendentes', count: pendentesCount, icon: <Clock size={16} />, color: 'bg-yellow-500' },
    { key: 'todos', label: 'Todos', count: visitantes.length, icon: <Users size={16} />, color: 'bg-blue-500' },
    { key: 'liberados', label: 'Liberados', count: liberadosCount, icon: <CheckCircle size={16} />, color: 'bg-green-500' },
  ]

  return (
    <div>
      {/* Header */}
      <div className="bg-[#FC5931] text-white text-center font-bold py-4 rounded-t-xl text-lg">
        Liberar Visitante Cadastrado
      </div>

      {/* Filter Tabs */}
      <div className="bg-white border-x border-gray-100 px-4 pt-4 pb-2">
        <div className="flex gap-2 mb-3">
          {tabs.map(tab => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`flex items-center gap-2 px-4 py-2.5 rounded-lg text-sm font-semibold transition-all ${
                activeTab === tab.key
                  ? `${tab.color} text-white shadow-md`
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              {tab.icon}
              {tab.label}
              <span className={`text-xs px-1.5 py-0.5 rounded-full ${
                activeTab === tab.key ? 'bg-white/20' : 'bg-gray-200'
              }`}>
                {tab.count}
              </span>
            </button>
          ))}
        </div>

        {/* Search */}
        <div className="relative">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Buscar por nome, CPF/RG, bloco ou apto..."
            className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
          />
        </div>
      </div>

      {/* Visitor List */}
      <div className="bg-white rounded-b-xl border border-gray-100 border-t-0 divide-y divide-gray-50">
        {filtered.length === 0 ? (
          <div className="py-16 text-center text-gray-400">
            <Users size={40} className="mx-auto mb-3 opacity-50" />
            <p className="font-medium">Nenhum visitante encontrado</p>
            <p className="text-sm mt-1">
              {activeTab === 'pendente' ? 'Não há visitantes com saída pendente.' :
               activeTab === 'liberados' ? 'Nenhum visitante liberado ainda.' :
               'Nenhum visitante registrado.'}
            </p>
          </div>
        ) : (
          filtered.map(v => (
            <div
              key={v.id}
              className="px-5 py-4 flex items-center gap-4 hover:bg-gray-50/50 transition-colors"
            >
              {/* Photo */}
              <div className="w-16 h-16 rounded-full bg-gray-200 overflow-hidden flex-shrink-0 ring-2 ring-gray-100">
                {v.foto_url ? (
                  <><> <> {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={v.foto_url} alt={v.nome} className="w-full h-full object-cover" />
                </>
                </></>
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-gray-400 text-2xl">👤</div>
                )}
              </div>

              {/* Info */}
              <div className="flex-1 min-w-0">
                <p className="font-bold text-gray-800 text-[15px]">
                  Visitante: {v.nome}
                </p>
                {(v.bloco || v.apto) && (
                  <p className="text-sm text-gray-500">
                    {getBlocoLabel(tipoEstrutura)}: {v.bloco || '−'} / {getAptoLabel(tipoEstrutura)}: {v.apto || '−'}
                  </p>
                )}
                <p className="text-sm text-gray-500">
                  <span className="font-medium">Entrada:</span> {fmtDate(v.entrada_at)}
                </p>
                {v.saida_at && (
                  <p className="text-sm text-gray-500">
                    <span className="font-medium">Saída:</span> {fmtDate(v.saida_at)}
                  </p>
                )}
                {v.tipo_visitante && (
                  <span className="inline-block mt-1 text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full">
                    {v.tipo_visitante}
                  </span>
                )}
              </div>

              {/* Action */}
              <div className="flex-shrink-0">
                {!v.saida_at ? (
                  <button
                    onClick={() => handleRegistrarSaida(v.id)}
                    disabled={isPending}
                    className="bg-red-500 hover:bg-red-600 text-white px-5 py-2.5 rounded-lg font-semibold text-sm transition-colors disabled:opacity-60 flex items-center gap-2 shadow-sm"
                  >
                    <LogOut size={16} />
                    Registrar Saída
                  </button>
                ) : (
                  <div className="bg-green-500 text-white px-5 py-2.5 rounded-lg text-sm font-semibold text-center min-w-[140px]">
                    <div className="flex items-center gap-1.5 justify-center">
                      <CheckCircle size={14} />
                      Saída Registrada
                    </div>
                    <div className="text-xs opacity-90 mt-0.5">
                      {new Date(v.saida_at!).toLocaleDateString('pt-BR')}
                    </div>
                  </div>
                )}
              </div>
            </div>
          ))
        )}
      </div>

      {/* Footer count */}
      {filtered.length > 0 && (
        <p className="text-center text-sm text-gray-400 mt-3">
          Exibindo {filtered.length} de {visitantes.length} visitante{visitantes.length !== 1 ? 's' : ''}
        </p>
      )}
    </div>
  )
}
