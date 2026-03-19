import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import RegistrarVisitanteClient from './registrar-visitante-client'

export const metadata = { title: 'Registrar Visitante — Condomeet' }

export default async function RegistrarVisitantePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, nome_completo, papel_sistema')
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

  // Recent visitors (last 50)
  const { data: visitantes } = await supabase
    .from('visitante_registros')
    .select('*')
    .eq('condominio_id', condoId)
    .order('entrada_at', { ascending: false })
    .limit(50)

  // Get distinct blocos/aptos from resident profiles
  const { data: moradores } = await supabase
    .from('perfil')
    .select('bloco_txt, apto_txt')
    .eq('condominio_id', condoId)
    .not('bloco_txt', 'is', null)

  // Build unique sorted lists
  const blocosSet = new Set<string>()
  const aptosPerBloco: Record<string, Set<string>> = {}
  for (const m of moradores ?? []) {
    if (m.bloco_txt) {
      blocosSet.add(m.bloco_txt)
      if (!aptosPerBloco[m.bloco_txt]) aptosPerBloco[m.bloco_txt] = new Set()
      if (m.apto_txt) aptosPerBloco[m.bloco_txt].add(m.apto_txt)
    }
  }
  const blocos = [...blocosSet].sort()
  const aptosMap: Record<string, string[]> = {}
  for (const b of blocos) {
    aptosMap[b] = [...(aptosPerBloco[b] ?? [])].sort((a, z) => a.localeCompare(z, 'pt-BR', { numeric: true }))
  }

  return (
    <div className="p-6">
      <RegistrarVisitanteClient
        visitantes={visitantes ?? []}
        condoId={condoId}
        currentUserId={user.id}
        currentUserName={profile?.nome_completo ?? ''}
        tipoEstrutura={tipoEstrutura}
        blocos={blocos}
        aptosMap={aptosMap}
      />
    </div>
  )
}
