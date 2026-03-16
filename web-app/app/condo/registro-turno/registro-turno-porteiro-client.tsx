'use client'

import { useState, useMemo } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  CheckCircle, XCircle, ClipboardList, Save, Loader2, History, PlusCircle,
  ChevronDown, ChevronUp, ArrowLeft
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
  condoId,
  currentUserId,
  currentUserName,
  registrosComDivergencia: initialDivergencias,
}: {
  inventario: InventarioItem[]
  registros: Registro[]
  porteiros: Porteiro[]
  condoId: string
  currentUserId: string
  currentUserName: string
  registrosComDivergencia: string[]
}) {
  const [tab, setTab] = useState<'historico' | 'adicionar'>('historico')
  const [registros, setRegistros] = useState(initialRegistros)
  const [divergenciaIds, setDivergenciaIds] = useState<Set<string>>(new Set(initialDivergencias))

  // ─── Detail view state ─────────────────────────────────────
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const [detailItems, setDetailItems] = useState<RegistroItem[]>([])
  const [loadingDetail, setLoadingDetail] = useState(false)

  // ─── Adicionar state ────────────────────────────────────────
  const [selectedPorteiro, setSelectedPorteiro] = useState(currentUserId)
  const [porteiroNome, setPorteiroNome] = useState(currentUserName)
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
    if (!selectedPorteiro) return
    setSaving(true)
    setSavedMsg('')
    const supabase = createClient()
    const p = porteiros.find(pt => pt.id === selectedPorteiro)

    // 1. Create registro
    const { data: registro, error } = await supabase
      .from('turno_registros')
      .insert({
        condominio_id: condoId,
        porteiro_id: selectedPorteiro,
        porteiro_nome: p?.nome_completo ?? porteiroNome,
        observacao: observacao.trim() || null,
      })
      .select()
      .single()

    if (error || !registro) {
      setSavedMsg('Erro ao salvar: ' + (error?.message ?? 'desconhecido'))
      setSaving(false)
      return
    }

    // 2. Insert item checks
    const itensPayload = Object.values(checks).map(c => ({
      registro_id: registro.id,
      inventario_id: c.inventario_id,
      confere: c.confere,
      qtd_informada: c.confere ? null : c.qtd_informada,
      comentario: c.confere ? null : c.comentario || null,
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
              {/* Detail view */}
              {expandedId && (() => {
                const r = registros.find(r => r.id === expandedId)
                if (!r) return null
                const { data, dia } = formatDate(r.created_at)
                const discrepancies = detailItems.filter(i => !i.confere)
                return (
                  <div className="p-6">
                    {/* Back button */}
                    <button
                      onClick={() => setExpandedId(null)}
                      className="flex items-center gap-2 text-[#FC5931] hover:text-[#D42F1D] font-medium text-sm mb-4 transition-colors"
                    >
                      <ArrowLeft size={18} /> Voltar ao histórico
                    </button>

                    {/* Porter report */}
                    <div className="text-center mb-4">
                      <h2 className="text-lg font-bold text-gray-800">Relato do Porteiro: {r.porteiro_nome}</h2>
                      <p className="text-sm text-gray-500">Data da criação: {data} — {dia}</p>
                      <p className="text-xs text-gray-400 mt-1">O que o Porteiro relatou...</p>
                    </div>

                    {/* Observation text */}
                    <div className="bg-gray-50 rounded-xl border border-gray-100 p-5 mb-6 min-h-[100px]">
                      <p className="text-sm text-gray-700 whitespace-pre-wrap">
                        {r.observacao || 'Nenhuma observação registrada.'}
                      </p>
                    </div>

                    {/* Inventory discrepancies */}
                    {loadingDetail ? (
                      <div className="text-center py-4">
                        <Loader2 size={20} className="animate-spin mx-auto text-gray-400" />
                      </div>
                    ) : discrepancies.length > 0 && (
                      <div className="mb-6">
                        <h3 className="text-sm font-bold text-red-600 mb-3">⚠️ Divergências no inventário</h3>
                        <div className="space-y-2">
                          {discrepancies.map(item => {
                            const invItem = inventario.find(i => i.id === item.inventario_id)
                            return (
                              <div
                                key={item.id}
                                className="flex items-start gap-3 bg-red-50 border border-red-200 rounded-xl px-4 py-3"
                              >
                                <XCircle size={18} className="text-red-500 mt-0.5 flex-shrink-0" />
                                <div>
                                  <p className="font-semibold text-sm text-red-800">
                                    {invItem?.nome ?? 'Item desconhecido'}
                                    {item.qtd_informada !== null && (
                                      <span className="font-normal text-red-600 ml-2">
                                        (esperado: {invItem?.quantidade} → informado: {item.qtd_informada})
                                      </span>
                                    )}
                                  </p>
                                  {item.comentario && (
                                    <p className="text-xs text-red-600 mt-1">{item.comentario}</p>
                                  )}
                                </div>
                              </div>
                            )
                          })}
                        </div>
                      </div>
                    )}
                  </div>
                )
              })()}

              {/* Table — always visible below detail or as standalone */}
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50">
                    <th className="px-5 py-3 text-left font-semibold text-gray-600">Data do registro</th>
                    <th className="px-5 py-3 text-left font-semibold text-gray-600">Dia da semana</th>
                    <th className="px-5 py-3 text-left font-semibold text-gray-600">Nome porteiro</th>
                    <th className="w-10"></th>
                  </tr>
                </thead>
                <tbody>
                  {registros.map(r => {
                    const { data, dia } = formatDate(r.created_at)
                    const isExpanded = expandedId === r.id
                    const hasDivergencia = divergenciaIds.has(r.id)
                    return (
                      <tr
                        key={r.id}
                        onClick={() => toggleDetail(r.id)}
                        className={`border-b cursor-pointer transition-colors ${
                          isExpanded
                            ? 'bg-[#FC5931]/10 border-l-4 border-l-[#FC5931] border-b-[#FC5931]/20'
                            : hasDivergencia
                              ? 'bg-red-50 border-b-red-100 hover:bg-red-100/60'
                              : 'border-b-gray-50 hover:bg-gray-50'
                        }`}
                      >
                        <td className={`px-5 py-3 ${hasDivergencia ? 'text-red-700 font-medium' : 'text-gray-700'}`}>{data}</td>
                        <td className={`px-5 py-3 ${hasDivergencia ? 'text-red-700' : 'text-gray-700'}`}>{dia}</td>
                        <td className={`px-5 py-3 font-medium ${hasDivergencia ? 'text-red-800' : 'text-gray-800'}`}>{r.porteiro_nome}</td>
                        <td className="px-3 py-3">
                          {isExpanded
                            ? <ChevronUp size={16} className="text-[#FC5931]" />
                            : <ChevronDown size={16} className="text-gray-400" />
                          }
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
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
                    setSelectedPorteiro(e.target.value)
                    const p = porteiros.find(pt => pt.id === e.target.value)
                    setPorteiroNome(p?.nome_completo ?? '')
                  }}
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                  title="Selecione o porteiro"
                >
                  <option value="">Selecione...</option>
                  {porteiros.map(p => (
                    <option key={p.id} value={p.id}>{p.nome_completo}</option>
                  ))}
                </select>
              </div>
              <div className="flex-1">
                <label className="text-xs font-medium text-gray-500 mb-1 block">Seu nome</label>
                <input
                  value={porteiroNome}
                  readOnly
                  className="w-full border border-gray-100 bg-gray-50 rounded-xl px-4 py-2.5 text-sm text-gray-600"
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
