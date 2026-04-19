import { createClient } from '@supabase/supabase-js'
import * as dotenv from 'dotenv'

dotenv.config({ path: 'web-app/.env.local' })

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

async function check() {
  const { data, error } = await supabase
    .from('perfil')
    .select('id, nome_completo, email, whatsapp, bloco_txt, apto_txt, status_aprovacao, papel_sistema, condominio_id, deleted_at')
    .ilike('email', '%danielebsassis%')
  
  if (error) console.error('Error in perfil:', error)
  else console.log('Perfil data:', data)

  const { data: authData, error: authError } = await supabase.auth.admin.listUsers()
  if (authError) console.error('Error in auth:', authError)
  else {
    const user = authData.users.find(u => u.email?.toLowerCase().includes('danielebsassis'))
    console.log('Auth data:', user)
  }
}
check()
