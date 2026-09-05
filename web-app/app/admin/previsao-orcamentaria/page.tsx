import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import PrevisaoOrcamentariaClient from './previsao-orcamentaria-client'
import { isAdminRole } from '@/lib/roles'

export default async function PrevisaoOrcamentariaPage({
  searchParams,
}: {
  searchParams: Promise<{ year?: string }>
}) {
  const supabase = await createClient()

  // 1. Authenticate user
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  if (!isAdminRole(profile?.papel_sistema)) {
    redirect('/condo')
  }

  const condoId = profile?.condominio_id
  if (!condoId) redirect('/condo')

  // 2. Resolve Year Parameter
  const searchParamsData = await searchParams
  const selectedYear = Number(searchParamsData?.year) || new Date().getFullYear()

  // 3. Fetch Plano de Contas (despesas, ativo)
  const { data: planoContas } = await supabase
    .from('condominio_plano_contas')
    .select('id, codigo, nome, tipo')
    .eq('condominio_id', condoId)
    .eq('tipo', 'despesa')
    .eq('ativo', true)
    .order('codigo')

  // 4. Fetch Budgets (Orçamentos) for the year
  const { data: orcamentos } = await supabase
    .from('condominio_orcamentos')
    .select('id, ano, mes, plano_conta_id, valor_previsto')
    .eq('condominio_id', condoId)
    .eq('ano', selectedYear)

  // 5. Fetch Actualized Expenses (Lançamentos Realizados) for current and previous year
  const startOfYear = `${selectedYear}-01-01`
  const endOfYear = `${selectedYear}-12-31`
  const prevStartOfYear = `${selectedYear - 1}-01-01`
  const prevEndOfYear = `${selectedYear - 1}-12-31`

  const { data: lancamentosAtual } = await supabase
    .from('condominio_lancamentos')
    .select('id, plano_conta_id, valor, data_vencimento, data_pagamento, status')
    .eq('condominio_id', condoId)
    .eq('tipo', 'despesa')
    .eq('status', 'pago')
    .gte('data_vencimento', startOfYear)
    .lte('data_vencimento', endOfYear)

  const { data: lancamentosAnterior } = await supabase
    .from('condominio_lancamentos')
    .select('id, plano_conta_id, valor, data_vencimento, data_pagamento, status')
    .eq('condominio_id', condoId)
    .eq('tipo', 'despesa')
    .eq('status', 'pago')
    .gte('data_vencimento', prevStartOfYear)
    .lte('data_vencimento', prevEndOfYear)

  return (
    <PrevisaoOrcamentariaClient
      condoId={condoId}
      selectedYear={selectedYear}
      planoContas={planoContas || []}
      orcamentos={orcamentos || []}
      lancamentosAtual={lancamentosAtual || []}
      lancamentosAnterior={lancamentosAnterior || []}
    />
  )
}
