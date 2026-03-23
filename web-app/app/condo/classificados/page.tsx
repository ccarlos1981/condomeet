import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ClassificadosClient from './classificados-client'

export const dynamic = 'force-dynamic'

export default async function ClassificadosPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: perfil } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, bloco_txt, apto_txt, nome_completo')
    .eq('id', user.id)
    .single()

  if (!perfil) redirect('/login')

  // Fetch approved classificados (without FK join)
  const { data: classificados } = await supabase
    .from('classificados')
    .select('*')
    .eq('condominio_id', perfil.condominio_id)
    .in('status', ['aprovado', 'vendido'])
    .order('created_at', { ascending: false })

  // Fetch user's own pending/rejected ads
  const { data: meusPendentes } = await supabase
    .from('classificados')
    .select('*')
    .eq('condominio_id', perfil.condominio_id)
    .eq('criado_por', user.id)
    .in('status', ['pendente', 'rejeitado'])
    .order('created_at', { ascending: false })

  // Fetch user's favorites
  const { data: favoritos } = await supabase
    .from('classificados_favoritos')
    .select('classificado_id')
    .eq('usuario_id', user.id)

  // Fetch condo info
  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', perfil.condominio_id)
    .single()

  // Merge & deduplicate (user's own approved ads appear in both queries)
  const seenIds = new Set<string>()
  const merged = [
    ...(meusPendentes ?? []),
    ...(classificados ?? []),
  ].filter((c: { id: string }) => {
    if (seenIds.has(c.id)) return false
    seenIds.add(c.id)
    return true
  })

  // Fetch creator profiles in one go
  const creatorIds = [...new Set(merged.map((c: { criado_por: string }) => c.criado_por))]
  const { data: criadores } = creatorIds.length > 0
    ? await supabase
        .from('perfil')
        .select('id, nome_completo, bloco_txt, apto_txt, whatsapp')
        .in('id', creatorIds)
    : { data: [] }

  const criadorMap = Object.fromEntries(
    (criadores ?? []).map((c: { id: string; nome_completo: string; bloco_txt: string; apto_txt: string; whatsapp: string }) => [c.id, c])
  )

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const allClassificados: any[] = merged.map((c: Record<string, unknown>) => ({
    ...c,
    perfil: criadorMap[c.criado_por as string] ?? null,
  }))

  return (
    <ClassificadosClient
      classificados={allClassificados}
      userId={user.id}
      condominioId={perfil.condominio_id}
      favoritosIds={(favoritos ?? []).map((f: { classificado_id: string }) => f.classificado_id)}
      tipoEstrutura={condoData?.tipo_estrutura ?? 'predio'}
      userName={perfil.nome_completo}
    />
  )
}
