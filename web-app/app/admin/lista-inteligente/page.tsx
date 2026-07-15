import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ListaInteligenteClient from './lista-inteligente-client'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Lista Inteligente — Admin' }

export default async function ListaInteligenteAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/admin')

  const { data: superadmin } = await supabase
    .from('system_superadmins')
    .select('email')
    .eq('email', user.email ?? '')
    .maybeSingle()

  if (!superadmin) redirect('/admin')

  return <ListaInteligenteClient />
}
