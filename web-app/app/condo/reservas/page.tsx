import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ReservasClient from './reservas-client'

export default async function ReservasPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, nome_completo, bloco_txt, apto_txt')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Load active areas for this condo
  const { data: areas } = await supabase
    .from('areas_comuns')
    .select('id, tipo_agenda, local, outro_local, tipo_reserva, capacidade, limite_acesso, hrs_cancelar, precos, instrucao_uso, aprovacao_automatica')
    .eq('condominio_id', condoId)
    .eq('ativo', true)
    .order('tipo_agenda')

  // Load resident's own reservations
  const { data: minhasReservas } = await supabase
    .from('reservas')
    .select('id, data_reserva, status, nome_evento, created_at, areas_comuns(tipo_agenda), areas_comuns_horarios(hora_inicio)')
    .eq('user_id', user.id)
    .order('data_reserva', { ascending: false })
    .limit(20)

  return (
    <ReservasClient
      areas={(areas ?? []) as AreaComum[]}
      minhasReservas={(minhasReservas ?? []) as unknown as MinhaReserva[]}
      profile={{
        nome: profile?.nome_completo ?? '',
        bloco: profile?.bloco_txt ?? '',
        apto: profile?.apto_txt ?? '',
      }}
    />
  )
}

export interface AreaComum {
  id: string
  tipo_agenda: string
  local: string
  outro_local?: string
  tipo_reserva: 'por_dia' | 'por_hora'
  capacidade: number
  limite_acesso: number
  hrs_cancelar: number
  precos: { valor: number; regra: string }[]
  instrucao_uso?: string
  aprovacao_automatica: boolean
}

export interface MinhaReserva {
  id: string
  data_reserva: string
  status: string
  nome_evento: string | null
  created_at: string
  areas_comuns: { tipo_agenda: string }
  areas_comuns_horarios: { hora_inicio: string } | null
}
