-- =================================================================
-- Migration: 20260713_whatsapp_consumption_dashboard
-- Objective: Setup read-only views and stored function (RPC) for
--            WhatsApp Cloud API consumption dashboard per condominium.
-- =================================================================

-- 1. View for metrics aggregated by condominio_id
CREATE OR REPLACE VIEW public.whatsapp_metrics_by_condo_view AS
WITH prices AS (
  SELECT DISTINCT ON (category) category, price
  FROM public.whatsapp_price_table
  WHERE effective_from <= now()
  ORDER BY category, effective_from DESC
)
SELECT
  condominio_id,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API') as meta_sent_count,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND (delivery_result->>'meta_delivery_status') IN ('delivered', 'read')) as meta_delivered_count,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND (delivery_result->>'meta_delivery_status') = 'read') as meta_read_count,
  COUNT(*) FILTER (WHERE status = 'failed' AND (delivery_result->>'provider') = 'META_CLOUD_API') as meta_failed_count,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'BOTCONVERSA') as botconversa_sent_count,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND template_name IS NULL) as meta_free_window_count,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND template_name IS NOT NULL) as meta_template_count,
  
  -- Latency
  COALESCE(AVG(EXTRACT(EPOCH FROM (sent_at - created_at))) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API'), 0) as meta_avg_latency_sec,
  
  -- Conversations active today (within 24h window)
  (SELECT COUNT(*) FROM public.whatsapp_conversations wc WHERE wc.window_open_until >= now() AND wc.condominio_id = o.condominio_id) as active_conversations_today,
  
  -- Estimated savings
  COALESCE(
    COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND template_name IS NULL) 
    * (SELECT price FROM prices WHERE category = 'utility'), 
    0
  ) as meta_savings_brl,

  -- Cost
  COALESCE(SUM(
    CASE 
      WHEN (delivery_result->>'provider') = 'META_CLOUD_API' AND template_name IS NOT NULL THEN
        CASE 
          WHEN template_name IN ('condomeet_recuperacao_senha_v1') THEN (SELECT price FROM prices WHERE category = 'authentication')
          WHEN template_name IN ('condomeet_documento_disponivel_v2') THEN (SELECT price FROM prices WHERE category = 'marketing')
          ELSE (SELECT price FROM prices WHERE category = 'utility')
        END
      WHEN (delivery_result->>'provider') = 'META_CLOUD_API' AND template_name IS NULL THEN (SELECT price FROM prices WHERE category = 'service')
      ELSE 0
    END
  ), 0) as meta_total_cost_brl
FROM public.whatsapp_outbox o
GROUP BY condominio_id;

-- 2. View for template usage count grouped by condominio_id
CREATE OR REPLACE VIEW public.whatsapp_template_usage_by_condo_view AS
SELECT 
  condominio_id,
  template_name,
  count(*) as usage_count
FROM public.whatsapp_outbox
WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND template_name IS NOT NULL
GROUP BY condominio_id, template_name;

-- 3. Stored function (RPC) to retrieve consumption stats per condominium
CREATE OR REPLACE FUNCTION public.get_whatsapp_consumption_by_condo(
  p_condominio_id uuid DEFAULT NULL
)
RETURNS TABLE (
  condominio_id uuid,
  condominio_nome text,
  gasto_hoje numeric,
  gasto_7d numeric,
  gasto_30d numeric,
  mensagens_enviadas bigint,
  conversas_pagas bigint,
  conversas_gratuitas bigint,
  participacao_percentual numeric,
  total_unidades bigint,
  custo_por_unidade numeric
) AS $$
DECLARE
  v_price_utility numeric;
  v_price_marketing numeric;
  v_price_auth numeric;
  v_price_service numeric;
  v_today timestamptz;
  v_week timestamptz;
  v_month timestamptz;
