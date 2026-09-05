'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  X, Star, Plus, Check, Loader2, Sparkles, AlertCircle, ToggleLeft, ToggleRight
} from 'lucide-react'
import { DocumentoTipo, DocumentoTipoPrioridade, Documento } from './types'
import { renderTipoIcon } from './tipo-selector'

const ICONES_DISPONIVEIS = [
  { name: 'file-text', label: 'Documento' },
  { name: 'book', label: 'Livro / Manual' },
  { name: 'scroll', label: 'Regimento / Termo' },
  { name: 'users', label: 'Assembleia / Pessoas' },
  { name: 'shield-check', label: 'Segurança / Seguro' },
  { name: 'flame', label: 'Bombeiros / AVCB' },
  { name: 'clipboard-check', label: 'Laudo / Inspeção' },
  { name: 'sparkles', label: 'Limpeza / Dedetização' },
  { name: 'award', label: 'Licença / Alvará' },
  { name: 'compass', label: 'Plantas / Obras' },
  { name: 'calculator', label: 'Orçamento' },
  { name: 'file-signature', label: 'Contrato' },
  { name: 'dollar-sign', label: 'Financeiro' },
  { name: 'receipt', label: 'Nota Fiscal' },
]

interface GerenciarTiposModalProps {
  condoId: string
  tipos: DocumentoTipo[]
  prioridades: DocumentoTipoPrioridade[]
  documentos: Documento[]
  categorias: string[]
  onClose: () => void
  onTiposUpdated: (newTipos: DocumentoTipo[]) => void
  onPrioridadesUpdated: (newPrioridades: DocumentoTipoPrioridade[]) => void
}

