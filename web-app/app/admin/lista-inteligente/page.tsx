import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ListaInteligenteClient from './lista-inteligente-client'

const SUPER_ADMIN_EMAIL = 'cristiano.santos@gmx.com'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Lista Inteligente — Admin' }

export default async function ListaInteligenteAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user || user.email !== SUPER_ADMIN_EMAIL) redirect('/admin')

  return <ListaInteligenteClient />
}
