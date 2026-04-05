import { createClient } from '@/lib/supabase/server'
import { redirect, notFound } from 'next/navigation'
import EditalClient from './edital-client'

export default async function AssembleiaEditalPage({
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

  // Fetch condo name (and other details in the future like address/cnpj)
  const { data: condoData } = await supabase
    .from('condominios')
    .select('*')
    .eq('id', condoId)
    .single()

  // Sort pautas by ordem
  const pautas = (assembleia.assembleia_pautas ?? []).sort(
    (a: { ordem: number }, b: { ordem: number }) => a.ordem - b.ordem
  )

  return (
    <EditalClient
      assembleia={{ ...assembleia, assembleia_pautas: undefined }}
      pautas={pautas}
      condominio={condoData || {}}
    />
  )
}