export default function GerenciarTiposModal({
  condoId,
  tipos,
  prioridades,
  documentos,
  categorias,
  onClose,
  onTiposUpdated,
  onPrioridadesUpdated,
}: GerenciarTiposModalProps) {
  const [tab, setTab] = useState<'prioridades' | 'custom'>('prioridades')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  // Form de novo tipo personalizado
  const [novoNome, setNovoNome] = useState('')
  const [novaDescricao, setNovaDescricao] = useState('')
  const [novaCategoria, setNovaCategoria] = useState(categorias[0] || 'Outros')
  const [novoIcone, setNovoIcone] = useState('file-text')
  const [novoTemValidade, setNovoTemValidade] = useState(false)
  const [novoRecorrente, setNovoRecorrente] = useState(false)

  const supabase = createClient()

  // 1. Toggle Prioritário
  async function togglePrioritario(tipoId: string) {
    setError('')
    setSuccess('')
    const existing = prioridades.find(p => p.tipo_id === tipoId)

    if (existing) {
      // Remove prioridade
      const { error: err } = await supabase
        .from('documento_tipo_prioridades')
        .delete()
        .eq('id', existing.id)

      if (err) {
        setError(`Erro ao remover prioridade: ${err.message}`)
        return
      }
      onPrioridadesUpdated(prioridades.filter(p => p.id !== existing.id))
      setSuccess('Prioridade atualizada com sucesso.')
    } else {
      // Adiciona prioridade
      const nextOrdem = prioridades.length + 1
      const { data, error: err } = await supabase
        .from('documento_tipo_prioridades')
        .insert({
          condominio_id: condoId,
          tipo_id: tipoId,
          is_prioritario: true,
          ordem: nextOrdem,
        })
        .select()
        .single()

      if (err) {
        setError(`Erro ao adicionar prioridade: ${err.message}`)
        return
      }
      if (data) {
        onPrioridadesUpdated([...prioridades, data as DocumentoTipoPrioridade])
        setSuccess('Prioridade adicionada com sucesso.')
      }
    }
  }

  // 2. Toggle Ativo em Tipo Personalizado
  async function toggleAtivoTipo(tipo: DocumentoTipo) {
    if (tipo.is_system) return
    setError('')
    setSuccess('')
    const nextAtivo = !tipo.ativo

    const { data, error: err } = await supabase
      .from('documento_tipos')
      .update({ ativo: nextAtivo, updated_at: new Date().toISOString() })
      .eq('id', tipo.id)
      .select()
      .single()

    if (err) {
      setError(`Erro ao alterar status: ${err.message}`)
      return
    }

    if (data) {
      onTiposUpdated(tipos.map(t => t.id === tipo.id ? (data as DocumentoTipo) : t))
      setSuccess(`Tipo "${tipo.nome}" ${nextAtivo ? 'ativado' : 'desativado'} com sucesso.`)
    }
  }

  // 3. Criar Novo Tipo Personalizado
  async function handleCriarTipo() {
    if (!novoNome.trim()) {
      setError('Informe o nome do tipo de documento.')
      return
    }
    if (!novaCategoria.trim()) {
      setError('Selecione ou informe uma categoria padrão.')
      return
    }

    setSaving(true)
    setError('')
    setSuccess('')

    const payload = {
      condominio_id: condoId,
      nome: novoNome.trim(),
      descricao: novaDescricao.trim() || null,
      categoria_padrao: novaCategoria.trim(),
      icone: novoIcone,
      is_system: false,
      ativo: true,
      ordem: 100,
      recorrente: novoRecorrente,
      normalmente_tem_validade: novoTemValidade,
      permite_lembrete: true,
      permite_exibir_moradores: true,
      permite_notificacao: true,
    }

    const { data, error: err } = await supabase
      .from('documento_tipos')
      .insert(payload)
      .select()
      .single()

    setSaving(false)

    if (err) {
      if (err.message.includes('uq_documento_tipos_condo_nome')) {
        setError(`Já existe um tipo com o nome "${novoNome.trim()}" cadastrado neste condomínio.`)
      } else {
        setError(`Erro ao criar tipo: ${err.message}`)
      }
      return
    }

    if (data) {
      onTiposUpdated([...tipos, data as DocumentoTipo])
      setSuccess(`Tipo "${novoNome.trim()}" criado com sucesso!`)
      setNovoNome('')
      setNovaDescricao('')
    }
  }

  // 4. Excluir Tipo Personalizado (com validação anti-delete de tipo em uso)
  async function handleExcluirTipo(tipo: DocumentoTipo) {
    if (tipo.is_system) return
    const emUso = documentos.some(d => d.tipo_id === tipo.id)
    if (emUso) {
      setError(`O tipo "${tipo.nome}" está em uso por documentos existentes. Por segurança, você pode desativá-lo para que não apareça em novos cadastros.`)
      return
    }

    if (!confirm(`Deseja realmente excluir o tipo personalizado "${tipo.nome}"?`)) return

    const { error: err } = await supabase
      .from('documento_tipos')
      .delete()
      .eq('id', tipo.id)

    if (err) {
      setError(`Erro ao excluir tipo: ${err.message}`)
      return
    }

    onTiposUpdated(tipos.filter(t => t.id !== tipo.id))
    onPrioridadesUpdated(prioridades.filter(p => p.tipo_id !== tipo.id))
    setSuccess(`Tipo "${tipo.nome}" excluído com sucesso.`)
  }

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div className="flex items-center gap-2">
            <Sparkles size={20} className="text-[#FC5931]" />
            <h2 className="text-lg font-bold text-gray-900">Gerenciar Tipos de Documentos</h2>
          </div>
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-gray-100 text-gray-400">
            <X size={18} />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-gray-100 px-6 gap-6 bg-gray-50/50">
          <button
            onClick={() => { setTab('prioridades'); setError(''); setSuccess('') }}
            className={`py-3 text-sm font-semibold border-b-2 transition flex items-center gap-1.5 ${
              tab === 'prioridades'
                ? 'border-[#FC5931] text-[#FC5931]'
                : 'border-transparent text-gray-500 hover:text-gray-800'
            }`}
          >
            <Star size={15} className={tab === 'prioridades' ? 'fill-[#FC5931]' : ''} />
            Tipos Prioritários do Condomínio ({prioridades.filter(p => p.is_prioritario).length})
          </button>
          <button
            onClick={() => { setTab('custom'); setError(''); setSuccess('') }}
            className={`py-3 text-sm font-semibold border-b-2 transition flex items-center gap-1.5 ${
              tab === 'custom'
                ? 'border-[#FC5931] text-[#FC5931]'
                : 'border-transparent text-gray-500 hover:text-gray-800'
            }`}
          >
            <Plus size={15} />
            Tipos Personalizados ({tipos.filter(t => !t.is_system).length})
          </button>
        </div>

        {/* Feedback Messages */}
        {error && (
          <div className="mx-6 mt-4 p-3 bg-red-50 text-red-700 text-sm rounded-xl flex items-center gap-2">
            <AlertCircle size={16} className="flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}
        {success && (
          <div className="mx-6 mt-4 p-3 bg-green-50 text-green-700 text-sm rounded-xl flex items-center gap-2">
            <Check size={16} className="flex-shrink-0" />
            <span>{success}</span>
          </div>
        )}

        {/* Content Body */}
        <div className="p-6 overflow-y-auto flex-1 space-y-4">
          {tab === 'prioridades' ? (
            <div className="space-y-4">
              <p className="text-xs text-gray-500">
                Selecione quais tipos de documentos devem aparecer em destaque no topo do seletor para os administradores deste condomínio.
              </p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                {tipos.filter(t => t.ativo).map(t => {
                  const isPrioritario = prioridades.some(p => p.tipo_id === t.id && p.is_prioritario)
                  return (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => togglePrioritario(t.id)}
                      className={`flex items-center justify-between p-3 rounded-xl border text-left transition ${
                        isPrioritario
                          ? 'border-amber-300 bg-amber-50/50 text-gray-900 font-medium'
                          : 'border-gray-100 hover:border-gray-200 bg-white text-gray-600'
                      }`}
                    >
                      <div className="flex items-center gap-2.5 min-w-0">
                        <div className={`w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 ${
                          isPrioritario ? 'bg-amber-100 text-amber-600' : 'bg-gray-100 text-gray-500'
                        }`}>
                          {renderTipoIcon(t.icone, 15)}
                        </div>
                        <div className="min-w-0">
                          <div className="text-xs font-semibold truncate">{t.nome}</div>
                          <div className="text-[10px] text-gray-400">{t.categoria_padrao}</div>
                        </div>
                      </div>
                      <Star size={18} className={isPrioritario ? 'fill-amber-500 text-amber-500' : 'text-gray-300'} />
                    </button>
                  )
                })}
              </div>
            </div>
          ) : (
            <div className="space-y-6">
              {/* Formulário de Novo Tipo */}
              <div className="bg-gray-50/70 rounded-2xl p-4 border border-gray-100 space-y-3">
                <h3 className="text-sm font-bold text-gray-900 flex items-center gap-1.5">
                  <Plus size={15} className="text-[#FC5931]" />
                  Criar Novo Tipo para este Condomínio
                </h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">Nome *</label>
                    <input
                      type="text"
                      value={novoNome}
                      onChange={e => setNovoNome(e.target.value)}
                      placeholder="Ex: Laudo do Gerador, Certificado da Piscina..."
                      className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                    />
                  </div>
                  <div>
                    <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">Categoria Padrão *</label>
                    <input
                      type="text"
                      value={novaCategoria}
                      onChange={e => setNovaCategoria(e.target.value)}
                      placeholder="Ex: Manutenção, Segurança, Obras..."
                      className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                    />
                  </div>
                </div>

                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">Ícone</label>
                  <div className="flex flex-wrap gap-1.5">
                    {ICONES_DISPONIVEIS.map(ic => (
                      <button
                        key={ic.name}
                        type="button"
                        onClick={() => setNovoIcone(ic.name)}
                        className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs border transition ${
                          novoIcone === ic.name
                            ? 'border-[#FC5931] bg-orange-50 text-[#FC5931] font-semibold'
                            : 'border-gray-200 bg-white hover:bg-gray-100 text-gray-600'
                        }`}
                      >
                        {renderTipoIcon(ic.name, 13)}
                        <span>{ic.label}</span>
                      </button>
                    ))}
                  </div>
                </div>

                <div className="flex gap-4 pt-1">
                  <label className="flex items-center gap-1.5 text-xs text-gray-700 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={novoTemValidade}
                      onChange={e => setNovoTemValidade(e.target.checked)}
                      className="accent-[#FC5931]"
                    />
                    Normalmente possui data de validade
                  </label>
                  <label className="flex items-center gap-1.5 text-xs text-gray-700 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={novoRecorrente}
                      onChange={e => setNovoRecorrente(e.target.checked)}
                      className="accent-[#FC5931]"
                    />
                    Documento recorrente periódico
                  </label>
                </div>

                <button
                  type="button"
                  onClick={handleCriarTipo}
                  disabled={saving || !novoNome.trim()}
                  className="w-full bg-[#FC5931] text-white py-2.5 rounded-xl text-sm font-semibold hover:bg-[#D42F1D] transition disabled:opacity-40 flex items-center justify-center gap-2"
                >
                  {saving && <Loader2 size={16} className="animate-spin" />}
                  {saving ? 'Criando Tipo...' : 'Salvar Novo Tipo Personalizado'}
                </button>
              </div>

              {/* Lista de Tipos Customizados Existentes */}
              <div className="space-y-2">
                <h4 className="text-xs font-bold text-gray-400 uppercase tracking-wider">
                  Tipos Personalizados do Condomínio ({tipos.filter(t => !t.is_system).length})
                </h4>
                {tipos.filter(t => !t.is_system).length === 0 ? (
                  <p className="text-xs text-gray-400 italic py-2">
                    Nenhum tipo customizado criado ainda. Use o formulário acima para adicionar tipos sob medida.
                  </p>
                ) : (
                  tipos.filter(t => !t.is_system).map(t => (
                    <div
                      key={t.id}
                      className="flex items-center justify-between p-3 rounded-xl border border-gray-100 bg-white shadow-xs"
                    >
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-orange-50 text-[#FC5931] flex items-center justify-center flex-shrink-0">
                          {renderTipoIcon(t.icone, 16)}
                        </div>
                        <div>
                          <div className="text-sm font-bold text-gray-800 flex items-center gap-2">
                            {t.nome}
                            {!t.ativo && (
                              <span className="text-[10px] bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded font-normal">
                                Inativo
                              </span>
                            )}
                          </div>
                          <div className="text-xs text-gray-400">{t.categoria_padrao}</div>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          onClick={() => toggleAtivoTipo(t)}
                          title={t.ativo ? 'Desativar tipo' : 'Ativar tipo'}
                          className="p-1 text-gray-500 hover:text-[#FC5931] transition"
                        >
                          {t.ativo ? <ToggleRight size={22} className="text-[#FC5931]" /> : <ToggleLeft size={22} className="text-gray-400" />}
                        </button>
                        <button
                          type="button"
                          onClick={() => handleExcluirTipo(t)}
                          title="Excluir tipo"
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition text-xs"
                        >
                          Excluir
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-gray-100 flex justify-end bg-gray-50/50">
          <button
            onClick={onClose}
            className="bg-[#FC5931] text-white px-6 py-2 rounded-xl text-sm font-semibold hover:bg-[#D42F1D] transition"
          >
            Concluir
          </button>
        </div>
      </div>
    </div>
  )
}
