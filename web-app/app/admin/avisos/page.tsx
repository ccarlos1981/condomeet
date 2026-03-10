import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AvisosAdminClient from './avisos-admin-client'

export default async function AvisosAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Load existing avisos with read counts
  const { data: avisos } = await supabase
    .from('avisos')
    .select(`
      id, titulo, corpo, created_at,
      avisos_lidos(count)
    `)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  // Total approved residents in condo (for read %)
  const { count: totalResidents } = await supabase
    .from('perfil')
    .select('*', { count: 'exact', head: true })
    .eq('condominio_id', condoId)
    .eq('status_aprovacao', 'aprovado')

  return (
    <AvisosAdminClient
      condominioId={condoId}
      avisos={(avisos ?? []).map(a => ({
        ...a,
        lidos: (a.avisos_lidos as unknown as { count: number }[])?.[0]?.count ?? 0,
      }))}
      totalResidents={totalResidents ?? 0}
    />
  )
}
