// enquete-push-notify — Supabase Edge Function
// Sends push notification to all approved residents when a poll is activated
// Based on avisos-push-notify pattern

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create } from 'https://deno.land/x/djwt@v2.9.1/mod.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }

  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  const pem = serviceAccount.private_key.replace(/\\n/g, '\n')
  const pemContents = pem.substring(
    pem.indexOf(pemHeader) + pemHeader.length,
    pem.indexOf(pemFooter),
  ).replace(/\s/g, '')
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const jwt = await create({ alg: 'RS256', typ: 'JWT' }, payload, privateKey)

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { condominio_id, enquete_id, pergunta } = await req.json()

    if (!condominio_id) {
      return new Response(JSON.stringify({ error: 'condominio_id é obrigatório' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Fetch FCM tokens of all approved residents in this condo
    const { data: residents, error } = await supabase
      .from('perfil')
      .select('fcm_token')
      .eq('condominio_id', condominio_id)
      .eq('status_aprovacao', 'aprovado')
      .eq('bloqueado', false)
      .not('fcm_token', 'is', null)

    if (error) throw error

    const tokens: string[] = (residents ?? [])
      .map((r: any) => r.fcm_token)
      .filter((t: any): t is string => typeof t === 'string' && t.length > 0 && !t.startsWith('dummy_fcm_token'))

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, total: 0, message: 'Nenhum FCM token encontrado' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Get Firebase access token
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON)
    const accessToken = await getAccessToken(serviceAccount)
    const projectId = serviceAccount.project_id
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    // Send notifications
    let sent = 0
    const errors: string[] = []
    for (const token of tokens) {
      const message = {
        message: {
          token,
          notification: {
            title: '📊 Nova Enquete disponível',
            body: pergunta ?? 'Uma nova enquete foi aberta. Participe!',
          },
          data: {
            type: 'enquete',
            enquete_id: enquete_id ?? '',
          },
          android: {
            priority: 'high' as const,
            notification: { channel_id: 'avisos' },
          },
          apns: {
            payload: { aps: { sound: 'condomeet.aiff', badge: 1 } },
          },
        },
      }

      const res = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(message),
      })

      if (res.ok) {
        sent++
      } else {
        const errBody = await res.text()
        errors.push(`[${res.status}] ${token.substring(0, 20)}... → ${errBody}`)
        console.error(`FCM error for token ${token.substring(0, 20)}: ${res.status} ${errBody}`)
      }
    }

    console.log(`enquete-push-notify: sent ${sent}/${tokens.length} for condo ${condominio_id}`)

    return new Response(JSON.stringify({ sent, total: tokens.length, errors }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('enquete-push-notify error:', String(err))
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
