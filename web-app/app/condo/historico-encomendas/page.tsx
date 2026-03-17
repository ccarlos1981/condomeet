import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ParcelList from '../encomendas/parcel-list'

export const metadata = { title: 'Histórico de Encomendas — Condomeet' }

export default async function HistoricoEncomendasPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Load DELIVERED parcels for the condominium
  const { data: parcels, error } = await supabase
    .from('encomendas')
    .select('id, resident_id, status, arrival_time, delivery_time, tipo, tracking_code, observacao, photo_url, pickup_proof_url, condominio_id, picked_up_by_id, picked_up_by_name')
    .eq('condominio_id', condoId)
    .eq('status', 'delivered')
    .order('delivery_time', { ascending: false })
    .limit(200)

  if (error) console.error('❌ parcels history error:', JSON.stringify(error))

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
  })) as { id: string; resident_id: string; status: string; arrival_time: string; delivery_time: string | null; tipo: string | null; tracking_code: string | null; observacao: string | null; photo_url: string | null; pickup_proof_url: string | null; condominio_id: string; picked_up_by_id: string | null; picked_up_by_name: string | null; perfil: { id: string; nome_completo: string; bloco_txt: string | null; apto_txt: string | null } | null }[]

  return (
    <div className="p-6 lg:p-8 max-w-5xl">
      <div className="mb-6">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">
          Gestão
        </p>
        <h1 className="text-2xl font-bold text-gray-900">
          Histórico de Encomendas
        </h1>
        <p className="text-sm text-gray-500 mt-1">Encomendas já entregues</p>
      </div>

      <ParcelList
        initialParcels={parcelsWithResident}
        isPorter={true}
        userId={user.id}
        condoId={condoId}
      />
    </div>
  )
}
