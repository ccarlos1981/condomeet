import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ClassificadosAdminClient from './classificados-admin-client'

export default async function ClassificadosAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: perfil } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  if (!perfil) redirect('/login')

  // Fetch pending classificados
  const { data: classificados } = await supabase
    .from('classificados')
    .select(`
      *,
      perfil:criado_por (
        nome_completo,
        bloco_txt,
        apto_txt,
        whatsapp
      )
    `)
    .eq('condominio_id', perfil.condominio_id)
    .in('status', ['pendente', 'aprovado', 'rejeitado'])
    .order('created_at', { ascending: false })

  // Fetch condo info for labels
  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', perfil.condominio_id)
    .single()

  return (
    <ClassificadosAdminClient
      classificados={(classificados ?? []).map((c: any) => ({
        ...c,
        perfil: Array.isArray(c.perfil) ? c.perfil[0] : c.perfil,
      }))}
      condominioId={perfil.condominio_id}
      tipoEstrutura={condoData?.tipo_estrutura ?? 'predio'}
    />
  )
}
