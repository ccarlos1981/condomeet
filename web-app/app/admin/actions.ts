'use server'

import { createClient } from '@/lib/supabase/server'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { revalidatePath } from 'next/cache'

import { isAdminRole, isTechnicalAdminRole, normalizeRoleForPersistence, canPromoteToAdmin } from '@/lib/roles'

/**
 * Gate 3I.3-A: Normalização canônica de telefone para E.164 (+55DDDNÚMERO).
 */
function normalizePhoneE164(phone: string): string | null {
  if (!phone || typeof phone !== 'string') return null

  const trimmed = phone.trim()
  if (!trimmed) return null

  const hadPlus55 = trimmed.startsWith('+55') || trimmed.startsWith('+ 55')
  let digits = trimmed.replace(/\D/g, '')

  if (hadPlus55) {
    if (digits.startsWith('55')) {
      digits = digits.slice(2)
    }
  } else if ((digits.length === 13 || digits.length === 12) && digits.startsWith('55')) {
    digits = digits.slice(2)
  }

  // DDD (2 dígitos) + número local (8 ou 9 dígitos) -> Total 10 ou 11 dígitos
  if (digits.length !== 10 && digits.length !== 11) {
    return null
  }

  const ddd = parseInt(digits.slice(0, 2), 10)
  if (isNaN(ddd) || ddd < 11 || ddd > 99) {
    return null
  }

  const localNumber = digits.slice(2)
  // Celular (9 dígitos) no Brasil inicia com 9
  if (localNumber.length === 9 && localNumber[0] !== '9') {
    return null
  }

  // Fixo (8 dígitos) no Brasil inicia com 2, 3, 4 ou 5
  if (localNumber.length === 8 && (localNumber[0] < '2' || localNumber[0] > '5')) {
    return null
  }

  return `+55${digits}`
}

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
    const isTargetAdmin = isTechnicalAdminRole(data.papel_sistema)

    let canonicalPapel = normalizeRoleForPersistence(data.papel_sistema)

    if (isTargetAdmin) {
      if (!canPromoteToAdmin(adminProfile?.papel_sistema)) {
        return { error: 'Permissão negada. Somente o Síndico ou Administrador podem atribuir a função de Admin.' }
      }
      canonicalPapel = 'Admin'
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
      papel_sistema: canonicalPapel,
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

export async function adminToggleBlockStatus(data: {
  profileId: string
  action: 'block' | 'unblock'
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    // 1. Obter perfil do operador autenticado
    const { data: operatorProfile, error: operatorError } = await supabase
      .from('perfil')
      .select('condominio_id, papel_sistema')
      .eq('id', user.id)
      .single()

    if (operatorError || !operatorProfile || !isAdminRole(operatorProfile.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem bloquear ou reativar moradores.' }
    }

    const condoId = operatorProfile.condominio_id
    if (!condoId) {
      return { error: 'Condomínio do operador não identificado.' }
    }

    // 2. Proteção contra auto-bloqueio do próprio operador
    if (data.profileId === user.id) {
      return { error: 'Operação inválida. Não é permitido bloquear o próprio usuário operador.' }
    }

    // 3. Obter perfil-alvo e validar isolamento multi-tenant
    const { data: targetProfile, error: targetError } = await supabase
      .from('perfil')
      .select('id, condominio_id, status_aprovacao, bloqueado, nome_completo, papel_sistema')
      .eq('id', data.profileId)
      .single()

    if (targetError || !targetProfile || targetProfile.condominio_id !== condoId) {
      return { error: 'Morador não encontrado ou não pertence a este condomínio.' }
    }

    // 4. Validar transições canônicas
    if (data.action === 'block') {
      const isAlreadyBlocked = targetProfile.status_aprovacao === 'bloqueado' && targetProfile.bloqueado === true
      if (isAlreadyBlocked) {
        return { error: 'Este morador já se encontra bloqueado.' }
      }
      if (targetProfile.status_aprovacao === 'pendente') {
        return { error: 'Cadastros pendentes devem ser aprovados ou rejeitados na esteira de aprovações, não bloqueados.' }
      }

      const { error: updateError } = await supabase
        .from('perfil')
        .update({
          status_aprovacao: 'bloqueado',
          bloqueado: true,
        })
        .eq('id', data.profileId)
        .eq('condominio_id', condoId)

      if (updateError) {
        console.error('Erro ao bloquear morador:', updateError)
        return { error: 'Falha ao bloquear o morador. Tente novamente.' }
      }
    } else if (data.action === 'unblock') {
      const isCurrentlyBlocked = targetProfile.status_aprovacao === 'bloqueado' || targetProfile.bloqueado === true
      if (!isCurrentlyBlocked) {
        return { error: 'Este morador não se encontra bloqueado.' }
      }

      const { error: updateError } = await supabase
        .from('perfil')
        .update({
          status_aprovacao: 'aprovado',
          bloqueado: false,
        })
        .eq('id', data.profileId)
        .eq('condominio_id', condoId)

      if (updateError) {
        console.error('Erro ao reativar morador:', updateError)
        return { error: 'Falha ao reativar o morador. Tente novamente.' }
      }
    } else {
      return { error: 'Ação de bloqueio inválida.' }
    }

    // 5. Revalidar rotas envolvidas
    revalidatePath('/admin/moradores')
    revalidatePath(`/admin/moradores/${data.profileId}`)
    revalidatePath('/portaria')
    revalidatePath('/admin/aprovacoes')

    return {
      success: true,
      action: data.action,
      newStatus: data.action === 'block' ? 'bloqueado' : 'aprovado',
      newBloqueado: data.action === 'block',
    }
  } catch (err: unknown) {
    console.error('Erro interno adminToggleBlockStatus:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao processar a operação.'
    return { error: msg }
  }
}

function translateInactivationError(errorMsg: string): string {
  if (errorMsg.includes('Operação não autorizada') || errorMsg.includes('não identificada')) {
    return 'Sessão expirada ou não autorizada. Por favor, refaça o login.'
  }
  if (errorMsg.includes('Apenas síndicos e administradores')) {
    return 'Permissão negada. Apenas síndicos e administradores podem inativar moradores.'
  }
  if (errorMsg.includes('Não é permitido inativar o próprio usuário')) {
    return 'Operação inválida. Não é permitido inativar seu próprio cadastro de operador.'
  }
  if (errorMsg.includes('motivo da inativação é obrigatório')) {
    return 'O motivo da inativação é obrigatório.'
  }
  if (errorMsg.includes('data de saída é obrigatória')) {
    return 'A data de saída é obrigatória.'
  }
  if (errorMsg.includes('data futura')) {
    return 'A data de saída não pode ser uma data futura.'
  }
  if (errorMsg.includes('Morador alvo não encontrado')) {
    return 'Morador não localizado no cadastro.'
  }
  if (errorMsg.includes('outro condomínio') || errorMsg.includes('multi-tenant')) {
    return 'Violação de condomínio. O morador não pertence ao condomínio atual.'
  }
  if (errorMsg.includes('Vínculo imobiliário não encontrado')) {
    return 'Vínculo do morador com a unidade não foi localizado.'
  }
  if (errorMsg.includes('já se encontra inativo')) {
    return 'Este vínculo imobiliário já se encontra inativo.'
  }
  if (errorMsg.includes('anterior à data de entrada')) {
    return 'A data de saída não pode ser anterior à data de entrada no imóvel.'
  }
  if (errorMsg.includes('Proprietário')) {
    return 'A opção de manter propriedade só é válida para moradores classificados como Proprietário.'
  }
  if (errorMsg.includes('mais de um vínculo ativo remanescente')) {
    return 'O morador possui múltiplos vínculos ativos remanescentes. Não é possível determinar a unidade principal automaticamente.'
  }
  return errorMsg.replace(/^ERROR:\s*/i, '').replace(/CONTEXT:[\s\S]*/i, '').trim() || 'Erro ao processar inativação do morador.'
}

export async function adminGetInactivationContext(profileId: string) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    // 1. Obter operador e condomínio
    const { data: opProfile, error: opError } = await supabase
      .from('perfil')
      .select('condominio_id, papel_sistema')
      .eq('id', user.id)
      .single()

    if (opError || !opProfile || !isAdminRole(opProfile.papel_sistema)) {
      return { error: 'Permissão negada. Apenas administradores e síndicos podem consultar dados para inativação.' }
    }

    const condoId = opProfile.condominio_id
    if (!condoId) return { error: 'Condomínio não identificado.' }

    // 2. Obter perfil do morador alvo
    const { data: target, error: targetError } = await supabase
      .from('perfil')
      .select('id, nome_completo, papel_sistema, status_aprovacao, bloqueado, tipo_morador, bloco_txt, apto_txt, condominio_id')
      .eq('id', profileId)
      .eq('condominio_id', condoId)
      .single()

    if (targetError || !target) {
      return { error: 'Morador não localizado neste condomínio.' }
    }

    // 3. Obter vínculos ativos em unidade_perfil
    const { data: rawLinks } = await supabase
      .from('unidade_perfil')
      .select(`
        id,
        status,
        data_entrada,
        unidade_id,
        unidades (
          id,
          blocos ( nome_ou_numero ),
          apartamentos ( numero )
        )
      `)
      .eq('perfil_id', profileId)
      .eq('status', 'ativo')

    const activeLinks = (rawLinks ?? []).map((l: any) => ({
      id: l.id,
      unidade_id: l.unidade_id,
      status: l.status,
      data_entrada: l.data_entrada,
      bloco: l.unidades?.blocos?.nome_ou_numero ?? '',
      apto: l.unidades?.apartamentos?.numero ?? '',
    }))

    // 4. Checar reservas futuras existentes (data_reserva >= hoje e status ativo/pendente)
    const todayStr = new Date().toISOString().split('T')[0]
    const { data: reservasRaw } = await supabase
      .from('reservas')
      .select(`
        id,
        data_reserva,
        status,
        areas_comuns ( nome )
      `)
      .eq('user_id', profileId)
      .eq('condominio_id', condoId)
      .gte('data_reserva', todayStr)
      .neq('status', 'cancelada')
      .order('data_reserva', { ascending: true })

    const futureReservas = (reservasRaw ?? []).map((r: any) => ({
      id: r.id,
      data_reserva: r.data_reserva,
      status: r.status,
      area_nome: r.areas_comuns?.nome || 'Área Comum',
    }))

    // 5. Checar convites futuros ou ativos existentes
    const nowIso = new Date().toISOString()
    const { data: convitesRaw } = await supabase
      .from('convites')
      .select(`
        id,
        guest_name,
        visitor_type,
        status,
        validity_date,
        valid_until
      `)
      .eq('resident_id', profileId)
      .eq('condominio_id', condoId)
      .in('status', ['ativo', 'pendente'])
      .or(`validity_date.gte.${nowIso},valid_until.gte.${nowIso}`)
      .order('created_at', { ascending: false })

    const futureConvites = (convitesRaw ?? []).map((c: any) => ({
      id: c.id,
      guest_name: c.guest_name || 'Convidado',
      visitor_type: c.visitor_type || 'Visitante',
      validity_date: c.valid_until || c.validity_date,
      status: c.status,
    }))

    const isProprietario = (target.tipo_morador ?? '').toLowerCase().includes('propriet')

    return {
      success: true,
      profile: target,
      activeLinks,
      futureReservas,
      futureConvites,
      isProprietario,
    }
  } catch (err: unknown) {
    console.error('Erro em adminGetInactivationContext:', err)
    const msg = err instanceof Error ? err.message : 'Erro ao obter dados para inativação.'
    return { error: msg }
  }
}

export async function adminInactivateResident(data: {
  profileId: string
  vinculoId: string
  dataSaida: string
  motivo: string
  continuaProprietario?: boolean
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    // 1. Obter operador
    const { data: opProfile, error: opError } = await supabase
      .from('perfil')
      .select('condominio_id, papel_sistema, status_aprovacao, bloqueado')
      .eq('id', user.id)
      .single()

    if (opError || !opProfile || !isAdminRole(opProfile.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem inativar moradores.' }
    }

    if (data.profileId === user.id) {
      return { error: 'Operação inválida. Não é permitido inativar o próprio usuário operador.' }
    }

    if (!data.motivo || !data.motivo.trim()) {
      return { error: 'O motivo da inativação é obrigatório.' }
    }

    if (!data.dataSaida) {
      return { error: 'A data de saída é obrigatória.' }
    }

    let parsedDataSaida = data.dataSaida
    if (/^\d{4}-\d{2}-\d{2}$/.test(data.dataSaida)) {
      parsedDataSaida = new Date(`${data.dataSaida}T12:00:00.000Z`).toISOString()
    }

    // 2. Invocar RPC canônica transacional
    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_inativar_morador', {
      p_perfil_id: data.profileId,
      p_vinculo_id: data.vinculoId,
      p_data_saida: parsedDataSaida,
      p_motivo: data.motivo.trim(),
      p_continua_proprietario: data.continuaProprietario ?? false,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_inativar_morador:', rpcError)
      return { error: translateInactivationError(rpcError.message) }
    }

    // 3. Revalidar rotas afetadas
    revalidatePath('/admin/moradores')
    revalidatePath(`/admin/moradores/${data.profileId}`)
    revalidatePath('/portaria')
    revalidatePath('/admin/aprovacoes')

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminInactivateResident:', err)
    const msg = err instanceof Error ? translateInactivationError(err.message) : 'Erro interno ao processar a inativação.'
    return { error: msg }
  }
}

function translateCreateLinkError(errorMsg: string): string {
  if (errorMsg.includes('deve ser posterior à última data de saída')) {
    return 'Para esta unidade, a data de entrada do novo vínculo deve ser posterior à última data de saída.'
  }
  if (errorMsg.includes('não pode ser anterior à data de saída')) {
    return 'A data de entrada não pode ser anterior à data de saída do período anterior nesta mesma unidade.'
  }
  if (errorMsg.includes('superior a 30 dias no futuro')) {
    return 'A data de entrada não pode ser superior a 30 dias no futuro.'
  }
  if (errorMsg.includes('bloqueio administrativo ativo')) {
    return 'Este usuário possui um bloqueio administrativo ativo. Reative o acesso antes de criar um novo vínculo residencial.'
  }
  if (errorMsg.includes('já possui um vínculo residencial ativo')) {
    return 'Este morador já possui um vínculo residencial ativo.'
  }
  if (errorMsg.includes('cadastros pendentes ou reprovados')) {
    return 'Operação não permitida para cadastros pendentes ou reprovados.'
  }
  if (errorMsg.includes('Status cadastral incompatível')) {
    return 'Status cadastral incompatível para criação de novo vínculo.'
  }
  if (errorMsg.includes('outro condomínio') || errorMsg.includes('multi-tenant') || errorMsg.includes('condomínio diferente')) {
    return 'Violação de condomínio. A unidade ou o morador não pertencem ao condomínio atual.'
  }
  if (errorMsg.includes('Unidade residencial não encontrada')) {
    return 'Unidade residencial não encontrada no sistema.'
  }
  if (errorMsg.includes('Tipo de morador inválido')) {
    return 'Tipo de morador inválido.'
  }
  if (errorMsg.includes('A data de entrada é obrigatória')) {
    return 'A data de entrada é obrigatória.'
  }
  return errorMsg.replace(/^ERROR:\s*/i, '').replace(/CONTEXT:[\s\S]*/i, '').trim() || 'Erro ao processar criação de novo vínculo.'
}

export async function adminGetResidentLinkContext(profileId: string) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    // 1. Obter operador e condomínio
    const { data: opProfile, error: opError } = await supabase
      .from('perfil')
      .select('condominio_id, papel_sistema')
      .eq('id', user.id)
      .single()

    if (opError || !opProfile || !isAdminRole(opProfile.papel_sistema)) {
      return { error: 'Permissão negada. Apenas administradores e síndicos podem criar vínculos de morador.' }
    }

    const condoId = opProfile.condominio_id
    if (!condoId) return { error: 'Condomínio não identificado.' }

    // 2. Obter perfil do morador alvo
    const { data: target, error: targetError } = await supabase
      .from('perfil')
      .select('id, nome_completo, email, papel_sistema, status_aprovacao, bloqueado, tipo_morador, bloco_txt, apto_txt, condominio_id')
      .eq('id', profileId)
      .eq('condominio_id', condoId)
      .single()

    if (targetError || !target) {
      return { error: 'Morador não localizado neste condomínio.' }
    }

    // 3. Obter blocos do condomínio
    const { data: blocosRaw, error: blocosError } = await supabase
      .from('blocos')
      .select('id, nome_ou_numero')
      .eq('condominio_id', condoId)
      .order('nome_ou_numero', { ascending: true })

    if (blocosError) {
      return { error: 'Erro ao carregar blocos do condomínio.' }
    }

    // 4. Obter unidades do condomínio com apartamentos
    const { data: unidadesRaw, error: unidadesError } = await supabase
      .from('unidades')
      .select(`
        id,
        bloco_id,
        apartamentos (
          id,
          numero
        )
      `)
      .eq('condominio_id', condoId)

    if (unidadesError) {
      return { error: 'Erro ao carregar unidades do condomínio.' }
    }

    const units = (unidadesRaw ?? []).map((u: any) => ({
      id: u.id,
      bloco_id: u.bloco_id,
      numero: u.apartamentos?.numero || '',
    })).sort((a: any, b: any) => a.numero.localeCompare(b.numero, undefined, { numeric: true }))

    // 5. Obter último vínculo inativo do morador para referência temporal
    const { data: lastLink } = await supabase
      .from('unidade_perfil')
      .select(`
        id,
        unidade_id,
        status,
        data_entrada,
        data_saida,
        unidades (
          blocos ( nome_ou_numero ),
          apartamentos ( numero )
        )
      `)
      .eq('perfil_id', profileId)
      .order('data_saida', { ascending: false, nullsFirst: false })
      .limit(1)
      .maybeSingle()

    const lastExitInfo = lastLink ? {
      unidadeId: lastLink.unidade_id,
      dataSaida: lastLink.data_saida,
      bloco: (lastLink as any).unidades?.blocos?.nome_ou_numero ?? '',
      apto: (lastLink as any).unidades?.apartamentos?.numero ?? '',
    } : null

    return {
      success: true,
      profile: target,
      blocos: blocosRaw ?? [],
      units,
      lastExitInfo,
    }
  } catch (err: unknown) {
    console.error('Erro em adminGetResidentLinkContext:', err)
    const msg = err instanceof Error ? err.message : 'Erro ao obter dados para novo vínculo.'
    return { error: msg }
  }
}

