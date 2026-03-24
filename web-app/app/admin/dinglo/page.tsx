import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import DingloAdminClient from './dinglo-admin-client'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Meu Bolso — Painel Admin' }

export default async function DingloAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  // Only owner can access
  if (user.email !== 'cristiano.santos@gmx.com') {
    redirect('/admin')
  }

  // Fetch metrics in parallel
  const [
    { count: totalUsuarios },
    { data: planos },
    { data: cupons },
    { data: cupomUsos },
    { data: planosConfig },
  ] = await Promise.all([
    supabase.from('dinglo_plano_usuario').select('*', { count: 'exact', head: true }),
    supabase.from('dinglo_plano_usuario').select('plano, ativo, user_id, created_at').order('created_at', { ascending: false }),
    supabase.from('dinglo_cupons').select('*').order('created_at', { ascending: false }),
    supabase.from('dinglo_cupom_usos').select('*, dinglo_cupons(codigo)').order('created_at', { ascending: false }).limit(50),
    supabase.from('dinglo_planos_config').select('*').order('ordem', { ascending: true }),
  ])

  // Get user emails for plan holders
  const userIds = (planos ?? []).map((p: { user_id: string }) => p.user_id)
  const { data: perfis } = userIds.length > 0
    ? await supabase.from('perfil').select('id, nome_completo, bloco_txt, apto_txt').in('id', userIds)
    : { data: [] }

  const perfilMap = Object.fromEntries(
    (perfis ?? []).map((p: { id: string; nome_completo: string; bloco_txt: string; apto_txt: string }) => [p.id, p])
  )

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const planosWithProfile: any[] = (planos ?? []).map((p: Record<string, unknown>) => ({
    ...p,
    perfil: perfilMap[p.user_id as string] ?? null,
  }))

  return (
    <DingloAdminClient
      totalUsuarios={totalUsuarios ?? 0}
      planos={planosWithProfile}
      cupons={cupons ?? []}
      cupomUsos={cupomUsos ?? []}
      planosConfig={planosConfig ?? []}
    />
  )
}
