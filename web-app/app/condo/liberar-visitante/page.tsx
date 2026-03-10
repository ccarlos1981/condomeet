import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import VisitorList from './visitor-list'

export default async function LiberarVisitantePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // 1) Fetch convites without join — only real columns from migrations
  const { data: convites, error: convitesError } = await supabase
    .from('convites')
    .select('id, qr_data, guest_name, visitor_type, visitante_compareceu, validity_date, created_at, liberado_em, resident_id, status')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  if (convitesError) console.error('❌ convites:', JSON.stringify(convitesError))

  // 2) Fetch perfil for those residents
  const residentIds = [...new Set((convites ?? []).map((c: any) => c.resident_id).filter(Boolean))]
  let perfilMap: Record<string, { nome_completo: string; bloco_txt: string | null; apto_txt: string | null }> = {}

  if (residentIds.length > 0) {
    const { data: perfis } = await supabase
      .from('perfil')
      .select('id, nome_completo, bloco_txt, apto_txt')
      .in('id', residentIds)
    ;(perfis ?? []).forEach((p: any) => { perfilMap[p.id] = p })
  }

  // 3) Merge
  const invitations = (convites ?? []).map((c: any) => ({
    ...c,
    perfil: perfilMap[c.resident_id] ?? null,
  }))

  return (
    <div className="p-6 lg:p-8 max-w-5xl">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Autorização prévia de visitante</h1>
      </div>
      <VisitorList
        initialInvitations={invitations}
        condoId={condoId}
        userId={user.id}
      />
    </div>
  )
}

