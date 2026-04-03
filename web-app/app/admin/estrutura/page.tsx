import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import EstruturaClient from './estrutura-client'
import { fetchAll } from '@/lib/supabase/utils'

export default async function EstruturaPage() {
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
  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condoData?.tipo_estrutura ?? 'predio'

  const [blocosData, aptosData, unidadesData] = await Promise.all([
    fetchAll(
      supabase
        .from('blocos')
        .select('id, nome_ou_numero, created_at')
        .eq('condominio_id', condoId)
        .order('nome_ou_numero')
    ),
    fetchAll(
      supabase
        .from('apartamentos')
        .select('id, numero, created_at')
        .eq('condominio_id', condoId)
        .order('numero')
    ),
    fetchAll(
      supabase
        .from('unidades')
        .select('id, bloco_id, apartamento_id, bloqueada, blocos(nome_ou_numero), apartamentos(numero)')
        .eq('condominio_id', condoId)
        .order('created_at', { ascending: false })
    ),
  ])

  return (
    <EstruturaClient
      condoId={condoId}
      tipoEstrutura={tipoEstrutura}
      blocos={blocosData as { id: string; nome_ou_numero: string }[]}
      apartamentos={aptosData as { id: string; numero: string }[]}
      unidades={unidadesData.map((u: any) => ({
        id: u.id as string,
        bloco_id: u.bloco_id as string,
        apartamento_id: u.apartamento_id as string,
        bloqueada: u.bloqueada as boolean,
        bloco_nome: (u.blocos as Record<string, string>)?.nome_ou_numero ?? '?',
        apto_numero: (u.apartamentos as Record<string, string>)?.numero ?? '?',
      }))}
    />
  )
}
