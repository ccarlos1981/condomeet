// ocorrencia-notify — WhatsApp + Push for occurrences (new + admin response)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.9.1/mod.ts"
import { smartSend, DELAY_TEXT_MS } from "../_shared/botconversa.ts"

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
          android: { priority: "high", notification: { channel_id: "avisos_v2", sound: "condomeet" } },
          apns: { payload: { aps: { sound: "condomeet.aiff", badge: 1 } } },
        },
      }),
    })
    return res.ok
  } catch { return false }
}

function genCodInterno(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  return Array.from({ length: 5 }, () => chars[Math.floor(Math.random() * chars.length)]).join("")
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
    const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY") ?? ""

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
      const bloco = resident?.bloco_txt || "—"
      const apto = resident?.apto_txt || "—"

      // Get síndicos by papel_sistema
      const { data: sindicos } = await supabase
        .from("perfil")
        .select("id, whatsapp, botconversa_id, fcm_token, notificacoes_whatsapp")
        .eq("condominio_id", condominio_id)
        .eq("status_aprovacao", "aprovado")
        .or("papel_sistema.ilike.%sindico%,papel_sistema.ilike.%síndico%,papel_sistema.eq.ADMIN")

      console.log(`[ocorrencia-notify] Found ${sindicos?.length ?? 0} síndicos for condo ${condominio_id}`)

      // WhatsApp to síndicos via BotConversa
      if (BOTCONVERSA_API_KEY) {
        const cod = genCodInterno()
        const msg =
          `🚨 Condomeet informa! 🚨\n\n` +
          `O(A) morador(a):\n${residentName}\n\n` +
          `Bloco:\n${bloco}\n\n` +
          `Apto:\n${apto}\n\n` +
          `Acabou de registrar uma nova *ocorrência*.\n\n` +
          `📝 Assunto: ${assunto || "Sem assunto"}\n\n` +
          `Acesse o painel para verificar.\n\n` +
          `Condomeet agradece!\n` +
          `Cód. interno: ${cod}`

        for (const s of (sindicos ?? [])) {
          const sData = s as Record<string, unknown>
          if (sData.notificacoes_whatsapp !== false && (sData.botconversa_id || (sData.whatsapp as string)?.trim())) {
            const result = await smartSend(BOTCONVERSA_API_KEY, sData.botconversa_id as string, sData.whatsapp as string, "text", msg, undefined, supabase, sData.id as string)
            results.push(`WhatsApp síndico: ${result.success ? "✅" : "❌"} ${result.error || ""}`)
            await new Promise(r => setTimeout(r, DELAY_TEXT_MS))
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
                `📋 Nova Ocorrência`,
                `${residentName} (${bloco}/${apto}): ${assunto || "Nova ocorrência"}`,
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
        .select("id, nome_completo, whatsapp, botconversa_id, fcm_token, notificacoes_whatsapp")
        .eq("id", resident_id)
        .single()

      if (resident?.notificacoes_whatsapp !== false && BOTCONVERSA_API_KEY && (resident?.botconversa_id || resident?.whatsapp)) {
        const cod = genCodInterno()
        const firstName = resident.nome_completo?.split(" ")[0] || "Morador"
        const msg =
          `📬 ${condoNome}\n\n` +
          `Ei ${firstName}, o Síndico do seu condomínio acabou de responder sua ocorrência.\n\n` +
          `📝 Assunto: ${assunto || "Sua ocorrência"}\n\n` +
          `Abra o app e veja a resposta 😊\n\n` +
          `Condomeet agradece.\n` +
          `Cód. interno: ${cod}`

        const result = await smartSend(BOTCONVERSA_API_KEY, resident.botconversa_id, resident.whatsapp, "text", msg, firstName, supabase, resident.id)
        results.push(`WhatsApp morador: ${result.success ? "✅" : "❌"}`)
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
