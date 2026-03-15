import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { FolderOpen, FileText, Download, Eye } from 'lucide-react'

export const metadata = { title: 'Contratos — Condomeet' }

export default async function CondoContratosPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Somente contratos visíveis aos moradores
  const { data: docs } = await supabase
    .from('contratos')
    .select('*, contrato_pastas(nome)')
    .eq('condominio_id', condoId)
    .eq('mostrar_moradores', true)
    .order('titulo')

  // Agrupa por pasta
  const grupos: Record<string, typeof docs> = {}
  ;(docs ?? []).forEach((d: any) => {
    const nomePasta = d.contrato_pastas?.nome ?? 'Sem pasta'
    if (!grupos[nomePasta]) grupos[nomePasta] = []
    grupos[nomePasta]!.push(d)
  })

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Contratos</h1>
        <p className="text-sm text-gray-500 mt-1">Contratos disponibilizados pela administração do condomínio</p>
      </div>

      {Object.keys(grupos).length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          <FolderOpen size={40} className="mx-auto mb-3 opacity-30" />
          <p className="font-medium text-gray-500">Nenhum contrato disponível</p>
        </div>
      ) : (
        <div className="space-y-4">
          {Object.entries(grupos).map(([nomePasta, docsNaPasta]) => (
            <div key={nomePasta} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="flex items-center gap-2 px-5 py-4 border-b border-gray-50">
                <FolderOpen size={18} className="text-[#FC3951]" />
                <span className="font-semibold text-gray-800">{nomePasta}</span>
                <span className="ml-auto text-xs text-gray-400">{docsNaPasta?.length} contrato(s)</span>
              </div>
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-gray-50 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                    <th className="px-5 py-3 text-left">Contrato</th>
                    <th className="px-3 py-3 text-left">Categoria</th>
                    <th className="px-3 py-3 text-left">Validade</th>
                    <th className="px-3 py-3"></th>
                  </tr>
                </thead>
                <tbody>
                  {docsNaPasta?.map((doc: any) => (
                    <tr key={doc.id} className="border-t border-gray-50 hover:bg-gray-50/50 transition">
                      <td className="px-5 py-3 font-medium text-gray-800 flex items-center gap-2">
                        <FileText size={14} className="text-[#FC3951] flex-shrink-0" />
                        {doc.titulo}
                      </td>
                      <td className="px-3 py-3 text-gray-500">{doc.categoria ?? '—'}</td>
                      <td className="px-3 py-3 text-gray-500">
                        {doc.data_validade ? new Date(doc.data_validade).toLocaleDateString('pt-BR') : '—'}
                      </td>
                      <td className="px-3 py-3">
                        <div className="flex items-center gap-1">
                          {doc.arquivo_url ? (
                            <a href={doc.arquivo_url} download={doc.arquivo_nome ?? doc.titulo}
                              title="Baixar arquivo"
                              className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC3951] hover:bg-orange-50 transition">
                              <Download size={14} />
                            </a>
                          ) : (
                            <span title="Sem arquivo" className="p-1.5 rounded-lg text-gray-200 cursor-not-allowed">
                              <Download size={14} />
                            </span>
                          )}
                          {doc.arquivo_url ? (
                            <a href={doc.arquivo_url} target="_blank" rel="noreferrer"
                              title="Visualizar arquivo"
                              className="p-1.5 rounded-lg text-gray-400 hover:text-blue-500 hover:bg-blue-50 transition">
                              <Eye size={14} />
                            </a>
                          ) : (
                            <span title="Sem arquivo" className="p-1.5 rounded-lg text-gray-200 cursor-not-allowed">
                              <Eye size={14} />
                            </span>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
