import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import VisitorList from './visitor-list'

export default async function VisitanteCheckinPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch tipo_estrutura from condominios
  const { data: condo } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condo?.tipo_estrutura ?? 'predio'

  // Fetch initial page of convites (10 items, pendentes by default)
  const { data: convites, count } = await supabase
    .from('convites')
    .select('id, qr_data, guest_name, visitor_type, visitante_compareceu, validity_date, created_at, liberado_em, resident_id, status, criado_por_portaria, bloco_destino, apto_destino, morador_nome_manual', { count: 'exact' })
    .eq('condominio_id', condoId)
    .eq('visitante_compareceu', false)
    .order('created_at', { ascending: false })
    .range(0, 9)

  // Fetch perfil for those residents
  const residentIds = [...new Set((convites ?? []).map((c: any) => c.resident_id).filter(Boolean))]
  let perfilMap: Record<string, { nome_completo: string; bloco_txt: string | null; apto_txt: string | null }> = {}

  if (residentIds.length > 0) {
    const { data: perfis } = await supabase
      .from('perfil')
      .select('id, nome_completo, bloco_txt, apto_txt')
      .in('id', residentIds)
    ;(perfis ?? []).forEach((p: any) => { perfilMap[p.id] = p })
  }

  // Merge
  const invitations = (convites ?? []).map((c: any) => ({
    ...c,
    perfil: perfilMap[c.resident_id] ?? null,
  }))

  return (
    <div className="p-6 lg:p-8 max-w-5xl">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Visitante c/ Autorização</h1>
        <p className="text-sm text-gray-500 mt-1">Check-in de visitantes com autorização prévia</p>
      </div>
      <VisitorList
        initialInvitations={invitations}
        initialTotal={count ?? invitations.length}
        condoId={condoId}
        userId={user.id}
        tipoEstrutura={tipoEstrutura}
      />
    </div>
  )
}