export async function adminCreateResidentLink(data: {
  profileId: string
  unidadeId: string
  dataEntrada: string
  tipoMorador: string
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    // 1. Obter operador
    const { data: opProfile, error: opError } = await supabase
      .from('perfil')
      .select('condominio_id, papel_sistema, status_aprovacao, bloqueado')
      .eq('id', user.id)
      .single()

    if (opError || !opProfile || !isAdminRole(opProfile.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem criar novos vínculos de morador.' }
    }

    if (!data.profileId) {
      return { error: 'Identificador do morador é obrigatório.' }
    }

    if (!data.unidadeId) {
      return { error: 'Selecione uma unidade residencial.' }
    }

    if (!data.dataEntrada) {
      return { error: 'A data de entrada é obrigatória.' }
    }

    let parsedDataEntrada = data.dataEntrada
    if (/^\d{4}-\d{2}-\d{2}$/.test(data.dataEntrada)) {
      parsedDataEntrada = new Date(`${data.dataEntrada}T12:00:00.000Z`).toISOString()
    }

    // 2. Invocar RPC canônica transacional
    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_criar_vinculo_morador', {
      p_perfil_id: data.profileId,
      p_unidade_id: data.unidadeId,
      p_data_entrada: parsedDataEntrada,
      p_tipo_morador: data.tipoMorador || 'Morador (a)',
    })

    if (rpcError) {
      console.error('Erro na RPC admin_criar_vinculo_morador:', rpcError)
      return { error: translateCreateLinkError(rpcError.message) }
    }

    // 3. Revalidar rotas afetadas
    revalidatePath('/admin/moradores')
    revalidatePath(`/admin/moradores/${data.profileId}`)
    revalidatePath('/portaria')
    revalidatePath('/admin/aprovacoes')

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminCreateResidentLink:', err)
    const msg = err instanceof Error ? translateCreateLinkError(err.message) : 'Erro interno ao criar novo vínculo.'
    return { error: msg }
  }
}

