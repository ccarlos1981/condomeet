'use server'

import { createClient } from '@/lib/supabase/server'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { revalidatePath } from 'next/cache'

import { isAdminRole } from '@/lib/roles'

export async function adminUpdateProfile(data: {
  id: string
  nome_completo: string
  whatsapp: string
  email: string
  bloco_txt: string
  apto_txt: string
  papel_sistema: string
  tipo_morador?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    // 1. Fetch current profile to get condominio_id
    const { data: adminProfile } = await supabase
      .from('perfil')
      .select('condominio_id, papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(adminProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e admins podem editar moradores.' }
    }

    const condoId = adminProfile?.condominio_id

    // 2. Fetch target profile
    const { data: targetProfile, error: targetError } = await supabase
      .from('perfil')
      .select('condominio_id')
      .eq('id', data.id)
      .single()

    if (targetError || !targetProfile || targetProfile.condominio_id !== condoId) {
      return { error: 'Morador não encontrado ou não pertence a este condomínio.' }
    }

    // 3. Normalize fields based on canonical roles
    let finalBloco = data.bloco_txt?.trim() ?? ''
    let finalApto = data.apto_txt?.trim() ?? ''
    const isTargetAdmin = data.papel_sistema === 'Admin'

    if (isTargetAdmin) {
      finalBloco = 'Admin'
      finalApto = 'Admin'
    } else if (finalBloco.toLowerCase() === 'admin' || finalApto.toLowerCase() === 'admin') {
      return { error: 'Moradores e síndicos devem possuir unidade residencial válida, não podendo utilizar a identificação técnica Admin.' }
    }

    // 4. Update the Perfil
    const profileUpdate: Record<string, any> = {
      nome_completo: data.nome_completo,
      whatsapp: data.whatsapp,
      email: data.email,
      bloco_txt: finalBloco,
      apto_txt: finalApto,
      papel_sistema: data.papel_sistema,
    }

    if (data.tipo_morador !== undefined) {
      profileUpdate.tipo_morador = data.tipo_morador
    }

    const { error: updateError } = await supabase
      .from('perfil')
      .update(profileUpdate)
      .eq('id', data.id)

    if (updateError) {
      console.error('Update perfil erro:', updateError)
      return { error: 'Erro ao atualizar dados do morador.' }
    }

    // 5. Update unidade_perfil ONLY for real residential units (non-Admin)
    try {
      if (!isTargetAdmin && finalBloco && finalApto && finalBloco !== 'Admin') {
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
            // Check if user is already actively linked to this exact unit
            const { data: existingActive } = await supabase
              .from('unidade_perfil')
              .select('id, unidade_id, status')
              .eq('perfil_id', data.id)
              .eq('status', 'ativo')

            const isAlreadyLinked = existingActive?.some(link => link.unidade_id === unidadeId)

            if (!isAlreadyLinked) {
              const nowIso = new Date().toISOString()
              
              // Inactivate any previous active unit links to preserve history
              await supabase
                .from('unidade_perfil')
                .update({
                  status: 'inativo',
                  data_saida: nowIso,
                })
                .eq('perfil_id', data.id)
                .eq('status', 'ativo')

              // Check if a link already exists for (perfil_id, unidadeId)
              const { data: targetLink } = await supabase
                .from('unidade_perfil')
                .select('id')
                .eq('perfil_id', data.id)
                .eq('unidade_id', unidadeId)
                .maybeSingle()

              if (targetLink) {
                await supabase
                  .from('unidade_perfil')
                  .update({
                    status: 'ativo',
                    data_saida: null,
                  })
                  .eq('id', targetLink.id)
              } else {
                await supabase
                  .from('unidade_perfil')
                  .insert({
                    perfil_id: data.id,
                    unidade_id: unidadeId,
                    status: 'ativo',
                    data_entrada: nowIso,
                  })
              }
            }
          }
        }
      }
    } catch (err) {
      console.error('Erro ao relinkar a unidade do condomínio:', err)
    }

    revalidatePath('/admin/aprovacoes')
    revalidatePath('/admin/moradores')
    revalidatePath('/portaria') // Also update concierge

    return { success: true }
  } catch (err: unknown) {
    console.error('Erro interno adminUpdateProfile:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao atualizar o perfil.'
    return { error: msg }
  }
}

export async function adminResetPassword(userId: string) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: adminProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    const normalizedRole = adminProfile?.papel_sistema?.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "") || ''
    if (!normalizedRole.includes('sindico') && !normalizedRole.includes('admin')) {
      return { error: 'Permissão negada. Apenas síndicos e admins podem resetar senhas.' }
    }

    if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
      return { error: 'Variáveis de ambiente do Supabase não configuradas no servidor (SUPABASE_SERVICE_ROLE_KEY ausente).' }
    }

    const supabaseAdmin = createSupabaseClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    )

    const { error } = await supabaseAdmin.auth.admin.updateUserById(
      userId,
      { password: '123456' }
    )

    if (error) {
      console.error('Erro ao resetar senha:', error)
      return { error: 'Erro ao resetar a senha: ' + error.message }
    }

    return { success: true }
  } catch (err: unknown) {
    console.error('Erro interno adminResetPassword:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao resetar senha.'
    return { error: msg }
  }
}
