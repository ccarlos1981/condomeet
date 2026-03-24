import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import MoradoresClient from './moradores-client'
import { AlertCircle } from 'lucide-react'

export default async function MoradoresPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
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

  const { data: moradores, error } = await supabase
    .from('perfil')
    .select('id, nome_completo, bloco_txt, apto_txt, status_aprovacao, papel_sistema, created_at')
    .eq('condominio_id', condoId)
    .eq('status_aprovacao', 'aprovado')
    .order('nome_completo', { ascending: true })

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 text-red-700 rounded-xl p-6 flex gap-3 items-start">
        <AlertCircle size={20} className="flex-shrink-0 mt-0.5" />
        <div>
          <p className="font-semibold">Erro ao carregar moradores</p>
          <p className="text-sm mt-1">{error.message}</p>
        </div>
      </div>
    )
  }

  return <MoradoresClient moradores={moradores ?? []} tipoEstrutura={tipoEstrutura} />
}
