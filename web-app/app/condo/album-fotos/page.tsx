import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AlbumFotosCondoClient from './album-fotos-condo-client'

export default async function AlbumFotosCondoPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, nome_completo')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Load albums with images, reactions, comments
  const { data: albums } = await supabase
    .from('album_fotos')
    .select(`
      id, titulo, descricao, tipo_evento, data_evento, created_at,
      perfil:autor_id (nome_completo),
      album_fotos_imagens (id, imagem_url, ordem),
      album_fotos_reacoes (id, user_id, emoji),
      album_fotos_comentarios (
        id, conteudo, created_at, parent_id,
        perfil:user_id (id, nome_completo)
      ),
      album_fotos_visualizacoes (count)
    `)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  const mapped = (albums ?? []).map(a => ({
    ...a,
    autor_nome: (a.perfil as unknown as { nome_completo: string })?.nome_completo ?? 'Administrador',
    imagens: (a.album_fotos_imagens ?? []).sort((x: { ordem: number }, y: { ordem: number }) => x.ordem - y.ordem),
    reacoes: a.album_fotos_reacoes ?? [],
    comentarios: (a.album_fotos_comentarios ?? []).sort(
      (x: { created_at: string }, y: { created_at: string }) => new Date(x.created_at).getTime() - new Date(y.created_at).getTime()
    ),
    visualizacoes_count: (a.album_fotos_visualizacoes as unknown as { count: number }[])?.[0]?.count ?? 0,
  }))

  return (
    <AlbumFotosCondoClient
      albums={mapped}
      userId={user.id}
      userName={profile?.nome_completo ?? ''}
    />
  )
}
