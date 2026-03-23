import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import PropagandaClient from './propaganda-client'

const SUPER_ADMIN_EMAIL = 'cristiano.santos@gmx.com'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Empresas Parceiras — Super Admin' }

export default async function PropagandaPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user || user.email !== SUPER_ADMIN_EMAIL) redirect('/login')

  // Load all condominios for the dropdown
  const { data: condominios } = await supabase
    .from('condominios')
    .select('id, nome')
    .order('nome')

  return (
    <PropagandaClient
      condominios={condominios ?? []}
      superAdminEmail={SUPER_ADMIN_EMAIL}
    />
  )
}
