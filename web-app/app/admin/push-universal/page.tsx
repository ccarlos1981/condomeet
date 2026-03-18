import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { Megaphone } from 'lucide-react'
import UniversalPushForm from './UniversalPushForm'

const SUPER_ADMIN_EMAILS = ['ccarlos1981+60@gmail.com', 'cristiano.santos@gmx.com']

export default async function PushUniversalPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user || !SUPER_ADMIN_EMAILS.includes(user.email ?? '')) {
    redirect('/admin')
  }

  // Fetch all condominiums for the dropdown
  const { data: condominios } = await supabase
    .from('condominios')
    .select('id, nome')
    .order('nome')

  return (
    <div>
      <div className="mb-8 flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-orange-50 flex items-center justify-center">
          <Megaphone size={20} className="text-[#FC5931]" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Push Notification Universal</h1>
          <p className="text-gray-500 text-sm mt-0.5">Envie uma notificação para os usuários do sistema</p>
        </div>
      </div>

      <div className="max-w-xl bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
        <UniversalPushForm condominios={condominios ?? []} />
      </div>
    </div>
  )
}
