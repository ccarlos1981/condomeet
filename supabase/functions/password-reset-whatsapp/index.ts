// password-reset-whatsapp — Supabase Edge Function
// Sends a 6-digit password reset code via WhatsApp (UAZAPI)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

function normalizePhone(raw: string): string {
  return raw.replace(/\D/g, "")
}

async function sendTextMessage(
  uazapiUrl: string,
  token: string,
  phone: string,
  text: string
): Promise<boolean> {
  try {
    const cleaned = normalizePhone(phone)
    if (cleaned.length < 10) return false
    const res = await fetch(`${uazapiUrl}/send/text`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        token,
      },
      body: JSON.stringify({ number: cleaned, text }),
    })
    console.log(`WhatsApp → ${cleaned}: ${res.ok ? "✅" : "❌"}`)
    return res.ok
  } catch (e: unknown) {
    console.error("WhatsApp error:", e instanceof Error ? e.message : String(e))
    return false
  }
}

serve(async (req) => {
  try {
    const { phone, code, name } = await req.json()

    if (!phone || !code) {
      return new Response(
        JSON.stringify({ error: "Missing phone or code" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    const UAZAPI_URL = Deno.env.get("UAZAPI_URL")
    const UAZAPI_TOKEN = Deno.env.get("UAZAPI_TOKEN")

    if (!UAZAPI_URL || !UAZAPI_TOKEN) {
      console.error("UAZAPI_URL or UAZAPI_TOKEN not configured")
      return new Response(
        JSON.stringify({ error: "WhatsApp not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      )
    }

    const firstName = name || "Morador"

    const msg =
      `🔐 Condomeet - Recuperação de Senha\n\n` +
      `Olá ${firstName},\n\n` +
      `Seu código de verificação: *${code}*\n\n` +
      `⏱️ Este código expira em 5 minutos.\n` +
      `🚫 Não compartilhe este código com ninguém.\n\n` +
      `Condomeet`

    const sent = await sendTextMessage(UAZAPI_URL, UAZAPI_TOKEN, phone, msg)

    return new Response(
      JSON.stringify({ ok: sent }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  } catch (err: any) {
    console.error("Unexpected error:", err)
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  }
})
