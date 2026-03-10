import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ConfigurarOrdemClient from './configurar-ordem-client'

export default async function ConfigurarOrdemPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

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

  return <ConfigurarOrdemClient initialConfig={config} condominioId={condoId} />
}
