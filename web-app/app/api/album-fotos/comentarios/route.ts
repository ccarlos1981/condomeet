import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

// POST — Add comment (with optional parent_id for replies)
export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { album_id, conteudo, parent_id } = await req.json()
  if (!album_id || !conteudo?.trim()) {
    return NextResponse.json({ error: 'album_id e conteudo são obrigatórios' }, { status: 400 })
  }

  const { data, error } = await supabase
    .from('album_fotos_comentarios')
    .insert({
      album_id,
      user_id: user.id,
      conteudo: conteudo.trim(),
      parent_id: parent_id || null,
    })
    .select(`
      id, conteudo, created_at, parent_id,
      perfil:user_id (id, nome_completo)
    `)
    .single()

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json(data, { status: 201 })
}

// DELETE — Delete own comment
export async function DELETE(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const id = req.nextUrl.searchParams.get('id')
  if (!id) return NextResponse.json({ error: 'id é obrigatório' }, { status: 400 })

  const { error } = await supabase
    .from('album_fotos_comentarios')
    .delete()
    .eq('id', id)

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}
