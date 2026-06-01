const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env.local' });

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);

async function test() {
  const { data, error } = await supabase.from('unidades').select('*').limit(1);
  console.log("Unidades:", data, error);
}

test();
