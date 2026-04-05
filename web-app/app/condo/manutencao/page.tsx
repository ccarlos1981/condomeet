import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ManutencaoCondoClient from './manutencao-condo-client'

export const metadata = { title: 'Manutenção — Condomeet' }

export default async function ManutencaoCondoPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  const { data: manutencoes } = await supabase
    .from('manutencoes')
    .select('*')
    .eq('condominio_id', condoId)
    .eq('visivel_moradores', true)
    .order('data_inicio', { ascending: false })

  return (
    <div className="p-6 lg:p-8 max-w-5xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">
          Histórico de manutenção
        </h1>
      </div>
      
      <ManutencaoCondoClient manutencoes={manutencoes || []} />
    </div>
  )
}
