import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ManutencaoClient from './manutencao-client'

export const metadata = { title: 'Manutenção — Admin Condomeet' }

export default async function ManutencaoPage() {
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
    .order('data_inicio', { ascending: false })

  const { data: fornecedores } = await supabase
    .from('fornecedores')
    .select('id, nome, documento')
    .eq('condominio_id', condoId)
    .order('nome', { ascending: true })

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Manutenção</h1>
        <p className="text-sm text-gray-500 mt-1">Gerencie as ocorrências de manutenção do condomínio e fornecedores.</p>
      </div>
      <ManutencaoClient 
        manutencoes={manutencoes ?? []} 
        fornecedores={fornecedores ?? []}
        condoId={condoId} 
      />
    </div>
  )
}
