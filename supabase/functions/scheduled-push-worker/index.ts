import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create } from 'https://deno.land/x/djwt@v2.9.1/mod.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')!

async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)

  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  const pem = serviceAccount.private_key
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

  const jwt = await create(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
    },
    privateKey,
  )

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const tokenData = await tokenResponse.json()
  if (!tokenData.access_token) {
    throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`)
  }
  return tokenData.access_token
}

serve(async (req) => {
  // Security check: require secret token (Service Role)
  const authHeader = req.headers.get('Authorization')
  if (authHeader !== `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // 1. Get current date & time in Brazil Timezone (BRT)
    const now = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Sao_Paulo" }))
    const dias = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sab']
    const diaSemana = dias[now.getDay()]
    const todayStr = now.toISOString().split('T')[0] // 'YYYY-MM-DD'
    
    const hh = String(now.getHours()).padStart(2, '0')
    const mm = String(now.getMinutes()).padStart(2, '0')
    const timeStr = `${hh}:${mm}:00`

    console.log(`[Worker] Running scheduled push check for day: ${diaSemana}, time: ${timeStr}, date: ${todayStr}`)

    // 2. Fetch active scheduled pushes for today that haven't run yet
    const { data: scheduled, error: dbError } = await supabase
      .from('push_agendamentos_recorrentes')
      .select('*')
      .eq('dia_semana', diaSemana)
      .eq('ativo', true)
      .or(`last_sent_at.is.null,last_sent_at.lt.${todayStr}`)

    if (dbError) throw dbError

    if (!scheduled || scheduled.length === 0) {
      return new Response(JSON.stringify({ message: 'Nenhum push agendado pendente para hoje' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Filter items whose scheduled time is <= current time
    const toSend = scheduled.filter(item => item.horario <= timeStr)

    if (toSend.length === 0) {
      return new Response(JSON.stringify({ message: 'Nenhum push agendado chegou ao horário de envio ainda' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // 3. Initialize Firebase Messaging OAuth2 token
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON)
    const accessToken = await getAccessToken(serviceAccount)
    const projectId = serviceAccount.project_id
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    let totalSent = 0
    const processedIds: string[] = []

    for (const item of toSend) {
      console.log(`[Worker] Sending scheduled push "${item.assunto}" (ID: ${item.id})`)

      // Fetch active device tokens
      let query = supabase
        .from('perfil')
        .select('fcm_token')
        .not('fcm_token', 'is', null)

      if (item.condominio_id) {
        query = query.eq('condominio_id', item.condominio_id)
      }

      const { data: perfis, error: tokenError } = await query
      if (tokenError) {
        console.error(`Error loading tokens for scheduled push ${item.id}:`, tokenError)
        continue
      }

      const tokens: string[] = (perfis ?? [])
        .map((r: any) => r.fcm_token)
        .filter((t: any): t is string => typeof t === 'string' && t.length > 0 && !t.startsWith('dummy_'))

      if (tokens.length === 0) {
        console.log(`[Worker] No active tokens found for scheduled push ${item.id}`)
        // Update last_sent_at anyway to avoid checking this again today
        await supabase
          .from('push_agendamentos_recorrentes')
          .update({ last_sent_at: todayStr })
          .eq('id', item.id)
        processedIds.push(item.id)
        continue
      }

      let sentCount = 0

      // Send to each token
      const promises = tokens.map(async (token) => {
        const message = {
          message: {
            token,
            notification: { title: item.assunto, body: item.mensagem },
            data: { type: 'universal', route: '/avisos' },
            android: {
              priority: 'high',
              notification: { channel_id: 'avisos_v2', sound: 'condomeet' },
            },
            apns: {
              payload: { aps: { sound: 'condomeet.aiff', badge: 1 } },
            },
          },
        }

        try {
          const res = await fetch(fcmUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(message),
          })

          if (res.ok) {
            sentCount++
          } else {
            console.error(`FCM error for token:`, await res.text())
          }
        } catch (fetchErr) {
          console.error(`FCM fetch error:`, fetchErr)
        }
      })

      await Promise.all(promises)

      // 4. Mark as sent today
      await supabase
        .from('push_agendamentos_recorrentes')
        .update({ last_sent_at: todayStr })
        .eq('id', item.id)

      processedIds.push(item.id)
      totalSent += sentCount
      console.log(`[Worker] Scheduled push "${item.assunto}" sent to ${sentCount} devices.`)
    }

    return new Response(JSON.stringify({ success: true, processed_schedules: processedIds.length, total_notifications_sent: totalSent }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (err) {
    console.error('Scheduled push worker execution error:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
