import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import EnquetesAdminClient from './enquetes-admin-client'

export default async function EnquetesAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Load enquetes with options
  const { data: enquetes } = await supabase
    .from('enquetes')
    .select(`
      id, pergunta, tipo_resposta, ativa, validade, created_at,
      enquete_opcoes(id, texto, ordem)
    `)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  // Total unique units (bloco+apto combos) for response %
  const { data: unitsRaw } = await supabase
    .from('perfil')
    .select('bloco_txt, apto_txt')
    .eq('condominio_id', condoId)
    .eq('status_aprovacao', 'aprovado')
    .not('bloco_txt', 'is', null)
    .not('apto_txt', 'is', null)

  const uniqueUnits = new Set(
    (unitsRaw ?? []).map(u => `${u.bloco_txt}-${u.apto_txt}`)
  )

  // For each enquete, count unique responding units (bloco+apto)
  const enqueteIds = (enquetes ?? []).map(e => e.id)
  let unitCountMap: Record<string, number> = {}

  if (enqueteIds.length > 0) {
    // Fetch all responses with bloco/apto to count unique units per enquete
    const { data: allRespostas } = await supabase
      .from('enquete_respostas')
      .select('enquete_id, bloco, apto')
      .in('enquete_id', enqueteIds)

    // Group by enquete_id and count unique bloco+apto combos
    const enqueteUnitSets: Record<string, Set<string>> = {}
    for (const r of (allRespostas ?? [])) {
      if (!r.bloco || !r.apto) continue
      if (!enqueteUnitSets[r.enquete_id]) {
        enqueteUnitSets[r.enquete_id] = new Set()
      }
      enqueteUnitSets[r.enquete_id].add(`${r.bloco}-${r.apto}`)
    }
    for (const [eid, unitSet] of Object.entries(enqueteUnitSets)) {
      unitCountMap[eid] = unitSet.size
    }
  }

  return (
    <EnquetesAdminClient
      condominioId={condoId}
      enquetes={(enquetes ?? []).map(e => ({
        ...e,
        opcoes: (e.enquete_opcoes as { id: string; texto: string; ordem: number }[])
          ?.sort((a, b) => a.ordem - b.ordem) ?? [],
        totalRespostas: unitCountMap[e.id] ?? 0,
      }))}
      totalUnidades={uniqueUnits.size}
    />
  )
}
