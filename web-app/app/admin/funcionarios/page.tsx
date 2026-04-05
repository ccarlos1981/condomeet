import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import FuncionariosClient from './funcionarios-client'

export const metadata = {
  title: 'Funcionários - Condomeet',
}

export default async function FuncionariosPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/login')
  }

  // Obter perfil e verificar o condomínio
  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  if (!profile?.condominio_id) {
    redirect('/condo')
  }

  const r = profile.papel_sistema?.toLowerCase() || ''
  // Apenas admins/sindicos num primeiro momento, 
  // embora o acesso seja também controlado no menu
  const isAdmin = r.includes('síndico') || r.includes('sindico') || r.includes('admin') || r.includes('sub_sindico')

  if (!isAdmin) {
    redirect('/condo')
  }

  // Buscar Funcionários desse condomínio
  const { data: funcionarios } = await supabase
    .from('funcionarios')
    .select('*')
    .eq('condominio_id', profile.condominio_id)
    .order('nome_do_funcionario', { ascending: true })

  return (
    <FuncionariosClient 
      initialData={funcionarios || []} 
      condominioId={profile.condominio_id} 
      userId={user.id}
    />
  )
}
