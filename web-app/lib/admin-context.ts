import { SupabaseClient } from '@supabase/supabase-js'
import { cookies } from 'next/headers'

export async function getActiveCondoId(supabase: SupabaseClient): Promise<string> {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return ''

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, administradora_id')
    .eq('id', user.id)
    .single()

  if (!profile) return ''

  let condoId = profile.condominio_id ?? ''

  if (profile.papel_sistema?.toLowerCase() === 'administradora' && profile.administradora_id) {
    const cookieStore = await cookies()
    const selectedCondoId = cookieStore.get('selected_condo_id')?.value
    if (selectedCondoId) {
      const { data: condoMatch } = await supabase
        .from('condominios')
        .select('id')
        .eq('id', selectedCondoId)
        .eq('administradora_id', profile.administradora_id)
        .maybeSingle()
      if (condoMatch) {
        condoId = selectedCondoId
      }
    }
  }

  return condoId;
}
