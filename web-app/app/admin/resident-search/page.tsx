import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ResidentSearchClient from '@/app/condo/resident-search/resident-search-client'

export const metadata = { title: 'Busca Moradores — Painel Admin' }

export default async function AdminResidentSearchPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''
  if (!condoId) redirect('/admin')

  // Fetch tipo_estrutura
  const { data: condo } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condo?.tipo_estrutura ?? 'predio'

  return (
    <div className="p-6 lg:p-8 max-w-5xl">
      <div className="mb-6">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">
          Geral
        </p>
        <h1 className="text-2xl font-bold text-gray-900">
          Busca Moradores
        </h1>
      </div>
      <ResidentSearchClient
        condoId={condoId}
        tipoEstrutura={tipoEstrutura}
      />
    </div>
  )
}
