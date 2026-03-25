import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AnalyticsDashboardClient from './analytics-client'

const SUPER_ADMIN_EMAIL = 'cristiano.santos@gmx.com'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Analytics & Trends — Lista Inteligente' }

export default async function AnalyticsPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user || user.email !== SUPER_ADMIN_EMAIL) redirect('/admin')
  return <AnalyticsDashboardClient />
}
