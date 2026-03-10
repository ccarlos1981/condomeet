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

  // Load pending + all reservas for the condo
  const { data: reservas } = await supabase
    .from('reservas')
    .select(`
      id, data_reserva, status, created_at,
      areas_comuns(tipo_agenda),
      perfil(nome_completo, bloco_txt, apto_txt, papel_sistema)
    `)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  const { data: tipos } = await supabase
    .from('areas_comuns')
    .select('tipo_agenda')
    .eq('condominio_id', condoId)

  const tiposUnicos = [...new Set((tipos ?? []).map(t => t.tipo_agenda))]

  return (
    <ReservasAdminClient
      reservas={(reservas ?? []) as unknown as ReservaRow[]}
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
