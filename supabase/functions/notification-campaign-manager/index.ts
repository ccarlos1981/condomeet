// notification-campaign-manager — Supabase Edge Function
// Manages the Notification Campaign Engine lifecycle & dashboard

import { createClient } from "npm:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const authHeader = req.headers.get("Authorization") ?? ""
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  try {
    const url = new URL(req.url)
    const action = url.pathname.split("/").pop()
    const body = await req.json().catch(() => ({}))

    // ── Pre-check: WhatsApp Status Block for sending actions ────────────────
    if (action === "approve" || action === "resume") {
      const { data: health } = await supabase
        .from("whatsapp_health_status")
        .select("whatsapp_connection_status")
        .eq("id", "singleton")
        .single()

      if (health?.whatsapp_connection_status === "disconnected") {
        return jsonResponse({
          error: "Rejeitado pelo Supervisor: O canal do WhatsApp esta desconectado no momento. Resolva a conexao antes de iniciar ou retomar campanhas."
        }, 400)
      }
    }

    if (action === "dashboard") {
      const mode = url.searchParams.get("mode") || "executive"

      // 1. Fetch Health Status
      const { data: health } = await supabase
        .from("whatsapp_health_status")
        .select("*")
        .eq("id", "singleton")
        .single()

      // 2. Fetch Pending Queue Size
      const { count: pendingQueue } = await supabase
        .from("notification_campaign_recipients")
        .select("id", { count: "exact", head: true })
        .eq("status", "pending")

      // 3. Fetch Active Campaigns (via dashboard view)
      const { data: activeCamps } = await supabase
        .from("vw_notification_campaign_dashboard")
        .select("*")
        .eq("campaign_status", "sending")

      // 4. Fetch Active Warnings (Critical/Warning logs from last 48h)
      const { data: activeAlerts } = await supabase
        .from("notification_supervisor_logs")
        .select("*")
        .in("severity", ["WARNING", "CRITICAL"])
        .gte("created_at", new Date(Date.now() - 48 * 3600000).toISOString())
        .order("created_at", { ascending: false })
        .limit(5)

      // 5. Fetch Telemetria Stats (via monitoring dashboard view)
      const { data: telemetry } = await supabase
        .from("vw_botconversa_monitoring_dashboard")
        .select("*")
        .maybeSingle()

      if (mode === "executive") {
        return jsonResponse({
          success: true,
          mode: "executive",
          general_health: health?.status || "unknown",
          api_status: health?.api_status || "unknown",
          whatsapp_connection_status: health?.whatsapp_connection_status || "unknown",
          connection_source: health?.connection_source || "unknown",
          confidence_level: health?.confidence_level || "unknown",
          queue_size_pending: pendingQueue || 0,
          active_campaigns_count: activeCamps?.length || 0,
          active_campaigns: (activeCamps || []).map(c => ({
            id: c.campaign_id,
            title: c.campaign_title,
            progress: c.progress_percentage,
            estimated_finish_at: c.estimated_finish_at
          })),
          active_alerts: (activeAlerts || []).map(a => ({
            created_at: a.created_at,
            severity: a.severity,
            rule_name: a.rule_name,
            message: a.message
          }))
        })
      } else {
        // Technical mode
        const { data: supervisorLogs } = await supabase
          .from("notification_supervisor_logs")
          .select("*")
          .order("created_at", { ascending: false })
          .limit(20)

        return jsonResponse({
          success: true,
          mode: "technical",
          last_api_success_at: health?.last_api_success_at || null,
          last_api_failure_at: health?.last_api_failure_at || null,
          last_reconnected_at: health?.last_reconnected_at || null,
          last_disconnected_at: health?.last_disconnected_at || null,
          last_error: health?.last_error || null,
          fail_count: health?.fail_count || 0,
          telemetry_metrics: telemetry || null,
          supervisor_logs: (supervisorLogs || []).map(l => ({
            created_at: l.created_at,
            severity: l.severity,
            rule_name: l.rule_name,
            message: l.message,
            action_taken: l.action_taken
          }))
        })
      }
    }

    if (action === "estimate") {
      const { condominio_id, filters } = body
      if (!condominio_id) return jsonResponse({ error: "condominio_id is required" }, 400)

      // Fetch Condo Limits
      const { data: condo, error: condoErr } = await supabase
        .from("condominios")
        .select("whatsapp_batch_size, whatsapp_batch_pause_minutes, max_whatsapp_per_hour, max_whatsapp_per_day")
        .eq("id", condominio_id)
        .single()

      if (condoErr || !condo) return jsonResponse({ error: "Condo settings not found" }, 404)

      // Fetch Recipient Profiles
      let query = supabase
        .from("perfil")
        .select("id")
        .eq("condominio_id", condominio_id)
        .not("whatsapp", "is", null)

      if (filters?.bloco) query = query.eq("bloco_txt", filters.bloco)
      if (filters?.apto) query = query.eq("apto_txt", filters.apto)
      if (filters?.role) query = query.eq("papel_sistema", filters.role)

      const { data: profiles, error: profErr } = await query
      if (profErr) return jsonResponse({ error: profErr.message }, 500)

      const totalRecipients = profiles?.length || 0
      const batchSize = condo.whatsapp_batch_size || 50
      const batchPauseMinutes = condo.whatsapp_batch_pause_minutes || 5
      const batches = Math.ceil(totalRecipients / batchSize)
      
      // 4 seconds per message average
      const activeSendMinutes = (totalRecipients * 4) / 60
      const pauseMinutes = batches > 1 ? (batches - 1) * batchPauseMinutes : 0
      const estimatedDurationMinutes = Math.ceil(activeSendMinutes + pauseMinutes)
      
      const now = new Date()
      const estimatedFinishAt = new Date(now.getTime() + estimatedDurationMinutes * 60000)

      return jsonResponse({
        success: true,
        total_recipients: totalRecipients,
        estimated_batches: batches,
        estimated_duration_minutes: estimatedDurationMinutes,
        estimated_finish_at: estimatedFinishAt.toISOString(),
        risk_warning: "AVISO: Envios em lote/campanha pelo WhatsApp carregam risco inerente de restrição da Meta caso os destinatários marquem a mensagem como spam. Certifique-se de que o conteúdo é relevante."
      })
    }

    if (action === "create") {
      const { condominio_id, title, channel, message_type, message_value, filters, created_by } = body
      if (!condominio_id || !title || !message_value) {
        return jsonResponse({ error: "Missing required fields (condominio_id, title, message_value)" }, 400)
      }

      // Fetch Condo Settings
      const { data: condo } = await supabase
        .from("condominios")
        .select("whatsapp_batch_size, whatsapp_batch_pause_minutes, max_whatsapp_per_hour, max_whatsapp_per_day")
        .eq("id", condominio_id)
        .single()

      if (!condo) return jsonResponse({ error: "Condominio not found" }, 404)

      // Fetch target profiles
      let query = supabase
        .from("perfil")
        .select("id, nome_completo, whatsapp, email, bloco_txt, apto_txt, papel_sistema")
        .eq("condominio_id", condominio_id)
        .not("whatsapp", "is", null)

      if (filters?.bloco) query = query.eq("bloco_txt", filters.bloco)
      if (filters?.apto) query = query.eq("apto_txt", filters.apto)
      if (filters?.role) query = query.eq("papel_sistema", filters.role)

      const { data: profiles, error: profErr } = await query
      if (profErr) return jsonResponse({ error: profErr.message }, 500)

      const totalRecipients = profiles?.length || 0
      const batchSize = condo.whatsapp_batch_size || 50
      const batchPauseMinutes = condo.whatsapp_batch_pause_minutes || 5
      const batches = Math.ceil(totalRecipients / batchSize)
      const activeSendMinutes = (totalRecipients * 4) / 60
      const pauseMinutes = batches > 1 ? (batches - 1) * batchPauseMinutes : 0
      const estimatedDurationMinutes = Math.ceil(activeSendMinutes + pauseMinutes)
      const estimatedFinishAt = new Date(Date.now() + estimatedDurationMinutes * 60000)

      // 1. Create Campaign row
      const { data: campaign, error: campErr } = await supabase
        .from("notification_campaigns")
        .insert({
          condominio_id,
          title,
          channel: channel || "whatsapp",
          message_type: message_type || "text",
          message_value,
          message_snapshot: { message_type, message_value },
          batch_size: batchSize,
          batch_pause_minutes: batchPauseMinutes,
          max_per_hour: condo.max_whatsapp_per_hour || 100,
          max_per_day: condo.max_whatsapp_per_day || 500,
          total_recipients: totalRecipients,
          pending_count: totalRecipients,
          estimated_duration_minutes: estimatedDurationMinutes,
          estimated_batches: batches,
          estimated_finish_at: estimatedFinishAt.toISOString(),
          created_by: created_by || null,
          status: "pending_approval"
        })
        .select()
        .single()

      if (campErr || !campaign) return jsonResponse({ error: campErr?.message || "Failed to create campaign" }, 500)

      // 2. Populate recipients snapshot
      if (totalRecipients > 0) {
        const recipientsPayload = profiles.map(p => ({
          campaign_id: campaign.id,
          perfil_id: p.id,
          recipient_name: p.nome_completo || "Morador",
          recipient_phone: p.whatsapp,
          recipient_email: p.email || null,
          recipient_unit: `${p.bloco_txt || ""}-${p.apto_txt || ""}`,
          recipient_role: p.papel_sistema || "morador",
          recipient_bloco: p.bloco_txt || null,
          recipient_apto: p.apto_txt || null,
          status: "pending"
        }))

        // Insert in chunks of 500 to avoid query size limits
        for (let i = 0; i < recipientsPayload.length; i += 500) {
          const chunk = recipientsPayload.slice(i, i + 500)
          const { error: insErr } = await supabase.from("notification_campaign_recipients").insert(chunk)
          if (insErr) {
            console.error("Failed to insert recipients chunk:", insErr)
          }
        }
      }

      return jsonResponse({ success: true, campaign_id: campaign.id, total_recipients: totalRecipients })
    }

    if (action === "approve") {
      const { campaign_id, approved_by, approval_reason } = body
      if (!campaign_id) return jsonResponse({ error: "campaign_id is required" }, 400)

      const { error } = await supabase
        .from("notification_campaigns")
        .update({
          status: "approved",
          approved_by: approved_by || null,
          approval_reason: approval_reason || null,
          started_at: new Date().toISOString()
        })
        .eq("id", campaign_id)

      if (error) return jsonResponse({ error: error.message }, 500)
      
      // Auto-transition to sending
      await supabase
        .from("notification_campaigns")
        .update({ status: "sending" })
        .eq("id", campaign_id)

      return jsonResponse({ success: true, message: "Campaign approved and started processing" })
    }

    if (action === "pause") {
      const { campaign_id, paused_by, pause_reason } = body
      if (!campaign_id) return jsonResponse({ error: "campaign_id is required" }, 400)

      const { error } = await supabase
        .from("notification_campaigns")
        .update({
          status: "paused",
          paused_by: paused_by || null,
          pause_reason: pause_reason || null
        })
        .eq("id", campaign_id)

      if (error) return jsonResponse({ error: error.message }, 500)
      return jsonResponse({ success: true, message: "Campaign paused" })
    }

    if (action === "resume") {
      const { campaign_id, resumed_by } = body
      if (!campaign_id) return jsonResponse({ error: "campaign_id is required" }, 400)

      const { error } = await supabase
        .from("notification_campaigns")
        .update({
          status: "sending",
          resumed_by: resumed_by || null
        })
        .eq("id", campaign_id)

      if (error) return jsonResponse({ error: error.message }, 500)
      return jsonResponse({ success: true, message: "Campaign resumed" })
    }

    if (action === "cancel") {
      const { campaign_id, cancelled_by, cancel_reason } = body
      if (!campaign_id) return jsonResponse({ error: "campaign_id is required" }, 400)

      // Update Campaign Status
      const { error } = await supabase
        .from("notification_campaigns")
        .update({
          status: "cancelled",
          cancelled_by: cancelled_by || null,
          cancel_reason: cancel_reason || null,
          completed_at: new Date().toISOString()
        })
        .eq("id", campaign_id)

      if (error) return jsonResponse({ error: error.message }, 500)

      // Update Recipients
      const { error: recErr } = await supabase
        .from("notification_campaign_recipients")
        .update({ status: "cancelled" })
        .eq("campaign_id", campaign_id)
        .in("status", ["pending", "sending"])

      if (recErr) console.error("Failed to cancel pending recipients:", recErr)

      return jsonResponse({ success: true, message: "Campaign cancelled successfully" })
    }

    return jsonResponse({ error: "Invalid action" }, 404)

  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("[CampaignManager] Unexpected error:", msg)
    return jsonResponse({ error: msg }, 500)
  }
})
