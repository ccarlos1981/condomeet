import { createClient } from '@supabase/supabase-js'
import { notFound } from 'next/navigation'
import VistoriaPublicView from './vistoria-public-view'
import type { Metadata } from 'next'

export const dynamic = 'force-dynamic'

// Use anon key + SECURITY DEFINER RPCs (no service_role needed)
function getSupabase() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ token: string }>
}): Promise<Metadata> {
  const { token } = await params
  const supabase = getSupabase()

  const { data } = await supabase.rpc('get_vistoria_publica', { p_token: token })

  return {
    title: data
      ? `${data.titulo} - Vistoria de ${data.tipo_vistoria === 'entrada' ? 'Entrada' : 'Saída'} | Condomeet`
      : 'Vistoria | Condomeet',
    description: 'Visualize e assine esta vistoria digital pelo Condomeet Check.',
  }
}

export default async function VistoriaPublicPage({
  params,
}: {
  params: Promise<{ token: string }>
}) {
  const { token } = await params
  const supabase = getSupabase()

  // Call the SECURITY DEFINER RPC that returns everything in one shot
  const { data: vistoriaData, error } = await supabase.rpc('get_vistoria_publica', { p_token: token })

  if (error || !vistoriaData) notFound()

  // Extract data from the consolidated JSON
  const vistoria = {
    id: vistoriaData.id,
    titulo: vistoriaData.titulo,
    tipo_bem: vistoriaData.tipo_bem,
    tipo_vistoria: vistoriaData.tipo_vistoria,
    endereco: vistoriaData.endereco,
    cod_interno: vistoriaData.cod_interno,
    status: vistoriaData.status,
    responsavel_nome: vistoriaData.responsavel_nome,
    proprietario_nome: vistoriaData.proprietario_nome,
    inquilino_nome: vistoriaData.inquilino_nome,
    plano: vistoriaData.plano,
    created_at: vistoriaData.created_at,
  }

  // Flatten sections -> items -> photos
  const secoes = vistoriaData.secoes ?? []
  const itens: Array<{ id: string; secao_id: string; nome: string; status: string; observacao: string | null; posicao: number }> = []
  const fotos: Array<{ id: string; item_id: string; foto_url: string }> = []

  for (const secao of secoes) {
    for (const item of secao.itens ?? []) {
      itens.push({
        id: item.id,
        secao_id: secao.id,
        nome: item.nome,
        status: item.status,
        observacao: item.observacao,
        posicao: item.posicao,
      })
      for (const foto of item.fotos ?? []) {
        fotos.push({
          id: foto.id,
          item_id: item.id,
          foto_url: foto.foto_url,
        })
      }
    }
  }

  return (
    <VistoriaPublicView
      vistoria={vistoria}
      secoes={secoes.map((s: { id: string; nome: string; icone_emoji: string; posicao: number }) => ({
        id: s.id,
        nome: s.nome,
        icone_emoji: s.icone_emoji,
        posicao: s.posicao,
      }))}
      itens={itens}
      fotos={fotos}
      assinaturas={vistoriaData.assinaturas ?? []}
      condoNome={vistoriaData.condo_nome ?? 'Condomínio'}
      token={token}
    />
  )
}
