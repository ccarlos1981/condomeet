import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ReservasAdminClient from './reservas-admin-client'

export default async function ReservasAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil').select('condominio_id').eq('id', user.id).single()

  const condoId = profile?.condominio_id ?? ''

  // Load reservas without FK join
  const { data: reservas } = await supabase
    .from('reservas')
    .select('id, data_reserva, status, created_at, area_id, user_id')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  const reservaList = reservas ?? []

  // Fetch areas_comuns separately
  const areaIds = [...new Set(reservaList.map((r: { area_id: string }) => r.area_id).filter(Boolean))]
  const { data: areas } = areaIds.length > 0
    ? await supabase
        .from('areas_comuns')
        .select('id, tipo_agenda')
        .in('id', areaIds)
    : { data: [] }

  const areaMap = Object.fromEntries(
    (areas ?? []).map((a: { id: string; tipo_agenda: string }) => [a.id, a])
  )

  // Fetch moradores separately
  const moradorIds = [...new Set(reservaList.map((r: { user_id: string }) => r.user_id).filter(Boolean))]
  const { data: moradores } = moradorIds.length > 0
    ? await supabase
        .from('perfil')
        .select('id, nome_completo, bloco_txt, apto_txt, papel_sistema')
        .in('id', moradorIds)
    : { data: [] }

  const moradorMap = Object.fromEntries(
    (moradores ?? []).map((m: { id: string; nome_completo: string; bloco_txt: string; apto_txt: string; papel_sistema: string }) => [m.id, m])
  )

  const { data: tipos } = await supabase
    .from('areas_comuns')
    .select('tipo_agenda')
    .eq('condominio_id', condoId)

  const tiposUnicos = [...new Set((tipos ?? []).map(t => t.tipo_agenda))]

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const withProfiles: any[] = reservaList.map((r: Record<string, unknown>) => ({
    ...r,
    areas_comuns: areaMap[r.area_id as string] ?? null,
    perfil: moradorMap[r.user_id as string] ?? null,
  }))

  return (
    <ReservasAdminClient
      reservas={withProfiles as unknown as ReservaRow[]}
      tiposAgenda={tiposUnicos}
    />
  )
}

export interface ReservaRow {
  id: string
  data_reserva: string
  status: string
  created_at: string
  areas_comuns: { tipo_agenda: string }
  perfil: { nome_completo: string; bloco_txt: string; apto_txt: string; papel_sistema: string }
}
