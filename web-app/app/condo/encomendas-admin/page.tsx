import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ParcelList from '../encomendas/parcel-list'

export const metadata = { title: 'Encomendas do Condomínio — Condomeet' }

export default async function EncomendasAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const role = profile?.papel_sistema ?? ''
  const isAdmin =
    role.toLowerCase().includes('portaria') ||
    role.toLowerCase().includes('porteiro') ||
    role.toLowerCase().includes('síndico') ||
    role.toLowerCase().includes('sindico') ||
    role === 'admin'

  // Only admin/porter/sindico can access this page
  // if (!isAdmin) redirect('/condo/encomendas')

  const condoId = profile?.condominio_id ?? ''

  // Load ALL parcels for the condominium
  const { data: parcels, error } = await supabase
    .from('encomendas')
    .select('id, resident_id, status, arrival_time, delivery_time, tipo, tracking_code, observacao, photo_url, pickup_proof_url, condominio_id, picked_up_by_id, picked_up_by_name, bloco, apto')
    .eq('condominio_id', condoId)
    .order('arrival_time', { ascending: false })
    .limit(200)

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
      <div className="mb-6 flex items-center justify-between flex-wrap gap-3">
        <div>
          <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">
            Gestão
          </p>
          <h1 className="text-2xl font-bold text-gray-900">
            Encomendas do Condomínio
          </h1>
        </div>
        {isAdmin && (
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
        isPorter={isAdmin}
        userId={user.id}
        condoId={condoId}
      />
    </div>
  )
}
