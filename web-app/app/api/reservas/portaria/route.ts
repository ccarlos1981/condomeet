import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  // Verify role
  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  if (!profile?.condominio_id) return NextResponse.json({ error: 'Perfil não encontrado' }, { status: 404 })

  const role = (profile.papel_sistema ?? '').toLowerCase()
  const allowedRoles = ['portaria', 'porteiro', 'síndico', 'sindico', 'sub', 'admin']
  if (!allowedRoles.some(r => role.includes(r))) {
    return NextResponse.json({ error: 'Acesso negado' }, { status: 403 })
  }

  const { area_id, horario_id, data_reserva, nome_evento, bloco, apto, morador_id } = await req.json()

  if (!area_id || !data_reserva || !bloco || !apto) {
    return NextResponse.json({ error: 'area_id, data_reserva, bloco e apto são obrigatórios' }, { status: 400 })
  }

  // Get area config
  const { data: area } = await supabase
    .from('areas_comuns')
    .select('aprovacao_automatica, limite_acesso, tipo_reserva')
    .eq('id', area_id)
    .single()

  if (!area) return NextResponse.json({ error: 'Área não encontrada' }, { status: 404 })

  // Check conflict
  const conflictQ = supabase
    .from('reservas')
    .select('id')
    .eq('area_id', area_id)
    .eq('data_reserva', data_reserva)
    .in('status', ['pendente', 'aprovado'])

  if (horario_id) conflictQ.eq('horario_id', horario_id)

  const { data: conflict } = await conflictQ
  if (conflict && conflict.length > 0) {
    return NextResponse.json({ error: 'Este horário já está reservado.' }, { status: 409 })
  }

  const status = area.aprovacao_automatica ? 'aprovado' : 'pendente'

  const { data: reserva, error } = await supabase
    .from('reservas')
    .insert({
      area_id,
      horario_id: horario_id ?? null,
      user_id: morador_id || null,
      condominio_id: profile.condominio_id,
      data_reserva,
      nome_evento: nome_evento ?? null,
      status,
      criado_por_portaria: true,
      bloco_destino: bloco,
      apto_destino: apto,
      criado_por: user.id,
    })
    .select()
    .single()

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json(reserva, { status: 201 })
}
