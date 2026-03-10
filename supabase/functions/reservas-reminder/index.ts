import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from 'https://deno.land/x/djwt@v2.9.1/mod.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')!
const BOTCONVERSA_API_KEY = Deno.env.get('BOTCONVERSA_API_KEY')
const BOTCONVERSA_FLOW_ID_RESERVA = Deno.env.get('BOTCONVERSA_FLOW_ID_RESERVA')

// ─── FCM helpers ──────────────────────────────────────────────────────────────
async function getFcmAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }
  const pem = serviceAccount.private_key.replace(/\\n/g, '\n')
  const pemContents = pem
    .substring(pem.indexOf('-----BEGIN PRIVATE KEY-----') + 27, pem.indexOf('-----END PRIVATE KEY-----'))
    .replace(/\s/g, '')
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  const privateKey = await crypto.subtle.importKey(
    'pkcs8', binaryDer, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  )
  const jwt = await create({ alg: 'RS256', typ: 'JWT' }, payload, privateKey)
  const tokenResp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
  })
  return (await tokenResp.json()).access_token
}

async function sendFcmPush(fcmToken: string, title: string, body: string, projectId: string, accessToken: string): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data: { type: 'reserva_lembrete' },
          android: { priority: 'high', notification: { channel_id: 'reservas' } },
          apns: { payload: { aps: { sound: 'default', badge: 1 } } },
        },
      }),
    }
  )
  return res.ok
}

// ─── WhatsApp (BotConversa) ───────────────────────────────────────────────────
async function sendWhatsApp(phone: string, nome: string, area: string, data: string): Promise<boolean> {
  if (!BOTCONVERSA_API_KEY) return false
  let cleanPhone = phone.replace(/\D/g, '')
  if (!cleanPhone.startsWith('55')) cleanPhone = '55' + cleanPhone

  const res = await fetch('https://backend.botconversa.com.br/api/v1/webhook/subscriber/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'API-KEY': BOTCONVERSA_API_KEY },
    body: JSON.stringify({
      phone: cleanPhone,
      first_name: nome.split(' ')[0],
      variables: [
        { key: 'nome_area', value: area },
        { key: 'data_evento', value: data },
      ],
      flow_id: BOTCONVERSA_FLOW_ID_RESERVA ? parseInt(BOTCONVERSA_FLOW_ID_RESERVA) : null,
    }),
  })
  return res.ok
}

// ─── Main handler ─────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Datas alvo: hoje+7 e hoje+1
    const today = new Date()
    const addDays = (d: Date, n: number) => {
      const r = new Date(d)
      r.setUTCDate(r.getUTCDate() + n)
      return r.toISOString().split('T')[0]
    }
    const targets = [
      { date: addDays(today, 7), tipo: '7_dias' as const, label: '7 dias' },
      { date: addDays(today, 1), tipo: '1_dia' as const, label: 'amanhã' },
    ]

    // Preparar FCM
    const serviceAccount = FIREBASE_SERVICE_ACCOUNT_JSON ? JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON) : null
    const fcmAccessToken = serviceAccount ? await getFcmAccessToken(serviceAccount) : null
    const projectId = serviceAccount?.project_id

    let totalSent = 0
    const log: unknown[] = []

    for (const { date, tipo, label } of targets) {
      // Busca reservas por_dia para a data alvo, que ainda não receberam este lembrete
      const { data: reservas } = await supabase
        .from('reservas')
        .select(`
          id, nome_evento, user_id, data_reserva,
          areas_comuns!inner(tipo_agenda, tipo_reserva),
          perfil:perfil!reservas_user_id_fkey(nome, telefone, fcm_token)
        `)
        .eq('areas_comuns.tipo_reserva', 'por_dia')
        .eq('data_reserva', date)
        .in('status', ['pendente', 'aprovado'])

      if (!reservas || reservas.length === 0) continue

      // Filtrar as que já tiveram lembrete enviado
      const { data: jaEnviados } = await supabase
        .from('reserva_notificacoes')
        .select('reserva_id')
        .in('reserva_id', reservas.map(r => r.id))
        .eq('tipo', tipo)

      const jaEnviadosSet = new Set((jaEnviados ?? []).map((n: { reserva_id: string }) => n.reserva_id))

      for (const reserva of reservas) {
        if (jaEnviadosSet.has(reserva.id)) continue

        const perfil = Array.isArray(reserva.perfil) ? reserva.perfil[0] : reserva.perfil
        const area = (Array.isArray(reserva.areas_comuns) ? reserva.areas_comuns[0] : reserva.areas_comuns) as { tipo_agenda: string }
        const nomeEvento = reserva.nome_evento || area?.tipo_agenda || 'evento'
        const nomeArea = area?.tipo_agenda || 'área comum'
        const dataFmt = new Date(date + 'T12:00:00Z').toLocaleDateString('pt-BR')
        const title = `📅 Lembrete: ${nomeEvento}`
        const body = tipo === '7_dias'
          ? `Você tem "${nomeEvento}" em ${nomeArea} em 7 dias (${dataFmt})`
          : `Seu evento "${nomeEvento}" em ${nomeArea} é amanhã (${dataFmt})! 🎉`

        let canal: 'whatsapp' | 'push' | 'falha' = 'falha'

        // 1. Tentar WhatsApp
        if (perfil?.telefone) {
          const waSent = await sendWhatsApp(perfil.telefone, perfil.nome ?? '', nomeArea, dataFmt)
          if (waSent) canal = 'whatsapp'
        }

        // 2. Fallback: FCM push
        if (canal === 'falha' && perfil?.fcm_token && fcmAccessToken && projectId) {
          const pushSent = await sendFcmPush(perfil.fcm_token, title, body, projectId, fcmAccessToken)
          if (pushSent) canal = 'push'
        }

        // Registrar tentativa (mesmo falha) para não retentar
        await supabase.from('reserva_notificacoes').upsert({
          reserva_id: reserva.id,
          tipo,
          canal,
        }, { onConflict: 'reserva_id,tipo' })

        log.push({ reserva_id: reserva.id, tipo, canal, data: date })
        if (canal !== 'falha') totalSent++
      }
    }

    return new Response(JSON.stringify({ sent: totalSent, log }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('reservas-reminder error:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
