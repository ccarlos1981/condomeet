// notification-campaign-worker — Supabase Edge Function
// Processes campaign batches sequentially with concurrency protection and retry backoff

import { createClient } from "npm:@supabase/supabase-js@2"
import { smartSend } from "../_shared/botconversa.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const BOTCONVERSA_API_KEY = Deno.env.get("BOTCONVERSA_API_KEY")
  if (!BOTCONVERSA_API_KEY) {
    return new Response(JSON.stringify({ error: "BOTCONVERSA_API_KEY not configured" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }

  try {
    // 1. Fetch campaigns with status = 'sending'
    const { data: campaigns, error: campErr } = await supabase
      .from("notification_campaigns")
      .select("*")
      .eq("status", "sending")

    if (campErr) throw campErr

    console.log(`[Worker] Found ${campaigns?.length || 0} active campaigns to process.`)

    for (const camp of campaigns || []) {
      // 2. Validate batch pause settings
      if (camp.last_batch_at) {
        const lastBatch = new Date(camp.last_batch_at)
        const pauseMs = camp.batch_pause_minutes * 60 * 1000
        if (Date.now() - lastBatch.getTime() < pauseMs) {
          console.log(`[Worker] Campaign "${camp.title}" is in batch pause interval. Skipping.`)
          continue
        }
      }

      // 3. Verify hourly and daily limits for the condominium
      const oneHourAgo = new Date(Date.now() - 3600000).toISOString()
      const { data: hourlyCount, error: hErr } = await supabase.rpc("count_condo_sends_since", {
        p_condominio_id: camp.condominio_id,
        p_since: oneHourAgo
      })

      const oneDayAgo = new Date(Date.now() - 86400000).toISOString()
      const { data: dailyCount, error: dErr } = await supabase.rpc("count_condo_sends_since", {
        p_condominio_id: camp.condominio_id,
        p_since: oneDayAgo
      })

      if (hErr || dErr) {
        console.error(`[Worker] Error counting limits for campaign "${camp.title}":`, hErr || dErr)
        continue
      }

      if (hourlyCount >= camp.max_per_hour || dailyCount >= camp.max_per_day) {
        const reason = `Limite de envio excedido (Horário: ${hourlyCount}/${camp.max_per_hour}, Diário: ${dailyCount}/${camp.max_per_day})`
        console.warn(`[Worker] Campaign "${camp.title}" reached limits. Pausing.`)
        
        await supabase
          .from("notification_campaigns")
          .update({
            status: "paused",
            pause_reason: reason
          })
          .eq("id", camp.id)

        // Log limit block metric
        await supabase.from("botconversa_monitoring").insert({
          action_type: "RATE_LIMIT_BLOCK",
          recipient_phone: "system",
          perfil_id: null,
          error_message: `Campaign paused: ${reason}`,
          function_name: "campaign-worker",
          delivery_status: "EDGE_FUNCTION_SUCCESS"
        })
        continue
      }

      // 4. Claim next batch of recipients
      const remainingHourly = camp.max_per_hour - hourlyCount
      const remainingDaily = camp.max_per_day - dailyCount
      const maxClaim = Math.min(camp.batch_size, remainingHourly, remainingDaily, 30) // safe ceiling to avoid timeouts

      if (maxClaim <= 0) {
        console.log(`[Worker] No available limits headroom for campaign "${camp.title}". Skipping batch.`)
        continue
      }

      const processingToken = crypto.randomUUID()
      const { data: claimedRecipients, error: claimErr } = await supabase.rpc("claim_campaign_recipients", {
        p_campaign_id: camp.id,
        p_token: processingToken,
        p_limit: maxClaim
      })

      if (claimErr) {
        console.error(`[Worker] Claim recipients failed for campaign "${camp.title}":`, claimErr)
        continue
      }

      const countClaimed = claimedRecipients?.length || 0
      console.log(`[Worker] Claimed ${countClaimed} recipients for campaign "${camp.title}" (token=${processingToken})`)

      if (countClaimed === 0) {
        // Double check if campaign is completed
        const { data: pendingRows } = await supabase
          .from("notification_campaign_recipients")
          .select("id")
          .eq("campaign_id", camp.id)
          .in("status", ["pending", "sending"])
          .limit(1)

        if (!pendingRows || pendingRows.length === 0) {
          console.log(`[Worker] Campaign "${camp.title}" has no pending recipients left. Marking completed.`)
          await supabase
            .from("notification_campaigns")
            .update({
              status: "completed",
              completed_at: new Date().toISOString()
            })
            .eq("id", camp.id)
        }
        continue
      }

      // 5. Process claimed batch
      for (const rec of claimedRecipients || []) {
        console.log(`[Worker] Processing recipient ${rec.recipient_name} (${rec.recipient_phone})`)

        if (camp.channel === "whatsapp") {
          // Pass priority = 0 for campaigns
          const sendRes = await smartSend(
            BOTCONVERSA_API_KEY,
            null, // resolve dynamic
            rec.recipient_phone,
            camp.message_type,
            camp.message_value,
            rec.recipient_name,
            supabase,
            rec.perfil_id,
            0 // priority
          )

          if (sendRes.success) {
            await supabase
              .from("notification_campaign_recipients")
              .update({
                status: "sent",
                sent_at: new Date().toISOString(),
                processing_token: null
              })
              .eq("id", rec.id)
          } else {
            const nextRetryCount = rec.retry_count + 1
            const lastError = sendRes.reason || sendRes.error || "Unknown error"

            if (nextRetryCount <= 3) {
              // Exponential backoff: 5, 15, 45 minutes
              const backoffMinutes = nextRetryCount === 1 ? 5 : nextRetryCount === 2 ? 15 : 45
              const nextRetryAt = new Date(Date.now() + backoffMinutes * 60000).toISOString()
              
              console.warn(`[Worker] Dispatch failed to ${rec.recipient_name}. Retrying in ${backoffMinutes}m (retry_count=${nextRetryCount})`)
              await supabase
                .from("notification_campaign_recipients")
                .update({
                  status: "pending",
                  retry_count: nextRetryCount,
                  next_retry_at: nextRetryAt,
                  last_error: lastError,
                  processing_token: null
                })
                .eq("id", rec.id)
            } else {
              // Exhausted attempts, mark as dead_letter
              console.error(`[Worker] Max retries reached for ${rec.recipient_name}. Marking dead_letter.`)
              await supabase
                .from("notification_campaign_recipients")
                .update({
                  status: "dead_letter",
                  retry_count: nextRetryCount,
                  last_error: lastError,
                  processing_token: null
                })
                .eq("id", rec.id)
            }
          }
        } else {
          // Placeholder for other channels
          await supabase
            .from("notification_campaign_recipients")
            .update({
              status: "sent",
              sent_at: new Date().toISOString(),
              processing_token: null
            })
            .eq("id", rec.id)
        }
      }

      // 6. Recalculate Campaign Metrics
      const { data: stats } = await supabase
        .from("notification_campaign_recipients")
        .select("status")
        .eq("campaign_id", camp.id)
      
      let sent = 0, pending = 0, failed = 0, cancelled = 0
      for (const r of stats || []) {
        if (r.status === "sent") sent++
        else if (r.status === "pending" || r.status === "sending") pending++
        else if (r.status === "dead_letter" || r.status === "failed") failed++
        else if (r.status === "cancelled") cancelled++
      }

      await supabase
        .from("notification_campaigns")
        .update({
          sent_count: sent,
          pending_count: pending,
          failed_count: failed,
          cancelled_count: cancelled,
          last_batch_at: new Date().toISOString(),
          status: pending === 0 ? "completed" : "sending",
          completed_at: pending === 0 ? new Date().toISOString() : null
        })
        .eq("id", camp.id)

      console.log(`[Worker] Campaign "${camp.title}" stats updated. Sent: ${sent}, Pending: ${pending}, Dead Letter: ${failed}`)
    }

    return new Response(JSON.stringify({ success: true, message: "Campaign worker executed successfully" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })

  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("[CampaignWorker] Unexpected worker error:", msg)
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
