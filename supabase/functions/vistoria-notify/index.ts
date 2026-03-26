import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

// ── FCM HTTP v1 ──

function pemToBinary(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----BEGIN PRIVATE KEY-----/, "").replace(/-----END PRIVATE KEY-----/, "").replace(/\n/g, "")
  const binary = atob(b64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const binaryDer = pemToBinary(serviceAccount.private_key)
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"]
  )
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: now, exp: now + 3600,
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
  if (!tokenData.access_token) throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`)
  return tokenData.access_token
}

async function sendFcmMessage(
  accessToken: string, projectId: string, fcmToken: string,
  title: string, body: string, data: Record<string, string>
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
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify(payload),
    })
    const result = await res.json()
    if (!res.ok) return { success: false, token: fcmToken, error: result?.error?.message ?? JSON.stringify(result) }
    return { success: true, token: fcmToken }
  } catch (e: any) {
    return { success: false, token: fcmToken, error: e.message }
  }
}

// ── CORS ──
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

// ── Main handler ──
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const { vistoria_id, condominio_id, titulo, status } = await req.json()

    if (!vistoria_id || !condominio_id) {
      return new Response(JSON.stringify({ error: "Missing vistoria_id or condominio_id" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    // 1. Firebase service account
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if (!serviceAccountJson) {
      return new Response(JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT_JSON not set" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }
    const serviceAccount = JSON.parse(serviceAccountJson)
    const firebaseProjectId = serviceAccount.project_id

    // 2. Supabase admin client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // 3. Fetch condo info
    const { data: condoData } = await supabase
      .from("condominios")
      .select("nome")
      .eq("id", condominio_id)
      .single()

    const condoNome = condoData?.nome ?? "Condomínio"

    // 4. Choose notification message based on status
    let pushTitle: string
    let pushBody: string

    if (status === "assinada") {
      pushTitle = "✍️ Vistoria assinada"
      pushBody = `A vistoria "${titulo}" foi assinada com sucesso!`
    } else {
      pushTitle = "📋 Vistoria concluída"
      pushBody = `A vistoria "${titulo}" foi concluída no ${condoNome}. Verifique e assine!`
    }

    // 5. Notify admins/síndicos of this condo
    const { data: admins } = await supabase
      .from("perfil")
      .select("id, nome_completo, fcm_token")
      .eq("condominio_id", condominio_id)
      .or("papel_sistema.ilike.%sindico%,papel_sistema.ilike.%síndico%,papel_sistema.ilike.%admin%")

    const validAdmins = (admins ?? []).filter((a: any) => a.fcm_token && a.fcm_token.length > 10)

    const accessToken = await getAccessToken(serviceAccount)
    const pushResults: any[] = []

    for (const admin of validAdmins) {
      const result = await sendFcmMessage(accessToken, firebaseProjectId, admin.fcm_token, pushTitle, pushBody, {
        type: "vistoria_concluida",
        vistoria_id,
      })
      pushResults.push(result)
      console.log(`[vistoria-notify] Push to ${admin.nome_completo}: ${result.success ? '✅' : '❌'} ${result.error || ''}`)
    }

    const pushSuccess = pushResults.filter((r: any) => r.success).length
    console.log(`[vistoria-notify] status=${status} push=${pushSuccess}/${pushResults.length}`)

    return new Response(
      JSON.stringify({
        status,
        push: { sent: pushSuccess, total: pushResults.length },
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err: any) {
    console.error("[vistoria-notify] Error:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
