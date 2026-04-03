import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import OcorrenciasClient from './ocorrencias-client'

export const metadata = { title: 'Ocorrências — Condomeet' }

export default async function OcorrenciasPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, nome_completo')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''
  const role = profile?.papel_sistema ?? ''
  const isAdmin =
    role === 'ADMIN' ||
    role.toLowerCase().includes('síndico') ||
    role.toLowerCase().includes('sindico')

  // Load occurrences
  const query = supabase
    .from('ocorrencias')
    .select('id, resident_id, assunto, description, category, status, photo_url, admin_response, admin_response_at, created_at, updated_at, condominio_id')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })
    .limit(200)

  if (!isAdmin) {
    // residents only see their own
    query.eq('resident_id', user.id)
  }

  const { data: occurrences, error } = await query
  if (error) console.error('❌ ocorrencias error:', JSON.stringify(error))

  // Resolve resident names
  const residentIds = [...new Set((occurrences ?? []).map((o: { resident_id: string }) => o.resident_id).filter(Boolean))]
  const perfilMap: Record<string, { nome_completo: string; bloco_txt: string | null; apto_txt: string | null }> = {}

  if (residentIds.length > 0) {
    const { data: perfis } = await supabase
      .from('perfil')
      .select('id, nome_completo, bloco_txt, apto_txt')
      .in('id', residentIds)
    ;(perfis ?? []).forEach((p: { id: string; nome_completo: string; bloco_txt: string | null; apto_txt: string | null }) => { perfilMap[p.id] = p })
  }

  const occurrencesWithResident = (occurrences ?? []).map((o: { resident_id: string; id: string; assunto: string; description: string; category: string; status: string; photo_url: string | null; admin_response: string | null; admin_response_at: string | null; created_at: string; updated_at: string; condominio_id: string }) => ({
    ...o,
    perfil: perfilMap[o.resident_id] ?? null,
  }))

  return (
    <div className="p-6 lg:p-8 max-w-4xl">
      <div className="mb-6">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">
          {isAdmin ? 'Administração' : 'Meu Apartamento'}
        </p>
        <h1 className="text-2xl font-bold text-gray-900">
          {isAdmin ? 'Ocorrências do Condomínio' : 'Minhas Ocorrências'}
        </h1>
      </div>

      <OcorrenciasClient
        initialOccurrences={occurrencesWithResident}
        isAdmin={isAdmin}
        userId={user.id}
        condoId={condoId}
      />
    </div>
  )
}
