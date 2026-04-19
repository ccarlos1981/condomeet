// password-reset-whatsapp — Supabase Edge Function
// Sends a 6-digit password reset code via WhatsApp (BotConversa)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { smartSend } from "../_shared/botconversa.ts"

serve(async (req) => {
  try {
    const { phone, code, name } = await req.json()

    if (!phone || !code) {
      return new Response(
        JSON.stringify({ error: "Missing phone or code" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY") ?? ""

    if (!BOTCONVERSA_API_KEY) {
      console.error("BOTCONVERSA_API_KEY not configured")
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

    const result = await smartSend(BOTCONVERSA_API_KEY, null, phone, "text", msg, firstName)

    return new Response(
      JSON.stringify({ ok: result.success }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("Unexpected error:", msg)
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  }
})
