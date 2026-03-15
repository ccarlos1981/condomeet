import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import FaleSindicoClient from './fale-sindico-client'

export const metadata = { title: 'Fale com o Síndico — Condomeet' }

export type Thread = {
  id: string
  tipo: string
  assunto: string
  status: string
  ultima_mensagem_em: string
  created_at: string
  _mensagem_count?: number
}

export default async function FaleSindicoPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, nome_completo, bloco_txt, apto_txt')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  const { data: threads, error } = await supabase
    .from('fale_sindico_threads')
    .select('id, tipo, assunto, status, ultima_mensagem_em, created_at')
    .eq('resident_id', user.id)
    .eq('condominio_id', condoId)
    .order('ultima_mensagem_em', { ascending: false })

  if (error) console.error('❌ fale_sindico_threads error:', JSON.stringify(error))

  return (
    <div className="p-6 lg:p-8 max-w-3xl">
      <div className="mb-6">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">Comunicação</p>
        <h1 className="text-2xl font-bold text-gray-900">Fale com o Síndico</h1>
        <p className="text-sm text-gray-500 mt-1">
          Envie mensagens diretamente para a administração do condomínio
        </p>
      </div>

      <FaleSindicoClient
        initialThreads={threads ?? []}
        userId={user.id}
        condoId={condoId}
        userName={profile?.nome_completo ?? 'Morador'}
      />
    </div>
  )
}
