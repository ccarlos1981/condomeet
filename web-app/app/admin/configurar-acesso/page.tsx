import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ConfigurarAcessoClient from './configurar-acesso-client'

export default async function ConfigurarAcessoPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Load features_config from condominios
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

  // Load distinct roles
  const { data: perfilRows } = await supabase
    .from('perfil')
    .select('papel_sistema')
    .eq('condominio_id', condoId)
    .not('papel_sistema', 'is', null)

  const dbRoles = [...new Set(
    (perfilRows ?? []).map(p => p.papel_sistema as string).filter(Boolean)
  )].sort()

  return (
    <ConfigurarAcessoClient
      initialConfig={config}
      condominioId={condoId}
      dbRoles={dbRoles}
    />
  )
}
