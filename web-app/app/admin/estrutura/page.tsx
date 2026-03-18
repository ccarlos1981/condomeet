import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import EstruturaClient from './estrutura-client'

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

  const [blocosRes, aptosRes, unidadesRes] = await Promise.all([
    supabase
      .from('blocos')
      .select('id, nome_ou_numero, created_at')
      .eq('condominio_id', condoId)
      .order('nome_ou_numero')
      .limit(10000),
    supabase
      .from('apartamentos')
      .select('id, numero, created_at')
      .eq('condominio_id', condoId)
      .order('numero')
      .limit(10000),
    supabase
      .from('unidades')
      .select('id, bloco_id, apartamento_id, bloqueada, blocos(nome_ou_numero), apartamentos(numero)')
      .eq('condominio_id', condoId)
      .order('created_at', { ascending: false })
      .limit(10000),
  ])

  return (
    <EstruturaClient
      condoId={condoId}
      blocos={(blocosRes.data ?? []) as { id: string; nome_ou_numero: string }[]}
      apartamentos={(aptosRes.data ?? []) as { id: string; numero: string }[]}
      unidades={(unidadesRes.data ?? []).map((u: Record<string, unknown>) => ({
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
