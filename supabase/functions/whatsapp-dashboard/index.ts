import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  try {
    // 1. Parallel loading of runtime config, health, views and prices
    const [
      runtimeRes,
      leaseRes,
      providerRes,
      healthRes,
      metricsRes,
      templateUsageRes,
      pilotRes,
      pricesRes,
      logsRes
    ] = await Promise.all([
      supabase.from("whatsapp_runtime").select("*").eq("id", "singleton").single(),
      supabase.from("worker_leases").select("*").eq("id", "singleton").single(),
      supabase.from("message_provider_runtime").select("*").eq("id", "singleton").single(),
      supabase.from("whatsapp_health_status").select("*").eq("id", "singleton").single(),
      supabase.from("whatsapp_metrics_view").select("*").single(),
      supabase.from("whatsapp_template_usage_view").select("*").order("usage_count", { ascending: false }),
      supabase.from("whatsapp_pilot_rollout").select("condominio_id, current_stage, is_active, condominios(nome)").eq("is_active", true).maybeSingle(),
      supabase.from("whatsapp_price_table").select("*").order("effective_from", { ascending: false }),
      supabase.from("botconversa_monitoring").select("*").order("timestamp", { ascending: false }).limit(15)
    ])

    const runtime = runtimeRes.data || {}
    const lease = leaseRes.data || {}
    const provider = providerRes.data || { active_provider: "BOTCONVERSA", automatic_failover_enabled: false }
    const health = healthRes.data || {}
    const metrics = metricsRes.data || {
      meta_sent_count: 0,
      meta_delivered_count: 0,
      meta_read_count: 0,
      meta_failed_count: 0,
      botconversa_sent_count: 0,
      meta_free_window_count: 0,
      meta_template_count: 0,
      meta_avg_latency_sec: 0,
      meta_total_cost_brl: 0
    }
    const templateUsage = templateUsageRes.data || []
    const pilot = pilotRes.data || null
    const pricesList = pricesRes.data || []

    // 2. Calculations
    const metaSent = Number(metrics.meta_sent_count) || 0
    const metaDelivered = Number(metrics.meta_delivered_count) || 0
    const metaRead = Number(metrics.meta_read_count) || 0
    const metaFailed = Number(metrics.meta_failed_count) || 0
    const bcSent = Number(metrics.botconversa_sent_count) || 0
    
    const deliveryRate = metaSent > 0 ? (metaDelivered / metaSent) * 100 : 0
    const readRate = metaSent > 0 ? (metaRead / metaSent) * 100 : 0
    const windowPercent = metaSent > 0 ? (Number(metrics.meta_free_window_count) / metaSent) * 100 : 0
    
    // Heartbeat Age calculation
    let heartbeatAge = "N/A"
    if (lease.last_heartbeat) {
      const diffSec = Math.round((Date.now() - new Date(lease.last_heartbeat).getTime()) / 1000)
      heartbeatAge = `${diffSec}s`
    }

    // Pilot KPIs validations
    const kpiDeliveryOk = metaSent === 0 || deliveryRate >= 98
    const kpiLatencyOk = Number(metrics.meta_avg_latency_sec) < 3
    const kpiFailoverOk = bcSent === 0
    const pilotPassGated = kpiDeliveryOk && kpiLatencyOk && kpiFailoverOk

    const html = `
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta http-equiv="refresh" content="10">
        <title>Painel de Observabilidade - Condomeet</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
        <style>
            body {
                font-family: 'Outfit', sans-serif;
                background-color: #08090c;
                color: #f1f5f9;
            }
            .glass {
                background: rgba(17, 24, 39, 0.6);
                backdrop-filter: blur(16px);
                border: 1px rgba(255, 255, 255, 0.04) solid;
            }
            .gradient-border {
                border: 1px transparent solid;
                background-image: linear-gradient(#111827, #111827), linear-gradient(135deg, #6366f1, #3b82f6);
                background-origin: border-box;
                background-clip: padding-box, border-box;
            }
            .glow-indigo {
                box-shadow: 0 0 25px rgba(99, 102, 241, 0.15);
            }
        </style>
    </head>
    <body class="min-h-screen p-4 md:p-8">
        <div class="max-w-7xl mx-auto space-y-8">
            
            <!-- HEADER -->
            <header class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 pb-6 border-b border-white/5">
                <div>
                    <span class="text-xs font-semibold tracking-wider text-indigo-400 uppercase">Observabilidade e Custos em Tempo Real</span>
                    <h1 class="text-3xl font-extrabold tracking-tight text-white mt-1">Mensageria Condomeet Dashboard</h1>
                </div>
                <div class="flex items-center gap-3 bg-white/5 px-4 py-2 rounded-full border border-white/5">
                    <span class="relative flex h-2 w-2">
                        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                        <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                    </span>
                    <span class="text-xs font-mono text-slate-400">Autorefresh a cada 10s</span>
                </div>
            </header>

            <!-- PILOT STATUS (GATED ROLLOUT) -->
            ${pilot ? `
            <section class="glass rounded-3xl p-6 border-indigo-500/20 glow-indigo relative overflow-hidden">
                <div class="absolute -right-10 -top-10 w-40 h-40 bg-indigo-500/10 rounded-full blur-3xl"></div>
                <div class="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-6">
                    <div>
                        <div class="flex items-center gap-2">
                            <span class="text-xs px-2.5 py-1 rounded-full bg-indigo-500/20 text-indigo-300 font-semibold uppercase tracking-wider">Piloto Ativo</span>
                            <span class="text-xs px-2.5 py-1 rounded-full bg-white/5 text-slate-300 border border-white/5 font-semibold">Gated Rollout</span>
                        </div>
                        <h2 class="text-2xl font-extrabold text-white mt-2">Condomínio: ${pilot.condominios?.nome || "Real Park"}</h2>
                        <p class="text-sm text-slate-400 mt-1">Estágio de liberação atual: <span class="font-bold text-indigo-300 uppercase">${pilot.current_stage}</span></p>
                    </div>
                    
                    <!-- KPI Checkers -->
                    <div class="flex flex-wrap gap-4 w-full lg:w-auto">
                        <div class="flex items-center gap-3 bg-white/5 px-4 py-3 rounded-2xl border border-white/5">
                            <div class="h-2 w-2 rounded-full ${kpiDeliveryOk ? "bg-emerald-400" : "bg-red-400"}"></div>
                            <div>
                                <div class="text-xs text-slate-400 font-medium">Delivery Rate</div>
                                <div class="text-sm font-bold text-white">${deliveryRate.toFixed(1)}% <span class="text-xs font-normal text-slate-400">(>= 98%)</span></div>
                            </div>
                        </div>
                        <div class="flex items-center gap-3 bg-white/5 px-4 py-3 rounded-2xl border border-white/5">
                            <div class="h-2 w-2 rounded-full ${kpiLatencyOk ? "bg-emerald-400" : "bg-red-400"}"></div>
                            <div>
                                <div class="text-xs text-slate-400 font-medium">Latência Média</div>
                                <div class="text-sm font-bold text-white">${Number(metrics.meta_avg_latency_sec).toFixed(2)}s <span class="text-xs font-normal text-slate-400">(< 3s)</span></div>
                            </div>
                        </div>
                        <div class="flex items-center gap-3 bg-white/5 px-4 py-3 rounded-2xl border border-white/5">
                            <div class="h-2 w-2 rounded-full ${kpiFailoverOk ? "bg-emerald-400" : "bg-red-400"}"></div>
                            <div>
                                <div class="text-xs text-slate-400 font-medium">Failovers</div>
                                <div class="text-sm font-bold text-white">${bcSent} <span class="text-xs font-normal text-slate-400">(= 0)</span></div>
                            </div>
                        </div>
                        
                        <div class="flex items-center justify-center bg-indigo-500/10 px-5 py-3 rounded-2xl border border-indigo-500/20 ml-auto lg:ml-0">
                            <span class="text-sm font-bold ${pilotPassGated ? "text-emerald-400" : "text-yellow-400"}">
                                ${pilotPassGated ? "✅ Pronto para Próximo Estágio" : "⏳ Pendente de Tráfego/Ajuste"}
                            </span>
                        </div>
                    </div>
                </div>
            </section>
            ` : ""}

            <!-- MAIN METRICS CARDS -->
            <section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                
                <!-- Card: Taxa de Entrega (Delivery Rate) -->
                <div class="glass rounded-3xl p-6 flex flex-col justify-between">
                    <div>
                        <span class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Meta Delivery Rate</span>
                        <div class="text-3xl font-extrabold text-white mt-3">${deliveryRate.toFixed(1)}%</div>
                    </div>
                    <div class="text-xs text-slate-400 mt-4 border-t border-white/5 pt-2">
                        Entregues: <span class="text-emerald-400 font-bold">${metaDelivered}</span> | Enviados: <span class="font-bold">${metaSent}</span>
                    </div>
                </div>

                <!-- Card: Taxa de Leitura (Read Rate) -->
                <div class="glass rounded-3xl p-6 flex flex-col justify-between">
                    <div>
                        <span class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Meta Read Rate</span>
                        <div class="text-3xl font-extrabold text-indigo-400 mt-3">${readRate.toFixed(1)}%</div>
                    </div>
                    <div class="text-xs text-slate-400 mt-4 border-t border-white/5 pt-2">
                        Lidos: <span class="text-indigo-400 font-bold">${metaRead}</span> | Entregues: <span class="font-bold">${metaDelivered}</span>
                    </div>
                </div>

                <!-- Card: Janela de 24h (Texto Livre) -->
                <div class="glass rounded-3xl p-6 flex flex-col justify-between">
                    <div>
                        <span class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Janela de 24h Aberta</span>
                        <div class="text-3xl font-extrabold text-emerald-400 mt-3">${windowPercent.toFixed(1)}%</div>
                    </div>
                    <div class="text-xs text-slate-400 mt-4 border-t border-white/5 pt-2">
                        Texto Livre: <span class="text-emerald-400 font-bold">${metrics.meta_free_window_count}</span> | Templates: <span class="font-bold">${metrics.meta_template_count}</span>
                    </div>
                </div>

                <!-- Card: Custos Acumulados Meta (Dinâmico) -->
                <div class="glass rounded-3xl p-6 flex flex-col justify-between">
                    <div>
                        <span class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Custos Estimados Meta</span>
                        <div class="text-3xl font-extrabold text-amber-400 mt-3">R$ ${Number(metrics.meta_total_cost_brl).toFixed(2)}</div>
                    </div>
                    <div class="text-xs text-slate-400 mt-4 border-t border-white/5 pt-2">
                        Cobrança dinâmica por categoria Meta
                    </div>
                </div>

            </section>

            <!-- SUBMETRICAS E TEMPLATES -->
            <section class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                
                <!-- Utilização de Templates -->
                <div class="glass rounded-3xl p-6 lg:col-span-2 space-y-6">
                    <h3 class="text-lg font-bold text-white">Frequência e Utilização de Templates Meta</h3>
                    <div class="space-y-4">
                        ${templateUsage.map(t => {
                            const percent = metaSent > 0 ? (Number(t.usage_count) / metaSent) * 100 : 0
                            return `
                            <div class="space-y-1">
                                <div class="flex justify-between text-xs font-medium">
                                    <span class="font-mono text-indigo-300 font-semibold">${t.template_name}</span>
                                    <span>${t.usage_count} disparos (${percent.toFixed(1)}%)</span>
                                </div>
                                <div class="w-full bg-white/5 rounded-full h-2">
                                    <div class="bg-indigo-500 h-2 rounded-full" style="width: ${percent}%"></div>
                                </div>
                            </div>
                            `
                        }).join('')}
                        ${templateUsage.length === 0 ? `
                            <div class="text-sm text-slate-500 text-center py-6">Nenhum template disparado até o momento.</div>
                        ` : ''}
                    </div>
                </div>

                <!-- Parametrização de Preços (Sem Deploy) -->
                <div class="glass rounded-3xl p-6 space-y-4">
                    <h3 class="text-lg font-bold text-white">Tabela de Preços Meta (BRL)</h3>
                    <div class="divide-y divide-white/5">
                        ${pricesList.map(p => `
                        <div class="flex justify-between items-center py-2 text-sm">
                            <span class="capitalize text-slate-300 font-medium">${p.category}</span>
                            <span class="font-mono font-bold text-amber-400">R$ ${Number(p.price).toFixed(4)}</span>
                        </div>
                        `).join('')}
                        ${pricesList.length === 0 ? `
                            <div class="text-xs text-slate-500 text-center py-4">Nenhum preço parametrizado no banco.</div>
                        ` : ''}
                    </div>
                    <div class="bg-amber-950/20 border border-amber-500/10 rounded-xl p-3 text-xs text-amber-200/70">
                        Preços carregados dinamicamente via tabela de banco. Permite reajustes sem necessidade de deploy.
                    </div>
                </div>

            </section>

            <!-- TELEMETRIA LOGS -->
            <section class="glass rounded-3xl p-6">
                <h3 class="text-lg font-bold text-white mb-4">Últimos Logs de Eventos e Webhooks</h3>
                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm">
                        <thead class="bg-white/5 text-slate-300 font-semibold">
                            <tr>
                                <th class="p-3 rounded-l-lg">Horário</th>
                                <th class="p-3">Ação</th>
                                <th class="p-3">Destinatário</th>
                                <th class="p-3">Função</th>
                                <th class="p-3 rounded-r-lg">Detalhes / Eventos</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-white/5 text-slate-400">
                            ${(logsRes.data || []).map(log => `
                                <tr class="hover:bg-white/[0.02]">
                                    <td class="p-3 whitespace-nowrap font-mono text-xs">
                                        ${new Date(log.timestamp).toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo" })}
                                    </td>
                                    <td class="p-3 whitespace-nowrap font-bold">
                                        <span class="text-xs px-2.5 py-0.5 rounded font-mono ${
                                            log.action_type.includes("PAUSED") || log.action_type.includes("OFFLINE")
                                            ? "bg-red-500/10 text-red-400"
                                            : log.action_type.includes("RESUMED") || log.action_type.includes("RECONNECTED")
                                            ? "bg-emerald-500/10 text-emerald-400"
                                            : "bg-indigo-500/10 text-indigo-400"
                                        }">
                                            ${log.action_type}
                                        </span>
                                    </td>
                                    <td class="p-3 whitespace-nowrap font-mono text-xs">${log.recipient_phone || "-"}</td>
                                    <td class="p-3 whitespace-nowrap">${log.function_name || "-"}</td>
                                    <td class="p-3 truncate max-w-xs font-mono text-xs" title="${log.error_message || ""}">
                                        ${log.error_message || "-"}
                                    </td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                </div>
            </section>

        </div>
    </body>
    </html>
    `

    return new Response(html, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "text/html; charset=utf-8",
      },
    })
  } catch (err: any) {
    const errorMsg = err.message || String(err)
    return new Response(`Erro ao renderizar dashboard: ${errorMsg}`, {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
    })
  }
})
