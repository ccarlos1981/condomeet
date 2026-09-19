import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ReservasAdminClient from './reservas-admin-client'
import { filterResidentialBlocos, filterResidentialAptos } from '@/lib/labels'

export default async function ReservasAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil').select('condominio_id').eq('id', user.id).single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch tipo
  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condoData?.tipo ?? 'predio'

  // Load all areas_comuns for this condominium
  const { data: todasAreas } = await supabase
    .from('areas_comuns')
    .select('id, tipo_agenda, local, outro_local, precos')
    .eq('condominio_id', condoId)
    .order('tipo_agenda')

  const areaList = todasAreas ?? []
  const areaMap = Object.fromEntries(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    areaList.map((a: any) => [a.id, a])
  )

  // Load blocos and aptos from perfil in this condominium
  const { data: perfisCondo } = await supabase
    .from('perfil')
    .select('bloco_txt, apto_txt')
    .eq('condominio_id', condoId)
    .not('bloco_txt', 'is', null)
    .not('apto_txt', 'is', null)

  const rawBlocos = [...new Set((perfisCondo ?? []).map((p: { bloco_txt?: string }) => p.bloco_txt?.trim()).filter(Boolean) as string[])].sort()
  const blocos = filterResidentialBlocos(rawBlocos)
  const aptosPorBloco: Record<string, string[]> = {}
  for (const b of blocos) {
    const rawAptos = [...new Set(
      (perfisCondo ?? [])
        .filter((p: { bloco_txt?: string }) => p.bloco_txt?.trim() === b)
        .map((p: { apto_txt?: string }) => p.apto_txt?.trim())
        .filter(Boolean) as string[]
    )].sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
    aptosPorBloco[b] = filterResidentialAptos(rawAptos)
  }
  const rawTodosAptos = [...new Set(
    (perfisCondo ?? []).map((p: { apto_txt?: string }) => p.apto_txt?.trim()).filter(Boolean) as string[]
  )].sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
  const todosAptos = filterResidentialAptos(rawTodosAptos)

  // Load reservas
  const { data: reservas } = await supabase
    .from('reservas')
    .select('id, data_reserva, status, created_at, area_id, user_id, nome_evento, valor_reserva, status_pagamento')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  const reservaList = reservas ?? []

  // Fetch moradores separately
  const moradorIds = [...new Set(reservaList.map((r: { user_id: string }) => r.user_id).filter(Boolean))]
  const { data: moradores } = moradorIds.length > 0
    ? await supabase
        .from('perfil')
        .select('id, nome_completo, bloco_txt, apto_txt, papel_sistema, whatsapp, botconversa_id')
        .in('id', moradorIds)
    : { data: [] }

  const moradorMap = Object.fromEntries(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (moradores ?? []).map((m: any) => [m.id, m])
  )

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const withProfiles: any[] = reservaList.map((r: Record<string, unknown>) => ({
    ...r,
    areas_comuns: areaMap[r.area_id as string] ?? null,
    perfil: moradorMap[r.user_id as string] ?? null,
  }))

  return (
    <ReservasAdminClient
      reservas={withProfiles as unknown as ReservaRow[]}
      areas={areaList}
      blocos={blocos}
      aptosPorBloco={aptosPorBloco}
      todosAptos={todosAptos}
      tipoEstrutura={tipoEstrutura}
    />
  )
}

export interface AreaItem {
  id: string
  tipo_agenda: string
  local?: string
  outro_local?: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  precos?: any[]
}

export interface ReservaRow {
  id: string
  data_reserva: string
  status: string
  created_at: string
  user_id: string
  area_id?: string
  nome_evento?: string
  valor_reserva?: number
  status_pagamento?: string
  areas_comuns: AreaItem
  perfil: { nome_completo: string; bloco_txt: string; apto_txt: string; papel_sistema: string; whatsapp?: string; botconversa_id?: string }
}
