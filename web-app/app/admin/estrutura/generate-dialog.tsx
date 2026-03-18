'use client'

import { useState } from 'react'
import { X, Sparkles, Building2, Home } from 'lucide-react'

type Bloco = { id: string; nome_ou_numero: string }
type Apartamento = { id: string; numero: string }
type Unidade = { id: string; bloco_id: string; apartamento_id: string }

interface Props {
  blocos: Bloco[]
  apartamentos: Apartamento[]
  unidades: Unidade[]
  loading: boolean
  onGenerate: (blocoIds: string[], aptoIds: string[]) => void
  onClose: () => void
}

export default function GenerateDialog({ blocos, apartamentos, unidades, loading, onGenerate, onClose }: Props) {
  const [selectedBlocos, setSelectedBlocos] = useState<Set<string>>(new Set(blocos.map(b => b.id)))
  const [selectedAptos, setSelectedAptos] = useState<Set<string>>(new Set(apartamentos.map(a => a.id)))

  function toggleBloco(id: string) {
    setSelectedBlocos(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  function toggleApto(id: string) {
    setSelectedAptos(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const total = selectedBlocos.size * selectedAptos.size
  let existing = 0
  for (const b of selectedBlocos) {
    for (const a of selectedAptos) {
      if (unidades.some(u => u.bloco_id === b && u.apartamento_id === a)) existing++
    }
  }
  const toCreate = total - existing

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[85vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h3 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <Sparkles size={20} className="text-[#FC5931]" />
            Gerar Unidades
          </h3>
          <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors" title="Fechar">
            <X size={18} />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {/* Blocos selection */}
          <div>
            <div className="flex items-center justify-between mb-3">
              <label className="text-sm font-semibold text-gray-700 flex items-center gap-2">
                <Building2 size={14} className="text-[#FC5931]" />
                Selecione os Blocos
              </label>
              <button
                onClick={() => {
                  if (selectedBlocos.size === blocos.length) setSelectedBlocos(new Set())
                  else setSelectedBlocos(new Set(blocos.map(b => b.id)))
                }}
                className="text-xs text-[#FC5931] hover:underline font-medium"
              >
                {selectedBlocos.size === blocos.length ? 'Desmarcar todos' : 'Selecionar todos'}
              </button>
            </div>
            <div className="flex flex-wrap gap-2">
              {blocos.map(b => (
                <button
                  key={b.id}
                  onClick={() => toggleBloco(b.id)}
                  className={`px-3 py-1.5 rounded-full text-sm font-medium border transition-all ${
                    selectedBlocos.has(b.id)
                      ? 'bg-[#FC5931]/10 border-[#FC5931]/30 text-[#FC5931]'
                      : 'bg-gray-50 border-gray-200 text-gray-500 hover:bg-gray-100'
                  }`}
                >
                  {selectedBlocos.has(b.id) && '✓ '}{b.nome_ou_numero}
                </button>
              ))}
            </div>
          </div>

          {/* Aptos selection */}
          <div>
            <div className="flex items-center justify-between mb-3">
              <label className="text-sm font-semibold text-gray-700 flex items-center gap-2">
                <Home size={14} className="text-[#FC5931]" />
                Selecione os Apartamentos
              </label>
              <button
                onClick={() => {
                  if (selectedAptos.size === apartamentos.length) setSelectedAptos(new Set())
                  else setSelectedAptos(new Set(apartamentos.map(a => a.id)))
                }}
                className="text-xs text-[#FC5931] hover:underline font-medium"
              >
                {selectedAptos.size === apartamentos.length ? 'Desmarcar todos' : 'Selecionar todos'}
              </button>
            </div>
            <div className="flex flex-wrap gap-2">
              {apartamentos.map(a => (
                <button
                  key={a.id}
                  onClick={() => toggleApto(a.id)}
                  className={`px-3 py-1.5 rounded-full text-sm font-medium border transition-all ${
                    selectedAptos.has(a.id)
                      ? 'bg-[#FC5931]/10 border-[#FC5931]/30 text-[#FC5931]'
                      : 'bg-gray-50 border-gray-200 text-gray-500 hover:bg-gray-100'
                  }`}
                >
                  {selectedAptos.has(a.id) && '✓ '}{a.numero}
                </button>
              ))}
            </div>
          </div>

          {/* Preview */}
          {selectedBlocos.size > 0 && selectedAptos.size > 0 && (
            <div className="bg-gray-50 rounded-xl p-4 border border-gray-100">
              <p className="text-sm text-gray-500">{total} combinações selecionadas</p>
              {toCreate > 0 ? (
                <p className="text-sm font-bold text-green-600 mt-1">
                  ✨ {toCreate} novas unidades serão criadas
                </p>
              ) : (
                <p className="text-sm font-bold text-[#FC5931] mt-1">
                  ✅ Todas as unidades selecionadas já existem
                </p>
              )}
            </div>
          )}
        </div>

        {/* Actions */}
        <div className="flex gap-3 px-6 py-4 border-t border-gray-100 bg-gray-50/50 rounded-b-2xl">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2.5 border border-gray-200 text-gray-600 rounded-xl text-sm font-medium hover:bg-gray-100 transition-colors"
          >
            Cancelar
          </button>
          <button
            onClick={() => onGenerate(Array.from(selectedBlocos), Array.from(selectedAptos))}
            disabled={loading || selectedBlocos.size === 0 || selectedAptos.size === 0}
            className="flex-1 px-4 py-2.5 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04a25] disabled:opacity-50 transition-colors"
          >
            {loading ? 'Gerando...' : 'Gerar Unidades'}
          </button>
        </div>
      </div>
    </div>
  )
}
