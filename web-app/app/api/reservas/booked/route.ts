import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

// GET /api/reservas/booked?areaId=...&year=...&month=...
// Returns array of ISO date strings (YYYY-MM-DD) already booked for that area+month
export async function GET(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const areaId = req.nextUrl.searchParams.get('areaId')
  const year   = req.nextUrl.searchParams.get('year')
  const month  = req.nextUrl.searchParams.get('month')
  if (!areaId || !year || !month) return NextResponse.json([], { status: 200 })

  const m = String(month).padStart(2, '0')
  const firstOfMonth = `${year}-${m}-01`
  const lastDay = new Date(Number(year), Number(month), 0).getDate()
  const lastOfMonth = `${year}-${m}-${String(lastDay).padStart(2, '0')}`

  const { data } = await supabase
    .from('reservas')
    .select('data_reserva')
    .eq('area_id', areaId)
    .in('status', ['pendente', 'aprovado'])
    .gte('data_reserva', firstOfMonth)
    .lte('data_reserva', lastOfMonth)

  const dates = [...new Set((data ?? []).map((r: { data_reserva: string }) => r.data_reserva))]
  return NextResponse.json(dates)
}
