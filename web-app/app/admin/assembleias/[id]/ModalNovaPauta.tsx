'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { PlusCircle, X, Info } from 'lucide-react'

export default function ModalNovaPauta({
  assembleiaId,
  nextOrdem,
  onClose,
  onSuccess
}: {
  assembleiaId: string
  nextOrdem: number
  onClose: () => void
  onSuccess: () => void
}) {
  const supabase = createClient()
  const [loading, setLoading] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})
  
  const [pauta, setPauta] = useState({
    titulo: '',
    descricao: '',
    tipo: 'votacao' as 'votacao' | 'informativo',
    quorum_tipo: 'simples',
    modo_resposta: 'unica' as 'unica' | 'multipla',
    resultado_visivel: false,
    opcoes_voto: ['A favor', 'Contra', 'Abstenção'] as string[],
    max_escolhas: 1
  })

  function update(key: keyof typeof pauta, val: any) {
    setPauta(p => ({ ...p, [key]: val }))
    setErrors(e => { const n = { ...e }; delete n[key]; return n })
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    
    if (!pauta.titulo.trim()) {
      setErrors({ titulo: 'O título da pauta é obrigatório' })
      document.getElementById('modal-novapauta-body')?.scrollTo({ top: 0, behavior: 'smooth' })
      return
    }
    if (pauta.tipo === 'votacao' && pauta.opcoes_voto.length === 0) {
      setErrors({ opcoes: 'Adicione pelo menos uma opção de voto' })
      return
    }

    setLoading(true)
    
    const insertData = {
      assembleia_id: assembleiaId,
      ordem: nextOrdem,
      titulo: pauta.titulo.trim(),
      descricao: pauta.descricao.trim() || null,
      tipo: pauta.tipo,
      quorum_tipo: pauta.tipo === 'votacao' ? pauta.quorum_tipo : null,
      modo_resposta: pauta.tipo === 'votacao' ? pauta.modo_resposta : null,
      resultado_visivel: pauta.tipo === 'votacao' ? pauta.resultado_visivel : false,
      opcoes_voto: pauta.tipo === 'votacao' ? pauta.opcoes_voto : null,
      max_escolhas: (pauta.tipo === 'votacao' && pauta.modo_resposta === 'multipla') ? pauta.max_escolhas : 1
    }

    const { error } = await supabase
      .from('assembleia_pautas')
      .insert(insertData)

    setLoading(false)
    if (error) {
      alert('Erro ao criar pauta: ' + error.message)
    } else {
      onSuccess()
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
      <div id="modal-novapauta-body" className="bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto shadow-2xl relative">
        
        {/* Header */}
        <div className="sticky top-0 bg-white border-b border-gray-100 flex items-center justify-between p-4 px-6 z-10">
          <h2 className="text-lg font-bold text-gray-800 flex items-center gap-2">
            <PlusCircle size={20} className="text-[#FC5931]" />
            Nova Pauta / Enquete
          </h2>
          <button onClick={onClose} className="p-2 rounded-full hover:bg-gray-100 text-gray-400 hover:text-gray-600 transition-colors">
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1">Título da Pauta *</label>
            <input
              type="text"
              value={pauta.titulo}
              onChange={e => update('titulo', e.target.value)}
              placeholder="Ex: Aprovação das contas"
              required
              className={`w-full px-4 py-3 rounded-xl border ${errors.titulo ? 'border-red-300 ring-2 ring-red-100' : 'border-gray-200'} focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm`}
            />
            {errors.titulo && <p className="text-xs text-red-500 mt-1">{errors.titulo}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1">Descrição</label>
            <textarea
              value={pauta.descricao}
              onChange={e => update('descricao', e.target.value)}
              placeholder="Detalhes adicionais (opcional)"
              rows={3}
              className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm resize-none"
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">Tipo da Pauta</label>
              <select
                value={pauta.tipo}
                onChange={e => update('tipo', e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm bg-white"
              >
                <option value="votacao">🗳️ Votação</option>
                <option value="informativo">ℹ️ Informativo</option>
              </select>
            </div>

            {pauta.tipo === 'votacao' && (
              <>
                <div>
                  <label className="block text-sm font-medium text-gray-600 mb-1">Quórum Exigido</label>
                  <select
                    value={pauta.quorum_tipo}
                    onChange={e => update('quorum_tipo', e.target.value)}
                    className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm bg-white"
                  >
                    <option value="simples">Maioria Simples</option>
                    <option value="dois_tercos">2/3 dos Presentes</option>
                    <option value="unanimidade">Unanimidade</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-600 mb-1">Modo de Resposta</label>
                  <select
                    value={pauta.modo_resposta}
                    onChange={e => {
                      const modo = e.target.value as 'unica' | 'multipla'
                      setPauta(prev => ({
                        ...prev,
                        modo_resposta: modo,
                        opcoes_voto: modo === 'unica' ? ['A favor', 'Contra', 'Abstenção'] : [],
                        max_escolhas: modo === 'unica' ? 1 : 2
                      }))
                    }}
                    className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm bg-white"
                  >
                    <option value="unica">🔘 Resposta Única</option>
                    <option value="multipla">☑️ Múltipla Escolha</option>
                  </select>
                </div>

                {pauta.modo_resposta === 'multipla' && (
                  <div>
                    <label className="block text-sm font-medium text-gray-600 mb-1">Máx. de Escolhas permitidas</label>
                    <input
                      type="number"
                      min={1}
                      max={Math.max(pauta.opcoes_voto.length, 1)}
                      value={pauta.max_escolhas}
                      onChange={e => update('max_escolhas', parseInt(e.target.value) || 1)}
                      className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm text-center"
                    />
                  </div>
                )}
              </>
            )}
          </div>

          {pauta.tipo === 'votacao' && (
            <div className="flex items-center gap-3 pt-2">
              <input
                type="checkbox"
                id="resultado_visivel"
                checked={pauta.resultado_visivel}
                onChange={e => update('resultado_visivel', e.target.checked)}
                className="w-4 h-4 text-[#FC5931] rounded"
              />
              <label htmlFor="resultado_visivel" className="text-sm text-gray-700 font-medium">
                Exibir resultados parciais em tempo real
              </label>
            </div>
          )}

          {/* Opções de Voto */}
          {pauta.tipo === 'votacao' && (
            <div className="bg-gray-50 p-4 rounded-xl border border-gray-100">
              <label className="block text-sm font-bold text-gray-700 mb-3">Opções de Voto</label>

              {pauta.modo_resposta === 'unica' ? (
                <div className="flex flex-wrap gap-2">
                  {pauta.opcoes_voto.map((op, i) => (
                    <span key={i} className="px-3 py-1.5 bg-green-50 border border-green-200 rounded-lg text-xs font-medium text-green-700">
                      🔘 {op}
                    </span>
                  ))}
                </div>
              ) : (
                <div className="space-y-4">
                  {errors.opcoes && <p className="text-xs text-red-500">{errors.opcoes}</p>}
                  
                  <div className="flex items-start gap-2 p-2.5 bg-amber-50 rounded-lg text-xs text-amber-700 mb-3">
                    <Info size={14} className="mt-0.5 shrink-0" />
                    <span>Adicione as opções personalizadas. Ex: "Investir na Piscina", "Reformar Parquinho", etc.</span>
                  </div>

                  {pauta.opcoes_voto.length > 0 && (
                    <div className="flex flex-wrap gap-2 mb-3">
                      {pauta.opcoes_voto.map((op, i) => (
                        <span key={i} className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-blue-50 border border-blue-200 rounded-lg text-xs font-medium text-blue-700">
                          ☑️ {op}
                          <button
                            type="button"
                            onClick={() => {
                              const newOps = pauta.opcoes_voto.filter((_, idx) => idx !== i)
                              setPauta(prev => ({
                                ...prev,
                                opcoes_voto: newOps,
                                max_escolhas: Math.min(prev.max_escolhas, Math.max(newOps.length, 1))
                              }))
                            }}
                            className="text-blue-400 hover:text-red-500"
                          >
                            <X size={12} />
                          </button>
                        </span>
                      ))}
                    </div>
                  )}

                  <div className="flex gap-2">
                    <input
                      type="text"
                      id="nova_opcao_input"
                      placeholder="Digite uma nova opção..."
                      className="flex-1 px-4 py-2.5 rounded-lg border border-gray-200 outline-none text-sm focus:border-blue-400"
                      onKeyDown={e => {
                        if (e.key === 'Enter') {
                          e.preventDefault()
                          const input = e.currentTarget
                          const val = input.value.trim()
                          if (val && !pauta.opcoes_voto.includes(val)) {
                            setPauta(prev => ({ ...prev, opcoes_voto: [...prev.opcoes_voto, val] }))
                            input.value = ''
                          }
                        }
                      }}
                    />
                    <button
                      type="button"
                      onClick={() => {
                        const input = document.getElementById('nova_opcao_input') as HTMLInputElement
                        const val = input?.value.trim()
                        if (val && !pauta.opcoes_voto.includes(val)) {
                          setPauta(prev => ({ ...prev, opcoes_voto: [...prev.opcoes_voto, val] }))
                          if(input) {
                            input.value = ''
                            input.focus()
                          }
                        }
                      }}
                      className="px-4 py-2.5 bg-blue-500 text-white rounded-lg text-sm font-medium hover:bg-blue-600 transition-colors"
                    >
                      Adicionar
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}

          <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="px-5 py-2.5 rounded-xl font-medium text-gray-600 hover:bg-gray-100 transition-colors text-sm"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-5 py-2.5 rounded-xl font-medium bg-[#FC5931] hover:bg-[#e04a2a] text-white transition-colors text-sm disabled:opacity-50 flex items-center gap-2"
            >
              {loading ? 'Adicionando...' : 'Adicionar Pauta'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
