import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'
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
  return tokenData.access_token
}

serve(async (req) => {
  // Can be called manually or via pg_net (Supabase cron)
  try {
    // Only accept POST
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }

    // Basic security check: require a secret token for CRON invocation
    const authHeader = req.headers.get('Authorization')
    if (authHeader !== `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`) {
      return new Response('Unauthorized', { status: 401 })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // 1. Fetch pending faturamentos with fcm_token
    const { data: pendentes, error } = await supabase
      .from('faturamentos')
      .select(`
        id, 
        valor_total, 
        data_vencimento,
        unidades (
          perfil (
            id, nome_completo, fcm_token
          )
        )
      `)
      .eq('status_pagamento', 'pendente')

    if (error) throw error
    if (!pendentes || pendentes.length === 0) {
      return new Response(JSON.stringify({ message: 'Nenhum boleto pendente' }), { status: 200 })
    }

    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON)
    const accessToken = await getAccessToken(serviceAccount)
    const projectId = serviceAccount.project_id
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    let sent = 0
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    for (const fat of pendentes) {
      // Find valid tokens from any perfil tied to the unidade
      const tokens: string[] = [];
      if (fat.unidades && fat.unidades.perfil) {
         // handle array of perfis attached to an unidade
         const perfis = Array.isArray(fat.unidades.perfil) ? fat.unidades.perfil : [fat.unidades.perfil];
         perfis.forEach((p: any) => {
            if (p.fcm_token && !p.fcm_token.startsWith('dummy_')) {
               tokens.push(p.fcm_token);
            }
         });
      }

      if (tokens.length === 0) continue

      const vencimento = new Date(fat.data_vencimento)
      vencimento.setHours(0, 0, 0, 0)

      const diffTime = vencimento.getTime() - today.getTime()
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

      let titulo = ''
      let corpo = ''

      if (diffDays === 5) {
        titulo = 'Seu Boleto Condomeet'
        corpo = `Lembrete: O boleto do seu condomínio vence em 5 dias (R$ ${Number(fat.valor_total).toFixed(2)}).`
      } else if (diffDays === 0) {
        titulo = 'Vence Hoje! 🚨'
        corpo = `Atenção: Seu boleto do condomínio vence hoje. Evite multas!`
      } else if (diffDays === -1) {
        titulo = 'Boleto Vencido ⚠️'
        corpo = `Seu boleto venceu ontem. Acesse o app para atualizar e realizar o pagamento.`
      }

      if (titulo && corpo) {
        for (const token of tokens) {
          const message = {
            message: {
              token,
              notification: { title: titulo, body: corpo },
              data: { type: 'financeiro', route: '/boletos' },
              android: {
                priority: 'high',
                notification: { channel_id: 'avisos_v2', sound: 'condomeet' },
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
            console.error(`FCM error for ${fat.id}:`, await res.text())
          }
        }
      }
    }

    return new Response(JSON.stringify({ sent, total_processed: pendentes.length }), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (err) {
    console.error('Push worker error:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
