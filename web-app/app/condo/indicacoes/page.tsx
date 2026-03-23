import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import IndicacoesClient from './indicacoes-client'

export const metadata = { title: 'Indicações de Serviço — Condomeet' }

export default async function IndicacoesPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, nome_completo')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch indicações with creator info
  const { data: indicacoes } = await supabase
    .from('indicacoes_servico')
    .select('*, criador:perfil!criado_por(nome_completo)')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  // Fetch all ratings for this condo's indicações
  const indicacaoIds = (indicacoes ?? []).map((i: any) => i.id)
  const { data: avaliacoes } = indicacaoIds.length > 0
    ? await supabase
        .from('indicacoes_avaliacoes')
        .select('*')
        .in('indicacao_id', indicacaoIds)
    : { data: [] }

  return (
    <div className="p-6">
      <IndicacoesClient
        indicacoes={indicacoes ?? []}
        avaliacoes={avaliacoes ?? []}
        condoId={condoId}
        currentUserId={user.id}
        currentUserName={profile?.nome_completo ?? ''}
      />
    </div>
  )
}
