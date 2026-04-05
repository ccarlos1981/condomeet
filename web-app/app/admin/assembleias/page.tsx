import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AssembleiasClient from './assembleias-client'

export default async function AssembleiasAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch tipo_estrutura
  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condoData?.tipo_estrutura ?? 'predio'

  // Load assembleias with pauta count
  const { data: assembleias } = await supabase
    .from('assembleias')
    .select(`
      id, nome, tipo, modalidade, status,
      dt_1a_convocacao, dt_2a_convocacao,
      dt_inicio_votacao, dt_fim_votacao,
      dt_inicio_transmissao, dt_fim_transmissao,
      eleicao_mesa, peso_voto_tipo,
      created_at, updated_at, created_by,
      assembleia_pautas(id)
    `)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  // Count total units for quorum reference
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

  return (
    <AssembleiasClient
      condominioId={condoId}
      assembleias={(assembleias ?? []).map(a => ({
        ...a,
        totalPautas: Array.isArray(a.assembleia_pautas) ? a.assembleia_pautas.length : 0,
      }))}
      totalUnidades={uniqueUnits.size}
      tipoEstrutura={tipoEstrutura}
    />
  )
}
