import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

// POST — Toggle reaction (one reaction per user per album)
// If same emoji → remove. If different emoji → replace. If none → add.
export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { album_id, emoji } = await req.json()
  if (!album_id || !emoji) {
    return NextResponse.json({ error: 'album_id e emoji são obrigatórios' }, { status: 400 })
  }

  // Check if user already has a reaction on this album
  const { data: existing } = await supabase
    .from('album_fotos_reacoes')
    .select('id, emoji')
    .eq('album_id', album_id)
    .eq('user_id', user.id)
    .maybeSingle()

  if (existing) {
    if (existing.emoji === emoji) {
      // Same emoji → remove (toggle off)
      await supabase.from('album_fotos_reacoes').delete().eq('id', existing.id)
      return NextResponse.json({ action: 'removed' })
    } else {
      // Different emoji → replace
      await supabase.from('album_fotos_reacoes')
        .update({ emoji })
        .eq('id', existing.id)
      return NextResponse.json({ action: 'replaced', previous_emoji: existing.emoji })
    }
  } else {
    // No existing reaction → add
    const { error } = await supabase
      .from('album_fotos_reacoes')
      .insert({ album_id, user_id: user.id, emoji })

    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json({ action: 'added' })
  }
}
