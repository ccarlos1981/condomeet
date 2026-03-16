'use client'
import { useState, useTransition, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import {
  PlusCircle, ToggleLeft, ToggleRight, Trash2, BarChart3,
  List, Printer, X, ChevronDown, ChevronUp
} from 'lucide-react'

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
  ativa: boolean
  validade: string | null
  created_at: string
  opcoes: Opcao[]
  totalRespostas: number
}

interface RespostaRow {
  nome: string
  bloco: string
  apto: string
  resultado: string
  data: string
}

interface Props {
  condominioId: string
  enquetes: Enquete[]
  totalUnidades: number
}

/* ================================================================
   Component
   ================================================================ */

export default function EnquetesAdminClient({
  condominioId,
  enquetes: initialEnquetes,
  totalUnidades,
}: Props) {
  const router = useRouter()
  const supabase = createClient()
  const [isPending, startTransition] = useTransition()

  const [enquetes, setEnquetes] = useState(initialEnquetes)

  // Sync local state when server props change (after router.refresh)
  useEffect(() => {
    setEnquetes(initialEnquetes)
  }, [initialEnquetes])

  // ── Create form state ──────────────────────────────────────
  const [pergunta, setPergunta] = useState('')
  const [tipoResposta, setTipoResposta] = useState<'unica' | 'multipla'>('unica')
  const [opcoes, setOpcoes] = useState<string[]>([])
  const [novaOpcao, setNovaOpcao] = useState('')
  const [validade, setValidade] = useState('')
  const [saving, setSaving] = useState(false)

  // ── View states ────────────────────────────────────────────
  const [chartModal, setChartModal] = useState<Enquete | null>(null)
  const [chartData, setChartData] = useState<{ texto: string; count: number }[]>([])
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const [respostas, setRespostas] = useState<RespostaRow[]>([])
  const [loadingRespostas, setLoadingRespostas] = useState(false)

  // ── Add option ─────────────────────────────────────────────
  function addOpcao() {
    const text = novaOpcao.trim()
    if (!text || opcoes.includes(text)) return
    setOpcoes([...opcoes, text])
    setNovaOpcao('')
  }

  function removeOpcao(idx: number) {
    setOpcoes(opcoes.filter((_, i) => i !== idx))
  }

  // ── Create enquete ─────────────────────────────────────────
  async function handleCreate() {
    if (!pergunta.trim() || opcoes.length < 2) return
    setSaving(true)

    try {
      const { data: enquete, error } = await supabase
        .from('enquetes')
        .insert({
          condominio_id: condominioId,
          pergunta: pergunta.trim(),
          tipo_resposta: tipoResposta,
          ativa: false,
          validade: validade || null,
        })
        .select()
        .single()

      if (error || !enquete) {
        alert('Erro ao criar enquete: ' + (error?.message ?? 'Verifique as permissões.'))
        setSaving(false)
        return
      }

      // Insert options
      const opcoesData = opcoes.map((texto, i) => ({
        enquete_id: enquete.id,
        texto,
        ordem: i + 1,
      }))
      const { data: insertedOpcoes } = await supabase
        .from('enquete_opcoes')
        .insert(opcoesData)
        .select()

      // Add to local state immediately (optimistic)
      const newEnquete: Enquete = {
        id: enquete.id,
        pergunta: enquete.pergunta,
        tipo_resposta: enquete.tipo_resposta,
        ativa: enquete.ativa,
        validade: enquete.validade,
        created_at: enquete.created_at,
        opcoes: (insertedOpcoes ?? []).map(o => ({
          id: o.id,
          texto: o.texto,
          ordem: o.ordem,
        })),
        totalRespostas: 0,
      }
      setEnquetes(prev => [newEnquete, ...prev])

      // Reset form
      setPergunta('')
      setTipoResposta('unica')
      setOpcoes([])
      setNovaOpcao('')
      setValidade('')
    } catch (e) {
      alert('Erro inesperado: ' + e)
    } finally {
      setSaving(false)
    }
  }

  // ── Toggle active ──────────────────────────────────────────
  async function toggleAtiva(enquete: Enquete) {
    const newAtiva = !enquete.ativa
    // Optimistic update
    setEnquetes(prev => prev.map(e =>
      e.id === enquete.id ? { ...e, ativa: newAtiva } : e
    ))
    await supabase
      .from('enquetes')
      .update({ ativa: newAtiva })
      .eq('id', enquete.id)
  }

  // ── Delete enquete ─────────────────────────────────────────
  async function handleDelete(id: string) {
    if (!confirm('Excluir esta enquete e todas as respostas?')) return
    // Optimistic update
    setEnquetes(prev => prev.filter(e => e.id !== id))
    await supabase.from('enquetes').delete().eq('id', id)
  }

  // ── Show chart modal ───────────────────────────────────────
  async function showChart(enquete: Enquete) {
    // For each option, count responses
    const { data } = await supabase
      .from('enquete_respostas')
      .select('opcao_id')
      .eq('enquete_id', enquete.id)

    const counts: Record<string, number> = {}
    for (const r of (data ?? [])) {
      counts[r.opcao_id] = (counts[r.opcao_id] || 0) + 1
    }

    setChartData(
      enquete.opcoes.map(o => ({
        texto: o.texto,
        count: counts[o.id] || 0,
      }))
    )
    setChartModal(enquete)
  }

  // ── Load responses by unit ─────────────────────────────────
  async function loadRespostas(enquete: Enquete) {
    if (expandedId === enquete.id) {
      setExpandedId(null)
      return
    }
    setLoadingRespostas(true)
    setExpandedId(enquete.id)

    const { data } = await supabase
      .from('enquete_respostas')
      .select(`
        created_at, bloco, apto, opcao_id,
        perfil:user_id(nome_completo)
      `)
      .eq('enquete_id', enquete.id)
      .order('created_at', { ascending: false })

    const opcaoMap: Record<string, string> = {}
    enquete.opcoes.forEach(o => { opcaoMap[o.id] = o.texto })

    setRespostas(
      (data ?? []).map(r => ({
        nome: (r.perfil as unknown as { nome_completo: string })?.nome_completo ?? '',
        bloco: r.bloco ?? '',
        apto: r.apto ?? '',
        resultado: opcaoMap[r.opcao_id] ?? '',
        data: new Date(r.created_at).toLocaleDateString('pt-BR'),
      }))
    )
    setLoadingRespostas(false)
  }

  // ── Print responses ────────────────────────────────────────
  function printRespostas(enquete: Enquete) {
    const rows = respostas.length > 0 ? respostas : []
    const html = `
      <html><head><title>Respostas - ${enquete.pergunta}</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        h2 { color: #333; }
        table { width: 100%; border-collapse: collapse; margin-top: 16px; }
        th, td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
        th { background: #f5f5f5; font-weight: bold; }
        .meta { color: #666; font-size: 13px; margin-bottom: 4px; }
      </style></head><body>
      <h2>Enquete: ${enquete.pergunta}</h2>
      <p class="meta">Tipo: ${enquete.tipo_resposta === 'unica' ? 'Única' : 'Múltipla'} | Criada: ${new Date(enquete.created_at).toLocaleDateString('pt-BR')}</p>
      <table>
        <thead><tr><th>Nome</th><th>Data</th><th>Bloco</th><th>Apto</th><th>Resposta</th></tr></thead>
        <tbody>${rows.map(r =>
          `<tr><td>${r.nome}</td><td>${r.data}</td><td>${r.bloco}</td><td>${r.apto}</td><td>${r.resultado}</td></tr>`
        ).join('')}</tbody>
      </table>
      <p style="margin-top:16px;color:#999;font-size:11px;">Total de respostas: ${rows.length}</p>
      </body></html>
    `
    const win = window.open('', '_blank')
    if (win) {
      win.document.write(html)
      win.document.close()
      win.print()
    }
  }

  // ── Percentage helper ──────────────────────────────────────
  function pct(enquete: Enquete) {
    if (totalUnidades === 0) return 0
    // Count unique users who responded
    return Math.round((enquete.totalRespostas / totalUnidades) * 100)
  }

  // ════════════════════════════════════════════════════════════
  //  RENDER
  // ════════════════════════════════════════════════════════════

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-8">
      <h1 className="text-2xl font-bold text-gray-800">
        📊 Enquetes
      </h1>

      {/* ── CREATE FORM ──────────────────────────────────── */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 space-y-5">
        <h2 className="text-lg font-semibold text-gray-700">Criar Nova Enquete</h2>

        {/* Pergunta */}
        <div>
          <label className="block text-sm font-medium text-gray-600 mb-1">
            Pergunta da Enquete
          </label>
          <input
            type="text"
            value={pergunta}
            onChange={e => setPergunta(e.target.value)}
            placeholder="Ex: Qual cor preferem para o hall?"
            className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
          />
        </div>

        {/* Tipo de resposta */}
        <div>
          <label className="block text-sm font-medium text-gray-600 mb-2">
            Tipo de Resposta
          </label>
          <div className="flex gap-4">
            {(['unica', 'multipla'] as const).map(t => (
              <label key={t} className="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name="tipoResposta"
                  checked={tipoResposta === t}
                  onChange={() => setTipoResposta(t)}
                  className="w-4 h-4 text-[#FC5931] focus:ring-[#FC5931]"
                />
                <span className="text-sm text-gray-700">
                  {t === 'unica' ? '🔘 Única' : '☑️ Múltipla'}
                </span>
              </label>
            ))}
          </div>
        </div>

        {/* Opções de resposta */}
        <div>
          <label className="block text-sm font-medium text-gray-600 mb-2">
            Respostas (mínimo 2)
          </label>
          <div className="flex gap-2 mb-3">
            <input
              type="text"
              value={novaOpcao}
              onChange={e => setNovaOpcao(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && addOpcao()}
              placeholder="Acrescente sua resposta aqui"
              className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
            />
            <button
              onClick={addOpcao}
              disabled={!novaOpcao.trim()}
              className="px-4 py-2.5 bg-[#FC5931] text-white rounded-xl hover:bg-[#e0324a] disabled:opacity-40 transition-colors"
              title="Adicionar opção"
            >
              <PlusCircle size={18} />
            </button>
          </div>

          {opcoes.map((opcao, i) => (
            <div key={i} className="flex items-center gap-2 mb-2 bg-gray-50 rounded-xl px-4 py-2.5">
              <span className="text-sm text-gray-700 flex-1">
                Resposta: {opcao}
              </span>
              <button
                onClick={() => removeOpcao(i)}
                className="text-red-400 hover:text-red-600 transition-colors"
                title="Remover opção"
              >
                <X size={16} />
              </button>
            </div>
          ))}
        </div>

        {/* Validade */}
        <div>
          <label className="block text-sm font-medium text-gray-600 mb-1">
            Validade da Enquete
          </label>
          <input
            type="date"
            value={validade}
            onChange={e => setValidade(e.target.value)}
            className="px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
          />
        </div>

        {/* Submit */}
        <button
          onClick={handleCreate}
          disabled={saving || !pergunta.trim() || opcoes.length < 2}
          className="w-full py-3 bg-[#FC5931] text-white rounded-xl font-semibold hover:bg-[#e0324a] disabled:opacity-40 transition-colors text-sm"
        >
          {saving ? 'Salvando...' : 'Inserir Enquete'}
        </button>
      </div>

      {/* ── ENQUETES LIST ────────────────────────────────── */}
      {enquetes.map(enquete => (
        <div
          key={enquete.id}
          className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden"
        >
          {/* Status bar */}
          <div className="flex items-center gap-3 px-6 py-3 bg-gray-50 border-b border-gray-100">
            <span className="text-xs font-medium text-gray-500">
              Status de respostas:
            </span>
            <div className="flex-1 h-5 bg-gray-200 rounded-full overflow-hidden relative">
              <div
                className="h-full bg-[#FC5931] rounded-full transition-all duration-500"
                style={{ width: `${Math.min(pct(enquete), 100)}%` }}
              />
              <span className="absolute inset-0 flex items-center justify-center text-[10px] font-bold text-gray-700">
                {pct(enquete)}%
              </span>
            </div>
          </div>

          {/* Card content */}
          <div className="p-6">
            <div className="flex gap-6">
              {/* Left info */}
              <div className="flex-1 space-y-1">
                <p className="text-xs text-gray-400">
                  Id da enquete: {enquete.id.slice(0, 8)}
                </p>
                <p className="text-sm">
                  <span className="font-semibold text-gray-600">Pergunta da Enquete:</span>
                  <br />
                  <span className="text-gray-800 font-medium">{enquete.pergunta}</span>
                </p>
                <p className="text-sm text-gray-600">
                  Status:{' '}
                  <span className={`font-semibold ${enquete.ativa ? 'text-green-600' : 'text-gray-400'}`}>
                    {enquete.ativa ? 'Ativa' : 'Inativa'}
                  </span>
                </p>
                <p className="text-xs text-gray-400">
                  Enquete criada: {new Date(enquete.created_at).toLocaleDateString('pt-BR')}
                </p>
                {enquete.validade && (
                  <p className="text-xs text-gray-400">
                    Validade: {new Date(enquete.validade).toLocaleDateString('pt-BR')}
                  </p>
                )}
              </div>

              {/* Right: options + actions */}
              <div className="space-y-2">
                <p className="text-xs font-semibold text-gray-500">
                  Opções de Respostas ({enquete.tipo_resposta === 'unica' ? 'Única' : 'Múltipla'}):
                </p>
                {enquete.opcoes.map(o => (
                  <p key={o.id} className="text-sm text-gray-600 pl-2">
                    Opção: {o.texto}
                  </p>
                ))}

                {/* Action buttons */}
                <div className="flex gap-2 pt-2">
                  <button
                    onClick={() => toggleAtiva(enquete)}
                    title={enquete.ativa ? 'Desativar' : 'Ativar'}
                    className={`p-2 rounded-lg transition-colors ${
                      enquete.ativa
                        ? 'bg-green-100 text-green-600 hover:bg-green-200'
                        : 'bg-gray-100 text-gray-400 hover:bg-gray-200'
                    }`}
                  >
                    {enquete.ativa ? <ToggleRight size={20} /> : <ToggleLeft size={20} />}
                  </button>
                  <button
                    onClick={() => showChart(enquete)}
                    title="Exibir gráfico de respostas"
                    className="p-2 rounded-lg bg-blue-100 text-blue-600 hover:bg-blue-200 transition-colors"
                  >
                    <BarChart3 size={20} />
                  </button>
                  <button
                    onClick={() => handleDelete(enquete.id)}
                    title="Excluir enquete"
                    className="p-2 rounded-lg bg-red-100 text-red-500 hover:bg-red-200 transition-colors"
                  >
                    <Trash2 size={20} />
                  </button>
                  <button
                    onClick={() => printRespostas(enquete)}
                    title="Imprimir respostas"
                    className="p-2 rounded-lg bg-orange-100 text-orange-600 hover:bg-orange-200 transition-colors"
                  >
                    <Printer size={20} />
                  </button>
                </div>
              </div>
            </div>

            {/* Expandable response buttons */}
            <div className="flex gap-3 mt-4 pt-4 border-t border-gray-100">
              <button
                onClick={() => loadRespostas(enquete)}
                className="flex items-center gap-2 px-4 py-2 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e0324a] transition-colors"
              >
                {expandedId === enquete.id ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                {expandedId === enquete.id ? 'Ocultar respostas' : 'Exibir Respostas'}
              </button>
              <button
                onClick={async () => {
                  await loadRespostas(enquete)
                  setTimeout(() => printRespostas(enquete), 500)
                }}
                className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-xl text-sm font-medium hover:bg-orange-600 transition-colors"
              >
                <Printer size={16} />
                Imprimir respostas
              </button>
            </div>

            {/* Expanded responses table */}
            {expandedId === enquete.id && (
              <div className="mt-4 overflow-x-auto">
                {loadingRespostas ? (
                  <p className="text-sm text-gray-400 py-4 text-center">Carregando...</p>
                ) : respostas.length === 0 ? (
                  <p className="text-sm text-gray-400 py-4 text-center">Nenhuma resposta ainda.</p>
                ) : (
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-gray-200">
                        <th className="text-left py-2 px-3 text-gray-500 font-semibold">Nome</th>
                        <th className="text-left py-2 px-3 text-gray-500 font-semibold">Data</th>
                        <th className="text-center py-2 px-3 text-gray-500 font-semibold">Apto</th>
                        <th className="text-center py-2 px-3 text-gray-500 font-semibold">Bloco</th>
                        <th className="text-left py-2 px-3 text-gray-500 font-semibold">Resultado</th>
                      </tr>
                    </thead>
                    <tbody>
                      {respostas.map((r, i) => (
                        <tr key={i} className="border-b border-gray-50 hover:bg-gray-50">
                          <td className="py-2 px-3 text-gray-700">{r.nome}</td>
                          <td className="py-2 px-3 text-gray-500">{r.data}</td>
                          <td className="py-2 px-3 text-center text-gray-600">{r.apto}</td>
                          <td className="py-2 px-3 text-center text-gray-600">{r.bloco}</td>
                          <td className="py-2 px-3 text-gray-700 font-medium">{r.resultado}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            )}
          </div>
        </div>
      ))}

      {enquetes.length === 0 && (
        <div className="text-center py-12 text-gray-400">
          <BarChart3 size={48} className="mx-auto mb-3 opacity-30" />
          <p>Nenhuma enquete cadastrada.</p>
        </div>
      )}

      {/* ── CHART MODAL ──────────────────────────────────── */}
      {chartModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-xl max-w-lg w-full p-6 relative">
            <button
              onClick={() => setChartModal(null)}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600"
              title="Fechar"
            >
              <X size={20} />
            </button>

            <h3 className="text-lg font-bold text-gray-800 mb-1">
              📊 Resultado da Enquete
            </h3>
            <p className="text-sm text-gray-500 mb-6">{chartModal.pergunta}</p>

            {/* Bar chart */}
            <div className="space-y-3">
              {chartData.map((d, i) => {
                const total = chartData.reduce((s, x) => s + x.count, 0)
                const pctVal = total > 0 ? Math.round((d.count / total) * 100) : 0
                const colors = ['#FC5931', '#3B82F6', '#10B981', '#F59E0B', '#8B5CF6', '#EC4899']
                return (
                  <div key={i}>
                    <div className="flex justify-between text-sm mb-1">
                      <span className="text-gray-700 font-medium">{d.texto}</span>
                      <span className="text-gray-500">{d.count} votos ({pctVal}%)</span>
                    </div>
                    <div className="h-6 bg-gray-100 rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full transition-all duration-700"
                        style={{
                          width: `${pctVal}%`,
                          backgroundColor: colors[i % colors.length],
                        }}
                      />
                    </div>
                  </div>
                )
              })}
            </div>

            <p className="text-xs text-gray-400 mt-4 text-center">
              Total de votos: {chartData.reduce((s, x) => s + x.count, 0)}
            </p>
          </div>
        </div>
      )}
    </div>
  )
}
