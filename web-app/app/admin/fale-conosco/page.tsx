import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import FaleConoscoAdminClient from './fale-conosco-admin-client'

export const metadata = { title: 'Fale Conosco — Admin Condomeet' }

export type AdminThread = {
  id: string
  tipo: string
  assunto: string
  status: string
  ultima_mensagem_em: string
  created_at: string
  resident_id: string
  perfil: {
    nome_completo: string
    bloco_txt: string | null
    apto_txt: string | null
  } | null
}

export default async function FaleConoscoAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, nome_completo')
    .eq('id', user.id)
    .single()

  const role = profile?.papel_sistema ?? ''
  const isAdmin =
    role === 'ADMIN' ||
    role.toLowerCase().includes('síndico') ||
    role.toLowerCase().includes('sindico')

  if (!isAdmin) redirect('/condo')

  const condoId = profile?.condominio_id ?? ''

  // Fetch tipo_estrutura
  const { data: condoData } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condoData?.tipo_estrutura ?? 'predio'

  // Fetch all threads for this condo
  const { data: threads, error } = await supabase
    .from('fale_sindico_threads')
    .select('id, tipo, assunto, status, ultima_mensagem_em, created_at, resident_id')
    .eq('condominio_id', condoId)
    .order('ultima_mensagem_em', { ascending: false })

  if (error) console.error('❌ fale_sindico admin error:', JSON.stringify(error))

  // Resolve resident profiles
  const residentIds = [...new Set((threads ?? []).map((t: any) => t.resident_id).filter(Boolean))]
  let perfilMap: Record<string, { nome_completo: string; bloco_txt: string | null; apto_txt: string | null }> = {}

  if (residentIds.length > 0) {
    const { data: perfis } = await supabase
      .from('perfil')
      .select('id, nome_completo, bloco_txt, apto_txt')
      .in('id', residentIds)
    ;(perfis ?? []).forEach((p: any) => { perfilMap[p.id] = p })
  }

  const threadsWithResident: AdminThread[] = (threads ?? []).map((t: any) => ({
    ...t,
    perfil: perfilMap[t.resident_id] ?? null,
  }))

  return (
    <FaleConoscoAdminClient
      initialThreads={threadsWithResident}
      adminId={user.id}
      adminName={profile?.nome_completo ?? 'Síndico'}
      condoId={condoId}
      tipoEstrutura={tipoEstrutura}
    />
  )
}
