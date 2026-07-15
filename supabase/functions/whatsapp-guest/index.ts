// supabase/functions/whatsapp-guest/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { sendInteractiveButtons, parseWebhook, smartSend, normalizePhone, isValidPhone } from "../_shared/botconversa.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseServiceRole = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY") || "";
    if (!BOTCONVERSA_API_KEY) {
      console.error("BOTCONVERSA_API_KEY not configured");
      return new Response("BotConversa not configured", { status: 500 });
    }

    const body = await req.json();
    console.log("whatsapp-guest payload received:", JSON.stringify(body));

    // SCENARIO 1: Triggered by database to SEND an approval request to the resident
    if (body.action === "send_approval_request") {
      const { visitor_id, condominio_id, nome, bloco, apto } = body;

      // 1. Fetch target unit residents
      const { data: residents, error: resErr } = await supabaseServiceRole
        .from("perfil")
        .select("id, nome_completo, botconversa_id, whatsapp, notificacoes_whatsapp")
        .eq("condominio_id", condominio_id)
        .eq("bloco_txt", bloco)
        .eq("apto_txt", apto)
        .eq("status_aprovacao", "aprovado");

      if (resErr) {
        console.error("Error fetching residents:", resErr);
        return new Response("Error fetching residents", { status: 500 });
      }

      if (!residents || residents.length === 0) {
        console.log(`No residents found for ${bloco}/${apto}`);
        return new Response("No residents found", { status: 200 });
      }

      // Filter opt-in residents with valid botconversa_id or whatsapp
      const activeResidents = residents.filter(
        (r) => r.notificacoes_whatsapp !== false && (r.botconversa_id || r.whatsapp)
      );

      if (activeResidents.length === 0) {
        console.log(`No active opt-in residents for ${bloco}/${apto}`);
        return new Response("No active residents", { status: 200 });
      }

      // 2. Fetch condominium name
      const { data: condo } = await supabaseServiceRole
        .from("condominios")
        .select("nome")
        .eq("id", condominio_id)
        .single();
      const condoNome = condo?.nome || "Condomínio";

      // 3. Send interactive button message to each resident
      const msgText = `🔔 *Visita pendente para aprovação:*\n\nO visitante *${nome}* está na portaria solicitando entrada para a sua unidade (${bloco}/${apto}).\n\nPor favor, escolha uma das opções abaixo:`;
      const buttons = [
        { id: `approve_${visitor_id}`, title: "Aprovar Entrada" },
        { id: `reject_${visitor_id}`, title: "Recusar Entrada" },
      ];

      for (const resident of activeResidents) {
        const subId = resident.botconversa_id || null;
        const phone = resident.whatsapp || null;
        
        await sendInteractiveButtons(
          BOTCONVERSA_API_KEY,
          subId,
          msgText,
          buttons,
          condoNome,
          "Powered by Condomeet",
          supabaseServiceRole,
          resident.id,
          phone
        );
      }

      return new Response("Approval requests dispatched", { status: 200 });
    }

    // SCENARIO 2: Callback/Webhook response from WhatsApp user reply
    const incoming = parseWebhook(body);
    if (!incoming) {
      return new Response("Ignored: not a valid BotConversa message", { status: 200 });
    }

    // Update last_message_received_at in whatsapp_health_status
    try {
      await supabaseServiceRole.from("whatsapp_health_status").update({
        last_message_received_at: new Date().toISOString()
      }).eq("id", "singleton");
    } catch (err) {
      console.error("[HealthCheck] Failed to update last_message_received_at:", err);
    }

    // Identify if the text/value contains approve_ or reject_
    const rawText = incoming.text || "";
    // BotConversa button click sends the payload ID as the message text/value
    const match = rawText.match(/(approve|reject)_([a-f0-9\-]{36})/i);

    if (match) {
      const decision = match[1].toLowerCase(); // 'approve' or 'reject'
      const visitorId = match[2];

      console.log(`Action reply decoded: ${decision} for visitor ${visitorId} from ${incoming.phone}`);

      // First fetch the visitor record to get its condominio_id
      const { data: visitor, error: visErr } = await supabaseServiceRole
        .from("visitante_registros")
        .select("condominio_id")
        .eq("id", visitorId)
        .maybeSingle();

      if (visErr || !visitor) {
        console.error(`Visitor not found: ${visitorId}`, visErr);
        return new Response("Visitor not found", { status: 200 });
      }

      // Get profile of the sender to log approved_por
      const phoneVariants = [
        incoming.phone,
        incoming.phone.startsWith("55") ? incoming.phone.substring(2) : `55${incoming.phone}`,
      ];

      let perfil = null;
      for (const variant of phoneVariants) {
        const { data } = await supabaseServiceRole
          .from("perfil")
          .select("id, nome_completo")
          .eq("whatsapp", variant)
          .eq("condominio_id", visitor.condominio_id)
          .eq("status_aprovacao", "aprovado")
          .limit(1);
        if (data && data.length > 0) {
          perfil = data[0];
          break;
        }
      }

      // Fallback in case of no match with condominio_id
      if (!perfil) {
        for (const variant of phoneVariants) {
          const { data } = await supabaseServiceRole
            .from("perfil")
            .select("id, nome_completo")
            .eq("whatsapp", variant)
            .eq("status_aprovacao", "aprovado")
            .limit(1);
          if (data && data.length > 0) {
            perfil = data[0];
            break;
          }
        }
      }

      if (!perfil) {
        console.warn(`Profile not found for phone ${incoming.phone}`);
        return new Response("Profile not found", { status: 200 });
      }

      const statusValue = decision === "approve" ? "liberado" : "rejeitado";

      // Update visitor status
      const { error: updateErr } = await supabaseServiceRole
        .from("visitante_registros")
        .update({
          status: statusValue,
          aprovado_por: perfil.id,
          aprovado_at: new Date().toISOString(),
          canal_liberacao: "whatsapp",
        })
        .eq("id", visitorId);

      if (updateErr) {
        console.error("Error updating visitor record:", updateErr);
        return new Response("DB update failed", { status: 500 });
      }

      // Send feedback back to the resident
      const feedbackMsg = decision === "approve"
        ? `✅ Entrada autorizada com sucesso! A liberação foi sincronizada com a portaria.`
        : `❌ Entrada recusada. A portaria foi notificada.`;

      await smartSend(
        BOTCONVERSA_API_KEY,
        incoming.botconversa_id,
        incoming.phone,
        "text",
        feedbackMsg,
        perfil.nome_completo?.split(" ")[0],
        supabaseServiceRole,
        perfil.id
      );

      return new Response("Response processed", { status: 200 });
    }

    return new Response("Ignored: no match for action buttons", { status: 200 });
  } catch (err) {
    console.error("whatsapp-guest function error:", err);
    return new Response("Error", { status: 500 });
  }
});
