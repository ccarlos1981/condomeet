import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import VisitaProprietarioAdminClient from './visita-proprietario-admin-client'

export const metadata = {
  title: 'Visita Proprietário — Admin — Condomeet',
}

export default async function VisitaProprietarioAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, nome_completo')
    .eq('id', user.id)
    .single()

  if (!profile?.condominio_id) redirect('/condo')

  const r = profile.papel_sistema?.toLowerCase() || ''
  const isAdmin = r.includes('síndico') || r.includes('sindico') || r.includes('admin') || r.includes('sub_sindico')
  if (!isAdmin) redirect('/condo')

  const condoId = profile.condominio_id

  // Fetch tipo_estrutura
  const { data: condo } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condo?.tipo_estrutura ?? 'predio'

  // Get blocos/aptos from perfil
  const { data: moradores } = await supabase
    .from('perfil')
    .select('id, nome_completo, bloco_txt, apto_txt')
    .eq('condominio_id', condoId)
    .not('bloco_txt', 'is', null)

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

  const blocos = [...blocosSet].sort((a, b) => a.localeCompare(b, 'pt-BR', { numeric: true }))
  const aptosMap: Record<string, string[]> = {}
  for (const b of blocos) {
    aptosMap[b] = [...(aptosPerBloco[b] ?? [])].sort((a, z) =>
      a.localeCompare(z, 'pt-BR', { numeric: true })
    )
  }

  const moradoresMap: Record<string, { id: string; nome: string }[]> = {}
  for (const [key, list] of Object.entries(moradoresPerUnit)) {
    moradoresMap[key] = list
  }

  return (
    <VisitaProprietarioAdminClient
      condoId={condoId}
      currentUserId={user.id}
      currentUserName={profile.nome_completo ?? ''}
      tipoEstrutura={tipoEstrutura}
      blocos={blocos}
      aptosMap={aptosMap}
      moradoresMap={moradoresMap}
    />
  )
}
