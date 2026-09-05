import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { FolderOpen, FileText, Download, Eye, CheckCircle2 } from 'lucide-react'
import { getCategoriaBadge } from '@/app/admin/documentos/constants'

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

  // Fetch docs visible to residents
  const { data: docs } = await supabase
    .from('documentos')
    .select('*, doc_pastas(nome)')
    .eq('condominio_id', condoId)
    .eq('mostrar_moradores', true)
    .order('titulo')

  type DocumentoDoc = {
    id: string
    titulo: string
    tipo?: string
    categoria?: string
    sem_validade?: boolean
    data_validade?: string
    arquivo_url?: string
    arquivo_nome?: string
    doc_pastas?: { nome: string } | null | { nome: string }[]
  }

  const grupos: Record<string, DocumentoDoc[]> = {}
  ;(docs ?? []).forEach((d: DocumentoDoc) => {
    const pastasList = Array.isArray(d.doc_pastas) ? d.doc_pastas : [d.doc_pastas]
    const nomePasta = pastasList[0]?.nome ?? 'Geral'
    if (!grupos[nomePasta]) grupos[nomePasta] = []
    grupos[nomePasta].push(d)
  })

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Documentos do Condomínio</h1>
        <p className="text-sm text-gray-500 mt-1">Consulte convenção, regimento, balancetes e documentos oficiais disponibilizados pela administração</p>
      </div>

      {Object.keys(grupos).length === 0 ? (
        <div className="text-center py-20 text-gray-400 bg-white rounded-2xl border border-gray-100 p-8">
          <FolderOpen size={40} className="mx-auto mb-3 opacity-30 text-[#FC5931]" />
          <p className="font-medium text-gray-700">Nenhum documento disponível no momento</p>
          <p className="text-xs text-gray-400 mt-1">Os documentos liberados pela administração aparecerão aqui.</p>
        </div>
      ) : (
        <div className="space-y-5">
          {Object.entries(grupos).map(([nomePasta, docsNaPasta]) => (
            <div key={nomePasta} className="bg-white rounded-2xl shadow-xs border border-gray-100 overflow-hidden">
              <div className="flex items-center gap-2.5 px-5 py-4 border-b border-gray-50 bg-gray-50/40">
                <FolderOpen size={18} className="text-[#FC5931]" />
                <span className="font-semibold text-gray-800">{nomePasta}</span>
                <span className="ml-auto text-xs text-gray-400">{docsNaPasta?.length} doc(s)</span>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-gray-50/70 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                      <th className="px-5 py-3 text-left">Documento</th>
                      <th className="px-3 py-3 text-left">Categoria</th>
                      <th className="px-3 py-3 text-left">Motivo</th>
                      <th className="px-3 py-3 text-left">Validade</th>
                      <th className="px-3 py-3 text-right">Ações</th>
                    </tr>
                  </thead>
                  <tbody>
                    {docsNaPasta?.map((doc: DocumentoDoc) => {
                      const badge = getCategoriaBadge(doc.tipo)

                      return (
                        <tr key={doc.id} className="border-t border-gray-50 hover:bg-gray-50/50 transition">
                          <td className="px-5 py-3 font-medium text-gray-800 flex items-center gap-2">
                            <FileText size={15} className="text-[#FC5931] flex-shrink-0" />
                            <div>
                              <div className="font-semibold text-gray-900">{doc.titulo}</div>
                              {doc.arquivo_nome && (
                                <div className="text-[11px] text-gray-400">{doc.arquivo_nome}</div>
                              )}
                            </div>
                          </td>
                          <td className="px-3 py-3">
                            <span className={`inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-semibold border ${badge.bg} ${badge.text} ${badge.border}`}>
                              {badge.label}
                            </span>
                          </td>
                          <td className="px-3 py-3 text-gray-700 font-medium">
                            {doc.categoria ?? '—'}
                          </td>
                          <td className="px-3 py-3 text-gray-500">
                            {doc.sem_validade ? (
                              <span className="inline-flex items-center gap-1 text-xs text-gray-500 bg-gray-100 px-2 py-0.5 rounded">
                                <CheckCircle2 size={12} className="text-gray-400" />
                                Permanente
                              </span>
                            ) : doc.data_validade ? (
                              new Date(doc.data_validade + 'T12:00:00').toLocaleDateString('pt-BR')
                            ) : (
                              '—'
                            )}
                          </td>
                          <td className="px-3 py-3 text-right">
                            <div className="flex items-center justify-end gap-1">
                              {doc.arquivo_url ? (
                                <>
                                  <a
                                    href={doc.arquivo_url}
                                    download={doc.arquivo_nome ?? doc.titulo}
                                    title="Baixar arquivo"
                                    className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC5931] hover:bg-orange-50 transition"
                                  >
                                    <Download size={15} />
                                  </a>
                                  <a
                                    href={doc.arquivo_url}
                                    target="_blank"
                                    rel="noreferrer"
                                    title="Visualizar arquivo"
                                    className="p-1.5 rounded-lg text-gray-400 hover:text-blue-500 hover:bg-blue-50 transition"
                                  >
                                    <Eye size={15} />
                                  </a>
                                </>
                              ) : (
                                <span className="text-xs text-gray-300 italic px-2">Sem anexo</span>
                              )}
                            </div>
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
