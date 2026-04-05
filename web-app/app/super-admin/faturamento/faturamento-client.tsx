'use client'

import React, { useState, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft, BarChart3, Database, Search, Shield, Zap, Filter, Calendar, Building2 } from 'lucide-react'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export default function FaturamentoClient({ consumos, superAdminEmail }: { consumos: any[], superAdminEmail: string }) {
  const router = useRouter()
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCondominio, setSelectedCondominio] = useState<string>('all')
  const [selectedPeriodo, setSelectedPeriodo] = useState<string>('all')

  const sortedConsumos = [...(consumos || [])].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())

  // Extrair filtros dinâmicos dos dados
  const { condominiosOptions, periodosOptions } = useMemo(() => {
    const condList = new Set<string>()
    const periodList = new Set<string>()
    
    sortedConsumos.forEach(c => {
      if (c.condominios?.nome) condList.add(c.condominios.nome)
      
      const date = new Date(c.created_at)
      // Formato YYYY-MM para ordenação e display amigável
      const monthStr = date.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })
      const sortValue = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
      periodList.add(JSON.stringify({ label: monthStr.charAt(0).toUpperCase() + monthStr.slice(1), value: sortValue }))
    })

    return {
      condominiosOptions: Array.from(condList).sort(),
      periodosOptions: Array.from(periodList).map(p => JSON.parse(p)).sort((a, b) => b.value.localeCompare(a.value))
    }
  }, [sortedConsumos])

  // Aplicar filtros avançados
  const filteredConsumos = sortedConsumos.filter(c => {
    // 1. Termo de Busca Livre
    const term = searchTerm.toLowerCase()
    const condName = c.condominios?.nome?.toLowerCase() || ''
    const srv = c.tipo_servico?.toLowerCase() || ''
    const matchSearch = term === '' || condName.includes(term) || srv.includes(term)

    // 2. Filtro Condomínio Dropdown
    const matchCondominio = selectedCondominio === 'all' || c.condominios?.nome === selectedCondominio

    // 3. Filtro Período (Mês/Ano) Dropdown
    const date = new Date(c.created_at)
    const rowPeriod = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
    const matchPeriod = selectedPeriodo === 'all' || rowPeriod === selectedPeriodo

    return matchSearch && matchCondominio && matchPeriod
  })

  // Recalcular métricas baseadas apenas nos itens filtrados (útil para cobrar fatura exata)
  const totalRevenue = filteredConsumos.reduce((acc, curr) => acc + Number(curr.valor_cobrado), 0)
  const totalOriginalCost = filteredConsumos.reduce((acc, curr) => acc + (Number(curr.valor_cobrado) / 3), 0) // Custo original é 1/3 do valor cobrado
  const totalAI = filteredConsumos.filter(c => c.tipo_servico === 'ATA_IA').reduce((acc, curr) => acc + Number(curr.valor_cobrado), 0)
  
  return (
    <div className="flex h-screen bg-[#F5F7FB]">
      <div className="flex-1 overflow-auto">
        {/* Header */}
        <header className="sticky top-0 z-10 bg-white/80 backdrop-blur-md border-b border-gray-100 flex flex-col md:flex-row md:items-center justify-between px-6 py-4 md:h-16 shadow-sm gap-4">
          <div className="flex items-center gap-4">
            <button onClick={() => router.push('/admin')} title="Voltar" aria-label="Voltar para Dashboard" className="p-2 hover:bg-gray-100 rounded-md text-gray-500 transition-colors">
              <ArrowLeft className="h-5 w-5" />
            </button>
            <div className="flex items-center gap-2">
              <div className="p-1.5 bg-yellow-100 rounded-lg">
                <BarChart3 className="h-5 w-5 text-yellow-600" />
              </div>
              <h1 className="text-xl font-semibold text-[#1A202C]">Faturamento & Extrato</h1>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="bg-yellow-50 text-yellow-700 border border-yellow-200 px-2.5 py-0.5 rounded-full text-xs font-semibold flex items-center">
              <Shield className="h-3.5 w-3.5 mr-1" /> Super Admin
            </div>
            <div className="text-sm text-gray-500 hidden md:block">{superAdminEmail}</div>
          </div>
        </header>

        <main className="p-6 md:p-8 max-w-7xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
          
          {/* Main Dashboard Cards */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="rounded-xl border border-green-200 bg-linear-to-br from-green-50 to-white shadow-sm ring-1 ring-black/5 p-6 flex flex-col relative overflow-hidden">
              <div className="absolute top-0 right-0 p-4 opacity-10"><BarChart3 size={64}/></div>
              <div className="flex flex-col mb-2 relative z-10">
                <span className="text-green-700 font-bold text-sm">Fatura para Cobrar (3x)</span>
                <span className="text-3xl font-black text-green-900 mt-1">
                  {new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(totalRevenue)}
                </span>
              </div>
              <p className="text-xs font-semibold text-green-600/80 mt-auto relative z-10">Lucro com a plataforma.</p>
            </div>

            <div className="rounded-xl border border-gray-200 bg-linear-to-br from-gray-50 to-white shadow-sm ring-1 ring-black/5 p-6 flex flex-col relative overflow-hidden">
              <div className="absolute top-0 right-0 p-4 opacity-5"><Database size={64}/></div>
              <div className="flex flex-col mb-2 relative z-10">
                <span className="text-gray-600 font-medium text-sm">Custo Original Plataforma</span>
                <span className="text-2xl font-bold text-gray-800 mt-1">
                  {new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(totalOriginalCost)}
                </span>
              </div>
              <p className="text-xs text-gray-500 mt-auto relative z-10">Seu custo real com APIs (Ex: Google).</p>
            </div>

            <div className="rounded-xl border border-indigo-100 bg-linear-to-br from-indigo-50 to-white shadow-sm ring-1 ring-black/5 p-6 flex flex-col">
              <div className="flex flex-col mb-2">
                <span className="text-indigo-600 font-medium text-sm flex items-center gap-1">
                  <Zap className="h-4 w-4" /> Uso da Geração de Ata IA
                </span>
                <span className="text-2xl font-bold text-indigo-900 mt-1">
                  {new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(totalAI)}
                </span>
              </div>
              <p className="text-xs text-indigo-600/70 mt-auto">Valor correspondente às Atas criadas.</p>
            </div>
            
            <div className="rounded-xl border border-blue-100 bg-linear-to-br from-blue-50 to-white shadow-sm ring-1 ring-black/5 p-6 flex flex-col">
              <div className="flex flex-col mb-2">
                <span className="text-blue-600 font-medium text-sm flex items-center gap-1">
                  <Database className="h-4 w-4" /> Armazenamento em Nuvem
                </span>
                <span className="text-2xl font-bold text-blue-900 mt-1">
                  {new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(totalRevenue - totalAI)}
                </span>
              </div>
              <p className="text-xs text-blue-600/70 mt-auto">Gravações das assembleias (1GB+).</p>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm ring-1 ring-gray-900/5 overflow-hidden">
            {/* Filters Bar */}
            <div className="p-5 border-b border-gray-100 flex flex-col gap-4">
              <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
                <Filter size={18} className="text-gray-400"/>
                Gerador de Faturas e Extrato
              </h2>
              
              <div className="flex flex-col sm:flex-row gap-3">
                
                {/* Dropdown: Período */}
                <div className="relative flex-1 max-w-[250px]">
                  <label className="text-xs font-semibold text-gray-500 mb-1 block uppercase tracking-wider">Mês de Cobrança</label>
                  <div className="relative">
                    <Calendar className="absolute left-2.5 top-2.5 h-4 w-4 text-gray-400" />
                    <select 
                      value={selectedPeriodo}
                      onChange={e => setSelectedPeriodo(e.target.value)}
                      className="w-full pl-9 pr-3 bg-gray-50 border border-gray-200 text-sm font-medium rounded-md h-9 focus:outline-none focus:ring-2 focus:ring-yellow-500 appearance-none text-gray-700"
                    >
                      <option value="all">Todos os Meses</option>
                      {periodosOptions.map(p => (
                        <option key={p.value} value={p.value}>{p.label}</option>
                      ))}
                    </select>
                  </div>
                </div>

                {/* Dropdown: Condomínio */}
                <div className="relative flex-1 max-w-[250px]">
                  <label className="text-xs font-semibold text-gray-500 mb-1 block uppercase tracking-wider">Filtrar Cliente (Condomínio)</label>
                  <div className="relative">
                    <Building2 className="absolute left-2.5 top-2.5 h-4 w-4 text-gray-400" />
                    <select 
                      value={selectedCondominio}
                      onChange={e => setSelectedCondominio(e.target.value)}
                      className="w-full pl-9 pr-3 bg-gray-50 border border-gray-200 text-sm font-medium rounded-md h-9 focus:outline-none focus:ring-2 focus:ring-yellow-500 appearance-none text-gray-700"
                    >
                      <option value="all">Todos os Condomínios</option>
                      {condominiosOptions.map(c => (
                        <option key={c} value={c}>{c}</option>
                      ))}
                    </select>
                  </div>
                </div>

                {/* Texto Busca Simples */}
                <div className="relative flex-1 max-w-[250px]">
                  <label className="text-xs font-semibold text-gray-500 mb-1 block uppercase tracking-wider">Busca Adicional</label>
                  <div className="relative">
                    <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-gray-400" />
                    <input 
                      type="search"
                      placeholder="Buscar servico..." 
                      className="pl-9 w-full bg-gray-50 border border-gray-200 text-sm font-medium rounded-md h-9 focus:outline-none focus:ring-2 focus:ring-yellow-500"
                      value={searchTerm}
                      onChange={e => setSearchTerm(e.target.value)}
                    />
                  </div>
                </div>

              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm whitespace-nowrap">
                <thead className="bg-[#F8FAFC] text-gray-600 border-b border-gray-100">
                  <tr>
                    <th className="px-6 py-3 font-semibold">Data / Hora / ID</th>
                    <th className="px-6 py-3 font-semibold">Condomínio Remetente</th>
                    <th className="px-6 py-3 font-semibold">Tipo Serviço</th>
                    <th className="px-6 py-3 font-semibold text-right text-gray-400">Seu Custo Base (1x)</th>
                    <th className="px-6 py-3 font-bold text-right text-green-700 bg-green-50/50">Cobrar Fatura (3x)</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {filteredConsumos.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="px-6 py-16 text-center">
                        <div className="flex flex-col items-center justify-center">
                          <Filter size={32} className="text-gray-300 mb-3" />
                          <h3 className="text-gray-900 font-medium text-lg">Sem registros para o filtro atual</h3>
                          <p className="text-gray-500">Altere o mês ou o condomínio acima.</p>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    filteredConsumos.map((consumo) => {
                      const chargedVal = Number(consumo.valor_cobrado)
                      const origCost = chargedVal / 3

                      return (
                        <tr key={consumo.id} className="hover:bg-gray-50/80 transition-colors">
                          <td className="px-6 py-4">
                            <div className="text-sm font-medium text-gray-900">
                              {new Date(consumo.created_at).toLocaleDateString('pt-BR')} às {new Date(consumo.created_at).toLocaleTimeString('pt-BR', { hour: '2-digit', minute:'2-digit' })}
                            </div>
                            <div className="text-[10px] text-gray-400 mt-1 uppercase tracking-wider font-mono">
                              REF: {consumo.id.split('-')[0]}
                            </div>
                          </td>
                          
                          <td className="px-6 py-4">
                            <div className="font-semibold text-gray-900">{consumo.condominios?.nome || 'Condomínio Removido'}</div>
                            {consumo.condominios?.cidade && (
                              <div className="text-xs text-gray-500 mt-0.5">{consumo.condominios.cidade} - {consumo.condominios.estado}</div>
                            )}
                          </td>
                          
                          <td className="px-6 py-4">
                            <span className={`inline-flex items-center px-2.5 py-1 rounded-md text-xs font-bold uppercase tracking-wider ${
                              consumo.tipo_servico === 'ATA_IA' 
                              ? 'bg-indigo-50 text-indigo-700 border border-indigo-200' 
                              : 'bg-blue-50 text-blue-700 border border-blue-200'
                            }`}>
                              {consumo.tipo_servico === 'ATA_IA' && <Zap className="h-3 w-3 mr-1" />}
                              {consumo.tipo_servico === 'ATA_IA' ? 'AI Generator' : 'Data Storage'}
                            </span>
                          </td>
                          
                          <td className="px-6 py-4 text-right">
                            <span className="font-mono text-gray-400 text-sm">
                              {new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(origCost)}
                            </span>
                          </td>
                          
                          <td className="px-6 py-4 text-right bg-green-50/20">
                            <span className="font-bold text-green-700 text-base">
                              {new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(chargedVal)}
                            </span>
                          </td>
                        </tr>
                      )
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>

        </main>
      </div>
    </div>
  )
}
