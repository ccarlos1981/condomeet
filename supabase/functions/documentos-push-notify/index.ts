import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create } from 'https://deno.land/x/djwt@v2.9.1/mod.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')!
const UAZAPI_URL = Deno.env.get('UAZAPI_URL')
const UAZAPI_TOKEN = Deno.env.get('UAZAPI_TOKEN')

// ─── FCM helpers ───
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

  const pem = serviceAccount.private_key.replace(/\\n/g, '\n')
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  const pemContents = pem
    .substring(pem.indexOf(pemHeader) + pemHeader.length, pem.indexOf(pemFooter))
    .replace(/\s/g, '')
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0))

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

// ─── WhatsApp helper ───
async function sendWhatsApp(phone: string, msg: string): Promise<boolean> {
  if (!UAZAPI_URL || !UAZAPI_TOKEN) return false
  try {
    const cleanedPhone = phone.replace(/\D/g, '')
    if (cleanedPhone.length < 10) return false
    const res = await fetch(`${UAZAPI_URL}/send/text`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'token': UAZAPI_TOKEN },
      body: JSON.stringify({ number: cleanedPhone, text: msg }),
    })
    console.log(`WhatsApp → ${cleanedPhone}: ${res.ok ? '✅' : '❌'}`)
    return res.ok
  } catch (e) {
    console.error('WhatsApp error:', e)
    return false
  }
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return ''
  return dateStr.split('-').reverse().join('/')
}

function genCodInterno(): string {
  return Math.random().toString(36).substring(2, 6).toUpperCase()
}

// ─── Notification builders ───
function buildPushNotification(titulo: string, tipo_evento: string): { title: string; body: string } {
  switch (tipo_evento) {
    case 'novo_documento':
      return { title: '📄 Novo documento disponível', body: titulo }
    case 'documento_editado':
      return { title: '📄 Documento editado', body: titulo }
    case 'novo_contrato':
      return { title: '📄 Novo contrato disponível', body: titulo }
    case 'contrato_editado':
      return { title: '📄 Contrato editado', body: titulo }
    case 'vencimento_30':
      return { title: '⚠️ Documento vence em 30 dias', body: titulo }
    case 'vencimento_60':
      return { title: '⚠️ Documento vence em 60 dias', body: titulo }
    case 'vencimento_90':
      return { title: '⚠️ Documento vence em 90 dias', body: titulo }
    default:
      return { title: '📄 Documentos do Condomínio', body: titulo }
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const { documento_id, condominio_id, titulo, tipo_evento } = await req.json()

    if (!condominio_id) {
      return new Response(JSON.stringify({ error: 'condominio_id required' }), { status: 400 })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // ── 1. Push para moradores ──
    const { data: residents, error } = await supabase
      .from('perfil')
      .select('fcm_token')
      .eq('condominio_id', condominio_id)
      .eq('status_aprovacao', 'aprovado')
      .not('fcm_token', 'is', null)

    if (error) throw error

    const tokens: string[] = (residents ?? [])
      .map((r: { fcm_token: string }) => r.fcm_token)
      .filter((t: string): t is string => typeof t === 'string' && t.length > 0)

    let pushSent = 0
    if (tokens.length > 0) {
      const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON)
      const accessToken = await getAccessToken(serviceAccount)
      const projectId = serviceAccount.project_id
      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

      const { title, body } = buildPushNotification(titulo ?? 'Documento do condomínio', tipo_evento ?? 'novo_documento')

      for (const token of tokens) {
        const message = {
          message: {
            token,
            notification: { title, body },
            data: {
              type: 'documento',
              documento_id: documento_id ?? '',
              tipo_evento: tipo_evento ?? '',
            },
            android: {
              priority: 'high' as const,
              notification: { channel_id: 'avisos', sound: 'condomeet' },
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

        if (res.ok) pushSent++
      }
    }

    // ── 2. WhatsApp para síndicos (on create/edit) ──
    let whatsappSent = 0
    const isContrato = tipo_evento === 'novo_contrato' || tipo_evento === 'contrato_editado'
    const isDocumento = tipo_evento === 'novo_documento' || tipo_evento === 'documento_editado'
    if (isDocumento || isContrato) {
      const tableName = isContrato ? 'contratos' : 'documentos'
      const itemLabel = isContrato ? 'contrato' : 'documento'
      const isEdit = tipo_evento === 'documento_editado' || tipo_evento === 'contrato_editado'

      // Fetch document/contract details
      const { data: doc } = await supabase
        .from(tableName)
        .select('titulo, categoria, data_expedicao, data_validade')
        .eq('id', documento_id)
        .single()

      // Fetch condo name
      const { data: condo } = await supabase
        .from('condominios')
        .select('nome')
        .eq('id', condominio_id)
        .single()

      const condoNome = condo?.nome || 'Condomínio'
      const labelCapital = isContrato ? 'Contrato' : 'Documento'
      const headerLine = isEdit
        ? `${labelCapital} Editado no condomínio ${condoNome}`
        : `${labelCapital} do condomínio ${condoNome}`

      // Fetch síndicos
      const { data: sindicos } = await supabase
        .from('perfil')
        .select('nome_completo, whatsapp, notificacoes_whatsapp')
        .eq('condominio_id', condominio_id)
        .in('tipo_morador', ['Síndico'])

      for (const s of (sindicos ?? [])) {
        if (s.whatsapp?.trim() && s.notificacoes_whatsapp !== false) {
          const firstName = (s.nome_completo || 'Síndico').split(' ')[0]
          const cod = genCodInterno()
          const msg = `${headerLine}\nEi, ${firstName}.\n\nO ${itemLabel} de Título:\n${doc?.titulo || titulo || ''}\n\nCategoria do ${itemLabel}:\n${doc?.categoria || ''}\n\nData de Expedição:\n${formatDate(doc?.data_expedicao)}\n\nData de Validade:\n${formatDate(doc?.data_validade)}\n\nCondomeet Agradece.\ncód interno: ${cod}`

          const sent = await sendWhatsApp(s.whatsapp, msg)
          if (sent) whatsappSent++
        }
      }
    }

    return new Response(JSON.stringify({ pushSent, pushTotal: tokens.length, whatsappSent }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('documentos-push-notify error:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
