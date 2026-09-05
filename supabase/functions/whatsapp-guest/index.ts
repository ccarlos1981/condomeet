// supabase/functions/whatsapp-guest/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { sendInteractiveButtons, parseWebhook, smartSend, normalizePhone, isValidPhone, MessageType } from "../_shared/botconversa.ts";

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

      let anyDispatched = false;
      let lastError: string | null = null;

      for (const resident of activeResidents) {
        const subId = resident.botconversa_id || null;
        const phone = resident.whatsapp || null;
        
        const sendRes = await sendInteractiveButtons(
          BOTCONVERSA_API_KEY,
          subId,
          msgText,
          buttons,
          condoNome,
          "Powered by Condomeet",
          supabaseServiceRole,
          resident.id,
          phone,
          MessageType.VISITOR_AUTHORIZED,
          "whatsapp-guest"
        );

        if (sendRes.success) {
          anyDispatched = true;
        } else {
          lastError = sendRes.error || sendRes.reason || "Falha no enfileiramento";
          console.error(`[whatsapp-guest] Failed to send interactive buttons to resident ${resident.id}:`, lastError);
        }
      }

      if (!anyDispatched) {
        return new Response(JSON.stringify({ error: lastError || "Failed to dispatch approval requests" }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      return new Response(JSON.stringify({ message: "Approval requests dispatched", count: activeResidents.length }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
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

    // Identify if the text/value contains approve_ or reject_ or textual choice (1, 2, aprovar, recusar, etc.)
    const rawText = (incoming.text || "").trim();
    const match = rawText.match(/(approve|reject)_([a-f0-9\-]{36})/i);

    let decision: string | null = null;
    let visitorId: string | null = null;
    let perfil: any = null;

    // Resolve profile of the sender by phone
    const phoneVariants = [
      incoming.phone,
      incoming.phone.startsWith("55") ? incoming.phone.substring(2) : `55${incoming.phone}`,
    ];

    for (const variant of phoneVariants) {
      const { data } = await supabaseServiceRole
        .from("perfil")
        .select("id, nome_completo, condominio_id, bloco_txt, apto_txt")
        .eq("whatsapp", variant)
        .eq("status_aprovacao", "aprovado")
        .limit(1);
      if (data && data.length > 0) {
        perfil = data[0];
        break;
      }
    }

    if (match) {
      decision = match[1].toLowerCase(); // 'approve' or 'reject'
      visitorId = match[2];
    } else {
      // Check for textual responses
      const clean = rawText.toLowerCase();
      let candidateDecision: string | null = null;

      if (["1", "aprovar", "aprovado", "sim", "autorizar", "liberar"].includes(clean)) {
        candidateDecision = "approve";
      } else if (["2", "recusar", "recusado", "nao", "não", "rejeitar", "bloquear"].includes(clean)) {
        candidateDecision = "reject";
      }

      if (candidateDecision && perfil) {
        // Query pending visitors for this unit
        const { data: pendingVisitors, error: pendErr } = await supabaseServiceRole
          .from("visitante_registros")
          .select("id, condominio_id, nome, bloco, apto")
          .eq("condominio_id", perfil.condominio_id)
          .eq("bloco", perfil.bloco_txt)
          .eq("apto", perfil.apto_txt)
          .eq("status", "aguardando_aprovacao")
          .order("entrada_at", { ascending: false });

        if (pendErr) {
          console.error("[whatsapp-guest] Error fetching pending visitors:", pendErr);
        } else if (pendingVisitors && pendingVisitors.length === 1) {
          decision = candidateDecision;
          visitorId = pendingVisitors[0].id;
          console.log(`[whatsapp-guest] Text reply '${rawText}' mapped to visitor ${visitorId} (unit ${perfil.bloco_txt}/${perfil.apto_txt}) with decision ${decision}`);
        } else if (pendingVisitors && pendingVisitors.length > 1) {
          console.warn(`[whatsapp-guest] Multiple pending visitors (${pendingVisitors.length}) for unit ${perfil.bloco_txt}/${perfil.apto_txt}. Ambiguous text reply ignored.`);
          return new Response("Ambiguous text reply: multiple pending visitors", { status: 200 });
        } else {
          console.log(`[whatsapp-guest] No pending visitors found for unit ${perfil.bloco_txt}/${perfil.apto_txt}`);
          return new Response("No pending visitors for text reply", { status: 200 });
        }
      }
    }

    if (decision && visitorId) {
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

      const sendFeedbackRes = await smartSend(
        BOTCONVERSA_API_KEY,
        incoming.botconversa_id,
        incoming.phone,
        "text",
        feedbackMsg,
        perfil.nome_completo?.split(" ")[0],
        supabaseServiceRole,
        perfil.id,
        MessageType.VISITOR_AUTHORIZED,
        "whatsapp-guest"
      );

      if (!sendFeedbackRes.success) {
        console.error(`[whatsapp-guest] Failed to enqueue decision feedback:`, sendFeedbackRes.error || sendFeedbackRes.reason);
        return new Response(JSON.stringify({ error: sendFeedbackRes.error || sendFeedbackRes.reason || "Failed to enqueue feedback" }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      return new Response(JSON.stringify({ message: "Response processed", decision, visitor_id: visitorId }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    return new Response("Ignored: no match for action buttons", { status: 200 });
  } catch (err) {
    console.error("whatsapp-guest function error:", err);
    return new Response("Error", { status: 500 });
  }
});
