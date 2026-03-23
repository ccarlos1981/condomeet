import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AlbumFotosAdminClient from './album-fotos-admin-client'

export default async function AlbumFotosAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Load existing albums with image count, reaction count, comment count, view count
  const { data: albums } = await supabase
    .from('album_fotos')
    .select(`
      id, titulo, descricao, tipo_evento, data_evento, created_at,
      album_fotos_imagens (id, imagem_url, ordem),
      album_fotos_reacoes (count),
      album_fotos_comentarios (count),
      album_fotos_visualizacoes (count)
    `)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  const mapped = (albums ?? []).map(a => ({
    ...a,
    imagens: (a.album_fotos_imagens ?? []).sort((x: { ordem: number }, y: { ordem: number }) => x.ordem - y.ordem),
    reacoes_count: (a.album_fotos_reacoes as unknown as { count: number }[])?.[0]?.count ?? 0,
    comentarios_count: (a.album_fotos_comentarios as unknown as { count: number }[])?.[0]?.count ?? 0,
    visualizacoes_count: (a.album_fotos_visualizacoes as unknown as { count: number }[])?.[0]?.count ?? 0,
  }))

  return (
    <AlbumFotosAdminClient
      condominioId={condoId}
      albums={mapped}
    />
  )
}
