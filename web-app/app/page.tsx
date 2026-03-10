import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import LandingPage from '@/components/landing/LandingPage'

export const metadata = {
  title: 'Condomeet — O Condomínio do Futuro',
  description: 'Gerencie seu condomínio de forma simples, segura e conectada. Autorize visitantes, controle encomendas, reserve áreas comuns e muito mais.',
}

export default async function RootPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (user) redirect('/condo')
  return <LandingPage />
}
