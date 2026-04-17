'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { FileText, ChevronDown, ChevronUp, Bell, AlertTriangle } from 'lucide-react'
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
}

export default function NotificacoesMultasClient({
  historicoData,
  currentUserId
}: {
  historicoData: HistoricoItem[]
  currentUserId: string
}) {
  const supabase = createClient()
  const [historico, setHistorico] = useState<HistoricoItem[]>(historicoData)
  const [expandedId, setExpandedId] = useState<string | null>(null)

  async function handleDownload(anexoUrl: string) {
    const { data } = await supabase.storage.from('documentos').createSignedUrl(anexoUrl, 60)
    if (data?.signedUrl) {
      window.open(data.signedUrl, '_blank')
    } else {
      alert('Não foi possível abrir o anexo.')
    }
  }

  async function markAsRead(id: string) {
    const item = historico.find(h => h.id === id)
    if (item && !item.lido_em) {
      const now = new Date().toISOString()
      
      setHistorico(prev => prev.map(h => {
        if (h.id === id) {
          return { ...h, lido_em: now }
        }
        return h
      }))

      // Persist in supabase
      await supabase
        .from('notificacoes_multas')
        .update({ lido_em: now, lido_por: currentUserId })
        .eq('id', id)
    }
  }

  function toggleExpand(id: string) {
    if (expandedId === id) {
      setExpandedId(null)
    } else {
      setExpandedId(id)
      markAsRead(id)
    }
  }

  function getStatusStyle(tipo: string) {
    if (tipo === 'MULTA') return 'bg-red-50 text-red-700 border-red-200'
    return 'bg-amber-50 text-amber-700 border-amber-200'
  }

  function getStatusIcon(tipo: string) {
    if (tipo === 'MULTA') return <AlertTriangle className="w-5 h-5" />
    return <Bell className="w-5 h-5" />
  }

  return (
    <div className="space-y-4">
      {historico.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <div className="w-12 h-12 bg-gray-50 rounded-full flex items-center justify-center mx-auto mb-4">
            <Bell className="w-6 h-6 text-gray-400" />
          </div>
          <h3 className="text-lg font-medium text-gray-900 mb-1">Nenhuma notificação</h3>
          <p className="text-gray-500">Sua unidade não possui notificações ou multas registradas.</p>
        </div>
      ) : (
        historico.map(item => {
          const isLido = !!item.lido_em
          const isExpanded = expandedId === item.id

          return (
            <div key={item.id} className="bg-white border text-left border-gray-200 rounded-xl overflow-hidden hover:shadow-sm transition-shadow">
              <button 
                onClick={() => toggleExpand(item.id)}
                className="w-full flex flex-col sm:flex-row sm:items-center p-4 gap-4 text-left"
              >
                <div className={`p-3 rounded-full shrink-0 flex items-center justify-center border ${getStatusStyle(item.tipo)}`}>
                  {getStatusIcon(item.tipo)}
                </div>
                
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <span className={`text-xs font-semibold px-2 py-0.5 rounded-full border ${getStatusStyle(item.tipo)}`}>
                      {item.tipo}
                    </span>
                    {!isLido && (
                      <span className="flex items-center gap-1 text-xs font-medium text-blue-600 bg-blue-50 px-2 py-0.5 rounded-full border border-blue-200">
                        <span className="w-1.5 h-1.5 bg-blue-600 rounded-full"></span>
                        Não Lida
                      </span>
                    )}
                  </div>
                  <h3 className={`text-base font-semibold truncate ${!isLido ? 'text-gray-900' : 'text-gray-600'}`}>
                    {item.titulo}
                  </h3>
                  <div className="flex items-center gap-3 text-sm text-gray-500 mt-1">
                    <span>Ocorrência: {format(parseISO(item.data_ocorrencia), "dd 'de' MMM, yyyy", { locale: ptBR })}</span>
                  </div>
                </div>

                <div className="shrink-0 flex items-center gap-3 text-gray-400 ml-auto sm:ml-0 mt-2 sm:mt-0">
                  {isExpanded ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
                </div>
              </button>

              {isExpanded && (
                <div className="px-4 pb-4 sm:px-16 sm:pb-5">
                  <div className="pt-4 border-t border-gray-100">
                    <h4 className="text-sm font-medium text-gray-900 mb-2">Detalhes da Ocorrência</h4>
                    <p className="text-sm text-gray-600 whitespace-pre-wrap leading-relaxed bg-gray-50 p-4 rounded-lg border border-gray-100">
                      {item.descricao || 'Nenhua descrição adicional fornecida.'}
                    </p>

                    <div className="flex items-center justify-between mt-4">
                      {item.anexo_url ? (
                        <button
                          onClick={() => {
                            handleDownload(item.anexo_url!)
                            markAsRead(item.id)
                          }}
                          className="inline-flex items-center gap-2 text-sm text-blue-600 font-medium hover:text-blue-700 bg-blue-50 hover:bg-blue-100 px-4 py-2 rounded-lg transition-colors"
                        >
                          <FileText className="w-4 h-4" />
                          Visualizar Anexo
                        </button>
                      ) : (
                        <span className="text-sm text-gray-400 italic">Sem anexos</span>
                      )}

                      {isLido && (
                        <div className="text-xs text-gray-400 text-right">
                          Lido em {format(parseISO(item.lido_em!), "dd/MM/yyyy 'às' HH:mm", { locale: ptBR })}
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              )}
            </div>
          )
        })
      )}
    </div>
  )
}
