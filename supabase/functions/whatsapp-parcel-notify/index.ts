import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  try {
    const { parcel_id, resident_name, unit, block, photo_url, resident_id, unit_id } = await req.json()

    // 1. Inicializar Supabase Admin
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const BOTCONVERSA_API_KEY = Deno.env.get('BOTCONVERSA_API_KEY')
    const BOTCONVERSA_FLOW_ID = Deno.env.get('BOTCONVERSA_FLOW_ID')

    if (!BOTCONVERSA_API_KEY) {
      return new Response(JSON.stringify({ error: "BOTCONVERSA_API_KEY não configurada" }), { status: 400 })
    }

    let profilesToNotify = [];

    if (unit_id) {
      // 2. Buscar todos os moradores da unidade
      const { data: profiles, error } = await supabaseAdmin
        .from('profiles')
        .select('id, full_name, phone, botconversa_id')
        .eq('unit_id', unit_id)
        .not('phone', 'is', null)

      if (!error && profiles) {
        profilesToNotify = profiles;
      }
    } else {
      // Fallback para morador único caso unidade não exista no payload
      const { data: singleProfile } = await supabaseAdmin
        .from('profiles')
        .select('id, full_name, phone, botconversa_id')
        .eq('id', resident_id)
        .single()

      if (singleProfile && singleProfile.phone) {
        profilesToNotify = [singleProfile];
      }
    }

    if (profilesToNotify.length === 0) {
      return new Response(JSON.stringify({ error: "Nenhum contato encontrado para notificação" }), { status: 400 })
    }

    console.log(`Sending parcel notification to ${profilesToNotify.length} resident(s) of unit ${unit_id || 'unknown'}`)

    const sendPromises = profilesToNotify.map(async (profile: any) => {
      // 1. Limpar e Garantir 55 (Brasil)
      let cleanPhone = profile.phone?.replace(/\D/g, '') || ''
      if (cleanPhone.length > 0 && !cleanPhone.startsWith('55')) {
        cleanPhone = '55' + cleanPhone
      }

      const body: any = {
        phone: cleanPhone,
        first_name: profile.full_name?.split(' ')[0] || resident_name,
        last_name: `(Apto ${unit})`,
        variables: [
          { key: "encomenda_id", value: parcel_id },
          { key: "unidade", value: unit },
          { key: "bloco", value: block },
          { key: "foto_url", value: photo_url || "" }
        ],
        flow_id: BOTCONVERSA_FLOW_ID ? parseInt(BOTCONVERSA_FLOW_ID) : null
      };

      console.log(`Payload para ${cleanPhone}:`, JSON.stringify(body));

      try {
        const response = await fetch(`https://backend.botconversa.com.br/api/v1/webhook/subscriber/`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'API-KEY': BOTCONVERSA_API_KEY as string
          },
          body: JSON.stringify(body)
        });

        const resultText = await response.text();
        console.log(`Resposta BotConversa (${cleanPhone}):`, resultText);
        return { success: response.ok, status: response.status, result: resultText, phone: cleanPhone };
      } catch (err: any) {
        console.error(`Erro ao enviar para ${cleanPhone}:`, err.message);
        return { success: false, error: err.message, phone: cleanPhone };
      }
    });

    const results = await Promise.all(sendPromises);
    const hasSuccess = results.some((r: any) => r.success);

    return new Response(JSON.stringify({
      messages_sent: results.length,
      success: hasSuccess,
      results
    }), {
      status: hasSuccess ? 200 : 500,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
