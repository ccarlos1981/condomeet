import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import HorariosClient from './horarios-client'

export default async function HorariosPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: area } = await supabase
    .from('areas_comuns')
    .select('id, tipo_agenda, tipo_reserva')
    .eq('id', id)
    .single()

  if (!area || area.tipo_reserva !== 'por_hora') redirect('/admin/areas-comuns')

  const { data: horarios } = await supabase
    .from('areas_comuns_horarios')
    .select('*')
    .eq('area_id', id)
    .order('dia_semana')
    .order('hora_inicio')

  return (
    <HorariosClient
      areaId={id}
      tipoAgenda={area.tipo_agenda}
      initialHorarios={horarios ?? []}
    />
  )
}
