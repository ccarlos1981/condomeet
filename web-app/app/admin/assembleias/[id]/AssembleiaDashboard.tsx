"use client"

import React from 'react'
import { CheckCircle2, BarChart3, Users, Printer } from 'lucide-react'

/* eslint-disable @typescript-eslint/no-explicit-any */

interface DashboardProps {
  assembleia?: any
  pautas: any[]
  votos: any[]
  totalUnidades?: number
}

const CircularProgress = ({ value, max, color, label }: any) => {
  const percentage = max > 0 ? Math.min(100, (value / max) * 100) : 0
  const radius = 36
  const circumference = 2 * Math.PI * radius
  const strokeDashoffset = circumference - (percentage / 100) * circumference
  return (
    <div className="flex flex-col items-center">
      <div className="relative w-28 h-28 flex items-center justify-center">
        <svg className="w-full h-full transform -rotate-90">
          <circle cx="56" cy="56" r={radius} stroke="currentColor" strokeWidth="10" fill="transparent" className="text-gray-100" />
          <circle cx="56" cy="56" r={radius} stroke="currentColor" strokeWidth="10" fill="transparent" strokeDasharray={circumference} strokeDashoffset={strokeDashoffset} className={`${color} transition-all duration-1000 ease-out`} strokeLinecap="round" />
        </svg>
        <div className="absolute flex flex-col items-center justify-center">
          <span className="text-2xl font-black text-gray-800">{value}</span>
        </div>
      </div>
      <span className="mt-2 text-xs font-bold text-gray-600 text-center max-w-[120px] leading-tight uppercase tracking-wider">{label}</span>
    </div>
  )
}

