import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

// GET /api/reservas/horarios?areaId=...&data=YYYY-MM-DD
export async function GET(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const areaId = req.nextUrl.searchParams.get('areaId')
  const data = req.nextUrl.searchParams.get('data')
  if (!areaId || !data) return NextResponse.json({ error: 'areaId and data required' }, { status: 400 })

  // Get day of week from date
  const date = new Date(data + 'T12:00:00')
  const DIAS = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab']
  const diaSemana = DIAS[date.getDay()]

  // Fetch all active time slots for that day
  const { data: horarios } = await supabase
    .from('areas_comuns_horarios')
    .select('id, hora_inicio, duracao_minutos')
    .eq('area_id', areaId)
    .eq('dia_semana', diaSemana)
    .eq('ativo', true)
    .order('hora_inicio')

  // Fetch already booked slots for that date
  const { data: reservasFeitas } = await supabase
    .from('reservas')
    .select('horario_id')
    .eq('area_id', areaId)
    .eq('data_reserva', data)
    .in('status', ['pendente', 'aprovado'])

  const ocupados = new Set((reservasFeitas ?? []).map((r: { horario_id: string | null }) => r.horario_id))

  const result = (horarios ?? []).map((h: { id: string; hora_inicio: string; duracao_minutos: number }) => ({
    ...h,
    disponivel: !ocupados.has(h.id),
  }))

  return NextResponse.json(result)
}
