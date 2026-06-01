const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env.local' });

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);

async function test() {
  const { data: condo } = await supabase.from('condominios').select('id').limit(1).single();
  const condoId = condo.id;
  
  const url = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/finance-simulate-billing`;
  console.log("Calling", url, "with condo_id", condoId);
  try {
      const res = await fetch(url, {
          method: 'POST',
          headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY}`
          },
          body: JSON.stringify({
              condominio_id: condoId,
              mes_referencia: '2026-05',
              modelo: 'fixo',
              valor_base: 400,
              taxas_extras: []
          })
      });
      const data = await res.json();
      console.log("Response:", data);
  } catch (e) {
      console.error(e);
  }
}

test();
