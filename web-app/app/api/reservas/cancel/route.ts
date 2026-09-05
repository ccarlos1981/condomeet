import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { reserva_id } = await req.json()
  if (!reserva_id) return NextResponse.json({ error: 'reserva_id required' }, { status: 400 })

  // 1. Get the reservation with user info
  const { data: reserva, error: rErr } = await supabase
    .from('reservas')
    .select('id, data_reserva, status, area_id, user_id, condominio_id')
    .eq('id', reserva_id)
    .single()

  if (rErr || !reserva) return NextResponse.json({ error: 'Reserva não encontrada' }, { status: 404 })

  // 2. Get area name
  const { data: area } = await supabase
    .from('areas_comuns')
    .select('tipo_agenda')
    .eq('id', reserva.area_id)
    .single()

  // 3. Update status to cancelado (Triggers tr_reserva_status_changed -> reserva-notify)
  const { error: updErr } = await supabase
    .from('reservas')
    .update({ status: 'cancelado', updated_at: new Date().toISOString() })
    .eq('id', reserva_id)

  if (updErr) return NextResponse.json({ error: updErr.message }, { status: 500 })

  return NextResponse.json({
    success: true,
  })
}
