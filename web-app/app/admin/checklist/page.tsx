import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ChecklistAdminClient from './checklist-client'

export const dynamic = 'force-dynamic'

export default async function ChecklistAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const SUPER_ADMIN_EMAILS = ['ccarlos1981+60@gmail.com', 'cristiano.santos@gmx.com']
  const isSuperAdmin = SUPER_ADMIN_EMAILS.includes(user.email ?? '')

  if (!isSuperAdmin) {
    redirect('/admin')
  }

  // 1. Fetch all Vistorias globally (with condo names)
  const { data: vistoriasData } = await supabase
    .from('vistorias')
    .select(`
      id,
      condominio_id,
      plano,
      tipo_bem,
      created_at,
      status,
      condominios ( nome )
    `)

  const vistorias = vistoriasData || []

  // Calculate Metrics
  const totalChecklists = vistorias.length
  
  // Group by condo
  const condosMap = new Map<string, { nome: string; count: number; plano: string; last_used: string }>()
  let countPlus = 0
  let countFree = 0
  const tipoBemCounts: Record<string, number> = {}

  vistorias.forEach(v => {
    // Plans
    if (v.plano === 'plus') countPlus++
    else countFree++

    // Tipos de Bem
    if (!tipoBemCounts[v.tipo_bem]) tipoBemCounts[v.tipo_bem] = 0
    tipoBemCounts[v.tipo_bem]++

    // By Condo
    if (!condosMap.has(v.condominio_id)) {
      // @ts-ignore
      const condoName = v.condominios?.nome || 'Condomínio Desconhecido'
      condosMap.set(v.condominio_id, {
        nome: condoName,
        count: 0,
        plano: v.plano, // Will track the latest or any plan
        last_used: v.created_at
      })
    }

    const condoNode = condosMap.get(v.condominio_id)!
    condoNode.count++
    if (new Date(v.created_at) > new Date(condoNode.last_used)) {
      condoNode.last_used = v.created_at
      if (v.plano === 'plus') condoNode.plano = 'plus' // upgrade if any is plus
    }
  })

  const condosAtivos = Array.from(condosMap.values()).sort((a, b) => b.count - a.count)

  // 2. Fetch Global Templates
  const { data: templatesData } = await supabase
    .from('vistoria_templates')
    .select('*')
    .eq('is_public', true)
    .order('created_at', { ascending: false })

  const templatesGlobais = templatesData || []

  return (
    <ChecklistAdminClient
      metrics={{
        totalChecklists,
        totalCondos: condosMap.size,
        countPlus,
        countFree,
        tipoBemCounts
      }}
      condosUsage={condosAtivos}
      templates={templatesGlobais}
    />
  )
}
