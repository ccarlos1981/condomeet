'use client'

import { useState, useEffect } from 'react'
import { Plus, Building2, Link as LinkIcon, Settings, Banknote, ShieldCheck, X } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

export default function ContasBancariasPage() {
  const [activeTab, setActiveTab] = useState<'contas' | 'plano'>('contas')
  const [showConfig, setShowConfig] = useState(false)
  const [multa, setMulta] = useState(2)
  const [juros, setJuros] = useState(3)
  const [condoId, setCondoId] = useState('')
  const [condoNome, setCondoNome] = useState('Condomínio')
  const [loading, setLoading] = useState(false)
  const supabase = createClient()

  useEffect(() => {
    async function loadData() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      
      const { data: profile } = await supabase.from('perfil').select('condominio_id').eq('id', user.id).single()
      if (profile?.condominio_id) {
        setCondoId(profile.condominio_id)
        const { data: condo } = await supabase.from('condominios').select('nome, multa_padrao, juros_mensal_padrao').eq('id', profile.condominio_id).single()
        if (condo) {
          if (condo.nome) setCondoNome(condo.nome)
          if (condo.multa_padrao !== null) setMulta(Number(condo.multa_padrao))
          if (condo.juros_mensal_padrao !== null) setJuros(Number(condo.juros_mensal_padrao))
        }
      }
    }
    loadData()
  }, [])

  async function handleSaveConfig() {
    if (!condoId) return
    setLoading(true)
    await supabase.from('condominios').update({
      multa_padrao: multa,
      juros_mensal_padrao: juros
    }).eq('id', condoId)
    setLoading(false)
    setShowConfig(false)
  }

  return (
    <div className="p-6 max-w-6xl mx-auto space-y-8">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Contas & Planos</h1>
          <p className="text-gray-500 mt-1">Gerencie a integração com o Banco e o Plano de Contas do condomínio.</p>
        </div>
        <div className="flex gap-3">
          <button className="px-4 py-2 bg-[#FC5931] hover:bg-[#D42F1D] text-white rounded-xl font-medium transition-colors flex items-center gap-2">
            <Plus size={18} />
            {activeTab === 'contas' ? 'Nova Conta' : 'Nova Categoria'}
          </button>
        </div>
      </div>

      <div className="flex gap-4 border-b border-gray-200">
        <button
          onClick={() => setActiveTab('contas')}
          className={`pb-4 px-2 font-medium text-sm transition-colors border-b-2 ${
            activeTab === 'contas' ? 'border-[#FC5931] text-[#FC5931]' : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          Contas Bancárias & Gateway
        </button>
        <button
          onClick={() => setActiveTab('plano')}
          className={`pb-4 px-2 font-medium text-sm transition-colors border-b-2 ${
            activeTab === 'plano' ? 'border-[#FC5931] text-[#FC5931]' : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          Plano de Contas (Categorias)
        </button>
      </div>

      {activeTab === 'contas' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="bg-white rounded-2xl p-6 shadow-sm border border-green-100 relative overflow-hidden">
            <div className="absolute top-0 right-0 p-4">
              <span className="px-2.5 py-1 bg-green-100 text-green-800 rounded-full text-xs font-bold flex items-center gap-1">
                <ShieldCheck size={14} /> Ativa (Split)
              </span>
            </div>
            <div className="flex items-center gap-4 mb-6">
              <div className="w-12 h-12 rounded-full bg-blue-50 flex items-center justify-center">
                <Banknote size={24} className="text-blue-600" />
              </div>
              <div>
                <h3 className="font-bold text-gray-900 text-lg">Asaas (Conta Secundária - {condoNome})</h3>
                <p className="text-sm text-gray-500">Gateway de Pagamento Integrado</p>
              </div>
            </div>
            
            <div className="space-y-3 mb-6">
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Taxa por Boleto Pago</span>
                <span className="font-medium text-gray-900">R$ 0,99</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Taxa do Condomeet (Split)</span>
                <span className="font-medium text-gray-900">3% (Somente Liquidados)</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Multa por Atraso (Repassada)</span>
                <span className="font-medium text-gray-900">{multa}%</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Juros Mensal</span>
                <span className="font-medium text-gray-900">{juros}% ao mês</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Dias para Saque</span>
                <span className="font-medium text-gray-900">D+2</span>
              </div>
            </div>

            <div className="flex gap-2">
              <button onClick={() => setShowConfig(true)} className="flex-1 py-2 bg-gray-50 hover:bg-gray-100 text-gray-700 rounded-lg text-sm font-medium border border-gray-200 transition-colors flex items-center justify-center gap-2">
                <Settings size={16} /> Configurar Juros/Multa
              </button>
              <button className="flex-1 py-2 bg-white hover:bg-gray-50 text-red-600 rounded-lg text-sm font-medium border border-gray-200 transition-colors flex items-center justify-center gap-2">
                <LinkIcon size={16} /> Desconectar
              </button>
            </div>
          </div>
          
          <div className="bg-gray-50 rounded-2xl p-6 border border-dashed border-gray-300 flex flex-col items-center justify-center text-center space-y-4">
            <div className="w-16 h-16 rounded-full bg-white flex items-center justify-center shadow-sm">
              <Building2 size={24} className="text-gray-400" />
            </div>
            <div>
              <h3 className="font-bold text-gray-900">Adicionar Conta Corrente</h3>
              <p className="text-sm text-gray-500 mt-1 max-w-xs mx-auto">Vincule a conta do Itaú, Bradesco ou Banco do Brasil para transferências de saque do Gateway.</p>
            </div>
            <button className="px-4 py-2 bg-white border border-gray-200 text-gray-700 rounded-xl font-medium hover:bg-gray-50 transition-colors shadow-sm mt-2">
              Adicionar Banco
            </button>
          </div>
        </div>
      )}

      {/* Modal de Configuração */}
      {showConfig && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-md overflow-hidden">
            <div className="flex items-center justify-between p-5 border-b border-gray-100">
              <h3 className="font-bold text-lg text-gray-900">Configurar Juros e Multa</h3>
              <button onClick={() => setShowConfig(false)} className="text-gray-400 hover:bg-gray-100 p-2 rounded-lg transition-colors">
                <X size={20} />
              </button>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Multa por Atraso (%)</label>
                <input
                  type="number"
                  value={multa}
                  onChange={(e) => setMulta(Number(e.target.value))}
                  className="w-full border border-gray-300 rounded-xl px-4 py-2.5 focus:outline-none focus:ring-2 focus:ring-[#FC5931] focus:border-[#FC5931]"
                />
                <p className="text-xs text-gray-500 mt-1">Valor fixo cobrado no primeiro dia de atraso.</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Juros ao Mês (%)</label>
                <input
                  type="number"
                  value={juros}
                  onChange={(e) => setJuros(Number(e.target.value))}
                  className="w-full border border-gray-300 rounded-xl px-4 py-2.5 focus:outline-none focus:ring-2 focus:ring-[#FC5931] focus:border-[#FC5931]"
                />
                <p className="text-xs text-gray-500 mt-1">Juros cobrados proporcionalmente por dia de atraso.</p>
              </div>
            </div>
            <div className="p-5 border-t border-gray-100 bg-gray-50 flex justify-end gap-3">
              <button onClick={() => setShowConfig(false)} className="px-4 py-2 font-medium text-gray-600 hover:bg-gray-200 rounded-xl transition-colors">
                Cancelar
              </button>
              <button onClick={handleSaveConfig} disabled={loading} className="px-5 py-2 font-medium bg-[#FC5931] hover:bg-[#D42F1D] text-white rounded-xl shadow-sm transition-colors disabled:opacity-50">
                {loading ? 'Salvando...' : 'Salvar Alterações'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Plano de contas mockup */}
      {activeTab === 'plano' && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="p-10 text-center text-gray-500">Plano de contas configurado.</div>
        </div>
      )}
    </div>
  )
}
