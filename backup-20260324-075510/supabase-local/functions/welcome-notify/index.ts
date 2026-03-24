// welcome-notify — Sends welcome WhatsApp msgs to new resident + notifies síndicos
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
    "pkcs8", pemToBinary(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"]
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

// ── WhatsApp via UazAPI ──────────────────────────────────────────────────────
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
    console.log(`WhatsApp → ${cleanedPhone}: ${res.ok ? "✅" : "❌"}`)
    return res.ok
  } catch (e: unknown) {
    console.error(`WhatsApp error:`, e instanceof Error ? e.message : String(e))
    return false
  }
}

function genCodInterno() {
  return Array.from({ length: 4 }, () =>
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"[
      Math.floor(Math.random() * 62)
    ]
  ).join("")
}

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

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
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

    const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")

    // Fetch perfil data
    const { data: perfil, error: perfilErr } = await supabase
      .from("perfil")
      .select("nome_completo, whatsapp, bloco_txt, apto_txt, tipo_morador, notificacoes_whatsapp")
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

    const condoNome = condo?.nome || "Condomínio"
    const tipoEstrutura = condo?.tipo_estrutura || "predio"
    const blocoLabel = getBlocoLabel(tipoEstrutura)
    const aptoLabel = getAptoLabel(tipoEstrutura)

    const firstName = perfil.nome_completo?.split(" ")[0] || "Morador"
    const lastName = perfil.nome_completo?.split(" ").slice(1).join(" ") || ""
    const results: string[] = []

    // ═════════════════════════════════════════════════════════════════
    // PART 1: Welcome messages to the new resident (2 messages)
    // ═════════════════════════════════════════════════════════════════
    if (perfil.whatsapp && perfil.whatsapp.trim() !== "" && perfil.notificacoes_whatsapp !== false && UAZAPI_URL && UAZAPI_TOKEN) {
      // Message 1: Welcome
      const cod1 = genCodInterno()
      const msg1 =
        `😀 ${condoNome}\n` +
        `\n` +
        `Olá ${firstName}, seu cadastro foi feito com sucesso.\n` +
        `\n` +
        `Em breve o Adm/Síndico do ${condoNome} irá liberar seu acesso.\n` +
        `\n` +
        `Condomeet agradece!\n` +
        `Cód interno: ${cod1}`

      const sent1 = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, perfil.whatsapp, msg1)
      results.push(`WhatsApp msg1: ${sent1 ? "✅" : "❌"}`)

      // Wait 5 seconds before second message
      await delay(5000)

      // Message 2: App info
      const cod2 = genCodInterno()
      const msg2 =
        `Ah, esse é número do aplicativo Condomeet.\n` +
        `\n` +
        `Cadastre nosso número no seu celular!\n` +
        `\n` +
        `Se precisar falar com o suporte do aplicativo Condomeet, cadastre no seu celular para não perder informação.\n` +
        `\n` +
        `Não temos informações internas do Condomínio.\n` +
        `\n` +
        `Se quiser saber das nossas novidades, siga a gente:\n` +
        `\n` +
        `www.instagram.com/condomeet.app\n` +
        `\n` +
        `Seja Bem vindo(a)!\n` +
        `Cód interno: ${cod2}`

      const sent2 = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, perfil.whatsapp, msg2)
      results.push(`WhatsApp msg2: ${sent2 ? "✅" : "❌"}`)
    } else {
      results.push("WhatsApp resident: skipped (no whatsapp or opt-out)")
    }

    // ═════════════════════════════════════════════════════════════════
    // PART 2: Notify all síndicos about new registration
    // ═════════════════════════════════════════════════════════════════
    const { data: sindicos } = await supabase
      .from("perfil")
      .select("id, whatsapp, fcm_token, notificacoes_whatsapp")
      .eq("condominio_id", condominio_id)
      .in("tipo_morador", ["Síndico"])

    const validSindicos = (sindicos ?? []).filter((s: Record<string, unknown>) => s.id !== perfil_id)

    if (validSindicos.length > 0 && UAZAPI_URL && UAZAPI_TOKEN) {
      const codSindico = genCodInterno()
      const msgSindico =
        `📗 Novo cadastro no ${condoNome}\n` +
        `\n` +
        `📝 Nome:\n` +
        `${firstName} \n` +
        `\n` +
        `📝 Sobrenome\n` +
        `${lastName} \n` +
        `\n` +
        `👉 Tipo de Cadastro:\n` +
        `${perfil.tipo_morador || "Morador"}\n` +
        `\n` +
        `🎞 Perfil:\n` +
        `${perfil.tipo_morador || "Morador (a)"}\n` +
        `\n` +
        `📲 Celular\n` +
        `${perfil.whatsapp || "Não informado"}\n` +
        `\n` +
        `🏙 Unidade:\n` +
        `${blocoLabel}: ${perfil.bloco_txt || "-"}\n` +
        `${aptoLabel}: ${perfil.apto_txt || "-"}\n` +
        `\n` +
        `Agora é só aprovar para deixar seu condomínio mais digital.\n` +
        `\n` +
        `Condomeet agradece.\n` +
        `cód interno: ${codSindico}`

      let sindicoWhatsappCount = 0
      for (let i = 0; i < validSindicos.length; i++) {
        const s = validSindicos[i] as Record<string, unknown>
        const sWhatsapp = s.whatsapp as string | undefined
        if (sWhatsapp && sWhatsapp.trim() !== "" && s.notificacoes_whatsapp !== false) {
          if (i > 0) {
            const d = Math.floor(Math.random() * 10000) + 5000
            await delay(d)
          }
          const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, sWhatsapp, msgSindico)
          if (sent) sindicoWhatsappCount++
        }
      }
      results.push(`WhatsApp síndicos: ${sindicoWhatsappCount}/${validSindicos.length}`)

      // Push to síndicos
      try {
        const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
        if (saJson) {
          const sa = JSON.parse(saJson)
          const accessToken = await getAccessToken(sa)
          const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`

          let pushCount = 0
          for (const s of validSindicos) {
            const sFcm = (s as Record<string, unknown>).fcm_token as string | undefined
            if (sFcm && sFcm.length > 10 && !sFcm.startsWith("dummy")) {
              const pushRes = await fetch(fcmUrl, {
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  Authorization: `Bearer ${accessToken}`,
                },
                body: JSON.stringify({
                  message: {
                    token: sFcm,
                    notification: {
                      title: `📗 Novo cadastro - ${condoNome}`,
                      body: `${firstName} ${lastName} solicitou acesso. Aprove no app!`,
                    },
                    data: { type: "new_registration", perfil_id, condominio_id },
                    android: { priority: "high", notification: { channel_id: "avisos", sound: "condomeet" } },
                    apns: { payload: { aps: { sound: "condomeet.aiff", badge: 1 } } },
                  },
                }),
              })
              if (pushRes.ok) pushCount++
            }
          }
          results.push(`Push síndicos: ${pushCount}/${validSindicos.length}`)
        }
      } catch (e: unknown) {
        console.error("Push síndico error:", e instanceof Error ? e.message : String(e))
      }
    } else {
      results.push("Síndicos: none found or UAZAPI not configured")
    }

    console.log(`welcome-notify results:`, results)

    return new Response(JSON.stringify({ ok: true, results }), {
      headers: { "Content-Type": "application/json" },
    })
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("welcome-notify error:", msg)
    return new Response(JSON.stringify({ error: msg }), { status: 500 })
  }
})
