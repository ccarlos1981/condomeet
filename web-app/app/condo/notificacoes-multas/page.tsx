import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import NotificacoesMultasClient from './notificacoes-multas-client'

export const metadata = { title: 'Notificações e Multas — Condomeet' }

export default async function NotificacoesMultasPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch historico
  // RLS (resident_read_multas) automatically ensures users only see records 
  // linked to their unidade_id via unidade_perfil table.
  const { data: historicoRaw } = await supabase
    .from('notificacoes_multas')
    .select(`
      id, tipo, titulo, descricao, anexo_url, lido_em, data_ocorrencia, created_at, status
    `)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  const historico = (historicoRaw || []).map((h: any) => ({
    id: h.id,
    tipo: h.tipo,
    titulo: h.titulo,
    descricao: h.descricao,
    data_ocorrencia: h.data_ocorrencia,
    anexo_url: h.anexo_url,
    lido_em: h.lido_em,
    created_at: h.created_at,
    status: h.status,
    bloco: '',
    apto: ''
  }))

  return (
    <div className="p-6 lg:p-8 max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Notificações e Multas</h1>
        <p className="text-sm text-gray-500 mt-1">
          Acompanhe as notificações e multas emitidas para sua unidade
        </p>
      </div>

      <NotificacoesMultasClient 
        historicoData={historico}
        currentUserId={user.id}
      />
    </div>
  )
}
