'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import {
  Users, Gift, TrendingUp, Crown, Plus, Trash2, ToggleLeft, ToggleRight,
  Copy, Check, Ticket, Settings2, Save, Star, X
} from 'lucide-react'

type Plano = {
  plano: string
  ativo: boolean
  user_id: string
  created_at: string
  perfil: { nome_completo: string; bloco_txt: string; apto_txt: string } | null
}

type Cupom = {
  id: string
  codigo: string
  descricao: string | null
  tipo: string
  desconto_percentual: number
  plano_concedido: string | null
  duracao_dias: number
  ativo: boolean
  max_usos: number | null
  usos_count: number
  validade: string | null
  created_at: string
}

type CupomUso = {
  id: string
  cupom_id: string
  user_id: string
  plano_anterior: string
  plano_novo: string
  created_at: string
  dinglo_cupons: { codigo: string } | null
}

type PlanoConfig = {
  id: string
  slug: string
  nome: string
  descricao: string | null
  preco: number
  periodo: string
  funcionalidades: string[]
  destaque: boolean
  ativo: boolean
  ordem: number
}

export default function DingloAdminClient({
  totalUsuarios,
  planos,
  cupons: initialCupons,
  cupomUsos,
  planosConfig: initialPlanosConfig,
}: {
  totalUsuarios: number
  planos: Plano[]
  cupons: Cupom[]
  cupomUsos: CupomUso[]
  planosConfig: PlanoConfig[]
}) {
  const supabase = createClient()
  const router = useRouter()
  const [tab, setTab] = useState<'dashboard' | 'cupons' | 'usuarios' | 'planos'>('dashboard')
  const [cupons, setCupons] = useState<Cupom[]>(initialCupons)
  const [planosConfig, setPlanosConfig] = useState<PlanoConfig[]>(initialPlanosConfig)
  const [editingPlan, setEditingPlan] = useState<string | null>(null)
  const [planForm, setPlanForm] = useState<Partial<PlanoConfig>>({})
  const [savingPlan, setSavingPlan] = useState(false)
  const [showModal, setShowModal] = useState(false)
  const [saving, setSaving] = useState(false)
  const [copied, setCopied] = useState<string | null>(null)

  // New coupon form state
  const [form, setForm] = useState({
    codigo: '',
    descricao: '',
    tipo: 'plano_gratis',
    desconto_percentual: 100,
    plano_concedido: 'plus',
    duracao_dias: 30,
    max_usos: '',
  })

  // Metrics
  const planCounts = {
    basico: planos.filter(p => p.plano === 'basico').length,
    plus: planos.filter(p => p.plano === 'plus').length,
    plus_anual: planos.filter(p => p.plano === 'plus_anual').length,
  }

  const thisMonth = planos.filter(p => {
    const d = new Date(p.created_at)
    const now = new Date()
    return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()
  }).length

  async function handleCreateCoupon(e: React.FormEvent) {
    e.preventDefault()
    setSaving(true)
    try {
      const { data, error } = await supabase.from('dinglo_cupons').insert({
        codigo: form.codigo.toUpperCase().trim(),
        descricao: form.descricao || null,
        tipo: form.tipo,
        desconto_percentual: form.tipo === 'desconto_percentual' ? form.desconto_percentual : 100,
        plano_concedido: form.tipo === 'plano_gratis' ? form.plano_concedido : null,
        duracao_dias: form.duracao_dias,
        max_usos: form.max_usos ? parseInt(form.max_usos) : null,
      }).select().single()

      if (error) throw error
      setCupons([data, ...cupons])
      setShowModal(false)
      setForm({ codigo: '', descricao: '', tipo: 'plano_gratis', desconto_percentual: 100, plano_concedido: 'plus', duracao_dias: 30, max_usos: '' })
    } catch (err) {
      alert('Erro ao criar cupom: ' + (err as Error).message)
    }
    setSaving(false)
  }

  async function toggleCoupon(id: string, ativo: boolean) {
    await supabase.from('dinglo_cupons').update({ ativo: !ativo }).eq('id', id)
    setCupons(cupons.map(c => c.id === id ? { ...c, ativo: !ativo } : c))
  }

  async function deleteCoupon(id: string) {
    if (!confirm('Excluir este cupom?')) return
    await supabase.from('dinglo_cupons').delete().eq('id', id)
    setCupons(cupons.filter(c => c.id !== id))
  }

  async function changeUserPlan(userId: string, newPlan: string) {
    await supabase.from('dinglo_plano_usuario').update({ plano: newPlan }).eq('user_id', userId)
    router.refresh()
  }

  function copyCode(code: string) {
    navigator.clipboard.writeText(code)
    setCopied(code)
    setTimeout(() => setCopied(null), 2000)
  }

  const planLabel = (p: string) => {
    switch (p) {
      case 'basico': return 'Básico'
      case 'plus': return 'Plus'
      case 'plus_anual': return 'Plus+'
      default: return p
    }
  }

  const planColor = (p: string) => {
    switch (p) {
      case 'basico': return 'bg-gray-100 text-gray-700'
      case 'plus': return 'bg-blue-100 text-blue-700'
      case 'plus_anual': return 'bg-purple-100 text-purple-700'
      default: return 'bg-gray-100 text-gray-600'
    }
  }

  return (
    <div className="p-6 max-w-6xl mx-auto">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          💰 Meu Bolso — Admin
        </h1>
        <p className="text-gray-500 text-sm mt-1">Painel de gestão exclusivo do proprietário</p>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-6 bg-gray-100 p-1 rounded-xl w-fit">
        {[
          { key: 'dashboard', label: 'Dashboard', icon: <TrendingUp size={16} /> },
          { key: 'cupons', label: 'Cupons', icon: <Gift size={16} /> },
          { key: 'usuarios', label: 'Usuários', icon: <Users size={16} /> },
          { key: 'planos', label: 'Planos', icon: <Settings2 size={16} /> },
        ].map(t => (
          <button
            key={t.key}
            onClick={() => setTab(t.key as typeof tab)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all ${
              tab === t.key
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {/* Dashboard Tab */}
      {tab === 'dashboard' && (
        <div className="space-y-6">
          {/* Metric Cards */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <MetricCard icon={<Users />} label="Total Usuários" value={totalUsuarios} color="blue" />
            <MetricCard icon={<TrendingUp />} label="Novos este Mês" value={thisMonth} color="green" />
            <MetricCard icon={<Crown />} label="Plano Plus" value={planCounts.plus} color="purple" />
            <MetricCard icon={<Ticket />} label="Cupons Ativos" value={cupons.filter(c => c.ativo).length} color="orange" />
          </div>

          {/* Plan Distribution */}
          <div className="bg-white rounded-2xl border border-gray-100 p-6 shadow-sm">
            <h3 className="font-semibold text-gray-900 mb-4">Distribuição de Planos</h3>
            <div className="space-y-3">
              {[
                { label: 'Básico (Grátis)', count: planCounts.basico, color: 'bg-gray-400' },
                { label: 'Plus (R$15/mês)', count: planCounts.plus, color: 'bg-blue-500' },
                { label: 'Plus+ (R$120/ano)', count: planCounts.plus_anual, color: 'bg-purple-500' },
              ].map(plan => (
                <div key={plan.label} className="flex items-center gap-3">
                  <div className={`w-3 h-3 rounded-full ${plan.color}`} />
                  <span className="text-sm text-gray-700 w-40">{plan.label}</span>
                  <div className="flex-1 bg-gray-100 rounded-full h-6 overflow-hidden">
                    <div
                      className={`h-full ${plan.color} rounded-full flex items-center justify-end pr-2 transition-all duration-500`}
                      style={{ width: totalUsuarios > 0 ? `${Math.max((plan.count / totalUsuarios) * 100, 8)}%` : '8%' }}
                    >
                      <span className="text-xs font-bold text-white">{plan.count}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Recent Coupon Usage */}
          <div className="bg-white rounded-2xl border border-gray-100 p-6 shadow-sm">
            <h3 className="font-semibold text-gray-900 mb-4">Últimos Usos de Cupons</h3>
            {cupomUsos.length === 0 ? (
              <p className="text-gray-400 text-sm">Nenhum cupom utilizado ainda.</p>
            ) : (
              <div className="divide-y">
                {cupomUsos.slice(0, 10).map(u => (
                  <div key={u.id} className="py-3 flex items-center justify-between">
                    <div>
                      <span className="text-sm font-medium">{u.dinglo_cupons?.codigo ?? '—'}</span>
                      <span className="text-xs text-gray-400 ml-2">
                        {planLabel(u.plano_anterior)} → {planLabel(u.plano_novo)}
                      </span>
                    </div>
                    <span className="text-xs text-gray-400">
                      {new Date(u.created_at).toLocaleDateString('pt-BR')}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Cupons Tab */}
      {tab === 'cupons' && (
        <div className="space-y-4">
          <div className="flex justify-between items-center">
            <h3 className="font-semibold text-gray-900">Cupons de Desconto</h3>
            <button
              onClick={() => setShowModal(true)}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-xl text-sm font-medium hover:bg-blue-700 transition-colors"
            >
              <Plus size={16} /> Criar Cupom
            </button>
          </div>

          {cupons.length === 0 ? (
            <div className="bg-white rounded-2xl border border-gray-100 p-12 text-center">
              <Gift size={48} className="mx-auto text-gray-300 mb-4" />
              <p className="text-gray-500">Nenhum cupom criado</p>
              <p className="text-gray-400 text-sm mt-1">Crie cupons para dar desconto ou acesso grátis aos planos</p>
            </div>
          ) : (
            <div className="grid gap-3">
              {cupons.map(c => (
                <div key={c.id} className={`bg-white rounded-2xl border p-5 shadow-sm ${!c.ativo ? 'opacity-60' : ''}`}>
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <code className="bg-blue-50 text-blue-700 px-3 py-1 rounded-lg font-bold text-sm tracking-wider">
                          {c.codigo}
                        </code>
                        <button onClick={() => copyCode(c.codigo)} className="text-gray-400 hover:text-gray-600">
                          {copied === c.codigo ? <Check size={14} className="text-green-500" /> : <Copy size={14} />}
                        </button>
                        <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${c.ativo ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                          {c.ativo ? 'Ativo' : 'Inativo'}
                        </span>
                      </div>
                      {c.descricao && <p className="text-sm text-gray-500 mb-2">{c.descricao}</p>}
                      <div className="flex gap-4 text-xs text-gray-400">
                        <span>
                          {c.tipo === 'plano_gratis'
                            ? `Acesso grátis: ${planLabel(c.plano_concedido ?? 'plus')}`
                            : `${c.desconto_percentual}% de desconto`}
                        </span>
                        <span>Duração: {c.duracao_dias} dias</span>
                        <span>Usos: {c.usos_count}{c.max_usos ? `/${c.max_usos}` : '/∞'}</span>
                        {c.validade && <span>Valido até: {new Date(c.validade).toLocaleDateString('pt-BR')}</span>}
                      </div>
                    </div>
                    <div className="flex gap-2 ml-4">
                      <button
                        onClick={() => toggleCoupon(c.id, c.ativo)}
                        className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
                        title={c.ativo ? 'Desativar' : 'Ativar'}
                      >
                        {c.ativo ? <ToggleRight size={20} className="text-green-500" /> : <ToggleLeft size={20} className="text-gray-400" />}
                      </button>
                      <button
                        onClick={() => deleteCoupon(c.id)}
                        className="p-2 rounded-lg hover:bg-red-50 text-red-400 hover:text-red-600 transition-colors"
                      >
                        <Trash2 size={18} />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Usuarios Tab */}
      {tab === 'usuarios' && (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50">
              <tr>
                <th className="text-left px-5 py-3 font-medium text-gray-500">Nome</th>
                <th className="text-left px-5 py-3 font-medium text-gray-500">Unidade</th>
                <th className="text-left px-5 py-3 font-medium text-gray-500">Plano</th>
                <th className="text-left px-5 py-3 font-medium text-gray-500">Desde</th>
                <th className="text-left px-5 py-3 font-medium text-gray-500">Ação</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {planos.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-5 py-12 text-center text-gray-400">
                    Nenhum usuário Meu Bolso ainda
                  </td>
                </tr>
              ) : (
                planos.map(p => (
                  <tr key={p.user_id} className="hover:bg-gray-50/50">
                    <td className="px-5 py-3 font-medium text-gray-900">
                      {p.perfil?.nome_completo ?? 'Desconhecido'}
                    </td>
                    <td className="px-5 py-3 text-gray-500">
                      {p.perfil ? `${p.perfil.bloco_txt ?? ''} / ${p.perfil.apto_txt ?? ''}` : '—'}
                    </td>
                    <td className="px-5 py-3">
                      <span className={`px-2.5 py-1 rounded-full text-xs font-bold ${planColor(p.plano)}`}>
                        {planLabel(p.plano)}
                      </span>
                    </td>
                    <td className="px-5 py-3 text-gray-400">
                      {new Date(p.created_at).toLocaleDateString('pt-BR')}
                    </td>
                    <td className="px-5 py-3">
                      <select
                        value={p.plano}
                        onChange={(e) => changeUserPlan(p.user_id, e.target.value)}
                        className="text-xs border border-gray-200 rounded-lg px-2 py-1.5 bg-white"
                      >
                        <option value="basico">Básico</option>
                        <option value="plus">Plus</option>
                        <option value="plus_anual">Plus+</option>
                      </select>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Planos Tab */}
      {tab === 'planos' && (
        <div className="space-y-4">
          <div className="flex justify-between items-center">
            <h3 className="font-semibold text-gray-900">Configuração dos Planos</h3>
            <p className="text-xs text-gray-400">Edite preços, nomes e funcionalidades</p>
          </div>

          <div className="grid gap-4">
            {planosConfig.map(plan => {
              const isEditing = editingPlan === plan.id
              return (
                <div key={plan.id} className={`bg-white rounded-2xl border-2 p-6 shadow-sm transition-all ${
                  plan.destaque ? 'border-blue-300' : 'border-gray-100'
                } ${!plan.ativo ? 'opacity-60' : ''}`}>

                  {!isEditing ? (
                    /* View Mode */
                    <div>
                      <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-3">
                          <h4 className="text-lg font-bold text-gray-900">{plan.nome}</h4>
                          {plan.destaque && (
                            <span className="flex items-center gap-1 text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full font-medium">
                              <Star size={10} /> Popular
                            </span>
                          )}
                          <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${plan.ativo ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                            {plan.ativo ? 'Ativo' : 'Inativo'}
                          </span>
                        </div>
                        <button
                          onClick={() => { setEditingPlan(plan.id); setPlanForm({ ...plan }) }}
                          className="flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800 font-medium"
                          title="Editar plano"
                        >
                          <Settings2 size={14} /> Editar
                        </button>
                      </div>
                      <p className="text-sm text-gray-500 mb-3">{plan.descricao}</p>
                      <p className="text-2xl font-bold text-gray-900 mb-4">
                        {plan.preco === 0 ? 'Grátis' : `R$ ${plan.preco.toFixed(2).replace('.', ',')}/${plan.periodo === 'anual' ? 'ano' : 'mês'}`}
                      </p>
                      <div className="space-y-1.5">
                        {(plan.funcionalidades ?? []).map((f, i) => (
                          <div key={i} className="flex items-center gap-2 text-sm text-gray-600">
                            <Check size={14} className="text-green-500 flex-shrink-0" />
                            {f}
                          </div>
                        ))}
                      </div>
                    </div>
                  ) : (
                    /* Edit Mode */
                    <div className="space-y-4">
                      <div className="grid grid-cols-2 gap-3">
                        <div>
                          <label className="text-xs font-medium text-gray-500 uppercase">Nome</label>
                          <input
                            type="text"
                            value={planForm.nome ?? ''}
                            onChange={e => setPlanForm({ ...planForm, nome: e.target.value })}
                            className="w-full mt-1 px-3 py-2 border rounded-lg text-sm"
                            title="Nome do plano"
                          />
                        </div>
                        <div>
                          <label className="text-xs font-medium text-gray-500 uppercase">Preço (R$)</label>
                          <input
                            type="number"
                            step="0.01"
                            min={0}
                            value={planForm.preco ?? 0}
                            onChange={e => setPlanForm({ ...planForm, preco: parseFloat(e.target.value) || 0 })}
                            className="w-full mt-1 px-3 py-2 border rounded-lg text-sm"
                            title="Preço do plano"
                          />
                        </div>
                      </div>
                      <div>
                        <label className="text-xs font-medium text-gray-500 uppercase">Descrição</label>
                        <input
                          type="text"
                          value={planForm.descricao ?? ''}
                          onChange={e => setPlanForm({ ...planForm, descricao: e.target.value })}
                          className="w-full mt-1 px-3 py-2 border rounded-lg text-sm"
                          title="Descrição do plano"
                        />
                      </div>
                      <div className="grid grid-cols-2 gap-3">
                        <div>
                          <label className="text-xs font-medium text-gray-500 uppercase">Período</label>
                          <select
                            value={planForm.periodo ?? 'mensal'}
                            onChange={e => setPlanForm({ ...planForm, periodo: e.target.value })}
                            className="w-full mt-1 px-3 py-2 border rounded-lg text-sm"
                            title="Período de cobrança"
                          >
                            <option value="gratis">Grátis</option>
                            <option value="mensal">Mensal</option>
                            <option value="anual">Anual</option>
                          </select>
                        </div>
                        <div className="flex items-end gap-4 pb-1">
                          <label className="flex items-center gap-2 text-sm">
                            <input
                              type="checkbox"
                              checked={planForm.destaque ?? false}
                              onChange={e => setPlanForm({ ...planForm, destaque: e.target.checked })}
                              className="rounded"
                            />
                            Destaque
                          </label>
                          <label className="flex items-center gap-2 text-sm">
                            <input
                              type="checkbox"
                              checked={planForm.ativo ?? true}
                              onChange={e => setPlanForm({ ...planForm, ativo: e.target.checked })}
                              className="rounded"
                            />
                            Ativo
                          </label>
                        </div>
                      </div>
                      <div>
                        <label className="text-xs font-medium text-gray-500 uppercase">Funcionalidades (uma por linha)</label>
                        <textarea
                          value={(planForm.funcionalidades ?? []).join('\n')}
                          onChange={e => setPlanForm({ ...planForm, funcionalidades: e.target.value.split('\n') })}
                          rows={5}
                          className="w-full mt-1 px-3 py-2 border rounded-lg text-sm"
                          title="Lista de funcionalidades"
                        />
                      </div>
                      <div className="flex gap-3">
                        <button
                          onClick={() => setEditingPlan(null)}
                          className="flex items-center gap-1 px-4 py-2 border rounded-xl text-sm font-medium text-gray-600 hover:bg-gray-50"
                        >
                          <X size={14} /> Cancelar
                        </button>
                        <button
                          onClick={async () => {
                            setSavingPlan(true)
                            const features = (planForm.funcionalidades ?? []).filter(f => f.trim())
                            const { error } = await supabase.from('dinglo_planos_config').update({
                              nome: planForm.nome,
                              descricao: planForm.descricao,
                              preco: planForm.preco,
                              periodo: planForm.periodo,
                              funcionalidades: features,
                              destaque: planForm.destaque,
                              ativo: planForm.ativo,
                              updated_at: new Date().toISOString(),
                            }).eq('id', plan.id)
                            if (error) {
                              alert('Erro: ' + error.message)
                            } else {
                              setPlanosConfig(planosConfig.map(p => p.id === plan.id ? { ...p, ...planForm, funcionalidades: features } as PlanoConfig : p))
                              setEditingPlan(null)
                            }
                            setSavingPlan(false)
                          }}
                          disabled={savingPlan}
                          className="flex items-center gap-1 px-4 py-2 bg-blue-600 text-white rounded-xl text-sm font-medium hover:bg-blue-700 disabled:opacity-50"
                        >
                          <Save size={14} /> {savingPlan ? 'Salvando...' : 'Salvar'}
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Create Coupon Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl">
            <div className="p-6 border-b border-gray-100">
              <h3 className="text-lg font-bold text-gray-900">Criar Cupom</h3>
              <p className="text-sm text-gray-500 mt-1">Dê desconto ou acesso grátis aos planos premium</p>
            </div>
            <form onSubmit={handleCreateCoupon} className="p-6 space-y-4">
              <div>
                <label className="text-xs font-medium text-gray-500 uppercase tracking-wider">Código do Cupom</label>
                <input
                  type="text"
                  value={form.codigo}
                  onChange={e => setForm({ ...form, codigo: e.target.value })}
                  placeholder="MEUBOLSO50"
                  className="w-full mt-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm uppercase tracking-wider font-mono focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                  maxLength={30}
                />
              </div>

              <div>
                <label className="text-xs font-medium text-gray-500 uppercase tracking-wider">Descrição (opcional)</label>
                <input
                  type="text"
                  value={form.descricao}
                  onChange={e => setForm({ ...form, descricao: e.target.value })}
                  placeholder="Desconto para early adopters"
                  className="w-full mt-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="text-xs font-medium text-gray-500 uppercase tracking-wider">Tipo</label>
                <select
                  value={form.tipo}
                  onChange={e => setForm({ ...form, tipo: e.target.value })}
                  className="w-full mt-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="plano_gratis">Acesso grátis a um plano</option>
                  <option value="desconto_percentual">Desconto percentual</option>
                </select>
              </div>

              {form.tipo === 'plano_gratis' && (
                <div>
                  <label className="text-xs font-medium text-gray-500 uppercase tracking-wider">Plano Concedido</label>
                  <select
                    value={form.plano_concedido}
                    onChange={e => setForm({ ...form, plano_concedido: e.target.value })}
                    className="w-full mt-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="plus">Plus (mensal)</option>
                    <option value="plus_anual">Plus+ (anual)</option>
                  </select>
                </div>
              )}

              {form.tipo === 'desconto_percentual' && (
                <div>
                  <label className="text-xs font-medium text-gray-500 uppercase tracking-wider">Desconto (%)</label>
                  <input
                    type="number"
                    min={1}
                    max={100}
                    value={form.desconto_percentual}
                    onChange={e => setForm({ ...form, desconto_percentual: parseInt(e.target.value) || 0 })}
                    className="w-full mt-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
              )}

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-gray-500 uppercase tracking-wider">Duração (dias)</label>
                  <input
                    type="number"
                    min={1}
                    value={form.duracao_dias}
                    onChange={e => setForm({ ...form, duracao_dias: parseInt(e.target.value) || 30 })}
                    className="w-full mt-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-gray-500 uppercase tracking-wider">Máx. Usos</label>
                  <input
                    type="number"
                    min={1}
                    value={form.max_usos}
                    onChange={e => setForm({ ...form, max_usos: e.target.value })}
                    placeholder="Ilimitado"
                    className="w-full mt-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
              </div>

              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="flex-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  disabled={saving || !form.codigo}
                  className="flex-1 px-4 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-medium hover:bg-blue-700 transition-colors disabled:opacity-50"
                >
                  {saving ? 'Salvando...' : 'Criar Cupom'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

function MetricCard({ icon, label, value, color }: { icon: React.ReactNode; label: string; value: number; color: string }) {
  const colors: Record<string, string> = {
    blue: 'bg-blue-50 text-blue-600',
    green: 'bg-green-50 text-green-600',
    purple: 'bg-purple-50 text-purple-600',
    orange: 'bg-orange-50 text-orange-600',
  }
  return (
    <div className="bg-white rounded-2xl border border-gray-100 p-5 shadow-sm">
      <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-3 ${colors[color]}`}>
        {icon}
      </div>
      <p className="text-2xl font-bold text-gray-900">{value}</p>
      <p className="text-xs text-gray-400 mt-1">{label}</p>
    </div>
  )
}
