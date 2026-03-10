import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { aviso_id } = await req.json()
  if (!aviso_id) return NextResponse.json({ error: 'aviso_id required' }, { status: 400 })

  // upsert — ignore if already exists
  const { error } = await supabase
    .from('avisos_lidos')
    .upsert({ aviso_id, user_id: user.id }, { onConflict: 'aviso_id,user_id' })

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}
