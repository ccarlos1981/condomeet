'use server'

import { createClient } from '@/lib/supabase/server'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { revalidatePath } from 'next/cache'

export async function adminUpdateProfile(data: {
  id: string
  nome_completo: string
  whatsapp: string
  email: string
  bloco_txt: string
  apto_txt: string
  papel_sistema: string
}) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Não autorizado')

  // 1. Fetch current profile to get condominio_id
  const { data: adminProfile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const normalizedRole = adminProfile?.papel_sistema?.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "") || ''
  if (!normalizedRole.includes('sindico') && !normalizedRole.includes('admin')) {
    throw new Error('Permissão negada. Apenas síndicos e admins podem editar moradores.')
  }

  const condoId = adminProfile?.condominio_id

  // 2. Fetch target profile
  const { data: targetProfile, error: targetError } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', data.id)
    .single()

  if (targetError || !targetProfile || targetProfile.condominio_id !== condoId) {
    throw new Error('Morador não encontrado ou não pertence a este condomínio.')
  }

  // 3. Update the Perfil
  const { error: updateError } = await supabase
    .from('perfil')
    .update({
      nome_completo: data.nome_completo,
      whatsapp: data.whatsapp,
      email: data.email,
      bloco_txt: data.bloco_txt,
      apto_txt: data.apto_txt,
      papel_sistema: data.papel_sistema
    })
    .eq('id', data.id)

  if (updateError) {
    console.error('Update perfil erro:', updateError)
    throw new Error('Erro ao atualizar dados do morador.')
  }

  // 4. Update unidade_perfil if bloco_txt or apto_txt changed
  try {
    if (data.bloco_txt && data.apto_txt) {
      // Find or create block
      let blocoId
      const { data: blocoArr } = await supabase
        .from('blocos')
        .select('id')
        .eq('condominio_id', condoId)
        .eq('nome_ou_numero', data.bloco_txt)
      if (blocoArr && blocoArr.length > 0) {
        blocoId = blocoArr[0].id
      } else {
        const { data: newBloco } = await supabase.from('blocos').insert({
          condominio_id: condoId,
          nome_ou_numero: data.bloco_txt
        }).select().single()
        blocoId = newBloco?.id
      }

      // Find or create apto
      let aptoId
      const { data: aptoArr } = await supabase
        .from('apartamentos')
        .select('id')
        .eq('condominio_id', condoId)
        .eq('numero', data.apto_txt)
      if (aptoArr && aptoArr.length > 0) {
        aptoId = aptoArr[0].id
      } else {
        const { data: newApto } = await supabase.from('apartamentos').insert({
          condominio_id: condoId,
          numero: data.apto_txt
        }).select().single()
        aptoId = newApto?.id
      }

      if (blocoId && aptoId) {
        // Find or create unidade
        let unidadeId
        const { data: unitArr } = await supabase
          .from('unidades')
          .select('id')
          .eq('condominio_id', condoId)
          .eq('bloco_id', blocoId)
          .eq('apartamento_id', aptoId)
        if (unitArr && unitArr.length > 0) {
          unidadeId = unitArr[0].id
        } else {
          const { data: newUnit } = await supabase.from('unidades').insert({
            condominio_id: condoId,
            bloco_id: blocoId,
            apartamento_id: aptoId
          }).select().single()
          unidadeId = newUnit?.id
        }

        if (unidadeId) {
          // Delete old bindings to keep it 1-to-1 ideally (assuming they moved)
          await supabase.from('unidade_perfil').delete().eq('perfil_id', data.id)

          // Insert new binding
          await supabase.from('unidade_perfil').insert({
            perfil_id: data.id,
            unidade_id: unidadeId
          })
        }
      }
    }
  } catch (err) {
    console.error('Erro ao relinkar a unidade do condomínio:', err)
  }

  revalidatePath('/admin/aprovacoes')
  revalidatePath('/admin/moradores')
  revalidatePath('/portaria') // Also update concierge
}

export async function adminResetPassword(userId: string) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Não autorizado')

  const { data: adminProfile } = await supabase
    .from('perfil')
    .select('papel_sistema')
    .eq('id', user.id)
    .single()

  const normalizedRole = adminProfile?.papel_sistema?.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "") || ''
  if (!normalizedRole.includes('sindico') && !normalizedRole.includes('admin')) {
    throw new Error('Permissão negada. Apenas síndicos e admins podem resetar senhas.')
  }

  const supabaseAdmin = createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )

  const { error } = await supabaseAdmin.auth.admin.updateUserById(
    userId,
    { password: '123456' }
  )

  if (error) {
    console.error('Erro ao resetar senha:', error)
    throw new Error('Erro ao resetar a senha do usuário.')
  }
}
