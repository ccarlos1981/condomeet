'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Fornecedor } from './types'
import {
  Search, Plus, Check, Building2, User, Phone, FileText, X, Loader2
} from 'lucide-react'

interface FornecedorSelectorProps {
  condoId: string
  fornecedores: Fornecedor[]
  selectedFornecedorId: string | null
  fornecedorNomeAvulso: string
  onSelectFornecedor: (fornecedor: Fornecedor | null) => void
  onChangeNomeAvulso: (nome: string) => void
  onFornecedorCreated: (novoFornecedor: Fornecedor) => void
}

export default function FornecedorSelector({
  condoId,
  fornecedores,
  selectedFornecedorId,
  fornecedorNomeAvulso,
  onSelectFornecedor,
  onChangeNomeAvulso,
  onFornecedorCreated,
}: FornecedorSelectorProps) {
  const [isAvulsoMode, setIsAvulsoMode] = useState<boolean>(
    !selectedFornecedorId && Boolean(fornecedorNomeAvulso)
  )
  const [search, setSearch] = useState('')
  const [isOpen, setIsOpen] = useState(false)
  const [showNovoModal, setShowNovoModal] = useState(false)

  // Form para criação rápida de fornecedor
  const [novoNome, setNovoNome] = useState('')
  const [novoTipo, setNovoTipo] = useState<'Pessoa Jurídica' | 'Pessoa Física'>('Pessoa Jurídica')
  const [novoTelefone, setNovoTelefone] = useState('')
  const [novoDocumento, setNovoDocumento] = useState('')
  const [isSaving, setIsSaving] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')

  const supabase = createClient()

  const selectedFornecedor = fornecedores.find(f => f.id === selectedFornecedorId)

  const filteredFornecedores = fornecedores.filter(f => {
    if (f.ativo === false) return false
    const q = search.toLowerCase()
    return (
      f.nome.toLowerCase().includes(q) ||
      (f.documento?.toLowerCase().includes(q) ?? false) ||
      (f.telefone?.toLowerCase().includes(q) ?? false)
    )
  })

  async function handleCreateFornecedor(e: React.FormEvent) {
    e.preventDefault()
    if (!novoNome.trim()) {
      setErrorMsg('Informe o nome ou razão social do fornecedor.')
      return
    }

    setIsSaving(true)
    setErrorMsg('')

    try {
      const { data, error } = await supabase
        .from('fornecedores')
        .insert({
          condominio_id: condoId,
          nome: novoNome.trim(),
          tipo: novoTipo,
          telefone: novoTelefone.trim() || null,
          documento: novoDocumento.trim() || null,
          ativo: true,
        })
        .select()
        .single()

      if (error) throw error

      const novo = data as Fornecedor
      onFornecedorCreated(novo)
      onSelectFornecedor(novo)
      setIsAvulsoMode(false)
      setShowNovoModal(false)
      setNovoNome('')
      setNovoTelefone('')
      setNovoDocumento('')
      setIsOpen(false)
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Erro ao cadastrar fornecedor'
      setErrorMsg(msg)
    } finally {
      setIsSaving(false)
    }
  }

  function handleSelectCadastrado(f: Fornecedor) {
    onSelectFornecedor(f)
    setIsAvulsoMode(false)
    setIsOpen(false)
  }

  function handleSwitchToAvulso() {
    setIsAvulsoMode(true)
    onSelectFornecedor(null)
    setIsOpen(false)
  }

  function handleSwitchToCadastrado() {
    setIsAvulsoMode(false)
    onChangeNomeAvulso('')
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block">
          Fornecedor / Prestador de Serviço
        </label>
        <button
          type="button"
          onClick={isAvulsoMode ? handleSwitchToCadastrado : handleSwitchToAvulso}
          className="text-xs text-[#FC5931] hover:underline font-medium"
        >
          {isAvulsoMode ? '← Selecionar da lista de fornecedores' : 'Preencher como fornecedor avulso'}
        </button>
      </div>

      {isAvulsoMode ? (
        // Modo Fornecedor Avulso (Texto Livre)
        <div className="relative">
          <input
            type="text"
            value={fornecedorNomeAvulso}
            onChange={e => onChangeNomeAvulso(e.target.value)}
            placeholder="Ex: Atlas Schindler, BioPrag, João Eletricista..."
            className="w-full border border-gray-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
          />
          <span className="text-[11px] text-gray-400 mt-1 block">
            Fornecedor avulso (não cadastrado formalmente na lista de fornecedores).
          </span>
        </div>
      ) : (
        // Modo Fornecedor Cadastrado
        <div className="relative">
          <div
            onClick={() => setIsOpen(!isOpen)}
            className="w-full border border-gray-200 rounded-xl px-3.5 py-2.5 text-sm bg-white cursor-pointer flex items-center justify-between hover:border-gray-300 transition"
          >
            {selectedFornecedor ? (
              <div className="flex items-center gap-2.5 truncate">
                <div className="w-6 h-6 rounded-lg bg-orange-50 text-[#FC5931] flex items-center justify-center shrink-0">
                  {selectedFornecedor.tipo === 'Pessoa Jurídica' ? <Building2 size={13} /> : <User size={13} />}
                </div>
                <div className="truncate">
                  <span className="font-semibold text-gray-900">{selectedFornecedor.nome}</span>
                  {selectedFornecedor.documento && (
                    <span className="text-gray-400 text-xs ml-2">({selectedFornecedor.documento})</span>
                  )}
                </div>
              </div>
            ) : (
              <span className="text-gray-400">Buscar ou selecionar fornecedor...</span>
            )}
            <Search size={16} className="text-gray-400 shrink-0 ml-2" />
          </div>

          {/* Dropdown Menu */}
          {isOpen && (
            <div className="absolute top-full left-0 right-0 mt-1.5 bg-white rounded-2xl shadow-xl border border-gray-100 z-50 overflow-hidden max-h-72 flex flex-col animate-in fade-in zoom-in-95 duration-100">
              <div className="p-2 border-b border-gray-100 flex items-center gap-2">
                <Search size={16} className="text-gray-400 ml-2" />
                <input
                  type="text"
                  value={search}
                  onChange={e => setSearch(e.target.value)}
                  placeholder="Buscar por nome, documento ou telefone..."
                  className="w-full text-sm outline-none px-1 py-1"
                  autoFocus
                />
                {search && (
                  <button onClick={() => setSearch('')} className="text-gray-400 hover:text-gray-600 p-1">
                    <X size={14} />
                  </button>
                )}
              </div>

              <div className="overflow-y-auto flex-1 p-1 divide-y divide-gray-50">
                {filteredFornecedores.length === 0 ? (
                  <div className="p-4 text-center text-gray-400 text-xs">
                    Nenhum fornecedor encontrado.
                  </div>
                ) : (
                  filteredFornecedores.map(f => {
                    const isSelected = f.id === selectedFornecedorId
                    return (
                      <div
                        key={f.id}
                        onClick={() => handleSelectCadastrado(f)}
                        className={`p-2.5 rounded-xl cursor-pointer flex items-center justify-between text-sm transition ${
                          isSelected ? 'bg-orange-50/80 text-[#FC5931]' : 'hover:bg-gray-50 text-gray-800'
                        }`}
                      >
                        <div className="flex items-center gap-2.5 truncate">
                          <div className={`w-7 h-7 rounded-lg flex items-center justify-center shrink-0 ${
                            isSelected ? 'bg-[#FC5931] text-white' : 'bg-gray-100 text-gray-500'
                          }`}>
                            {f.tipo === 'Pessoa Jurídica' ? <Building2 size={14} /> : <User size={14} />}
                          </div>
                          <div className="truncate">
                            <p className={`font-medium text-xs truncate ${isSelected ? 'text-[#FC5931] font-semibold' : 'text-gray-800'}`}>
                              {f.nome}
                            </p>
                            <p className="text-[11px] text-gray-400 truncate">
                              {f.telefone ? `📞 ${f.telefone}` : ''} {f.documento ? `• Doc: ${f.documento}` : ''}
                            </p>
                          </div>
                        </div>
                        {isSelected && <Check size={16} className="text-[#FC5931] shrink-0" />}
                      </div>
                    )
                  })
                )}
              </div>

              <div className="p-2 border-t border-gray-100 bg-gray-50 flex items-center justify-between">
                <button
                  type="button"
                  onClick={() => {
                    setShowNovoModal(true)
                    setIsOpen(false)
                  }}
                  className="text-xs text-[#FC5931] font-semibold flex items-center gap-1 hover:underline p-1"
                >
                  <Plus size={14} /> + Novo fornecedor
                </button>
                <button
                  type="button"
                  onClick={handleSwitchToAvulso}
                  className="text-xs text-gray-500 hover:text-gray-800 p-1"
                >
                  Digitar como avulso
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Modal de Cadastro Rápido de Fornecedor */}
      {showNovoModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-xl bg-orange-50 text-[#FC5931] flex items-center justify-center">
                  <Building2 size={18} />
                </div>
                <h3 className="font-bold text-gray-900 text-base">Novo Fornecedor</h3>
              </div>
              <button
                onClick={() => setShowNovoModal(false)}
                className="text-gray-400 hover:text-gray-600 p-1 rounded-lg"
              >
                <X size={18} />
              </button>
            </div>

            {errorMsg && (
              <div className="mb-4 p-2.5 rounded-xl bg-red-50 text-red-700 text-xs border border-red-100">
                {errorMsg}
              </div>
            )}

            <form onSubmit={handleCreateFornecedor} className="space-y-3.5">
              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">
                  Nome / Razão Social <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={novoNome}
                  onChange={e => setNovoNome(e.target.value)}
                  placeholder="Ex: Atlas Elevadores Ltda"
                  className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                  autoFocus
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">
                    Tipo
                  </label>
                  <select
                    value={novoTipo}
                    onChange={e => setNovoTipo(e.target.value as 'Pessoa Jurídica' | 'Pessoa Física')}
                    className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                  >
                    <option value="Pessoa Jurídica">Pessoa Jurídica</option>
                    <option value="Pessoa Física">Pessoa Física</option>
                  </select>
                </div>
                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">
                    Telefone
                  </label>
                  <input
                    type="text"
                    value={novoTelefone}
                    onChange={e => setNovoTelefone(e.target.value)}
                    placeholder="(11) 98888-7777"
                    className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1">
                  CNPJ / CPF
                </label>
                <input
                  type="text"
                  value={novoDocumento}
                  onChange={e => setNovoDocumento(e.target.value)}
                  placeholder="00.000.000/0001-00"
                  className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                />
              </div>

              <div className="flex gap-2 justify-end pt-2">
                <button
                  type="button"
                  onClick={() => setShowNovoModal(false)}
                  className="px-4 py-2 text-xs font-medium text-gray-600 hover:bg-gray-100 rounded-xl transition"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  disabled={isSaving}
                  className="px-4 py-2 text-xs font-bold text-white bg-[#FC5931] hover:bg-[#e04820] rounded-xl flex items-center gap-1.5 transition disabled:opacity-50"
                >
                  {isSaving ? <Loader2 size={14} className="animate-spin" /> : null}
                  Cadastrar e Selecionar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
