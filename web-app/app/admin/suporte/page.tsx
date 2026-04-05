import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import SuporteAdminClient from './suporte-admin-client'

export const metadata = { title: 'Suporte Sistema — Admin Condomeet' }

export type SuporteChat = {
  id: string
  resident_id: string
  condominio_id: string | null
  last_message: string | null
  unread_admin: number
  unread_user: number
  updated_at: string
  created_at: string
  perfil: {
    nome_completo: string
    bloco_txt: string | null
    apto_txt: string | null
  } | null
  condominio: {
    nome: string
  } | null
}

export default async function SuporteSistemaAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  // Check if they are SuperAdmin
  const isSuperAdmin = user.email === 'cristiano.santos@gmx.com' || user.email === 'erikaosc@gmail.com'
  
  if (!isSuperAdmin) redirect('/admin') // Redirect non-superadmins back to standard admin

  // Fetch all chats
  const { data: chats, error } = await supabase
    .from('suporte_sistema_chats')
    .select('id, resident_id, condominio_id, last_message, unread_admin, unread_user, updated_at, created_at')
    .order('updated_at', { ascending: false })

  if (error) console.error('❌ suporte_sistema admin error:', JSON.stringify(error))

  // Manual relational fetching to avoid issues if foreign keys are tricky with generic Next.js supabase client
  const residentIds = [...new Set((chats ?? []).map((t: { resident_id: string }) => t.resident_id).filter(Boolean))]
  const condoIds = [...new Set((chats ?? []).map((t: { condominio_id: string }) => t.condominio_id).filter(Boolean))]
  
  const perfilMap: Record<string, { nome_completo: string; bloco_txt: string | null; apto_txt: string | null }> = {}
  const condoMap: Record<string, { nome: string }> = {}

  if (residentIds.length > 0) {
    const { data: perfis } = await supabase
      .from('perfil')
      .select('id, nome_completo, bloco_txt, apto_txt')
      .in('id', residentIds)
    ;(perfis ?? []).forEach((p: { id: string; nome_completo: string; bloco_txt: string | null; apto_txt: string | null }) => { perfilMap[p.id] = p })
  }

  if (condoIds.length > 0) {
    const { data: condos } = await supabase
      .from('condominios')
      .select('id, nome')
      .in('id', condoIds)
    ;(condos ?? []).forEach((c: { id: string; nome: string }) => { condoMap[c.id] = c })
  }

  const chatsResolved: SuporteChat[] = (chats ?? []).map((t: { id: string; resident_id: string; condominio_id: string | null; last_message: string | null; unread_admin: number; unread_user: number; updated_at: string; created_at: string }) => ({
    ...t,
    perfil: perfilMap[t.resident_id] ?? null,
    condominio: t.condominio_id ? (condoMap[t.condominio_id] ?? { nome: 'Desconhecido' }) : null,
  }))

  return (
    <div className="flex flex-col h-[calc(100vh-4rem)] lg:h-[calc(100vh-6rem)] rounded-xl overflow-hidden shadow-lg border border-gray-200">
      {/* Basic header */}
      <div className="bg-[#111827] border-b border-gray-800 text-white p-5">
        <h1 className="text-xl font-bold tracking-tight">Central de Suporte Global <span className="ml-2 text-xs bg-indigo-500/20 text-indigo-300 px-2 py-1 rounded-full uppercase tracking-widest font-semibold">Super Admin</span></h1>
        <p className="text-sm text-gray-400 mt-1">Conversas diretas estilo WhatsApp com usuários de todos os condomínios.</p>
      </div>

      {/* Main chat client */}
      <SuporteAdminClient
        initialChats={chatsResolved}
        adminId={user.id}
      />
    </div>
  )
}
