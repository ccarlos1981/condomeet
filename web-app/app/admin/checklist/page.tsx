import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ChecklistClient from './checklist-client'

export default async function ChecklistPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  // Get user's condo
  const { data: morador } = await supabase
    .from('moradores')
    .select('condominio_id')
    .eq('user_id', user.id)
    .single()

  if (!morador) redirect('/login')

  // Load all features status
  const condoId = morador.condominio_id

  // Garagem: check for vagas
  const { count: garagemCount } = await supabase
    .from('garagem_vagas')
    .select('id', { count: 'exact', head: true })
    .eq('condominio_id', condoId)

  // Lista: check for mercados
  const { count: mercadosCount } = await supabase
    .from('lista_supermercados')
    .select('id', { count: 'exact', head: true })

  // Lista: check for produtos
  const { count: produtosCount } = await supabase
    .from('lista_produtos')
    .select('id', { count: 'exact', head: true })

  // Dinglo: check for usuários
  const { count: dingloUsersCount } = await supabase
    .from('dinglo_usuarios')
    .select('id', { count: 'exact', head: true })

  // Propaganda: check for ads
  const { count: propagandaCount } = await supabase
    .from('propaganda')
    .select('id', { count: 'exact', head: true })
    .eq('condominio_id', condoId)

  return (
    <ChecklistClient
      stats={{
        garagem: garagemCount ?? 0,
        mercados: mercadosCount ?? 0,
        produtos: produtosCount ?? 0,
        dingloUsers: dingloUsersCount ?? 0,
        propaganda: propagandaCount ?? 0,
      }}
    />
  )
}
