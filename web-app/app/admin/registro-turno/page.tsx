import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import RegistroTurnoClient from './registro-turno-client'

export const metadata = { title: 'Registro de Turno — Admin Condomeet' }

export default async function RegistroTurnoPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id ?? ''

  const [{ data: assuntos }, { data: inventario }] = await Promise.all([
    supabase.from('turno_assuntos').select('*').eq('condominio_id', condoId).order('created_at'),
    supabase.from('turno_inventario').select('*').eq('condominio_id', condoId).order('nome'),
  ])

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Config Registro de Turno</h1>
        <p className="text-sm text-gray-500 mt-1">Cadastre assuntos e o inventário da portaria</p>
      </div>
      <RegistroTurnoClient
        initialAssuntos={assuntos ?? []}
        initialInventario={inventario ?? []}
        condoId={condoId}
      />
    </div>
  )
}
