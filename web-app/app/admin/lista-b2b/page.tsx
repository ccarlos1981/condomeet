import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import B2BDashboardClient from './b2b-dashboard-client'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Dashboard B2B Mercados — Admin' }

export default async function B2BDashboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/admin')

  const { data: superadmin } = await supabase
    .from('system_superadmins')
    .select('email')
    .eq('email', user.email ?? '')
    .maybeSingle()

  if (!superadmin) redirect('/admin')

  // Pre-fetch supermarkets
  const { data: supermarkets } = await supabase
    .from('lista_supermarkets')
    .select('id, name')
    .order('name')

  return <B2BDashboardClient supermarkets={supermarkets ?? []} />
}
