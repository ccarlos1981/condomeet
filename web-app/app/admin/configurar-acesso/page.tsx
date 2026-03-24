import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ConfigurarAcessoClient from './configurar-acesso-client'

const SUPER_ADMIN_EMAIL = 'cristiano.santos@gmx.com'

export default async function ConfigurarAcessoPage({
  searchParams,
}: {
  searchParams: Promise<{ condo?: string }>
}) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const isSuperAdmin = user.email === SUPER_ADMIN_EMAIL

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  // For super admin: allow switching via ?condo= param
  const params = await searchParams
  const condoId = (isSuperAdmin && params.condo)
    ? params.condo
    : (profile?.condominio_id ?? '')

  // Load features_config from the selected condominium
  const { data: condo } = await supabase
    .from('condominios')
    .select('features_config')
    .eq('id', condoId)
    .maybeSingle()

  let config: Record<string, unknown> = {}
  if (condo?.features_config) {
    config = typeof condo.features_config === 'string'
      ? JSON.parse(condo.features_config)
      : condo.features_config
  }

  // Load distinct roles for the selected condominium
  const { data: perfilRows } = await supabase
    .from('perfil')
    .select('papel_sistema')
    .eq('condominio_id', condoId)
    .not('papel_sistema', 'is', null)

  const dbRoles = [...new Set(
    (perfilRows ?? []).map(p => p.papel_sistema as string).filter(Boolean)
  )].sort()

  // Super admin: load all condominiums for the switcher dropdown
  let allCondominios: { id: string; nome: string }[] | undefined
  if (isSuperAdmin) {
    const { data: condos } = await supabase
      .from('condominios')
      .select('id, nome')
      .order('nome')
    allCondominios = (condos ?? []) as { id: string; nome: string }[]
  }

  return (
    <ConfigurarAcessoClient
      initialConfig={config}
      condominioId={condoId}
      dbRoles={dbRoles}
      allCondominios={allCondominios}
    />
  )
}
