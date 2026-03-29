import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { lat, lng, radius = 5000 } = await req.json()

    if (!lat || !lng) {
      throw new Error('Latitude e Longitude são obrigatórios')
    }

    const googleApiKey = Deno.env.get('GOOGLE_MAPS_API_KEY')
    if (!googleApiKey) {
      throw new Error('Chave da Google Maps API não configurada no servidor.')
    }

    // 1. Fetch Google Places
    const type = 'supermarket'
    const language = 'pt-BR'
    const url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${lat},${lng}&radius=${radius}&type=${type}&language=${language}&key=${googleApiKey}`

    const response = await fetch(url)
    const json = await response.json()

    if (json.status !== 'OK' && json.status !== 'ZERO_RESULTS') {
      throw new Error(`Google Places Error: ${json.status} - ${json.error_message}`)
    }

    const places = json.results

    if (!places || places.length === 0) {
      return new Response(JSON.stringify([]), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Initialize Supabase Admin
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    const upsertData = places.map((place: Record<string, any>) => ({
      name: place.name,
      address: place.vicinity || '',
      latitude: place.geometry?.location?.lat,
      longitude: place.geometry?.location?.lng,
      google_place_id: place.place_id,
      is_chain: false,
      is_sponsored: false,
      logo_url: place.icon
    }))

    // 4. Batch Upsert to Supabase
    // Using `onConflict: 'google_place_id'` to update existing or insert new.
    // .select() returns the final rows with their UUIDs
    const { data: dbSupermarkets, error } = await supabaseClient
      .from('lista_supermarkets')
      .upsert(upsertData, { onConflict: 'google_place_id' })
      .select()

    if (error) {
      console.error('Upsert error:', error)
      throw new Error('Erro ao salvar supermercados no banco: ' + error.message)
    }

    return new Response(JSON.stringify(dbSupermarkets), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error: unknown) {
    console.error('Function error:', error)
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
