import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import LiberarVisitanteClient from './liberar-visitante-client'

export default async function LiberarVisitantePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch tipo_estrutura
  const { data: condo } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condo?.tipo_estrutura ?? 'predio'

  // Fetch registered visitors (most recent 100)
  const { data: visitantes } = await supabase
    .from('visitante_registros')
    .select('*')
    .eq('condominio_id', condoId)
    .order('entrada_at', { ascending: false })
    .limit(100)

  return (
    <div className="p-6 lg:p-8 max-w-5xl">
      <LiberarVisitanteClient
        visitantes={visitantes ?? []}
        condoId={condoId}
        userId={user.id}
        tipoEstrutura={tipoEstrutura}
      />
    </div>
  )
}
