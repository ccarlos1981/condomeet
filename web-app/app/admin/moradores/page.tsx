import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import MoradoresClient, { FilterStatus } from './moradores-client'
import { AlertCircle } from 'lucide-react'

export default async function MoradoresPage(props: {
  searchParams?: Promise<{ status?: string }>
}) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const resolvedSearchParams = props.searchParams ? await props.searchParams : undefined
  const rawStatus = resolvedSearchParams?.status?.toLowerCase()
  const validStatuses: FilterStatus[] = ['todos', 'ativo', 'pendente', 'bloqueado', 'rejeitado', 'inativo']
  const initialStatus: FilterStatus = validStatuses.includes(rawStatus as FilterStatus)
    ? (rawStatus as FilterStatus)
    : 'pendente'

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch tipo_estrutura
  const { data: condo } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condo?.tipo_estrutura ?? 'predio'

  // Fetch blocos cadastrados do condomínio para compor as opções do filtro
  const { data: blocosData } = await supabase
    .from('blocos')
    .select('nome_ou_numero')
    .eq('condominio_id', condoId)
    .order('nome_ou_numero', { ascending: true })

  const blocosCadastrados = blocosData?.map(b => b.nome_ou_numero).filter(Boolean) ?? []

  // Carregamento em lotes (batch fetch) para superar o limite de 1.000 registros do PostgREST
  // Garantindo que condomínios com mais de 1.000 moradores (ex: Recanto das Palmeiras, ~1.390) não sofram truncamento
  const BATCH_SIZE = 1000
  let moradores: any[] = []
  let from = 0
  let hasMore = true
  let fetchError: any = null

  while (hasMore) {
    const { data: batch, error } = await supabase
      .from('perfil')
      .select('id, nome_completo, bloco_txt, apto_txt, status_aprovacao, papel_sistema, created_at, email, whatsapp, tipo_morador, bloqueado')
      .eq('condominio_id', condoId)
      .order('nome_completo', { ascending: true })
      .range(from, from + BATCH_SIZE - 1)

    if (error) {
      fetchError = error
      break
    }

    if (batch && batch.length > 0) {
      moradores = moradores.concat(batch)
      if (batch.length < BATCH_SIZE) {
        hasMore = false
      } else {
        from += BATCH_SIZE
      }
    } else {
      hasMore = false
    }
  }

  if (fetchError) {
    return (
      <div className="bg-red-50 border border-red-200 text-red-700 rounded-xl p-6 flex gap-3 items-start">
        <AlertCircle size={20} className="flex-shrink-0 mt-0.5" />
        <div>
          <p className="font-semibold">Erro ao carregar moradores</p>
          <p className="text-sm mt-1">{fetchError.message}</p>
        </div>
      </div>
    )
  }

  return (
    <MoradoresClient
      moradores={moradores}
      tipoEstrutura={tipoEstrutura}
      currentUserRole={profile?.papel_sistema}
      blocosCadastrados={blocosCadastrados}
      initialStatus={initialStatus}
    />
  )

}
