import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import DocumentosWrapper from './documentos-wrapper'

export const metadata = { title: 'Documentos — Admin Condomeet' }

export default async function DocumentosPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  const [{ data: pastas }, { data: docs }, { data: categorias }, { data: regras }] = await Promise.all([
    supabase.from('doc_pastas').select('*').eq('condominio_id', condoId).order('nome'),
    supabase.from('documentos').select('*').eq('condominio_id', condoId).order('titulo'),
    supabase.from('documentos_categorias').select('nome').eq('condominio_id', condoId).order('nome'),
    supabase.from('condominio_regras').select('*').eq('condominio_id', condoId).order('created_at', { ascending: false }),
  ])

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Documentos e Regimento</h1>
        <p className="text-sm text-gray-500 mt-1">Gerencie os arquivos, pastas e regras do condomínio para o Chatbot de IA</p>
      </div>
      <DocumentosWrapper
        initialPastas={pastas ?? []}
        initialDocs={docs ?? []}
        initialRegras={regras ?? []}
        condoId={condoId}
        tabelaPastas="doc_pastas"
        tabelaDocs="documentos"
        storageBucket="documentos"
        titulo="Documento"
        initialCategorias={(categorias ?? []).map((c: { nome: string }) => c.nome)}
      />
    </div>
  )
}
