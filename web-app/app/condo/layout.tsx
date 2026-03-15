import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import Sidebar from '@/components/sidebar'

export default async function CondoLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('nome_completo, papel_sistema, bloco_txt, apto_txt, condominio_id')
    .eq('id', user.id)
    .single()

  const { data: condo } = await supabase
    .from('condominios')
    .select('nome, features_config')
    .eq('id', profile?.condominio_id ?? '')
    .single()

  const unidade = [profile?.bloco_txt, profile?.apto_txt].filter(Boolean).join(' / ') || '—'

  return (
    <div className="flex min-h-screen bg-[#f3f4f8]">
      <Sidebar
        role={profile?.papel_sistema ?? 'Morador'}
        userName={profile?.nome_completo?.split(' ')[0] ?? 'Usuário'}
        condoName={condo?.nome ?? 'Condomínio'}
        unidade={unidade}
        featuresConfig={condo?.features_config ?? null}
      />
      <main className="flex-1 overflow-auto">
        {children}
      </main>
    </div>
  )
}
