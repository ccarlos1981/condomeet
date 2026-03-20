'use client'

import { useState, useMemo } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  CheckCircle, XCircle, ClipboardList, Save, Loader2, History, PlusCircle,
  ChevronDown
} from 'lucide-react'

// ─── Types ───────────────────────────────────────────────────

type InventarioItem = {
  id: string
  assunto_id: string
  condominio_id: string
  nome: string
  quantidade: number
  unidade: string
  observacao: string | null
  turno_assuntos: { titulo: string }
}

type Registro = {
  id: string
  porteiro_nome: string
  observacao: string | null
  created_at: string
}

type RegistroItem = {
  id: string
  inventario_id: string
  confere: boolean
  qtd_informada: number | null
  comentario: string | null
}

type Porteiro = {
  id: string
  nome_completo: string
}

type ItemCheck = {
  inventario_id: string
  confere: boolean
  qtd_informada: number | null
  comentario: string
}

const DIAS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado']

function formatDate(iso: string) {
  const d = new Date(iso)
  return {
    data: d.toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }),
    dia: DIAS[d.getDay()],
  }
}

// ─── Main Component ──────────────────────────────────────────

export default function RegistroTurnoPorteiroClient({
  inventario,
  registros: initialRegistros,
  porteiros,
  nomesHistoricos,
  condoId,
  registrosComDivergencia: initialDivergencias,
}: {
  inventario: InventarioItem[]
  registros: Registro[]
  porteiros: Porteiro[]
  nomesHistoricos: string[]
  condoId: string
  registrosComDivergencia: string[]
}) {
  const [tab, setTab] = useState<'historico' | 'adicionar'>('historico')
  const [registros, setRegistros] = useState(initialRegistros)
  const [divergenciaIds, setDivergenciaIds] = useState<Set<string>>(new Set(initialDivergencias))

  // ─── Detail view state ─────────────────────────────────────
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const [currentPage, setCurrentPage] = useState(1)
  const ITEMS_PER_PAGE = 10
  const [detailItems, setDetailItems] = useState<RegistroItem[]>([])
  const [loadingDetail, setLoadingDetail] = useState(false)

  // ─── Adicionar state ────────────────────────────────────────
  const [selectedPorteiro, setSelectedPorteiro] = useState('')
  const [porteiroNome, setPorteiroNome] = useState('')

  // Merged dropdown names: profiles + historical, no duplicates
  const dropdownNomes = useMemo(() => {
    const perfNomes = porteiros.map(p => p.nome_completo)
    const all = [...perfNomes, ...nomesHistoricos]
    return [...new Set(all)].sort()
  }, [porteiros, nomesHistoricos])
  const [observacao, setObservacao] = useState('')
  const [saving, setSaving] = useState(false)
  const [savedMsg, setSavedMsg] = useState('')

  // Item checks: keyed by inventario_id
  const [checks, setChecks] = useState<Record<string, ItemCheck>>(() => {
    const map: Record<string, ItemCheck> = {}
    for (const item of inventario) {
      map[item.id] = { inventario_id: item.id, confere: true, qtd_informada: null, comentario: '' }
    }
    return map
  })

  // Text suggestions: previous observações from selected porteiro
  const sugestoes = useMemo(() => {
    return registros
      .filter(r => {
        const p = porteiros.find(pt => pt.id === selectedPorteiro)
        return p && r.porteiro_nome === p.nome_completo && r.observacao
      })
      .map(r => r.observacao!)
      .filter((v, i, a) => a.indexOf(v) === i)
      .slice(0, 5)
  }, [selectedPorteiro, registros, porteiros])

  // ─── Load detail for a registro ────────────────────────────
  async function toggleDetail(registroId: string) {
    if (expandedId === registroId) {
      setExpandedId(null)
      return
    }
    setLoadingDetail(true)
    setExpandedId(registroId)
    const supabase = createClient()
    const { data } = await supabase
      .from('turno_registro_itens')
      .select('*')
      .eq('registro_id', registroId)
    setDetailItems(data ?? [])
    setLoadingDetail(false)
  }

  function toggleCheck(itemId: string) {
    setChecks(prev => ({
      ...prev,
      [itemId]: {
        ...prev[itemId],
        confere: !prev[itemId].confere,
        qtd_informada: prev[itemId].confere ? 0 : null,
        comentario: prev[itemId].confere ? prev[itemId].comentario : '',
      },
    }))
  }

  function updateCheck(itemId: string, field: 'qtd_informada' | 'comentario', value: string) {
    setChecks(prev => ({
      ...prev,
      [itemId]: {
        ...prev[itemId],
        [field]: field === 'qtd_informada' ? Number(value) || 0 : value,
      },
    }))
  }

  async function handleSave() {
    if (!porteiroNome.trim()) return
    setSaving(true)
    setSavedMsg('')
    const supabase = createClient()
    const nameToSave = porteiroNome.trim()
    if (!nameToSave) return
    const p = porteiros.find(pt => pt.nome_completo === nameToSave)

    // 1. Create registro
    const { data: registro, error } = await supabase
      .from('turno_registros')
      .insert({
        condominio_id: condoId,
        porteiro_id: p?.id || null,
        porteiro_nome: nameToSave,
        observacao: observacao.trim() || null,
      })
      .select()
      .single()

    if (error || !registro) {
      setSavedMsg('Erro ao salvar: ' + (error?.message ?? 'desconhecido'))
      setSaving(false)
      return
    }

    // 2. Insert ONLY divergent items (confere === false)
    const itensPayload = Object.values(checks)
      .filter(c => !c.confere)
      .map(c => ({
        registro_id: registro.id,
        inventario_id: c.inventario_id,
        confere: false,
        qtd_informada: c.qtd_informada,
        comentario: c.comentario || null,
      }))

    if (itensPayload.length > 0) {
      await supabase.from('turno_registro_itens').insert(itensPayload)
    }

    // 3. Update local state
    setRegistros(prev => [registro, ...prev])
    // Track divergence for the new registro
    const hasDivergence = Object.values(checks).some(c => !c.confere)
    if (hasDivergence) {
      setDivergenciaIds(prev => new Set([...prev, registro.id]))
    }
    setSavedMsg('✅ Registro salvo com sucesso!')
    setObservacao('')
    // Reset checks
    const resetMap: Record<string, ItemCheck> = {}
    for (const item of inventario) {
      resetMap[item.id] = { inventario_id: item.id, confere: true, qtd_informada: null, comentario: '' }
    }
    setChecks(resetMap)
    setSaving(false)

    // Switch to history
    setTimeout(() => {
      setTab('historico')
      setSavedMsg('')
    }, 2000)
  }

  return (
    <div className="max-w-4xl mx-auto">
      {/* Title */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Registre aqui como foi seu turno</h1>
      </div>

      {/* Radio tabs */}
      <div className="flex items-center gap-6 mb-6">
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="radio"
            name="tab"
            checked={tab === 'historico'}
            onChange={() => setTab('historico')}
            className="w-4 h-4 accent-[#FC5931]"
          />
          <span className="flex items-center gap-1.5 font-medium text-sm text-gray-700">
            <History size={16} /> Histórico dos Registros
          </span>
        </label>
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="radio"
            name="tab"
            checked={tab === 'adicionar'}
            onChange={() => setTab('adicionar')}
            className="w-4 h-4 accent-[#FC5931]"
          />
          <span className="flex items-center gap-1.5 font-medium text-sm text-gray-700">
            <PlusCircle size={16} /> Adicionar Registro de turno
          </span>
        </label>
      </div>

      {/* ─── HISTÓRICO ─────────────────────────────────────────── */}
      {tab === 'historico' && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          {registros.length === 0 ? (
            <div className="text-center py-16 text-gray-400">
              <ClipboardList size={40} className="mx-auto mb-3 opacity-30" />
              <p className="font-medium text-gray-500">Nenhum registro de turno</p>
              <p className="text-sm">Clique em &quot;Adicionar Registro&quot; para criar o primeiro</p>
            </div>
          ) : (
            <div>
              {/* Header row */}
              <div className="grid grid-cols-[1fr_1fr_1fr_40px] border-b border-gray-200 bg-gray-50 px-5 py-3">
                <span className="font-semibold text-sm text-gray-600">Data do registro</span>
                <span className="font-semibold text-sm text-gray-600 text-center">Dia da semana</span>
                <span className="font-semibold text-sm text-gray-600 text-right">Nome porteiro</span>
                <span></span>
              </div>

              {/* Accordion rows — paginated */}
              {registros.slice((currentPage - 1) * ITEMS_PER_PAGE, currentPage * ITEMS_PER_PAGE).map(r => {
                const { data, dia } = formatDate(r.created_at)
                const isExpanded = expandedId === r.id
                const hasDivergencia = divergenciaIds.has(r.id)
                const discrepancies = isExpanded ? detailItems.filter(i => !i.confere) : []

                return (
                  <div key={r.id}>
                    {/* Row */}
                    <div
                      onClick={() => toggleDetail(r.id)}
                      className={`grid grid-cols-[1fr_1fr_1fr_40px] items-center px-5 py-3 cursor-pointer transition-colors border-b ${
                        isExpanded
                          ? 'bg-[#FC5931]/10 border-b-[#FC5931]/20'
                          : hasDivergencia
                            ? 'bg-red-50 border-b-red-100 hover:bg-red-100/60'
                            : 'border-b-gray-100 hover:bg-gray-50'
                      }`}
                    >
                      <span className={`text-sm ${hasDivergencia ? 'text-red-700 font-medium' : 'text-gray-700'}`}>{data}</span>
                      <span className={`text-sm text-center ${hasDivergencia ? 'text-red-700' : 'text-gray-700'}`}>{dia}</span>
                      <span className={`text-sm text-right font-medium ${hasDivergencia ? 'text-red-800' : 'text-gray-800'}`}>{r.porteiro_nome}</span>
                      <span className="flex justify-center">
                        <ChevronDown
                          size={18}
                          className={`transition-transform duration-200 ${
                            isExpanded ? 'rotate-180 text-[#FC5931]' : 'text-gray-400'
                          }`}
                        />
                      </span>
                    </div>

                    {/* Expanded detail — opens BELOW the row */}
                    {isExpanded && (
                      <div className="border-b-2 border-[#FC5931]/20 bg-white px-6 py-5">
                        {loadingDetail ? (
                          <div className="text-center py-4">
                            <Loader2 size={20} className="animate-spin mx-auto text-gray-400" />
                          </div>
                        ) : (
                          <div className="space-y-5">
                            {/* Header */}
                            <div className="text-center">
                              <h3 className="text-base font-bold text-gray-800">Relato do Porteiro: {r.porteiro_nome}</h3>
                              <p className="text-xs text-gray-500 mt-0.5">Data da criação: {data} — {dia}</p>
                            </div>

                            {/* Divergências — tabela estilo antigo */}
                            {discrepancies.length > 0 ? (
                              <div>
                                {discrepancies.map(item => {
                                  const invItem = inventario.find(i => i.id === item.inventario_id)
                                  return (
                                    <div key={item.id} className="mb-4 border border-gray-200 rounded-lg overflow-hidden">
                                      {/* Cabeçalho tabela */}
                                      <div className="grid grid-cols-3 bg-gray-50 border-b border-gray-200 px-4 py-2">
                                        <span className="text-xs font-bold text-gray-600">Material</span>
                                        <span className="text-xs font-bold text-gray-600 text-center">QTD</span>
                                        <span className="text-xs font-bold text-gray-600 text-right">Tipo</span>
                                      </div>
                                      {/* Material info */}
                                      <div className="grid grid-cols-3 px-4 py-3 border-b border-gray-100">
                                        <span className="text-sm font-semibold text-gray-800">{invItem?.nome ?? 'Item'}</span>
                                        <span className="text-sm text-gray-700 text-center">{invItem?.quantidade ?? '-'}</span>
                                        <span className="text-sm text-gray-700 text-right">{invItem?.unidade ?? '-'}</span>
                                      </div>
                                      {/* Quantidade divergente */}
                                      <div className="px-4 py-3 bg-red-50 border-2 border-dashed border-red-300">
                                        <div className="flex items-center justify-between mb-2">
                                          <span className="text-xs text-red-700 font-medium">Quantidade de: {invItem?.nome}</span>
                                          <span className="bg-white border border-red-300 rounded px-3 py-1 text-sm font-bold text-red-700 min-w-[50px] text-center">
                                            {item.qtd_informada ?? '-'}
                                          </span>
                                        </div>
                                        {item.comentario && (
                                          <div className="bg-white border border-red-200 rounded px-3 py-2 mt-1">
                                            <p className="text-xs text-red-700">{item.comentario}</p>
                                          </div>
                                        )}
                                      </div>
                                    </div>
                                  )
                                })}
                              </div>
                            ) : (
                              <p className="text-center text-sm text-green-600 font-medium">✅ Nenhuma divergência no inventário</p>
                            )}

                            {/* O que o Porteiro relatou */}
                            <div>
                              <p className="text-center text-xs text-gray-500 font-medium mb-2">O que o Porteiro relatou...</p>
                              <div className="border border-gray-200 rounded-lg">
                                <div className="px-4 py-1.5 bg-gray-50 border-b border-gray-200">
                                  <span className="text-xs font-bold text-gray-600">Oobs gerais:</span>
                                </div>
                                <div className="px-4 py-3 min-h-[60px]">
                                  <p className="text-sm text-gray-700 whitespace-pre-wrap">
                                    {r.observacao || ''}
                                  </p>
                                </div>
                              </div>
                            </div>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                )
              })}

              {/* Pagination */}
              {registros.length > ITEMS_PER_PAGE && (
                <div className="flex items-center justify-center gap-2 py-4 border-t border-gray-100">
                  <button
                    onClick={() => { setCurrentPage(p => Math.max(1, p - 1)); setExpandedId(null) }}
                    disabled={currentPage === 1}
                    className="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
                  >
                    ← Anterior
                  </button>
                  {Array.from({ length: Math.ceil(registros.length / ITEMS_PER_PAGE) }, (_, i) => i + 1).map(pg => (
                    <button
                      key={pg}
                      onClick={() => { setCurrentPage(pg); setExpandedId(null) }}
                      className={`w-8 h-8 text-sm rounded-lg transition-colors ${
                        pg === currentPage
                          ? 'bg-[#FC5931] text-white font-bold'
                          : 'border border-gray-200 hover:bg-gray-50 text-gray-600'
                      }`}
                    >
                      {pg}
                    </button>
                  ))}
                  <button
                    onClick={() => { setCurrentPage(p => Math.min(Math.ceil(registros.length / ITEMS_PER_PAGE), p + 1)); setExpandedId(null) }}
                    disabled={currentPage === Math.ceil(registros.length / ITEMS_PER_PAGE)}
                    className="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
                  >
                    Próximo →
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* ─── ADICIONAR ─────────────────────────────────────────── */}
      {tab === 'adicionar' && (
        <div className="space-y-6">
          {/* Inventory check */}
          <div>
            <h2 className="text-lg font-bold text-gray-800 mb-4">Histórico do inventário</h2>
            {inventario.length === 0 ? (
              <p className="text-gray-400 text-sm">Nenhum item cadastrado no inventário. Peça ao síndico para configurar.</p>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {inventario.map(item => {
                  const check = checks[item.id]
                  return (
                    <div
                      key={item.id}
                      className={`bg-white rounded-xl border-2 transition-all duration-200 ${
                        check.confere
                          ? 'border-green-200 shadow-sm'
                          : 'border-red-300 shadow-md'
                      }`}
                    >
                      {/* Item header */}
                      <div className="flex items-center justify-between px-4 py-3">
                        <div>
                          <p className="font-semibold text-gray-800 text-sm">{item.nome}</p>
                          <p className="text-xs text-gray-400 mt-0.5">
                            <span className="font-bold text-gray-600">{item.quantidade}</span> {item.unidade}
                          </p>
                        </div>
                        <button
                          onClick={() => toggleCheck(item.id)}
                          className="transition-transform hover:scale-110"
                          title={check.confere ? 'Marcar como divergente' : 'Marcar como confere'}
                        >
                          {check.confere
                            ? <CheckCircle size={28} className="text-green-500" />
                            : <XCircle size={28} className="text-red-500" />
                          }
                        </button>
                      </div>

                      {/* Expanded: discrepancy fields */}
                      {!check.confere && (
                        <div className="px-4 pb-4 pt-1 space-y-2 border-t border-red-100 bg-red-50/30">
                          <div>
                            <label className="text-xs font-medium text-gray-500">Outra quantidade:</label>
                            <input
                              type="number"
                              min={0}
                              value={check.qtd_informada ?? ''}
                              onChange={e => updateCheck(item.id, 'qtd_informada', e.target.value)}
                              placeholder="0"
                              className="w-full border border-red-200 rounded-lg px-3 py-1.5 text-sm mt-1 focus:outline-none focus:ring-2 focus:ring-red-300 bg-white"
                            />
                          </div>
                          <div>
                            <label className="text-xs font-medium text-gray-500">Comentário sobre esse material:</label>
                            <textarea
                              value={check.comentario}
                              onChange={e => updateCheck(item.id, 'comentario', e.target.value)}
                              placeholder="Escreva aqui um comentário sobre esse material"
                              rows={2}
                              className="w-full border border-red-200 rounded-lg px-3 py-1.5 text-sm mt-1 resize-none focus:outline-none focus:ring-2 focus:ring-red-300 bg-white"
                            />
                          </div>
                        </div>
                      )}
                    </div>
                  )
                })}
              </div>
            )}
          </div>

          {/* Shift change section */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
            <h2 className="text-lg font-bold text-gray-800 mb-4">Mudança de Turno</h2>

            {/* Porter selection */}
            <div className="flex gap-4 mb-4">
              <div className="flex-1">
                <label className="text-xs font-medium text-gray-500 mb-1 block">Escolha seu nome aqui...</label>
                <select
                  value={selectedPorteiro}
                  onChange={e => {
                    const nome = e.target.value
                    setSelectedPorteiro(nome)
                    setPorteiroNome(nome)
                  }}
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                  title="Selecione o porteiro"
                >
                  <option value="">Selecione...</option>
                  {dropdownNomes.map(nome => (
                    <option key={nome} value={nome}>{nome}</option>
                  ))}
                </select>
              </div>
              <div className="flex-1">
                <label className="text-xs font-medium text-gray-500 mb-1 block">Seu nome</label>
                <input
                  value={porteiroNome}
                  onChange={e => setPorteiroNome(e.target.value)}
                  placeholder="Escolha seu nome ou escreva seu nome aqui"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                />
              </div>
            </div>

            {/* Text suggestions */}
            {sugestoes.length > 0 && (
              <div className="mb-4">
                <p className="text-xs font-semibold text-gray-500 mb-2">
                  Histórico dos seus textos, clique nele e ganhe tempo.
                </p>
                <div className="flex flex-wrap gap-2">
                  {sugestoes.map((s, i) => (
                    <button
                      key={i}
                      onClick={() => setObservacao(s)}
                      className="text-xs px-3 py-1.5 bg-gray-100 hover:bg-[#FC5931]/10 hover:text-[#FC5931] text-gray-600 rounded-lg transition-colors text-left max-w-[300px] truncate"
                      title={s}
                    >
                      {s.length > 60 ? s.slice(0, 60) + '…' : s}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* Observation textarea */}
            <div className="mb-4">
              <label className="text-xs font-medium text-gray-500 mb-1 block">Observação geral do seu turno</label>
              <textarea
                value={observacao}
                onChange={e => setObservacao(e.target.value)}
                placeholder="Escreva aqui a observação geral do seu turno"
                rows={5}
                className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
              />
            </div>

            {/* Save */}
            <div className="flex items-center gap-4">
              <button
                onClick={handleSave}
                disabled={saving || !selectedPorteiro}
                className="flex items-center gap-2 bg-[#FC5931] text-white px-8 py-3 rounded-xl font-semibold text-sm hover:bg-[#D42F1D] transition-colors disabled:opacity-40 shadow-sm shadow-[#FC5931]/20"
              >
                {saving ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
                {saving ? 'Salvando...' : 'Salvar'}
              </button>
              {savedMsg && (
                <span className={`text-sm font-medium ${savedMsg.includes('Erro') ? 'text-red-600' : 'text-green-600'}`}>{savedMsg}</span>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
