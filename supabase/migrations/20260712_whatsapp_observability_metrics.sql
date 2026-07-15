-- Migração para Métricas de Observabilidade e Custos WhatsApp Cloud API

-- 1. Tabela de parametrização de preços da Meta Cloud API
CREATE TABLE IF NOT EXISTS public.whatsapp_price_table (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL, -- 'utility', 'marketing', 'authentication', 'service'
  price numeric(10, 4) NOT NULL,
  currency text NOT NULL DEFAULT 'BRL',
  effective_from timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(category, effective_from)
);

-- Seed de preços vigentes para o Brasil
INSERT INTO public.whatsapp_price_table (category, price, currency, effective_from) VALUES
  ('utility', 0.0700, 'BRL', '2026-07-12 00:00:00-03'),
  ('marketing', 0.3000, 'BRL', '2026-07-12 00:00:00-03'),
  ('authentication', 0.0600, 'BRL', '2026-07-12 00:00:00-03'),
  ('service', 0.0000, 'BRL', '2026-07-12 00:00:00-03')
ON CONFLICT (category, effective_from) DO NOTHING;

-- 2. Tabela de controle do Gated Rollout do piloto
CREATE TABLE IF NOT EXISTS public.whatsapp_pilot_rollout (
  condominio_id uuid PRIMARY KEY REFERENCES public.condominios(id) ON DELETE CASCADE,
  current_stage text NOT NULL DEFAULT 'encomendas', -- 'encomendas' | 'visitantes' | 'reservas' | 'completo'
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Habilitar piloto inicial para o condomínio Real Park (ID correspondente)
INSERT INTO public.whatsapp_pilot_rollout (condominio_id, current_stage, is_active) VALUES
  ('ed90ec35-95f0-4a04-92b4-35fe4217f0e1', 'encomendas', true)
ON CONFLICT (condominio_id) DO UPDATE SET current_stage = 'encomendas', is_active = true;

-- 3. View para Agregação de Métricas em Tempo Real
CREATE OR REPLACE VIEW public.whatsapp_metrics_view AS
WITH prices AS (
  SELECT DISTINCT ON (category) category, price
  FROM public.whatsapp_price_table
  WHERE effective_from <= now()
  ORDER BY category, effective_from DESC
)
SELECT
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API') as meta_sent_count,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND (delivery_result->>'meta_delivery_status') IN ('delivered', 'read')) as meta_delivered_count,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND (delivery_result->>'meta_delivery_status') = 'read') as meta_read_count,
  COUNT(*) FILTER (WHERE status = 'failed' AND (delivery_result->>'provider') = 'META_CLOUD_API') as meta_failed_count,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'BOTCONVERSA') as botconversa_sent_count,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND template_name IS NULL) as meta_free_window_count,
  COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND template_name IS NOT NULL) as meta_template_count,
  
  -- Cálculo dinâmico do custo acumulado
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
FROM public.whatsapp_outbox;

-- 4. View para Contagem de Uso de cada Template
CREATE OR REPLACE VIEW public.whatsapp_template_usage_view AS
SELECT 
  template_name,
  count(*) as usage_count
FROM public.whatsapp_outbox
WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND template_name IS NOT NULL
GROUP BY template_name;
