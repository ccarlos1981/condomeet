import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import FaturamentoClient from './faturamento-client'

const SUPER_ADMIN_EMAIL = 'cristiano.santos@gmx.com'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Faturamento de Consumos Extras — Super Admin' }

export default async function FaturamentoPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  
  if (!user || user.email !== SUPER_ADMIN_EMAIL) {
    redirect('/login')
  }

  // Load all consumos_extras using raw query with nested condominios object
  // Since we don't have types for consumo_extras yet, we use any or generic types in client.
  const { data: consumos, error } = await supabase
    .from('consumo_extras')
    .select(`
      *,
      condominios (
        nome,
        cidade,
        estado
      )
    `)
    .order('created_at', { ascending: false })

  if (error) {
    console.warn('Tabela de consumo extras pode ainda não ter sido criada no banco de dados:', error)
  }

  return (
    <FaturamentoClient
      consumos={consumos ?? []}
      superAdminEmail={SUPER_ADMIN_EMAIL}
    />
  )
}
