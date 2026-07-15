'use client'

import { useEffect, useState } from 'react'
import { getDashboardMetrics, getConsumptionByCondo, getSuperUserInfo } from '../actions'
import { 
  BarChart3, DollarSign, MessageSquare, CheckCircle, 
  TrendingUp, TrendingDown, Clock, ShieldAlert, Sparkles, Download
} from 'lucide-react'
import { useRouter } from 'next/navigation'

export default function DashboardPage() {
  const router = useRouter()
  const [loading, setLoading] = useState(true)
  const [authorized, setAuthorized] = useState(false)
  const [data, setData] = useState<any>(null)

  const [showCondoConsumption, setShowCondoConsumption] = useState(false)
  const [condoConsumption, setCondoConsumption] = useState<any[]>([])
  const [loadingConsumption, setLoadingConsumption] = useState(false)

  useEffect(() => {
    async function init() {
      try {
        // Query the centralized server action
        const auth = await getSuperUserInfo()
        if (!auth.authorized) {
          router.push('/admin')
          return
        }

        setAuthorized(true)

        // Load global consolidated metrics
        const metrics = await getDashboardMetrics()
        setData(metrics)
      } catch (err) {
        console.error(err)
        router.push('/admin')
      } finally {
        setLoading(false)
      }
    }
    init()
  }, [router])

  const handleToggleConsumption = async () => {
    if (!showCondoConsumption) {
      setShowCondoConsumption(true)
      if (condoConsumption.length === 0) {
        setLoadingConsumption(true)
        try {
          const res = await getConsumptionByCondo()
          setCondoConsumption(res)
        } catch (err) {
          console.error('Error loading consumption:', err)
        } finally {
          setLoadingConsumption(false)
        }
      }
    } else {
      setShowCondoConsumption(false)
    }
  }

  const handleExportCSV = () => {
    if (condoConsumption.length === 0) return

    const headers = [
      'Condominio',
      'Mensagens Enviadas',
      'Conversas Pagas',
      'Mensagens Gratuitas',
      'Gasto Hoje',
      'Gasto 7 Dias',
      'Gasto 30 Dias',
      'Participacao Percentual',
      'Unidades',
      'Custo por Unidade'
    ]

    const rows = condoConsumption.map(c => [
      c.condominio_nome,
      c.mensagens_enviadas,
      c.conversas_pagas,
      c.conversas_gratuitas,
      `R$ ${Number(c.gasto_hoje).toFixed(2)}`,
      `R$ ${Number(c.gasto_7d).toFixed(2)}`,
      `R$ ${Number(c.gasto_30d).toFixed(2)}`,
      `${Number(c.participacao_percentual).toFixed(2)}%`,
      c.total_unidades,
      `R$ ${Number(c.custo_por_unidade).toFixed(2)}`
    ])

    const csvContent = [
      headers.join(';'),
      ...rows.map(r => r.map(val => `"${String(val).replace(/"/g, '""')}"`).join(';'))
    ].join('\n')

    const blob = new Blob([new Uint8Array([0xEF, 0xBB, 0xBF]), csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.setAttribute('href', url)
    link.setAttribute('download', `consumo_whatsapp_condominios_${new Date().toISOString().split('T')[0]}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  const getGrowthIndicator = (gastoHoje: number, gasto30d: number) => {
    const dailyAvg = gasto30d / 30
    const growth = dailyAvg > 0 ? ((gastoHoje - dailyAvg) / dailyAvg) * 100 : 0

    let badgeColor = 'text-emerald-700 bg-emerald-50 border border-emerald-200'
    let indicator = 'Normal'
    let trendSign = growth > 0 ? '↑ ' : ''
    let percentageText = `${trendSign}${growth.toFixed(0)}%`

    if (growth > 100) {
      badgeColor = 'text-red-700 bg-red-50 border border-red-200 animate-pulse'
      indicator = 'Crítico'
    } else if (growth > 50) {
      badgeColor = 'text-amber-700 bg-amber-50 border border-amber-200'
      indicator = 'Atenção'
    }

    return (
      <div className="flex items-center gap-2">
        <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-bold ${badgeColor}`}>
          <span>{percentageText}</span>
        </span>
        <span className="text-[11px] text-gray-500 font-semibold">{indicator}</span>
      </div>
    )
  }

  const getThresholdHighlight = (gasto30d: number) => {
    if (gasto30d > 200) {
      return {
        borderClass: 'border-red-500 ring-1 ring-red-500 shadow-md',
        badge: (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-red-600 text-white animate-bounce">
            🚨 &gt; R$ 200/mês
          </span>
        )
      }
    }
    if (gasto30d > 100) {
      return {
        borderClass: 'border-red-300 shadow-sm',
        badge: (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-red-100 text-red-700 border border-red-200">
            🔴 &gt; R$ 100/mês
          </span>
        )
      }
    }
    if (gasto30d > 50) {
      return {
        borderClass: 'border-amber-300 shadow-sm',
        badge: (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-700 border border-amber-200">
            🟠 &gt; R$ 50/mês
          </span>
        )
      }
    }
    return {
      borderClass: 'border-gray-100',
      badge: null
    }
  }

  if (loading) {
    return (
      <div className="flex h-[60vh] items-center justify-center">
        <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-[#FC5931]"></div>
      </div>
    )
  }

  if (!authorized || !data) return null

  const { costs, metricsView, templateUsage } = data

  const deliveryRate = Number(metricsView.meta_sent_count) > 0 
    ? (Number(metricsView.meta_delivered_count) / Number(metricsView.meta_sent_count)) * 100 
    : 0

  const readRate = Number(metricsView.meta_sent_count) > 0 
    ? (Number(metricsView.meta_read_count) / Number(metricsView.meta_sent_count)) * 100 
    : 0

  return (
    <div className="space-y-8 max-w-7xl mx-auto pb-10">
      
      {/* Header */}
      <div className="flex justify-between items-center border-b border-gray-200 pb-5">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">API Oficial — Dashboard</h1>
          <p className="text-sm text-gray-500 mt-1">Estatísticas de faturamento e volumetria técnica do WhatsApp Cloud API</p>
        </div>
      </div>

      {/* Cards Financeiros Superiores */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        
        {/* Gasto Hoje */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex flex-col justify-between">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Gasto Hoje</p>
              <h3 className="text-3xl font-extrabold text-gray-900 mt-2">R$ {costs.today.value.toFixed(2)}</h3>
            </div>
            <div className="bg-orange-50 p-2.5 rounded-xl text-[#FC5931]">
              <DollarSign size={20} />
            </div>
          </div>
          <div className="flex items-center gap-2 mt-4 pt-3 border-t border-gray-50 text-xs text-gray-500">
            <span className="font-semibold text-gray-700">{costs.today.count}</span> mensagens enviadas
            <span className={`ml-auto flex items-center gap-0.5 font-bold ${costs.today.growth >= 0 ? 'text-red-500' : 'text-green-500'}`}>
              {costs.today.growth >= 0 ? <TrendingUp size={14} /> : <TrendingDown size={14} />}
              {Math.abs(costs.today.growth).toFixed(1)}%
            </span>
          </div>
        </div>

        {/* Gasto Semana */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex flex-col justify-between">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Gasto Semana (7d)</p>
              <h3 className="text-3xl font-extrabold text-gray-900 mt-2">R$ {costs.week.value.toFixed(2)}</h3>
            </div>
            <div className="bg-orange-50 p-2.5 rounded-xl text-[#FC5931]">
              <DollarSign size={20} />
            </div>
          </div>
          <div className="flex items-center gap-2 mt-4 pt-3 border-t border-gray-50 text-xs text-gray-500">
            <span className="font-semibold text-gray-700">{costs.week.count}</span> mensagens enviadas
            <span className={`ml-auto flex items-center gap-0.5 font-bold ${costs.week.growth >= 0 ? 'text-red-500' : 'text-green-500'}`}>
              {costs.week.growth >= 0 ? <TrendingUp size={14} /> : <TrendingDown size={14} />}
              {Math.abs(costs.week.growth).toFixed(1)}%
            </span>
          </div>
        </div>

        {/* Gasto Mês */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex flex-col justify-between">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Gasto Mês (30d)</p>
              <h3 className="text-3xl font-extrabold text-gray-900 mt-2">R$ {costs.month.value.toFixed(2)}</h3>
            </div>
            <div className="bg-orange-50 p-2.5 rounded-xl text-[#FC5931]">
              <DollarSign size={20} />
            </div>
          </div>
          <div className="flex items-center gap-2 mt-4 pt-3 border-t border-gray-50 text-xs text-gray-500">
            <span className="font-semibold text-gray-700">{costs.month.count}</span> mensagens enviadas
            <span className={`ml-auto flex items-center gap-0.5 font-bold ${costs.month.growth >= 0 ? 'text-red-500' : 'text-green-500'}`}>
              {costs.month.growth >= 0 ? <TrendingUp size={14} /> : <TrendingDown size={14} />}
              {Math.abs(costs.month.growth).toFixed(1)}%
            </span>
          </div>
        </div>

      </div>

      {/* Cards de Métricas Adicionais Aprovadas */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        
        {/* Card: Conversas Abertas Hoje */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex items-center gap-5">
          <div className="bg-emerald-50 p-4 rounded-2xl text-emerald-600 flex-shrink-0">
            <MessageSquare size={28} />
          </div>
          <div>
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Conversas Abertas Hoje</p>
            <h3 className="text-2xl font-black text-gray-800 mt-1">{metricsView.active_conversations_today}</h3>
            <p className="text-xs text-gray-500 mt-1">Interações ativas de moradores nas últimas 24 horas</p>
          </div>
        </div>

        {/* Card: Economia Janela 24h */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex items-center gap-5">
          <div className="bg-blue-50 p-4 rounded-2xl text-blue-600 flex-shrink-0">
            <Sparkles size={28} />
          </div>
          <div>
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Economia pela Janela 24h</p>
            <h3 className="text-2xl font-black text-emerald-600 mt-1">R$ {Number(metricsView.meta_savings_brl).toFixed(2)}</h3>
            <p className="text-xs text-gray-500 mt-1">
              Economia gerada por <span className="font-bold">{metricsView.meta_free_window_count}</span> mensagens gratuitas de texto livre
            </p>
          </div>
        </div>

      </div>

      {/* Seção de Controle do Toggle de Consumo por Condomínio */}
      <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h3 className="text-base font-bold text-gray-800">Visualização de Consumo por Condomínio</h3>
          <p className="text-xs text-gray-500 mt-1">Gere relatórios, veja custos médios de unidades e identifique anomalias operacionais.</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={handleToggleConsumption}
            className="flex items-center gap-2 px-5 py-2.5 text-xs font-bold text-white bg-[#FC5931] hover:bg-[#e24e29] active:scale-[0.98] rounded-xl shadow-xs transition-all flex-shrink-0"
          >
            <BarChart3 size={15} />
            {showCondoConsumption ? 'Ocultar consumo por condomínio' : 'Mostrar consumo por condomínio'}
          </button>

          {showCondoConsumption && condoConsumption.length > 0 && (
            <button
              onClick={handleExportCSV}
              className="flex items-center gap-2 px-5 py-2.5 text-xs font-bold text-gray-700 bg-white hover:bg-gray-50 border border-gray-200 rounded-xl shadow-xs transition-all flex-shrink-0"
            >
              <Download size={15} />
              Exportar CSV
            </button>
          )}
        </div>
      </div>

      {/* Seção Collapsible Expandida */}
      {showCondoConsumption && (
        <div className="space-y-6 animate-fadeIn">
          
          {/* Top 5 Condomínios (Visão Global MASTER) */}
          {condoConsumption.length > 0 && (
            <div className="bg-gradient-to-r from-amber-50 to-orange-50 rounded-2xl p-5 border border-amber-100">
              <div className="flex items-center gap-2 mb-3">
                <span className="text-xl">🏆</span>
                <h3 className="text-sm font-bold text-amber-900 uppercase tracking-wider">Top 5 Condomínios com Maior Consumo (Últimos 30 Dias)</h3>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-5 gap-4">
                {condoConsumption.slice(0, 5).map((c, idx) => (
                  <div key={c.condominio_id} className="bg-white/80 backdrop-blur-xs rounded-xl p-3 shadow-xs border border-amber-100 flex flex-col justify-between">
                    <div>
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs font-bold text-amber-700 bg-amber-100 w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0">
                          {idx + 1}
                        </span>
                        <p className="text-xs font-bold text-gray-800 truncate" title={c.condominio_nome}>
                          {c.condominio_nome}
                        </p>
                      </div>
                      <p className="text-lg font-black text-gray-900 mt-2">R$ {Number(c.gasto_30d).toFixed(2)}</p>
                    </div>
                    <p className="text-[10px] text-gray-500 font-semibold mt-1">
                      Participação: <span className="text-[#FC5931]">{Number(c.participacao_percentual).toFixed(1)}%</span>
                    </p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Grid de Cards de Consumo */}
          {loadingConsumption ? (
            <div className="flex h-24 items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#FC5931]"></div>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {condoConsumption.map(c => {
                const threshold = getThresholdHighlight(Number(c.gasto_30d));
                return (
                  <div
                    key={c.condominio_id}
                    className={`bg-white rounded-2xl p-6 shadow-sm border flex flex-col justify-between transition-all hover:shadow-md ${threshold.borderClass}`}
                  >
                    <div>
                      {/* Top Header Card */}
                      <div className="flex justify-between items-start gap-2 mb-4">
                        <div>
                          <h4 className="text-base font-bold text-gray-900">{c.condominio_nome}</h4>
                        </div>
                        {threshold.badge && <div className="flex-shrink-0">{threshold.badge}</div>}
                      </div>

                      {/* Gasto Hoje / 7D / 30D Grid */}
                      <div className="grid grid-cols-3 gap-2 mb-4 pb-4 border-b border-gray-50 text-xs">
                        <div>
                          <p className="font-semibold text-gray-400 uppercase tracking-wider text-[9px]">Gasto Hoje</p>
                          <p className="text-sm font-bold text-gray-800 mt-1">R$ {Number(c.gasto_hoje).toFixed(2)}</p>
                        </div>
                        <div>
                          <p className="font-semibold text-gray-400 uppercase tracking-wider text-[9px]">Últimos 7d</p>
                          <p className="text-sm font-bold text-gray-800 mt-1">R$ {Number(c.gasto_7d).toFixed(2)}</p>
                        </div>
                        <div>
                          <p className="font-semibold text-gray-400 uppercase tracking-wider text-[9px]">Últimos 30d</p>
                          <p className="text-sm font-bold text-[#FC5931] mt-1">R$ {Number(c.gasto_30d).toFixed(2)}</p>
                        </div>
                      </div>

                      {/* Volumetria de Mensagens */}
                      <div className="space-y-2 mb-4 pb-4 border-b border-gray-50 text-xs text-gray-500">
                        <div className="flex justify-between">
                          <span>Mensagens enviadas:</span>
                          <span className="font-bold text-gray-800">{c.mensagens_enviadas}</span>
                        </div>
                        <div className="flex justify-between">
                          <span>Conversas pagas:</span>
                          <span className="font-semibold text-gray-700">{c.conversas_pagas}</span>
                        </div>
                        <div className="flex justify-between">
                          <span>Mensagens gratuitas (24h):</span>
                          <span className="font-semibold text-gray-700">{c.conversas_gratuitas}</span>
                        </div>
                      </div>

                      {/* Custo unitário e participação */}
                      <div className="space-y-2 text-xs text-gray-500">
                        <div className="flex justify-between items-center">
                          <span>Participação custo total:</span>
                          <span className="font-bold text-gray-800 bg-gray-100 px-2 py-0.5 rounded">{Number(c.participacao_percentual).toFixed(1)}%</span>
                        </div>
                        <div className="flex justify-between">
                          <span>Total de unidades:</span>
                          <span className="font-semibold text-gray-700">{c.total_unidades}</span>
                        </div>
                        <div className="flex justify-between">
                          <span>Custo médio por unidade:</span>
                          <span className="font-bold text-emerald-600">R$ {Number(c.custo_por_unidade).toFixed(2)}</span>
                        </div>
                      </div>
                    </div>

                    {/* Alerta de Anomalia de Consumo (Growth) */}
                    <div className="flex justify-between items-center pt-3 mt-4 border-t border-dashed border-gray-100">
                      <span className="text-[11px] font-semibold text-gray-400 uppercase tracking-wider">Status de Uso</span>
                      {getGrowthIndicator(Number(c.gasto_hoje), Number(c.gasto_30d))}
                    </div>

                  </div>
                )
              })}
              {condoConsumption.length === 0 && (
                <div className="col-span-full text-center py-10 text-xs text-gray-400 bg-white rounded-2xl border border-gray-100">
                  Nenhum dado de consumo disponível.
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* Cards Técnicos Operacionais */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
        
        <div className="bg-white rounded-2xl p-5 shadow-sm border border-gray-100">
          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-wider">Meta Delivery Rate</p>
          <div className="text-2xl font-extrabold text-gray-800 mt-2">{deliveryRate.toFixed(1)}%</div>
          <p className="text-[10px] text-gray-500 mt-1">Entregas confirmadas</p>
        </div>

        <div className="bg-white rounded-2xl p-5 shadow-sm border border-gray-100">
          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-wider">Meta Read Rate</p>
          <div className="text-2xl font-extrabold text-gray-800 mt-2">{readRate.toFixed(1)}%</div>
          <p className="text-[10px] text-gray-500 mt-1">Leituras confirmadas</p>
        </div>

        <div className="bg-white rounded-2xl p-5 shadow-sm border border-gray-100">
          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-wider">Failovers Ativados</p>
          <div className="text-2xl font-extrabold text-red-500 mt-2">{metricsView.botconversa_sent_count}</div>
          <p className="text-[10px] text-gray-500 mt-1">Envios via BotConversa</p>
        </div>

        <div className="bg-white rounded-2xl p-5 shadow-sm border border-gray-100">
          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-wider">Latência Média</p>
          <div className="text-2xl font-extrabold text-gray-800 mt-2">{Number(metricsView.meta_avg_latency_sec).toFixed(1)}s</div>
          <p className="text-[10px] text-gray-500 mt-1">Tempo de envio Meta</p>
        </div>

      </div>

      {/* Gráficos / Distribuições Operacionais */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {/* Utilização de Templates */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 space-y-5">
          <h4 className="text-sm font-bold text-gray-800">Frequência de Uso de Templates</h4>
          <div className="space-y-4 max-h-[300px] overflow-y-auto pr-2">
            {templateUsage.map((t: any) => {
              const total = Number(metricsView.meta_sent_count) || 1
              const pct = (t.usage_count / total) * 100
              return (
                <div key={t.template_name} className="space-y-1">
                  <div className="flex justify-between text-xs font-semibold">
                    <span className="font-mono text-gray-600">{t.template_name}</span>
                    <span className="text-gray-700">{t.usage_count} envios ({pct.toFixed(1)}%)</span>
                  </div>
                  <div className="w-full bg-gray-100 h-2 rounded-full overflow-hidden">
                    <div className="bg-[#FC5931] h-full rounded-full" style={{ width: `${pct}%` }}></div>
                  </div>
                </div>
              )
            })}
            {templateUsage.length === 0 && (
              <div className="text-center py-10 text-xs text-gray-400">Nenhum template disparado até o momento.</div>
            )}
          </div>
        </div>

        {/* Distribuição Operacional */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 space-y-6">
          <h4 className="text-sm font-bold text-gray-800">Distribuição Operacional dos Disparos</h4>
          <div className="space-y-4">
            
            {/* Texto livre */}
            <div className="space-y-1">
              <div className="flex justify-between text-xs font-semibold">
                <span className="text-gray-600">Mensagens em Texto Livre (Janela 24h)</span>
                <span className="text-gray-800">{metricsView.meta_free_window_count}</span>
              </div>
              <div className="w-full bg-gray-100 h-3 rounded-full overflow-hidden">
                <div className="bg-emerald-500 h-full rounded-full" style={{ width: `${Number(metricsView.meta_sent_count) > 0 ? (Number(metricsView.meta_free_window_count) / Number(metricsView.meta_sent_count)) * 100 : 0}%` }}></div>
              </div>
            </div>

            {/* Templates Utility */}
            <div className="space-y-1">
              <div className="flex justify-between text-xs font-semibold">
                <span className="text-gray-600">Templates Utility</span>
                <span className="text-gray-800">{metricsView.meta_template_count}</span>
              </div>
              <div className="w-full bg-gray-100 h-3 rounded-full overflow-hidden">
                <div className="bg-blue-500 h-full rounded-full" style={{ width: `${Number(metricsView.meta_sent_count) > 0 ? (Number(metricsView.meta_template_count) / Number(metricsView.meta_sent_count)) * 100 : 0}%` }}></div>
              </div>
            </div>

            {/* Failover */}
            <div className="space-y-1">
              <div className="flex justify-between text-xs font-semibold">
                <span className="text-gray-600">Failovers BotConversa</span>
                <span className="text-gray-800">{metricsView.botconversa_sent_count}</span>
              </div>
              <div className="w-full bg-gray-100 h-3 rounded-full overflow-hidden">
                <div className="bg-red-500 h-full rounded-full" style={{ width: `${(Number(metricsView.botconversa_sent_count) / (Number(metricsView.meta_sent_count) || 1)) * 100}%` }}></div>
              </div>
            </div>

          </div>
        </div>

      </div>

    </div>
  )
}
