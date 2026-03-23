import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

// POST — Mark album as viewed
export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { album_id } = await req.json()
  if (!album_id) {
    return NextResponse.json({ error: 'album_id é obrigatório' }, { status: 400 })
  }

  // Upsert — ignore if already viewed
  const { error } = await supabase
    .from('album_fotos_visualizacoes')
    .upsert(
      { album_id, user_id: user.id },
      { onConflict: 'album_id,user_id' }
    )

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}
