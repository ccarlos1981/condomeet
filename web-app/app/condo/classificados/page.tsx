import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ClassificadosClient from './classificados-client'

export default async function ClassificadosPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: perfil } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, bloco_txt, apto_txt, nome_completo')
    .eq('id', user.id)
    .single()

  if (!perfil) redirect('/login')

  // Fetch approved classificados with creator profile
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
    .in('status', ['aprovado', 'vendido'])
    .order('created_at', { ascending: false })

  // Fetch user's own pending/rejected ads
  const { data: meusPendentes } = await supabase
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
    .eq('criado_por', user.id)
    .in('status', ['pendente', 'rejeitado'])
    .order('created_at', { ascending: false })

  // Fetch user's favorites
  const { data: favoritos } = await supabase
    .from('classificados_favoritos')
    .select('classificado_id')
    .eq('usuario_id', user.id)

  // Fetch condo info
  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', perfil.condominio_id)
    .single()

  const allClassificados = [
    ...(meusPendentes ?? []),
    ...(classificados ?? []),
  ].map((c: any) => ({ // eslint-disable-line @typescript-eslint/no-explicit-any
    ...c,
    perfil: Array.isArray(c.perfil) ? c.perfil[0] : c.perfil,
  }))

  return (
    <ClassificadosClient
      classificados={allClassificados}
      userId={user.id}
      condominioId={perfil.condominio_id}
      favoritosIds={(favoritos ?? []).map((f: any) => f.classificado_id)} // eslint-disable-line @typescript-eslint/no-explicit-any
      tipoEstrutura={condoData?.tipo_estrutura ?? 'predio'}
      userName={perfil.nome_completo}
    />
  )
}
