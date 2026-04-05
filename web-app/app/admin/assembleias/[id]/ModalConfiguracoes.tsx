'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Settings, X, Info } from 'lucide-react'

// Utilizando o mesmo tipo basico
export default function ModalConfiguracoes({
  assembleia,
  onClose,
  onSuccess
}: {
  assembleia: any
  onClose: () => void
  onSuccess: () => void
}) {
  const supabase = createClient()
  const [loading, setLoading] = useState(false)
  const [form, setForm] = useState({
    dt_1a_convocacao: assembleia.dt_1a_convocacao ? assembleia.dt_1a_convocacao.slice(0, 16) : '',
    dt_2a_convocacao: assembleia.dt_2a_convocacao ? assembleia.dt_2a_convocacao.slice(0, 16) : '',
    dt_inicio_votacao: assembleia.dt_inicio_votacao ? assembleia.dt_inicio_votacao.slice(0, 16) : '',
    dt_fim_votacao: assembleia.dt_fim_votacao ? assembleia.dt_fim_votacao.slice(0, 16) : '',
    local_presencial: assembleia.local_presencial || '',
    eleicao_mesa: assembleia.eleicao_mesa || false,
    presidente_mesa: assembleia.presidente_mesa || '',
    secretario_mesa: assembleia.secretario_mesa || '',
    procuracao_exige_firma: assembleia.procuracao_exige_firma || false
  })

  function update(key: keyof typeof form, val: any) {
    setForm(p => ({ ...p, [key]: val }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    const updates = {
      dt_1a_convocacao: form.dt_1a_convocacao || null,
      dt_2a_convocacao: form.dt_2a_convocacao || null,
      dt_inicio_votacao: form.dt_inicio_votacao || null,
      dt_fim_votacao: form.dt_fim_votacao || null,
      local_presencial: form.local_presencial || null,
      eleicao_mesa: form.eleicao_mesa,
      presidente_mesa: form.presidente_mesa || null,
      secretario_mesa: form.secretario_mesa || null,
      procuracao_exige_firma: form.procuracao_exige_firma,
      updated_at: new Date().toISOString()
    }

    const { error } = await supabase
      .from('assembleias')
      .update(updates)
      .eq('id', assembleia.id)
    
    setLoading(false)
    if (error) {
      alert('Erro ao atualizar: ' + error.message)
    } else {
      onSuccess()
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto shadow-2xl">
        
        {/* Header */}
        <div className="sticky top-0 bg-white border-b border-gray-100 flex items-center justify-between p-4 px-6 z-10">
          <h2 className="text-lg font-bold text-gray-800 flex items-center gap-2">
            <Settings size={20} className="text-[#FC5931]" />
            Editar Configurações
          </h2>
          <button onClick={onClose} className="p-2 rounded-full hover:bg-gray-100 text-gray-400 hover:text-gray-600 transition-colors">
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          <div className="flex items-start gap-3 p-3 bg-blue-50 rounded-xl text-xs text-blue-700">
            <Info size={16} className="mt-0.5 flex-shrink-0" />
            <p>Se você alterar o Fim da Votação para o passado, a assembleia será bloqueada automaticamente na visão do morador.</p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Data 1ª Convocação
              </label>
              <input
                type="datetime-local"
                value={form.dt_1a_convocacao}
                onChange={e => update('dt_1a_convocacao', e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Data 2ª Convocação
              </label>
              <input
                type="datetime-local"
                value={form.dt_2a_convocacao}
                onChange={e => update('dt_2a_convocacao', e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Início da Votação
              </label>
              <input
                type="datetime-local"
                value={form.dt_inicio_votacao}
                onChange={e => update('dt_inicio_votacao', e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Fim da Votação
              </label>
              <input
                type="datetime-local"
                value={form.dt_fim_votacao}
                onChange={e => update('dt_fim_votacao', e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
              />
            </div>
          </div>

          {assembleia.modalidade !== 'online' && (
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Local Presencial
              </label>
              <input
                type="text"
                value={form.local_presencial}
                onChange={e => update('local_presencial', e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
              />
            </div>
          )}

          <div className="border-t border-gray-100 pt-6 space-y-4">
            <h3 className="text-sm font-bold text-gray-700">Mesa Diretora & Preferências</h3>
            
            <div className="flex items-center gap-3">
              <input
                type="checkbox"
                id="eleicao_mesa"
                checked={form.eleicao_mesa}
                onChange={e => update('eleicao_mesa', e.target.checked)}
                className="w-4 h-4 text-[#FC5931] rounded"
              />
              <label htmlFor="eleicao_mesa" className="text-sm text-gray-700 font-medium">
                Eleição da mesa durante a assembleia
              </label>
            </div>

            {!form.eleicao_mesa && (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-600 mb-1">
                    Presidente da Mesa
                  </label>
                  <input
                    type="text"
                    value={form.presidente_mesa}
                    onChange={e => update('presidente_mesa', e.target.value)}
                    className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-600 mb-1">
                    Secretário da Mesa
                  </label>
                  <input
                    type="text"
                    value={form.secretario_mesa}
                    onChange={e => update('secretario_mesa', e.target.value)}
                    className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
                  />
                </div>
              </div>
            )}

            <div className="flex items-center gap-3 pt-2">
              <input
                type="checkbox"
                id="procuracao"
                checked={form.procuracao_exige_firma}
                onChange={e => update('procuracao_exige_firma', e.target.checked)}
                className="w-4 h-4 text-[#FC5931] rounded"
              />
              <label htmlFor="procuracao" className="text-sm text-gray-700 font-medium">
                Exigir firma reconhecida na procuração
              </label>
            </div>
          </div>

          <div className="flex justify-end gap-3 pt-4 pb-2 border-t border-gray-100">
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
              {loading ? 'Salvando...' : 'Salvar Configurações'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
