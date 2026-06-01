'use client'

import { useState } from 'react'
import { CheckCircle2, AlertCircle, Download, PlayCircle, Loader2, ArrowRight, ArrowLeft, Settings, Edit, X } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

type FinanceiroClientProps = {
  condoId: string
  condoName: string
  hasSplit: boolean
  modeloPadrao: string
  cotaPadrao: number
  totalReceitas: number
  totalDespesas: number
  faturamentos: any[]
}

export default function FinanceiroClient({ 
  condoId, 
  hasSplit, 
  modeloPadrao,
  cotaPadrao,
  totalReceitas, 
  totalDespesas, 
  faturamentos: initialFaturamentos
}: FinanceiroClientProps) {
  const [faturamentos, setFaturamentos] = useState(initialFaturamentos)
  const [step, setStep] = useState(0) // 0 = Resumo normal, 1 = Passo 1, 2 = Passo 2, etc.
  
  // Wizard State
  const [modelo, setModelo] = useState(modeloPadrao)
  const [valorBase, setValorBase] = useState(cotaPadrao)
  const [taxasExtras, setTaxasExtras] = useState<{descricao: string, valor: number}[]>([])
  
  // Simulation State
  const [simulacao, setSimulacao] = useState<any[]>([])
  const [resumoSimulacao, setResumoSimulacao] = useState<any>(null)
  
  const [isLoading, setIsLoading] = useState(false)
  const [generationSuccess, setGenerationSuccess] = useState(false)
  
  // Modal Edit State
  const [editingBoleto, setEditingBoleto] = useState<any>(null)
  const [editNovaData, setEditNovaData] = useState('')
  const [editIsentarJuros, setEditIsentarJuros] = useState(false)
  
  // Edit Rascunho State
  const [editingRascunhoIdx, setEditingRascunhoIdx] = useState<number | null>(null)
  const [editingRascunhoValores, setEditingRascunhoValores] = useState({
    valor_base: 0,
    taxas_extras: 0,
    multas: 0,
    reservas: 0,
  })
  
  const supabase = createClient()

  const formatCurrency = (val: number) => {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
  }

  const startWizard = () => setStep(1)

  const handleEditRascunho = (index: number) => {
    const item = simulacao[index]
    if (!item) return
    setEditingRascunhoIdx(index)
    setEditingRascunhoValores({
      valor_base: item.valor_base || 0,
      taxas_extras: item.taxas_extras || 0,
      multas: item.multas || 0,
      reservas: item.reservas || 0,
    })
  }

  const handleSaveRascunho = () => {
    if (editingRascunhoIdx === null) return
    const updatedSimulacao = [...simulacao]
    const item = updatedSimulacao[editingRascunhoIdx]
    if (item) {
      const vBase = Number(editingRascunhoValores.valor_base) || 0
      const vExtras = Number(editingRascunhoValores.taxas_extras) || 0
      const vMultas = Number(editingRascunhoValores.multas) || 0
      const vReservas = Number(editingRascunhoValores.reservas) || 0
      const newTotal = vBase + vExtras + vMultas + vReservas

      updatedSimulacao[editingRascunhoIdx] = {
        ...item,
        valor_base: vBase,
        taxas_extras: vExtras,
        multas: vMultas,
        reservas: vReservas,
        valor_total: newTotal
      }
      setSimulacao(updatedSimulacao)

      // Recalcular resumo
      const newTotalArrecadar = updatedSimulacao.reduce((sum, it) => sum + (it.valor_total || 0), 0)
      setResumoSimulacao({
        ...resumoSimulacao,
        valor_total_arrecadar: newTotalArrecadar
      })
    }
    setEditingRascunhoIdx(null)
  }

  const handleSimular = async () => {
    setIsLoading(true)
    try {
      const currentMonth = new Date().toISOString().substring(0, 7)
      const { data, error } = await supabase.functions.invoke('finance-simulate-billing', {
        body: { 
          condominio_id: condoId,
          mes_referencia: currentMonth,
          modelo,
          valor_base: valorBase,
          taxas_extras: taxasExtras
        }
      })

      if (error) throw error

      if (data.success) {
        setSimulacao(data.simulacao)
        setResumoSimulacao(data.resumo)
        setStep(4)
      }
    } catch (err) {
      console.error('Error simulating boletos:', err)
      alert('Erro ao calcular prévia. Verifique o console.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleGenerateBoletos = async () => {
    setIsLoading(true)
    try {
      const currentMonth = new Date().toISOString().substring(0, 7)
      
      const { data, error } = await supabase.functions.invoke('finance-billing-engine', {
        body: { 
          condominio_id: condoId,
          mes_referencia: currentMonth,
          boletos_rascunho: simulacao
        }
      })

      if (error) throw error

      if (data.success) {
        setGenerationSuccess(true)
        setStep(5) // Finished
        // Recarregar a página ou refazer fetch para mostrar boletos (simplificado aqui)
        setTimeout(() => window.location.reload(), 3000)
      }
    } catch (err) {
      console.error('Error generating boletos:', err)
      alert('Erro ao processar faturamento. Verifique o console.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleUpdateBoleto = async () => {
    if (!editingBoleto) return;
    setIsLoading(true);
    try {
       const { data, error } = await supabase.functions.invoke('finance-update-boleto', {
          body: {
             faturamento_id: editingBoleto.id,
             isentar_juros: editIsentarJuros,
             nova_data_vencimento: editNovaData || undefined
          }
       });

       if (error) throw error;
       alert('Boleto atualizado com sucesso!');
       setEditingBoleto(null);
       window.location.reload();
    } catch (err) {
       console.error(err);
       alert('Erro ao atualizar boleto.');
    } finally {
       setIsLoading(false);
    }
  }

  const addTaxaExtra = () => setTaxasExtras([...taxasExtras, { descricao: '', valor: 0 }])
  const updateTaxa = (index: number, field: string, val: string | number) => {
    const newTaxas = [...taxasExtras]
    newTaxas[index] = { ...newTaxas[index], [field]: val }
    setTaxasExtras(newTaxas)
  }
  const removeTaxa = (index: number) => {
    const newTaxas = [...taxasExtras]
    newTaxas.splice(index, 1)
    setTaxasExtras(newTaxas)
  }

  return (
    <div className="p-6 max-w-6xl mx-auto space-y-8">
      {/* HEADER */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Financeiro & Boletos</h1>
          <p className="text-gray-500 mt-1">Gestão de contas, balancetes e faturamento do condomínio.</p>
        </div>
      </div>

      {step === 0 && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 animate-in fade-in">
          {/* Resumo Financeiro */}
          <div className="col-span-1 md:col-span-2 bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
            <h2 className="text-lg font-bold text-gray-800 mb-4">Balancete Mensal (Real)</h2>
            <div className="space-y-4">
              <div className="flex justify-between items-center py-3 border-b border-gray-50">
                <span className="text-gray-600 font-medium">1.0 Receitas Totais</span>
                <span className="text-green-600 font-bold">{formatCurrency(totalReceitas)}</span>
              </div>
              <div className="flex justify-between items-center py-3 border-b border-gray-50">
                <span className="text-gray-600 font-medium">2.0 Despesas Ordinárias</span>
                <span className="text-red-500 font-bold">- {formatCurrency(totalDespesas)}</span>
              </div>
              <div className="flex justify-between items-center py-4 bg-gray-50 px-4 rounded-xl mt-4">
                <span className="text-gray-800 font-bold">Saldo Operacional</span>
                <span className="text-gray-900 font-bold">{formatCurrency(totalReceitas - totalDespesas)}</span>
              </div>
            </div>
          </div>

          {/* Emitir Boletos Call to Action */}
          <div className="col-span-1 bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex flex-col justify-between">
            <div>
              <h2 className="text-lg font-bold text-gray-800 mb-2">Emitir Boletos</h2>
              <p className="text-sm text-gray-500 mb-6">Inicie o assistente para gerar as cobranças deste mês.</p>
              
              <div className="bg-blue-50 text-blue-800 p-4 rounded-xl text-sm mb-6">
                <p className="font-semibold">Modelo Configurado: {modelo === 'fixo' ? 'Cota Fixa' : 'Rateio'}</p>
                {hasSplit && (
                  <p className="opacity-90 mt-2 text-xs font-bold text-blue-700">✓ Split Asaas Ativo</p>
                )}
              </div>
            </div>
            
            <button 
              onClick={startWizard}
              className="w-full py-3.5 bg-[#FC5931] hover:bg-[#D42F1D] text-white font-bold rounded-xl flex justify-center items-center gap-2 transition-all shadow-md hover:shadow-lg"
            >
              <PlayCircle size={18} />
              Gerar Novas Cobranças
            </button>
          </div>
        </div>
      )}

      {/* WIZARD STEPS */}
      {step > 0 && step < 5 && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden animate-in fade-in">
           <div className="bg-gray-50 px-6 py-4 border-b border-gray-100 flex items-center justify-between">
              <h2 className="font-bold text-gray-800 flex items-center gap-2">
                 <Settings size={18} className="text-[#FC5931]" />
                 Assistente de Faturamento (Passo {step} de 4)
              </h2>
              <button onClick={() => setStep(0)} className="text-sm text-gray-500 hover:text-gray-800">Cancelar</button>
           </div>
           
           <div className="p-6">
              {step === 1 && (
                 <div className="space-y-6 max-w-xl mx-auto">
                    <div>
                       <h3 className="text-lg font-bold text-gray-800 mb-1">Passo 1: Cota Base</h3>
                       <p className="text-sm text-gray-500 mb-6">Como será a cobrança principal deste mês?</p>
                       
                       <div className="space-y-4">
                          <label className={`block border p-4 rounded-xl cursor-pointer transition-colors ${modelo === 'fixo' ? 'border-[#FC5931] bg-orange-50' : 'border-gray-200 hover:border-gray-300'}`}>
                             <div className="flex items-center gap-3">
                                <input type="radio" checked={modelo === 'fixo'} onChange={() => setModelo('fixo')} className="w-5 h-5 text-[#FC5931] focus:ring-[#FC5931]" />
                                <div>
                                   <p className="font-bold text-gray-900">Cota Fixa</p>
                                   <p className="text-sm text-gray-500">Valor predefinido igual para todas as cotas.</p>
                                </div>
                             </div>
                             {modelo === 'fixo' && (
                                <div className="mt-4 ml-8">
                                   <label className="text-sm font-medium text-gray-700">Valor da Cota (R$)</label>
                                   <input type="number" value={valorBase} onChange={(e) => setValorBase(Number(e.target.value))} className="mt-1 block w-48 rounded-md border-gray-300 shadow-sm focus:border-[#FC5931] focus:ring-[#FC5931] sm:text-sm" />
                                </div>
                             )}
                          </label>

                          <label className={`block border p-4 rounded-xl cursor-pointer transition-colors ${modelo === 'rateio' ? 'border-[#FC5931] bg-orange-50' : 'border-gray-200 hover:border-gray-300'}`}>
                             <div className="flex items-center gap-3">
                                <input type="radio" checked={modelo === 'rateio'} onChange={() => setModelo('rateio')} className="w-5 h-5 text-[#FC5931] focus:ring-[#FC5931]" />
                                <div>
                                   <p className="font-bold text-gray-900">Rateio de Despesas</p>
                                   <p className="text-sm text-gray-500">O sistema dividirá o total de despesas (R$ {totalDespesas}) pelas unidades.</p>
                                </div>
                             </div>
                          </label>
                       </div>
                    </div>
                 </div>
              )}

              {step === 2 && (
                 <div className="space-y-6 max-w-xl mx-auto">
                    <h3 className="text-lg font-bold text-gray-800 mb-1">Passo 2: Taxas Extras</h3>
                    <p className="text-sm text-gray-500 mb-6">Deseja adicionar alguma taxa global para todos os moradores? (Ex: Fundo de Reserva)</p>
                    
                    {taxasExtras.map((taxa, i) => (
                       <div key={i} className="flex items-end gap-4 p-4 border rounded-xl bg-gray-50">
                          <div className="flex-1">
                             <label className="text-xs font-medium text-gray-500 uppercase">Descrição</label>
                             <input type="text" value={taxa.descricao} onChange={e => updateTaxa(i, 'descricao', e.target.value)} placeholder="Ex: Taxa de Obras" className="mt-1 block w-full rounded-md border-gray-300 sm:text-sm" />
                          </div>
                          <div className="w-32">
                             <label className="text-xs font-medium text-gray-500 uppercase">Valor (R$)</label>
                             <input type="number" value={taxa.valor} onChange={e => updateTaxa(i, 'valor', Number(e.target.value))} className="mt-1 block w-full rounded-md border-gray-300 sm:text-sm" />
                          </div>
                          <button onClick={() => removeTaxa(i)} className="p-2 text-red-500 hover:bg-red-50 rounded-lg">X</button>
                       </div>
                    ))}
                    <button onClick={addTaxaExtra} className="text-sm font-bold text-[#FC5931] hover:text-[#D42F1D]">+ Adicionar Taxa Extra</button>
                 </div>
              )}

              {step === 3 && (
                 <div className="space-y-6 max-w-xl mx-auto text-center py-8">
                    <CheckCircle2 size={48} className="mx-auto text-green-500 mb-4" />
                    <h3 className="text-xl font-bold text-gray-800">Pronto para a Prévia</h3>
                    <p className="text-gray-500">O sistema agora vai juntar a Cota Base, as Taxas Extras e vasculhar o banco de dados por Multas e Reservas individuais para calcular a fatura exata de cada apartamento.</p>
                 </div>
              )}

              {step === 4 && (
                 <div className="space-y-6">
                    <div className="flex justify-between items-end mb-4">
                       <div>
                          <h3 className="text-lg font-bold text-gray-800">Prévia do Faturamento (Rascunho)</h3>
                          <p className="text-sm text-gray-500">Confira os valores finais antes de disparar para o Asaas.</p>
                       </div>
                       <div className="text-right">
                          <p className="text-sm text-gray-500">Total a Arrecadar</p>
                          <p className="text-2xl font-bold text-green-600">{formatCurrency(resumoSimulacao?.valor_total_arrecadar || 0)}</p>
                       </div>
                    </div>

                    <div className="overflow-x-auto border rounded-xl">
                       <table className="w-full text-left text-sm">
                          <thead className="bg-gray-50 border-b">
                             <tr>
                                <th className="p-3 font-medium">Unidade</th>
                                <th className="p-3 font-medium">Cota Base</th>
                                <th className="p-3 font-medium">Taxas Extras</th>
                                <th className="p-3 font-medium text-red-500">Multas</th>
                                <th className="p-3 font-medium text-blue-500">Reservas</th>
                                <th className="p-3 font-bold text-gray-900">TOTAL</th>
                                <th className="p-3 font-medium text-right">Ações</th>
                             </tr>
                          </thead>
                          <tbody>
                             {simulacao.map((item, i) => (
                                <tr key={i} className="border-b last:border-0 hover:bg-gray-50">
                                   <td className="p-3 font-medium">{item.bloco ? `${item.bloco} / ` : ''}Apto {item.apto}</td>
                                   <td className="p-3">{formatCurrency(item.valor_base)}</td>
                                   <td className="p-3">{formatCurrency(item.taxas_extras)}</td>
                                   <td className="p-3 text-red-500">{formatCurrency(item.multas)}</td>
                                   <td className="p-3 text-blue-500">{formatCurrency(item.reservas)}</td>
                                   <td className="p-3 font-bold text-gray-900">{formatCurrency(item.valor_total)}</td>
                                   <td className="p-3 text-right">
                                      <button 
                                         onClick={() => handleEditRascunho(i)}
                                         className="text-[#FC5931] hover:text-[#D42F1D] p-1 inline-flex items-center gap-1 font-semibold text-xs transition-colors"
                                         title="Editar valores"
                                      >
                                         <Edit size={14} />
                                         Editar
                                      </button>
                                   </td>
                                </tr>
                             ))}
                          </tbody>
                       </table>
                    </div>
                 </div>
              )}
           </div>

           <div className="bg-gray-50 px-6 py-4 border-t border-gray-100 flex justify-between">
              {step > 1 ? (
                 <button onClick={() => setStep(step - 1)} className="px-4 py-2 text-gray-600 font-medium hover:bg-gray-200 rounded-lg flex items-center gap-2">
                    <ArrowLeft size={16} /> Voltar
                 </button>
              ) : <div></div>}
              
              {step < 3 && (
                 <button onClick={() => setStep(step + 1)} className="px-6 py-2 bg-gray-900 text-white font-bold rounded-lg flex items-center gap-2 hover:bg-gray-800">
                    Avançar <ArrowRight size={16} />
                 </button>
              )}
              {step === 3 && (
                 <button onClick={handleSimular} disabled={isLoading} className="px-6 py-2 bg-blue-600 text-white font-bold rounded-lg flex items-center gap-2 hover:bg-blue-700 disabled:opacity-50">
                    {isLoading ? <Loader2 className="animate-spin" size={16} /> : <PlayCircle size={16} />}
                    Gerar Prévia
                 </button>
              )}
              {step === 4 && (
                 <button onClick={handleGenerateBoletos} disabled={isLoading} className="px-6 py-2 bg-[#FC5931] text-white font-bold rounded-lg flex items-center gap-2 hover:bg-[#D42F1D] disabled:opacity-50 shadow-lg">
                    {isLoading ? <Loader2 className="animate-spin" size={16} /> : <CheckCircle2 size={16} />}
                    Confirmar e Emitir Boletos
                 </button>
              )}
           </div>
        </div>
      )}

      {step === 5 && (
        <div className="bg-green-50 border border-green-200 rounded-2xl p-8 text-center animate-in fade-in">
           <CheckCircle2 size={64} className="mx-auto text-green-500 mb-4" />
           <h2 className="text-2xl font-bold text-green-800">Sucesso!</h2>
           <p className="text-green-600 mt-2">Os boletos foram gerados no Asaas e já estão disponíveis para os moradores.</p>
        </div>
      )}
      
      {/* Listagem de Boletos Real */}
      {step === 0 && (
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-lg font-bold text-gray-800">Boletos Recentes</h2>
          </div>
          
          <div className="overflow-x-auto">
            {faturamentos.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                Nenhum boleto gerado para este condomínio ainda.
              </div>
            ) : (
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-gray-100 text-sm text-gray-500">
                    <th className="pb-3 font-medium">Unidade</th>
                    <th className="pb-3 font-medium">Morador</th>
                    <th className="pb-3 font-medium">Vencimento</th>
                    <th className="pb-3 font-medium">Valor Total</th>
                    <th className="pb-3 font-medium">Status</th>
                    <th className="pb-3 font-medium text-right">Ações</th>
                  </tr>
                </thead>
                <tbody className="text-sm">
                  {faturamentos.map(fat => (
                    <tr key={fat.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                      <td className="py-4 text-gray-800 font-medium whitespace-nowrap">
                        {fat.unidades?.blocos?.nome_ou_numero ? `${fat.unidades.blocos.nome_ou_numero} / ` : ''}Apto {fat.unidades?.apartamentos?.numero}
                      </td>
                      <td className="py-4 text-gray-600">{fat.perfil?.nome_completo || 'Não atribuído'}</td>
                      <td className="py-4 text-gray-600">
                        {new Date(fat.data_vencimento).toLocaleDateString('pt-BR', {timeZone: 'UTC'})}
                      </td>
                      <td className="py-4 font-medium text-gray-900">{formatCurrency(fat.valor_total)}</td>
                      <td className="py-4">
                        {fat.status_pagamento === 'pago' ? (
                          <span className="px-2.5 py-1 bg-green-100 text-green-800 rounded-full text-xs font-semibold">Pago</span>
                        ) : (
                          <span className="px-2.5 py-1 bg-yellow-100 text-yellow-800 rounded-full text-xs font-semibold">Pendente</span>
                        )}
                      </td>
                      <td className="py-4 text-right flex justify-end gap-2">
                        {fat.status_pagamento === 'pendente' && (
                          <button onClick={() => {
                             setEditingBoleto(fat);
                             setEditNovaData(fat.data_vencimento);
                             setEditIsentarJuros(false);
                          }} className="text-gray-500 hover:text-blue-600 p-1.5" title="Editar Boleto">
                            <Edit size={18} />
                          </button>
                        )}
                        <a href={fat.gateway_invoice_url} target="_blank" className="text-[#FC5931] hover:text-[#D42F1D] p-1.5" title="Ver no Asaas">
                          <Download size={18} />
                        </a>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}

      {/* MODAL EDIÇÃO */}
      {editingBoleto && (
         <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-xl relative animate-in zoom-in-95">
               <button onClick={() => setEditingBoleto(null)} className="absolute top-4 right-4 text-gray-400 hover:text-gray-600">
                  <X size={20} />
               </button>
               <h3 className="text-lg font-bold text-gray-900 mb-1">Editar Boleto</h3>
               <p className="text-sm text-gray-500 mb-6">Apto {editingBoleto.unidades?.apartamentos?.numero} - {editingBoleto.perfil?.nome_completo}</p>
               
               <div className="space-y-4 mb-6">
                  <div>
                     <label className="block text-sm font-medium text-gray-700 mb-1">Novo Vencimento (Opcional)</label>
                     <input type="date" value={editNovaData} onChange={e => setEditNovaData(e.target.value)} className="w-full rounded-md border-gray-300 shadow-sm sm:text-sm" />
                  </div>
                  <label className="flex items-center gap-3 p-3 border rounded-xl cursor-pointer hover:bg-gray-50">
                     <input type="checkbox" checked={editIsentarJuros} onChange={e => setEditIsentarJuros(e.target.checked)} className="w-5 h-5 text-blue-600 rounded border-gray-300" />
                     <div className="flex-1">
                        <p className="text-sm font-bold text-gray-800">Isentar Juros e Multa</p>
                        <p className="text-xs text-gray-500">Zera as taxas extras deste boleto no Asaas.</p>
                     </div>
                  </label>
               </div>

               <div className="flex gap-3 justify-end">
                  <button onClick={() => setEditingBoleto(null)} className="px-4 py-2 text-gray-600 font-medium hover:bg-gray-100 rounded-lg">Cancelar</button>
                  <button onClick={handleUpdateBoleto} disabled={isLoading} className="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-lg flex items-center gap-2">
                     {isLoading ? <Loader2 className="animate-spin" size={16} /> : 'Salvar Alterações'}
                  </button>
               </div>
            </div>
         </div>
      )}

      {/* MODAL EDIÇÃO RASCUNHO */}
      {editingRascunhoIdx !== null && (
         <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-xl relative animate-in zoom-in-95">
               <button onClick={() => setEditingRascunhoIdx(null)} className="absolute top-4 right-4 text-gray-400 hover:text-gray-600">
                  <X size={20} />
               </button>
               <h3 className="text-lg font-bold text-gray-900 mb-1">Ajustar Lançamentos</h3>
               <p className="text-sm text-gray-500 mb-6">
                  {simulacao[editingRascunhoIdx]?.bloco ? `${simulacao[editingRascunhoIdx].bloco} / ` : ''}Apto {simulacao[editingRascunhoIdx]?.apto} - {simulacao[editingRascunhoIdx]?.morador_nome}
               </p>
               
               <div className="space-y-4 mb-6">
                  <div>
                     <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Cota Base (R$)</label>
                     <input 
                        type="number" 
                        value={editingRascunhoValores.valor_base} 
                        onChange={e => setEditingRascunhoValores({ ...editingRascunhoValores, valor_base: Number(e.target.value) })} 
                        className="w-full rounded-md border-gray-300 shadow-sm sm:text-sm focus:border-[#FC5931] focus:ring-[#FC5931]" 
                     />
                  </div>
                  <div>
                     <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Taxas Extras (R$)</label>
                     <input 
                        type="number" 
                        value={editingRascunhoValores.taxas_extras} 
                        onChange={e => setEditingRascunhoValores({ ...editingRascunhoValores, taxas_extras: Number(e.target.value) })} 
                        className="w-full rounded-md border-gray-300 shadow-sm sm:text-sm focus:border-[#FC5931] focus:ring-[#FC5931]" 
                     />
                  </div>
                  <div>
                     <label className="block text-xs font-semibold text-gray-500 uppercase mb-1 text-red-600">Multas (R$)</label>
                     <input 
                        type="number" 
                        value={editingRascunhoValores.multas} 
                        onChange={e => setEditingRascunhoValores({ ...editingRascunhoValores, multas: Number(e.target.value) })} 
                        className="w-full rounded-md border-gray-300 shadow-sm sm:text-sm focus:border-[#FC5931] focus:ring-[#FC5931]" 
                     />
                  </div>
                  <div>
                     <label className="block text-xs font-semibold text-gray-500 uppercase mb-1 text-blue-600">Reservas / Outros (R$)</label>
                     <input 
                        type="number" 
                        value={editingRascunhoValores.reservas} 
                        onChange={e => setEditingRascunhoValores({ ...editingRascunhoValores, reservas: Number(e.target.value) })} 
                        className="w-full rounded-md border-gray-300 shadow-sm sm:text-sm focus:border-[#FC5931] focus:ring-[#FC5931]" 
                     />
                  </div>
                  
                  <div className="bg-gray-50 p-4 rounded-xl flex justify-between items-center border border-gray-100 mt-2">
                     <span className="font-semibold text-gray-700 text-sm">Novo Valor Total:</span>
                     <span className="font-bold text-gray-900 text-lg">
                        {formatCurrency(
                           (Number(editingRascunhoValores.valor_base) || 0) +
                           (Number(editingRascunhoValores.taxas_extras) || 0) +
                           (Number(editingRascunhoValores.multas) || 0) +
                           (Number(editingRascunhoValores.reservas) || 0)
                        )}
                     </span>
                  </div>
               </div>

               <div className="flex gap-3 justify-end">
                  <button onClick={() => setEditingRascunhoIdx(null)} className="px-4 py-2 text-gray-600 font-medium hover:bg-gray-100 rounded-lg">Cancelar</button>
                  <button onClick={handleSaveRascunho} className="px-6 py-2 bg-[#FC5931] hover:bg-[#D42F1D] text-white font-bold rounded-lg transition-colors">
                     Confirmar Ajustes
                  </button>
               </div>
            </div>
         </div>
      )}
    </div>
  )
}
