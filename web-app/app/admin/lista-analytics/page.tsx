import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AnalyticsDashboardClient from './analytics-client'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Analytics & Trends — Lista Inteligente' }

export default async function AnalyticsPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/admin')

  const { data: superadmin } = await supabase
    .from('system_superadmins')
    .select('email')
    .eq('email', user.email ?? '')
    .maybeSingle()

  if (!superadmin) redirect('/admin')

  return <AnalyticsDashboardClient />
}
