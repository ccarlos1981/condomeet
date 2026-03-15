import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import EnquetesMoradorClient from './enquetes-morador-client'

export default async function EnquetesMoradorPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, bloco_txt, apto_txt')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''
  const bloco = profile?.bloco_txt ?? ''
  const apto = profile?.apto_txt ?? ''

  // All active enquetes with options
  const { data: enquetes } = await supabase
    .from('enquetes')
    .select('id, pergunta, tipo_resposta, validade, created_at, enquete_opcoes(id, texto, ordem)')
    .eq('condominio_id', condoId)
    .eq('ativa', true)
    .order('created_at', { ascending: false })

  // Responses for this unit (bloco+apto) — to know what they voted
  const { data: unitRespostas } = await supabase
    .from('enquete_respostas')
    .select('enquete_id, opcao_id, created_at')
    .eq('bloco', bloco)
    .eq('apto', apto)

  // All responses for chart data (counts per option)
  const { data: allRespostas } = await supabase
    .from('enquete_respostas')
    .select('enquete_id, opcao_id')

  return (
    <div className="p-6 lg:p-8 max-w-4xl">
      <EnquetesMoradorClient
        enquetes={enquetes ?? []}
        unitRespostas={unitRespostas ?? []}
        allRespostas={allRespostas ?? []}
        userId={user.id}
        bloco={bloco}
        apto={apto}
      />
    </div>
  )
}
