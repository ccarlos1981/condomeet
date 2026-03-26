import { createClient } from '@supabase/supabase-js'
import { notFound } from 'next/navigation'
import VistoriaPublicView from './vistoria-public-view'

export const dynamic = 'force-dynamic'

export default async function VistoriaPublicPage({
  params,
}: {
  params: Promise<{ token: string }>
}) {
  const { token } = await params

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )

  // Fetch vistoria by public token (with service role, bypasses RLS)
  const { data: vistoria } = await supabase
    .from('vistorias')
    .select('*')
    .eq('link_publico_token', token)
    .single()

  if (!vistoria) notFound()

  // Fetch all related data
  const { data: secoes } = await supabase
    .from('vistoria_secoes')
    .select('*')
    .eq('vistoria_id', vistoria.id)
    .order('posicao')

  const secaoIds = (secoes ?? []).map((s: { id: string }) => s.id)

  const { data: itens } = secaoIds.length > 0
    ? await supabase.from('vistoria_itens').select('*').in('secao_id', secaoIds).order('posicao')
    : { data: [] }

  const itemIds = (itens ?? []).map((i: { id: string }) => i.id)

  const { data: fotos } = itemIds.length > 0
    ? await supabase.from('vistoria_fotos').select('*').in('item_id', itemIds).order('posicao')
    : { data: [] }

  const { data: assinaturas } = await supabase
    .from('vistoria_assinaturas')
    .select('*')
    .eq('vistoria_id', vistoria.id)

  // Fetch condo name
  const { data: condo } = await supabase
    .from('condominios')
    .select('nome')
    .eq('id', vistoria.condominio_id)
    .single()

  return (
    <VistoriaPublicView
      vistoria={vistoria}
      secoes={secoes ?? []}
      itens={itens ?? []}
      fotos={fotos ?? []}
      assinaturas={assinaturas ?? []}
      condoNome={condo?.nome ?? 'Condomínio'}
    />
  )
}
