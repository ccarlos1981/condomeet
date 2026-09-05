import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ForceUpdateClient from './force-update-client'
import { getAppVersionPolicy } from './actions'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Governança de Versões (Force Update) — Super Admin' }

export default async function SuperAdminForceUpdatePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/login')
  }

  // Verifica permissão na tabela oficial system_superadmins
  const { data: superadmin } = await supabase
    .from('system_superadmins')
    .select('email')
    .eq('email', user.email ?? '')
    .maybeSingle()

  if (!superadmin) {
    redirect('/admin')
  }

  const policy = await getAppVersionPolicy()

  return (
    <ForceUpdateClient
      initialPolicy={policy}
      userEmail={user.email ?? ''}
    />
  )
}
