// fale-sindico-notify — WhatsApp + Push for Fale Conosco (new thread + admin response)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

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
  if (!data.access_token) throw new Error(`FCM token error`)
  return data.access_token
}

async function sendFcmPush(accessToken: string, projectId: string, fcmToken: string, title: string, body: string, data: Record<string, string>): Promise<boolean> {
  try {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify({ message: { token: fcmToken, notification: { title, body }, data, android: { priority: "high", notification: { channel_id: "avisos", sound: "condomeet" } }, apns: { payload: { aps: { sound: "condomeet.aiff", badge: 1 } } } } }),
    })
    return res.ok
  } catch { return false }
}

async function sendWhatsApp(url: string, token: string, phone: string, msg: string): Promise<boolean> {
  try {
    const cleanedPhone = phone.replace(/\D/g, "")
    if (cleanedPhone.length < 10) return false
    const res = await fetch(`${url}/send/text`, { method: "POST", headers: { "Content-Type": "application/json", "Accept": "application/json", "token": token }, body: JSON.stringify({ number: cleanedPhone, text: msg }) })
    console.log(`WhatsApp → ${cleanedPhone}: ${res.ok ? "✅" : "❌"}`)
    return res.ok
  } catch (e: unknown) { console.error(`WhatsApp error:`, e instanceof Error ? e.message : String(e)); return false }
}

function genCodInterno() {
  return Array.from({ length: 4 }, () => "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"[Math.floor(Math.random() * 62)]).join("")
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })

  try {
    const { action, thread_id, condominio_id, resident_id, assunto } = await req.json()
    if (!condominio_id) return new Response(JSON.stringify({ error: "condominio_id required" }), { status: 400 })

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
    const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")

    const { data: condo } = await supabase.from("condominios").select("nome").eq("id", condominio_id).single()
    const condoNome = condo?.nome || "Condomínio"

    const results: string[] = []

    if (action === "new_thread") {
      // Notify síndicos about new thread
      const { data: resident } = await supabase.from("perfil").select("nome_completo").eq("id", resident_id).single()
      const residentName = resident?.nome_completo || "Morador"

      const { data: sindicos } = await supabase.from("perfil").select("id, whatsapp, fcm_token, notificacoes_whatsapp").eq("condominio_id", condominio_id).in("tipo_morador", ["Síndico"])

      if (UAZAPI_URL && UAZAPI_TOKEN) {
        const cod = genCodInterno()
        const msg = `💬 ${condoNome}\n\nNova mensagem no Fale Conosco!\n\n👤 Morador: ${residentName}\n📝 Assunto: ${assunto || "Mensagem do morador"}\n\nAcesse o painel para responder.\n\nCondomeet agradece.\nCód interno: ${cod}`

        for (const s of (sindicos ?? [])) {
          const sData = s as Record<string, unknown>
          if ((sData.whatsapp as string)?.trim() && sData.notificacoes_whatsapp !== false) {
            const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, sData.whatsapp as string, msg)
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
              const ok = await sendFcmPush(accessToken, sa.project_id, sFcm, `💬 Fale Conosco - ${condoNome}`, `${residentName}: ${assunto || "Nova mensagem"}`, { type: "fale_conosco", thread_id: thread_id || "" })
              results.push(`Push síndico: ${ok ? "✅" : "❌"}`)
            }
          }
        }
      } catch (e: unknown) { console.error("Push error:", e instanceof Error ? e.message : String(e)) }

    } else if (action === "admin_reply") {
      // Notify resident about admin reply
      const { data: resident } = await supabase.from("perfil").select("nome_completo, whatsapp, fcm_token, notificacoes_whatsapp").eq("id", resident_id).single()

      if (resident?.whatsapp && resident.notificacoes_whatsapp !== false && UAZAPI_URL && UAZAPI_TOKEN) {
        const firstName = resident.nome_completo?.split(" ")[0] || "Morador"
        const cod = genCodInterno()
        const msg = `💬 ${condoNome}\n\nOlá ${firstName},\n\nO síndico respondeu sua mensagem no Fale Conosco.\n\n📝 Assunto: ${assunto || "Sua mensagem"}\n\nAcesse o app para ver a resposta.\n\nCondomeet agradece.\nCód interno: ${cod}`
        const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, resident.whatsapp, msg)
        results.push(`WhatsApp morador: ${sent ? "✅" : "❌"}`)
      }

      if (resident?.fcm_token && resident.fcm_token.length > 10) {
        try {
          const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
          if (saJson) {
            const sa = JSON.parse(saJson)
            const accessToken = await getAccessToken(sa)
            const ok = await sendFcmPush(accessToken, sa.project_id, resident.fcm_token, `💬 Resposta do Síndico`, `Sua mensagem no Fale Conosco foi respondida`, { type: "fale_conosco_reply", thread_id: thread_id || "" })
            results.push(`Push morador: ${ok ? "✅" : "❌"}`)
          }
        } catch (e: unknown) { console.error("Push error:", e instanceof Error ? e.message : String(e)) }
      }
    }

    console.log(`fale-sindico-notify [${action}] results:`, results)
    return new Response(JSON.stringify({ ok: true, action, results }), { headers: { "Content-Type": "application/json" } })
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("fale-sindico-notify error:", msg)
    return new Response(JSON.stringify({ error: msg }), { status: 500 })
  }
})
