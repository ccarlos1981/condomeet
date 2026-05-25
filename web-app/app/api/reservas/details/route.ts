import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

export async function GET(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const areaId = req.nextUrl.searchParams.get('areaId')
  const date = req.nextUrl.searchParams.get('date')

  if (!areaId || !date) {
    return NextResponse.json({ error: 'Missing parameters' }, { status: 400 })
  }

  const { data: userData } = await supabase
    .from('perfil')
    .select('papel_sistema')
    .eq('id', user.id)
    .single()

  const allowedRoles = ['síndico', 'sindico', 'sub síndico', 'sub sindico', 'admin', 'administrador', 'porteiro', 'portaria', 'zelador']
  const userRole = userData?.papel_sistema?.toLowerCase().trim() || ''
  const canSeeDetails = allowedRoles.includes(userRole)

  const { data, error } = await supabase
    .from('reservas')
    .select(`
      id,
      user_id,
      nome_evento,
      data_reserva,
      areas_comuns_horarios ( hora_inicio ),
      perfil!user_id ( nome_completo, bloco_txt, apto_txt )
    `)
    .eq('area_id', areaId)
    .eq('data_reserva', date)
    .in('status', ['pendente', 'aprovado'])
    .order('created_at', { ascending: true })

  if (error) {
    console.error("Erro detalhes reserva:", error)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  // Filter out personal details if user lacks permission
  const filteredData = data?.map(r => {
    if (!canSeeDetails && r.user_id !== user.id) {
      const { perfil, ...rest } = r
      return rest
    }
    return r
  })

  return NextResponse.json(filteredData)
}
