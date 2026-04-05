'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import {
  ArrowLeft, Gavel, Calendar, Globe, Building2, Video,
  FileText, Vote, Users, Eye, CheckCircle2, XCircle,
  Clock, Trash2, Play, Square, Send,
  ListOrdered, Settings, Info,
  Scale, PlusCircle, Printer
} from 'lucide-react'
import AssembleiaDashboard from './AssembleiaDashboard'
import ModalConfiguracoes from './ModalConfiguracoes'
import ModalNovaPauta from './ModalNovaPauta'
import LiveDashboard from './LiveDashboard'

/* ================================================================
   Types
   ================================================================ */

interface Assembleia {
  id: string
  condominio_id: string
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
  local_presencial: string | null
  jitsi_room_name: string | null
  eleicao_mesa: boolean
  presidente_mesa: string | null
  secretario_mesa: string | null
  peso_voto_tipo: string
  procuracao_exige_firma: boolean
  edital_url: string | null
  ata_url: string | null
  gravacao_url: string | null
  created_by: string
  created_at: string
  updated_at: string
}

interface Pauta {
  id: string
  ordem: number
  titulo: string
  descricao: string | null
  tipo: string
  quorum_tipo: string
  opcoes_voto: string[]
  modo_resposta: string
  max_escolhas: number
  resultado_visivel: boolean
}

interface Props {
  assembleia: Assembleia
  pautas: Pauta[]
  condoNome: string
  totalUnidades: number
  userId: string
  votos?: any[]
}

/* ================================================================
   Helpers
   ================================================================ */

const STATUS_CONFIG: Record<string, { label: string; color: string; bg: string; icon: React.ReactNode; textColor: string }> = {
  rascunho:       { label: 'Rascunho',       color: 'border-gray-300',   bg: 'bg-gray-50',    icon: <FileText size={16} />,      textColor: 'text-gray-600' },
  agendada:       { label: 'Agendada',       color: 'border-blue-300',   bg: 'bg-blue-50',    icon: <Calendar size={16} />,      textColor: 'text-blue-600' },
  em_andamento:   { label: 'Em Andamento',   color: 'border-green-300',  bg: 'bg-green-50',   icon: <Play size={16} />,          textColor: 'text-green-600' },
  votacao_aberta: { label: 'Votação Aberta', color: 'border-orange-300', bg: 'bg-orange-50',  icon: <Vote size={16} />,          textColor: 'text-orange-600' },
  finalizada:     { label: 'Finalizada',     color: 'border-purple-300', bg: 'bg-purple-50',  icon: <CheckCircle2 size={16} />,  textColor: 'text-purple-600' },
  ata_publicada:  { label: 'Ata Publicada',  color: 'border-emerald-300',bg: 'bg-emerald-50', icon: <FileText size={16} />,      textColor: 'text-emerald-600' },
  cancelada:      { label: 'Cancelada',      color: 'border-red-300',    bg: 'bg-red-50',     icon: <XCircle size={16} />,       textColor: 'text-red-500' },
}

const QUORUM_LABELS: Record<string, string> = {
  simples: 'Maioria Simples',
  dois_tercos: '2/3 dos Presentes',
  unanimidade: 'Unanimidade',
}

const MODALIDADE_LABELS: Record<string, { label: string; icon: React.ReactNode }> = {
  online:     { label: 'Online', icon: <Globe size={16} /> },
  presencial: { label: 'Presencial', icon: <Building2 size={16} /> },
  hibrida:    { label: 'Híbrida', icon: <Video size={16} /> },
}

