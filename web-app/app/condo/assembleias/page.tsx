import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export const metadata = { title: 'Assembleias — Condomeet' }

export default async function CondoAssembleiasPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  if (!profile?.condominio_id) redirect('/condo')

  const { data: assembleias } = await supabase
    .from('assembleias')
    .select('id, nome, tipo, modalidade, status, dt_1a_convocacao, dt_fim_votacao')
    .eq('condominio_id', profile.condominio_id)
    .in('status', ['agendada', 'em_andamento', 'votacao_aberta', 'finalizada', 'ata_publicada'])
    .order('dt_1a_convocacao', { ascending: false })
    .limit(20)

  function formatDate(d: string | null) {
    if (!d) return '—'
    return new Date(d).toLocaleDateString('pt-BR', {
      day: '2-digit', month: '2-digit', year: 'numeric',
      hour: '2-digit', minute: '2-digit',
    })
  }

  const STATUS_LABELS: Record<string, { label: string; color: string }> = {
    agendada:       { label: 'Agendada',       color: 'bg-blue-100 text-blue-700' },
    em_andamento:   { label: 'Em Andamento',   color: 'bg-green-100 text-green-700' },
    votacao_aberta: { label: 'Votação Aberta', color: 'bg-orange-100 text-orange-700' },
    finalizada:     { label: 'Finalizada',     color: 'bg-purple-100 text-purple-700' },
    ata_publicada:  { label: 'Ata Publicada',  color: 'bg-emerald-100 text-emerald-700' },
  }

  return (
    <div className="p-6 lg:p-8 max-w-4xl">
      <div className="mb-6">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">
          Condomínio
        </p>
        <h1 className="text-2xl font-bold text-gray-900">
          Assembleias
        </h1>
      </div>

      {assembleias && assembleias.length > 0 ? (
        <div className="space-y-3">
          {assembleias.map(a => {
            const statusCfg = STATUS_LABELS[a.status] ?? { label: a.status, color: 'bg-gray-100 text-gray-600' }
            return (
              <div key={a.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
                <div className="flex items-center justify-between flex-wrap gap-2">
                  <div>
                    <h3 className="font-semibold text-gray-800">{a.nome}</h3>
                    <p className="text-xs text-gray-400 mt-0.5">
                      {a.tipo} · {a.modalidade} · 1ª Conv: {formatDate(a.dt_1a_convocacao)}
                    </p>
                  </div>
                  <span className={`px-3 py-1 rounded-full text-xs font-bold ${statusCfg.color}`}>
                    {statusCfg.label}
                  </span>
                </div>
              </div>
            )
          })}
        </div>
      ) : (
        <div className="text-center py-16 bg-white rounded-2xl border border-gray-100">
          <p className="text-gray-400">Nenhuma assembleia publicada ainda.</p>
        </div>
      )}
    </div>
  )
}
