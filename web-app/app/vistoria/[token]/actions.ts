'use server'

import { createClient } from '@supabase/supabase-js'

// Use anon key - RPCs are SECURITY DEFINER, storage has anon upload policy
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export async function submitSignature(formData: FormData) {
  const token = formData.get('token') as string
  const nome = formData.get('nome') as string
  const cpf = formData.get('cpf') as string
  const email = formData.get('email') as string
  const papel = formData.get('papel') as string
  const signatureBase64 = formData.get('signature') as string

  if (!token || !nome || !cpf || !email || !signatureBase64) {
    return { error: 'Todos os campos são obrigatórios (Nome, CPF, Email e Assinatura).' }
  }

  // Validate CPF format (11 digits)
  const cpfClean = cpf.replace(/\D/g, '')
  if (cpfClean.length !== 11) {
    return { error: 'CPF deve ter 11 dígitos.' }
  }

  // Validate email
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (!emailRegex.test(email)) {
    return { error: 'E-mail inválido.' }
  }

  try {
    // Convert base64 to buffer for upload
    const base64Data = signatureBase64.replace(/^data:image\/\w+;base64,/, '')
    const buffer = Buffer.from(base64Data, 'base64')

    // Upload signature image to Storage (anon role with path-restricted policy)
    const fileName = `assinaturas/web/${token}_${Date.now()}.png`
    const { error: uploadError } = await supabase.storage
      .from('vistorias')
      .upload(fileName, buffer, {
        contentType: 'image/png',
        upsert: false,
      })

    if (uploadError) {
      console.error('Upload error:', uploadError)
      return { error: 'Erro ao enviar assinatura. Tente novamente.' }
    }

    // Get public URL
    const { data: urlData } = supabase.storage
      .from('vistorias')
      .getPublicUrl(fileName)

    const assinaturaUrl = urlData.publicUrl

    // Call SECURITY DEFINER RPC to save signature and update vistoria status
    const { data, error: rpcError } = await supabase.rpc('assinar_vistoria_publica', {
      p_token: token,
      p_nome: nome,
      p_cpf: cpfClean,
      p_email: email,
      p_papel: papel || 'inquilino',
      p_assinatura_url: assinaturaUrl,
    })

    if (rpcError) {
      console.error('RPC error:', rpcError)
      return { error: 'Erro ao registrar assinatura.' }
    }

    if (data?.error) {
      return { error: data.error }
    }

    return { success: true }
  } catch (err) {
    console.error('Unexpected error:', err)
    return { error: 'Erro inesperado. Tente novamente.' }
  }
}
