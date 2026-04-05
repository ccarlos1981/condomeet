import { createServerClient, type CookieOptions } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import AtaClient from './ata-client'

export const dynamic = 'force-dynamic'

export default async function AssembleiaAtaPage(props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const cookieStore = await cookies();
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value
        },
      },
    }
  )

  const { data: { session } } = await supabase.auth.getSession()

  if (!session) {
    redirect('/auth-sindico')
  }

  // Fetch assembleia
  const { data: assembleia, error: assembleiaError } = await supabase
    .from('assembleias')
    .select('*')
    .eq('id', params.id)
    .single()

  if (assembleiaError || !assembleia) {
    console.error('Error fetching assembleia', assembleiaError)
    redirect('/admin/assembleias')
  }
  
  // Condominio is the relation loaded
  const { data: condominioData } = await supabase
    .from('condominios')
    .select('id, nome, cidade, estado, cnpj, logradouro, numero, complemento, bairro, cep')
    .eq('id', assembleia.condominio_id)
    .single()

  const condominio = condominioData || {}

  return (
    <AtaClient 
      assembleia={assembleia} 
      condominio={condominio} 
    />
  )
}
