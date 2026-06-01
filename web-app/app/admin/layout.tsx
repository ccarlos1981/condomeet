import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AdminSidebar from './admin-sidebar'
import { cookies } from 'next/headers'

const SUPER_ADMIN_EMAILS = ['ccarlos1981+60@gmail.com', 'cristiano.santos@gmx.com']

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('papel_sistema, nome_completo, condominio_id, administradora_id')
    .eq('id', user.id)
    .single()

  const role = profile?.papel_sistema ?? ''
  const isSuperAdmin = SUPER_ADMIN_EMAILS.includes(user.email ?? '')
  const isAdmin = ['Síndico', 'Síndico (a)', 'sindico', 'ADMIN', 'admin', 'Porteiro', 'Porteria', 'Administradora'].some(r =>
    role.toLowerCase().includes(r.toLowerCase())
  )
  if (!isAdmin && !isSuperAdmin) redirect('/condo')

  let condoId = profile?.condominio_id ?? ''
  let managedCondos: { id: string; nome: string }[] = []

  if (role.toLowerCase() === 'administradora' && profile?.administradora_id) {
    const { data: condos } = await supabase
      .from('condominios')
      .select('id, nome')
      .eq('administradora_id', profile.administradora_id)
    if (condos) managedCondos = condos

    const cookieStore = await cookies()
    const selectedCondoId = cookieStore.get('selected_condo_id')?.value
    if (selectedCondoId && condos?.some(c => c.id === selectedCondoId)) {
      condoId = selectedCondoId
    }
  }

  const { data: condo } = await supabase
    .from('condominios')
    .select('nome')
    .eq('id', condoId)
    .single()

  return (
    <div className="flex min-h-screen bg-[#f3f4f8]">
      <AdminSidebar
        condoName={condo?.nome ?? 'Condomínio'}
        userName={profile?.nome_completo ?? ''}
        role={role}
        isSuperAdmin={isSuperAdmin}
        managedCondos={managedCondos}
      />
      <main className="flex-1 overflow-y-auto min-h-screen p-6 lg:p-8">
        {children}
      </main>
    </div>
  )
}
