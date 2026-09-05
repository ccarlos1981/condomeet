import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { Megaphone } from 'lucide-react'
import UniversalPushForm from './UniversalPushForm'

export default async function PushUniversalPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/admin')
  }

  const { data: superadmin } = await supabase
    .from('system_superadmins')
    .select('email')
    .eq('email', user.email ?? '')
    .maybeSingle()

  if (!superadmin) {
    redirect('/admin')
  }

  // Fetch all condominiums for the dropdown
  const { data: condominios } = await supabase
    .from('condominios')
    .select('id, nome')
    .order('nome')

  // Fetch global agendamentos (condominio_id is NULL)
  const { data: agendamentos } = await supabase
    .from('push_agendamentos_recorrentes')
    .select('id, dia_semana, horario, assunto, mensagem, ativo')
    .is('condominio_id', null)

  // Fetch profiles to calculate total registered users vs active push devices
  const { data: perfis } = await supabase
    .from('perfil')
    .select('condominio_id, fcm_token')

  const condoStats: Record<string, { totalUsuarios: number; totalDispositivos: number }> = {}
  let globalUsuarios = 0
  let globalDispositivos = 0

  if (perfis) {
    for (const p of perfis) {
      globalUsuarios++
      const hasToken = typeof p.fcm_token === 'string' && p.fcm_token.trim().length > 0
      if (hasToken) globalDispositivos++

      if (p.condominio_id) {
        if (!condoStats[p.condominio_id]) {
          condoStats[p.condominio_id] = { totalUsuarios: 0, totalDispositivos: 0 }
        }
        condoStats[p.condominio_id].totalUsuarios++
        if (hasToken) {
          condoStats[p.condominio_id].totalDispositivos++
        }
      }
    }
  }

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-orange-50 flex items-center justify-center">
          <Megaphone size={20} className="text-[#FC5931]" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Push Notification Universal</h1>
          <p className="text-gray-500 text-sm mt-0.5">Envie mensagens instantâneas ou agende notificações semanais para todo o sistema.</p>
        </div>
      </div>

      <UniversalPushForm 
        condominios={condominios ?? []} 
        initialAgendamentos={agendamentos || []}
        stats={{
          global: { totalUsuarios: globalUsuarios, totalDispositivos: globalDispositivos },
          byCondo: condoStats,
        }}
      />
    </div>
  )
}
