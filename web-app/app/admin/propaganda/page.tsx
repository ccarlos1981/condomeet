import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import PropagandaClient from './propaganda-client'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Empresas Parceiras — Admin' }

export default async function PropagandaAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/admin')

  const { data: superadmin } = await supabase
    .from('system_superadmins')
    .select('email')
    .eq('email', user.email ?? '')
    .maybeSingle()

  if (!superadmin) redirect('/admin')

  const { data: condominios } = await supabase
    .from('condominios')
    .select('id, nome')
    .order('nome')

  return (
    <PropagandaClient
      condominios={condominios ?? []}
      superAdminEmail={user.email ?? ''}
    />
  )
}
