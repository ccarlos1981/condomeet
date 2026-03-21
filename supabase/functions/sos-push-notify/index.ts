import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

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

// ── FCM HTTP v1 helpers (same pattern as parcel-push-notify) ──────────────

async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: "RS256" as const, typ: "JWT" }
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: getNumericDate(3600),
  }

  const pemKey = serviceAccount.private_key
  const binaryDer = pemToBinary(pemKey)
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )

  const jwt = await create(header, payload, cryptoKey)

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

// ── Main handler ──────────────────────────────────────────────────────────

serve(async (req) => {
  try {
    const { sos_id, resident_id, condominium_id } = await req.json()

    if (!sos_id || !resident_id || !condominium_id) {
      return new Response(JSON.stringify({ error: "Missing required fields: sos_id, resident_id, condominium_id" }), {
        status: 400,
      })
    }

    // 1. Load Firebase service account
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if (!serviceAccountJson) {
      return new Response(JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT_JSON not set" }), { status: 500 })
    }
    const serviceAccount = JSON.parse(serviceAccountJson)
    const projectId = serviceAccount.project_id

    // 2. Supabase admin client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // 3. Get resident name and unit info
    const { data: resident, error: resError } = await supabase
      .from("perfil")
      .select("nome_completo, bloco_txt, apto_txt")
      .eq("id", resident_id)
      .single()

    if (resError || !resident) {
      console.error("Error fetching resident:", resError)
      return new Response(JSON.stringify({ error: "Resident not found" }), { status: 404 })
    }

    // Fetch tipo_estrutura for dynamic labels
    const { data: condoData } = await supabase
      .from("condominios")
      .select("tipo_estrutura")
      .eq("id", condominium_id)
      .single()
    const tipoEstrutura = condoData?.tipo_estrutura ?? 'predio'

    const residentName = resident.nome_completo ?? "Morador"
    const unitLabel =
      resident.bloco_txt && resident.apto_txt
        ? `${getBlocoLabel(tipoEstrutura)} ${resident.bloco_txt} / ${getAptoLabel(tipoEstrutura)} ${resident.apto_txt}`
        : resident.apto_txt
          ? `${getAptoLabel(tipoEstrutura)} ${resident.apto_txt}`
          : "Sem unidade"

    // 4. Get FCM tokens of síndicos, subsíndicos, and admins in the same condo
    const { data: staff, error: staffError } = await supabase
      .from("perfil")
      .select("id, nome_completo, fcm_token")
      .eq("condominio_id", condominium_id)
      .in("role", ["sindico", "subsindico", "admin"])
      .not("fcm_token", "is", null)

    if (staffError) {
      console.error("Error fetching staff:", staffError)
      return new Response(JSON.stringify({ error: staffError.message }), { status: 500 })
    }

    const validStaff = (staff ?? []).filter((s: any) => s.fcm_token && s.fcm_token.length > 10)

    if (validStaff.length === 0) {
      console.log("No FCM tokens found for síndicos/admins in condo:", condominium_id)
      return new Response(JSON.stringify({ sent: 0, message: "No staff tokens found" }), { status: 200 })
    }

    // 5. Build notification
    const title = "🚨 SOS - Emergência!"
    const body = `${residentName} (${unitLabel}) está precisando de ajuda!`

    const notifData: Record<string, string> = {
      type: "sos",
      sos_id: String(sos_id),
      resident_id: String(resident_id),
      condominium_id: String(condominium_id),
    }

    // 6. Get FCM access token and send
    const accessToken = await getAccessToken(serviceAccount)

    const results = await Promise.all(
      validStaff.map((s: any) =>
        sendFcmMessage(accessToken, projectId, s.fcm_token, title, body, notifData)
      )
    )

    const successCount = results.filter((r: any) => r.success).length
    console.log(`SOS push sent ${successCount}/${results.length} to staff for SOS: ${sos_id}`)

    return new Response(JSON.stringify({ sent: successCount, total: results.length, results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  } catch (err: any) {
    console.error("Unexpected error:", err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
