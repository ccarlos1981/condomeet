'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Target, TrendingUp, TrendingDown, AlertCircle, Calendar, Edit, X, HelpCircle, ArrowLeft, ArrowRight } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

type PrevisaoOrcamentariaClientProps = {
  condoId: string
  selectedYear: number
  planoContas: any[]
  orcamentos: any[]
  lancamentosAtual: any[]
  lancamentosAnterior: any[]
}

const MESES_NOMES = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
]

export default function PrevisaoOrcamentariaClient({
  condoId,
  selectedYear,
  planoContas,
  orcamentos,
  lancamentosAtual,
  lancamentosAnterior
}: PrevisaoOrcamentariaClientProps) {
  const router = useRouter()
  const supabase = createClient()
  
  const [loading, setLoading] = useState(false)
  const [showConfig, setShowConfig] = useState(false)
  const [selectedPlanoContaId, setSelectedPlanoContaId] = useState('')
  const [mesesMetas, setMesesMetas] = useState<Record<number, number>>({
    1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0, 12: 0
  })
  const [valorUnicoReplica, setValorUnicoReplica] = useState('')

  // 1. Formatar moeda
  const formatCurrency = (val: number) => {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
  }

  // 2. Cálculos Globais
  const totalPrevisto = orcamentos.reduce((sum, o) => sum + Number(o.valor_previsto || 0), 0)
  const totalRealizado = lancamentosAtual.reduce((sum, l) => sum + Number(l.valor || 0), 0)
  const saldoRestante = totalPrevisto - totalRealizado
  const percentualGlobal = totalPrevisto > 0 ? Math.round((totalRealizado / totalPrevisto) * 100) : 0

  // 3. Abrir modal para categoria específica
  const handleOpenConfig = (planoContaId: string) => {
    setSelectedPlanoContaId(planoContaId)
    const metas: Record<number, number> = {}
    for (let m = 1; m <= 12; m++) {
      const match = orcamentos.find(o => o.plano_conta_id === planoContaId && o.mes === m)
      metas[m] = match ? Number(match.valor_previsto || 0) : 0
    }
    setMesesMetas(metas)
    setValorUnicoReplica('')
    setShowConfig(true)
  }

  // 4. Atalho: Replicar valor único para todos os meses
  const handleReplicarValorUnico = () => {
    const val = Number(valorUnicoReplica) || 0
    const updated: Record<number, number> = {}
    for (let m = 1; m <= 12; m++) {
      updated[m] = val
    }
    setMesesMetas(updated)
  }

  // 5. Atalho: Replicar média do ano anterior
  const handleReplicarMediaAnterior = () => {
    const realizadoAnterior = lancamentosAnterior
      .filter(l => l.plano_conta_id === selectedPlanoContaId)
      .reduce((sum, l) => sum + Number(l.valor || 0), 0)
    const media = Math.round((realizadoAnterior / 12) * 100) / 100
    
    const updated: Record<number, number> = {}
    for (let m = 1; m <= 12; m++) {
      updated[m] = media
    }
    setMesesMetas(updated)
  }

  // 6. Gravar orçamentos no Supabase
  const handleSaveOrcamentos = async () => {
    if (!selectedPlanoContaId) return
    setLoading(true)
    try {
      const payload = Object.entries(mesesMetas).map(([mes, valor]) => ({
        condominio_id: condoId,
        ano: selectedYear,
        mes: Number(mes),
        plano_conta_id: selectedPlanoContaId,
        valor_previsto: Number(valor) || 0
      }))

      const { error } = await supabase
        .from('condominio_orcamentos')
        .upsert(payload, { onConflict: 'condominio_id,ano,mes,plano_conta_id' })

      if (error) throw error

      setShowConfig(false)
      router.refresh()
    } catch (err) {
      console.error('Erro ao salvar orçamento:', err)
      alert('Ocorreu um erro ao salvar as metas.')
    } finally {
      setLoading(false)
    }
  }

  const getMediaMensalPrevista = (planoContaId: string) => {
    const orcadoAnual = orcamentos
      .filter(o => o.plano_conta_id === planoContaId)
      .reduce((sum, o) => sum + Number(o.valor_previsto || 0), 0)
    return orcadoAnual / 12
  }

  return (
    <div className="p-6 max-w-6xl mx-auto space-y-8">
      {/* HEADER */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Previsão Orçamentária</h1>
          <p className="text-gray-500 mt-1">Acompanhe as metas financeiras e o orçamento mensal/anual do condomínio.</p>
        </div>
        <div className="flex gap-3 items-center">
          <div className="flex items-center gap-2 bg-white border border-gray-200 px-3 py-2 rounded-xl text-sm font-medium shadow-sm">
            <Calendar size={16} className="text-gray-500"/>
            <select 
              value={selectedYear}
              onChange={(e) => router.push(`/admin/previsao-orcamentaria?year=${e.target.value}`)}
              className="bg-transparent border-none outline-none text-gray-700 cursor-pointer font-semibold"
            >
              <option value="2025">2025</option>
              <option value="2026">2026</option>
              <option value="2027">2027</option>
            </select>
          </div>
          <button 
            onClick={() => handleOpenConfig(planoContas[0]?.id || '')}
            disabled={planoContas.length === 0}
            className="px-4 py-2 bg-[#FC5931] hover:bg-[#D42F1D] text-white rounded-xl font-bold transition-all shadow-md hover:shadow-lg flex items-center gap-2 disabled:opacity-50"
          >
            <Target size={18} />
            Ajustar Orçamento
          </button>
        </div>
      </div>

      {/* DASHBOARD SUMMARY CARDS */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 relative overflow-hidden group hover:shadow-md transition-shadow">
          <h3 className="text-sm font-semibold text-gray-500 mb-1">Orçamento Previsto (Anual)</h3>
          <p className="text-3xl font-black text-gray-900">{formatCurrency(totalPrevisto)}</p>
          <div className="mt-4 flex items-center gap-2">
            <div className="w-full bg-gray-100 rounded-full h-2">
              <div className="bg-blue-500 h-2 rounded-full transition-all duration-500" style={{ width: '100%' }}></div>
            </div>
          </div>
        </div>
        
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 relative overflow-hidden group hover:shadow-md transition-shadow">
          <h3 className="text-sm font-semibold text-gray-500 mb-1">Despesas Realizadas (YTD)</h3>
          <p className="text-3xl font-black text-gray-900">{formatCurrency(totalRealizado)}</p>
          <div className="mt-4 flex items-center gap-2">
            <div className="w-full bg-gray-100 rounded-full h-2">
              <div 
                className={`h-2 rounded-full transition-all duration-500 ${percentualGlobal > 100 ? 'bg-red-500' : 'bg-[#FC5931]'}`} 
                style={{ width: `${Math.min(percentualGlobal, 100)}%` }}
              ></div>
            </div>
            <span className="font-bold text-sm text-gray-600 shrink-0">{percentualGlobal}%</span>
          </div>
        </div>

        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 relative overflow-hidden group hover:shadow-md transition-shadow">
          <h3 className="text-sm font-semibold text-gray-500 mb-1">Saldo Orçamentário Restante</h3>
          <p className={`text-3xl font-black ${saldoRestante < 0 ? 'text-red-500' : 'text-green-600'}`}>
            {formatCurrency(saldoRestante)}
          </p>
          <div className="mt-4 flex items-center gap-2">
            {saldoRestante < 0 ? (
              <div className="flex items-center gap-1.5 text-xs text-red-600 bg-red-50 px-3 py-1.5 rounded-lg font-bold">
                <TrendingDown size={14} /> Limite Excedido
              </div>
            ) : (
              <div className="flex items-center gap-1.5 text-xs text-green-700 bg-green-50 px-3 py-1.5 rounded-lg font-bold">
                <TrendingUp size={14} /> Dentro do planejado
              </div>
            )}
          </div>
        </div>
      </div>

      {/* PLANO DE CONTAS MATRIX */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="p-6 border-b border-gray-50 flex justify-between items-center bg-gray-50/50">
          <h2 className="text-lg font-bold text-gray-800">Acompanhamento por Categoria</h2>
          <span className="text-xs font-semibold px-2.5 py-1 bg-gray-100 text-gray-600 rounded-full">
            {planoContas.length} categorias
          </span>
        </div>
        
        <div className="overflow-x-auto">
          {planoContas.length === 0 ? (
            <div className="text-center py-16 text-gray-400">
              <AlertCircle size={40} className="mx-auto mb-3 text-gray-200" />
              Nenhuma categoria de despesa ativa no plano de contas.
            </div>
          ) : (
            <table className="w-full text-left border-collapse text-sm">
              <thead>
                <tr className="border-b border-gray-100 text-gray-500 font-semibold bg-gray-50/30">
                  <th className="p-4 font-medium">Código</th>
                  <th className="p-4 font-medium">Categoria</th>
                  <th className="p-4 font-medium text-right">Realizado {selectedYear - 1}</th>
                  <th className="p-4 font-medium text-right bg-blue-50/20">Média Mensal {selectedYear - 1}</th>
                  <th className="p-4 font-medium text-right bg-orange-50/20 text-[#FC5931]">Orçado Mensal (Média)</th>
                  <th className="p-4 font-medium text-right">Realizado {selectedYear}</th>
                  <th className="p-4 font-medium text-center">Status</th>
                  <th className="p-4 font-medium text-center">Ações</th>
                </tr>
              </thead>
              <tbody>
                {planoContas.map(pc => {
                  const realizadoAnt = lancamentosAnterior
                    .filter(l => l.plano_conta_id === pc.id)
                    .reduce((sum, l) => sum + Number(l.valor || 0), 0)
                  const mediaAnt = realizadoAnt / 12
                  
                  const orcadoAnu = orcamentos
                    .filter(o => o.plano_conta_id === pc.id)
                    .reduce((sum, o) => sum + Number(o.valor_previsto || 0), 0)
                  const orcadoMensalMed = orcadoAnu / 12

                  const realizadoAtu = lancamentosAtual
                    .filter(l => l.plano_conta_id === pc.id)
                    .reduce((sum, l) => sum + Number(l.valor || 0), 0)

                  const pct = orcadoAnu > 0 ? Math.round((realizadoAtu / orcadoAnu) * 100) : 0
                  const isEstourado = orcadoAnu > 0 && realizadoAtu > orcadoAnu

                  return (
                    <tr key={pc.id} className="border-b border-gray-50 last:border-0 hover:bg-gray-50/30 transition-colors">
                      <td className="p-4 text-gray-500 font-mono font-semibold">{pc.codigo}</td>
                      <td className="p-4 font-bold text-gray-900">{pc.nome}</td>
                      <td className="p-4 text-right text-gray-600">{formatCurrency(realizadoAnt)}</td>
                      <td className="p-4 text-right text-gray-600 bg-blue-50/10">{formatCurrency(mediaAnt)}</td>
                      <td className="p-4 text-right font-bold text-[#FC5931] bg-orange-50/10">{formatCurrency(orcadoMensalMed)}</td>
                      <td className="p-4 text-right font-medium text-gray-900">{formatCurrency(realizadoAtu)}</td>
                      <td className="p-4 text-center">
                        {orcadoAnu === 0 ? (
                          <span className="px-2 py-0.5 bg-gray-100 text-gray-500 rounded text-xs font-semibold">Não orçado</span>
                        ) : isEstourado ? (
                          <span className="px-2.5 py-1 bg-red-100 text-red-700 rounded-full text-xs font-bold inline-flex items-center gap-1">
                            <AlertCircle size={12} /> Estourou ({pct}%)
                          </span>
                        ) : (
                          <span className="px-2.5 py-1 bg-green-100 text-green-800 rounded-full text-xs font-bold">
                            ✓ {pct}%
                          </span>
                        )}
                      </td>
                      <td className="p-4 text-center">
                        <button
                          onClick={() => handleOpenConfig(pc.id)}
                          className="p-2 text-gray-400 hover:text-[#FC5931] rounded-lg transition-colors inline-flex"
                          title="Ajustar metas mensais"
                        >
                          <Edit size={16} />
                        </button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* MODAL CONFIGURAR METAS DA CATEGORIA */}
      {showConfig && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl overflow-hidden animate-in zoom-in-95 duration-200">
            {/* Header */}
            <div className="flex items-center justify-between p-5 border-b border-gray-100 bg-gray-50/50">
              <div>
                <h3 className="font-bold text-lg text-gray-900">Planejamento Orçamentário ({selectedYear})</h3>
                <p className="text-xs text-gray-500 mt-0.5">
                  Categoria: <span className="font-bold text-gray-700">{planoContas.find(pc => pc.id === selectedPlanoContaId)?.nome}</span>
                </p>
              </div>
              <button 
                onClick={() => setShowConfig(false)}
                className="text-gray-400 hover:bg-gray-100 p-2 rounded-lg transition-colors"
              >
                <X size={20} />
              </button>
            </div>

            {/* Content */}
            <div className="p-6 space-y-6 max-h-[70vh] overflow-y-auto">
              
              {/* Dropdown de troca rápida de categoria */}
              <div className="flex flex-col md:flex-row gap-4 items-end bg-gray-50 p-4 rounded-xl border border-gray-100">
                <div className="flex-1 w-full">
                  <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-1">Trocar Categoria</label>
                  <select 
                    value={selectedPlanoContaId}
                    onChange={(e) => handleOpenConfig(e.target.value)}
                    className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 font-semibold text-gray-700"
                  >
                    {planoContas.map(pc => (
                      <option key={pc.id} value={pc.id}>{pc.codigo} - {pc.nome}</option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Atalhos rápidos de preenchimento */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="border border-dashed border-gray-200 p-4 rounded-xl flex items-center justify-between gap-4">
                  <div className="flex-1">
                    <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-1">Valor Fixo</label>
                    <input 
                      type="number" 
                      placeholder="R$ 0,00" 
                      value={valorUnicoReplica}
                      onChange={e => setValorUnicoReplica(e.target.value)}
                      className="w-full border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20"
                    />
                  </div>
                  <button 
                    onClick={handleReplicarValorUnico}
                    className="px-4 py-2 bg-gray-900 hover:bg-gray-800 text-white rounded-lg text-xs font-bold transition-all shadow-sm shrink-0"
                  >
                    Replicar nos 12 meses
                  </button>
                </div>

                <div className="border border-dashed border-gray-200 p-4 rounded-xl flex items-center justify-between gap-4 bg-blue-50/20">
                  <div>
                    <h4 className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-1">Copiar Ano Anterior</h4>
                    <p className="text-[11px] text-gray-500 leading-tight">Calcula a média mensal real de {selectedYear - 1} e preenche todas as parcelas.</p>
                  </div>
                  <button 
                    onClick={handleReplicarMediaAnterior}
                    className="px-4 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-xs font-bold transition-all shadow-sm shrink-0"
                  >
                    Replicar Média
                  </button>
                </div>
              </div>

              {/* Grid 12 Meses */}
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
                {MESES_NOMES.map((nome, index) => {
                  const numMes = index + 1
                  return (
                    <div key={numMes} className="border border-gray-100 p-3 rounded-xl bg-white shadow-sm flex flex-col gap-1.5">
                      <label className="text-xs font-bold text-gray-500">{nome}</label>
                      <input 
                        type="number"
                        value={mesesMetas[numMes] || 0}
                        onChange={e => setMesesMetas({ ...mesesMetas, [numMes]: Number(e.target.value) || 0 })}
                        className="w-full border border-gray-200 rounded-lg px-2.5 py-1.5 text-sm font-semibold text-gray-800 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                      />
                    </div>
                  )
                })}
              </div>

              {/* Totalizador Anual */}
              <div className="bg-gray-50 p-4 rounded-xl flex justify-between items-center border border-gray-100">
                <div>
                  <span className="font-semibold text-gray-700 text-sm block">Total Previsto (Anual)</span>
                  <span className="text-[11px] text-gray-400">Calculado a partir das 12 parcelas mensais</span>
                </div>
                <span className="font-black text-gray-900 text-xl">
                  {formatCurrency(
                    Object.values(mesesMetas).reduce((sum, v) => sum + Number(v || 0), 0)
                  )}
                </span>
              </div>
            </div>

            {/* Footer buttons */}
            <div className="p-5 border-t border-gray-100 bg-gray-50/50 flex justify-end gap-3">
              <button 
                onClick={() => setShowConfig(false)}
                className="px-4 py-2 font-medium text-gray-600 hover:bg-gray-200 rounded-xl transition-colors text-sm"
              >
                Cancelar
              </button>
              <button 
                onClick={handleSaveOrcamentos}
                disabled={loading}
                className="px-6 py-2 font-bold bg-[#FC5931] hover:bg-[#D42F1D] text-white rounded-xl shadow-md hover:shadow-lg transition-all text-sm disabled:opacity-50"
              >
                {loading ? 'Gravando...' : 'Confirmar Orçamento'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
