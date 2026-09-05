'use client'

import { useState } from 'react'
import { Send, Megaphone, Edit, Clock, Check, X, ShieldAlert, Trash2, Users, Smartphone, Info } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

interface Condominio {
  id: string
  nome: string
}

interface Agendamento {
  id: string
  dia_semana: string
  horario: string
  assunto: string
  mensagem: string
  ativo: boolean
}

interface CondoStats {
  totalUsuarios: number
  totalDispositivos: number
}

interface Props {
  condominios: Condominio[]
  initialAgendamentos: Agendamento[]
  stats?: {
    global: CondoStats
    byCondo: Record<string, CondoStats>
  }
}

const ORDER: Record<string, number> = { seg: 0, ter: 1, qua: 2, qui: 3, sex: 4, sab: 5, dom: 6 }

const DIA_LABELS: Record<string, string> = {
  seg: 'Segunda-feira',
  ter: 'Terça-feira',
  qua: 'Quarta-feira',
  qui: 'Quinta-feira',
  sex: 'Sexta-feira',
  sab: 'Sábado',
  dom: 'Domingo'
}

export default function UniversalPushForm({ condominios, initialAgendamentos, stats }: Props) {
  // Manual push form state
  const [condominioId, setCondominioId] = useState('')
  const [titulo, setTitulo] = useState('')
  const [corpo, setCorpo] = useState('')
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  // Scheduled push state
  const [agendamentos, setAgendamentos] = useState<Agendamento[]>(initialAgendamentos)
  const [editingAgendamento, setEditingAgendamento] = useState<Agendamento | null>(null)
  const [editDiaSemana, setEditDiaSemana] = useState('seg')
  const [editHorario, setEditHorario] = useState('09:00')
  const [editAssunto, setEditAssunto] = useState('')
  const [editMensagem, setEditMensagem] = useState('')
  const [editAtivo, setEditAtivo] = useState(false)

  const selectedCondo = condominios.find(c => c.id === condominioId)
  const currentStats = condominioId
    ? (stats?.byCondo[condominioId] ?? { totalUsuarios: 0, totalDispositivos: 0 })
    : (stats?.global ?? { totalUsuarios: 0, totalDispositivos: 0 })

  const sortedAgendamentos = [...agendamentos].sort((a, b) => {
    const dayDiff = ORDER[a.dia_semana] - ORDER[b.dia_semana]
    if (dayDiff !== 0) return dayDiff
    return a.horario.localeCompare(b.horario)
  })

  async function handleToggleAtivo(ag: Agendamento) {
    const newAtivo = !ag.ativo
    setAgendamentos(prev => prev.map(item => item.id === ag.id ? { ...item, ativo: newAtivo } : item))

    const supabase = createClient()
    const { error } = await supabase
      .from('push_agendamentos_recorrentes')
      .update({ ativo: newAtivo })
      .eq('id', ag.id)

    if (error) {
      console.error(error)
      alert('Erro ao atualizar status.')
      setAgendamentos(prev => prev.map(item => item.id === ag.id ? { ...item, ativo: ag.ativo } : item))
    }
  }

  function handleOpenEdit(ag: Agendamento) {
    setEditingAgendamento(ag)
    setEditDiaSemana(ag.dia_semana)
    // Strip seconds if present in format HH:MM:SS
    setEditHorario(ag.horario.substring(0, 5))
    setEditAssunto(ag.assunto)
    setEditMensagem(ag.mensagem)
    setEditAtivo(ag.ativo)
  }

  function handleOpenCreate() {
    setEditingAgendamento({
      id: 'new',
      dia_semana: 'seg',
      horario: '09:00:00',
      assunto: '',
      mensagem: '',
      ativo: true
    })
    setEditDiaSemana('seg')
    setEditHorario('09:00')
    setEditAssunto('')
    setEditMensagem('')
    setEditAtivo(true)
  }

  async function handleDelete(id: string) {
    if (!confirm('Tem certeza que deseja excluir este agendamento?')) return

    const supabase = createClient()
    const { error } = await supabase
      .from('push_agendamentos_recorrentes')
      .delete()
      .eq('id', id)

    if (error) {
      console.error(error)
      alert('Erro ao excluir agendamento.')
    } else {
      setAgendamentos(prev => prev.filter(item => item.id !== id))
    }
  }

  async function handleSaveEdicao(e: React.FormEvent) {
    e.preventDefault()
    if (!editingAgendamento) return
    setLoading(true)

    try {
      const supabase = createClient()
      const timeFormatted = editHorario.length === 5 ? `${editHorario}:00` : editHorario

      if (editingAgendamento.id === 'new') {
        const { data, error } = await supabase
          .from('push_agendamentos_recorrentes')
          .insert({
            dia_semana: editDiaSemana,
            horario: timeFormatted,
            assunto: editAssunto.trim(),
            mensagem: editMensagem.trim(),
            ativo: editAtivo,
            condominio_id: null
          })
          .select()
          .single()

        if (error) throw error

        if (data) {
          setAgendamentos(prev => [...prev, data])
        }
      } else {
        const { error } = await supabase
          .from('push_agendamentos_recorrentes')
          .update({
            dia_semana: editDiaSemana,
            horario: timeFormatted,
            assunto: editAssunto.trim(),
            mensagem: editMensagem.trim(),
            ativo: editAtivo
          })
          .eq('id', editingAgendamento.id)

        if (error) throw error

        setAgendamentos(prev => prev.map(item => item.id === editingAgendamento.id ? {
          ...item,
          dia_semana: editDiaSemana,
          horario: timeFormatted,
          assunto: editAssunto.trim(),
          mensagem: editMensagem.trim(),
          ativo: editAtivo
        } : item))
      }
      setEditingAgendamento(null)
    } catch (err: any) {
      console.error(err)
      if (err.code === '23505') {
        alert('Já existe um agendamento para este mesmo dia da semana e horário.')
      } else {
        alert(`Erro ao salvar agendamento: ${err.message || err.code || JSON.stringify(err)}`)
      }
    } finally {
      setLoading(false)
    }
  }

  async function handleManualSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!titulo.trim() || !corpo.trim()) return

    setLoading(true)
    setResult(null)

    try {
      const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
      const supabase = createClient()
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token

      if (!token) {
        throw new Error('Usuário não autenticado. Faça login novamente.')
      }

      const body: Record<string, string> = {
        titulo: titulo.trim(),
        corpo: corpo.trim(),
      }
      if (condominioId) {
        body.condominio_id = condominioId
      }

      const res = await fetch(`${supabaseUrl}/functions/v1/universal-push-notify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify(body),
      })

      let data: Record<string, any>
      try {
        data = await res.json()
      } catch {
        throw new Error(`Resposta inválida do servidor. Verifique os logs da Edge Function.`)
      }

      if (!res.ok) {
        throw new Error((data?.error as string) ?? `Erro ao enviar push`)
      }

      if (data.total === 0) {
        setResult({
          type: 'error',
          message: `Nenhum dispositivo com Push ativo encontrado para o público selecionado (0 dispositivos).`,
        })
      } else if (data.sent === data.total) {
        setResult({
          type: 'success',
          message: `✅ Push enviado para ${data.sent} de ${data.total} dispositivos com Push ativo.`,
        })
      } else {
        const failed = data.total - data.sent
        setResult({
          type: 'success',
          message: `✅ Push enviado para ${data.sent} de ${data.total} dispositivos com Push ativo (${failed} ${failed === 1 ? 'falhou' : 'falharam'}).`,
        })
      }
      setTitulo('')
      setCorpo('')
    } catch (err) {
      setResult({
        type: 'error',
        message: `❌ ${err instanceof Error ? err.message : 'Erro desconhecido'}`,
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
      
      {/* COLUNA ESQUERDA: ENVIO IMEDIATO */}
      <div className="lg:col-span-5 bg-white rounded-2xl border border-gray-100 shadow-sm p-6 space-y-5">
        <div className="border-b border-gray-50 pb-3">
          <h2 className="text-lg font-bold text-gray-800">Envio Imediato</h2>
          <p className="text-xs text-gray-400">Dispare uma notificação de forma imediata.</p>
        </div>

        <form onSubmit={handleManualSubmit} className="space-y-5">
          {/* Info banner */}
          <div className="bg-orange-50 border border-orange-200 rounded-xl p-4 flex gap-3 items-start">
            <Megaphone size={18} className="text-orange-500 mt-0.5 shrink-0" />
            <p className="text-sm text-orange-700">
              {condominioId
                ? <>Este push será enviado para os dispositivos com Push ativo do <strong>{selectedCondo?.nome}</strong>.</>
                : <>Este push será enviado para os <strong>dispositivos com Push ativo</strong> em todos os condomínios.</>
              }
            </p>
          </div>

          {/* Result feedback */}
          {result && (
            <div className={`rounded-xl p-4 text-sm font-medium ${
              result.type === 'success'
                ? 'bg-green-50 border border-green-200 text-green-700'
                : 'bg-red-50 border border-red-200 text-red-700'
            }`}>
              {result.message}
            </div>
          )}

          {/* Condomínio selector */}
          <div>
            <label htmlFor="condominio-select" className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">
              Condomínio
            </label>
            <select
              id="condominio-select"
              value={condominioId}
              onChange={e => setCondominioId(e.target.value)}
              className="w-full px-4 py-3 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent transition appearance-none font-semibold text-gray-700"
              title="Selecionar condomínio"
            >
              <option value="">Todos os Condomínios</option>
              {condominios.map(c => (
                <option key={c.id} value={c.id}>{c.nome}</option>
              ))}
            </select>
          </div>

          {/* Card de Contexto: Usuários x Dispositivos */}
          <div className="bg-slate-50 border border-slate-200/80 rounded-xl p-4 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-700 uppercase tracking-wider">
                {condominioId ? selectedCondo?.nome : 'Todos os Condomínios'}
              </span>
              <span className="text-[11px] font-semibold px-2 py-0.5 bg-slate-200/70 text-slate-700 rounded-md">
                Público Estimado
              </span>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="bg-white rounded-lg p-3 border border-slate-100 shadow-sm">
                <div className="flex items-center gap-1.5 text-slate-500 text-xs font-medium mb-1">
                  <Users size={14} className="text-slate-400" />
                  <span>Usuários cadastrados</span>
                </div>
                <p className="text-xl font-bold text-slate-900">{currentStats.totalUsuarios}</p>
              </div>

              <div className="bg-white rounded-lg p-3 border border-orange-100 shadow-sm">
                <div className="flex items-center gap-1.5 text-orange-600 text-xs font-semibold mb-1">
                  <Smartphone size={14} className="text-[#FC5931]" />
                  <span>Push ativo</span>
                </div>
                <p className="text-xl font-bold text-[#FC5931]">{currentStats.totalDispositivos}</p>
              </div>
            </div>

            <div className="flex items-start gap-2 pt-1 text-[11px] text-slate-500 leading-tight">
              <Info size={14} className="text-slate-400 shrink-0 mt-0.5" />
              <span>
                Somente usuários com o aplicativo instalado, login realizado e Push ativo recebem esta notificação.
              </span>
            </div>
          </div>

          {/* Assunto */}
          <div>
            <label htmlFor="push-titulo" className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">
              Assunto do Push
            </label>
            <input
              id="push-titulo"
              type="text"
              value={titulo}
              onChange={e => setTitulo(e.target.value)}
              placeholder="Ex: Aviso Importante"
              maxLength={100}
              required
              className="w-full px-4 py-3 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent transition font-semibold text-gray-800"
            />
            <p className="text-xs text-gray-400 mt-1 text-right">{titulo.length}/100</p>
          </div>

          {/* Conteúdo */}
          <div>
            <label htmlFor="push-corpo" className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">
              Conteúdo do Push
            </label>
            <textarea
              id="push-corpo"
              value={corpo}
              onChange={e => setCorpo(e.target.value)}
              placeholder="Ex: Nova funcionalidade disponível no app..."
              maxLength={300}
              required
              rows={4}
              className="w-full px-4 py-3 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent transition resize-none text-gray-700"
            />
            <p className="text-xs text-gray-400 mt-1 text-right">{corpo.length}/300</p>
          </div>

          {/* Submit */}
          <button
            type="submit"
            disabled={loading || !titulo.trim() || !corpo.trim()}
            className="w-full flex items-center justify-center gap-2 px-6 py-3.5 bg-[#FC5931] text-white font-bold rounded-xl hover:bg-[#D42F1D] disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-md hover:shadow-lg"
          >
            {loading ? 'Enviando...' : 'Enviar Push Universal'}
          </button>
        </form>
      </div>

      {/* COLUNA DIREITA: CRONOGRAMA SEMANAL RECORRENTE */}
      <div className="lg:col-span-7 bg-white rounded-2xl border border-gray-100 shadow-sm p-6 space-y-5">
        <div className="border-b border-gray-50 pb-3 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-bold text-gray-800">Cronograma Semanal (Recorrente)</h2>
            <p className="text-xs text-gray-400">Envie avisos nos dias e horários selecionados toda semana.</p>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handleOpenCreate}
              className="flex items-center gap-1 px-3 py-1.5 bg-orange-50 hover:bg-orange-100 text-[#FC5931] text-xs font-bold rounded-lg transition-colors border border-orange-100 shrink-0"
            >
              + Novo Horário
            </button>
            <span className="text-[10px] font-bold px-2 py-1.5 bg-blue-50 text-blue-700 rounded-full border border-blue-100 flex items-center gap-1 shrink-0">
              <Clock size={10} /> Auto-cron (30m)
            </span>
          </div>
        </div>

        <div className="space-y-4">
          {sortedAgendamentos.length === 0 ? (
            <div className="text-center py-12 border-2 border-dashed border-gray-100 rounded-2xl p-6">
              <Clock className="mx-auto text-gray-300 mb-3" size={32} />
              <p className="text-sm font-semibold text-gray-600">Nenhum agendamento programado</p>
              <p className="text-xs text-gray-400 mt-1">Crie um horário para iniciar o disparo automático dos avisos semanais.</p>
              <button
                type="button"
                onClick={handleOpenCreate}
                className="mt-4 px-4 py-2 bg-[#FC5931] text-white text-xs font-bold rounded-xl hover:bg-[#D42F1D] transition-colors shadow-sm"
              >
                Criar Primeiro Horário
              </button>
            </div>
          ) : (
            sortedAgendamentos.map(ag => (
              <div 
                key={ag.id} 
                className={`border rounded-xl p-4 transition-all flex flex-col md:flex-row md:items-center justify-between gap-4 ${
                  ag.ativo 
                    ? 'border-orange-100 bg-orange-50/10 shadow-sm' 
                    : 'border-gray-100 bg-gray-50/20 opacity-80'
                }`}
              >
                <div className="space-y-1.5 flex-1 min-w-0">
                  <div className="flex items-center gap-3">
                    <span className="font-black text-gray-900 text-sm">{DIA_LABELS[ag.dia_semana]}</span>
                    {ag.ativo ? (
                      <span className="px-2 py-0.5 bg-orange-100 text-[#FC5931] rounded-md text-[10px] font-bold uppercase">Ativo</span>
                    ) : (
                      <span className="px-2 py-0.5 bg-gray-100 text-gray-400 rounded-md text-[10px] font-bold uppercase">Pausado</span>
                    )}
                  </div>
                  
                  <div className="space-y-1">
                    <div className="flex items-center gap-1.5 text-xs text-gray-500 font-semibold">
                      <Clock size={12} className={ag.ativo ? 'text-[#FC5931]' : 'text-gray-400'} />
                      Dispara às {ag.horario.substring(0, 5)}
                    </div>
                    <p className={`text-xs font-bold truncate ${ag.ativo ? 'text-gray-800' : 'text-gray-500'}`}>
                      Assunto: {ag.assunto}
                    </p>
                    <p className={`text-[11px] line-clamp-1 ${ag.ativo ? 'text-gray-500' : 'text-gray-400'}`}>
                      {ag.mensagem}
                    </p>
                  </div>
                </div>

                {/* Botões de Ação */}
                <div className="flex items-center gap-2 shrink-0">
                  {/* Switch Toggle */}
                  <button
                    onClick={() => handleToggleAtivo(ag)}
                    className={`w-11 h-6 rounded-full transition-all relative ${
                      ag.ativo ? 'bg-[#FC5931]' : 'bg-gray-200'
                    }`}
                    title={ag.ativo ? 'Desativar notificação' : 'Ativar notificação'}
                  >
                    <div className={`w-4 h-4 rounded-full bg-white absolute top-1 transition-all ${
                      ag.ativo ? 'right-1' : 'left-1'
                    }`} />
                  </button>

                  {/* Edit Button */}
                  <button
                    onClick={() => handleOpenEdit(ag)}
                    className="p-2 text-gray-400 hover:text-[#FC5931] hover:bg-gray-50 rounded-xl transition-all"
                    title="Configurar notificação"
                  >
                    <Edit size={16} />
                  </button>

                  {/* Delete Button */}
                  <button
                    onClick={() => handleDelete(ag.id)}
                    className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-xl transition-all"
                    title="Excluir agendamento"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* MODAL CONFIGURAR AGENDAMENTO DE DIA DA SEMANA */}
      {editingAgendamento && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-200">
            
            {/* Header */}
            <div className="flex items-center justify-between p-5 border-b border-gray-100 bg-gray-50/50">
              <div>
                <h3 className="font-bold text-lg text-gray-900">
                  {editingAgendamento.id === 'new' ? 'Novo Agendamento' : 'Configurar Push'}
                </h3>
                {editingAgendamento.id !== 'new' && (
                  <p className="text-xs text-gray-500 mt-0.5">
                    Dia: <span className="font-bold text-[#FC5931]">{DIA_LABELS[editingAgendamento.dia_semana]}</span>
                  </p>
                )}
              </div>
              <button 
                type="button"
                onClick={() => setEditingAgendamento(null)}
                className="text-gray-400 hover:bg-gray-100 p-2 rounded-lg transition-colors"
              >
                <X size={20} />
              </button>
            </div>

            {/* Form */}
            <form onSubmit={handleSaveEdicao}>
              <div className="p-6 space-y-5">
                
                {/* Ativo toggle */}
                <label className="flex items-center gap-3 p-3 border border-gray-100 rounded-xl cursor-pointer hover:bg-gray-50/30 transition">
                  <input 
                    type="checkbox" 
                    checked={editAtivo}
                    onChange={e => setEditAtivo(e.target.checked)}
                    className="w-5 h-5 text-[#FC5931] focus:ring-[#FC5931] rounded border-gray-300"
                  />
                  <div>
                    <p className="text-sm font-bold text-gray-800">Ativar para esta semana</p>
                    <p className="text-[11px] text-gray-400">Se desmarcado, a mensagem não será enviada.</p>
                  </div>
                </label>

                {/* Dia da Semana Select */}
                <div>
                  <label htmlFor="edit-dia-semana" className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">
                    Dia da Semana
                  </label>
                  <select 
                    id="edit-dia-semana"
                    value={editDiaSemana}
                    onChange={e => setEditDiaSemana(e.target.value)}
                    required
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent font-semibold text-gray-700"
                  >
                    {Object.entries(DIA_LABELS).map(([key, value]) => (
                      <option key={key} value={key}>{value}</option>
                    ))}
                  </select>
                </div>

                {/* Horário */}
                <div>
                  <label htmlFor="edit-horario" className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">
                    Horário de Disparo
                  </label>
                  <div className="relative">
                    <input 
                      id="edit-horario"
                      type="time" 
                      value={editHorario}
                      onChange={e => setEditHorario(e.target.value)}
                      required
                      className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent font-semibold text-gray-700"
                    />
                  </div>
                </div>

                {/* Assunto */}
                <div>
                  <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">
                    Assunto do Push
                  </label>
                  <input 
                    type="text" 
                    value={editAssunto}
                    onChange={e => setEditAssunto(e.target.value)}
                    placeholder="Ex: Bom dia, condomínio!"
                    required
                    maxLength={100}
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent font-semibold text-gray-800"
                  />
                </div>

                {/* Mensagem */}
                <div>
                  <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">
                    Mensagem do Push
                  </label>
                  <textarea 
                    value={editMensagem}
                    onChange={e => setEditMensagem(e.target.value)}
                    placeholder="Escreva a mensagem que os moradores receberão..."
                    required
                    rows={4}
                    maxLength={300}
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent text-gray-700 resize-none"
                  />
                  <p className="text-[10px] text-gray-400 text-right mt-1">{editMensagem.length}/300</p>
                </div>
              </div>

              {/* Footer */}
              <div className="p-5 border-t border-gray-100 bg-gray-50/50 flex justify-end gap-3">
                <button 
                  type="button"
                  onClick={() => setEditingAgendamento(null)}
                  className="px-4 py-2 font-medium text-gray-600 hover:bg-gray-200 rounded-xl transition-colors text-sm"
                >
                  Cancelar
                </button>
                <button 
                  type="submit"
                  disabled={loading || !editAssunto.trim() || !editMensagem.trim()}
                  className="px-6 py-2 font-bold bg-[#FC5931] hover:bg-[#D42F1D] text-white rounded-xl shadow-md hover:shadow-lg transition-all text-sm disabled:opacity-50"
                >
                  {loading ? 'Salvando...' : 'Confirmar Programação'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
