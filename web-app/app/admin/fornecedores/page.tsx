import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import FornecedoresClient from './fornecedores-client'
import { isAdminRole } from '@/lib/roles'

export const metadata = {
  title: 'Fornecedores - Condomeet',
}

export default async function FornecedoresPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/login')
  }

  // Get user profile to check condo
  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  if (!profile?.condominio_id) {
    redirect('/condo')
  }

  if (!isAdminRole(profile.papel_sistema)) {
    // Only admins/sindicos can access Fornecedores
    redirect('/condo')
  }

  // Fetch Fornecedores
  const { data: fornecedores } = await supabase
    .from('fornecedores')
    .select('*')
    .eq('condominio_id', profile.condominio_id)
    .order('nome', { ascending: true })

  return (
    <FornecedoresClient 
      initialData={fornecedores || []} 
      condominioId={profile.condominio_id} 
    />
  )
}