BEGIN
  -- Get active prices
  SELECT price INTO v_price_utility FROM public.whatsapp_price_table WHERE category = 'utility' AND effective_from <= now() ORDER BY effective_from DESC LIMIT 1;
  SELECT price INTO v_price_marketing FROM public.whatsapp_price_table WHERE category = 'marketing' AND effective_from <= now() ORDER BY effective_from DESC LIMIT 1;
  SELECT price INTO v_price_auth FROM public.whatsapp_price_table WHERE category = 'authentication' AND effective_from <= now() ORDER BY effective_from DESC LIMIT 1;
  SELECT price INTO v_price_service FROM public.whatsapp_price_table WHERE category = 'service' AND effective_from <= now() ORDER BY effective_from DESC LIMIT 1;

  -- Fallbacks if not set
  v_price_utility := COALESCE(v_price_utility, 0.0700);
  v_price_marketing := COALESCE(v_price_marketing, 0.3000);
  v_price_auth := COALESCE(v_price_auth, 0.0600);
  v_price_service := COALESCE(v_price_service, 0.0000);

  -- Set timezone aware timestamps matching client local behavior (America/Sao_Paulo)
  v_today := date_trunc('day', now() AT TIME ZONE 'America/Sao_Paulo') AT TIME ZONE 'America/Sao_Paulo';
  v_week := now() - interval '7 days';
  v_month := now() - interval '30 days';

  RETURN QUERY
  WITH raw_data AS (
    SELECT 
      o.condominio_id as raw_condo_id,
      o.sent_at,
      CASE 
        WHEN (o.delivery_result->>'provider') = 'META_CLOUD_API' AND o.template_name IS NOT NULL THEN
          CASE 
            WHEN o.template_name IN ('condomeet_recuperacao_senha_v1') THEN v_price_auth
            WHEN o.template_name IN ('condomeet_documento_disponivel_v2') THEN v_price_marketing
            ELSE v_price_utility
          END
        WHEN (o.delivery_result->>'provider') = 'META_CLOUD_API' AND o.template_name IS NULL THEN v_price_service
        ELSE 0
      END as cost,
      CASE WHEN (o.delivery_result->>'provider') = 'META_CLOUD_API' AND o.template_name IS NOT NULL THEN 1 ELSE 0 END as is_paid,
      CASE WHEN (o.delivery_result->>'provider') = 'META_CLOUD_API' AND o.template_name IS NULL THEN 1 ELSE 0 END as is_free,
      CASE WHEN (o.delivery_result->>'provider') = 'META_CLOUD_API' THEN 1 ELSE 0 END as is_sent
    FROM public.whatsapp_outbox o
    WHERE o.status = 'sent' 
      AND (o.delivery_result->>'provider') = 'META_CLOUD_API'
  ),
  global_totals AS (
    SELECT COALESCE(SUM(cost), 0) as total_month_cost_all
    FROM raw_data
    WHERE sent_at >= v_month
  ),
  aggregated AS (
    SELECT 
      c.id as condo_id,
      COALESCE(c.nome, 'Sem Condomínio') as condo_nome,
      COALESCE(SUM(r.cost) FILTER (WHERE r.sent_at >= v_today), 0)::numeric as today_cost,
      COALESCE(SUM(r.cost) FILTER (WHERE r.sent_at >= v_week), 0)::numeric as week_cost,
      COALESCE(SUM(r.cost) FILTER (WHERE r.sent_at >= v_month), 0)::numeric as month_cost,
      COALESCE(SUM(r.is_sent) FILTER (WHERE r.sent_at >= v_month), 0)::bigint as total_sent_30d,
      COALESCE(SUM(r.is_paid) FILTER (WHERE r.sent_at >= v_month), 0)::bigint as total_paid_30d,
      COALESCE(SUM(r.is_free) FILTER (WHERE r.sent_at >= v_month), 0)::bigint as total_free_30d,
      COALESCE((SELECT COUNT(*) FROM public.apartamentos ap WHERE ap.condominio_id = c.id), 0)::bigint as units_count
    FROM public.condominios c
    LEFT JOIN raw_data r ON r.raw_condo_id = c.id
    WHERE (p_condominio_id IS NULL OR c.id = p_condominio_id)
    GROUP BY c.id, c.nome
  )
  SELECT 
    a.condo_id,
    a.condo_nome::text,
    a.today_cost,
    a.week_cost,
    a.month_cost,
    a.total_sent_30d,
    a.total_paid_30d,
    a.total_free_30d,
    CASE 
      WHEN g.total_month_cost_all > 0 THEN ROUND((a.month_cost / g.total_month_cost_all * 100)::numeric, 2)
      ELSE 0::numeric
    END as part_pct,
    a.units_count,
    CASE 
      WHEN a.units_count > 0 THEN ROUND((a.month_cost / a.units_count)::numeric, 2)
      ELSE 0::numeric
    END as cost_per_unit
  FROM aggregated a
  CROSS JOIN global_totals g
  ORDER BY a.month_cost DESC, a.week_cost DESC, a.today_cost DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
