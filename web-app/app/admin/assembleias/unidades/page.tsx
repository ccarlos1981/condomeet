import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ConfigUnidadesClient from './config-unidades-client'

export default async function ConfigUnidadesPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch condo info
  const { data: condoData } = await supabase
    .from('condominios')
    .select('nome, tipo_estrutura')
    .eq('id', condoId)
    .single()

  // Fetch all units with block & apartment info
  const { data: unidades } = await supabase
    .from('unidades')
    .select(`
      id,
      bloqueada,
      fracao_ideal,
      bloqueada_assembleia,
      bloqueada_app,
      bloco:blocos(nome_ou_numero),
      apartamento:apartamentos(numero)
    `)
    .eq('condominio_id', condoId)
    .order('id')

  // Count moradores per unidade
  const { data: vinculos } = await supabase
    .from('unidade_perfil')
    .select('unidade_id, perfil:perfil(nome_completo)')

  // Build moradores count map
  const moradoresMap: Record<string, number> = {}
  vinculos?.forEach(v => {
    moradoresMap[v.unidade_id] = (moradoresMap[v.unidade_id] || 0) + 1
  })

  const formattedUnidades = (unidades || []).map(u => ({
    id: u.id,
    bloco: (u.bloco as any)?.nome_ou_numero ?? '—',
    apartamento: (u.apartamento as any)?.numero ?? '—',
    fracao_ideal: u.fracao_ideal ?? 1.00,
    bloqueada_assembleia: u.bloqueada_assembleia ?? false,
    bloqueada_app: u.bloqueada_app ?? false,
    moradores_count: moradoresMap[u.id] || 0,
  }))

  return (
    <ConfigUnidadesClient
      condoNome={condoData?.nome ?? ''}
      tipoEstrutura={condoData?.tipo_estrutura ?? 'predio'}
      unidades={formattedUnidades}
    />
  )
}
