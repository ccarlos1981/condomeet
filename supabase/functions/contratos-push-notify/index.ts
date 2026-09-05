import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create } from 'https://deno.land/x/djwt@v2.9.1/mod.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')!

// Papéis canônicos autorizados para receber notificações administrativas de contratos
const CANONICAL_ADMIN_ROLES = [
  'síndico', 'sindico', 'admin', 'administrador',
  'síndico (a)', 'sindico (a)', 'síndico(a)', 'sindico(a)',
  'subsíndico', 'subsindico', 'subsíndico (a)', 'subsindico (a)', 'subsíndico(a)', 'subsindico(a)'
]

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
    'pkcs8', binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign'],
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

function buildNotification(fornecedor: string, titulo: string, tipo_evento: string): { title: string; body: string } {
  const nomeFornecedor = fornecedor || 'Fornecedor'
  const nomeServico = titulo ? `(${titulo})` : ''

  switch (tipo_evento) {
    case '90_DIAS':
      return {
        title: '📅 Contrato vence em 90 dias',
        body: `O contrato de ${nomeFornecedor} ${nomeServico} vence em 90 dias.`,
      }
    case '30_DIAS':
      return {
        title: '⚠️ Contrato vence em 30 dias',
        body: `O contrato de ${nomeFornecedor} ${nomeServico} vence em 30 dias.`,
      }
    case 'VENCE_HOJE':
      return {
        title: '🔴 Contrato vence hoje',
        body: `O contrato de ${nomeFornecedor} ${nomeServico} vence hoje.`,
      }
    case 'VENCIDO':
      return {
        title: '🔴 Contrato vencido',
        body: `O contrato de ${nomeFornecedor} ${nomeServico} expirou e requer atenção da administração.`,
      }
    case 'novo_contrato':
      return {
        title: '📋 Novo contrato cadastrado',
        body: `Contrato de ${nomeFornecedor} ${nomeServico} foi registrado no condomínio.`,
      }
    default:
      return {
        title: '📋 Contrato do Condomínio',
        body: `${nomeFornecedor} - ${titulo}`,
      }
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const {
      contrato_id,
      condominio_id,
      titulo,
      fornecedor_nome,
      data_validade,
      tipo_evento,
    } = await req.json()

    if (!condominio_id || !contrato_id) {
      return new Response(JSON.stringify({ error: 'condominio_id e contrato_id são obrigatórios' }), { status: 400 })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const evento = tipo_evento ?? '30_DIAS'
    const dataRef = data_validade || new Date().toISOString().slice(0, 10)

    // 1. Busca perfis aprovados do condomínio com token FCM ativo
    const { data: rawProfiles, error: profileErr } = await supabase
      .from('perfil')
      .select('id, fcm_token, papel_sistema')
      .eq('condominio_id', condominio_id)
      .eq('status_aprovacao', 'aprovado')
      .not('fcm_token', 'is', null)

    if (profileErr) throw profileErr

    // 2. Filtro estrito: Somente papéis canônicos administrativos
    const authorizedAdmins = (rawProfiles ?? []).filter((p) => {
      const role = (p.papel_sistema ?? '').trim().toLowerCase()
      return CANONICAL_ADMIN_ROLES.includes(role)
    })

    if (authorizedAdmins.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, skipped: 0, message: 'Nenhum administrador com FCM token encontrado' }),
        { headers: { 'Content-Type': 'application/json' } },
      )
    }

    // 3. Preparação do Firebase Messaging
    let accessToken: string | null = null
    let projectId: string | null = null
    let fcmUrl: string | null = null

    if (FIREBASE_SERVICE_ACCOUNT_JSON) {
      try {
        const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON)
        accessToken = await getAccessToken(serviceAccount)
        projectId = serviceAccount.project_id
        fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
      } catch (fcmInitErr) {
        console.error('Erro ao inicializar Firebase Service Account:', fcmInitErr)
      }
    }

    const { title, body } = buildNotification(fornecedor_nome, titulo ?? '', evento)

    let sentCount = 0
    let skippedCount = 0

    // 4. Envio com Idempotência Estrita (Anti-Spam)
    for (const admin of authorizedAdmins) {
      const adminId = admin.id
      const token = admin.fcm_token

      if (!token) continue

      // Verifica se o alerta deste evento já foi registrado para este destinatário
      const { data: existingLog } = await supabase
        .from('contrato_notificacoes_log')
        .select('id')
        .eq('contrato_id', contrato_id)
        .eq('tipo_alerta', evento)
        .eq('data_referencia', dataRef)
        .eq('destinatario_id', adminId)
        .maybeSingle()

      if (existingLog) {
        skippedCount++
        continue
      }

      // Dispara push FCM se configurado
      let fcmSuccess = true
      if (fcmUrl && accessToken) {
        const message = {
          message: {
            token,
            notification: { title, body },
            data: {
              type: 'contrato',
              contrato_id: contrato_id ?? '',
              tipo_evento: evento,
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
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
          fcmSuccess = res.ok
        } catch (fcmSendErr) {
          console.error(`Erro ao disparar FCM para admin ${adminId}:`, fcmSendErr)
          fcmSuccess = false
        }
      }

      // Registra idempotência no log (mesmo em modo de teste ou após disparo)
      const { error: logErr } = await supabase
        .from('contrato_notificacoes_log')
        .insert({
          condominio_id: condominio_id,
          contrato_id: contrato_id,
          tipo_alerta: evento,
          data_referencia: dataRef,
          destinatario_id: adminId,
        })

      if (logErr) {
        console.warn(`Aviso ao registrar log de idempotência: ${logErr.message}`)
      }

      sentCount++
    }

    return new Response(
      JSON.stringify({
        ok: true,
        sent: sentCount,
        skipped_duplicates: skippedCount,
        total_admins: authorizedAdmins.length,
      }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
