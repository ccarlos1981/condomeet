'use server'

import { revalidatePath } from 'next/cache'

import { createClient } from '@/lib/supabase/server'

export async function createGlobalTemplate(formData: FormData) {
  const nome = formData.get('nome') as string
  const descricao = formData.get('descricao') as string
  const tipo_bem = formData.get('tipo_bem') as string
  const icone_emoji = formData.get('icone_emoji') as string

  if (!nome || !tipo_bem) {
    return { error: 'Nome e Tipo de Bem são obrigatórios' }
  }

  const supabase = await createClient()

  const { error } = await supabase
    .from('vistoria_templates')
    .insert({
      nome,
      descricao: descricao || null,
      tipo_bem,
      icone_emoji: icone_emoji || '📋',
      is_public: true
    })

  if (error) {
    console.error('Erro ao criar template global:', error)
    return { error: error.message }
  }

  revalidatePath('/admin/checklist')
  return { success: true }
}
