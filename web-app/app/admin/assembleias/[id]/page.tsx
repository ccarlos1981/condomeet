import { createClient } from '@/lib/supabase/server'
import { redirect, notFound } from 'next/navigation'
import AssembleiaDetalheClient from './assembleia-detalhe-client'

export default async function AssembleiaDetalhePage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch assembleia with pautas
  const { data: assembleia, error } = await supabase
    .from('assembleias')
    .select(`
      *,
      assembleia_pautas(*)
    `)
    .eq('id', id)
    .eq('condominio_id', condoId)
    .single()

  if (error || !assembleia) notFound()

  // Fetch votes (if any) to support dashboard when finalizada
  const { data: votos } = await supabase
    .from('assembleia_votos')
    .select(`
      *,
      unidades (
        bloco:blocos ( nome_ou_numero ),
        apartamento:apartamentos ( numero )
      ),
      perfil!assembleia_votos_votante_user_id_fkey ( nome_completo )
    `)
    .eq('assembleia_id', id)

  // Fetch condo name
  const { data: condoData } = await supabase
    .from('condominios')
    .select('nome')
    .eq('id', condoId)
    .single()

  // Count total units for quorum reference
  const { count: totalUnidades } = await supabase
    .from('unidades')
    .select('id', { count: 'exact', head: true })
    .eq('condominio_id', condoId)

  // Sort pautas by ordem
  const pautas = (assembleia.assembleia_pautas ?? []).sort(
    (a: { ordem: number }, b: { ordem: number }) => a.ordem - b.ordem
  )

  return (
    <AssembleiaDetalheClient
      assembleia={{ ...assembleia, assembleia_pautas: undefined }}
      pautas={pautas}
      condoNome={condoData?.nome ?? ''}
      totalUnidades={totalUnidades ?? 0}
      userId={user.id}
      votos={votos || []}
    />
  )
}
