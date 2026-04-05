import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import NovaAssembleiaClient from './nova-assembleia-client'

export default async function NovaAssembleiaPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch tipo_estrutura
  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo_estrutura, nome')
    .eq('id', condoId)
    .single()

  return (
    <NovaAssembleiaClient
      condominioId={condoId}
      condoNome={condoData?.nome ?? ''}
      userId={user.id}
      tipoEstrutura={condoData?.tipo_estrutura ?? 'predio'}
    />
  )
}