function formatDateTime(d: string | null) {
  if (!d) return '—'
  return new Date(d).toLocaleString('pt-BR', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

/* ================================================================
   Component
   ================================================================ */

export default function AssembleiaDetalheClient({
  assembleia,
  pautas,
  condoNome,
  totalUnidades,
  userId,
  votos = [],
}: Props) {
  const router = useRouter()
  const supabase = createClient()
  const [status, setStatus] = useState(assembleia.status)
  const [loading, setLoading] = useState(false)
  const [showConfigModal, setShowConfigModal] = useState(false)
  const [showPautaModal, setShowPautaModal] = useState(false)

  const statusCfg = STATUS_CONFIG[status] ?? STATUS_CONFIG.rascunho
  const modalidade = MODALIDADE_LABELS[assembleia.modalidade] ?? MODALIDADE_LABELS.online
  const isRascunho = status === 'rascunho'

  // ── Status transition ──────────────────────────────────
  async function changeStatus(newStatus: string) {
    const confirmMsg: Record<string, string> = {
      agendada: 'Publicar esta assembleia? Os moradores serão notificados.',
      em_andamento: 'Iniciar a sessão da assembleia? Moradores poderão participar da sala ao vivo.',
      finalizada: 'Encerrar a assembleia? Esta ação não pode ser desfeita e os resultados serão consolidados.',
      cancelada: 'Cancelar esta assembleia? Esta ação não pode ser desfeita.',
    }

    if (!confirm(confirmMsg[newStatus] ?? `Alterar status para ${newStatus}?`)) return

    setLoading(true)
    const { error } = await supabase
      .from('assembleias')
      .update({ status: newStatus })
      .eq('id', assembleia.id)

    if (!error) {
      setStatus(newStatus)
      // Audit log
      await supabase.from('assembleia_audit_log').insert({
        assembleia_id: assembleia.id,
        evento: `alterou_status_${newStatus}`,
        dados: { de: status, para: newStatus },
        user_id: userId,
      })
      router.refresh()
    } else {
      alert('Erro ao alterar status: ' + error.message)
    }
    setLoading(false)
  }

  // ── Delete (only rascunho) ─────────────────────────────
  async function handleDelete() {
    if (!confirm('Excluir esta assembleia e todos os dados vinculados? Esta ação não pode ser desfeita.')) return
    setLoading(true)
    await supabase.from('assembleias').delete().eq('id', assembleia.id)
    router.push('/admin/assembleias')
  }

  // ── Status flow buttons ────────────────────────────────
  function getStatusActions(): { label: string; status: string; icon: React.ReactNode; color: string }[] {
    switch (status) {
      case 'rascunho':
        return [{ label: 'Publicar Assembleia', status: 'agendada', icon: <Send size={16} />, color: 'bg-blue-500 hover:bg-blue-600 text-white' }]
      case 'agendada':
        return [
          { label: 'Iniciar Sessão', status: 'em_andamento', icon: <Play size={16} />, color: 'bg-green-500 hover:bg-green-600 text-white' },
          { label: 'Encerrar Assembleia', status: 'finalizada', icon: <Square size={16} />, color: 'bg-purple-500 hover:bg-purple-600 text-white' },
        ]
      case 'em_andamento':
        return [
          { label: 'Encerrar Assembleia', status: 'finalizada', icon: <Square size={16} />, color: 'bg-purple-500 hover:bg-purple-600 text-white' },
        ]
      default:
        return []
    }
  }

  return (
    <div className="max-w-5xl mx-auto px-4 py-8 space-y-6">

      {/* ── HEADER ───────────────────────────────────────── */}
      <div className="flex items-start justify-between">
        <div className="flex items-start gap-3">
          <button
            onClick={() => router.push('/admin/assembleias')}
            className="p-2 mt-1 rounded-lg hover:bg-gray-100 transition-colors"
            title="Voltar para lista"
          >
            <ArrowLeft size={20} className="text-gray-600" />
          </button>
          <div>
            <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-3">
              <Gavel size={24} className="text-[#FC5931]" />
              {assembleia.nome}
            </h1>
            <p className="text-sm text-gray-500 mt-0.5">
              {condoNome} · {assembleia.tipo} · {modalidade.label}
            </p>
          </div>
        </div>

        {/* Status badge & Print */}
        <div className="flex items-center gap-3">
          <button
            onClick={() => router.push(`/admin/assembleias/${assembleia.id}/edital`)}
            className="print:hidden flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 hover:bg-gray-200 border border-gray-200 rounded-xl font-semibold transition-colors text-sm"
          >
            <Printer size={16} />
            <span className="hidden sm:inline">Gerar Edital / PDF</span>
          </button>
          
          <div className={`flex items-center gap-2 px-4 py-2 rounded-xl border-2 ${statusCfg.color} ${statusCfg.bg}`}>
            {statusCfg.icon}
            <span className={`text-sm font-bold ${statusCfg.textColor}`}>{statusCfg.label}</span>
          </div>
        </div>
      </div>

      {/* ── STATUS ACTIONS ───────────────────────────────── */}
      {(getStatusActions().length > 0 || isRascunho) && (
        <div className="flex items-center gap-3 flex-wrap">
          {getStatusActions().map(action => (
            <button
              key={action.status}
              onClick={() => changeStatus(action.status)}
              disabled={loading}
              className={`flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold transition-all shadow-sm disabled:opacity-40 ${action.color}`}
            >
              {action.icon}
              {action.label}
            </button>
          ))}

          {/* Cancel button for non-final states */}
          {['rascunho', 'agendada', 'em_andamento'].includes(status) && (
            <button
              onClick={() => changeStatus('cancelada')}
              disabled={loading}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium text-red-600 bg-red-50 hover:bg-red-100 transition-colors border border-red-200 disabled:opacity-40 ml-auto"
            >
              <XCircle size={16} />
              Cancelar
            </button>
          )}

          {/* Delete (rascunho only) */}
          {isRascunho && (
            <button
              onClick={handleDelete}
              disabled={loading}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium text-red-600 bg-red-50 hover:bg-red-100 transition-colors border border-red-200 disabled:opacity-40"
            >
              <Trash2 size={16} />
              Excluir
            </button>
          )}
        </div>
      )}

      {/* ── LIVE DASHBOARD OU CONFIGURACOES ───────────────────────────────────── */}
      {status === 'em_andamento' || status === 'votacao_aberta' ? (
        <LiveDashboard assembleia={assembleia} pautas={pautas} userId={userId} totalUnidades={totalUnidades} />
      ) : (
        <>
          {/* ── INFO CARDS ───────────────────────────────────── */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <Calendar size={16} className="text-blue-500" />
            <span className="text-xs text-gray-500">1ª Convocação</span>
          </div>
          <p className="text-sm font-semibold text-gray-800">{formatDateTime(assembleia.dt_1a_convocacao)}</p>
        </div>

        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <Calendar size={16} className="text-indigo-500" />
            <span className="text-xs text-gray-500">2ª Convocação</span>
          </div>
          <p className="text-sm font-semibold text-gray-800">{formatDateTime(assembleia.dt_2a_convocacao)}</p>
        </div>

        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <Vote size={16} className="text-orange-500" />
            <span className="text-xs text-gray-500">Início Votação</span>
          </div>
          <p className="text-sm font-semibold text-gray-800">{formatDateTime(assembleia.dt_inicio_votacao)}</p>
        </div>

        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <Clock size={16} className="text-red-500" />
            <span className="text-xs text-gray-500">Fim Votação</span>
          </div>
          <p className="text-sm font-semibold text-gray-800">{formatDateTime(assembleia.dt_fim_votacao)}</p>
        </div>
      </div>

      {/* ── SETTINGS SUMMARY ─────────────────────────────── */}
      <div className="bg-white rounded-xl border border-gray-100 p-5 shadow-sm">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-bold text-gray-700 flex items-center gap-2">
            <Settings size={16} className="text-[#FC5931]" />
            Configurações
          </h3>
          <button
            onClick={() => setShowConfigModal(true)}
            className="text-xs font-semibold text-[#FC5931] hover:text-[#e04a2a] bg-[#FC5931]/10 px-3 py-1.5 rounded-lg transition-colors"
          >
            Editar Configurações
          </button>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4 text-sm">
          <div>
            <span className="text-xs text-gray-500 block">Tipo</span>
            <span className="font-medium text-gray-800">{assembleia.tipo}</span>
          </div>
          <div>
            <span className="text-xs text-gray-500 block">Modalidade</span>
            <span className="font-medium text-gray-800 flex items-center gap-1.5">{modalidade.icon} {modalidade.label}</span>
          </div>
          <div>
            <span className="text-xs text-gray-500 block">Peso do Voto</span>
            <span className="font-medium text-gray-800 flex items-center gap-1.5">
              <Scale size={14} />
              {assembleia.peso_voto_tipo === 'unitario' ? '1 unidade = 1 voto' : 'Fração Ideal'}
            </span>
          </div>
          <div>
            <span className="text-xs text-gray-500 block">Mesa Diretora</span>
            <span className="font-medium text-gray-800">
              {assembleia.eleicao_mesa
                ? 'Eleição durante assembleia'
                : `${assembleia.presidente_mesa ?? '—'}${assembleia.secretario_mesa ? ` / ${assembleia.secretario_mesa}` : ''}`
              }
            </span>
          </div>
          <div>
            <span className="text-xs text-gray-500 block">Procuração</span>
            <span className="font-medium text-gray-800">
              {assembleia.procuracao_exige_firma ? '📋 Exige firma reconhecida' : '📄 Simples (sem firma)'}
            </span>
          </div>
          <div>
            <span className="text-xs text-gray-500 block">Unidades</span>
            <span className="font-medium text-gray-800 flex items-center gap-1.5">
              <Users size={14} />
              {totalUnidades} unidades
            </span>
          </div>
          {assembleia.local_presencial && (
            <div className="sm:col-span-2">
              <span className="text-xs text-gray-500 block">Local Presencial</span>
              <span className="font-medium text-gray-800">{assembleia.local_presencial}</span>
            </div>
          )}
        </div>
      </div>

      {/* ── PAUTAS OU DASHBOARD ────────────────────────────── */}
      {status === 'finalizada' ? (
        <AssembleiaDashboard assembleia={assembleia} pautas={pautas} votos={votos} totalUnidades={totalUnidades} />
      ) : (
        <div className="bg-white rounded-xl border border-gray-100 p-5 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-bold text-gray-700 flex items-center gap-2">
              <ListOrdered size={16} className="text-[#FC5931]" />
              Pautas ({pautas.length})
            </h3>
            <button
              onClick={() => setShowPautaModal(true)}
              className="text-xs font-semibold text-[#FC5931] hover:text-[#e04a2a] bg-[#FC5931]/10 px-3 py-1.5 rounded-lg flex items-center gap-1 transition-colors"
            >
              <PlusCircle size={14} /> Nova Pauta / Enquete
            </button>
          </div>

        {pautas.length === 0 ? (
          <p className="text-sm text-gray-400 text-center py-4">Nenhuma pauta cadastrada</p>
        ) : (
          <div className="space-y-3">
            {pautas.map(p => {
              const opcoes = Array.isArray(p.opcoes_voto) ? p.opcoes_voto : (typeof p.opcoes_voto === 'string' ? JSON.parse(p.opcoes_voto) : [])

              return (
                <div
                  key={p.id}
                  className="flex items-start gap-4 p-4 bg-gray-50 rounded-xl hover:bg-gray-100/60 transition-colors"
                >
                  {/* Ordem badge */}
                  <span className="w-8 h-8 rounded-full bg-[#FC5931] text-white text-sm font-bold flex items-center justify-center shrink-0">
                    {p.ordem}
                  </span>

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-gray-800">{p.titulo}</p>
                    {p.descricao && (
                      <p className="text-xs text-gray-500 mt-1">{p.descricao}</p>
                    )}

                    <div className="flex flex-wrap items-center gap-2 mt-2">
                      {/* Tipo */}
                      <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-semibold ${
                        p.tipo === 'votacao'
                          ? 'bg-orange-100 text-orange-700'
                          : 'bg-blue-100 text-blue-700'
                      }`}>
                        {p.tipo === 'votacao' ? '🗳️ Votação' : 'ℹ️ Informativo'}
                      </span>

                      {/* Quorum */}
                      {p.tipo === 'votacao' && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-medium bg-gray-200 text-gray-600">
                          {QUORUM_LABELS[p.quorum_tipo] ?? p.quorum_tipo}
                        </span>
                      )}

                      {/* Modo resposta */}
                      {p.tipo === 'votacao' && (
                        <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-medium ${
                          p.modo_resposta === 'multipla'
                            ? 'bg-blue-100 text-blue-700'
                            : 'bg-green-100 text-green-700'
                        }`}>
                          {p.modo_resposta === 'multipla'
                            ? `☑️ Múltipla (máx ${p.max_escolhas})`
                            : '🔘 Resposta Única'
                          }
                        </span>
                      )}

                      {/* Resultado visível */}
                      {p.resultado_visivel && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-medium bg-amber-100 text-amber-700">
                          <Eye size={10} /> Resultado visível
                        </span>
                      )}
                    </div>

                    {/* Opções de voto */}
                    {p.tipo === 'votacao' && opcoes.length > 0 && (
                      <div className="flex flex-wrap gap-1.5 mt-2">
                        {opcoes.map((op: string, i: number) => (
                          <span
                            key={i}
                            className={`inline-flex items-center px-2.5 py-1 rounded-lg text-[11px] font-medium ${
                              p.modo_resposta === 'multipla'
                                ? 'bg-blue-50 text-blue-700 border border-blue-200'
                                : 'bg-green-50 text-green-700 border border-green-200'
                            }`}
                          >
                            {p.modo_resposta === 'multipla' ? '☑️' : '🔘'} {op}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>
      )}

      {/* ── AUDIT LOG TIP ────────────────────────────────── */}
      <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-xl text-sm text-blue-700">
        <Info size={18} className="mt-0.5 shrink-0" />
        <div>
          <p className="font-medium">📋 ID da Assembleia</p>
          <p className="text-xs mt-1 text-blue-600 flex items-center gap-2">
            <code className="bg-blue-100 px-2 py-0.5 rounded text-[11px] font-mono">{assembleia.id}</code>
            <span className="text-blue-400">Criada em {formatDateTime(assembleia.created_at)}</span>
          </p>
        </div>
      </div>
      </>
      )}

      {showConfigModal && (
        <ModalConfiguracoes
          assembleia={assembleia}
          onClose={() => setShowConfigModal(false)}
          onSuccess={() => { setShowConfigModal(false); router.refresh() }}
        />
      )}

      {showPautaModal && (
        <ModalNovaPauta
          assembleiaId={assembleia.id}
          nextOrdem={pautas.length + 1}
          onClose={() => setShowPautaModal(false)}
          onSuccess={() => { setShowPautaModal(false); router.refresh() }}
        />
      )}
    </div>
  )
}

