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

  // Load albums without FK joins
  const { data: albums } = await supabase
    .from('album_fotos')
    .select(`
      id, titulo, descricao, tipo_evento, data_evento, created_at, autor_id,
      album_fotos_imagens (id, imagem_url, ordem),
      album_fotos_reacoes (id, user_id, emoji),
      album_fotos_comentarios (id, conteudo, created_at, parent_id, user_id),
      album_fotos_visualizacoes (count)
    `)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  const albumList = albums ?? []

  // Fetch all unique user IDs (authors + commenters) in one query
  const autorIds = [...new Set(albumList.map((a: { autor_id: string }) => a.autor_id))]
  const commenterIds = albumList.flatMap((a: Record<string, unknown>) =>
    ((a.album_fotos_comentarios as { user_id: string }[]) ?? []).map(c => c.user_id)
  )
  const allUserIds = [...new Set([...autorIds, ...commenterIds])]

  const { data: perfis } = allUserIds.length > 0
    ? await supabase
        .from('perfil')
        .select('id, nome_completo')
        .in('id', allUserIds)
    : { data: [] }

  const perfilMap = Object.fromEntries(
    (perfis ?? []).map((p: { id: string; nome_completo: string }) => [p.id, p.nome_completo])
  )

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const mapped: any[] = albumList.map((a: Record<string, unknown>) => ({
    ...a,
    autor_nome: perfilMap[a.autor_id as string] ?? 'Administrador',
    imagens: ((a.album_fotos_imagens as { ordem: number }[]) ?? [])
      .sort((x, y) => x.ordem - y.ordem),
    reacoes: a.album_fotos_reacoes ?? [],
    comentarios: ((a.album_fotos_comentarios as { user_id: string; created_at: string }[]) ?? [])
      .map(c => ({
        ...c,
        perfil: { id: c.user_id, nome_completo: perfilMap[c.user_id] ?? 'Morador' },
      }))
      .sort((x, y) => new Date(x.created_at).getTime() - new Date(y.created_at).getTime()),
    visualizacoes_count: (a.album_fotos_visualizacoes as { count: number }[])?.[0]?.count ?? 0,
  }))

  return (
    <AlbumFotosCondoClient
      albums={mapped}
      userId={user.id}
      userName={profile?.nome_completo ?? ''}
    />
  )
}
