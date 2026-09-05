'use client'

import { useState, useMemo } from 'react'
import {
  Search, Star, TrendingUp, Plus, Check, FileText, Book, Scroll, Users,
  Megaphone, DollarSign, FileSpreadsheet, BarChart3, Receipt, ShieldCheck,
  Flame, ClipboardCheck, Sparkles, Award, Compass, Calculator, FileSignature,
  X, ChevronDown, Layers
} from 'lucide-react'
import { DocumentoTipo, DocumentoTipoPrioridade, Documento } from './types'

// Map of icon names to Lucide icons
export function renderTipoIcon(iconeName: string, size = 16, className = '') {
  switch (iconeName) {
    case 'book': return <Book size={size} className={className} />
    case 'scroll': return <Scroll size={size} className={className} />
    case 'users': return <Users size={size} className={className} />
    case 'megaphone': return <Megaphone size={size} className={className} />
    case 'dollar-sign': return <DollarSign size={size} className={className} />
    case 'file-spreadsheet': return <FileSpreadsheet size={size} className={className} />
    case 'bar-chart': return <BarChart3 size={size} className={className} />
    case 'receipt': return <Receipt size={size} className={className} />
    case 'shield-check': return <ShieldCheck size={size} className={className} />
    case 'flame': return <Flame size={size} className={className} />
    case 'clipboard-check': return <ClipboardCheck size={size} className={className} />
    case 'sparkles': return <Sparkles size={size} className={className} />
    case 'award': return <Award size={size} className={className} />
    case 'compass': return <Compass size={size} className={className} />
    case 'calculator': return <Calculator size={size} className={className} />
    case 'file-signature': return <FileSignature size={size} className={className} />
    default: return <FileText size={size} className={className} />
  }
}

interface TipoSelectorProps {
  tipos: DocumentoTipo[]
  prioridades: DocumentoTipoPrioridade[]
  documentos: Documento[]
  selectedTipoId: string | null
  onSelectTipo: (tipo: DocumentoTipo) => void
  onOpenNovoTipoModal?: () => void
}

