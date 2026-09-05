import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ContratosClient from './contratos-client'
import { Contrato, ContratoPasta, Fornecedor } from './types'

export const metadata = { title: 'Contratos — Admin Condomeet' }

export default async function ContratosPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  const [
    { data: contratosRes },
    { data: pastasRes },
    { data: fornecedoresRes },
    { data: categoriasRes }
  ] = await Promise.all([
    supabase
      .from('contratos')
      .select('*, fornecedores(id, nome, telefone, documento, tipo), contrato_pastas(id, nome)')
      .eq('condominio_id', condoId)
      .order('created_at', { ascending: false }),
    supabase
      .from('contrato_pastas')
      .select('*')
      .eq('condominio_id', condoId)
      .order('nome'),
    supabase
      .from('fornecedores')
      .select('*')
      .eq('condominio_id', condoId)
      .eq('ativo', true)
      .order('nome'),
    supabase
      .from('documentos_categorias')
      .select('nome')
      .eq('condominio_id', condoId)
      .order('nome'),
  ])

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Contratos</h1>
        <p className="text-sm text-gray-500 mt-1">
          Gerencie fornecedores, vigências e custos operacionais recorrentes do condomínio
        </p>
      </div>

      <ContratosClient
        initialContratos={(contratosRes as unknown as Contrato[]) ?? []}
        initialPastas={(pastasRes as unknown as ContratoPasta[]) ?? []}
        initialFornecedores={(fornecedoresRes as unknown as Fornecedor[]) ?? []}
        initialCategorias={(categoriasRes ?? []).map((c: { nome: string }) => c.nome)}
        condoId={condoId}
      />
    </div>
  )
}
