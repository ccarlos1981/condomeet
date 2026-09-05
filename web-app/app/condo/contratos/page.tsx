import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { FolderOpen, FileText, Download, Eye, Building2 } from 'lucide-react'

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
    .select('*, contrato_pastas(nome), fornecedores(nome)')
    .eq('condominio_id', condoId)
    .eq('mostrar_moradores', true)
    .order('titulo')

  // Agrupa por pasta
  type ContratoDoc = {
    id: string
    titulo: string
    categoria?: string
    data_validade?: string
    sem_validade?: boolean
    fornecedor_nome?: string
    arquivo_url?: string
    arquivo_nome?: string
    fornecedores?: { nome: string } | null
    contrato_pastas?: { nome: string } | null | { nome: string }[]
  }

  const grupos: Record<string, ContratoDoc[]> = {}
  ;(docs ?? []).forEach((d: unknown) => {
    const docItem = d as ContratoDoc
    const pastasList = Array.isArray(docItem.contrato_pastas)
      ? docItem.contrato_pastas
      : [docItem.contrato_pastas]
    const nomePasta = pastasList[0]?.nome ?? 'Sem pasta'
    if (!grupos[nomePasta]) grupos[nomePasta] = []
    grupos[nomePasta].push(docItem)
  })

  return (
    <div className="p-6 max-w-4xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Contratos</h1>
        <p className="text-sm text-gray-500 mt-1">
          Contratos e termos de prestadores de serviços disponibilizados pela administração
        </p>
      </div>

      {Object.keys(grupos).length === 0 ? (
        <div className="text-center py-20 text-gray-400 bg-white rounded-2xl border border-gray-100 p-8">
          <FolderOpen size={40} className="mx-auto mb-3 opacity-30" />
          <p className="font-semibold text-gray-700">Nenhum contrato disponível</p>
          <p className="text-xs text-gray-400 mt-1">
            Os contratos públicos disponibilizados pelo síndico aparecerão aqui.
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {Object.entries(grupos).map(([nomePasta, docsNaPasta]) => (
            <div key={nomePasta} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="flex items-center gap-2 px-5 py-4 border-b border-gray-50 bg-gray-50/50">
                <FolderOpen size={18} className="text-[#FC5931]" />
                <span className="font-bold text-gray-800 text-sm">{nomePasta}</span>
                <span className="ml-auto text-xs text-gray-400">{docsNaPasta?.length} contrato(s)</span>
              </div>
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-gray-50/80 text-[11px] font-bold text-gray-400 uppercase tracking-wide">
                    <th className="px-5 py-3 text-left">Fornecedor / Serviço</th>
                    <th className="px-3 py-3 text-left">Categoria</th>
                    <th className="px-3 py-3 text-left">Vigência</th>
                    <th className="px-3 py-3 text-right">Ações</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {docsNaPasta?.map((doc: ContratoDoc) => {
                    const fNome = doc.fornecedores?.nome || doc.fornecedor_nome

                    return (
                      <tr key={doc.id} className="hover:bg-gray-50/50 transition">
                        <td className="px-5 py-3.5">
                          <div className="flex items-center gap-2.5">
                            <div className="w-7 h-7 rounded-lg bg-orange-50 text-[#FC5931] flex items-center justify-center shrink-0">
                              {fNome ? <Building2 size={14} /> : <FileText size={14} />}
                            </div>
                            <div>
                              <p className="font-semibold text-gray-900 text-xs sm:text-sm">{doc.titulo}</p>
                              {fNome && <p className="text-[11px] text-gray-500 font-medium">{fNome}</p>}
                            </div>
                          </div>
                        </td>
                        <td className="px-3 py-3.5 text-gray-500 text-xs">
                          {doc.categoria ? (
                            <span className="bg-gray-100 text-gray-700 px-2 py-0.5 rounded-md text-[11px] font-medium">
                              {doc.categoria}
                            </span>
                          ) : (
                            '—'
                          )}
                        </td>
                        <td className="px-3 py-3.5 text-gray-500 text-xs">
                          {doc.sem_validade ? (
                            <span className="text-gray-600 font-medium">Permanente</span>
                          ) : doc.data_validade ? (
                            new Date(doc.data_validade + 'T00:00:00').toLocaleDateString('pt-BR')
                          ) : (
                            '—'
                          )}
                        </td>
                        <td className="px-3 py-3.5 text-right">
                          <div className="flex items-center justify-end gap-1">
                            {doc.arquivo_url ? (
                              <>
                                <a
                                  href={doc.arquivo_url}
                                  download={doc.arquivo_nome ?? doc.titulo}
                                  title="Baixar arquivo"
                                  className="p-1.5 rounded-lg text-gray-400 hover:text-[#FC5931] hover:bg-orange-50 transition"
                                >
                                  <Download size={14} />
                                </a>
                                <a
                                  href={doc.arquivo_url}
                                  target="_blank"
                                  rel="noreferrer"
                                  title="Visualizar arquivo"
                                  className="p-1.5 rounded-lg text-gray-400 hover:text-blue-500 hover:bg-blue-50 transition"
                                >
                                  <Eye size={14} />
                                </a>
                              </>
                            ) : (
                              <span title="Sem arquivo" className="p-1.5 rounded-lg text-gray-200 cursor-not-allowed">
                                <Download size={14} />
                              </span>
                            )}
                          </div>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
