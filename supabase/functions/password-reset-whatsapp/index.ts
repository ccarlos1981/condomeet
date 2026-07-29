// password-reset-whatsapp — Supabase Edge Function
// Sends a 6-digit password reset code via WhatsApp using the official
// MetaTemplateService architecture (AUTHENTICATION template).
//
// Architecture: Structured Contract (FASE 2) → smartSend → whatsapp_outbox → worker
// Template: condomeet_recuperacao_senha_v1 (AUTHENTICATION category)
// MessageType: OTP (Priority 1 — Queue High)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js@2"
import { smartSend, MessageType } from "../_shared/botconversa.ts"

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

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // Normalize phone to search profile
    let cleanPhoneStr = phone.replace(/\D/g, "")
    if (cleanPhoneStr.startsWith("55") && cleanPhoneStr.length > 11) {
      // Keep it
    } else if (!cleanPhoneStr.startsWith("55") && cleanPhoneStr.length >= 10) {
      cleanPhoneStr = "55" + cleanPhoneStr
    }

    const { data: perfil } = await supabase
      .from("perfil")
      .select("id, botconversa_id")
      .eq("whatsapp", cleanPhoneStr)
      .limit(1)
      .maybeSingle()

    const firstName = name || "Morador"

    // Texto da mensagem (fallback visual para BotConversa e logs de auditoria).
    // Quando enviado via Meta Cloud API, o worker utiliza o template AUTHENTICATION
    // via contrato estruturado, ignorando este texto.
    const msg =
      `🔐 Condomeet - Recuperação de Senha\n\n` +
      `Olá ${firstName},\n\n` +
      `Seu código de verificação: *${code}*\n\n` +
      `⏱️ Este código expira em 5 minutos.\n` +
      `🚫 Não compartilhe este código com ninguém.\n\n` +
      `Condomeet`

    // Template parameters para o contrato estruturado FASE 2.
    // O template AUTHENTICATION 'condomeet_recuperacao_senha_v1' espera 2 parâmetros:
    //   {{1}} = Nome do usuário
    //   {{2}} = Código de verificação (OTP)
    const templateParams = [firstName, code]

    const result = await smartSend(
      BOTCONVERSA_API_KEY,
      perfil?.botconversa_id,
      phone,
      "text",
      msg,
      firstName,
      supabase,
      perfil?.id,
      MessageType.OTP,                    // messageType — Resolução oficial via EVENT_PRIORITY_MAP
      "password-reset-whatsapp",          // callerFunction — Rastreabilidade operacional
      templateParams                      // templateParams — Contrato estruturado FASE 2
    )

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
