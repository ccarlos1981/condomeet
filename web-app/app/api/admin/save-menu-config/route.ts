import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function POST(request: Request) {
  try {
    const { condominioId, config } = await request.json()
    if (!condominioId || !config) {
      return NextResponse.json({ error: 'Missing condominioId or config' }, { status: 400 })
    }

    const supabase = await createClient()

    // Auth check
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

    const { data: profile } = await supabase
      .from('perfil')
      .select('papel_sistema, condominio_id')
      .eq('id', user.id)
      .single()

    const isAdmin = ['síndico', 'sindico', 'admin'].some(r =>
      (profile?.papel_sistema ?? '').toLowerCase().includes(r)
    )
    if (!isAdmin || profile?.condominio_id !== condominioId) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const { error } = await supabase
      .from('condominios')
      .update({ features_config: config })
      .eq('id', condominioId)

    if (error) throw error

    return NextResponse.json({ ok: true })
  } catch (err) {
    console.error('[save-menu-config]', err)
    return NextResponse.json({ error: String(err) }, { status: 500 })
  }
}
