import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ParcelRegisterForm from './parcel-register-form'
import { fetchAll } from '@/lib/supabase/utils'
import { isAdminRole, isFeatureVisible } from '@/lib/roles'
import { filterResidentialBlocos, filterResidentialAptos, isTechnicalAdminUnit } from '@/lib/labels'

export const metadata = { title: 'Registrar Encomenda — Condomeet' }

export interface UnitOption {
  blocoNome: string
  aptoNumero: string
  residentId: string | null
  residentName: string | null
}

interface BlocoRow {
  id: string
  nome_ou_numero: string
}

interface AptoRow {
  id: string
  numero: string
}

interface UnidadeRow {
  id: string
  bloco_id: string
  apartamento_id: string
}

interface PerfilRow {
  id: string
  nome_completo: string
  bloco_txt: string | null
  apto_txt: string | null
  papel_sistema?: string | null
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

  const role = profile?.papel_sistema
  const isAdmin = isAdminRole(role)
  const condoId = profile?.condominio_id ?? ''

  // Fetch tipo_estrutura, features_config, blocos and apartamentos in parallel
  const [condoResult, blocos, rawAptos] = await Promise.all([
    supabase
      .from('condominios')
      .select('tipo_estrutura, features_config')
      .eq('id', condoId)
      .single(),
    fetchAll(
      supabase
        .from('blocos')
        .select('id, nome_ou_numero')
        .eq('condominio_id', condoId)
        .order('nome_ou_numero')
    ),
    fetchAll(
      supabase
        .from('apartamentos')
        .select('id, numero')
        .eq('condominio_id', condoId)
        .order('numero')
    ),
  ])

  const featuresConfig = condoResult.data?.features_config
  // O síndico define no features_config quem pode registrar encomendas (pending_del)
  // Admin e Síndico possuem acesso nativo; demais perfis dependem da autorização dinâmica do síndico
  const canAccessParcels =
    isAdmin ||
    isFeatureVisible('pending_del', role, featuresConfig)

  if (!canAccessParcels) {
    redirect('/condo')
  }

  const tipoEstrutura = condoResult.data?.tipo_estrutura ?? 'predio'

  const rawBlocos = (blocos as unknown as BlocoRow[]) ?? []
  const rawApartamentos = (rawAptos as unknown as AptoRow[]) ?? []

  const allBlocosDesc = filterResidentialBlocos(rawBlocos.map(b => b.nome_ou_numero))
  const allAptosDesc = filterResidentialAptos(rawApartamentos.map(a => a.numero))

  let units: UnitOption[] = []

  if (rawBlocos.length > 0) {
    const blocoMap: Record<string, string> = {}
    rawBlocos.forEach(b => { blocoMap[b.id] = b.nome_ou_numero })

    const unidades = await fetchAll(
      supabase
        .from('unidades')
        .select('id, bloco_id, apartamento_id')
        .eq('condominio_id', condoId)
    )
    const rawUnidades = (unidades as unknown as UnidadeRow[]) ?? []

    if (rawUnidades.length > 0) {
      // Reuse rawApartamentos instead of fetching apartamentos again (eliminates duplicate query)
      const aptoMap: Record<string, string> = {}
      rawApartamentos.forEach(a => { aptoMap[a.id] = a.numero })

      // Fetch residents to map bloco_txt+apto_txt → profile (excluding technical Admin)
      const perfis = await fetchAll(
        supabase
          .from('perfil')
          .select('id, nome_completo, bloco_txt, apto_txt, papel_sistema')
          .eq('condominio_id', condoId)
          .neq('papel_sistema', 'Admin')
          .neq('bloco_txt', 'Admin')
          .not('apto_txt', 'is', null)
      )
      const rawPerfis = (perfis as unknown as PerfilRow[]) ?? []

      const residentMap: Record<string, { id: string; nome: string }> = {}
      rawPerfis.forEach(p => {
        const key = `${p.bloco_txt}|${p.apto_txt}`
        residentMap[key] = { id: p.id, nome: p.nome_completo }
      })

      units = rawUnidades
        .map(u => {
          const blocoNome = blocoMap[u.bloco_id] ?? '?'
          const aptoNumero = aptoMap[u.apartamento_id] ?? '?'
          const resident = residentMap[`${blocoNome}|${aptoNumero}`]
          return {
            blocoNome,
            aptoNumero,
            residentId: resident?.id ?? null,
            residentName: resident?.nome ?? null,
          }
        })
        .filter(u => !isTechnicalAdminUnit(u.blocoNome, u.aptoNumero))
        .sort((a, b) =>
          a.blocoNome.localeCompare(b.blocoNome, 'pt', { numeric: true }) || a.aptoNumero.localeCompare(b.aptoNumero, 'pt', { numeric: true })
        )
    }
  }

  // Strategy 2 fallback: use denormalized bloco_txt/apto_txt from perfil
  if (units.length === 0) {
    const perfis = await fetchAll(
      supabase
        .from('perfil')
        .select('id, nome_completo, bloco_txt, apto_txt, papel_sistema')
        .eq('condominio_id', condoId)
        .neq('papel_sistema', 'Admin')
        .neq('bloco_txt', 'Admin')
        .not('apto_txt', 'is', null)
        .order('bloco_txt')
        .order('apto_txt')
    )
    const rawPerfisFallback = (perfis as unknown as PerfilRow[]) ?? []

    units = rawPerfisFallback
      .filter(p => !isTechnicalAdminUnit(p.bloco_txt, p.apto_txt))
      .map(p => ({
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
        tipoEstrutura={tipoEstrutura}
        allBlocos={allBlocosDesc}
        allAptos={allAptosDesc}
      />
    </div>
  )
}
