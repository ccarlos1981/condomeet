import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ProfileForm from './profile-form'

export default async function EditProfilePage() {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  // Fetch profile
  const { data: profile } = await supabase
    .from('perfil')
    .select('nome_completo, whatsapp, tipo_morador, bloco_txt, apto_txt, condominio_id')
    .eq('id', user.id)
    .single()

  if (!profile) redirect('/condo')

  const condoId = profile.condominio_id ?? ''

  // Fetch all blocos for this condo
  const { data: blocosData } = await supabase
    .from('blocos')
    .select('id, nome_ou_numero')
    .eq('condominio_id', condoId)
    .order('nome_ou_numero')
    .limit(10000)

  const blocos = (blocosData ?? []).map((b: any) => ({ id: b.id, nome_ou_numero: b.nome_ou_numero }))

  // Find current bloco
  const currentBloco = blocos.find(
    (b: any) => b.nome_ou_numero.toLowerCase().trim() === (profile.bloco_txt ?? '').toLowerCase().trim()
  )
  const currentBlocoId = currentBloco?.id ?? ''

  // Fetch apartments for current bloco
  let initialAptos: { id: string; numero: string }[] = []
  let currentAptoId = ''

  if (currentBlocoId) {
    const { data: unidades } = await supabase
      .from('unidades')
      .select('apartamento_id')
      .eq('condominio_id', condoId)
      .eq('bloco_id', currentBlocoId)
      .limit(10000)

    if (unidades && unidades.length > 0) {
      const aptoIds = unidades.map((u: any) => u.apartamento_id)
      const { data: aptosData } = await supabase
        .from('apartamentos')
        .select('id, numero')
        .in('id', aptoIds)
        .order('numero')
        .limit(10000)

      initialAptos = (aptosData ?? []).map((a: any) => ({ id: a.id, numero: String(a.numero) }))
      initialAptos.sort((a, b) => a.numero.localeCompare(b.numero, undefined, { numeric: true }))

      // Find current apto
      const currApto = initialAptos.find(
        a => a.numero.toLowerCase().trim() === (profile.apto_txt ?? '').toLowerCase().trim()
      )
      currentAptoId = currApto?.id ?? ''
    }
  }

  return (
    <ProfileForm
      userId={user.id}
      condoId={condoId}
      email={user.email ?? ''}
      currentName={profile.nome_completo ?? ''}
      currentWhatsapp={profile.whatsapp ?? ''}
      currentTipoMorador={profile.tipo_morador ?? 'Proprietário (a)'}
      currentBlocoTxt={profile.bloco_txt ?? ''}
      currentAptoTxt={profile.apto_txt ?? ''}
      currentBlocoId={currentBlocoId}
      currentAptoId={currentAptoId}
      blocos={blocos}
      initialAptos={initialAptos}
    />
  )
}
