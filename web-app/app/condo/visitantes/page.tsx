import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import VisitantesResidentClient from './visitantes-client'

export const metadata = { title: 'Autorizar Visitante — Condomeet' }

export default async function VisitantesPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, nome_completo, bloco_txt, apto_txt')
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

  // Morador só vê os próprios convites — carregar os 5 últimos
  const { data: convites, error } = await supabase
    .from('convites')
    .select('id, qr_data, guest_name, visitor_type, visitante_compareceu, validity_date, created_at, liberado_em, status')
    .eq('resident_id', user.id)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })
    .limit(5)

  if (error) console.error('❌ visitantes error:', JSON.stringify(error))

  return (
    <div className="p-6 lg:p-8 max-w-4xl">
      <div className="mb-6">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">Acesso</p>
        <h1 className="text-2xl font-bold text-gray-900">Autorizar Visitante</h1>
        <p className="text-sm text-gray-500 mt-1">
          Gere autorizações para seus visitantes entrarem no condomínio
        </p>
      </div>

      <VisitantesResidentClient
        initialConvites={convites ?? []}
        userId={user.id}
        condoId={condoId}
        residentName={profile?.nome_completo ?? ''}
        bloco={profile?.bloco_txt ?? ''}
        apto={profile?.apto_txt ?? ''}
        tipoEstrutura={tipoEstrutura}
      />
    </div>
  )
}
