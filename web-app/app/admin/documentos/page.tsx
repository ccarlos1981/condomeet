import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import DocumentosClient from './documentos-client'

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

  const [{ data: pastas }, { data: docs }] = await Promise.all([
    supabase.from('doc_pastas').select('*').eq('condominio_id', condoId).order('nome'),
    supabase.from('documentos').select('*').eq('condominio_id', condoId).order('titulo'),
  ])

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Documentos</h1>
        <p className="text-sm text-gray-500 mt-1">Gerencie os documentos do condomínio por pasta</p>
      </div>
      <DocumentosClient
        initialPastas={pastas ?? []}
        initialDocs={docs ?? []}
        condoId={condoId}
        tabelaPastas="doc_pastas"
        tabelaDocs="documentos"
        storageBucket="documentos"
        titulo="Documento"
      />
    </div>
  )
}
