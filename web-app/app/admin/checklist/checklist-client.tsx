'use client'

import { useState } from 'react'
import {
  ClipboardCheck, BarChart3, Building2, LayoutTemplate,
  Crown, ShieldCheck, PieChart, Plus, Search, Map, X, Loader2
} from 'lucide-react'
import { createGlobalTemplate } from './actions'


export type GlobalMetrics = {
  totalChecklists: number
  totalCondos: number
  countPlus: number
  countFree: number
  tipoBemCounts: Record<string, number>
}

export type CondoUsage = {
  nome: string
  count: number
  plano: string
  last_used: string
}

export type VistoriaTemplateGlobal = {
  id: string
  nome: string
  descricao: string
  tipo_bem: string
  icone_emoji: string
  created_at: string
}

export type ChecklistAdminClientProps = {
  metrics: GlobalMetrics
  condosUsage: CondoUsage[]
  templates: VistoriaTemplateGlobal[]
}

export default function ChecklistAdminClient({ metrics, condosUsage, templates }: ChecklistAdminClientProps) {
  const [activeTab, setActiveTab] = useState<'overview' | 'templates'>('overview')
  const [searchCondo, setSearchCondo] = useState('')

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [modalForm, setModalForm] = useState({
    nome: '',
    descricao: '',
    tipo_bem: 'apartamento',
    icone_emoji: '📋'
  })

  // Handle Modal Submit
  const handleCreateTemplate = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)

    const formData = new FormData()
    formData.append('nome', modalForm.nome)
    formData.append('descricao', modalForm.descricao)
    formData.append('tipo_bem', modalForm.tipo_bem)
    formData.append('icone_emoji', modalForm.icone_emoji)

    const result = await createGlobalTemplate(formData)

    setIsSubmitting(false)
    if (result.error) {
      alert('Erro: ' + result.error)
    } else {
      setIsModalOpen(false)
      setModalForm({
        nome: '',
        descricao: '',
        tipo_bem: 'apartamento',
        icone_emoji: '📋'
      })
    }
  }

  const filteredCondos = condosUsage.filter(c =>
    c.nome.toLowerCase().includes(searchCondo.toLowerCase())
  )

  const formatDate = (dateString: string) => {
    return new Intl.DateTimeFormat('pt-BR', {
      day: '2-digit', month: 'short', year: 'numeric'
    }).format(new Date(dateString))
  }

  const tiposEntries = Object.entries(metrics.tipoBemCounts).sort((a, b) => b[1] - a[1])

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-3">
          <ClipboardCheck size={28} className="text-indigo-600" />
          Checklist Parceiros
        </h1>
        <p className="text-sm text-gray-500 mt-1">
          Backoffice Global da funcionalidade Checklists/Vistorias no aplicativo.
        </p>
      </div>

      {/* Tabs */}
      <div className="flex space-x-1 bg-gray-100/80 p-1 rounded-xl w-fit">
        <button
          onClick={() => setActiveTab('overview')}
          className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg transition-colors ${
            activeTab === 'overview' ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          <BarChart3 size={16} /> Visão Geral & Uso
        </button>
        <button
          onClick={() => setActiveTab('templates')}
          className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg transition-colors ${
            activeTab === 'templates' ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          <LayoutTemplate size={16} /> Templates Globais
        </button>
      </div>

      {activeTab === 'overview' && (
        <div className="space-y-6 animate-in fade-in duration-300">
          {/* Metrics Grid */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
              <div className="flex items-center justify-between text-gray-500 mb-2">
                <span className="text-sm font-medium">Total de Checklists</span>
                <ClipboardCheck size={18} className="text-indigo-500" />
              </div>
              <p className="text-3xl font-bold text-gray-900">{metrics.totalChecklists}</p>
            </div>
            <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
              <div className="flex items-center justify-between text-gray-500 mb-2">
                <span className="text-sm font-medium">Condomínios Ativos</span>
                <Building2 size={18} className="text-emerald-500" />
              </div>
              <p className="text-3xl font-bold text-gray-900">{metrics.totalCondos}</p>
            </div>
            <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
              <div className="flex items-center justify-between text-gray-500 mb-2">
                <span className="text-sm font-medium">Uso Plus vs Free</span>
                <Crown size={18} className="text-amber-500" />
              </div>
              <div className="flex items-baseline gap-2">
                <p className="text-3xl font-bold text-gray-900">{metrics.countPlus}</p>
                <span className="text-sm text-gray-500">/ {metrics.countFree} free</span>
              </div>
            </div>
            <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
              <div className="flex items-center justify-between text-gray-500 mb-2">
                <span className="text-sm font-medium">Item Mais Frequente</span>
                <PieChart size={18} className="text-blue-500" />
              </div>
              <p className="text-xl font-bold text-gray-900 capitalize truncate">
                {tiposEntries.length > 0 ? tiposEntries[0][0] : '-'}
              </p>
            </div>
          </div>

          {/* Uso por Condomínio Tabela */}
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden shadow-sm">
            <div className="p-5 border-b border-gray-100 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
              <div>
                <h3 className="font-semibold text-gray-900">Uso por Condomínio</h3>
                <p className="text-sm text-gray-500">Acompanhe quem está gerando checklists no sistema</p>
              </div>
              <div className="relative w-full sm:w-64">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                <input
                  type="text"
                  placeholder="Buscar condomínio..."
                  value={searchCondo}
                  onChange={(e) => setSearchCondo(e.target.value)}
                  className="w-full pl-9 pr-4 py-2 text-sm border border-gray-200 rounded-lg outline-hidden focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 transition-all"
                  aria-label="Buscar condomínio na lista de uso"
                  title="Buscar condomínio"
                />
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-gray-50/50 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                    <th className="p-4 border-b">Condomínio</th>
                    <th className="p-4 border-b text-center">Checklists Gerados</th>
                    <th className="p-4 border-b text-center">Adesão (Plano)</th>
                    <th className="p-4 border-b text-right">Último Uso</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {filteredCondos.length > 0 ? (
                    filteredCondos.map((condo) => (
                      <tr key={condo.nome} className="hover:bg-gray-50/50 transition-colors">
                        <td className="p-4">
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-full bg-indigo-50 flex items-center justify-center shrink-0">
                              <Building2 size={14} className="text-indigo-600" />
                            </div>
                            <span className="font-medium text-gray-900">{condo.nome}</span>
                          </div>
                        </td>
                        <td className="p-4 text-center font-medium text-gray-700">
                          {condo.count}
                        </td>
                        <td className="p-4 text-center">
                          {condo.plano === 'plus' ? (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium bg-amber-50 text-amber-700 border border-amber-200/50">
                              <Crown size={12} /> Plus
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium bg-gray-100 text-gray-600 border border-gray-200">
                              <ShieldCheck size={12} /> Free
                            </span>
                          )}
                        </td>
                        <td className="p-4 text-right text-sm text-gray-500">
                          {formatDate(condo.last_used)}
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={4} className="p-8 text-center text-gray-500">
                        Nenhum condomínio encontrado.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'templates' && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden shadow-sm animate-in fade-in duration-300">
          <div className="p-5 border-b border-gray-100 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <div>
              <h3 className="font-semibold text-gray-900">Templates Globais de Checklist</h3>
              <p className="text-sm text-gray-500">Modelos disponíveis para todos os condomínios do sistema.</p>
            </div>
            <button
              onClick={() => setIsModalOpen(true)}
              className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors"
              title="Adicionar Novo Template Global"
            >
              <Plus size={16} /> Novo Template Global
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-gray-50/50 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  <th className="p-4 border-b">Nome / Tipo</th>
                  <th className="p-4 border-b">Descrição</th>
                  <th className="p-4 border-b text-center">Data Criação</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {templates.length > 0 ? (
                  templates.map((tpl) => (
                    <tr key={tpl.id} className="hover:bg-gray-50/50 transition-colors">
                      <td className="p-4">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-lg bg-gray-50 border border-gray-100 flex items-center justify-center shrink-0 text-xl">
                            {tpl.icone_emoji}
                          </div>
                          <div>
                            <p className="font-semibold text-gray-900">{tpl.nome}</p>
                            <p className="text-xs text-gray-500 flex items-center gap-1 mt-0.5">
                              <Map size={12} /> {tpl.tipo_bem}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="p-4">
                        <p className="text-sm text-gray-600 line-clamp-2 max-w-md">
                          {tpl.descricao || '-'}
                        </p>
                      </td>
                      <td className="p-4 text-center text-sm text-gray-500">
                        {formatDate(tpl.created_at)}
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={3} className="p-8 text-center text-gray-500">
                      Nenhum template global configurado.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Modal Overlay para Novo Template */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-lg overflow-hidden flex flex-col max-h-[90vh]">
            <div className="p-5 border-b border-gray-100 flex justify-between items-center">
              <h3 className="font-semibold text-gray-900 text-lg">Criar Novo Template Global</h3>
              <button 
                onClick={() => setIsModalOpen(false)}
                className="text-gray-400 hover:text-gray-600 transition-colors p-1"
                aria-label="Fechar Modal"
              >
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleCreateTemplate} className="p-5 space-y-4 overflow-y-auto">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nome do Template *</label>
                <input
                  type="text"
                  required
                  placeholder="Ex: Vistoria Padrão de Entrada"
                  value={modalForm.nome}
                  onChange={(e) => setModalForm({...modalForm, nome: e.target.value})}
                  className="w-full px-4 py-2 border border-gray-200 rounded-lg outline-hidden focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Descrição</label>
                <textarea
                  placeholder="Informações adicionais para este template..."
                  value={modalForm.descricao}
                  onChange={(e) => setModalForm({...modalForm, descricao: e.target.value})}
                  className="w-full px-4 py-2 border border-gray-200 rounded-lg outline-hidden focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 resize-none h-24"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Tipo de Bem *</label>
                  <select
                    title="Tipo de Bem"
                    aria-label="Tipo de Bem"
                    value={modalForm.tipo_bem}
                    onChange={(e) => setModalForm({...modalForm, tipo_bem: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-200 rounded-lg outline-hidden bg-white focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
                  >
                    <option value="apartamento">Apartamento</option>
                    <option value="casa">Casa</option>
                    <option value="carro">Carro</option>
                    <option value="moto">Moto</option>
                    <option value="barco">Barco</option>
                    <option value="equipamento">Equipamento</option>
                    <option value="personalizado">Personalizado</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Ícone Emoji *</label>
                  <input
                    type="text"
                    required
                    placeholder="Ex: 🏠"
                    maxLength={2}
                    value={modalForm.icone_emoji}
                    onChange={(e) => setModalForm({...modalForm, icone_emoji: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-200 rounded-lg outline-hidden focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 text-center text-xl"
                  />
                </div>
              </div>

              <div className="pt-4 border-t border-gray-100 flex justify-end gap-3 mt-6">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 text-gray-700 hover:bg-gray-100 font-medium rounded-lg transition-colors"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2 min-w-[120px] disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  {isSubmitting ? (
                    <><Loader2 size={18} className="animate-spin" /> Salvando...</>
                  ) : (
                    'Salvar Template'
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
