import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import EstoqueClient from './estoque-client'

export const metadata = {
  title: 'Controle de Estoque - Condomeet',
  description: 'Gerencie o estoque do seu condomínio de forma inteligente'
}

export default async function EstoquePage() {
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
  const isAdmin = r.includes('síndico') || r.includes('sindico') || r.includes('admin')
  if (!isAdmin) redirect('/condo')

  // Fetch all data in parallel
  const [
    { data: locais },
    { data: categorias },
    { data: produtos },
    { data: fornecedores },
    { data: movimentacoes },
    { data: emprestimos },
    { data: condoData },
  ] = await Promise.all([
    supabase.from('estoque_locais').select('*').eq('condominio_id', profile.condominio_id).order('nome'),
    supabase.from('estoque_categorias').select('*').eq('condominio_id', profile.condominio_id).order('nome'),
    supabase.from('estoque_produtos').select('*, estoque_locais(nome), estoque_categorias(nome), fornecedores(nome)').eq('condominio_id', profile.condominio_id).order('nome'),
    supabase.from('fornecedores').select('id, nome').eq('condominio_id', profile.condominio_id).order('nome'),
    supabase.from('estoque_movimentacoes').select('*, estoque_produtos(nome, unidade), perfil:realizado_por(nome_completo)').eq('condominio_id', profile.condominio_id).order('created_at', { ascending: false }).limit(200),
    supabase.from('estoque_emprestimos').select('*, estoque_produtos(nome, unidade)').eq('condominio_id', profile.condominio_id).order('created_at', { ascending: false }),
    supabase.from('condominios').select('nome').eq('id', profile.condominio_id).single(),
  ])

  return (
    <EstoqueClient
      condominioId={profile.condominio_id}
      condominioNome={condoData?.nome || 'Condomínio'}
      userId={user.id}
      initialLocais={locais || []}
      initialCategorias={categorias || []}
      initialProdutos={produtos || []}
      initialFornecedores={fornecedores || []}
      initialMovimentacoes={movimentacoes || []}
      initialEmprestimos={emprestimos || []}
    />
  )
}
