import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ==========================================
// 1. DECLARATIVE LIST OF OFFICIAL TEMPLATES
// ==========================================
const OFFICIAL_TEMPLATES = [
  {
    name: "retirada_de_encomenda",
    template_family: "retirada_de_encomenda",
    template_version: 1,
    category: "UTILITY",
    language: "pt_BR",
    components: [
      {
        type: "BODY",
        text: "Olá! Aviso do Condomínio {{1}}:\n\nEncomenda retirada com sucesso!\n\n📨 Tipo: {{2}}\n\n🏢 Unidade\nBloco: {{3}} / Apto: {{4}}\n\n👤 Retirada por: {{5}}\n📅 Data/Hora: {{6}}\n\nCondomeet agradece!\nCod. interno: {{7}} (Registro do sistema)",
        example: { body_text: [["Montserrat", "caixa", "B", "301", "ENZO", "02/07/2026, 11:15", "PCF98"]] }
      }
    ]
  },
  {
    name: "condomeet_encomenda_recebida_v2",
    template_family: "encomenda_recebida",
    template_version: 2,
    category: "UTILITY",
    language: "pt_BR",
    components: [
      {
        type: "BODY",
        text: "✅ {{1}}\n\nChegou uma encomenda para o seu apartamento!\n\n📨 *Tipo de encomenda:*\n{{2}}\n\n🏢 *Unidade*\n{{3}}: {{4}} / {{5}}: {{6}}\n\n🔍 *Cod. rastreio:* {{7}}\n⏱ *Retirar até:* {{8}}\n\n🗒️ *Observação da encomenda:*\n{{9}}\n\nCondomeet agradece!",
        example: { body_text: [["Real Park", "Pacote Grande", "Bloco", "A", "Apto", "101", "BR123456789", "Amanhã", "Deixar na portaria principal"]] }
      }
    ]
  },
  {
    name: "condomeet_visitante_aguardando_v3",
    template_family: "visitante_aguardando",
    template_version: 3,
    category: "UTILITY",
    language: "pt_BR",
    components: [
      {
        type: "BODY",
        text: "🏢 {{1}}\nOlá, {{2}}!\n\nO visitante {{3}} está aguardando autorização para entrar.\n\nTipo: {{4}}\nVisita para a Data: {{5}}\n\nCódigo na portaria: 🔑 {{6}}\n\nPor favor, informe a portaria se deseja autorizar a entrada.",
        example: { body_text: [["Real Park", "João", "Maria da Silva", "Prestador de Serviço", "Hoje", "98765"]] }
      }
    ]
  },
  {
    name: "condomeet_visitante_autorizado_v1",
    template_family: "visitante_autorizado",
    template_version: 1,
    category: "UTILITY",
    language: "pt_BR",
    components: [
      {
        type: "BODY",
        text: "🏢 {{1}}\n\nOlá, {{2}}!\n\nA entrada do visitante {{3}} foi autorizada e registrada com sucesso.\n\nData/Hora da autorização: {{4}}\n\nCondomeet agradece!",
        example: { body_text: [["Real Park", "João", "Maria da Silva", "02/07/2026 11:15"]] }
      }
    ]
  },
  {
    name: "condomeet_reserva_confirmada_v2",
    template_family: "reserva_confirmada",
    template_version: 2,
    category: "UTILITY",
    language: "pt_BR",
    components: [
      {
        type: "BODY",
        text: "📆 Condomínio {{1}}\n\nOlá, {{2}}!\n\nSua reserva foi confirmada com sucesso!\n\nEspaço: {{3}}\nData do evento: {{4}}\n\nAproveite o seu evento!",
        example: { body_text: [["Real Park", "João", "Salão de Festas", "15/08/2026"]] }
      }
    ]
  },
  {
    name: "condomeet_reserva_cancelada_v2",
    template_family: "reserva_cancelada",
    template_version: 2,
    category: "UTILITY",
    language: "pt_BR",
    components: [
      {
        type: "BODY",
        text: "📆 Condomínio {{1}}\n\nOlá, {{2}}!\n\nSua reserva foi cancelada.\n\nEspaço: {{3}}\nData: {{4}}\n\nSe tiver dúvidas, entre em contato com a administração.",
        example: { body_text: [["Real Park", "João", "Salão de Festas", "15/08/2026"]] }
      }
    ]
  },
  {
    name: "condomeet_boas_vindas_v1",
    template_family: "boas_vindas",
    template_version: 1,
    category: "UTILITY",
    language: "pt_BR",
    components: [
      {
        type: "BODY",
        text: "📱 *Condomeet*\n\nOlá, *{{1}}*! 👋\n\nBem-vindo(a) ao *{{2}}*! O seu cadastro na plataforma Condomeet foi aprovado.\n\nA partir de agora, você receberá aqui no WhatsApp notificações importantes sobre:\n\n📦 Encomendas\n🚪 Visitantes\n📢 Avisos do Síndico\n📅 Reservas\n\nQualquer dúvida, conte com a gente! 😊",
        example: { body_text: [["João", "Real Park"]] }
      }
    ]
  },
  {
    name: "condomeet_recuperacao_senha_v1",
    template_family: "recuperacao_senha",
    template_version: 1,
    category: "AUTHENTICATION",
    language: "pt_BR",
    components: [
      {
        type: "BODY",
        text: "Seu código de verificação do Condomeet é {{1}}. Ele expira em 5 minutos. Por sua segurança, não compartilhe este código com ninguém.",
        example: { body_text: [["123456"]] }
      }
    ]
  }
];

