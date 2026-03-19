import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AutorizarVisitantePortariaClient from './autorizar-visitante-portaria-client'

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
    .select('nome')
    .eq('id', condoId)
    .single()

  // Get distinct blocos/aptos from resident profiles
  const { data: moradores } = await supabase
    .from('perfil')
    .select('id, nome_completo, bloco_txt, apto_txt, botconversa_id, whatsapp')
    .eq('condominio_id', condoId)
    .not('bloco_txt', 'is', null)
    .or('status_aprovacao.is.null,status_aprovacao.eq.aprovado')

  // Build unique sorted lists + residents per unit
  const blocosSet = new Set<string>()
  const aptosPerBloco: Record<string, Set<string>> = {}
  const residentsPerUnit: Record<string, { id: string; nome_completo: string }[]> = {}

  for (const m of moradores ?? []) {
    if (m.bloco_txt) {
      blocosSet.add(m.bloco_txt)
      if (!aptosPerBloco[m.bloco_txt]) aptosPerBloco[m.bloco_txt] = new Set()
      if (m.apto_txt) {
        aptosPerBloco[m.bloco_txt].add(m.apto_txt)
        const unitKey = `${m.bloco_txt}__${m.apto_txt}`
        if (!residentsPerUnit[unitKey]) residentsPerUnit[unitKey] = []
        residentsPerUnit[unitKey].push({
          id: m.id,
          nome_completo: m.nome_completo || 'Morador',
        })
      }
    }
  }
  const blocos = [...blocosSet].sort()
  const aptosMap: Record<string, string[]> = {}
  for (const b of blocos) {
    aptosMap[b] = [...(aptosPerBloco[b] ?? [])].sort((a, z) => a.localeCompare(z, 'pt-BR', { numeric: true }))
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
        blocos={blocos}
        aptosMap={aptosMap}
        residentsPerUnit={residentsPerUnit}
      />
    </div>
  )
}
