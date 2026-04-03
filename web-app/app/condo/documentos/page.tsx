import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { FolderOpen, FileText, Download, Eye } from 'lucide-react'

export const metadata = { title: 'Documentos — Condomeet' }

export default async function CondoDocumentosPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Only fetch docs visible to residents
  const { data: docs } = await supabase
    .from('documentos')
    .select('*, doc_pastas(nome)')
    .eq('condominio_id', condoId)
    .eq('mostrar_moradores', true)
    .order('titulo')

  // Group by pasta
  type DocumentoDoc = { id: string; titulo: string; categoria?: string; data_validade?: string; arquivo_url?: string; arquivo_nome?: string; doc_pastas?: { nome: string } | null | { nome: string }[] }
  const grupos: Record<string, typeof docs> = {}
  ;(docs ?? []).forEach((d: DocumentoDoc) => {
    const pastasList = Array.isArray(d.doc_pastas) ? d.doc_pastas : [d.doc_pastas]
    const nomePasta = pastasList[0]?.nome ?? 'Sem pasta'
    if (!grupos[nomePasta]) grupos[nomePasta] = []
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    grupos[nomePasta]!.push(d as any)
  })

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Documentos</h1>
        <p className="text-sm text-gray-500 mt-1">Documentos disponibilizados pela administração do condomínio</p>
      </div>

      {Object.keys(grupos).length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          <FolderOpen size={40} className="mx-auto mb-3 opacity-30" />
          <p className="font-medium text-gray-500">Nenhum documento disponível</p>
        </div>
      ) : (
        <div className="space-y-4">
          {Object.entries(grupos).map(([nomePasta, docsNaPasta]) => (
            <div key={nomePasta} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="flex items-center gap-2 px-5 py-4 border-b border-gray-50">
                <FolderOpen size={18} className="text-[#FC5931]" />
                <span className="font-semibold text-gray-800">{nomePasta}</span>
                <span className="ml-auto text-xs text-gray-400">{docsNaPasta?.length} doc(s)</span>
              </div>
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-gray-50 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                    <th className="px-5 py-3 text-left">Documento</th>
                    <th className="px-3 py-3 text-left">Categoria</th>
                    <th className="px-3 py-3 text-left">Validade</th>
                    <th className="px-3 py-3"></th>
                  </tr>
                </thead>
                <tbody>
                  {docsNaPasta?.map((doc: DocumentoDoc) => (
                    <tr key={doc.id} className="border-t border-gray-50 hover:bg-gray-50/50 transition">
                      <td className="px-5 py-3 font-medium text-gray-800 flex items-center gap-2">
                        <FileText size={14} className="text-[#FC5931] flex-shrink-0" />
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
                              className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC5931] hover:bg-orange-50 transition">
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
