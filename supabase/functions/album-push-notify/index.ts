import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from 'https://deno.land/x/djwt@v2.9.1/mod.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')!

// Concorrência controlada: 25 requisições simultâneas por lote
// Equilíbrio ótimo entre velocidade (~1.4s para 150 moradores) e proteção contra esgotamento de sockets
const BATCH_SIZE = 25

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

const TITULOS_POR_TIPO: Record<string, string> = {
  evento: '🎉 Novo Evento',
  manutencao: '🔧 Nova Manutenção',
  reuniao: '👥 Nova Reunião',
  outros: '📌 Nova Informação',
  aviso: '⚠️ Novo Aviso',
  comunicado: '📢 Novo Comunicado',
}

const DEFAULT_TITULO_PUSH = '📢 Novo Comunicado'

interface EligibleResident {
  id: string
  fcm_token: string
}

interface SendResult {
  success: boolean
  profileId: string
  status?: number
  errorCode?: string | null
  tokenCleaned: boolean
}

function extractFcmErrorCode(errorData: any): string | null {
  if (!errorData?.error) return null

  // 1. Procurar em error.details pelo padrão de erro oficial do FCM v1
  if (Array.isArray(errorData.error.details)) {
    for (const detail of errorData.error.details) {
      if (detail?.errorCode && typeof detail.errorCode === 'string') {
        return detail.errorCode
      }
    }
  }

  // 2. Fallback para error.status (ex: 'NOT_FOUND', 'INVALID_ARGUMENT')
  if (typeof errorData.error.status === 'string') {
    return errorData.error.status
  }

  // 3. Fallback para error.message se for string curta
  if (typeof errorData.error.message === 'string' && errorData.error.message.length <= 50) {
    return errorData.error.message
  }

  return null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const { album_id, condominio_id, titulo, tipo_evento } = await req.json()
    const pushTitle = (tipo_evento && TITULOS_POR_TIPO[tipo_evento]) ?? DEFAULT_TITULO_PUSH

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Consulta estrita aos moradores aprovados do condomínio com token FCM preenchido
    // Seleciona exclusivamente id e fcm_token (sem dados pessoais)
    const { data: residents, error } = await supabase
      .from('perfil')
      .select('id, fcm_token')
      .eq('condominio_id', condominio_id)
      .eq('status_aprovacao', 'aprovado')
      .not('fcm_token', 'is', null)

    if (error) throw error

    const eligibleResidents: EligibleResident[] = (residents ?? []).filter(
      (r): r is EligibleResident =>
        typeof r.id === 'string' &&
        r.id.length > 0 &&
        typeof r.fcm_token === 'string' &&
        r.fcm_token.trim().length > 0,
    )

    if (eligibleResidents.length === 0) {
      console.log(
        '[FCM Summary] eligible: 0 | sent: 0 | failed: 0 | invalid_tokens_removed: 0 (No eligible tokens found)',
      )
      return new Response(
        JSON.stringify({
          success: true,
          eligible: 0,
          sent: 0,
          failed: 0,
          invalid_tokens_removed: 0,
          message: 'No eligible FCM tokens found',
        }),
        {
          headers: { 'Content-Type': 'application/json' },
        },
      )
    }

    // Obter access token do Firebase OAuth2
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON)
    const accessToken = await getAccessToken(serviceAccount)
    const projectId = serviceAccount.project_id
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    // Função de envio individual resiliente e instrumentada
    const sendNotification = async (resident: EligibleResident): Promise<SendResult> => {
      const message = {
        message: {
          token: resident.fcm_token,
          notification: {
            title: pushTitle,
            body: titulo ?? 'Confira as novas fotos do condomínio!',
          },
          data: {
            type: 'album_fotos',
            album_id: album_id ?? '',
            route: '/album-fotos',
          },
          android: {
            priority: 'high',
            notification: {
              channel_id: 'avisos_v2',
              sound: 'condomeet',
            },
          },
          apns: {
            headers: {
              'apns-priority': '10',
            },
            payload: {
              aps: {
                sound: 'condomeet.aiff',
                badge: 1,
              },
            },
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
          return { success: true, profileId: resident.id, tokenCleaned: false }
        }

        // Leitura segura do body da resposta com erro do FCM
        let errorData: any = null
        try {
          errorData = await res.json()
        } catch (_) {
          // Se JSON parsing falhar, mantém errorData como null
        }

        const fcmErrorCode = extractFcmErrorCode(errorData)
        // Somente UNREGISTERED comprova que o token não é mais utilizável/registrado
        // INVALID_ARGUMENT, 5xx, timeouts e erros transitórios NÃO removem o token
        const isUnregistered = fcmErrorCode === 'UNREGISTERED'

        // Log sanitizado de falha técnica (NUNCA expor token completo nem dados pessoais)
        console.warn(
          `[FCM Failure] profile_id: ${resident.id} | status: ${res.status} | error_code: ${fcmErrorCode ?? 'UNKNOWN'}`,
        )

        let tokenCleaned = false
        if (isUnregistered) {
          // Limpeza condicional segura:
          // Garante que só remove se o fcm_token ainda for exatamente o mesmo que falhou,
          // protegendo contra race conditions caso o app tenha atualizado um token novo
          const { error: cleanupError } = await supabase
            .from('perfil')
            .update({ fcm_token: null })
            .eq('id', resident.id)
            .eq('fcm_token', resident.fcm_token)

          if (!cleanupError) {
            tokenCleaned = true
            console.log(`[FCM Cleanup] Removido token UNREGISTERED para profile_id: ${resident.id}`)
          } else {
            console.error(
              `[FCM Cleanup Error] Falha ao limpar token para profile_id ${resident.id}: ${cleanupError.message}`,
            )
          }
        }

        return {
          success: false,
          profileId: resident.id,
          status: res.status,
          errorCode: fcmErrorCode,
          tokenCleaned,
        }
      } catch (netErr) {
        // Falha de rede ou timeout: registrar falha técnica, NUNCA limpar token
        console.warn(`[FCM Network Error] profile_id: ${resident.id} | error: ${String(netErr)}`)
        return {
          success: false,
          profileId: resident.id,
          status: 0,
          errorCode: 'NETWORK_ERROR',
          tokenCleaned: false,
        }
      }
    }

    // Processamento em concorrência controlada (batches de 25 com Promise.allSettled)
    let sent = 0
    let failed = 0
    let invalid_tokens_removed = 0

    for (let i = 0; i < eligibleResidents.length; i += BATCH_SIZE) {
      const batch = eligibleResidents.slice(i, i + BATCH_SIZE)
      const batchResults = await Promise.allSettled(
        batch.map((resident) => sendNotification(resident)),
      )

      for (const result of batchResults) {
        if (result.status === 'fulfilled') {
          if (result.value.success) {
            sent++
          } else {
            failed++
            if (result.value.tokenCleaned) {
              invalid_tokens_removed++
            }
          }
        } else {
          // Rejeição inesperada da promise
          failed++
          console.warn(`[FCM Batch Unhandled Error] ${String(result.reason)}`)
        }
      }
    }

    // Telemetria final consolidada
    console.log(
      `[FCM Summary] eligible: ${eligibleResidents.length} | sent: ${sent} | failed: ${failed} | invalid_tokens_removed: ${invalid_tokens_removed}`,
    )

    return new Response(
      JSON.stringify({
        success: true,
        eligible: eligibleResidents.length,
        sent,
        failed,
        invalid_tokens_removed,
      }),
      {
        headers: { 'Content-Type': 'application/json' },
      },
    )
  } catch (err) {
    console.error(`[FCM Fatal Error] ${String(err)}`)
    return new Response(JSON.stringify({ success: false, error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
