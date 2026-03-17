'use client'

import React, { useRef, useState } from 'react'
import Link from 'next/link'
import {
  Building2, Plus, Trash2, Pencil, Clock, ToggleLeft, ToggleRight, CheckCircle, XCircle
} from 'lucide-react'

const TIPOS_AGENDA = [
  'Salão de Festa','Churrasqueira','Sauna','Quadra de Tênis','Piscina',
  'Campo de Futebol','Academia','Sala de Jogos','Espaço Gourmet','Coworking',
  'Brinquedoteca','Lavanderia','Mudança','Obra','Outro',
]

const LOCAIS = [
  'Espaço comum','Área de lazer','Térreo','Cobertura','Bloco A','Bloco B','Bloco C','Outro',
]

interface Preco { valor: number; regra: string }

interface Area {
  id: string
  tipo_agenda: string
  local: string
  outro_local?: string
  tipo_reserva: 'por_dia' | 'por_hora'
  capacidade: number
  limite_acesso: number
  hrs_cancelar: number
  precos: Preco[]
  instrucao_uso?: string
  ativo: boolean
  aprovacao_automatica: boolean
}

interface Props {
  condominioId: string
  initialAreas: Area[]
}

const emptyForm = (): Omit<Area, 'id'> => ({
  tipo_agenda: '', local: '', outro_local: '',
  tipo_reserva: 'por_dia', capacidade: 0, limite_acesso: 0,
  hrs_cancelar: 0, precos: [{valor:0,regra:''},{valor:0,regra:''},{valor:0,regra:''}],
  instrucao_uso: '', ativo: true, aprovacao_automatica: false,
})

