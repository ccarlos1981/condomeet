import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// ── Dynamic structure labels ────────────────────────────────────────────────
function getBlocoLabel(tipo?: string): string {
  if (tipo === 'casa_quadra') return 'Quadra'
  if (tipo === 'casa_rua') return 'Rua'
  return 'Bloco'
}
function getAptoLabel(tipo?: string): string {
  if (tipo === 'casa_quadra') return 'Lote'
  if (tipo === 'casa_rua') return 'Número'
  return 'Apto'
}

serve(async (req) => {
  try {
    const { parcel_id, event, condominio_id, bloco, apto, tipo, picked_up_by_name } = await req.json()

    // Aceitar apenas eventos conhecidos: 'arrived' e 'delivered'
    if (event !== 'arrived' && event !== 'delivered') {
      return new Response(JSON.stringify({ skipped: true, reason: `Evento '${event}' ignorado para WhatsApp` }), { status: 200 })
    }

    // 1. Inicializar Supabase Admin
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const BOTCONVERSA_API_KEY = Deno.env.get('BOTCONVERSA_API_KEY')

    if (!BOTCONVERSA_API_KEY) {
      return new Response(JSON.stringify({ error: "BOTCONVERSA_API_KEY não configurada" }), { status: 400 })
    }

    let condoNome = "Condomínio";
    let tipoEstrutura = 'predio';
    if (condominio_id) {
      const { data: condo } = await supabaseAdmin.from('condominios').select('nome, tipo_estrutura').eq('id', condominio_id).single();
      if (condo) {
        condoNome = condo.nome;
        tipoEstrutura = condo.tipo_estrutura || 'predio';
      }
    }
    const blocoLabel = getBlocoLabel(tipoEstrutura);
    const aptoLabel = getAptoLabel(tipoEstrutura);

    let parcelData: any = null;
    if (parcel_id) {
      const { data: enc } = await supabaseAdmin.from('encomendas').select('*').eq('id', parcel_id).single();
      parcelData = enc;
    }

    let profilesToNotify: any[] = [];

    if (condominio_id && bloco && apto) {
      // 2. Buscar todos os moradores da unidade no schema 'perfil'
      const { data: profiles, error } = await supabaseAdmin
        .from('perfil')
        .select('id, nome_completo, fcm_token, botconversa_id')
        .eq('condominio_id', condominio_id)
        .eq('bloco_txt', bloco)
        .eq('apto_txt', apto)
        .eq('status_aprovacao', 'aprovado')
        .eq('bloqueado', false)
        .not('botconversa_id', 'is', null)

      if (!error && profiles) {
        profilesToNotify = profiles;
      }
    }

    if (profilesToNotify.length === 0) {
      return new Response(JSON.stringify({ error: "Nenhum contato encontrado para notificação" }), { status: 400 })
    }

    console.log(`[${event}] Sending parcel WhatsApp to ${profilesToNotify.length} resident(s) of unit ${bloco} / ${apto}`)

    const { sendMessage } = await import("../_shared/botconversa.ts")

    const sendPromises = profilesToNotify.map(async (profile: any) => {
      try {
        // Gerar código interno para anti-ban
        const codInterno = Math.random().toString(36).substring(2, 7).toUpperCase();

        let txtMsg: string;

        if (event === 'arrived') {
          // ── Mensagem de CHEGADA ──
          const createdDate = parcelData?.created_at ? new Date(parcelData.created_at) : new Date();
          createdDate.setDate(createdDate.getDate() + 7);
          // Format in Brazil timezone (Deno edge runtime runs in UTC)
          const withdrawUntil = createdDate.toLocaleDateString('pt-BR', {
            timeZone: 'America/Sao_Paulo',
            day: '2-digit', month: '2-digit', year: 'numeric',
          });

          const observationText = parcelData?.observacao?.trim() || parcelData?.notes?.trim() || 'Nenhuma';
          const trackingCode = parcelData?.tracking_code?.trim() || 'Nenhum';

          txtMsg = `📦 ${condoNome}

Chegou uma encomenda para o seu apartamento.

📨 Tipo de encomenda:
${tipo || 'Pacote'}

🏢 Unidade
${blocoLabel}: ${bloco} / ${aptoLabel}: ${apto}

🔍 Cod. rastreio: ${trackingCode}

⏱ Retirar até: ${withdrawUntil}

🗒️ Observação da encomenda:
${observationText}

Condomeet agradece!
Cod. interno: ${codInterno}`;
        } else {
          // ── Mensagem de ENTREGA ──
          const deliveryTime = parcelData?.delivery_time
            ? new Date(parcelData.delivery_time)
            : new Date();
          // Format in Brazil timezone (Deno edge runtime runs in UTC)
          const deliveryStr = deliveryTime.toLocaleString('pt-BR', {
            timeZone: 'America/Sao_Paulo',
            day: '2-digit', month: '2-digit', year: 'numeric',
            hour: '2-digit', minute: '2-digit',
          });

          const whoPickedUp = picked_up_by_name?.trim() || 'Morador';

          txtMsg = `✅ ${condoNome}

Encomenda retirada com sucesso!

📨 Tipo: ${tipo || 'Pacote'}

🏢 Unidade
${blocoLabel}: ${bloco} / ${aptoLabel}: ${apto}

👤 Retirada por: ${whoPickedUp}
📅 Data/Hora: ${deliveryStr}

Condomeet agradece!
Cod. interno: ${codInterno}`;
        }

        const result1 = await sendMessage(BOTCONVERSA_API_KEY as string, profile.botconversa_id, "text", txtMsg);
        
        // Enviar foto SOMENTE no evento 'arrived', com delay random (10-20s)
        if (event === 'arrived' && result1.success && parcelData?.photo_url) {
          const delayMs = Math.floor(Math.random() * (20000 - 10000 + 1) + 10000);
          await new Promise(res => setTimeout(res, delayMs));
          await sendMessage(BOTCONVERSA_API_KEY as string, profile.botconversa_id, "file", parcelData.photo_url);
        }

        return result1;
      } catch (err: any) {
        return { success: false, error: err.message, subscriberId: profile.botconversa_id };
      }
    });

    const results = await Promise.all(sendPromises);
    const hasSuccess = results.some((r: any) => r.success);

    return new Response(JSON.stringify({
      event,
      messages_sent: results.length,
      success: hasSuccess,
      results
    }), {
      status: hasSuccess ? 200 : 500,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
