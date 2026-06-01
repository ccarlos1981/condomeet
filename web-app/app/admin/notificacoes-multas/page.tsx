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
    .select('condominio_id, nome_completo, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Fetch all units to get their IDs and names
  const { data: unidadesRaw } = await supabase
    .from('unidades')
    .select('id, blocos ( nome_ou_numero ), apartamentos ( numero )')
    .eq('condominio_id', condoId)

  // Map units for the UI
  interface UnitOption { id: string; bloco: string; apto: string }
  const units: UnitOption[] = []
  
  if (unidadesRaw) {
    for (const u of unidadesRaw as any[]) {
      if (u.blocos?.nome_ou_numero && u.apartamentos?.numero) {
        units.push({
          id: u.id,
          bloco: u.blocos.nome_ou_numero,
          apto: u.apartamentos.numero
        })
      }
    }
  }

  // Group by block to fill dropdowns easily
  const blocosDisponiveis = Array.from(new Set(units.map(u => u.bloco))).sort((a, z) => a.localeCompare(z, 'pt-BR', { numeric: true }))

  // Fetch historico
  const { data: historicoRaw } = await supabase
    .from('notificacoes_multas')
    .select(`
      id, tipo, titulo, descricao, anexo_url, lido_em, data_ocorrencia, created_at, status, valor,
      unidades ( blocos (nome_ou_numero), apartamentos(numero) )
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
    valor: h.valor,
    bloco: (h.unidades as any)?.blocos?.nome_ou_numero ?? '',
    apto: (h.unidades as any)?.apartamentos?.numero ?? ''
  }))

  return (
    <div className="p-6 lg:p-8 max-w-5xl mx-auto">
      <div className="mb-6">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">Gestão</p>
        <h1 className="text-2xl font-bold text-gray-900">Notificações e Multas</h1>
        <p className="text-sm text-gray-500 mt-1">
          Registre multas e notificações para as unidades, que serão avisadas via aplicativo
        </p>
      </div>

      <NotificacoesMultasClient 
        condoId={condoId} 
        currentUserId={user.id}
        blocos={blocosDisponiveis}
        units={units}
        historicoData={historico}
      />
    </div>
  )
}
