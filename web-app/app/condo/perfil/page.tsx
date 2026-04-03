import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ProfileForm from './profile-form'
import { fetchAll } from '@/lib/supabase/utils'

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

  // Fetch tipo_estrutura from condominios
  const { data: condo } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condo?.tipo_estrutura ?? 'predio'

  // Fetch all blocos for this condo
  const blocosData = await fetchAll(
    supabase
      .from('blocos')
      .select('id, nome_ou_numero')
      .eq('condominio_id', condoId)
      .order('nome_ou_numero')
  )

  const blocos = (blocosData as any[] ?? []).map((b: any) => ({ id: b.id, nome_ou_numero: b.nome_ou_numero }))

  // Find current bloco
  const currentBloco = blocos.find(
    (b: { id: string; nome_ou_numero: string }) => b.nome_ou_numero.toLowerCase().trim() === (profile.bloco_txt ?? '').toLowerCase().trim()
  )
  const currentBlocoId = currentBloco?.id ?? ''

  // Fetch apartments for current bloco
  let initialAptos: { id: string; numero: string }[] = []
  let currentAptoId = ''

  if (currentBlocoId) {
    const unidades = await fetchAll(
      supabase
        .from('unidades')
        .select('apartamento_id')
        .eq('condominio_id', condoId)
        .eq('bloco_id', currentBlocoId)
    )

    if (unidades && unidades.length > 0) {
      const aptoIds = (unidades as any[]).map((u: any) => u.apartamento_id)
      const aptosData = await fetchAll(
        supabase
          .from('apartamentos')
          .select('id, numero')
          .in('id', aptoIds)
          .order('numero')
      )

      initialAptos = (aptosData as any[] ?? []).map((a: any) => ({ id: a.id, numero: String(a.numero) }))
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
      tipoEstrutura={tipoEstrutura}
      blocos={blocos}
      initialAptos={initialAptos}
    />
  )
}
