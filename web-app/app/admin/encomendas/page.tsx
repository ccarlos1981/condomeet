import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ParcelList from '@/app/condo/encomendas/parcel-list'

export const metadata = { title: 'Encomendas do Condomínio — Painel Admin' }

export default async function AdminEncomendasPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema')
    .eq('id', user.id)
    .single()

  const role = (profile?.papel_sistema ?? '').toLowerCase()
  const isAdmin = role.includes('síndico') || role.includes('sindico') || role === 'admin'
  if (!isAdmin) redirect('/condo')

  const condoId = profile?.condominio_id ?? ''

  // Fetch tipo_estrutura
  const { data: condo } = await supabase
    .from('condominios')
    .select('tipo_estrutura')
    .eq('id', condoId)
    .single()
  const tipoEstrutura = condo?.tipo_estrutura ?? 'predio'

  // Fetch ALL blocos and aptos from structural tables for filter dropdowns
  const { data: blocosData } = await supabase
    .from('blocos')
    .select('nome_ou_numero')
    .eq('condominio_id', condoId)
    .gt('nome_ou_numero', '0')

  const { data: aptosData } = await supabase
    .from('apartamentos')
    .select('numero')
    .eq('condominio_id', condoId)
    .gt('numero', '0')

  const numSort = (a: string, b: string) => a.localeCompare(b, 'pt', { numeric: true })
  const allBlocos = [...new Set((blocosData ?? []).map(b => b.nome_ou_numero).filter(Boolean) as string[])].sort(numSort)
  const allAptosArr = [...new Set((aptosData ?? []).map(a => a.numero).filter(Boolean) as string[])].sort(numSort)
  const allAptosMap: Record<string, string[]> = {}
  for (const bloco of allBlocos) {
    allAptosMap[bloco] = allAptosArr
  }

  // NOTE: parcels are now fetched client-side by ParcelList

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
        <a
          href="/condo/registrar-encomenda"
          className="flex items-center gap-2 bg-[#FC5931] text-white text-sm font-semibold px-5 py-2.5 rounded-xl hover:bg-[#D42F1D] transition-colors shadow-sm"
        >
          + Nova Encomenda
        </a>
      </div>

      <ParcelList
        initialParcels={[]}
        isPorter={true}
        userId={user.id}
        condoId={condoId}
        tipoEstrutura={tipoEstrutura}
        allBlocos={allBlocos}
        allAptosMap={allAptosMap}
      />
    </div>
  )
}