export default function AreasComunsClient({ condominioId, initialAreas }: Props) {
  const [areas, setAreas] = useState<Area[]>(initialAreas)
  const [form, setForm] = useState(emptyForm())
  const [editId, setEditId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [showForm, setShowForm] = useState(false)
  const formRef = useRef<HTMLDivElement>(null)

  function setField<K extends keyof typeof form>(k: K, v: typeof form[K]) {
    setForm(f => ({ ...f, [k]: v }))
  }

  function setPreco(idx: number, key: keyof Preco, val: string | number) {
    const updated = form.precos.map((p, i) => i === idx ? { ...p, [key]: val } : p)
    setField('precos', updated)
  }

  function startEdit(area: Area) {
    const { id, ...rest } = area
    const precos = [...(rest.precos ?? [])]
    while (precos.length < 3) precos.push({ valor: 0, regra: '' })
    setForm({ ...rest, precos })
    setEditId(id)
    setShowForm(true)
    // Scroll to the form below the list
    setTimeout(() => formRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 50)
  }

  function cancelEdit() {
    setForm(emptyForm())
    setEditId(null)
    setShowForm(false)
    setError(null)
  }

  async function handleSave() {
    if (!form.tipo_agenda) { setError('Escolha o Tipo de Agenda'); return }
    setSaving(true); setError(null)

    const payload = {
      ...form,
      outro_local: form.local === 'Outro' ? form.outro_local : null,
      precos: form.precos, // always save all 3 slots to preserve position (Faixa 1/2/3)
    }

    const method = editId ? 'PUT' : 'POST'
    const body = editId ? { id: editId, ...payload } : { ...payload, condominio_id: condominioId }

    const res = await fetch('/api/areas-comuns', {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    const data = await res.json()
    if (!res.ok) { setError(data.error ?? 'Erro ao salvar'); setSaving(false); return }

    if (editId) {
      setAreas(prev => prev.map(a => a.id === editId ? data : a))
    } else {
      setAreas(prev => [data, ...prev])
    }
    cancelEdit()
    setSaving(false)
  }

  async function handleDelete(id: string) {
    if (!confirm('Excluir esta área comum?')) return
    await fetch(`/api/areas-comuns?id=${id}`, { method: 'DELETE' })
    setAreas(prev => prev.filter(a => a.id !== id))
  }

  async function toggleField(area: Area, field: 'ativo' | 'aprovacao_automatica') {
    const updated = { id: area.id, [field]: !area[field] }
    const res = await fetch('/api/areas-comuns', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updated),
    })
    if (res.ok) {
      const data = await res.json()
      setAreas(prev => prev.map(a => a.id === area.id ? data : a))
    }
  }

  const labelLocal = (a: Area) => a.local === 'Outro' && a.outro_local ? a.outro_local : a.local

  return (
    <div className="max-w-5xl">
      {/* Header */}
      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Building2 size={22} className="text-[#FC5931]" />
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Áreas Comuns</h1>
            <p className="text-sm text-gray-500">Configure os espaços disponíveis para reserva.</p>
          </div>
        </div>
        <button
          onClick={() => setShowForm(f => !f)}
          className="flex items-center gap-2 bg-[#FC5931] text-white px-5 py-2.5 rounded-full text-sm font-semibold hover:bg-[#D42F1D] transition-colors"
        >
          <Plus size={16} />
          Nova Área
        </button>
      </div>


      {/* List */}
      {areas.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-2xl border border-gray-100">
          <Building2 size={40} className="mx-auto mb-3 text-gray-200" />
          <p className="text-gray-400 text-sm">Nenhuma área comum cadastrada ainda.</p>
          <p className="text-gray-300 text-xs mt-1">Clique em "Nova Área" para começar.</p>
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-[#FC5931] text-white">
                <th className="text-left px-4 py-3 font-semibold">Tipo Agenda</th>
                <th className="text-left px-4 py-3 font-semibold">Local</th>
                <th className="px-4 py-3 font-semibold">Reserva</th>
                <th className="px-4 py-3 font-semibold">Cap.</th>
                <th className="px-4 py-3 font-semibold">Hrs Cancel.</th>
                <th className="px-4 py-3 font-semibold">Limite</th>
                <th className="px-4 py-3 font-semibold text-center" colSpan={2}>Ações</th>
              </tr>
            </thead>
            <tbody>
              {areas.map((area, idx) => (
                <React.Fragment key={area.id}>
                  <tr key={area.id} className={`border-b border-gray-50 ${!area.ativo ? 'opacity-50' : ''} ${idx % 2 === 0 ? '' : 'bg-gray-50/50'}`}>
                    <td className="px-4 py-3 font-medium text-gray-900">{area.tipo_agenda}</td>
                    <td className="px-4 py-3 text-gray-600">{labelLocal(area)}</td>
                    <td className="px-4 py-3 text-center">
                      <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${area.tipo_reserva === 'por_hora' ? 'bg-blue-100 text-blue-700' : 'bg-orange-100 text-orange-700'}`}>
                        {area.tipo_reserva === 'por_hora' ? 'Por Hora' : 'Por Dia'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-center text-gray-600">{area.capacidade}</td>
                    <td className="px-4 py-3 text-center text-gray-600">{area.hrs_cancelar}h</td>
                    <td className="px-4 py-3 text-center text-gray-600">{area.limite_acesso}</td>
                    <td className="px-4 py-3" colSpan={2}></td>
                  </tr>
                  {/* Actions row */}
                  <tr key={`${area.id}-actions`} className={`border-b border-gray-100 ${!area.ativo ? 'opacity-50' : ''} ${idx % 2 === 0 ? '' : 'bg-gray-50/50'}`}>
                    <td colSpan={8} className="px-4 pb-3">
                      <div className="flex items-center gap-2 flex-wrap">
                        {/* Delete */}
                        <button
                          onClick={() => handleDelete(area.id)}
                          className="flex items-center gap-1 text-xs text-red-500 hover:text-red-700 px-3 py-1.5 rounded-lg hover:bg-red-50 transition-colors"
                        >
                          <Trash2 size={14} /> Apagar
                        </button>

                        {/* Horários (only por_hora) */}
                        {area.tipo_reserva === 'por_hora' && (
                          <Link
                            href={`/admin/areas-comuns/${area.id}/horarios`}
                            className="flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800 px-3 py-1.5 rounded-lg hover:bg-blue-50 transition-colors"
                          >
                            <Clock size={14} /> Horários
                          </Link>
                        )}

                        {/* Edit */}
                        <button
                          onClick={() => startEdit(area)}
                          className="flex items-center gap-1 text-xs text-gray-600 hover:text-gray-900 px-3 py-1.5 rounded-lg hover:bg-gray-100 transition-colors"
                        >
                          <Pencil size={14} /> Editar
                        </button>

                        {/* Desativar / Ativar */}
                        <button
                          onClick={() => toggleField(area, 'ativo')}
                          className={`flex items-center gap-1 text-xs px-3 py-1.5 rounded-lg transition-colors ${
                            area.ativo
                              ? 'text-green-700 hover:bg-green-50'
                              : 'text-gray-500 hover:bg-gray-100'
                          }`}
                        >
                          {area.ativo
                            ? <><ToggleRight size={16} className="text-green-600" /> Desativar</>
                            : <><ToggleLeft size={16} className="text-gray-400" /> Ativar</>}
                        </button>

                        {/* Aprovação automática */}
                        <button
                          onClick={() => toggleField(area, 'aprovacao_automatica')}
                          className={`flex items-center gap-1 text-xs px-3 py-1.5 rounded-lg transition-colors ${
                            area.aprovacao_automatica
                              ? 'text-green-700 hover:bg-green-50'
                              : 'text-gray-500 hover:bg-gray-100'
                          }`}
                        >
                          {area.aprovacao_automatica
                            ? <><CheckCircle size={14} className="text-green-600" /> Aprovação Auto</>
                            : <><XCircle size={14} className="text-gray-400" /> Aprovação Manual</>}
                        </button>
                      </div>
                    </td>
                  </tr>
                </React.Fragment>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Form — shown below the list when editing or adding */}
      {showForm && (
        <div ref={formRef} className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 mt-8 scroll-mt-4">
          <h2 className="text-base font-semibold text-gray-800 mb-4">
            {editId ? 'Editar Área Comum' : 'Cadastrar Área Comum'}
          </h2>

          {/* Tipo de reserva radio */}
          <div className="flex items-center gap-6 mb-5">
            {(['por_dia', 'por_hora'] as const).map(t => (
              <label key={t} className="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  checked={form.tipo_reserva === t}
                  onChange={() => setField('tipo_reserva', t)}
                  className="accent-[#FC5931]"
                />
                <span className="text-sm font-medium text-gray-700">
                  {t === 'por_dia' ? 'Por Dia (dia inteiro)' : 'Por Hora (com horários)'}
                </span>
              </label>
            ))}
          </div>

          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3 mb-4">
            <select
              value={form.tipo_agenda}
              onChange={e => setField('tipo_agenda', e.target.value)}
              aria-label="Tipo de Agenda"
              className="col-span-2 border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
            >
              <option value="">Tipo de Agenda</option>
              {TIPOS_AGENDA.map(t => <option key={t}>{t}</option>)}
            </select>

            <select
              value={form.local}
              onChange={e => setField('local', e.target.value)}
              aria-label="Local"
              className="border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 text-gray-700"
            >
              <option value="">Local</option>
              {LOCAIS.map(l => <option key={l}>{l}</option>)}
            </select>

            <input
              type="text"
              placeholder={form.local === 'Outro' ? 'Nome do local' : 'Outro local (opcional)'}
              value={form.outro_local ?? ''}
              onChange={e => setField('outro_local', e.target.value)}
              className="border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
            />

            <input
              type="number" min={1} placeholder="Capacidade (pessoas)"
              value={form.capacidade || ''}
              onChange={e => setField('capacidade', Number(e.target.value))}
              className="border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
            />

            <input
              type="number" min={1} placeholder="Limite de acesso"
              value={form.limite_acesso || ''}
              onChange={e => setField('limite_acesso', Number(e.target.value))}
              className="border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
            />
          </div>

          <div className="grid grid-cols-2 md:grid-cols-3 gap-3 mb-4">
            <input
              type="number" min={0} placeholder="Hrs para cancelar"
              value={form.hrs_cancelar || ''}
              onChange={e => setField('hrs_cancelar', Number(e.target.value))}
              className="border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
            />
          </div>

          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">
            Regras de Preço (deixe em 0 para gratuito)
          </p>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
            {[0, 1, 2].map(i => (
              <div key={i} className="border border-gray-100 rounded-xl p-3 space-y-2">
                <p className="text-xs font-semibold text-gray-400">Faixa {i + 1}</p>
                <div className="flex items-center gap-2">
                  <span className="text-xs text-gray-500">R$</span>
                  <input
                    type="number" min={0} step="any"
                    placeholder={`Valor ${i + 1}`}
                    value={form.precos[i]?.valor || ''}
                    onChange={e => setPreco(i, 'valor', Number(e.target.value))}
                    className="flex-1 border border-gray-200 rounded-lg px-2 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                  />
                </div>
                <textarea
                  rows={2}
                  placeholder={`Regra ${i + 1} (ex: até 2 reservas/ano)`}
                  value={form.precos[i]?.regra || ''}
                  onChange={e => setPreco(i, 'regra', e.target.value)}
                  className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-xs resize-none focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                />
              </div>
            ))}
          </div>

          <textarea
            rows={4}
            placeholder="Instrução de uso (ex: Não é permitido som alto...)"
            value={form.instrucao_uso || ''}
            onChange={e => setField('instrucao_uso', e.target.value)}
            className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm resize-none mb-4 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
          />

          {error && <p className="text-red-500 text-xs mb-3">{error}</p>}

          <div className="flex items-center gap-3">
            <button
              onClick={handleSave}
              disabled={saving}
              className="bg-[#FC5931] text-white px-6 py-2.5 rounded-full text-sm font-semibold hover:bg-[#D42F1D] transition-colors disabled:opacity-50"
            >
              {saving ? 'Salvando...' : editId ? 'Atualizar' : 'Salvar'}
            </button>
            <button
              onClick={cancelEdit}
              className="text-sm text-gray-500 hover:text-gray-700 transition-colors"
            >
              Cancelar
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