export default function AssembleiaDashboard({ pautas, votos, totalUnidades = 0 }: DashboardProps) {
  const votesByPauta = pautas.reduce((acc: Record<string, any[]>, p) => {
    const pid = p.id as string
    acc[pid] = votos.filter(v => v.pauta_id === pid)
    return acc
  }, {})

  const uniqueUnitsSet = new Set<string>()
  votos.forEach((voto) => {
    const votoUnidades = voto.unidades as any
    const bloco = (votoUnidades?.bloco?.nome_ou_numero as string) || ''
    const apto = (votoUnidades?.apartamento?.numero as string) || ''
    const unidadeNome = `${bloco}-${apto}`
    if (bloco && apto) uniqueUnitsSet.add(unidadeNome)
  })
  const unidadesVotantes = uniqueUnitsSet.size
  const ausentes = Math.max(0, totalUnidades - unidadesVotantes)
  const votantesPerc = totalUnidades > 0 ? Math.round((unidadesVotantes / totalUnidades) * 100) : 0

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
      <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-gray-800">Resultados da Assembleia</h2>
          <p className="text-sm text-gray-500 mt-1">
            Esta assembleia foi finalizada. Confira o painel geral de presença e resultados detalhados abaixo.
          </p>
        </div>
        <div className="flex items-center gap-4">
          <button
            onClick={() => window.print()}
            className="print:hidden flex items-center gap-2 px-4 py-2 bg-purple-100 text-purple-700 hover:bg-purple-200 rounded-xl font-bold transition-colors text-sm shadow-sm"
          >
            <Printer size={16} />
            Gerar PDF / Imprimir
          </button>
          
          <div className="h-12 w-12 rounded-full bg-purple-50 flex items-center justify-center border border-purple-100 shadow-sm shrink-0">
            <CheckCircle2 className="text-purple-600" size={24} />
          </div>
        </div>
      </div>

      <div className="bg-white rounded-2xl p-6 md:p-8 border border-gray-100 shadow-sm w-full">
        <h3 className="font-bold text-gray-800 mb-6 flex items-center gap-2">
          <BarChart3 size={20} className="text-[#FC5931]" /> Painel de Engajamento
        </h3>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
          {/* Progress Bars as seen in print - moved down or hide as we will use circles */}
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="font-bold text-gray-700">Lista de presença</span>
              <span className="font-bold text-[#FC5931]">{votantesPerc}%</span>
            </div>
            <div className="w-full bg-gray-100 rounded-full h-3 overflow-hidden">
              <div className="bg-[#FC5931] h-3 rounded-full transition-all duration-1000 ease-out" style={{ width: `${votantesPerc}%` }} />
            </div>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="font-bold text-gray-700">Lista de apartamento</span>
              <span className="font-bold text-blue-600">{votantesPerc}%</span>
            </div>
            <div className="w-full bg-gray-100 rounded-full h-3 overflow-hidden">
              <div className="bg-blue-500 h-3 rounded-full transition-all duration-1000 ease-out" style={{ width: `${votantesPerc}%` }} />
            </div>
          </div>
        </div>

        <div className="flex flex-wrap justify-center md:justify-around gap-6">
           <CircularProgress value={totalUnidades} max={totalUnidades} color="text-amber-400" label="Aptos Cadastrados" />
           <CircularProgress value={unidadesVotantes} max={totalUnidades} color="text-blue-500" label="Aptos Presentes" />
           <CircularProgress value={unidadesVotantes} max={totalUnidades} color="text-emerald-500" label="Aptos que Votaram" />
           <CircularProgress value={ausentes} max={totalUnidades} color="text-red-500" label="Aptos que Não Votaram" />
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {pautas.map((pauta, idx) => {
          const pautaVotos = votesByPauta[pauta.id] || []
          const totalPautaVotos = pautaVotos.length
          
          // Calculate answers
          const results: Record<string, number> = {}
          pautaVotos.forEach((votoObj: any) => {
            let userVotos: string[] = []
            try {
              // Try to parse if it's a JSON array (multiple choices)
              const parsed = JSON.parse(votoObj.voto as string)
              if (Array.isArray(parsed)) {
                userVotos = parsed
              } else {
                userVotos = [votoObj.voto as string]
              }
            } catch {
              userVotos = [votoObj.voto as string]
            }

            userVotos.forEach(ans => {
              results[ans] = (results[ans] || 0) + 1
            })
          })

          // Sort descending by count
          const sortedResults = Object.entries(results).sort((a, b) => b[1] - a[1])

          return (
            <div key={pauta.id as string} className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
              <div className="flex gap-3 mb-6">
                <div className="w-8 h-8 rounded-full bg-gray-50 flex items-center justify-center shrink-0">
                  <span className="text-sm font-bold text-gray-400">{idx + 1}</span>
                </div>
                <div>
                  <h3 className="font-semibold text-gray-800 leading-tight">{pauta.titulo as string}</h3>
                  <div className="flex items-center gap-2 mt-2">
                    <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-blue-50 text-blue-700">
                      {pauta.tipo === 'votacao' ? <BarChart3 size={12} /> : <Users size={12} />}
                      {pauta.tipo === 'votacao' ? 'Votação' : 'Informativo'}
                    </span>
                    <span className="text-xs text-gray-500 font-medium">
                      {totalPautaVotos} votos registrados
                    </span>
                  </div>
                </div>
              </div>

              {/* Progress bars */}
              {pauta.tipo === 'votacao' && (
                <div className="space-y-4">
                  {sortedResults.length > 0 ? sortedResults.map(([opcao, count]) => {
                    const percentage = totalPautaVotos > 0 ? Math.round((count / totalPautaVotos) * 100) : 0
                    return (
                      <div key={opcao} className="space-y-1.5">
                        <div className="flex items-center justify-between text-sm">
                          <span className="font-medium text-gray-700 truncate pr-4">{opcao}</span>
                          <span className="font-bold text-gray-900">{percentage}%</span>
                        </div>
                        <div className="w-full bg-gray-100 rounded-full h-2 overflow-hidden">
                          <div 
                            className="bg-indigo-500 h-2 rounded-full transition-all duration-1000 ease-out" 
                            style={{ width: `${percentage}%` }}
                          />
                        </div>
                        <p className="text-xs text-gray-500">{count} votos</p>
                      </div>
                    )
                  }) : (
                    <div className="py-6 text-center text-sm text-gray-400 font-medium bg-gray-50 rounded-xl">
                      Nenhum voto registrado.
                    </div>
                  )}
                </div>
              )}
            </div>
          )
        })}
      </div>
      
      {/* Lista de Votantes Detailed Area */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="p-5 border-b border-gray-100 flex items-center justify-between">
          <h2 className="font-bold text-gray-800 flex items-center gap-2">
            <Users size={20} className="text-[#FC5931]" />
            Relatório de Presença e Votos
          </h2>
        </div>
        <div className="p-0 overflow-x-auto">
          <table className="w-full text-left text-sm text-gray-600">
            <thead className="text-xs text-gray-500 uppercase bg-gray-50">
              <tr>
                <th className="px-6 py-4 font-semibold">Unidade</th>
                <th className="px-6 py-4 font-semibold">Morador</th>
                <th className="px-6 py-4 font-semibold">Pauta</th>
                <th className="px-6 py-4 font-semibold">Voto</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {votos.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-6 py-8 text-center text-gray-400">
                    Nenhum voto registrado para exibir no relatório.
                  </td>
                </tr>
              ) : (
                votos.map(voto => {
                  const pauta = pautas.find(p => p.id === voto.pauta_id)
                  const votoUnidades = voto.unidades as any
                  const blocoObj = votoUnidades?.bloco as any
                  const aptoObj = votoUnidades?.apartamento as any
                  
                  const bloco = blocoObj?.nome_ou_numero as string || ''
                  const apto = aptoObj?.numero as string || ''
                  const unidadeNome = `${bloco} - ${apto}`
                  
                  const perfilObj = voto.perfil as any
                  const moradorNome = perfilObj?.nome_completo as string || 'Desconhecido'

                  return (
                    <tr key={voto.id as string} className="hover:bg-gray-50/50 transition-colors">
                      <td className="px-6 py-4 font-medium text-gray-900 whitespace-nowrap">
                        {unidadeNome}
                      </td>
                      <td className="px-6 py-4">{moradorNome}</td>
                      <td className="px-6 py-4 max-w-xs truncate" title={pauta?.titulo as string}>
                        {(pauta?.titulo as string) || '...'}
                      </td>
                      <td className="px-6 py-4 font-medium text-gray-900">
                        {((voto.voto as string) || '').replace(/[\[\]"]/g, '').replace(/,/g, ', ')}
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
