import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import FinanceiroClient from './financeiro-client'
import { isAdminRole } from '@/lib/roles'

export default async function FinanceiroPage() {
  const supabase = await createClient()

  // 1. Get current user and profile
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  if (!isAdminRole(profile?.papel_sistema)) {
    // Only admins/síndicos can see this page
    redirect('/condo')
  }

  const condoId = profile?.condominio_id
  if (!condoId) redirect('/condo')

  // 2. Fetch Condo Settings
  const { data: condo } = await supabase
    .from('condominios')
    .select('nome, gateway_account_id, modelo_cobranca_padrao, valor_cota_padrao')
    .eq('id', condoId)
    .single()

  // 3. Fetch recent Boletos (Faturamentos) for this condo
  // Assuming a simplistic fetch for the last 5 faturamentos
  const { data: faturamentos } = await supabase
    .from('faturamentos')
    .select(`
      id, valor_total, data_vencimento, status_pagamento,
      unidades (id, blocos(nome_ou_numero), apartamentos(numero)),
      perfil!faturamentos_morador_id_fkey (nome_completo)
    `)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })
    .limit(5)

  // 4. Fetch Launch/DRE data for the current month
  // (In a real app, we'd filter by current month and group by plano de contas)
  // Here we do a mock aggregation for MVP visualization
  const { data: lancamentos } = await supabase
    .from('condominio_lancamentos')
    .select('tipo, valor')
    .eq('condominio_id', condoId)

  let totalReceitas = 0;
  let totalDespesas = 0;

  if (lancamentos) {
    lancamentos.forEach(l => {
      if (l.tipo === 'receita') totalReceitas += Number(l.valor)
      if (l.tipo === 'despesa') totalDespesas += Number(l.valor)
    })
  }

  return (
    <FinanceiroClient 
      condoId={condoId}
      condoName={condo?.nome || 'Condomínio'}
      hasSplit={!!condo?.gateway_account_id}
      modeloPadrao={condo?.modelo_cobranca_padrao || 'fixo'}
      cotaPadrao={condo?.valor_cota_padrao || 0}
      totalReceitas={totalReceitas}
      totalDespesas={totalDespesas}
      faturamentos={faturamentos || []}
    />
  )
}
