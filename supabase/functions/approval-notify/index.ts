// approval-notify — Sends WhatsApp + Push when a resident is approved
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

// ── FCM helpers ─────────────────────────────────────────────────────────────
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

async function getAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: getNumericDate(3600),
  }
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBinary(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )
  const jwt = await create({ alg: "RS256", typ: "JWT" }, payload, key)
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  })
  const data = await res.json()
  if (!data.access_token) throw new Error(`FCM token error: ${JSON.stringify(data)}`)
  return data.access_token
}

// ── UazAPI WhatsApp ──────────────────────────────────────────────────────────
async function sendWhatsApp(url: string, token: string, phone: string, msg: string): Promise<boolean> {
  try {
    const cleanedPhone = phone.replace(/\D/g, "")
    const res = await fetch(`${url}/send/text`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "token": token,
      },
      body: JSON.stringify({ number: cleanedPhone, text: msg }),
    })
    const data = await res.json()
    console.log(`WhatsApp → ${cleanedPhone}: ${res.ok ? "✅" : "❌"}`, data?.status || "")
    return res.ok
  } catch (e: unknown) {
    console.error(`WhatsApp error:`, e instanceof Error ? e.message : String(e))
    return false
  }
}

// ── Structure labels ─────────────────────────────────────────────────────────
function getBlocoLabel(tipo?: string) {
  if (tipo === "casa_quadra") return "Quadra"
  if (tipo === "casa_rua") return "Rua"
  return "Bloco"
}
function getAptoLabel(tipo?: string) {
  if (tipo === "casa_quadra") return "Lote"
  if (tipo === "casa_rua") return "Número"
  return "Apto"
}

function genCodInterno() {
  return Array.from({ length: 4 }, () =>
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"[
      Math.floor(Math.random() * 62)
    ]
  ).join("")
}

// ── Main handler ─────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })
  }

  try {
    const { perfil_id, condominio_id } = await req.json()
    if (!perfil_id || !condominio_id) {
      return new Response(JSON.stringify({ error: "perfil_id and condominio_id required" }), { status: 400 })
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // Fetch approved perfil
    const { data: perfil, error: perfilErr } = await supabase
      .from("perfil")
      .select("nome_completo, whatsapp, fcm_token, bloco_txt, apto_txt, notificacoes_whatsapp")
      .eq("id", perfil_id)
      .single()

    if (perfilErr || !perfil) {
      console.error("Perfil not found:", perfilErr)
      return new Response(JSON.stringify({ error: "Perfil not found" }), { status: 404 })
    }

    // Fetch condo info
    const { data: condo } = await supabase
      .from("condominios")
      .select("nome, tipo_estrutura")
      .eq("id", condominio_id)
      .single()

    const condoNome = condo?.nome || "seu condomínio"
    const tipoEstrutura = condo?.tipo_estrutura || "predio"
    const blocoLabel = getBlocoLabel(tipoEstrutura)
    const aptoLabel = getAptoLabel(tipoEstrutura)

    const results: string[] = []

    // ── 1. WhatsApp to approved resident ──────────────────────────────────
    if (perfil.whatsapp && perfil.whatsapp.trim() !== "" && perfil.notificacoes_whatsapp !== false) {
      const codInterno = genCodInterno()
      const msg =
        `😄\n` +
        `${condoNome}\n` +
        `\n` +
        `Seu cadastro foi aprovado e/ou ativado.\n` +
        `\n` +
        `Agora você poderá acessar o aplicativo Condomeet no ${condoNome}.\n` +
        `\n` +
        `Sua unidade está em:\n` +
        `\n` +
        `${blocoLabel}: ${perfil.bloco_txt || "-"}\n` +
        `${aptoLabel}: ${perfil.apto_txt || "-"}\n` +
        `\n` +
        `Condomeet agradece!\n` +
        `Cód interno: ${codInterno}`

      const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
      const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")

      if (UAZAPI_URL && UAZAPI_TOKEN) {
        const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, perfil.whatsapp, msg)
        results.push(`WhatsApp resident: ${sent ? "✅" : "❌"}`)
      } else {
        results.push("WhatsApp: UAZAPI not configured")
      }
    } else {
      results.push("WhatsApp: no whatsapp or opt-out")
    }

    // ── 2. Push notification to approved resident ─────────────────────────
    if (perfil.fcm_token && perfil.fcm_token.length > 10 && !perfil.fcm_token.startsWith("dummy")) {
      try {
        const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
        if (saJson) {
          const sa = JSON.parse(saJson)
          const accessToken = await getAccessToken(sa)
          const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`

          const pushRes = await fetch(fcmUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: perfil.fcm_token,
                notification: {
                  title: "✅ Cadastro Aprovado!",
                  body: `Seu cadastro no ${condoNome} foi aprovado. Acesse o app Condomeet!`,
                },
                data: { type: "approval", condominio_id },
                android: { priority: "high", notification: { channel_id: "avisos", sound: "condomeet" } },
                apns: { payload: { aps: { sound: "condomeet.aiff", badge: 1 } } },
              },
            }),
          })
          results.push(`Push resident: ${pushRes.ok ? "✅" : "❌"}`)
        }
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e)
        console.error("Push error:", msg)
        results.push(`Push error: ${msg}`)
      }
    }

    console.log(`approval-notify results:`, results)

    return new Response(JSON.stringify({ ok: true, results }), {
      headers: { "Content-Type": "application/json" },
    })
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("approval-notify error:", msg)
    return new Response(JSON.stringify({ error: msg }), { status: 500 })
  }
})
