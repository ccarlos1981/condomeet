'use client'
import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import {
  PlusCircle, Eye, Trash2, Calendar, Users, Vote,
  Clock, CheckCircle2, XCircle, FileText, AlertTriangle,
  Search, Filter, Gavel, Video, Building2, Globe,
  DollarSign, HardDrive, X, Sparkles
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

/* ================================================================
   Types
   ================================================================ */

interface Assembleia {
  id: string
  nome: string
  tipo: string
  modalidade: string
  status: string
  dt_1a_convocacao: string | null
  dt_2a_convocacao: string | null
  dt_inicio_votacao: string | null
  dt_fim_votacao: string | null
  dt_inicio_transmissao: string | null
  dt_fim_transmissao: string | null
  eleicao_mesa: boolean
  peso_voto_tipo: string
  created_at: string
  updated_at: string
  created_by: string
  totalPautas: number
}

interface Props {
  condominioId: string
  assembleias: Assembleia[]
  totalUnidades: number
  tipoEstrutura?: string
}

/* ================================================================
   Status helpers
   ================================================================ */

const STATUS_CONFIG: Record<string, { label: string; color: string; bg: string; icon: React.ReactNode }> = {
  rascunho:       { label: 'Rascunho',       color: 'text-gray-500',   bg: 'bg-gray-100',    icon: <FileText size={14} /> },
  agendada:       { label: 'Agendada',       color: 'text-blue-600',   bg: 'bg-blue-50',     icon: <Calendar size={14} /> },
  em_andamento:   { label: 'Em Andamento',   color: 'text-green-600',  bg: 'bg-green-50',    icon: <Video size={14} /> },
  votacao_aberta: { label: 'Votação Aberta', color: 'text-orange-600', bg: 'bg-orange-50',   icon: <Vote size={14} /> },
  finalizada:     { label: 'Finalizada',     color: 'text-purple-600', bg: 'bg-purple-50',   icon: <CheckCircle2 size={14} /> },
  ata_publicada:  { label: 'Ata Publicada',  color: 'text-emerald-600',bg: 'bg-emerald-50',  icon: <FileText size={14} /> },
  cancelada:      { label: 'Cancelada',      color: 'text-red-500',    bg: 'bg-red-50',      icon: <XCircle size={14} /> },
}

const MODALIDADE_ICON: Record<string, React.ReactNode> = {
  online:     <Globe size={14} />,
  presencial: <Building2 size={14} />,
  hibrida:    <Video size={14} />,
}

function formatDate(d: string | null) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatDateShort(d: string | null) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('pt-BR')
}

/* ================================================================
   Component
   ================================================================ */

