import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ParcelList from './parcel-list'

export const metadata = { title: 'Encomendas — Condomeet' }

export default async function EncomendasPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, nome_completo')
    .eq('id', user.id)
    .single()

  const role = profile?.papel_sistema ?? ''
  const isPorter =
    role.toLowerCase().includes('portaria') ||
    role.toLowerCase().includes('porteiro') ||
    role.toLowerCase().includes('síndico') ||
    role.toLowerCase().includes('sindico') ||
    role === 'admin'

  const condoId = profile?.condominio_id ?? ''

  // Load parcels: porter sees all, resident sees own
  const query = supabase
    .from('encomendas')
    .select('id, resident_id, status, arrival_time, delivery_time, tipo, tracking_code, observacao, photo_url, pickup_proof_url, condominio_id, picked_up_by_id, picked_up_by_name')
    .eq('condominio_id', condoId)
    .order('arrival_time', { ascending: false })
    .limit(200)

  if (!isPorter) {
    query.eq('resident_id', user.id)
  }

  const { data: parcels, error } = await query
  if (error) console.error('❌ parcels error:', JSON.stringify(error))

  // Resolve resident names
  const residentIds = [...new Set((parcels ?? []).map((p: any) => p.resident_id).filter(Boolean))]
  let perfilMap: Record<string, { nome_completo: string; bloco_txt: string | null; apto_txt: string | null }> = {}

  if (residentIds.length > 0) {
    const { data: perfis } = await supabase
      .from('perfil')
      .select('id, nome_completo, bloco_txt, apto_txt')
      .in('id', residentIds)
    ;(perfis ?? []).forEach((p: any) => { perfilMap[p.id] = p })
  }

  const parcelsWithResident = (parcels ?? []).map((p: any) => ({
    ...p,
    perfil: perfilMap[p.resident_id] ?? null,
  }))

  return (
    <div className="p-6 lg:p-8 max-w-5xl">
      <div className="mb-6 flex items-center justify-between flex-wrap gap-3">
        <div>
          <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">
            {isPorter ? 'Portaria' : 'Meu Apartamento'}
          </p>
          <h1 className="text-2xl font-bold text-gray-900">
            {isPorter ? 'Encomendas do Condomínio' : 'Minhas Encomendas'}
          </h1>
        </div>
        {isPorter && (
          <a
            href="/condo/registrar-encomenda"
            className="flex items-center gap-2 bg-[#FC5931] text-white text-sm font-semibold px-5 py-2.5 rounded-xl hover:bg-[#D42F1D] transition-colors shadow-sm"
          >
            + Nova Encomenda
          </a>
        )}
      </div>

      <ParcelList
        initialParcels={parcelsWithResident}
        isPorter={isPorter}
        userId={user.id}
        condoId={condoId}
      />
    </div>
  )
}
