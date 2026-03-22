// ocorrencia-notify — WhatsApp + Push for occurrences (new + admin response)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

// ── FCM helpers ────────────────────────────────────────────────────────────
function pemToBinary(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----BEGIN PRIVATE KEY-----/, "").replace(/-----END PRIVATE KEY-----/, "").replace(/\n/g, "")
  const binary = atob(b64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

async function getAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const key = await crypto.subtle.importKey("pkcs8", pemToBinary(sa.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"])
  const jwt = await create({ alg: "RS256", typ: "JWT" }, { iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: "https://oauth2.googleapis.com/token", iat: now, exp: getNumericDate(3600) }, key)
  const res = await fetch("https://oauth2.googleapis.com/token", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }) })
  const data = await res.json()
  if (!data.access_token) throw new Error(`FCM token error: ${JSON.stringify(data)}`)
  return data.access_token
}

async function sendFcmPush(accessToken: string, projectId: string, fcmToken: string, title: string, body: string, data: Record<string, string>): Promise<boolean> {
  try {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify({
        message: { token: fcmToken, notification: { title, body }, data,
          android: { priority: "high", notification: { channel_id: "avisos", sound: "condomeet" } },
          apns: { payload: { aps: { sound: "condomeet.aiff", badge: 1 } } },
        },
      }),
    })
    return res.ok
  } catch { return false }
}

// ── WhatsApp via UazAPI ──────────────────────────────────────────────────
async function sendWhatsApp(url: string, token: string, phone: string, msg: string): Promise<boolean> {
  try {
    const cleanedPhone = phone.replace(/\D/g, "")
    if (cleanedPhone.length < 10) return false
    const res = await fetch(`${url}/send/text`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json", "token": token },
      body: JSON.stringify({ number: cleanedPhone, text: msg }),
    })
    console.log(`WhatsApp → ${cleanedPhone}: ${res.ok ? "✅" : "❌"}`)
    return res.ok
  } catch (e: unknown) {
    console.error(`WhatsApp error:`, e instanceof Error ? e.message : String(e))
    return false
  }
}

function genCodInterno() {
  return Array.from({ length: 4 }, () =>
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"[Math.floor(Math.random() * 62)]
  ).join("")
}

// ── Main handler ─────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })

  try {
    const { action, ocorrencia_id, resident_id, condominio_id, assunto, admin_response } = await req.json()

    if (!ocorrencia_id || !condominio_id) {
      return new Response(JSON.stringify({ error: "ocorrencia_id and condominio_id required" }), { status: 400 })
    }

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
    const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")

    // Fetch condo name
    const { data: condo } = await supabase.from("condominios").select("nome").eq("id", condominio_id).single()
    const condoNome = condo?.nome || "Condomínio"

    const results: string[] = []

    if (action === "created") {
      // ═══════════════════════════════════════════════════════════════
      // NEW OCCURRENCE → Notify síndicos
      // ═══════════════════════════════════════════════════════════════
      const { data: resident } = await supabase
        .from("perfil")
        .select("nome_completo, bloco_txt, apto_txt")
        .eq("id", resident_id)
        .single()

      const residentName = resident?.nome_completo || "Morador"

      // Get síndicos
      const { data: sindicos } = await supabase
        .from("perfil")
        .select("id, whatsapp, fcm_token, notificacoes_whatsapp")
        .eq("condominio_id", condominio_id)
        .in("tipo_morador", ["Síndico"])

      // WhatsApp to síndicos
      if (UAZAPI_URL && UAZAPI_TOKEN) {
        const cod = genCodInterno()
        const msg =
          `📋 ${condoNome}\n` +
          `\n` +
          `Nova ocorrência registrada!\n` +
          `\n` +
          `👤 Morador: ${residentName}\n` +
          `📝 Assunto: ${assunto || "Sem assunto"}\n` +
          `\n` +
          `Acesse o painel para verificar.\n` +
          `\n` +
          `Condomeet agradece.\n` +
          `Cód interno: ${cod}`

        for (const s of (sindicos ?? [])) {
          const sData = s as Record<string, unknown>
          const sWhatsapp = sData.whatsapp as string | undefined
          if (sWhatsapp && sWhatsapp.trim() !== "" && sData.notificacoes_whatsapp !== false) {
            const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, sWhatsapp, msg)
            results.push(`WhatsApp síndico: ${sent ? "✅" : "❌"}`)
          }
        }
      }

      // Push to síndicos
      try {
        const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
        if (saJson) {
          const sa = JSON.parse(saJson)
          const accessToken = await getAccessToken(sa)
          for (const s of (sindicos ?? [])) {
            const sFcm = (s as Record<string, unknown>).fcm_token as string | undefined
            if (sFcm && sFcm.length > 10 && !sFcm.startsWith("dummy")) {
              const ok = await sendFcmPush(accessToken, sa.project_id, sFcm,
                `📋 Nova Ocorrência - ${condoNome}`,
                `${residentName}: ${assunto || "Nova ocorrência registrada"}`,
                { type: "ocorrencia", ocorrencia_id }
              )
              results.push(`Push síndico: ${ok ? "✅" : "❌"}`)
            }
          }
        }
      } catch (e: unknown) {
        console.error("Push error:", e instanceof Error ? e.message : String(e))
      }

    } else if (action === "responded") {
      // ═══════════════════════════════════════════════════════════════
      // ADMIN RESPONDED → Notify resident
      // ═══════════════════════════════════════════════════════════════
      const { data: resident } = await supabase
        .from("perfil")
        .select("nome_completo, whatsapp, fcm_token, notificacoes_whatsapp")
        .eq("id", resident_id)
        .single()

      if (resident?.whatsapp && resident.notificacoes_whatsapp !== false && UAZAPI_URL && UAZAPI_TOKEN) {
        const cod = genCodInterno()
        const firstName = resident.nome_completo?.split(" ")[0] || "Morador"
        const msg =
          `📋 ${condoNome}\n` +
          `\n` +
          `Olá ${firstName},\n` +
          `\n` +
          `O síndico respondeu sua ocorrência:\n` +
          `📝 Assunto: ${assunto || "Sua ocorrência"}\n` +
          `\n` +
          `💬 Resposta: ${admin_response || "Verifique no app"}\n` +
          `\n` +
          `Condomeet agradece.\n` +
          `Cód interno: ${cod}`

        const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, resident.whatsapp, msg)
        results.push(`WhatsApp morador: ${sent ? "✅" : "❌"}`)
      }

      // Push to resident
      if (resident?.fcm_token && resident.fcm_token.length > 10) {
        try {
          const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
          if (saJson) {
            const sa = JSON.parse(saJson)
            const accessToken = await getAccessToken(sa)
            const ok = await sendFcmPush(accessToken, sa.project_id, resident.fcm_token,
              `📋 Ocorrência respondida`,
              `O síndico respondeu sua ocorrência sobre: ${assunto || ""}`,
              { type: "ocorrencia_response", ocorrencia_id }
            )
            results.push(`Push morador: ${ok ? "✅" : "❌"}`)
          }
        } catch (e: unknown) {
          console.error("Push error:", e instanceof Error ? e.message : String(e))
        }
      }
    }

    console.log(`ocorrencia-notify [${action}] results:`, results)
    return new Response(JSON.stringify({ ok: true, action, results }), {
      headers: { "Content-Type": "application/json" },
    })
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("ocorrencia-notify error:", msg)
    return new Response(JSON.stringify({ error: msg }), { status: 500 })
  }
})
