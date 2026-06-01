import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const ASAAS_API_KEY = Deno.env.get("ASAAS_API_KEY") || "";
const ASAAS_URL = Deno.env.get("ASAAS_API_URL") || "https://www.asaas.com/api/v3";

serve(async (req) => {
  try {
    // 1. Signature Validation (Asaas Webhook Token)
    const webhookSecret = Deno.env.get("ASAAS_WEBHOOK_SECRET");
    const receivedToken = req.headers.get("asaas-access-token") || req.headers.get("Asaas-Access-Token");
    
    if (webhookSecret && receivedToken !== webhookSecret) {
      console.warn("Unauthorized webhook request. Token mismatch.");
      return new Response("Unauthorized", { status: 401 });
    }

    const payload = await req.json();
    console.log("Asaas Webhook Received:", payload.event);

    if (payload.event === "PAYMENT_RECEIVED" || payload.event === "PAYMENT_CONFIRMED") {
      const paymentId = payload.payment.id;
      const externalReference = payload.payment.externalReference;

      const supabaseServiceRole = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
      );

      // 2. Check if it matches financeiro_acordo_parcelas
      const { data: installment } = await supabaseServiceRole
        .from("financeiro_acordo_parcelas")
        .select("*")
        .eq("gateway_invoice_id", paymentId)
        .maybeSingle();

      if (installment) {
        if (installment.status === "pago") {
          return new Response("Already processed", { status: 200 });
        }

        // Update the installment status to pago
        const { error: updateErr } = await supabaseServiceRole
          .from("financeiro_acordo_parcelas")
          .update({
            status: "pago",
            data_pagamento: new Date().toISOString()
          })
          .eq("id", installment.id);

        if (updateErr) {
          console.error("Error updating installment status:", updateErr);
          return new Response("Error updating installment", { status: 500 });
        }

        return new Response("OK (Agreement Installment Paid)", { status: 200 });
      }

      // 2.5. Check if it matches faturamentos (condo invoice)
      const { data: faturamento } = await supabaseServiceRole
        .from("faturamentos")
        .select("id, status_pagamento")
        .eq("gateway_fatura_id", paymentId)
        .maybeSingle();

      if (faturamento) {
        if (faturamento.status_pagamento === "pago") {
          return new Response("Already processed", { status: 200 });
        }

        // Update faturamento status to pago
        const { error: updateErr } = await supabaseServiceRole
          .from("faturamentos")
          .update({
            status_pagamento: "pago",
            data_pagamento: new Date().toISOString().split('T')[0]
          })
          .eq("id", faturamento.id);

        if (updateErr) {
          console.error("Error updating faturamento status:", updateErr);
          return new Response("Error updating faturamento", { status: 500 });
        }

        // Fetch related faturamento_itens of type 'reserva'
        const { data: items } = await supabaseServiceRole
          .from("faturamento_itens")
          .select("referencia_id")
          .eq("faturamento_id", faturamento.id)
          .eq("tipo_item", "reserva");

        if (items && items.length > 0) {
          const resIds = items.map(i => i.referencia_id).filter(id => id !== null);
          if (resIds.length > 0) {
            console.log(`[Webhook] Marking ${resIds.length} reservations as paid:`, resIds);
            await supabaseServiceRole
              .from("reservas")
              .update({ status_pagamento: 'pago' })
              .in("id", resIds);
          }
        }

        return new Response("OK (Faturamento Paid and Bookings Cleared)", { status: 200 });
      }

      // 3. Fallback: Existing Garage Reservation Payment Processing
      if (!externalReference) {
        return new Response("No external reference", { status: 200 });
      }

      // Get reservation details
      const { data: reservation } = await supabaseServiceRole
        .from("garage_reservations")
        .select(`
          *,
          garages (chave_pix)
        `)
        .eq("id", externalReference)
        .single();

      if (!reservation) {
        console.error("Reservation not found for payment:", externalReference);
        return new Response("OK", { status: 200 });
      }

      if (reservation.payment_status === 'repassado') {
        return new Response("Already processed", { status: 200 });
      }

      // Mark as paid
      await supabaseServiceRole
        .from("garage_reservations")
        .update({
          payment_status: 'pago',
          status: 'confirmado'
        })
        .eq("id", externalReference);

      // PIX Payout (Transfer 85% to owner)
      const chavePix = reservation.garages?.chave_pix;
      const valorLiquido = Number(reservation.valor_liquido);

      if (chavePix && valorLiquido > 0) {
        let pixKeyType = "RANDOM";
        if (chavePix.includes("@")) pixKeyType = "EMAIL";
        else if (chavePix.length === 11 && !isNaN(Number(chavePix))) pixKeyType = "CPF";
        else if (chavePix.length === 14 && !isNaN(Number(chavePix))) pixKeyType = "CNPJ";
        else if (chavePix.startsWith("+") || (chavePix.length >= 10 && !isNaN(Number(chavePix.replace(/\D/g, ''))))) pixKeyType = "PHONE";

        const transferPayload = {
          value: valorLiquido,
          pixAddressKey: chavePix,
          pixAddressKeyType: pixKeyType,
          description: `Repasse Garagem Reserva #${externalReference.split('-')[0]}`,
        };

        const transferRes = await fetch(`${ASAAS_URL}/transfers`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "access_token": ASAAS_API_KEY,
          },
          body: JSON.stringify(transferPayload),
        });

        const transferData = await transferRes.json();
        
        if (transferData.id) {
          await supabaseServiceRole
            .from("garage_reservations")
            .update({
              payment_status: 'repassado',
              transfer_id: transferData.id,
            })
            .eq("id", externalReference);
        } else {
          console.error("Asaas Transfer Error:", transferData);
          await supabaseServiceRole
            .from("garage_reservations")
            .update({
              payment_status: 'falha_repasse',
            })
            .eq("id", externalReference);
        }
      }

      return new Response("OK (Garage Reservation Paid)", { status: 200 });
    }

    return new Response("Ignored Event", { status: 200 });
  } catch (err) {
    console.error("Webhook error:", err);
    return new Response("Error", { status: 500 });
  }
});
