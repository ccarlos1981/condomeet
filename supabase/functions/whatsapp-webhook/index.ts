import { createClient } from "npm:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const verifyToken = Deno.env.get("META_WEBHOOK_VERIFY_TOKEN") || "condomeet_meta_webhook_verify_token_2026"

  // 1. Webhook Verification (GET)
  if (req.method === "GET") {
    const url = new URL(req.url)
    const mode = url.searchParams.get("hub.mode")
    const token = url.searchParams.get("hub.verify_token")
    const challenge = url.searchParams.get("hub.challenge")

    if (mode === "subscribe" && token === verifyToken) {
      console.log("[Webhook] Verification successful.")
      return new Response(challenge, {
        status: 200,
        headers: { "Content-Type": "text/plain" },
      })
    } else {
      console.warn("[Webhook] Verification failed. Token mismatch.")
      return new Response("Forbidden", { status: 403 })
    }
  }

  // 2. Webhook Event Reception (POST)
  if (req.method === "POST") {
    try {
      const body = await req.json()
      console.log("[Webhook] Received event body:", JSON.stringify(body))

      if (body.object !== "whatsapp_business_account") {
        return new Response(JSON.stringify({ status: "ignored" }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }

      for (const entry of body.entry || []) {
        const wabaId = entry.id
        for (const change of entry.changes || []) {
          const value = change.value
          const field = change.field

          if (field === "messages") {
            // A. Process message status updates (sent, delivered, read, failed)
            if (value.statuses && value.statuses.length > 0) {
              for (const statusObj of value.statuses) {
                const wamid = statusObj.id
                const status = statusObj.status // "sent" | "delivered" | "read" | "failed"
                const recipient = statusObj.recipient_id
                const errors = statusObj.errors

                console.log(`[Webhook] Status update: wamid=${wamid}, status=${status}, recipient=${recipient}`)

                // Find corresponding message in outbox directly via JSONB field query
                const { data: messages, error: findError } = await supabase
                  .from("whatsapp_outbox")
                  .select("id, delivery_result, status")
                  .eq("delivery_result->>provider_message_id", wamid)
                  .limit(1)
                
                if (!findError && messages && messages.length > 0) {
                  const targetMsg = messages[0]
                  
                  const updatedResult = {
                    ...targetMsg.delivery_result,
                    meta_delivery_status: status,
                    meta_delivery_updated_at: new Date().toISOString()
                  }

                  if (status === "failed") {
                    const errorMsg = errors && errors[0] ? `${errors[0].code}: ${errors[0].title}` : "Meta Delivery Failed"
                    await supabase
                      .from("whatsapp_outbox")
                      .update({
                        status: "failed",
                        error_message: `Falha na entrega Meta: ${errorMsg}`,
                        delivery_result: updatedResult
                      })
                      .eq("id", targetMsg.id)
                  } else {
                    await supabase
                      .from("whatsapp_outbox")
                      .update({
                        delivery_result: updatedResult
                      })
                      .eq("id", targetMsg.id)
                  }
                }
              }
            }

            // B. Process incoming messages (residents answering the bot)
            if (value.messages && value.messages.length > 0) {
              for (const message of value.messages) {
                const from = message.from
                const text = message.text?.body || ""
                console.log(`[Webhook] Incoming message from ${from}: ${text}`)
                
                // Audit incoming message
                try {
                  await supabase.from("botconversa_monitoring").insert({
                    action_type: "META_INCOMING_MESSAGE",
                    recipient_phone: from,
                    error_message: `Mensagem recebida: ${text.substring(0, 200)}`,
                    function_name: "whatsapp-webhook",
                    delivery_status: "WHATSAPP_DELIVERY_UNKNOWN"
                  })
                } catch (_) {}

                // Update resident's last_interaction_at window and save to outbox
                try {
                  const phoneSearch = from.replace(/\D/g, "")
                  let matchedPerfil: any = null
                  
                  if (phoneSearch.length >= 8) {
                    const { data: perfil } = await supabase
                      .from("perfil")
                      .select("id, condominio_id, nome_completo")
                      .or(`whatsapp.eq.${phoneSearch},whatsapp.eq.55${phoneSearch},whatsapp.eq.${phoneSearch.slice(0, 4) + phoneSearch.slice(5)}`)
                      .limit(1)
                      .maybeSingle()
                    
                    matchedPerfil = perfil
                  }

                  if (matchedPerfil) {
                    console.log(`[Webhook] Updating last_interaction_at for perfil_id=${matchedPerfil.id}`)
                    await supabase
                      .from("perfil")
                      .update({ last_interaction_at: new Date().toISOString() })
                      .eq("id", matchedPerfil.id)
                  }

                  // Gravar a mensagem de entrada no whatsapp_outbox com status = received
                  const firstName = matchedPerfil?.nome_completo ? matchedPerfil.nome_completo.split(" ")[0] : "Morador"
                  await supabase.from("whatsapp_outbox").insert({
                    recipient_phone: from,
                    payload_type: "text",
                    message_type: "RESPOSTA_MORADOR",
                    message_content: { value: text, firstName },
                    status: "received",
                    perfil_id: matchedPerfil?.id || null,
                    condominio_id: matchedPerfil?.condominio_id || null,
                    sent_at: new Date().toISOString(),
                    message_hash: "received_" + from + "_" + Date.now() + "_" + Math.random().toString(36).substring(2, 7)
                  })
                } catch (e: any) {
                  console.error("[Webhook] Failed to process incoming message and update window:", e.message)
                }
              }
            }
          }

          // C. Process template status updates
          if (field === "template_status_update") {
            const templateName = value.template_name
            const event = value.event // "APPROVED" | "REJECTED" | "PAUSED"
            console.warn(`[Webhook] Template Status Update: ${templateName} -> ${event}`)
            
            try {
              await supabase.from("botconversa_monitoring").insert({
                action_type: "META_TEMPLATE_STATUS_UPDATE",
                recipient_phone: "system",
                error_message: `Template "${templateName}" mudou de status para: ${event}`,
                function_name: "whatsapp-webhook",
                delivery_status: "WHATSAPP_DELIVERY_UNKNOWN"
              })
            } catch (_) {}
          }

          // D. Process phone number quality updates
          if (field === "phone_number_quality_update") {
            const currentQuality = value.current_quality_rating
            const newQuality = value.new_quality_rating
            console.warn(`[Webhook] Phone Quality Update: ${currentQuality} -> ${newQuality}`)
            
            try {
              await supabase.from("botconversa_monitoring").insert({
                action_type: "META_PHONE_QUALITY_UPDATE",
                recipient_phone: "system",
                error_message: `Qualidade do numero alterada de ${currentQuality} para ${newQuality}`,
                function_name: "whatsapp-webhook",
                delivery_status: "WHATSAPP_DELIVERY_UNKNOWN"
              })
            } catch (_) {}
          }

          // E. Process account updates
          if (field === "account_update") {
            const event = value.event // "DISABLE_ALERT" | "BAN_ALERT" | etc
            console.warn(`[Webhook] Account Update Event: ${event}`)
            
            try {
              await supabase.from("botconversa_monitoring").insert({
                action_type: "META_ACCOUNT_UPDATE",
                recipient_phone: "system",
                error_message: `Alerta de conta Meta: ${event}`,
                function_name: "whatsapp-webhook",
                delivery_status: "WHATSAPP_DELIVERY_UNKNOWN"
              })
            } catch (_) {}
          }
        }
      }

      return new Response(JSON.stringify({ status: "success" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    } catch (err: any) {
      console.error("[Webhook] Error processing webhook:", err)
      return new Response(JSON.stringify({ error: err.message || String(err) }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }
  }

  return new Response("Method not allowed", { status: 405 })
})
