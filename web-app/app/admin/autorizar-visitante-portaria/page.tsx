import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AutorizarVisitantePortariaClient from '../../condo/autorizar-visitante-portaria/autorizar-visitante-portaria-client'

export const metadata = { title: 'Autorização Visitante (Portaria) — Condomeet' }

export default async function AutorizarVisitantePortariaPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, nome_completo, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Get condo name
  const { data: condo } = await supabase
    .from('condominios')
    .select('nome, tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condo?.tipo_estrutura ?? 'predio'

  // Fetch structural blocks and apartments
  const { data: structuralData } = await supabase
    .from('blocos')
    .select('nome_ou_numero, unidades ( apartamentos ( numero ) )')
    .eq('condominio_id', condoId)
    .order('nome_ou_numero')
    .limit(10000)

  // Build blocos + aptosMap from structural tables
  const blocosSet = new Set<string>()
  const aptosPerBloco: Record<string, Set<string>> = {}

  interface StructuralBlock {
    nome_ou_numero: string | null
    unidades: { apartamentos: { numero: string | null } | null }[] | null
  }

  for (const blk of (structuralData ?? []) as unknown as StructuralBlock[]) {
    const blocoName = blk.nome_ou_numero
    if (!blocoName) continue
    blocosSet.add(blocoName)
    if (!aptosPerBloco[blocoName]) aptosPerBloco[blocoName] = new Set()
    const units = blk.unidades ?? []
    for (const u of units) {
      const apto = u?.apartamentos?.numero
      if (apto) aptosPerBloco[blocoName].add(apto)
    }
  }
  const blocos = [...blocosSet].sort((a, z) => a.localeCompare(z, 'pt-BR', { numeric: true }))
  const aptosMap: Record<string, string[]> = {}
  for (const b of blocos) {
    aptosMap[b] = [...(aptosPerBloco[b] ?? [])].sort((a, z) => a.localeCompare(z, 'pt-BR', { numeric: true }))
  }

  // Fetch residents for unit lookup (who requested the visit)
  const { data: moradores } = await supabase
    .from('perfil')
    .select('id, nome_completo, bloco_txt, apto_txt')
    .eq('condominio_id', condoId)
    .not('bloco_txt', 'is', null)
    .or('status_aprovacao.is.null,status_aprovacao.eq.aprovado')

  const residentsPerUnit: Record<string, { id: string; nome_completo: string }[]> = {}
  for (const m of moradores ?? []) {
    if (m.bloco_txt && m.apto_txt) {
      const unitKey = `${m.bloco_txt}__${m.apto_txt}`
      if (!residentsPerUnit[unitKey]) residentsPerUnit[unitKey] = []
      residentsPerUnit[unitKey].push({
        id: m.id,
        nome_completo: m.nome_completo || 'Morador',
      })
    }
  }

  return (
    <div className="p-6 lg:p-8 max-w-3xl">
      <div className="mb-6">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">Portaria</p>
        <h1 className="text-2xl font-bold text-gray-900">Autorização Visitante (Portaria)</h1>
        <p className="text-sm text-gray-500 mt-1">
          Registre autorizações de visitante solicitadas pelos moradores
        </p>
      </div>

      <AutorizarVisitantePortariaClient
        condoId={condoId}
        condoName={condo?.nome ?? 'Condomínio'}
        currentUserId={user.id}
        currentUserName={profile?.nome_completo ?? ''}
        tipoEstrutura={tipoEstrutura}
        blocos={blocos}
        aptosMap={aptosMap}
        residentsPerUnit={residentsPerUnit}
      />
    </div>
  )
}
