import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

// ── FCM HTTP v1 helpers ─────────────────────────────────────────────────────

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
      produto_nome,
      quantidade_atual,
      quantidade_minima,
      unidade,
      tipo_alerta, // 'critico' | 'zerado' | 'vencendo' | 'vencido'
    } = await req.json()

    if (!condominio_id || !produto_nome) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400 })
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

    // 3. Fetch FCM tokens for síndico + zelador of this condomínio
    const { data: recipients, error: fetchError } = await supabase
      .from("perfil")
      .select("id, nome_completo, fcm_token, papel_sistema")
      .eq("condominio_id", condominio_id)
      .not("fcm_token", "is", null)

    if (fetchError) {
      console.error("Error fetching recipients:", fetchError)
      return new Response(JSON.stringify({ error: fetchError.message }), { status: 500 })
    }

    // Filter to síndico and zelador only
    const validRecipients = (recipients ?? []).filter((r: any) => {
      if (!r.fcm_token || r.fcm_token.length < 10) return false
      const papel = (r.papel_sistema ?? "").toLowerCase()
      return papel.includes("síndico") || papel.includes("sindico") || papel.includes("zelador")
    })

    if (validRecipients.length === 0) {
      console.log("No FCM tokens found for síndico/zelador")
      return new Response(JSON.stringify({ sent: 0, message: "No tokens found" }), { status: 200 })
    }

    // 4. Build notification content based on alert type
    let title = ""
    let body = ""

    switch (tipo_alerta) {
      case "zerado":
        title = "⛔ Estoque ZERADO"
        body = `${produto_nome} está com estoque zerado! Providencie a reposição imediata.`
        break
      case "vencido":
        title = "🚫 Produto VENCIDO"
        body = `${produto_nome} está com validade expirada. Retire do estoque.`
        break
      case "vencendo":
        title = "⏰ Produto vencendo"
        body = `${produto_nome} está próximo da validade. Verifique o estoque.`
        break
      case "critico":
      default:
        title = "⚠️ Estoque CRÍTICO"
        body = `${produto_nome}: ${quantidade_atual ?? 0} ${unidade ?? "un"} restantes (mínimo: ${quantidade_minima ?? 0}).`
        break
    }

    const notifData: Record<string, string> = {
      type: "estoque_critico",
      produto: produto_nome,
      quantidade: String(quantidade_atual ?? 0),
      alerta: tipo_alerta ?? "critico",
    }

    // 5. Get FCM access token
    const accessToken = await getAccessToken(serviceAccount)

    // 6. Send to all síndico/zelador tokens
    const results = await Promise.all(
      validRecipients.map((r: any) =>
        sendFcmMessage(accessToken, projectId, r.fcm_token, title, body, notifData)
      )
    )

    const successCount = results.filter((r: any) => r.success).length
    console.log(`Sent ${successCount}/${results.length} estoque push notifications (${tipo_alerta})`)

    return new Response(JSON.stringify({ sent: successCount, total: results.length, results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  } catch (err: any) {
    console.error("Unexpected error:", err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
