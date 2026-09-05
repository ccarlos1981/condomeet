'use client'

import { useState, useEffect } from 'react'
import { RefreshCw, ExternalLink, CheckCircle, AlertTriangle, AlertCircle, Copy, Send } from 'lucide-react'
import { fetchTemplates, syncTemplates } from './actions'

export default function WhatsappTemplatesClient() {
  const [templates, setTemplates] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [syncing, setSyncing] = useState(false)
  const [message, setMessage] = useState<string | null>(null)

  const loadData = async () => {
    setLoading(true)
    const { data, error } = await fetchTemplates()
    if (error) {
      setMessage(`Erro: ${error}`)
    } else {
      setTemplates(data || [])
    }
    setLoading(false)
  }

  useEffect(() => {
    loadData()
  }, [])

  const handleSync = async () => {
    setSyncing(true)
    setMessage('Sincronizando com Meta API...')
    const { success, error, result } = await syncTemplates()
    setSyncing(false)
    if (error) {
      setMessage(`Erro na Sincronização: ${error}`)
    } else {
      setMessage(`Sincronização Concluída — Criados: ${result?.createdCount ?? 0} | Atualizados: ${result?.updatedCount ?? 0} | Erros: ${result?.errorCount ?? 0}`)
      loadData()
    }
  }

  const getStatusBadge = (status: string) => {
    switch (status?.toUpperCase()) {
      case 'APPROVED': return <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-green-100 text-green-800">Aprovado</span>
      case 'PENDING': return <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800">Pendente</span>
      case 'REJECTED': return <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-red-100 text-red-800">Rejeitado</span>
      default: return <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-gray-100 text-gray-800">{status || 'Indefinido'}</span>
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-gray-900">Templates Oficiais Meta</h2>
          <p className="text-sm text-gray-500">
            Gerenciamento centralizado dos templates do WhatsApp Cloud API.
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={handleSync}
            disabled={syncing || loading}
            className="inline-flex items-center gap-2 px-4 py-2 bg-[#FC5931] hover:bg-[#e04d28] text-white rounded-xl font-medium text-sm transition-colors disabled:opacity-50"
          >
            <RefreshCw size={16} className={syncing ? 'animate-spin' : ''} />
            {syncing ? 'Sincronizando...' : 'Sincronizar Meta'}
          </button>
          <a
            href="https://business.facebook.com/wa/manage/message-templates/"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-4 py-2 border border-gray-200 hover:bg-gray-50 text-gray-700 rounded-xl font-medium text-sm transition-colors"
          >
            <ExternalLink size={16} /> Abrir na Meta
          </a>
        </div>
      </div>

      {message && (
        <div className="p-4 bg-gray-50 border border-gray-200 rounded-xl text-sm text-gray-700">
          {message}
        </div>
      )}

      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="p-6 border-b border-gray-100">
          <h3 className="font-bold text-gray-900 text-lg">Templates Cadastrados</h3>
        </div>
        <div className="p-6">
          {loading ? (
            <div className="py-8 text-center text-gray-500">Carregando templates...</div>
          ) : templates.length === 0 ? (
            <div className="py-8 text-center text-gray-500">
              <AlertCircle className="mx-auto mb-2 h-8 w-8 text-gray-400" />
              Nenhum template encontrado localmente. Clique em "Sincronizar Meta" para carregar a lista oficial.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm text-gray-600">
                <thead className="bg-gray-50 text-xs uppercase text-gray-500 font-semibold border-b border-gray-100">
                  <tr>
                    <th className="p-3">Família / Versão</th>
                    <th className="p-3">Nome Meta</th>
                    <th className="p-3">Categoria</th>
                    <th className="p-3">Idioma</th>
                    <th className="p-3">Qualidade</th>
                    <th className="p-3">Status</th>
                    <th className="p-3">Última Sincronização</th>
                    <th className="p-3 text-right">Ações</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {templates.map((tpl) => (
                    <tr key={tpl.id} className="hover:bg-gray-50/50">
                      <td className="p-3">
                        <div className="font-medium text-[#FC5931]">{tpl.template_family}</div>
                        <div className="text-xs text-gray-400">v{tpl.template_version}</div>
                      </td>
                      <td className="p-3 font-mono text-xs">{tpl.name}</td>
                      <td className="p-3">{tpl.category}</td>
                      <td className="p-3">{tpl.language}</td>
                      <td className="p-3">
                        {tpl.quality_score === 'GREEN' && <CheckCircle size={16} className="text-green-500" />}
                        {tpl.quality_score === 'YELLOW' && <AlertTriangle size={16} className="text-yellow-500" />}
                        {tpl.quality_score === 'RED' && <AlertCircle size={16} className="text-red-500" />}
                        {!tpl.quality_score && '-'}
                      </td>
                      <td className="p-3">{getStatusBadge(tpl.status)}</td>
                      <td className="p-3 text-xs text-gray-400">
                        {tpl.last_synced_at ? new Date(tpl.last_synced_at).toLocaleString('pt-BR') : '-'}
                      </td>
                      <td className="p-3 text-right">
                        <div className="flex justify-end gap-2">
                          <button disabled title="Validar" className="p-1.5 text-gray-300 cursor-not-allowed">
                            <CheckCircle size={16} />
                          </button>
                          <button disabled title="Duplicar" className="p-1.5 text-gray-300 cursor-not-allowed">
                            <Copy size={16} />
                          </button>
                          <button disabled title="Reenviar" className="p-1.5 text-gray-300 cursor-not-allowed">
                            <Send size={16} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
