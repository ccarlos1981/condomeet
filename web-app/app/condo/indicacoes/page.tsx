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

  // 1. Fetch indicações (sem join FK — mais seguro)
  const { data: indicacoes } = await supabase
    .from('indicacoes_servico')
    .select('*')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  const indicacoesList = indicacoes ?? []

  // 2. Fetch names of creators in one go
  const creatorIds = [...new Set(indicacoesList.map((i: { criado_por: string }) => i.criado_por))]
  const { data: criadores } = creatorIds.length > 0
    ? await supabase
        .from('perfil')
        .select('id, nome_completo')
        .in('id', creatorIds)
    : { data: [] }

  const criadorMap = Object.fromEntries(
    (criadores ?? []).map((c: { id: string; nome_completo: string }) => [c.id, c.nome_completo])
  )

  // 3. Merge creator names into indicações
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const indicacoesComCriador: any[] = indicacoesList.map((i: Record<string, unknown>) => ({
    ...i,
    criador: { nome_completo: criadorMap[i.criado_por as string] ?? 'Morador' },
  }))

  // 4. Fetch all ratings for this condo's indicações
  const indicacaoIds = indicacoesList.map((i: { id: string }) => i.id)
  const { data: avaliacoes } = indicacaoIds.length > 0
    ? await supabase
        .from('indicacoes_avaliacoes')
        .select('*')
        .in('indicacao_id', indicacaoIds)
    : { data: [] }

  return (
    <div className="p-6">
      <IndicacoesClient
        indicacoes={indicacoesComCriador}
        avaliacoes={avaliacoes ?? []}
        condoId={condoId}
        currentUserId={user.id}
        currentUserName={profile?.nome_completo ?? ''}
      />
    </div>
  )
}
