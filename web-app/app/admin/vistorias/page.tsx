import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import VistoriasAdminClient from './vistorias-admin-client'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Vistorias — Painel Admin' }

export default async function VistoriasAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: perfil } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  if (!perfil) redirect('/login')

  // Fetch vistorias do condomínio
  const { data: vistorias } = await supabase
    .from('vistorias')
    .select('*')
    .eq('condominio_id', perfil.condominio_id)
    .order('created_at', { ascending: false })

  // Fetch creator profiles
  const creatorIds = [...new Set((vistorias ?? []).map((v: { criado_por: string }) => v.criado_por))]
  const { data: criadores } = creatorIds.length > 0
    ? await supabase
        .from('perfil')
        .select('id, nome_completo, bloco_txt, apto_txt')
        .in('id', creatorIds)
    : { data: [] }

  const criadorMap = Object.fromEntries(
    (criadores ?? []).map((c: { id: string; nome_completo: string; bloco_txt: string; apto_txt: string }) => [c.id, c])
  )

  // Fetch templates
  const { data: templates } = await supabase
    .from('vistoria_templates')
    .select(`
      *,
      vistoria_template_secoes (
        *,
        vistoria_template_itens (*)
      )
    `)
    .eq('is_public', true)
    .order('nome')

  // Fetch condo info for labels
  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', perfil.condominio_id)
    .single()

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const withProfiles: any[] = (vistorias ?? []).map((v: Record<string, unknown>) => ({
    ...v,
    perfil: criadorMap[v.criado_por as string] ?? null,
  }))

  return (
    <VistoriasAdminClient
      vistorias={withProfiles}
      templates={templates ?? []}
      userId={user.id}
      condominioId={perfil.condominio_id}
      tipoEstrutura={condoData?.tipo_estrutura ?? 'predio'}
    />
  )
}