// ==========================================
// 2. MAIN HANDLER
// ==========================================
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Validate SuperAdmin
    const authHeader = req.headers.get('Authorization')!;
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token);
    if (userError || !user) throw new Error('Unauthorized');
    
    const { data: saData } = await supabaseClient.from('system_superadmins').select('email').eq('email', user.email).single();
    if (!saData) throw new Error('Forbidden: SuperAdmin only');

    const { action } = await req.json();

    if (action === 'sync') {
      const result = await syncTemplates(supabaseClient, user.email!);
      return new Response(JSON.stringify(result), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    return new Response(JSON.stringify({ error: 'Invalid action' }), { status: 400, headers: corsHeaders });
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
  }
});

async function syncTemplates(supabase: any, adminEmail: string) {
  const token = Deno.env.get('WHATSAPP_ACCESS_TOKEN');
  const wabaId = Deno.env.get('WHATSAPP_BUSINESS_ACCOUNT_ID');
  if (!token || !wabaId) throw new Error("Missing Meta Credentials in Environment");

  const startTime = Date.now();
  let createdCount = 0, updatedCount = 0, rejectedCount = 0, errorCount = 0;
  const executionLog: any[] = [];
  const validationReport: any[] = []; // Integrity report

  // 1. Fetch from Meta
  let metaTemplates: any[] = [];
  try {
    const url = `https://graph.facebook.com/v20.0/${wabaId}/message_templates?limit=100`;
    const res = await fetch(url, { headers: { 'Authorization': `Bearer ${token}` } });
    const json = await res.json();
    if (json.error) throw json.error;
    metaTemplates = json.data || [];
  } catch (err: any) {
    executionLog.push({ step: 'fetch_meta', error: err.message || err });
    errorCount++;
  }

  const metaMap = new Map();
  metaTemplates.forEach(t => metaMap.set(`${t.name}_${t.language}`, t));

  // 2. Compare, Create Missing & Validate Integrity
  for (const official of OFFICIAL_TEMPLATES) {
    const key = `${official.name}_${official.language}`;
    let metaTpl = metaMap.get(key);

    let classification = '✗ Ausente';

    if (!metaTpl) {
      // Create it
      try {
        const payload = {
          name: official.name,
          category: official.category,
          language: official.language,
          components: official.components
        };
        const res = await fetch(`https://graph.facebook.com/v20.0/${wabaId}/message_templates`, {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const json = await res.json();
        if (json.error) {
          executionLog.push({ action: 'create', template: official.name, error: json.error });
          errorCount++;
        } else {
          createdCount++;
          metaTpl = { id: json.id, name: official.name, language: official.language, status: 'PENDING', category: official.category };
          metaMap.set(key, metaTpl);
          classification = '✓ Sincronizado (Criado Agora)';
        }
      } catch (err: any) {
        executionLog.push({ action: 'create', template: official.name, error: err.message });
        errorCount++;
      }
    } else {
      // Check for divergence (simplified check: category mismatch or language mismatch)
      if (metaTpl.category !== official.category) {
        classification = '⚠ Divergente';
      } else {
        classification = '✓ Sincronizado';
      }
    }

    validationReport.push({
      family: official.template_family,
      name: official.name,
      status: classification,
      meta_status: metaTpl?.status || 'N/A'
    });
  }

  executionLog.push({ step: 'integrity_validation', report: validationReport });

  // 3. Upsert to Local Database (with meta_template_id Divergence Guard)
  for (const official of OFFICIAL_TEMPLATES) {
    const key = `${official.name}_${official.language}`;
    const metaTpl = metaMap.get(key);
    
    if (metaTpl) {
      // Query existing local record for divergence validation
      const { data: existingRow } = await supabase
        .from('whatsapp_meta_templates')
        .select('meta_template_id, status')
        .eq('name', official.name)
        .eq('language', official.language || 'pt_BR')
        .maybeSingle();

      // Divergence Check: If existing meta_template_id is present and differs from Meta API ID
      if (existingRow?.meta_template_id && existingRow.meta_template_id !== metaTpl.id) {
        const divError = `Divergência de meta_template_id para '${official.name}': local=${existingRow.meta_template_id}, Meta=${metaTpl.id}`;
        console.error(JSON.stringify({
          event: "TEMPLATE_ID_DIVERGENCE_DETECTED",
          template_name: official.name,
          existing_meta_template_id: existingRow.meta_template_id,
          received_meta_template_id: metaTpl.id,
          error: divError
        }));

        executionLog.push({
          action: 'sync_blocked_divergence',
          template: official.name,
          error: divError
        });

        errorCount++;
        continue; // Block automatic sync until administrative validation
      }

      if (metaTpl.status === 'REJECTED') rejectedCount++;
      updatedCount++;

      await supabase.from('whatsapp_meta_templates').upsert({
        meta_template_id: metaTpl.id,
        name: official.name,
        template_family: official.template_family,
        template_version: official.template_version,
        category: metaTpl.category || official.category,
        language: metaTpl.language || official.language,
        channel: 'whatsapp',
        tenant: 'default',
        status: metaTpl.status,
        quality_score: metaTpl.quality_score?.score || null,
        rejected_reason: metaTpl.rejected_reason || null,
        definition_payload: official.components,
        meta_payload: metaTpl,
        last_synced_at: new Date().toISOString()
      }, { onConflict: 'name,language,channel,tenant' });
    }
  }

  const durationMs = Date.now() - startTime;

  // 4. Log sync
  await supabase.from('whatsapp_template_sync_logs').insert({
    executed_by: adminEmail,
    created_count: createdCount,
    updated_count: updatedCount,
    rejected_count: rejectedCount,
    error_count: errorCount,
    duration_ms: durationMs,
    execution_log: executionLog
  });

  return { createdCount, updatedCount, rejectedCount, errorCount, durationMs, validationReport };
}

