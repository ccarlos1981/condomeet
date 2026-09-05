'use server'

import { createClient as createServerClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'

export interface AppVersionPolicy {
  id: number
  min_android_build: number
  min_ios_build: number
  latest_android_version: string
  latest_ios_version: string
  force_update_title: string
  force_update_message: string
  store_url_android: string
  store_url_ios: string
  is_kill_switch_active: boolean
  updated_at: string
  updated_by: string | null
}

async function checkSuperAdmin() {
  const supabase = await createServerClient()
  const { data: { user }, error: authError } = await supabase.auth.getUser()
  if (authError || !user) {
    throw new Error('Acesso Negado: Usuário não autenticado.')
  }

  // Verifica na tabela oficial de governança system_superadmins
  const { data: superadmin } = await supabase
    .from('system_superadmins')
    .select('email')
    .eq('email', user.email ?? '')
    .maybeSingle()

  if (!superadmin) {
    throw new Error('Acesso Negado: Acesso restrito a SuperAdmins.')
  }

  return user
}

export async function getAppVersionPolicy(): Promise<AppVersionPolicy> {
  await checkSuperAdmin()
  const supabase = await createServerClient()

  const { data, error } = await supabase
    .from('app_version_policy')
    .select('*')
    .eq('id', 1)
    .single()

  if (error || !data) {
    throw new Error(error?.message || 'Política de versão não encontrada.')
  }

  return data as AppVersionPolicy
}

export async function updateAppVersionPolicy(payload: Partial<AppVersionPolicy>): Promise<{ success: boolean; error?: string }> {
  try {
    const user = await checkSuperAdmin()
    const supabase = await createServerClient()

    // Validações de segurança
    if (payload.min_android_build !== undefined && (payload.min_android_build < 1 || payload.min_android_build > 50000)) {
      return { success: false, error: 'Build mínima Android inválida (deve estar entre 1 e 50000).' }
    }
    if (payload.min_ios_build !== undefined && (payload.min_ios_build < 1 || payload.min_ios_build > 50000)) {
      return { success: false, error: 'Build mínima iOS inválida (deve estar entre 1 e 50000).' }
    }

    const { error } = await supabase
      .from('app_version_policy')
      .update({
        ...payload,
        updated_at: new Date().toISOString(),
        updated_by: user.email,
      })
      .eq('id', 1)

    if (error) {
      return { success: false, error: error.message }
    }

    revalidatePath('/super-admin/force-update')
    return { success: true }
  } catch (err: any) {
    return { success: false, error: err.message || 'Erro inesperado ao atualizar política.' }
  }
}

export async function toggleKillSwitch(active: boolean): Promise<{ success: boolean; error?: string }> {
  return updateAppVersionPolicy({ is_kill_switch_active: active })
}

export async function rollbackToBaseline(): Promise<{ success: boolean; error?: string }> {
  return updateAppVersionPolicy({
    min_android_build: 101,
    min_ios_build: 101,
    is_kill_switch_active: false,
  })
}
