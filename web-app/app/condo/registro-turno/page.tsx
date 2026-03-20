import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import RegistroTurnoPorteiroClient from './registro-turno-porteiro-client'

export const metadata = { title: 'Registro de Turno — Condomeet' }

export default async function RegistroTurnoPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, nome_completo, papel_sistema')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  // Load inventory items
  const { data: inventario } = await supabase
    .from('turno_inventario')
    .select('*, turno_assuntos!inner(titulo)')
    .eq('condominio_id', condoId)
    .order('nome')

  // Load recent shift records
  const { data: registros } = await supabase
    .from('turno_registros')
    .select('*')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })
    .limit(50)

  // Load porters for dropdown (profiles + historical names)
  const { data: porteiros } = await supabase
    .from('perfil')
    .select('id, nome_completo')
    .eq('condominio_id', condoId)
    .in('papel_sistema', ['Portaria', 'Porteiro', 'portaria', 'porteiro'])

  // Load distinct historical porter names
  const { data: historicoNomes } = await supabase
    .from('turno_registros')
    .select('porteiro_nome')
    .eq('condominio_id', condoId)

  const nomesHistoricos = [...new Set((historicoNomes ?? []).map(h => h.porteiro_nome))].filter(Boolean)

  // Load registro IDs that have discrepancies
  const { data: divergencias } = await supabase
    .from('turno_registro_itens')
    .select('registro_id')
    .eq('confere', false)

  const registrosComDivergencia = [...new Set((divergencias ?? []).map(d => d.registro_id))]

  return (
    <div className="p-6">
      <RegistroTurnoPorteiroClient
        inventario={inventario ?? []}
        registros={registros ?? []}
        porteiros={porteiros ?? []}
        nomesHistoricos={nomesHistoricos}
        condoId={condoId}
        registrosComDivergencia={registrosComDivergencia}
      />
    </div>
  )
}
