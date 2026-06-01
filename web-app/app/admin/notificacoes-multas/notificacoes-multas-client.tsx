'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Plus, Trash2, FileText, Loader2, X } from 'lucide-react'
import { format, parseISO } from 'date-fns'
import { ptBR } from 'date-fns/locale'

type HistoricoItem = {
  id: string
  tipo: string
  titulo: string
  descricao: string
  anexo_url: string | null
  lido_em: string | null
  status: string
  data_ocorrencia: string
  created_at: string
  bloco: string
  apto: string
  valor: number | null
}

type UnitOption = { id: string; bloco: string; apto: string }

export default function NotificacoesMultasClient({
  condoId,
  currentUserId,
  blocos,
  units,
  historicoData
}: {
  condoId: string
  currentUserId: string
  blocos: string[]
  units: UnitOption[]
  historicoData: HistoricoItem[]
}) {
  const supabase = createClient()
  const [historico, setHistorico] = useState<HistoricoItem[]>(historicoData)
  
  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [loading, setLoading] = useState(false)
  const [deletingId, setDeletingId] = useState<string | null>(null)

  // Form State
  const [formTipo, setFormTipo] = useState<'NOTIFICACAO' | 'MULTA'>('NOTIFICACAO')
  const [formData, setFormData] = useState('')
  const [formBloco, setFormBloco] = useState('')
  const [formApto, setFormApto] = useState('')
  const [formValor, setFormValor] = useState('')
  const [formOcorrencia, setFormOcorrencia] = useState('')
  const [formDescricao, setFormDescricao] = useState('')
  const [file, setFile] = useState<File | null>(null)

  const ocorrenciasOpcoes = [
    'Outras infrações da convenção sem multa',
    'Notificação financeira',
    'Outras infrações da convenção com multa',
    'Convivência: infração da convenção sem multa',
    'Convivência: infração da convenção com multa',
    'Obra: infração da convenção sem multa',
    'Obra: infração da convenção com multa',
    'Outros...'
  ]

  const aptosDisponiveis = formBloco ? units.filter(u => u.bloco === formBloco) : []

  async function handleDownload(anexoUrl: string) {
    const { data } = await supabase.storage.from('documentos').createSignedUrl(anexoUrl, 60)
    if (data?.signedUrl) {
      window.open(data.signedUrl, '_blank')
    } else {
      alert('Não foi possível abrir o anexo.')
    }
  }

  async function handleDelete(id: string) {
    if (!confirm('Deseja realmente excluir este registro?')) return
    setDeletingId(id)
    const { error } = await supabase.from('notificacoes_multas').delete().eq('id', id)
    if (!error) {
      setHistorico(prev => prev.filter(item => item.id !== id))
    } else {
      alert('Erro ao excluir.')
    }
    setDeletingId(null)
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!formOcorrencia || !formBloco || !formApto) return

    const selectedUnit = units.find(u => u.bloco === formBloco && u.apto === formApto)
    if (!selectedUnit) return

    setLoading(true)

    let uploadedPath = null
    if (file) {
      const ext = file.name.split('.').pop()
      const fileName = `notificacoes/${Date.now()}_${Math.random().toString(36).substring(7)}.${ext}`
      const { error: upErr, data: upData } = await supabase.storage.from('documentos').upload(fileName, file, { upsert: true })
      if (!upErr && upData) {
        uploadedPath = upData.path
      } else {
        console.error('File upload error', upErr)
      }
    }

    const newRecord = {
      condominio_id: condoId,
      unidade_id: selectedUnit.id,
      autor_id: currentUserId,
      tipo: formTipo,
      titulo: formOcorrencia,
      descricao: formDescricao,
      valor: formTipo === 'MULTA' && formValor ? Number(formValor) : null,
      data_ocorrencia: formData ? new Date(formData).toISOString() : new Date().toISOString(),
      anexo_url: uploadedPath
    }

    const { data: inserted, error } = await supabase
      .from('notificacoes_multas')
      .insert(newRecord)
      .select(`
        id, tipo, titulo, descricao, anexo_url, lido_em, data_ocorrencia, created_at, status, valor,
        unidades ( blocos (nome_ou_numero), apartamentos(numero) )
      `)
      .single()

    if (error) {
      console.error(error)
      alert('Erro ao inserir notificação/multa.')
    } else if (inserted) {
      const formattedInserted: HistoricoItem = {
        id: inserted.id,
        tipo: inserted.tipo,
        titulo: inserted.titulo,
        descricao: inserted.descricao,
        data_ocorrencia: inserted.data_ocorrencia,
        anexo_url: inserted.anexo_url,
        lido_em: inserted.lido_em,
        created_at: inserted.created_at,
        status: inserted.status,
        valor: inserted.valor,
        bloco: (inserted.unidades as any)?.blocos?.nome_ou_numero ?? '',
        apto: (inserted.unidades as any)?.apartamentos?.numero ?? ''
      }
      setHistorico([formattedInserted, ...historico])
      closeModal()
    }
    setLoading(false)
  }

  function closeModal() {
    setIsModalOpen(false)
    setFormTipo('NOTIFICACAO')
    setFormData('')
    setFormBloco('')
    setFormApto('')
    setFormValor('')
    setFormOcorrencia('')
    setFormDescricao('')
    setFile(null)
  }

  return (
    <div className="space-y-6">
      <button
        onClick={() => setIsModalOpen(true)}
        className="w-full flex items-center justify-center gap-3 bg-gray-100 hover:bg-gray-200 text-gray-700 font-bold py-5 rounded-2xl transition-all shadow-sm border border-gray-200/60"
      >
        <div className="w-8 h-8 rounded-full bg-[#FC5931] flex items-center justify-center text-white shrink-0">
          <Plus size={20} strokeWidth={3} />
        </div>
        Insira multa ou notificação
      </button>

      <div className="space-y-4">
        {historico.length === 0 ? (
          <p className="text-gray-500 text-center py-8">Nenhum registro encontrado.</p>
        ) : (
          historico.map(item => (
            <div key={item.id} className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 relative max-w-4xl">
              <div className="space-y-3.5 pr-24">
                <div className="text-sm"><span className="font-extrabold text-gray-900 w-24 inline-block">Bloco:</span> <span className="text-gray-700">{item.bloco}</span></div>
                <div className="text-sm"><span className="font-extrabold text-gray-900 w-24 inline-block">Unidade:</span> <span className="text-gray-700">{item.apto}</span></div>
                <div className="text-sm"><span className="font-extrabold text-gray-900 w-24 inline-block">Ocorrência:</span> <span className="text-gray-700">{item.titulo}</span></div>
                {item.tipo === 'MULTA' && item.valor !== null && item.valor !== undefined && (
                  <div className="text-sm"><span className="font-extrabold text-red-600 w-24 inline-block">Valor:</span> <span className="text-red-600 font-bold">R$ {Number(item.valor).toFixed(2).replace('.', ',')}</span></div>
                )}
                {item.descricao && (
                  <div className="text-sm flex"><span className="font-extrabold text-gray-900 w-24 inline-block shrink-0">Descrição:</span> <span className="text-gray-700">{item.descricao}</span></div>
                )}
                {item.anexo_url && (
                  <div className="text-sm"><span className="font-extrabold text-gray-900 w-24 inline-block">Doc enviado:</span> <span className="text-gray-700 font-medium">Documento Anexado</span></div>
                )}
                <div className={`text-sm font-extrabold pt-2 ${item.lido_em ? 'text-green-600' : 'text-red-500'}`}>
                  {item.lido_em ? 'Documento Lido' : 'Documento não Lido'}
                </div>
              </div>
              <div className="absolute right-6 top-1/2 -translate-y-1/2 flex items-center gap-5">
                {item.anexo_url && (
                  <button onClick={() => handleDownload(item.anexo_url!)} className="text-[#FC5931] hover:text-orange-600 transition-colors" title="Ver Documento">
                    <FileText size={36} fill="#FC5931" className="text-white" />
                  </button>
                )}
                <button 
                   onClick={() => handleDelete(item.id)} 
                   disabled={deletingId === item.id}
                   className="text-red-500 hover:text-red-700 transition-colors" 
                   title="Excluir"
                >
                  {deletingId === item.id ? <Loader2 size={36} className="animate-spin" /> : <Trash2 size={36} fill="currentColor" className="text-white" />}
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {isModalOpen && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4 backdrop-blur-sm">
          <div className="bg-white rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden relative">
            <div className="px-6 border-b border-gray-100 flex items-center justify-between bg-white relative top-0 z-10 p-5">
              <h2 className="text-xl font-bold text-gray-800">Insira a multa ou Infração</h2>
              <button onClick={closeModal} className="text-gray-400 hover:bg-gray-100 p-2 rounded-full transition-colors">
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleSubmit} className="p-6 space-y-5 overflow-y-auto max-h-[80vh]">
              {/* Radio tipo */}
              <div className="flex items-center gap-10 justify-center pb-2">
                <label className="flex items-center gap-2 cursor-pointer font-medium text-gray-700">
                  <input type="radio" value="NOTIFICACAO" checked={formTipo === 'NOTIFICACAO'} onChange={() => setFormTipo('NOTIFICACAO')} className="w-4 h-4 text-[#FC5931] accent-[#FC5931]" />
                  Notificação
                </label>
                <label className="flex items-center gap-2 cursor-pointer font-medium text-gray-700">
                  <input type="radio" value="MULTA" checked={formTipo === 'MULTA'} onChange={() => setFormTipo('MULTA')} className="w-4 h-4 text-[#FC5931] accent-[#FC5931]" />
                  Multa
                </label>
              </div>

              {/* Data */}
              <div className="flex items-center gap-4">
                <label className="w-24 font-bold text-gray-800 shrink-0 text-sm">Data:</label>
                <input 
                  type="datetime-local" 
                  required
                  value={formData} 
                  onChange={e => setFormData(e.target.value)} 
                  className="w-full p-2.5 rounded-xl border border-gray-200 outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] text-sm"
                />
              </div>

              {/* Bloco */}
              <div className="flex items-center gap-4">
                <label className="w-24 font-bold text-gray-800 shrink-0 text-sm">Bloco:</label>
                <select 
                  required
                  value={formBloco} 
                  onChange={e => {
                    setFormBloco(e.target.value)
                    setFormApto('')
                  }} 
                  className="w-full p-2.5 rounded-xl border border-gray-200 outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] text-sm bg-white"
                >
                  <option value="">Selecione</option>
                  {blocos.map(b => (
                    <option key={b} value={b}>{b}</option>
                  ))}
                </select>
              </div>

              {/* Apto */}
              <div className="flex items-center gap-4">
                <label className="w-24 font-bold text-gray-800 shrink-0 text-sm">Apto:</label>
                <select 
                  required
                  value={formApto} 
                  onChange={e => setFormApto(e.target.value)} 
                  className="w-full p-2.5 rounded-xl border border-gray-200 outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] text-sm bg-white"
                  disabled={!formBloco}
                >
                  <option value="">Selecione</option>
                  {aptosDisponiveis.map(a => (
                    <option key={a.id} value={a.apto}>{a.apto}</option>
                  ))}
                </select>
              </div>

              {/* Valor (only for MULTA) */}
              {formTipo === 'MULTA' && (
                <div className="flex items-center gap-4">
                  <label className="w-24 font-bold text-gray-800 shrink-0 text-sm">Valor (R$):</label>
                  <input 
                    type="number"
                    step="0.01"
                    min="0.01"
                    required
                    placeholder="0,00"
                    value={formValor} 
                    onChange={e => setFormValor(e.target.value)} 
                    className="w-full p-2.5 rounded-xl border border-gray-200 outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] text-sm"
                  />
                </div>
              )}

              {/* Documento */}
              <div className="flex items-center gap-4">
                <label className="w-24 font-bold text-gray-800 shrink-0 text-sm">Documento</label>
                <div className="w-full relative">
                  <input 
                    type="file" 
                    onChange={e => setFile(e.target.files?.[0] || null)} 
                    className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                  />
                  <div className="w-full p-2.5 rounded-xl border border-gray-200 bg-white text-center text-sm text-gray-500 line-clamp-1">
                    {file ? file.name : 'Clique para importar o Documento'}
                  </div>
                </div>
              </div>

              {/* Ocorrencia */}
              <div className="space-y-2 pt-2">
                <label className="block font-bold text-gray-800 text-sm">Ocorrência:</label>
                <select 
                  required
                  value={formOcorrencia} 
                  onChange={e => setFormOcorrencia(e.target.value)} 
                  className="w-full p-2.5 rounded-xl border border-gray-200 outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] text-sm bg-white"
                >
                  <option value="">Motivo</option>
                  {ocorrenciasOpcoes.map(o => (
                    <option key={o} value={o}>{o}</option>
                  ))}
                </select>
              </div>

              {/* Descrição */}
              <div className="space-y-2 pt-2">
                <label className="block font-bold text-gray-800 text-sm">Descrição</label>
                <textarea 
                  required
                  value={formDescricao}
                  onChange={e => setFormDescricao(e.target.value)}
                  placeholder="Escreva aqui uma descrição"
                  className="w-full p-3 rounded-xl border border-gray-200 outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931] text-sm h-28 resize-none"
                />
              </div>

              <div className="flex items-center justify-center gap-4 pt-4">
                 <button 
                   type="submit" 
                   disabled={loading}
                   className="bg-[#FC5931] hover:bg-orange-600 text-white font-bold py-2.5 px-8 rounded-full transition-colors flex items-center justify-center gap-2 min-w-[120px]"
                 >
                   {loading && <Loader2 size={16} className="animate-spin" />}
                   Enviar
                 </button>
                 <button 
                   type="button" 
                   onClick={closeModal}
                   className="bg-gray-100 hover:bg-gray-200 text-gray-700 font-bold py-2.5 px-8 rounded-full transition-colors min-w-[120px]"
                 >
                   Cancelar
                 </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
