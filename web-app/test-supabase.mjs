import { createClient } from '@supabase/supabase-js'

async function check() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  const supabase = createClient(supabaseUrl, supabaseKey)

  const { data, error } = await supabase.from('unidades').select('id').eq('condominio_id', 'b699e35f-c2f9-461f-93c3-de8a80e73744').limit(10000)
  console.log("Returned rows:", data ? data.length : 0)
  if (error) console.error(error)
}

check()
