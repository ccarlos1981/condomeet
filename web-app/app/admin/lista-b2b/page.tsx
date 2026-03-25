import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import B2BDashboardClient from './b2b-dashboard-client'

const SUPER_ADMIN_EMAIL = 'cristiano.santos@gmx.com'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Dashboard B2B Mercados — Admin' }

export default async function B2BDashboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user || user.email !== SUPER_ADMIN_EMAIL) redirect('/admin')

  // Pre-fetch supermarkets
  const { data: supermarkets } = await supabase
    .from('lista_supermarkets')
    .select('id, name')
    .order('name')

  return <B2BDashboardClient supermarkets={supermarkets ?? []} />
}
