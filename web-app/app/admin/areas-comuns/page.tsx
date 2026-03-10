import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AreasComunsClient from './areas-comuns-client'

export default async function AreasComunsPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  const { data: areas } = await supabase
    .from('areas_comuns')
    .select('*')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  return <AreasComunsClient condominioId={condoId} initialAreas={areas ?? []} />
}
