import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import VisitaProprietarioClient from './visita-proprietario-client'

export const metadata = { title: 'Visita Proprietário — Condomeet' }

export default async function VisitaProprietarioPage() {
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

  // Recent visitas (last 100)
  const { data: visitas } = await supabase
    .from('visita_proprietario')
    .select('*')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })
    .limit(100)

  // Get distinct blocos/aptos from resident profiles
  const { data: moradores } = await supabase
    .from('perfil')
    .select('id, nome_completo, bloco_txt, apto_txt')
    .eq('condominio_id', condoId)
    .not('bloco_txt', 'is', null)

  // Build unique sorted lists
  const blocosSet = new Set<string>()
  const aptosPerBloco: Record<string, Set<string>> = {}
  const moradoresPerUnit: Record<string, { id: string; nome: string }[]> = {}

  for (const m of moradores ?? []) {
    if (m.bloco_txt) {
      blocosSet.add(m.bloco_txt)
      if (!aptosPerBloco[m.bloco_txt]) aptosPerBloco[m.bloco_txt] = new Set()
      if (m.apto_txt) {
        aptosPerBloco[m.bloco_txt].add(m.apto_txt)
        const unitKey = `${m.bloco_txt}|${m.apto_txt}`
        if (!moradoresPerUnit[unitKey]) moradoresPerUnit[unitKey] = []
        moradoresPerUnit[unitKey].push({
          id: m.id,
          nome: m.nome_completo ?? 'Sem nome',
        })
      }
    }
  }

  const blocos = [...blocosSet].sort()
  const aptosMap: Record<string, string[]> = {}
  for (const b of blocos) {
    aptosMap[b] = [...(aptosPerBloco[b] ?? [])].sort((a, z) =>
      a.localeCompare(z, 'pt-BR', { numeric: true })
    )
  }

  // Serialize moradoresPerUnit (Set isn't serializable)
  const moradoresMap: Record<string, { id: string; nome: string }[]> = {}
  for (const [key, list] of Object.entries(moradoresPerUnit)) {
    moradoresMap[key] = list
  }

  return (
    <div className="p-6">
      <VisitaProprietarioClient
        visitas={visitas ?? []}
        condoId={condoId}
        currentUserId={user.id}
        currentUserName={profile?.nome_completo ?? ''}
        tipoEstrutura={tipoEstrutura}
        blocos={blocos}
        aptosMap={aptosMap}
        moradoresMap={moradoresMap}
      />
    </div>
  )
}
