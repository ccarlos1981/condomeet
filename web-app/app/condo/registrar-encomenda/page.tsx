import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ParcelRegisterForm from './parcel-register-form'
import { fetchAll } from '@/lib/supabase/utils'

export const metadata = { title: 'Registrar Encomenda — Condomeet' }

export interface UnitOption {
  blocoNome: string
  aptoNumero: string
  residentId: string | null
  residentName: string | null
}

export default async function RegistrarEncomendaPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, nome_completo')
    .eq('id', user.id)
    .single()

  const role = profile?.papel_sistema ?? ''
  const isPorter =
    role.toLowerCase().includes('portaria') ||
    role.toLowerCase().includes('porteiro') ||
    role.toLowerCase().includes('síndico') ||
    role.toLowerCase().includes('sindico') ||
    role === 'admin'

  if (!isPorter) redirect('/condo')

  const condoId = profile?.condominio_id ?? ''

  // Strategy 1: fetch from structural tables (blocos + unidades + apartamentos)
  let units: UnitOption[] = []

  const blocos = await fetchAll(
    supabase
      .from('blocos')
      .select('id, nome_ou_numero')
      .eq('condominio_id', condoId)
      .order('nome_ou_numero')
  )

  const rawAptos = await fetchAll(
    supabase
      .from('apartamentos')
      .select('id, numero')
      .eq('condominio_id', condoId)
      .order('numero')
  )

  const allBlocosDesc = blocos ? blocos.map(b => b.nome_ou_numero) : []
  const allAptosDesc = rawAptos ? rawAptos.map(a => a.numero) : []

  if (blocos && blocos.length > 0) {
    const blocoMap: Record<string, string> = {}
    blocos.forEach(b => { blocoMap[b.id] = b.nome_ou_numero })

    const unidades = await fetchAll(
      supabase
        .from('unidades')
        .select('id, bloco_id, apartamento_id')
        .eq('condominio_id', condoId)
    )

    if (unidades && unidades.length > 0) {
      const aptos = await fetchAll(
        supabase
          .from('apartamentos')
          .select('id, numero')
          .eq('condominio_id', condoId)
      )
      const aptoMap: Record<string, string> = {}
      ;(aptos ?? []).forEach((a: any) => { aptoMap[a.id] = a.numero })

      // Fetch residents to map bloco_txt+apto_txt → profile
      const perfis = await fetchAll(
        supabase
          .from('perfil')
          .select('id, nome_completo, bloco_txt, apto_txt')
          .eq('condominio_id', condoId)
          .not('apto_txt', 'is', null)
      )

      const residentMap: Record<string, { id: string; nome: string }> = {}
      ;(perfis ?? []).forEach((p: any) => {
        const key = `${p.bloco_txt}|${p.apto_txt}`
        residentMap[key] = { id: p.id, nome: p.nome_completo }
      })

      units = unidades.map((u: any) => {
        const blocoNome = blocoMap[u.bloco_id] ?? '?'
        const aptoNumero = aptoMap[u.apartamento_id] ?? '?'
        const resident = residentMap[`${blocoNome}|${aptoNumero}`]
        return {
          blocoNome,
          aptoNumero,
          residentId: resident?.id ?? null,
          residentName: resident?.nome ?? null,
        }
      }).sort((a, b) =>
        a.blocoNome.localeCompare(b.blocoNome) || a.aptoNumero.localeCompare(b.aptoNumero)
      )
    }
  }

  // Strategy 2 fallback: use denormalized bloco_txt/apto_txt from perfil
  if (units.length === 0) {
    const perfis = await fetchAll(
      supabase
        .from('perfil')
        .select('id, nome_completo, bloco_txt, apto_txt')
        .eq('condominio_id', condoId)
        .not('apto_txt', 'is', null)
        .order('bloco_txt')
        .order('apto_txt')
    )

    units = (perfis ?? []).map((p: any) => ({
      blocoNome: p.bloco_txt ?? '?',
      aptoNumero: p.apto_txt ?? '?',
      residentId: p.id,
      residentName: p.nome_completo,
    }))
  }

  return (
    <div className="p-6 lg:p-8 max-w-2xl">
      <div className="mb-6">
        <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">Portaria</p>
        <h1 className="text-2xl font-bold text-gray-900">Registrar Encomenda</h1>
        <p className="text-sm text-gray-500 mt-1">
          Preencha os dados da encomenda recebida e tire uma foto.
        </p>
      </div>

      <ParcelRegisterForm
        condoId={condoId}
        registeredById={user.id}
        units={units}
        allBlocos={allBlocosDesc}
        allAptos={allAptosDesc}
      />
    </div>
  )
}
