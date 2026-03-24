import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

// ── FCM helpers ──────────────────────────────────────────────────────────────

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

// ── CORS ─────────────────────────────────────────────────────────────────────
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

// ── Main handler ─────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const { condominio_id, indicacao_id } = await req.json()
    if (!condominio_id || !indicacao_id) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
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

    // 3. Fetch indicação + criador
    const { data: indicacao } = await supabase
      .from("indicacoes_servico")
      .select("nome, especialidade, criado_por")
      .eq("id", indicacao_id)
      .single()

    if (!indicacao) {
      return new Response(JSON.stringify({ error: "Indicação not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    const { data: criador } = await supabase
      .from("perfil")
      .select("nome_completo")
      .eq("id", indicacao.criado_por)
      .single()

    const { data: condoData } = await supabase
      .from("condominios")
      .select("nome")
      .eq("id", condominio_id)
      .single()

    const condoNome = condoData?.nome ?? "Condomínio"
    const indicadorNome = criador?.nome_completo ?? "Um morador"

    // 4. Fetch all active residents with FCM tokens
    const { data: moradores, error: moradoresError } = await supabase
      .from("perfil")
      .select("id, fcm_token")
      .eq("condominio_id", condominio_id)
      .eq("status_aprovacao", "active")
      .eq("bloqueado", false)
      .not("fcm_token", "is", null)

    if (moradoresError) {
      console.error(`[indicacoes-notify] Error fetching moradores: ${moradoresError.message}`)
    }

    const validMoradores = (moradores ?? []).filter((m: any) => m.fcm_token && m.fcm_token.length > 10)
    console.log(`[indicacoes-notify] Sending to ${validMoradores.length} moradores`)

    // 5. Send push
    const accessToken = await getAccessToken(serviceAccount)
    const pushTitle = `🌟 Nova indicação em ${condoNome}`
    const pushBody = `${indicacao.nome} (${indicacao.especialidade}) foi indicado por ${indicadorNome}`

    const results = await Promise.all(
      validMoradores.map((m: any) =>
        sendFcmMessage(accessToken, firebaseProjectId, m.fcm_token, pushTitle, pushBody, {
          type: "indicacao_nova",
          indicacao_id,
        })
      )
    )

    const successCount = results.filter((r: any) => r.success).length
    console.log(`[indicacoes-notify] push=${successCount}/${results.length}`)

    return new Response(
      JSON.stringify({ push: { sent: successCount, total: results.length } }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err: any) {
    console.error("Unexpected error:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
