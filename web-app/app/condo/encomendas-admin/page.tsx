import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ParcelList from '../encomendas/parcel-list'
import { filterResidentialBlocos, filterResidentialAptos } from '@/lib/labels'
import { isAdminRole, isPorterRole, isFeatureVisible } from '@/lib/roles'

export const metadata = { title: 'Encomendas do Condomínio — Condomeet' }

export default async function EncomendasAdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const rawRole = profile?.papel_sistema
  const isSysAdmin = isAdminRole(rawRole)
  const isPorter = isPorterRole(rawRole)
  const roleLower = (rawRole ?? '').toLowerCase()
  const isStaffLegacy = roleLower.includes('zelador') || roleLower.includes('funcionario')

  if (!isSysAdmin && !isPorter && !isStaffLegacy) {
    redirect('/condo')
  }

  const condoId = profile?.condominio_id ?? ''

  // Fetch tipo_estrutura, features_config, blocos and apartamentos in parallel
  const [condoResult, blocosData, aptosData] = await Promise.all([
    supabase
      .from('condominios')
      .select('tipo_estrutura, features_config')
      .eq('id', condoId)
      .single(),
    supabase
      .from('blocos')
      .select('nome_ou_numero')
      .eq('condominio_id', condoId)
      .gt('nome_ou_numero', '0'),
    supabase
      .from('apartamentos')
      .select('numero')
      .eq('condominio_id', condoId)
      .gt('numero', '0'),
  ])
  const tipoEstrutura = condoResult.data?.tipo_estrutura ?? 'predio'

  // Se for Portaria (sem privilégio de admin), só acessa se o módulo estiver liberado no features_config
  if (isPorter && !isSysAdmin) {
    const featuresConfig = condoResult.data?.features_config
    const canAccessParcels =
      isFeatureVisible('pending_del', rawRole, featuresConfig) ||
      isFeatureVisible('parcels', rawRole, featuresConfig)

    if (!canAccessParcels) {
      redirect('/condo')
    }
  }

  const allBlocos = filterResidentialBlocos((blocosData.data ?? []).map(b => b.nome_ou_numero))
  const allAptosArr = filterResidentialAptos((aptosData.data ?? []).map(a => a.numero))
  // Map: every bloco gets the same set of aptos (standard structure)
  const allAptosMap: Record<string, string[]> = {}
  for (const bloco of allBlocos) {
    allAptosMap[bloco] = allAptosArr
  }


  // NOTE: parcels are now fetched client-side by ParcelList with server-side
  // filtering + pagination (10/page). No need to preload here.

  const canRegister = isSysAdmin || isPorter

  return (
    <div className="p-6 lg:p-8 max-w-5xl">
      <div className="mb-6 flex items-center justify-between flex-wrap gap-3">
        <div>
          <p className="text-sm text-gray-500 font-medium uppercase tracking-wider mb-1">
            Gestão
          </p>
          <h1 className="text-2xl font-bold text-gray-900">
            Encomendas do Condomínio
          </h1>
        </div>
        {canRegister && (
          <a
            href="/condo/registrar-encomenda"
            className="flex items-center gap-2 bg-[#FC5931] text-white text-sm font-semibold px-5 py-2.5 rounded-xl hover:bg-[#D42F1D] transition-colors shadow-sm"
          >
            + Nova Encomenda
          </a>
        )}
      </div>

      <ParcelList
        initialParcels={[]}
        isPorter={isSysAdmin || isPorter}
        userId={user.id}
        condoId={condoId}
        tipoEstrutura={tipoEstrutura}
        allBlocos={allBlocos}
        allAptosMap={allAptosMap}
      />
    </div>
  )
}
