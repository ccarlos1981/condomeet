import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

// POST — Toggle reaction (insert or delete)
export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { album_id, emoji } = await req.json()
  if (!album_id || !emoji) {
    return NextResponse.json({ error: 'album_id e emoji são obrigatórios' }, { status: 400 })
  }

  // Check if reaction already exists
  const { data: existing } = await supabase
    .from('album_fotos_reacoes')
    .select('id')
    .eq('album_id', album_id)
    .eq('user_id', user.id)
    .eq('emoji', emoji)
    .maybeSingle()

  if (existing) {
    // Remove reaction
    await supabase.from('album_fotos_reacoes').delete().eq('id', existing.id)
    return NextResponse.json({ action: 'removed' })
  } else {
    // Add reaction
    const { error } = await supabase
      .from('album_fotos_reacoes')
      .insert({ album_id, user_id: user.id, emoji })

    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json({ action: 'added' })
  }
}
