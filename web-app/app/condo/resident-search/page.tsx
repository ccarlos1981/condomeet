import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ResidentSearchClient from './resident-search-client'

export const metadata = { title: 'Busca Moradores — Condomeet' }

export default async function ResidentSearchPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''
  if (!condoId) redirect('/condo')

  // Fetch tipo_estrutura
  const { data: condo } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condo?.tipo_estrutura ?? 'predio'

  return (
    <div className="p-6">
      <ResidentSearchClient
        condoId={condoId}
        tipoEstrutura={tipoEstrutura}
      />
    </div>
  )
}
