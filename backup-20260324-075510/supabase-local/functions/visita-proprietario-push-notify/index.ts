import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

// ── Dynamic structure labels ────────────────────────────────────────────────
function getBlocoLabel(tipo?: string): string {
  if (tipo === 'casa_quadra') return 'Quadra'
  if (tipo === 'casa_rua') return 'Rua'
  return 'Bloco'
}
function getAptoLabel(tipo?: string): string {
  if (tipo === 'casa_quadra') return 'Lote'
  if (tipo === 'casa_rua') return 'Número'
  return 'Apto'
}

// ── FCM HTTP v1 send ───────────────────────────────────────────────────────

function pemToBinary(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "")
  const binary = atob(b64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)

  const binaryDer = pemToBinary(serviceAccount.private_key)
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )

  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    },
    cryptoKey
  )

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  })

  const tokenData = await tokenRes.json()
  if (!tokenData.access_token) {
    throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`)
  }
  return tokenData.access_token
}

async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<{ success: boolean; token: string; error?: string }> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
  const payload = {
    message: {
      token: fcmToken,
      notification: { title, body },
      data,
      android: { priority: "high", notification: { channel_id: "avisos", sound: "condomeet" } },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "condomeet.aiff", badge: 1 } },
      },
    },
  }

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(payload),
    })

    const result = await res.json()
    if (!res.ok) {
      const errMsg = result?.error?.message ?? JSON.stringify(result)
      return { success: false, token: fcmToken, error: errMsg }
    }
    return { success: true, token: fcmToken }
  } catch (e: any) {
    return { success: false, token: fcmToken, error: e.message }
  }
}

// ── Main handler ───────────────────────────────────────────────────────────

serve(async (req) => {
  try {
    const {
      condominio_id,
      bloco,
      apto,
      tipo,          // 'entrada' | 'saida'
      nome_morador,
    } = await req.json()

    if (!condominio_id || !tipo || !nome_morador) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400 })
    }

    if (!bloco && !apto) {
      console.warn(`Skipping push: bloco and apto are empty`)
      return new Response(
        JSON.stringify({ sent: 0, message: "Skipped — no bloco/apto to target" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    }

    // 1. Load Firebase service account
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if (!serviceAccountJson) {
      return new Response(JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT_JSON not set" }), { status: 500 })
    }
    const serviceAccount = JSON.parse(serviceAccountJson)
    const projectId = serviceAccount.project_id

    // 2. Load Supabase admin client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // 3. Fetch FCM tokens for residents of the unit
    const query = supabase
      .from("perfil")
      .select("id, nome_completo, fcm_token")
      .eq("condominio_id", condominio_id)
      .not("fcm_token", "is", null)

    if (bloco) query.eq("bloco_txt", bloco)
    if (apto) query.eq("apto_txt", apto)

    const { data: residents, error: resError } = await query
    if (resError) {
      console.error("Error fetching residents:", resError)
      return new Response(JSON.stringify({ error: resError.message }), { status: 500 })
    }

    const validResidents = (residents ?? []).filter((r: any) => r.fcm_token && r.fcm_token.length > 10)

    if (validResidents.length === 0) {
      console.log("No FCM tokens found for unit", bloco, apto)
      return new Response(JSON.stringify({ sent: 0, message: "No tokens found" }), { status: 200 })
    }

    // 4. Fetch tipo_estrutura for dynamic labels
    const { data: condoData } = await supabase
      .from("condominios")
      .select("tipo_estrutura")
      .eq("id", condominio_id)
      .single()
    const tipoEstrutura = condoData?.tipo_estrutura ?? 'predio'

    // 5. Build notification content
    const unitLabel = `${getBlocoLabel(tipoEstrutura)} ${bloco ?? "?"} / ${getAptoLabel(tipoEstrutura)} ${apto ?? "?"}`
    const isEntrada = tipo === 'entrada'

    const title = isEntrada ? "🚪 Entrada registrada" : "🚪 Saída registrada"
    const body = `${nome_morador} — ${isEntrada ? 'entrada' : 'saída'} registrada. ${unitLabel}`

    const notifData: Record<string, string> = {
      type: "visita_proprietario",
      event: tipo,
      nome_morador,
      bloco: bloco ?? "",
      apto: apto ?? "",
    }

    // 6. Get FCM access token
    const accessToken = await getAccessToken(serviceAccount)

    // 7. Send to all tokens
    const results = await Promise.all(
      validResidents.map((r: any) =>
        sendFcmMessage(accessToken, projectId, r.fcm_token, title, body, notifData)
      )
    )

    const successCount = results.filter((r: any) => r.success).length
    console.log(`Sent ${successCount}/${results.length} push notifications for visita_proprietario: ${tipo}`)

    return new Response(JSON.stringify({ sent: successCount, total: results.length, results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  } catch (err: any) {
    console.error("Unexpected error:", err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