export default function TipoSelector({
  tipos,
  prioridades,
  documentos,
  selectedTipoId,
  onSelectTipo,
  onOpenNovoTipoModal,
}: TipoSelectorProps) {
  const [search, setSearch] = useState('')
  const [isOpen, setIsOpen] = useState(false)

  // 1. Tipos ativos
  const activeTipos = useMemo(() => tipos.filter(t => t.ativo), [tipos])

  // 2. Tipo selecionado atualmente
  const selectedTipo = useMemo(
    () => tipos.find(t => t.id === selectedTipoId),
    [tipos, selectedTipoId]
  )

  // 3. Tipos Prioritários do Condomínio (configuração manual deliberada do síndico)
  const tiposPrioritarios = useMemo(() => {
    const prioridadeMap = new Map<string, number>()
    prioridades.forEach(p => {
      if (p.is_prioritario) prioridadeMap.set(p.tipo_id, p.ordem ?? 0)
    })
    return activeTipos
      .filter(t => prioridadeMap.has(t.id))
      .sort((a, b) => (prioridadeMap.get(a.id) ?? 0) - (prioridadeMap.get(b.id) ?? 0))
  }, [activeTipos, prioridades])

  // 4. Tipos Mais Utilizados (métrica dinâmica calculada por contagem real nos documentos)
  const tiposMaisUtilizados = useMemo(() => {
    const counts = new Map<string, number>()
    documentos.forEach(d => {
      if (d.tipo_id) {
        counts.set(d.tipo_id, (counts.get(d.tipo_id) || 0) + 1)
      }
    })
    return activeTipos
      .filter(t => (counts.get(t.id) || 0) > 0)
      .sort((a, b) => (counts.get(b.id) || 0) - (counts.get(a.id) || 0))
      .slice(0, 5)
  }, [activeTipos, documentos])

  // 5. Tipos agrupados por categoria
  const categoriasAgrupadas = useMemo(() => {
    const groups: { [cat: string]: DocumentoTipo[] } = {}
    activeTipos.forEach(t => {
      const cat = t.categoria_padrao || 'Outros'
      if (!groups[cat]) groups[cat] = []
      groups[cat].push(t)
    })
    return groups
  }, [activeTipos])

  // 6. Filtragem por busca
  const filteredTipos = useMemo(() => {
    if (!search.trim()) return activeTipos
    const q = search.toLowerCase()
    return activeTipos.filter(
      t => t.nome.toLowerCase().includes(q) ||
           (t.descricao && t.descricao.toLowerCase().includes(q)) ||
           t.categoria_padrao.toLowerCase().includes(q)
    )
  }, [activeTipos, search])

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide">
          Tipo de Documento <span className="text-red-500">*</span>
        </label>
        {onOpenNovoTipoModal && (
          <button
            type="button"
            onClick={onOpenNovoTipoModal}
            className="text-xs text-[#FC5931] hover:text-[#D42F1D] font-medium flex items-center gap-1 transition"
          >
            <Plus size={13} />
            Novo Tipo Personalizado
          </button>
        )}
      </div>

      {/* Botão Seletor Principal */}
      <div className="relative">
        <button
          type="button"
          onClick={() => setIsOpen(!isOpen)}
          className={`w-full border rounded-xl px-4 py-3 text-sm flex items-center justify-between transition bg-white shadow-sm ${
            isOpen ? 'border-[#FC5931] ring-2 ring-[#FC5931]/20' : 'border-gray-200 hover:border-gray-300'
          }`}
        >
          {selectedTipo ? (
            <div className="flex items-center gap-3 min-w-0">
              <div className="w-8 h-8 rounded-lg bg-orange-50 text-[#FC5931] flex items-center justify-center flex-shrink-0">
                {renderTipoIcon(selectedTipo.icone, 18)}
              </div>
              <div className="text-left min-w-0">
                <div className="font-semibold text-gray-800 flex items-center gap-2">
                  <span className="truncate">{selectedTipo.nome}</span>
                  {!selectedTipo.is_system && (
                    <span className="text-[10px] bg-orange-100 text-[#FC5931] px-1.5 py-0.5 rounded font-medium">
                      Personalizado
                    </span>
                  )}
                </div>
                <div className="text-xs text-gray-400 truncate">
                  Categoria sugerida: {selectedTipo.categoria_padrao}
                </div>
              </div>
            </div>
          ) : (
            <div className="flex items-center gap-2 text-gray-400">
              <Layers size={18} className="text-gray-300" />
              <span>Selecione o tipo estruturado de documento...</span>
            </div>
          )}
          <ChevronDown size={18} className={`text-gray-400 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
        </button>

        {/* Dropdown Flutuante */}
        {isOpen && (
          <div className="absolute z-50 mt-2 w-full bg-white rounded-2xl shadow-xl border border-gray-100 p-4 max-h-[460px] overflow-y-auto space-y-4">
            {/* Campo de Busca */}
            <div className="relative">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type="text"
                value={search}
                onChange={e => setSearch(e.target.value)}
                placeholder="Buscar tipo de documento..."
                className="w-full pl-9 pr-8 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] bg-gray-50"
                autoFocus
              />
              {search && (
                <button
                  type="button"
                  onClick={() => setSearch('')}
                  className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  <X size={14} />
                </button>
              )}
            </div>

            {/* Quando há busca ativa, mostra lista direta filtrada */}
            {search.trim() ? (
              <div className="space-y-1">
                <div className="text-xs font-semibold text-gray-400 uppercase tracking-wider px-1">
                  Resultados da Busca ({filteredTipos.length})
                </div>
                {filteredTipos.length === 0 ? (
                  <div className="text-center py-6 text-sm text-gray-400">
                    Nenhum tipo de documento encontrado para &quot;{search}&quot;.
                  </div>
                ) : (
                  filteredTipos.map(t => (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => { onSelectTipo(t); setIsOpen(false); setSearch('') }}
                      className={`w-full flex items-center justify-between p-2.5 rounded-xl text-left transition ${
                        selectedTipoId === t.id ? 'bg-orange-50 text-[#FC5931]' : 'hover:bg-gray-50 text-gray-700'
                      }`}
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="w-7 h-7 rounded-lg bg-gray-100 flex items-center justify-center text-gray-600 flex-shrink-0">
                          {renderTipoIcon(t.icone, 15)}
                        </div>
                        <div className="min-w-0">
                          <div className="text-sm font-medium truncate">{t.nome}</div>
                          <div className="text-xs text-gray-400 truncate">{t.categoria_padrao} • {t.descricao || 'Sem descrição'}</div>
                        </div>
                      </div>
                      {selectedTipoId === t.id && <Check size={16} className="text-[#FC5931] flex-shrink-0" />}
                    </button>
                  ))
                )}
              </div>
            ) : (
              <>
                {/* 1. Seção Prioritários do Condomínio (se houver configurado) */}
                {tiposPrioritarios.length > 0 && (
                  <div className="space-y-2">
                    <div className="flex items-center gap-1.5 text-xs font-bold text-amber-600 uppercase tracking-wider px-1">
                      <Star size={13} className="fill-amber-500 text-amber-500" />
                      Prioritários do Condomínio
                    </div>
                    <div className="grid grid-cols-2 gap-2">
                      {tiposPrioritarios.map(t => (
                        <button
                          key={t.id}
                          type="button"
                          onClick={() => { onSelectTipo(t); setIsOpen(false) }}
                          className={`flex items-center gap-2.5 p-2 rounded-xl text-left border transition ${
                            selectedTipoId === t.id
                              ? 'border-[#FC5931] bg-orange-50/70 text-[#FC5931]'
                              : 'border-gray-100 hover:border-orange-200 hover:bg-orange-50/30 text-gray-700'
                          }`}
                        >
                          <div className="w-6 h-6 rounded-md bg-amber-50 text-amber-600 flex items-center justify-center flex-shrink-0">
                            {renderTipoIcon(t.icone, 14)}
                          </div>
                          <span className="text-xs font-semibold truncate">{t.nome}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {/* 2. Seção Mais Utilizados (métrica real calculada por uso) */}
                {tiposMaisUtilizados.length > 0 && (
                  <div className="space-y-2 pt-1 border-t border-gray-100">
                    <div className="flex items-center gap-1.5 text-xs font-bold text-blue-600 uppercase tracking-wider px-1">
                      <TrendingUp size={13} />
                      Mais Utilizados
                    </div>
                    <div className="flex flex-wrap gap-1.5">
                      {tiposMaisUtilizados.map(t => (
                        <button
                          key={t.id}
                          type="button"
                          onClick={() => { onSelectTipo(t); setIsOpen(false) }}
                          className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium border transition ${
                            selectedTipoId === t.id
                              ? 'border-[#FC5931] bg-[#FC5931] text-white'
                              : 'border-gray-200 bg-gray-50 hover:bg-gray-100 text-gray-700'
                          }`}
                        >
                          {renderTipoIcon(t.icone, 13)}
                          <span>{t.nome}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {/* 3. Todos os tipos agrupados por categoria */}
                <div className="space-y-3 pt-2 border-t border-gray-100">
                  <div className="text-xs font-semibold text-gray-400 uppercase tracking-wider px-1">
                    Todos os Tipos por Categoria
                  </div>
                  {Object.entries(categoriasAgrupadas).map(([categoria, items]) => (
                    <div key={categoria} className="space-y-1">
                      <div className="text-xs font-bold text-gray-500 px-1 py-0.5 bg-gray-100/70 rounded-md inline-block">
                        {categoria}
                      </div>
                      <div className="grid grid-cols-1 gap-1">
                        {items.map(t => (
                          <button
                            key={t.id}
                            type="button"
                            onClick={() => { onSelectTipo(t); setIsOpen(false) }}
                            className={`w-full flex items-center justify-between p-2 rounded-xl text-left transition ${
                              selectedTipoId === t.id ? 'bg-orange-50 text-[#FC5931] font-semibold' : 'hover:bg-gray-50 text-gray-700'
                            }`}
                          >
                            <div className="flex items-center gap-2.5 min-w-0">
                              <div className="w-6 h-6 rounded-md bg-gray-100 flex items-center justify-center text-gray-500 flex-shrink-0">
                                {renderTipoIcon(t.icone, 13)}
                              </div>
                              <span className="text-xs truncate">{t.nome}</span>
                              {!t.is_system && (
                                <span className="text-[9px] bg-orange-100 text-[#FC5931] px-1 rounded font-normal">
                                  Custom
                                </span>
                              )}
                            </div>
                            {selectedTipoId === t.id && <Check size={14} className="text-[#FC5931] flex-shrink-0" />}
                          </button>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>
        )}
      </div>

      {/* Chips de Acesso Rápido nos Mais Populares (abaixo do seletor fechado) */}
      {!isOpen && tiposPrioritarios.length > 0 && (
        <div className="flex items-center gap-1.5 flex-wrap pt-1">
          <span className="text-[11px] text-gray-400 font-medium">Prioritários:</span>
          {tiposPrioritarios.slice(0, 4).map(t => (
            <button
              key={t.id}
              type="button"
              onClick={() => onSelectTipo(t)}
              className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs transition ${
                selectedTipoId === t.id
                  ? 'bg-[#FC5931] text-white font-semibold shadow-xs'
                  : 'bg-gray-100 hover:bg-orange-50 hover:text-[#FC5931] text-gray-600'
              }`}
            >
              {renderTipoIcon(t.icone, 12)}
              <span>{t.nome}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
