import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ClassificadosAdminClient from './classificados-admin-client'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Classificados — Painel Admin' }

export default async function ClassificadosAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: perfil } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  if (!perfil) redirect('/login')

  // Fetch classificados without FK join
  const { data: classificados } = await supabase
    .from('classificados')
    .select('*')
    .eq('condominio_id', perfil.condominio_id)
    .in('status', ['pendente', 'aprovado', 'rejeitado'])
    .order('created_at', { ascending: false })

  // Fetch creator profiles separately
  const creatorIds = [...new Set((classificados ?? []).map((c: { criado_por: string }) => c.criado_por))]
  const { data: criadores } = creatorIds.length > 0
    ? await supabase
        .from('perfil')
        .select('id, nome_completo, bloco_txt, apto_txt, whatsapp')
        .in('id', creatorIds)
    : { data: [] }

  const criadorMap = Object.fromEntries(
    (criadores ?? []).map((c: { id: string; nome_completo: string; bloco_txt: string; apto_txt: string; whatsapp: string }) => [c.id, c])
  )

  // Fetch condo info for labels
  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', perfil.condominio_id)
    .single()

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const withProfiles: any[] = (classificados ?? []).map((c: Record<string, unknown>) => ({
    ...c,
    perfil: criadorMap[c.criado_por as string] ?? null,
  }))

  return (
    <ClassificadosAdminClient
      classificados={withProfiles}
      condominioId={perfil.condominio_id}
      tipoEstrutura={condoData?.tipo_estrutura ?? 'predio'}
    />
  )
}
