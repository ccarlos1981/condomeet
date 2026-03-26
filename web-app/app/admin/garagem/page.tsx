import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import GaragemAdminClient from './garagem-admin-client'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Garagem Inteligente — Painel Admin' }

const SUPER_ADMIN_EMAILS = ['ccarlos1981+60@gmail.com', 'cristiano.santos@gmx.com']

export default async function GaragemAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  if (!SUPER_ADMIN_EMAILS.includes(user.email ?? '')) redirect('/admin')

  // Fetch all garages with owner + condo info
  const { data: garages } = await supabase
    .from('garages')
    .select(`
      *,
      perfil:owner_id ( id, nome_completo, bloco_txt, apto_txt, whatsapp ),
      condominios:condominio_id ( id, nome )
    `)
    .order('created_at', { ascending: false })

  // Fetch all reservations
  const { data: reservations } = await supabase
    .from('garage_reservations')
    .select(`
      *,
      renter:renter_id ( id, nome_completo, bloco_txt, apto_txt ),
      garage:garage_id ( spot_identifier, spot_type )
    `)
    .order('created_at', { ascending: false })
    .limit(100)

  // Fetch all trials
  const { data: trials } = await supabase
    .from('garage_condo_trial')
    .select(`
      *,
      condominios:condominio_id ( id, nome )
    `)
    .order('trial_start', { ascending: false })

  // Fetch earnings summary
  const { data: earnings } = await supabase
    .from('garage_earnings')
    .select('*')
    .order('month', { ascending: false })
    .limit(50)

  return (
    <GaragemAdminClient
      garages={garages ?? []}
      reservations={reservations ?? []}
      trials={trials ?? []}
      earnings={earnings ?? []}
    />
  )
}
