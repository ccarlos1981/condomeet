import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { isAdminRole, isFeatureVisible } from '@/lib/roles'
import AvisosCondoClient from './avisos-condo-client'

export default async function AvisosCondoPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, nome_completo, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''
  const rawRole = profile?.papel_sistema

  // Query features_config to validate dynamic feature permission
  const { data: condo } = await supabase
    .from('condominios')
    .select('features_config')
    .eq('id', condoId)
    .single()

  const featuresConfig = condo?.features_config
  const isSysAdmin = isAdminRole(rawRole)

  // Validate dynamic permission with safe fallback for legacy condominios
  const canAccess =
    isSysAdmin ||
    isFeatureVisible('avisos', rawRole, featuresConfig, true)

  if (!canAccess) {
    redirect('/condo')
  }

  // All condo's avisos
  const { data: todos } = await supabase
    .from('avisos')
    .select('id, titulo, corpo, created_at')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  // Which ones this user has already read
  const { data: lidos } = await supabase
    .from('avisos_lidos')
    .select('aviso_id')
    .eq('user_id', user.id)

  const lidosSet = new Set((lidos ?? []).map(r => r.aviso_id))

  const naoLidos = (todos ?? []).filter(a => !lidosSet.has(a.id))
  const lidosList = (todos ?? []).filter(a => lidosSet.has(a.id))

  return (
    <div className="p-6 lg:p-8 max-w-4xl">
      <AvisosCondoClient
        naoLidos={naoLidos}
        lidos={lidosList}
      />
    </div>
  )
}
