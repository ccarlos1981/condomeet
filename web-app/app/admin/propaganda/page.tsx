import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import PropagandaClient from './propaganda-client'

const SUPER_ADMIN_EMAIL = 'cristiano.santos@gmx.com'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Empresas Parceiras — Admin' }

export default async function PropagandaAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user || user.email !== SUPER_ADMIN_EMAIL) redirect('/admin')

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