export default function AssembleiasClient({
  condominioId,
  assembleias: initialAssembleias,
  totalUnidades,
}: Props) {
  const router = useRouter()
  const supabase = createClient()
  const [assembleias, setAssembleias] = useState(initialAssembleias)
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('todos')
  const [showCostModal, setShowCostModal] = useState(false)

  // Custos cobrados (3x markup)
  const STORAGE_COST_PER_HOUR = 0.30  // ~500MB/h × R$0.60/GB = R$0.30/h/mês
  const AI_ATA_COST_PER_HOUR = 15.00  // R$15.00/hora de transcrição

  function formatCurrency(v: number) {
    return v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
  }

  // Sync with server props
  useEffect(() => {
    setAssembleias(initialAssembleias)
  }, [initialAssembleias])

  // Filtered list
  const filtered = assembleias.filter(a => {
    const matchSearch = !searchTerm ||
      a.nome.toLowerCase().includes(searchTerm.toLowerCase()) ||
      a.tipo.toLowerCase().includes(searchTerm.toLowerCase())
    const matchStatus = statusFilter === 'todos' || a.status === statusFilter
    return matchSearch && matchStatus
  })

  // Delete assembleia (only rascunho)
  async function handleDelete(id: string) {
    if (!confirm('Excluir esta assembleia e todos os dados vinculados?')) return
    setAssembleias(prev => prev.filter(a => a.id !== id))
    await supabase.from('assembleias').delete().eq('id', id)
  }

  // Stats
  const stats = {
    total: assembleias.length,
    agendadas: assembleias.filter(a => a.status === 'agendada').length,
    emAndamento: assembleias.filter(a => ['em_andamento', 'votacao_aberta'].includes(a.status)).length,
    finalizadas: assembleias.filter(a => ['finalizada', 'ata_publicada'].includes(a.status)).length,
  }

  // ════════════════════════════════════════════════════════════
  //  RENDER
  // ════════════════════════════════════════════════════════════

  return (
    <div className="max-w-6xl mx-auto px-4 py-8 space-y-6">

      {/* ── HEADER ──────────────────────────────────────── */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-3">
            <Gavel size={28} className="text-[#FC5931]" />
            Assembleias
          </h1>
          <p className="text-sm text-gray-500 mt-1">
            Gerencie as assembleias do condomínio · {totalUnidades} unidades cadastradas
          </p>
        </div>
        <button
          onClick={() => setShowCostModal(true)}
          className="flex items-center gap-2 px-5 py-3 bg-[#FC5931] text-white rounded-xl font-semibold hover:bg-[#e04a2a] transition-all shadow-lg shadow-[#FC5931]/20 text-sm"
        >
          <PlusCircle size={18} />
          Nova Assembleia
        </button>
      </div>

      {/* ── STATS CARDS ─────────────────────────────────── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          { label: 'Total', value: stats.total, icon: <Gavel size={20} />, color: 'text-gray-700', bg: 'bg-gray-50' },
          { label: 'Agendadas', value: stats.agendadas, icon: <Calendar size={20} />, color: 'text-blue-600', bg: 'bg-blue-50' },
          { label: 'Em Andamento', value: stats.emAndamento, icon: <Clock size={20} />, color: 'text-orange-600', bg: 'bg-orange-50' },
          { label: 'Finalizadas', value: stats.finalizadas, icon: <CheckCircle2 size={20} />, color: 'text-green-600', bg: 'bg-green-50' },
        ].map(s => (
          <div key={s.label} className={`${s.bg} rounded-2xl p-4 border border-gray-100`}>
            <div className="flex items-center justify-between">
              <span className={`${s.color}`}>{s.icon}</span>
              <span className={`text-2xl font-bold ${s.color}`}>{s.value}</span>
            </div>
            <p className="text-xs text-gray-500 mt-2 font-medium">{s.label}</p>
          </div>
        ))}
      </div>

      {/* ── FILTERS ─────────────────────────────────────── */}
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
            placeholder="Buscar assembleia..."
            className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
          />
        </div>
        <div className="relative">
          <Filter size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <select
            value={statusFilter}
            onChange={e => setStatusFilter(e.target.value)}
            className="pl-10 pr-8 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm appearance-none bg-white"
          >
            <option value="todos">Todos os status</option>
            {Object.entries(STATUS_CONFIG).map(([key, cfg]) => (
              <option key={key} value={key}>{cfg.label}</option>
            ))}
          </select>
        </div>
      </div>

      {/* ── TABLE ────────────────────────────────────────── */}
      {filtered.length > 0 ? (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50/50">
                  <th className="text-left py-3 px-4 text-gray-500 font-semibold">Assembleia</th>
                  <th className="text-center py-3 px-4 text-gray-500 font-semibold">Tipo</th>
                  <th className="text-center py-3 px-4 text-gray-500 font-semibold">Modalidade</th>
                  <th className="text-center py-3 px-4 text-gray-500 font-semibold">Status</th>
                  <th className="text-center py-3 px-4 text-gray-500 font-semibold">Pautas</th>
                  <th className="text-center py-3 px-4 text-gray-500 font-semibold">1ª Convocação</th>
                  <th className="text-center py-3 px-4 text-gray-500 font-semibold">Votação</th>
                  <th className="text-center py-3 px-4 text-gray-500 font-semibold">Ações</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(a => {
                  const statusCfg = STATUS_CONFIG[a.status] ?? STATUS_CONFIG.rascunho
                  const modalIcon = MODALIDADE_ICON[a.modalidade] ?? <Globe size={14} />
                  const isRascunho = a.status === 'rascunho'
                  const isVotacaoAberta = a.status === 'votacao_aberta'

                  return (
                    <tr
                      key={a.id}
                      className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors cursor-pointer"
                      onClick={() => router.push(`/admin/assembleias/${a.id}`)}
                    >
                      {/* Nome */}
                      <td className="py-3 px-4">
                        <p className="font-medium text-gray-800 truncate max-w-[240px]">{a.nome}</p>
                        <p className="text-xs text-gray-400 mt-0.5">
                          Criada em {formatDateShort(a.created_at)}
                        </p>
                      </td>

                      {/* Tipo */}
                      <td className="py-3 px-4 text-center">
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-indigo-50 text-indigo-600">
                          {a.tipo}
                        </span>
                      </td>

                      {/* Modalidade */}
                      <td className="py-3 px-4 text-center">
                        <span className="inline-flex items-center gap-1.5 text-xs text-gray-600 capitalize">
                          {modalIcon} {a.modalidade}
                        </span>
                      </td>

                      {/* Status */}
                      <td className="py-3 px-4 text-center">
                        <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold ${statusCfg.bg} ${statusCfg.color}`}>
                          {statusCfg.icon} {statusCfg.label}
                        </span>
                      </td>

                      {/* Pautas */}
                      <td className="py-3 px-4 text-center">
                        <span className="text-sm font-medium text-gray-700">{a.totalPautas}</span>
                      </td>

                      {/* 1ª Convocação */}
                      <td className="py-3 px-4 text-center text-xs text-gray-500">
                        {formatDate(a.dt_1a_convocacao)}
                      </td>

                      {/* Votação */}
                      <td className="py-3 px-4 text-center">
                        {a.dt_inicio_votacao ? (
                          <div className="text-xs">
                            <p className="text-gray-600">{formatDateShort(a.dt_inicio_votacao)}</p>
                            <p className="text-gray-400">até {formatDateShort(a.dt_fim_votacao)}</p>
                          </div>
                        ) : (
                          <span className="text-xs text-gray-400">—</span>
                        )}
                        {isVotacaoAberta && (
                          <span className="inline-block mt-1 text-[10px] px-1.5 py-0.5 bg-orange-100 text-orange-600 rounded-full font-bold animate-pulse">
                            AO VIVO
                          </span>
                        )}
                      </td>

                      {/* Ações */}
                      <td className="py-3 px-4 text-center" onClick={e => e.stopPropagation()}>
                        <div className="flex items-center justify-center gap-1.5">
                          <button
                            onClick={() => router.push(`/admin/assembleias/${a.id}`)}
                            title="Visualizar"
                            className="p-2 rounded-lg bg-blue-50 text-blue-600 hover:bg-blue-100 transition-colors"
                          >
                            <Eye size={16} />
                          </button>
                          {isRascunho && (
                            <button
                              onClick={() => handleDelete(a.id)}
                              title="Excluir rascunho"
                              className="p-2 rounded-lg bg-red-50 text-red-500 hover:bg-red-100 transition-colors"
                            >
                              <Trash2 size={16} />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="text-center py-16 bg-white rounded-2xl border border-gray-100 shadow-sm">
          <Gavel size={48} className="mx-auto mb-4 text-gray-300" />
          <h3 className="text-lg font-semibold text-gray-600 mb-2">
            {searchTerm || statusFilter !== 'todos'
              ? 'Nenhuma assembleia encontrada'
              : 'Nenhuma assembleia cadastrada'}
          </h3>
          <p className="text-sm text-gray-400 mb-6">
            {searchTerm || statusFilter !== 'todos'
              ? 'Tente ajustar os filtros de busca.'
              : 'Crie sua primeira assembleia e gerencie tudo por aqui.'}
          </p>
          {!searchTerm && statusFilter === 'todos' && (
            <button
              onClick={() => setShowCostModal(true)}
              className="inline-flex items-center gap-2 px-6 py-3 bg-[#FC5931] text-white rounded-xl font-semibold hover:bg-[#e04a2a] transition-all shadow-lg shadow-[#FC5931]/20 text-sm"
            >
              <PlusCircle size={18} />
              Criar Primeira Assembleia
            </button>
          )}
        </div>
      )}

      {/* ── LEGAL TIP ───────────────────────────────────── */}
      <div className="flex items-start gap-3 p-4 bg-amber-50 rounded-xl border border-amber-100">
        <AlertTriangle size={18} className="text-amber-500 mt-0.5 flex-shrink-0" />
        <div className="text-xs text-amber-700">
          <p className="font-semibold mb-1">📋 O que a Lei diz</p>
          <p>
            Lei 14.309/2022: Assembleias virtuais são permitidas se não proibidas pela convenção do condomínio.
            A convocação deve informar modalidade, link de acesso e instruções de participação com antecedência mínima
            prevista na convenção (geralmente 10 dias).
          </p>
        </div>
      </div>
      {/* ── COST MODAL ───────────────────────────────── */}
      {showCostModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="bg-white rounded-3xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden animate-in zoom-in-95 duration-300">
            {/* Header */}
            <div className="bg-gradient-to-r from-[#FC5931] to-orange-500 p-6 text-white relative">
              <button
                onClick={() => setShowCostModal(false)}
                title="Fechar"
                className="absolute top-4 right-4 p-1.5 rounded-full bg-white/20 hover:bg-white/30 transition-colors"
              >
                <X size={16} />
              </button>
              <div className="flex items-center gap-3 mb-2">
                <div className="w-10 h-10 bg-white/20 rounded-xl flex items-center justify-center">
                  <Sparkles size={20} />
                </div>
                <div>
                  <h3 className="text-lg font-bold">Serviços Opcionais</h3>
                  <p className="text-xs text-white/80">Gravação + Transcrição IA</p>
                </div>
              </div>
              <p className="text-xs text-white/70 mt-2">
                Ao criar uma assembleia, você pode usar dois serviços adicionais de forma independente:
              </p>
            </div>

            {/* Services */}
            <div className="p-6 space-y-4">
              {/* Service 1: Recording */}
              <div className="flex items-start gap-3 p-4 bg-emerald-50 rounded-xl border border-emerald-200">
                <div className="w-9 h-9 bg-emerald-100 rounded-lg flex items-center justify-center shrink-0">
                  <HardDrive size={18} className="text-emerald-600" />
                </div>
                <div>
                  <h4 className="text-sm font-bold text-emerald-800">Gravação na Nuvem</h4>
                  <p className="text-xs text-emerald-600 mt-0.5">Grave a sessão ao vivo e acesse a qualquer momento</p>
                  <p className="text-sm font-bold text-emerald-700 mt-1">
                    {formatCurrency(STORAGE_COST_PER_HOUR)} <span className="text-xs font-normal">/ hora / mês</span>
                  </p>
                </div>
              </div>

              {/* Service 2: AI Transcription */}
              <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-xl border border-blue-200">
                <div className="w-9 h-9 bg-blue-100 rounded-lg flex items-center justify-center shrink-0">
                  <FileText size={18} className="text-blue-600" />
                </div>
                <div>
                  <h4 className="text-sm font-bold text-blue-800">ATA por Inteligência Artificial</h4>
                  <p className="text-xs text-blue-600 mt-0.5">Transcrição automática + geração de ata formatada</p>
                  <p className="text-sm font-bold text-blue-700 mt-1">
                    {formatCurrency(AI_ATA_COST_PER_HOUR)} <span className="text-xs font-normal">/ hora de gravação</span>
                  </p>
                </div>
              </div>

              {/* Simulation Table */}
              <div className="bg-gray-50 rounded-xl border border-gray-200 overflow-hidden">
                <div className="flex items-center gap-2 p-3 bg-gray-100 border-b border-gray-200">
                  <DollarSign size={14} className="text-gray-600" />
                  <span className="text-xs font-bold text-gray-700">Simulação de Custo por Duração</span>
                </div>
                <table className="w-full text-xs">
                  <thead>
                    <tr className="border-b border-gray-200">
                      <th className="text-left py-2.5 px-4 text-gray-500 font-semibold">Duração</th>
                      <th className="text-center py-2.5 px-4 text-emerald-600 font-semibold">Gravação/mês</th>
                      <th className="text-center py-2.5 px-4 text-blue-600 font-semibold">ATA (IA)</th>
                      <th className="text-right py-2.5 px-4 text-gray-700 font-bold">Total*</th>
                    </tr>
                  </thead>
                  <tbody>
                    {[1, 2, 3].map(h => (
                      <tr key={h} className="border-b border-gray-100 last:border-0">
                        <td className="py-2.5 px-4 font-semibold text-gray-700">{h}h</td>
                        <td className="py-2.5 px-4 text-center text-emerald-600">{formatCurrency(STORAGE_COST_PER_HOUR * h)}</td>
                        <td className="py-2.5 px-4 text-center text-blue-600">{formatCurrency(AI_ATA_COST_PER_HOUR * h)}</td>
                        <td className="py-2.5 px-4 text-right font-bold text-gray-800">{formatCurrency((STORAGE_COST_PER_HOUR + AI_ATA_COST_PER_HOUR) * h)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <p className="text-[10px] text-gray-400 text-center">
                * Gravação é recorrente (mensal enquanto armazenada). ATA é cobrada uma única vez por transcrição.
                Ambos os serviços são opcionais.
              </p>

              {/* CTA */}
              <div className="flex gap-3 pt-2">
                <button
                  onClick={() => setShowCostModal(false)}
                  className="flex-1 py-3 rounded-xl border border-gray-200 text-sm font-semibold text-gray-600 hover:bg-gray-50 transition-colors"
                >
                  Cancelar
                </button>
                <button
                  onClick={() => { setShowCostModal(false); router.push('/admin/assembleias/nova') }}
                  className="flex-1 py-3 rounded-xl bg-[#FC5931] text-white text-sm font-bold hover:bg-[#e04a2a] transition-colors shadow-lg shadow-[#FC5931]/20 flex items-center justify-center gap-2"
                >
                  <PlusCircle size={16} />
                  Entendi, Criar Assembleia
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
