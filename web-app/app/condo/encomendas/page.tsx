import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ParcelList from './parcel-list'

export const metadata = { title: 'Minhas Encomendas — Condomeet' }

export default async function EncomendasPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, nome_completo, bloco_txt, apto_txt')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Always filter by unit (bloco + apto) — this is "Minhas Encomendas"
  let query = supabase
    .from('encomendas')
    .select('id, resident_id, status, arrival_time, delivery_time, tipo, tracking_code, observacao, photo_url, pickup_proof_url, condominio_id, picked_up_by_id, picked_up_by_name, bloco, apto')
    .eq('condominio_id', condoId)
    .order('arrival_time', { ascending: false })
    .limit(200)

  if (profile?.bloco_txt && profile?.apto_txt) {
    // Get all residents in the same unit
    const { data: unitResidents } = await supabase
      .from('perfil')
      .select('id')
      .eq('condominio_id', condoId)
      .eq('bloco_txt', profile.bloco_txt)
      .eq('apto_txt', profile.apto_txt)
    
    const unitIds = (unitResidents ?? []).map((r: { id: string }) => r.id)
    if (unitIds.length > 0) {
      query = query.in('resident_id', unitIds)
    } else {
      query = query.eq('resident_id', user.id)
    }
  } else {
    query = query.eq('resident_id', user.id)
  }

  const { data: parcels, error } = await query
  if (error) console.error('❌ parcels error:', JSON.stringify(error))

  // Resolve resident names
  const residentIds = [...new Set((parcels ?? []).map((p: { resident_id: string }) => p.resident_id).filter(Boolean))]
  const perfilMap: Record<string, { id: string; nome_completo: string; bloco_txt: string | null; apto_txt: string | null }> = {}

  if (residentIds.length > 0) {
    const { data: perfis } = await supabase
      .from('perfil')
      .select('id, nome_completo, bloco_txt, apto_txt')
      .in('id', residentIds)
    ;(perfis ?? []).forEach((p: { id: string; nome_completo: string; bloco_txt: string | null; apto_txt: string | null }) => { perfilMap[p.id] = p })
  }

  const parcelsWithResident = (parcels ?? []).map((p: { resident_id: string; [key: string]: unknown }) => ({
    ...p,
    perfil: perfilMap[p.resident_id] ?? null,
  })) as { id: string; resident_id: string; status: string; arrival_time: string; delivery_time: string | null; tipo: string | null; tracking_code: string | null; observacao: string | null; photo_url: string | null; pickup_proof_url: string | null; condominio_id: string; picked_up_by_id: string | null; picked_up_by_name: string | null; bloco: string | null; apto: string | null; perfil: { id: string; nome_completo: string; bloco_txt: string | null; apto_txt: string | null } | null }[]

  return (
    <div className="p-6 lg:p-8 max-w-5xl">
      <div className="mb-6">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">
          Meu Apartamento
        </p>
        <h1 className="text-2xl font-bold text-gray-900">
          Minhas Encomendas
        </h1>
      </div>

      <ParcelList
        initialParcels={parcelsWithResident}
        isPorter={false}
        userId={user.id}
        condoId={condoId}
      />
    </div>
  )
}
