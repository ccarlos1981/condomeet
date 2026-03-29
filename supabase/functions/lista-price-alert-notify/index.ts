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
      price_raw_id,
      sku_id,
      price,
      supermarket_id,
    } = await req.json()

    if (!price_raw_id || !sku_id || !price) {
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

    // 3. Get the SKU → variant → base product info for the notification message
    const { data: skuData } = await supabase
      .from("lista_products_sku")
      .select("id, brand, variant_id, lista_product_variants(variant_name, base_id, lista_products_base(name, icon_emoji))")
      .eq("id", sku_id)
      .single()

    if (!skuData) {
      console.warn("SKU not found:", sku_id)
      return new Response(JSON.stringify({ sent: 0, message: "SKU not found" }), { status: 200 })
    }

    const variant = skuData.lista_product_variants as any
    const baseProd = variant?.lista_products_base as any
    const productName = baseProd?.name ?? "Produto"
    const variantName = variant?.variant_name ?? ""
    const emoji = baseProd?.icon_emoji ?? "📦"
    const variantId = skuData.variant_id

    // 4. Get supermarket name (optional)
    let marketName = ""
    if (supermarket_id) {
      const { data: marketData } = await supabase
        .from("lista_supermarkets")
        .select("name")
        .eq("id", supermarket_id)
        .single()
      marketName = marketData?.name ?? ""
    }

    // 5. Find all active alerts for this variant where target_price >= reported price
    const { data: alerts, error: alertsError } = await supabase
      .from("lista_price_alerts")
      .select("id, user_id, target_price")
      .eq("variant_id", variantId)
      .eq("is_active", true)
      .gte("target_price", price)

    if (alertsError) {
      console.error("Error fetching alerts:", alertsError)
      return new Response(JSON.stringify({ error: alertsError.message }), { status: 500 })
    }

    if (!alerts || alerts.length === 0) {
      console.log(`No matching alerts for variant ${variantId} at price ${price}`)
      return new Response(JSON.stringify({ sent: 0, message: "No matching alerts" }), { status: 200 })
    }

    console.log(`Found ${alerts.length} matching alert(s) for ${productName} ${variantName} at R$${price}`)

    // 6. Get FCM tokens for all alert owners
    const userIds = [...new Set(alerts.map((a: any) => a.user_id))]
    const { data: users, error: usersError } = await supabase
      .from("perfil")
      .select("id, fcm_token")
      .in("id", userIds)
      .not("fcm_token", "is", null)

    if (usersError || !users || users.length === 0) {
      console.log("No FCM tokens found for alert owners")
      return new Response(JSON.stringify({ sent: 0, message: "No tokens found" }), { status: 200 })
    }

    // 7. Build notification
    const priceFormatted = Number(price).toFixed(2)
    const title = `${emoji} Alerta de Preço!`
    const marketInfo = marketName ? ` no ${marketName}` : ""
    const body = `${productName} ${variantName} está por R$ ${priceFormatted}${marketInfo}. Abaixo da sua meta!`

    const notifData: Record<string, string> = {
      type: "price_alert",
      price_raw_id: String(price_raw_id),
      sku_id: String(sku_id),
      price: String(price),
    }

    // 8. Get FCM access token
    const accessToken = await getAccessToken(serviceAccount)

    // 9. Send push to each user
    const results = await Promise.all(
      users.map((u: any) =>
        sendFcmMessage(accessToken, projectId, u.fcm_token, title, body, notifData)
      )
    )

    // 10. Update alerts: mark last_notified_at
    const now = new Date().toISOString()
    for (const alert of alerts) {
      await supabase
        .from("lista_price_alerts")
        .update({ last_notified_at: now })
        .eq("id", alert.id)
    }

    const successCount = results.filter((r: any) => r.success).length
    console.log(`Sent ${successCount}/${results.length} price alert push notifications`)

    return new Response(JSON.stringify({ sent: successCount, total: results.length, results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  } catch (err: any) {
    console.error("Unexpected error:", err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
