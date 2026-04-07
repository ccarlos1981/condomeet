import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import PassoAPassoClient from './passo-a-passo-client'

export default async function PassoAPassoPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  return <PassoAPassoClient />
}
