import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import EnquetesAdminClient from './enquetes-admin-client'

export default async function EnquetesAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Load enquetes with options and response counts
  const { data: enquetes } = await supabase
    .from('enquetes')
    .select(`
      id, pergunta, tipo_resposta, ativa, validade, created_at,
      enquete_opcoes(id, texto, ordem),
      enquete_respostas(count)
    `)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  // Total unique units (bloco+apto combos) for response %
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
    <EnquetesAdminClient
      condominioId={condoId}
      enquetes={(enquetes ?? []).map(e => ({
        ...e,
        opcoes: (e.enquete_opcoes as { id: string; texto: string; ordem: number }[])
          ?.sort((a, b) => a.ordem - b.ordem) ?? [],
        totalRespostas: (e.enquete_respostas as unknown as { count: number }[])?.[0]?.count ?? 0,
      }))}
      totalUnidades={uniqueUnits.size}
    />
  )
}
