import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AprovacoesClient from './aprovacoes-client'
import { AlertCircle } from 'lucide-react'

export default async function ApprovalsPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch ALL profiles (all statuses) — columns that actually exist in perfil
  const { data: profiles, error } = await supabase
    .from('perfil')
    .select('id, nome_completo, bloco_txt, apto_txt, status_aprovacao, papel_sistema, created_at')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 text-red-700 rounded-xl p-6 flex gap-3 items-start">
        <AlertCircle size={20} className="flex-shrink-0 mt-0.5" />
        <div>
          <p className="font-semibold">Erro ao carregar aprovações</p>
          <p className="text-sm mt-1">{error.message}</p>
          <p className="text-xs mt-2 text-red-500">
            Pode ser necessário adicionar uma política RLS que permita ao síndico ler todos os perfis do condomínio.
          </p>
        </div>
      </div>
    )
  }

  return <AprovacoesClient profiles={profiles ?? []} />
}
