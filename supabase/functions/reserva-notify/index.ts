// reserva-notify — WhatsApp + Push for reservations (new, approved, auto-approved)
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
      method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
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
    const { action, reserva_id, user_id, condominio_id, area_nome, data_reserva, bloco_destino, apto_destino } = await req.json()
    if (!condominio_id) return new Response(JSON.stringify({ error: "condominio_id required" }), { status: 400 })

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
    const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")

    const { data: condo } = await supabase.from("condominios").select("nome").eq("id", condominio_id).single()
    const condoNome = condo?.nome || "Condomínio"

    const results: string[] = []

    if (action === "pending_approval") {
      // Manual approval needed → notify síndicos + resident(s)
      const formattedDate = data_reserva ? data_reserva.split("-").reverse().join("/") : ""
      const hasSpecificUser = user_id && user_id !== ""

      // Fetch specific resident or all unit residents
      let resident: Record<string, unknown> | null = null
      let unitResidents: Record<string, unknown>[] = []

      if (hasSpecificUser) {
        const { data: r } = await supabase.from("perfil").select("nome_completo, tipo_morador, bloco_txt, apto_txt, whatsapp, fcm_token, notificacoes_whatsapp").eq("id", user_id).single()
        resident = r
      }

      // If no specific user OR we need unit info, fetch all residents of the unit
      if (!hasSpecificUser && bloco_destino && apto_destino) {
        const { data: unitR } = await supabase.from("perfil").select("id, nome_completo, tipo_morador, bloco_txt, apto_txt, whatsapp, fcm_token, notificacoes_whatsapp").eq("condominio_id", condominio_id).eq("bloco_txt", bloco_destino).eq("apto_txt", apto_destino)
        unitResidents = (unitR ?? []) as Record<string, unknown>[]
      }

      const residentName = resident?.nome_completo as string || "Morador"
      const tipoMorador = resident?.tipo_morador as string || ""
      const bloco = resident?.bloco_txt as string || bloco_destino || ""
      const apto = resident?.apto_txt as string || apto_destino || ""

      const { data: sindicos } = await supabase.from("perfil").select("id, whatsapp, fcm_token, notificacoes_whatsapp").eq("condominio_id", condominio_id).in("tipo_morador", ["Síndico", "Síndico (a)", "Síndico(a)", "sindico", "sindico (a)", "ADMIN", "Admin", "admin"])

      // ── WhatsApp to síndicos ──
      if (UAZAPI_URL && UAZAPI_TOKEN) {
        const cod = genCodInterno()
        const msgSindico = `📆 Novo agendamento no ${condoNome}\n\n🧾Nome:\n${residentName}\n\n👉 Tipo de Cadastro:\n${tipoMorador}\n\n🏙 Unidade:\nBloco: ${bloco}\nApto: ${apto}\n\nEspaço:\n${area_nome || "Área comum"}\n\nData do agendamento:\n${formattedDate}\n\nVeja se está tudo ok, pois o morador irá aguardar a aprovação.\n\nLembre se que em 7 dias, a solicitação irá expirar!\n\nCondomeet agradece.\ncód interno: ${cod}`
        for (const s of (sindicos ?? [])) {
          const sData = s as Record<string, unknown>
          if ((sData.whatsapp as string)?.trim() && sData.notificacoes_whatsapp !== false) {
            const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, sData.whatsapp as string, msgSindico)
            results.push(`WhatsApp síndico: ${sent ? "✅" : "❌"}`)
          }
        }
      }

      // ── Push to síndicos ──
      let fcmAccessToken: string | null = null
      let fcmProjectId: string | null = null
      try {
        const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
        if (saJson) {
          const sa = JSON.parse(saJson)
          fcmAccessToken = await getAccessToken(sa)
          fcmProjectId = sa.project_id
          for (const s of (sindicos ?? [])) {
            const sFcm = (s as Record<string, unknown>).fcm_token as string | undefined
            if (sFcm && sFcm.length > 10 && !sFcm.startsWith("dummy")) {
              const ok = await sendFcmPush(fcmAccessToken, fcmProjectId!, sFcm, `📆 Reserva pendente - ${condoNome}`, `${residentName} solicitou reserva de ${area_nome || "área comum"}`, { type: "reserva_pending", reserva_id: reserva_id || "" })
              results.push(`Push síndico: ${ok ? "✅" : "❌"}`)
            }
          }
        }
      } catch (e: unknown) { console.error("Push síndico error:", e instanceof Error ? e.message : String(e)) }

      // ── Notify resident(s) ──
      if (hasSpecificUser && resident) {
        // Specific user selected → notify just them
        if (UAZAPI_URL && UAZAPI_TOKEN && (resident.whatsapp as string)?.trim() && resident.notificacoes_whatsapp !== false) {
          const codRes = genCodInterno()
          const msgResident = `📆 Condomínio ${condoNome}:\n\nA reserva do(a) ${area_nome || "Área comum"} para sua unidade, foi feita com sucesso.\n\nAguarde a administração do seu condomínio aprovar a reserva.\n\nData do evento:\n${formattedDate}\n\nSempre fique atento(a) a data e horário!\n\nCondomeet agradece!\nCód interno: ${codRes}`
          const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, resident.whatsapp as string, msgResident)
          results.push(`WhatsApp morador: ${sent ? "✅" : "❌"}`)
        }
        if (fcmAccessToken && fcmProjectId && (resident.fcm_token as string)?.length > 10) {
          const ok = await sendFcmPush(fcmAccessToken, fcmProjectId, resident.fcm_token as string, `📆 Reserva registrada - ${condoNome}`, `Sua reserva de ${area_nome || "área comum"} está pendente de aprovação`, { type: "reserva_created", reserva_id: reserva_id || "" })
          results.push(`Push morador: ${ok ? "✅" : "❌"}`)
        }
      } else if (unitResidents.length > 0) {
        // No specific user → notify ALL residents of the unit
        const codUnit = genCodInterno()
        const msgUnit = `📆Condomínio ${condoNome}\n\nAlguém do seu apto solicitou um agendamento que foi registrado com sucesso.\n\nAguarde a administração do Condominio aprovar.\n\nIremos lembrar você um dia antes do evento.\n\nCondomeet Agradece.\ncód interno: ${codUnit}`

        for (const r of unitResidents) {
          const rWhatsapp = r.whatsapp as string | undefined
          if (UAZAPI_URL && UAZAPI_TOKEN && rWhatsapp?.trim() && r.notificacoes_whatsapp !== false) {
            const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, rWhatsapp, msgUnit)
            results.push(`WhatsApp unidade ${r.nome_completo}: ${sent ? "✅" : "❌"}`)
          }
          const rFcm = r.fcm_token as string | undefined
          if (fcmAccessToken && fcmProjectId && rFcm && rFcm.length > 10 && !rFcm.startsWith("dummy")) {
            const ok = await sendFcmPush(fcmAccessToken, fcmProjectId, rFcm, `📆 Reserva registrada - ${condoNome}`, `Uma reserva de ${area_nome || "área comum"} foi feita para sua unidade`, { type: "reserva_created", reserva_id: reserva_id || "" })
            results.push(`Push unidade ${r.nome_completo}: ${ok ? "✅" : "❌"}`)
          }
        }
      }

    } else if (action === "approved" || action === "auto_approved") {
      // Notify resident about approval
      const { data: resident } = await supabase.from("perfil").select("nome_completo, whatsapp, fcm_token, notificacoes_whatsapp").eq("id", user_id).single()
      const firstName = resident?.nome_completo?.split(" ")[0] || "Morador"

      if (resident?.whatsapp && resident.notificacoes_whatsapp !== false && UAZAPI_URL && UAZAPI_TOKEN) {
        const cod = genCodInterno()
        const msg = `📆Condomínio ${condoNome}\n\nEi ${firstName}, seu agendamento foi registrado com sucesso.\n\nSua reserva já está aprovada!\n\nIremos lembrar você um dia antes do evento.\n\nCondomeet Agradece.\ncód interno: ${cod}`
        const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, resident.whatsapp, msg)
        results.push(`WhatsApp morador: ${sent ? "✅" : "❌"}`)
      }

      if (resident?.fcm_token && resident.fcm_token.length > 10) {
        try {
          const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
          if (saJson) {
            const sa = JSON.parse(saJson)
            const accessToken = await getAccessToken(sa)
            const ok = await sendFcmPush(accessToken, sa.project_id, resident.fcm_token, `✅ Reserva aprovada! - ${condoNome}`, `Ei ${firstName}, sua reserva de ${area_nome || "área comum"} foi aprovada!`, { type: "reserva_approved", reserva_id: reserva_id || "" })
            results.push(`Push morador: ${ok ? "✅" : "❌"}`)
          }
        } catch (e: unknown) { console.error("Push error:", e instanceof Error ? e.message : String(e)) }
      }

    } else if (action === "rejected") {
      // Notify resident about rejection
      const { data: resident } = await supabase.from("perfil").select("nome_completo, whatsapp, fcm_token, notificacoes_whatsapp").eq("id", user_id).single()
      const firstName = resident?.nome_completo?.split(" ")[0] || "Morador"

      if (resident?.whatsapp && resident.notificacoes_whatsapp !== false && UAZAPI_URL && UAZAPI_TOKEN) {
        const cod = genCodInterno()
        const msg = `📆 Condomínio ${condoNome}\n\nOlá ${firstName},\n\nInfelizmente sua reserva foi recusada. ❌\n\n🏠 Espaço: ${area_nome || "Área comum"}\n📅 Data: ${data_reserva || ""}\n\nEntre em contato com o síndico para mais informações.\n\nCondomeet agradece.\nCód interno: ${cod}`
        const sent = await sendWhatsApp(UAZAPI_URL, UAZAPI_TOKEN, resident.whatsapp, msg)
        results.push(`WhatsApp morador: ${sent ? "✅" : "❌"}`)
      }

      if (resident?.fcm_token && resident.fcm_token.length > 10) {
        try {
          const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
          if (saJson) {
            const sa = JSON.parse(saJson)
            const accessToken = await getAccessToken(sa)
            const ok = await sendFcmPush(accessToken, sa.project_id, resident.fcm_token, `❌ Reserva recusada - ${condoNome}`, `${area_nome || "Área comum"} - ${data_reserva || ""}`, { type: "reserva_rejected", reserva_id: reserva_id || "" })
            results.push(`Push morador: ${ok ? "✅" : "❌"}`)
          }
        } catch (e: unknown) { console.error("Push error:", e instanceof Error ? e.message : String(e)) }
      }
    }

    console.log(`reserva-notify [${action}] results:`, results)
    return new Response(JSON.stringify({ ok: true, action, results }), { headers: { "Content-Type": "application/json" } })
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("reserva-notify error:", msg)
    return new Response(JSON.stringify({ error: msg }), { status: 500 })
  }
})
