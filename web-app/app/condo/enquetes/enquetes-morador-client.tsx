'use client'
import { useState, useMemo } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { X, ChevronRight, BarChart3, ListOrdered } from 'lucide-react'

/* ================================================================
   Types
   ================================================================ */

interface Opcao {
  id: string
  texto: string
  ordem: number
}

interface Enquete {
  id: string
  pergunta: string
  tipo_resposta: 'unica' | 'multipla'
  validade: string | null
  created_at: string
  enquete_opcoes: Opcao[]
}

interface Props {
  enquetes: Enquete[]
  unitRespostas: { enquete_id: string; opcao_id: string; created_at: string }[]
  allRespostas: { enquete_id: string; opcao_id: string }[]
  userId: string
  bloco: string
  apto: string
}

/* ================================================================
   Component
   ================================================================ */

export default function EnquetesMoradorClient({
  enquetes,
  unitRespostas: initialUnitRespostas,
  allRespostas: initialAllRespostas,
  userId,
  bloco,
  apto,
}: Props) {
  const supabase = createClient()
  const router = useRouter()

  // Track unit responses locally
  const [unitRespostas, setUnitRespostas] = useState(initialUnitRespostas)
  const [allRespostas, setAllRespostas] = useState(initialAllRespostas)

  // Modal state
  const [openEnquete, setOpenEnquete] = useState<Enquete | null>(null)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [sending, setSending] = useState(false)
  const [showResult, setShowResult] = useState(false)

  // ── Helpers ──────────────────────────────────────────────
  function isExpired(enquete: Enquete): boolean {
    if (!enquete.validade) return false
    return new Date(enquete.validade) < new Date(new Date().toDateString())
  }

  function unitVotedFor(enqueteId: string): string[] {
    return unitRespostas
      .filter(r => r.enquete_id === enqueteId)
      .map(r => r.opcao_id)
  }

  function hasUnitVoted(enqueteId: string): boolean {
    return unitRespostas.some(r => r.enquete_id === enqueteId)
  }

  function fmtDate(d: string): string {
    try {
      return new Date(d).toLocaleDateString('pt-BR')
    } catch {
      return d
    }
  }

  // ── Chart data for an enquete ────────────────────────────
  function chartDataFor(enquete: Enquete) {
    const opcoes = [...(enquete.enquete_opcoes ?? [])].sort((a, b) => a.ordem - b.ordem)
    const counts: Record<string, number> = {}
    for (const r of allRespostas) {
      if (r.enquete_id === enquete.id) {
        counts[r.opcao_id] = (counts[r.opcao_id] || 0) + 1
      }
    }
    const total = opcoes.reduce((s, o) => s + (counts[o.id] || 0), 0)
    return { opcoes, counts, total }
  }

  // ── Open enquete modal ───────────────────────────────────
  function openModal(enquete: Enquete) {
    const voted = unitVotedFor(enquete.id)
    setOpenEnquete(enquete)
    setSelected(new Set(voted))
    setShowResult(voted.length > 0)
  }

  // ── Handle selection ─────────────────────────────────────
  function handleSelect(opcaoId: string) {
    if (!openEnquete) return
    if (openEnquete.tipo_resposta === 'unica') {
      setSelected(new Set([opcaoId]))
    } else {
      setSelected(prev => {
        const next = new Set(prev)
        if (next.has(opcaoId)) next.delete(opcaoId)
        else next.add(opcaoId)
        return next
      })
    }
  }

  // ── Submit vote ──────────────────────────────────────────
  async function handleSubmit() {
    if (!openEnquete || selected.size === 0) return
    setSending(true)

    try {
      // Delete previous responses for this unit
      await supabase
        .from('enquete_respostas')
        .delete()
        .eq('enquete_id', openEnquete.id)
        .eq('bloco', bloco)
        .eq('apto', apto)

      // Insert new responses
      const rows = Array.from(selected).map(opcaoId => ({
        enquete_id: openEnquete.id,
        opcao_id: opcaoId,
        user_id: userId,
        bloco,
        apto,
      }))

      const { error } = await supabase
        .from('enquete_respostas')
        .insert(rows)

      if (error) {
        alert('Erro ao enviar voto: ' + error.message)
      } else {
        // Update local state
        setUnitRespostas(prev => {
          const filtered = prev.filter(r => r.enquete_id !== openEnquete!.id)
          const newRows = rows.map(r => ({
            enquete_id: r.enquete_id,
            opcao_id: r.opcao_id,
            created_at: new Date().toISOString(),
          }))
          return [...filtered, ...newRows]
        })
        // Update all respostas for chart
        setAllRespostas(prev => {
          const filtered = prev.filter(r =>
            !(r.enquete_id === openEnquete!.id &&
              unitRespostas.some(u => u.enquete_id === openEnquete!.id && u.opcao_id === r.opcao_id))
          )
          const newRows = rows.map(r => ({
            enquete_id: r.enquete_id,
            opcao_id: r.opcao_id,
          }))
          return [...filtered, ...newRows]
        })
        setShowResult(true)
      }
    } catch (e) {
      alert('Erro: ' + e)
    } finally {
      setSending(false)
    }
  }

  // ── Revote ───────────────────────────────────────────────
  function handleRevote() {
    setShowResult(false)
  }

  // ── Enquete numbering ────────────────────────────────────
  const enqueteNumbers = useMemo(() => {
    const map: Record<string, number> = {}
    enquetes.forEach((e, i) => { map[e.id] = enquetes.length - i })
    return map
  }, [enquetes])

  // ════════════════════════════════════════════════════════════
  //  RENDER
  // ════════════════════════════════════════════════════════════

  return (
    <div className="max-w-3xl mx-auto space-y-4">
      <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
        <BarChart3 size={24} className="text-[#FC3951]" />
        Enquetes
      </h1>

      {enquetes.length === 0 && (
        <div className="text-center py-16 text-gray-400">
          <BarChart3 size={48} className="mx-auto mb-3 opacity-30" />
          <p>Nenhuma enquete ativa no momento.</p>
        </div>
      )}

      {/* ── LIST ──────────────────────────────────── */}
      {enquetes.map(enquete => {
        const expired = isExpired(enquete)
        const voted = hasUnitVoted(enquete.id)

        return (
          <div key={enquete.id}>
            {/* Date header */}
            <p className="text-sm text-gray-500 font-medium mb-2">
              Data da enquete: {fmtDate(enquete.created_at)}
            </p>

            {/* Card */}
            <button
              onClick={() => openModal(enquete)}
              className={`w-full flex items-center gap-4 px-5 py-4 rounded-2xl transition-all duration-150 text-left ${
                expired
                  ? 'bg-[#FC3951] text-white shadow-md shadow-[#FC3951]/20'
                  : voted
                    ? 'bg-green-50 border-2 border-green-200 text-gray-800 hover:shadow-md'
                    : 'bg-white border border-gray-200 text-gray-800 hover:shadow-md hover:border-gray-300'
              }`}
            >
              <ListOrdered size={28} className={expired ? 'text-white/80' : 'text-[#FC3951]'} />
              <div className="flex-1 min-w-0">
                <p className={`text-xs font-medium ${expired ? 'text-white/70' : 'text-gray-400'}`}>
                  Pergunta:
                </p>
                <p className={`text-sm font-semibold truncate ${expired ? 'text-white' : ''}`}>
                  {enquete.pergunta}
                </p>
              </div>
              <div className="text-right flex-shrink-0">
                <p className={`text-xs font-medium ${expired ? 'text-white/70' : 'text-gray-400'}`}>
                  Validade:
                </p>
                <p className={`text-sm font-semibold ${expired ? 'text-white' : ''}`}>
                  {enquete.validade ? fmtDate(enquete.validade) : '—'}
                </p>
              </div>
              <ChevronRight size={24} className={`flex-shrink-0 ${expired ? 'text-white' : 'text-green-500'}`} />
            </button>
          </div>
        )
      })}

      {/* ── MODAL ─────────────────────────────────── */}
      {openEnquete && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-xl max-w-lg w-full max-h-[90vh] overflow-y-auto relative">
            {/* Header */}
            <div className="flex justify-between items-start p-6 pb-3 border-b border-gray-100">
              <div>
                <p className="text-sm text-gray-500 font-medium">
                  Enquete de Número:
                </p>
                <p className="text-sm font-bold text-gray-800">
                  {enqueteNumbers[openEnquete.id]}ª enquete
                </p>
              </div>
              <div className="text-right">
                <p className="text-sm text-gray-500 font-medium">
                  Enquete válida até o dia:
                </p>
                <p className="text-sm font-bold text-gray-800">
                  {openEnquete.validade ? fmtDate(openEnquete.validade) : '—'}
                </p>
              </div>
              <button
                onClick={() => { setOpenEnquete(null); setShowResult(false) }}
                className="ml-2 text-red-500 hover:text-red-700 flex-shrink-0"
              >
                <X size={22} />
              </button>
            </div>

            {/* Content */}
            <div className="p-6 space-y-4">
              {/* Pergunta */}
              <div className="bg-gray-50 rounded-xl p-4 border border-gray-100">
                <p className="text-xs font-semibold text-gray-500 mb-1">Pergunta:</p>
                <p className="text-sm text-gray-800 font-medium">{openEnquete.pergunta}</p>
              </div>

              {/* Opções */}
              <div>
                <p className="text-xs font-semibold text-gray-500 mb-2">Opções de respostas:</p>
                <div className="space-y-2">
                  {[...(openEnquete.enquete_opcoes ?? [])].sort((a, b) => a.ordem - b.ordem).map(opcao => {
                    const isSelected = selected.has(opcao.id)
                    const isUnica = openEnquete.tipo_resposta === 'unica'
                    const disabled = showResult && !isExpired(openEnquete)

                    return (
                      <label
                        key={opcao.id}
                        className={`flex items-center gap-3 px-4 py-3 rounded-xl border cursor-pointer transition-all ${
                          isSelected
                            ? 'border-[#FC3951] bg-[#FC3951]/5'
                            : 'border-gray-200 hover:border-gray-300'
                        } ${disabled ? 'opacity-60 pointer-events-none' : ''}`}
                      >
                        <input
                          type={isUnica ? 'radio' : 'checkbox'}
                          name={`enquete-${openEnquete.id}`}
                          checked={isSelected}
                          onChange={() => handleSelect(opcao.id)}
                          className="w-4 h-4 accent-[#FC3951]"
                          disabled={disabled}
                        />
                        <span className="text-sm text-gray-700">{opcao.texto}</span>
                      </label>
                    )
                  })}
                </div>
              </div>

              {/* ── After voting ─────────────────────────── */}
              {showResult ? (
                <div className="space-y-4">
                  {/* Confirmation */}
                  <div className="text-center py-2">
                    <p className="text-base font-bold text-gray-800">Obrigado!</p>
                    <p className="text-sm text-gray-600">
                      Seu apto já respondeu a pesquisa.
                    </p>
                    <p className="text-xs text-gray-400 mt-1">
                      Até a validade da enquete, seu apto poderá responder novamente.
                    </p>
                  </div>

                  {/* Last unit response */}
                  <div className="bg-gray-50 rounded-xl p-3 border border-gray-100">
                    <p className="text-xs font-bold text-gray-600">
                      Última(s) resposta(s) do seu APTO:{' '}
                      <span className="text-gray-800">
                        {(() => {
                          const voted = unitVotedFor(openEnquete.id)
                          const opcoes = openEnquete.enquete_opcoes ?? []
                          return opcoes
                            .filter(o => voted.includes(o.id))
                            .map(o => o.texto)
                            .join(', ')
                        })()}
                      </span>
                    </p>
                  </div>

                  {/* Revote button */}
                  {!isExpired(openEnquete) && (
                    <div className="text-center">
                      <button
                        onClick={handleRevote}
                        className="px-6 py-2.5 bg-gray-600 text-white rounded-xl text-sm font-semibold hover:bg-gray-700 transition-colors"
                      >
                        Responder novamente
                      </button>
                    </div>
                  )}

                  {/* Partial chart */}
                  <div>
                    <p className="text-sm font-bold text-gray-700 text-center mb-3">
                      Resultado parcial da enquete:
                    </p>
                    <EnqueteBarChart enquete={openEnquete} allRespostas={allRespostas} />
                  </div>
                </div>
              ) : (
                /* Submit button */
                <button
                  onClick={handleSubmit}
                  disabled={selected.size === 0 || sending || isExpired(openEnquete)}
                  className="w-full py-3 bg-gray-500 text-white rounded-xl font-semibold text-sm hover:bg-gray-600 disabled:opacity-40 transition-colors"
                >
                  {sending ? 'Enviando...' : isExpired(openEnquete) ? 'Enquete encerrada' : 'Responder'}
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

/* ================================================================
   Bar Chart Component
   ================================================================ */

function EnqueteBarChart({
  enquete,
  allRespostas,
}: {
  enquete: Enquete
  allRespostas: { enquete_id: string; opcao_id: string }[]
}) {
  const opcoes = [...(enquete.enquete_opcoes ?? [])].sort((a, b) => a.ordem - b.ordem)
  const counts: Record<string, number> = {}
  for (const r of allRespostas) {
    if (r.enquete_id === enquete.id) {
      counts[r.opcao_id] = (counts[r.opcao_id] || 0) + 1
    }
  }
  const maxVal = Math.max(...opcoes.map(o => counts[o.id] || 0), 1)
  const colors = ['#FC3951', '#3B82F6', '#10B981', '#F59E0B', '#8B5CF6', '#EC4899', '#14B8A6', '#F97316']

  return (
    <div className="bg-gray-50 rounded-xl p-4 border border-gray-100">
      {/* Title */}
      <p className="text-xs font-semibold text-gray-600 text-center mb-3 leading-snug">
        {enquete.pergunta}
      </p>
      {/* Bars */}
      <div className="flex items-end gap-3 justify-center" style={{ minHeight: 120 }}>
        {opcoes.map((o, i) => {
          const val = counts[o.id] || 0
          const heightPct = maxVal > 0 ? (val / maxVal) * 100 : 0
          const color = colors[i % colors.length]
          return (
            <div key={o.id} className="flex flex-col items-center gap-1" style={{ flex: 1, maxWidth: 60 }}>
              <span className="text-xs font-bold text-gray-600">{val}</span>
              <div
                className="w-full rounded-t-lg transition-all duration-500"
                style={{
                  height: `${Math.max(heightPct, 4)}px`,
                  minHeight: 4,
                  maxHeight: 100,
                  backgroundColor: color,
                }}
              />
              <span className="text-[10px] font-semibold text-gray-500 mt-1">
                Resp {i + 1}
              </span>
            </div>
          )
        })}
      </div>

      {/* Legend */}
      <div className="mt-4 space-y-1 border-t border-gray-200 pt-3">
        {opcoes.map((o, i) => (
          <div key={o.id} className="flex items-center gap-2 text-xs text-gray-600">
            <div
              className="w-3 h-3 rounded-sm flex-shrink-0"
              style={{ backgroundColor: colors[i % colors.length] }}
            />
            <span className="font-semibold">Resp {i + 1}:</span>
            <span className="truncate">{o.texto}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