// ============================================================================
// VEÍCULOS CANÔNICOS (Gate 3D.2-B)
// ============================================================================

export async function adminCreateVehicle(data: {
  profileId: string
  unidadeId: string
  placa: string
  tipo: string
  marca: string
  modelo: string
  cor: string
  ano?: number | null
  observacao?: string | null
  vagaNumero?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem cadastrar veículos.' }
    }

    if (!data.profileId) return { error: 'Identificador do morador é obrigatório.' }
    if (!data.unidadeId) return { error: 'Identificador da unidade é obrigatório.' }
    if (!data.placa?.trim()) return { error: 'A placa do veículo é obrigatória.' }
    if (!data.tipo?.trim()) return { error: 'O tipo do veículo é obrigatório.' }
    if (!data.marca?.trim()) return { error: 'A marca do veículo é obrigatória.' }
    if (!data.modelo?.trim()) return { error: 'O modelo do veículo é obrigatório.' }
    if (!data.cor?.trim()) return { error: 'A cor do veículo é obrigatória.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_cadastrar_veiculo', {
      p_perfil_id: data.profileId,
      p_unidade_id: data.unidadeId,
      p_placa: data.placa.trim(),
      p_tipo: data.tipo.trim(),
      p_marca: data.marca.trim(),
      p_modelo: data.modelo.trim(),
      p_cor: data.cor.trim(),
      p_ano: data.ano ?? null,
      p_observacao: data.observacao?.trim() || null,
      p_vaga_numero: data.vagaNumero?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_cadastrar_veiculo:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    revalidatePath(`/admin/moradores/${data.profileId}`)

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminCreateVehicle:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao cadastrar veículo.'
    return { error: msg }
  }
}

export async function adminUpdateVehicle(data: {
  veiculoId: string
  profileId: string
  tipo: string
  marca: string
  modelo: string
  cor: string
  ano?: number | null
  observacao?: string | null
  vagaNumero?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem atualizar veículos.' }
    }

    if (!data.veiculoId) return { error: 'Identificador do veículo é obrigatório.' }
    if (!data.tipo?.trim()) return { error: 'O tipo do veículo é obrigatório.' }
    if (!data.marca?.trim()) return { error: 'A marca do veículo é obrigatória.' }
    if (!data.modelo?.trim()) return { error: 'O modelo do veículo é obrigatório.' }
    if (!data.cor?.trim()) return { error: 'A cor do veículo é obrigatória.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_atualizar_veiculo', {
      p_veiculo_id: data.veiculoId,
      p_tipo: data.tipo.trim(),
      p_marca: data.marca.trim(),
      p_modelo: data.modelo.trim(),
      p_cor: data.cor.trim(),
      p_ano: data.ano ?? null,
      p_observacao: data.observacao?.trim() || null,
      p_vaga_numero: data.vagaNumero?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_atualizar_veiculo:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminUpdateVehicle:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao atualizar veículo.'
    return { error: msg }
  }
}

export async function adminCorrectVehiclePlate(data: {
  veiculoId: string
  profileId: string
  novaPlaca: string
  motivo: string
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem corrigir placas.' }
    }

    if (!data.veiculoId) return { error: 'Identificador do veículo é obrigatório.' }
    if (!data.novaPlaca?.trim()) return { error: 'A nova placa é obrigatória.' }
    if (!data.motivo?.trim()) return { error: 'O motivo da correção da placa é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_corrigir_placa_veiculo', {
      p_veiculo_id: data.veiculoId,
      p_nova_placa: data.novaPlaca.trim(),
      p_motivo: data.motivo.trim(),
    })

    if (rpcError) {
      console.error('Erro na RPC admin_corrigir_placa_veiculo:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminCorrectVehiclePlate:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao retificar placa.'
    return { error: msg }
  }
}

export async function adminInactivateVehicle(data: {
  veiculoId: string
  profileId: string
  motivo: string
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem inativar veículos.' }
    }

    if (!data.veiculoId) return { error: 'Identificador do veículo é obrigatório.' }
    if (!data.motivo?.trim()) return { error: 'O motivo da inativação é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_inativar_veiculo', {
      p_veiculo_id: data.veiculoId,
      p_motivo: data.motivo.trim(),
    })

    if (rpcError) {
      console.error('Erro na RPC admin_inativar_veiculo:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminInactivateVehicle:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao inativar veículo.'
    return { error: msg }
  }
}

export async function adminReactivateVehicle(data: {
  veiculoId: string
  profileId: string
  motivo?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem reativar veículos.' }
    }

    if (!data.veiculoId) return { error: 'Identificador do veículo é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_reativar_veiculo', {
      p_veiculo_id: data.veiculoId,
      p_motivo: data.motivo?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_reativar_veiculo:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminReactivateVehicle:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao reativar veículo.'
    return { error: msg }
  }
}

// ============================================================================
// BASE CADASTRAL 360º — MÓDULO PETS (GATE 3E.2-B)
// ============================================================================

export async function adminCreatePet(data: {
  profileId: string
  unidadeId: string
  nome: string
  especie: string
  raca?: string | null
  sexo?: string | null
  porte?: string | null
  cor?: string | null
  dataNascimento?: string | null
  castrado?: boolean | null
  vacinado?: boolean | null
  observacao?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem cadastrar pets.' }
    }

    if (!data.profileId) return { error: 'O morador tutor é obrigatório.' }
    if (!data.unidadeId) return { error: 'A unidade residencial é obrigatória.' }
    if (!data.nome?.trim()) return { error: 'O nome do pet é obrigatório.' }
    if (!data.especie?.trim()) return { error: 'A espécie do pet é obrigatória.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_cadastrar_pet', {
      p_perfil_id: data.profileId,
      p_unidade_id: data.unidadeId,
      p_nome: data.nome.trim(),
      p_especie: data.especie.trim().toLowerCase(),
      p_raca: data.raca?.trim() || null,
      p_sexo: data.sexo?.trim().toLowerCase() || null,
      p_porte: data.porte?.trim().toLowerCase() || null,
      p_cor: data.cor?.trim() || null,
      p_data_nascimento: data.dataNascimento || null,
      p_castrado: typeof data.castrado === 'boolean' ? data.castrado : null,
      p_vacinado: typeof data.vacinado === 'boolean' ? data.vacinado : null,
      p_observacao: data.observacao?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_cadastrar_pet:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    revalidatePath(`/admin/moradores/${data.profileId}`)

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminCreatePet:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao cadastrar pet.'
    return { error: msg }
  }
}

export async function adminUpdatePet(data: {
  petId: string
  profileId: string
  nome: string
  especie: string
  raca?: string | null
  sexo?: string | null
  porte?: string | null
  cor?: string | null
  dataNascimento?: string | null
  castrado?: boolean | null
  vacinado?: boolean | null
  observacao?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem atualizar pets.' }
    }

    if (!data.petId) return { error: 'Identificador do pet é obrigatório.' }
    if (!data.nome?.trim()) return { error: 'O nome do pet é obrigatório.' }
    if (!data.especie?.trim()) return { error: 'A espécie do pet é obrigatória.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_atualizar_pet', {
      p_pet_id: data.petId,
      p_nome: data.nome.trim(),
      p_especie: data.especie.trim().toLowerCase(),
      p_raca: data.raca?.trim() || null,
      p_sexo: data.sexo?.trim().toLowerCase() || null,
      p_porte: data.porte?.trim().toLowerCase() || null,
      p_cor: data.cor?.trim() || null,
      p_data_nascimento: data.dataNascimento || null,
      p_castrado: typeof data.castrado === 'boolean' ? data.castrado : null,
      p_vacinado: typeof data.vacinado === 'boolean' ? data.vacinado : null,
      p_observacao: data.observacao?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_atualizar_pet:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminUpdatePet:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao atualizar pet.'
    return { error: msg }
  }
}

export async function adminInactivatePet(data: {
  petId: string
  profileId: string
  motivo: string
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem inativar pets.' }
    }

    if (!data.petId) return { error: 'Identificador do pet é obrigatório.' }
    if (!data.motivo?.trim()) return { error: 'O motivo da inativação é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_inativar_pet', {
      p_pet_id: data.petId,
      p_motivo: data.motivo.trim(),
    })

    if (rpcError) {
      console.error('Erro na RPC admin_inativar_pet:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminInactivatePet:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao inativar pet.'
    return { error: msg }
  }
}

export async function adminReactivatePet(data: {
  petId: string
  profileId: string
  motivo?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem reativar pets.' }
    }

    if (!data.petId) return { error: 'Identificador do pet é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_reativar_pet', {
      p_pet_id: data.petId,
      p_motivo: data.motivo?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_reativar_pet:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminReactivatePet:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao reativar pet.'
    return { error: msg }
  }
}

export async function adminTransferPetUnit(data: {
  petId: string
  profileId: string
  novaUnidadeId: string
  motivo?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem transferir unidades de pets.' }
    }

    if (!data.petId) return { error: 'Identificador do pet é obrigatório.' }
    if (!data.novaUnidadeId) return { error: 'A nova unidade residencial é obrigatória.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_transferir_unidade_pet', {
      p_pet_id: data.petId,
      p_nova_unidade_id: data.novaUnidadeId,
      p_motivo: data.motivo?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_transferir_unidade_pet:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminTransferPetUnit:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao transferir unidade do pet.'
    return { error: msg }
  }
}

// ==============================================================================
// BASE CADASTRAL 360º — GATE 3F.2-B — FOTOS DE PETS E VEÍCULOS
// ==============================================================================

export async function adminSavePetPhoto(data: {
  petId: string
  fotoPath: string
  profileId?: string
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    if (!data.petId) return { error: 'Identificador do pet é obrigatório.' }
    if (!data.fotoPath?.trim()) return { error: 'O caminho da foto é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_salvar_foto_pet', {
      p_pet_id: data.petId,
      p_foto_path: data.fotoPath.trim(),
    })

    if (rpcError) {
      console.error('Erro na RPC admin_salvar_foto_pet:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminSavePetPhoto:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao salvar foto do pet.'
    return { error: msg }
  }
}

export async function adminRemovePetPhoto(data: {
  petId: string
  motivo?: string | null
  profileId?: string
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    if (!data.petId) return { error: 'Identificador do pet é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_remover_foto_pet', {
      p_pet_id: data.petId,
      p_motivo: data.motivo?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_remover_foto_pet:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminRemovePetPhoto:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao remover foto do pet.'
    return { error: msg }
  }
}

export async function adminSaveVehiclePhoto(data: {
  veiculoId: string
  fotoPath: string
  profileId?: string
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    if (!data.veiculoId) return { error: 'Identificador do veículo é obrigatório.' }
    if (!data.fotoPath?.trim()) return { error: 'O caminho da foto é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_salvar_foto_veiculo', {
      p_veiculo_id: data.veiculoId,
      p_foto_path: data.fotoPath.trim(),
    })

    if (rpcError) {
      console.error('Erro na RPC admin_salvar_foto_veiculo:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminSaveVehiclePhoto:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao salvar foto do veículo.'
    return { error: msg }
  }
}

export async function adminRemoveVehiclePhoto(data: {
  veiculoId: string
  motivo?: string | null
  profileId?: string
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    if (!data.veiculoId) return { error: 'Identificador do veículo é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_remover_foto_veiculo', {
      p_veiculo_id: data.veiculoId,
      p_motivo: data.motivo?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_remover_foto_veiculo:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminRemoveVehiclePhoto:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao remover foto do veículo.'
    return { error: msg }
  }
}

// ==============================================================================
// BASE CADASTRAL 360º — GATE 3G.3-B2 — DEPENDENTES (SERVER ACTIONS)
// ==============================================================================

export async function adminCadastrarDependente(data: {
  profileId: string
  unidadeId: string
  nomeCompleto: string
  parentesco?: string | null
  dataNascimento?: string | null
  observacao?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem cadastrar dependentes.' }
    }

    if (!data.profileId) return { error: 'O morador responsável é obrigatório.' }
    if (!data.unidadeId) return { error: 'A unidade residencial é obrigatória.' }
    if (!data.nomeCompleto?.trim()) return { error: 'O nome completo do dependente é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_cadastrar_dependente', {
      p_unidade_id: data.unidadeId,
      p_responsavel_perfil_id: data.profileId,
      p_nome_completo: data.nomeCompleto.trim(),
      p_parentesco: data.parentesco?.trim() || null,
      p_data_nascimento: data.dataNascimento || null,
      p_observacao: data.observacao?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_cadastrar_dependente:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    revalidatePath(`/admin/moradores/${data.profileId}`)

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminCadastrarDependente:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao cadastrar dependente.'
    return { error: msg }
  }
}

export async function adminAtualizarDependente(data: {
  dependenteId: string
  profileId: string
  nomeCompleto: string
  parentesco?: string | null
  dataNascimento?: string | null
  observacao?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem atualizar dependentes.' }
    }

    if (!data.dependenteId) return { error: 'Identificador do dependente é obrigatório.' }
    if (!data.nomeCompleto?.trim()) return { error: 'O nome completo do dependente é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_atualizar_dependente', {
      p_dependente_id: data.dependenteId,
      p_nome_completo: data.nomeCompleto.trim(),
      p_parentesco: data.parentesco?.trim() || null,
      p_data_nascimento: data.dataNascimento || null,
      p_observacao: data.observacao?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_atualizar_dependente:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminAtualizarDependente:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao atualizar dependente.'
    return { error: msg }
  }
}

export async function adminInativarDependente(data: {
  dependenteId: string
  profileId: string
  motivo: string
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem inativar dependentes.' }
    }

    if (!data.dependenteId) return { error: 'Identificador do dependente é obrigatório.' }
    if (!data.motivo?.trim()) return { error: 'O motivo da inativação é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_inativar_dependente', {
      p_dependente_id: data.dependenteId,
      p_motivo: data.motivo.trim(),
    })

    if (rpcError) {
      console.error('Erro na RPC admin_inativar_dependente:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminInativarDependente:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao inativar dependente.'
    return { error: msg }
  }
}

export async function adminReativarDependente(data: {
  dependenteId: string
  profileId: string
  motivo?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem reativar dependentes.' }
    }

    if (!data.dependenteId) return { error: 'Identificador do dependente é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_reativar_dependente', {
      p_dependente_id: data.dependenteId,
      p_motivo: data.motivo?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_reativar_dependente:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminReativarDependente:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao reativar dependente.'
    return { error: msg }
  }
}

export async function adminTrocarResponsavelDependente(data: {
  dependenteId: string
  profileId: string
  novoResponsavelPerfilId: string
  motivo?: string | null
}) {
  try {
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    const { data: opProfile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    if (!isAdminRole(opProfile?.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem transferir responsabilidade de dependentes.' }
    }

    if (!data.dependenteId) return { error: 'Identificador do dependente é obrigatório.' }
    if (!data.novoResponsavelPerfilId) return { error: 'O novo responsável é obrigatório.' }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('admin_trocar_responsavel_dependente', {
      p_dependente_id: data.dependenteId,
      p_novo_responsavel_perfil_id: data.novoResponsavelPerfilId,
      p_motivo: data.motivo?.trim() || null,
    })

    if (rpcError) {
      console.error('Erro na RPC admin_trocar_responsavel_dependente:', rpcError)
      return { error: rpcError.message }
    }

    revalidatePath('/admin/moradores')
    if (data.profileId) {
      revalidatePath(`/admin/moradores/${data.profileId}`)
    }

    return {
      success: true,
      result: rpcResult,
    }
  } catch (err: unknown) {
    console.error('Erro interno em adminTrocarResponsavelDependente:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao transferir responsabilidade do dependente.'
    return { error: msg }
  }
}

/**
 * Gate 3G.4-D2: Consulta a ocupação atual de uma unidade residencial.
 * Retorna a contagem de moradores ativos + dependentes ativos não-convertidos.
 * Usada pelo modal "Novo Vínculo" para validação UX do limite de 4 pessoas.
 * A RPC admin_criar_vinculo_morador permanece como autoridade final.
 */
export async function adminGetUnitOccupancy(unidadeId: string): Promise<{
  ocupacao?: number
  error?: string
}> {
  try {
    if (!unidadeId) return { error: 'ID da unidade não informado.' }

    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Sessão expirada.' }

    // A) Moradores ativos: COUNT DISTINCT perfil_id em unidade_perfil
    const { count: moradoresCount, error: morErr } = await supabase
      .from('unidade_perfil')
      .select('perfil_id', { count: 'exact', head: true })
      .eq('unidade_id', unidadeId)
      .eq('status', 'ativo')

    if (morErr) {
      console.error('[adminGetUnitOccupancy] Erro ao contar moradores:', morErr.message)
      return { error: 'Falha ao consultar ocupação da unidade.' }
    }

    // B) Dependentes ativos não-convertidos
    const { count: depsCount, error: depErr } = await supabase
      .from('dependentes')
      .select('id', { count: 'exact', head: true })
      .eq('unidade_id', unidadeId)
      .eq('status', 'ativo')
      .is('perfil_convertido_id', null)

    if (depErr) {
      console.error('[adminGetUnitOccupancy] Erro ao contar dependentes:', depErr.message)
      return { error: 'Falha ao consultar ocupação da unidade.' }
    }

    return { ocupacao: (moradoresCount ?? 0) + (depsCount ?? 0) }
  } catch (err: unknown) {
    console.error('[adminGetUnitOccupancy] Erro interno:', err)
    return { error: 'Erro interno ao consultar ocupação.' }
  }
}

/**
 * Gate 3H.2-C1: Consulta paginada server-side dos convites emitidos por um morador.
 * Read-only com isolamento multi-tenant estrito e range de 5 registros por página.
 */
export async function adminGetResidentInvitesPage(residentId: string, page: number = 1) {
  try {
    if (!residentId?.trim()) {
      return { error: 'Identificador do morador é obrigatório.' }
    }

    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    // Obter perfil do operador autenticado e validar permissão administrativa
    const { data: operatorProfile, error: operatorError } = await supabase
      .from('perfil')
      .select('condominio_id, papel_sistema')
      .eq('id', user.id)
      .single()

    if (operatorError || !operatorProfile || !isAdminRole(operatorProfile.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem consultar convites.' }
    }

    const condoId = operatorProfile.condominio_id
    if (!condoId) {
      return { error: 'Condomínio do operador não identificado.' }
    }

    const PAGE_SIZE = 5
    const safePage = Math.max(1, Math.floor(Number(page) || 1))
    const from = (safePage - 1) * PAGE_SIZE
    const to = from + PAGE_SIZE - 1

    const { data: convites, error: queryError, count } = await supabase
      .from('convites')
      .select(
        'id, resident_id, guest_name, visitor_type, status, validity_date, valid_until, qr_data, created_at, visitante_compareceu, liberado_em, liberado_por, documento, placa, whatsapp, observacao, cracha_referencia, bloco_destino, apto_destino, criado_por_portaria',
        { count: 'exact' }
      )
      .eq('resident_id', residentId.trim())
      .eq('condominio_id', condoId)
      .order('created_at', { ascending: false })
      .range(from, to)

    if (queryError) {
      console.error('[adminGetResidentInvitesPage] Erro ao consultar convites:', queryError)
      return { error: 'Falha ao consultar convites do morador.' }
    }

    const total = count ?? 0
    const totalPages = total > 0 ? Math.ceil(total / PAGE_SIZE) : 0

    return {
      success: true,
      data: convites ?? [],
      page: safePage,
      pageSize: PAGE_SIZE,
      total,
      totalPages,
    }
  } catch (err: unknown) {
    console.error('[adminGetResidentInvitesPage] Erro interno:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao consultar convites.'
    return { error: msg }
  }
}

/**
 * Gate 3H: Consulta paginada dos registros de portaria (acessos) de uma unidade residencial.
 * Read-only com isolamento multi-tenant estrito e range de 5 registros por página.
 */
export async function adminGetUnitAccessPage(
  condominioId: string,
  bloco: string,
  apto: string,
  page: number = 1
) {
  try {
    const safePage = Math.max(1, Math.floor(Number(page) || 1))
    const PAGE_SIZE = 5

    if (!condominioId?.trim() || !bloco?.trim() || !apto?.trim()) {
      return {
        success: true,
        data: [],
        page: safePage,
        pageSize: PAGE_SIZE,
        total: 0,
        totalPages: 0,
      }
    }

    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado' }

    // Obter perfil do operador autenticado e validar permissão administrativa
    const { data: operatorProfile, error: operatorError } = await supabase
      .from('perfil')
      .select('condominio_id, papel_sistema')
      .eq('id', user.id)
      .single()

    if (operatorError || !operatorProfile || !isAdminRole(operatorProfile.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem consultar acessos.' }
    }

    const from = (safePage - 1) * 5
    const to = from + 4

    const { data, error: queryError, count } = await supabase
      .from('visitante_registros')
      .select('id, nome, tipo_visitante, entrada_at, saida_at, status, created_at', { count: 'exact' })
      .eq('condominio_id', condominioId.trim())
      .eq('bloco', bloco.trim())
      .eq('apto', apto.trim())
      .order('entrada_at', { ascending: false })
      .range(from, to)

    if (queryError) {
      console.error('[adminGetUnitAccessPage] Erro ao consultar registros de portaria:', queryError)
      return { error: 'Falha ao consultar registros de portaria da unidade.' }
    }

    const total = count ?? 0

    return {
      success: true,
      data: data ?? [],
      page: safePage,
      pageSize: PAGE_SIZE,
      total,
      totalPages: Math.ceil(total / 5),
    }
  } catch (err: unknown) {
    console.error('[adminGetUnitAccessPage] Erro interno:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao consultar acessos.'
    return { error: msg }
  }
}

/**
 * Gate 3I.3-B: Edição canônica dos dados gerais do morador para o Resident 360.
 * Atualiza exclusivamente nome_completo, whatsapp, tipo_morador e papel_sistema.
 * Não altera email, unidades nem credenciais de autenticação.
 * Registra trilha de auditoria em public.perfil_audit_log (RESIDENT_GENERAL_DATA_UPDATED).
 */
export async function adminUpdateResidentGeneralData(data: {
  residentId: string
  nome_completo: string
  whatsapp: string
  tipo_morador: string
  papel_sistema: string
  motivo?: string
}): Promise<{ success?: boolean; error?: string }> {
  try {
    if (!data.residentId?.trim()) {
      return { error: 'Identificador do morador é obrigatório.' }
    }

    const cleanNome = data.nome_completo?.trim()
    if (!cleanNome) {
      return { error: 'O nome completo é obrigatório.' }
    }

    const normalizedWhatsapp = normalizePhoneE164(data.whatsapp)
    if (!normalizedWhatsapp) {
      return { error: 'Número de telefone/WhatsApp inválido. Informe um número com DDD válido (ex: 11 99999-9999).' }
    }

    const cleanTipoMorador = data.tipo_morador?.trim()
    if (!cleanTipoMorador) {
      return { error: 'O tipo de morador é obrigatório.' }
    }

    if (!data.papel_sistema?.trim()) {
      return { error: 'O papel no sistema é obrigatório.' }
    }

    // 1. Autenticação e autorização do operador
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return { error: 'Não autorizado.' }

    const { data: operatorProfile, error: operatorError } = await supabase
      .from('perfil')
      .select('condominio_id, papel_sistema')
      .eq('id', user.id)
      .single()

    if (operatorError || !operatorProfile || !isAdminRole(operatorProfile.papel_sistema)) {
      return { error: 'Permissão negada. Apenas síndicos e administradores podem editar moradores.' }
    }

    const isTargetAdmin = isTechnicalAdminRole(data.papel_sistema)
    let canonicalPapel = isTargetAdmin ? 'Admin' : normalizeRoleForPersistence(data.papel_sistema)
    const normPapelLower = canonicalPapel.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    if (normPapelLower.startsWith('morador')) canonicalPapel = 'Morador'
    else if (normPapelLower.startsWith('porteir')) canonicalPapel = 'Porteiro'
    else if (normPapelLower.startsWith('zelador')) canonicalPapel = 'Zelador'
    else if (normPapelLower.includes('subsindico')) canonicalPapel = 'Subsíndico'
    else if (normPapelLower.includes('sindico')) canonicalPapel = 'Síndico'

    if (isTargetAdmin) {
      if (!canPromoteToAdmin(operatorProfile.papel_sistema)) {
        return { error: 'Permissão negada. Somente o Síndico ou Administrador podem atribuir a função de Admin.' }
      }
    }

    // 3. Execução atômica via RPC transacional no PostgreSQL
    const { error: rpcError } = await supabase.rpc('admin_atualizar_dados_gerais_morador', {
      p_resident_id: data.residentId.trim(),
      p_nome_completo: cleanNome,
      p_whatsapp: normalizedWhatsapp,
      p_tipo_morador: cleanTipoMorador,
      p_papel_sistema: canonicalPapel,
      p_motivo: data.motivo?.trim() || null,
    })

    if (rpcError) {
      console.error('[adminUpdateResidentGeneralData] Erro na RPC admin_atualizar_dados_gerais_morador:', rpcError)
      return { error: rpcError.message || 'Falha ao atualizar os dados do morador.' }
    }

    // 4. Revalidação de rotas
    revalidatePath('/admin/moradores')
    revalidatePath(`/admin/moradores/${data.residentId.trim()}`)

    return { success: true }
  } catch (err: unknown) {
    console.error('[adminUpdateResidentGeneralData] Erro interno:', err)
    const msg = err instanceof Error ? err.message : 'Erro interno ao atualizar os dados gerais do morador.'
    return { error: msg }
  }
}
