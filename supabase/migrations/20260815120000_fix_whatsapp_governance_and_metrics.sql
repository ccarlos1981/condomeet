-- Migration: 20260815120000_fix_whatsapp_governance_and_metrics.sql
-- Description: Fix internal categorization of condomeet_documento_disponivel_v2 from marketing to utility in metrics views

CREATE OR REPLACE VIEW public.whatsapp_metrics_by_condo_view AS
WITH prices AS (
  SELECT 
    0.0000 as service,        -- User initiated (Free tier / Service)
    0.0350 as utility,        -- Utility template (BRL ~0.035)
    0.0315 as authentication, -- Auth template (BRL ~0.0315)
    0.0625 as marketing       -- Marketing template (BRL ~0.0625)
)
SELECT 
  c.id as condominio_id,
  c.nome as condominio_nome,
  COALESCE(COUNT(o.id) FILTER (WHERE o.status = 'sent'), 0) as total_sent_messages,
  COALESCE(COUNT(o.id) FILTER (WHERE o.status = 'sent' AND (o.delivery_result->>'provider') = 'META_CLOUD_API'), 0) as total_meta_messages,
  COALESCE(COUNT(o.id) FILTER (WHERE o.status = 'sent' AND (o.delivery_result->>'provider') = 'BOTCONVERSA'), 0) as total_botconversa_messages,
  
  -- Paid Meta Conversations (Templates)
  COALESCE(COUNT(o.id) FILTER (WHERE o.status = 'sent' AND (o.delivery_result->>'provider') = 'META_CLOUD_API' AND o.template_name IS NOT NULL), 0) as meta_paid_conversations,
  
  -- Free Meta Conversations (24h Window / Free Service)
  COALESCE(COUNT(o.id) FILTER (WHERE o.status = 'sent' AND (o.delivery_result->>'provider') = 'META_CLOUD_API' AND o.template_name IS NULL), 0) as meta_free_conversations,
  
  -- Estimated savings vs standard template cost
  COALESCE(
    COUNT(o.id) FILTER (WHERE o.status = 'sent' AND (o.delivery_result->>'provider') = 'META_CLOUD_API' AND o.template_name IS NULL) 
    * (SELECT utility FROM prices), 
    0
  ) as meta_savings_brl,

  -- Cost calculation: condomeet_documento_disponivel_v2 mapped to UTILITY (Operational Document Expiry Alert)
  COALESCE(SUM(
    CASE 
      WHEN (o.delivery_result->>'provider') = 'META_CLOUD_API' AND o.template_name IS NOT NULL THEN
        CASE 
          WHEN o.template_name IN ('condomeet_recuperacao_senha_v1') THEN (SELECT authentication FROM prices)
          WHEN o.template_name IN ('condomeet_documento_disponivel_v2') THEN (SELECT utility FROM prices)
          ELSE (SELECT utility FROM prices)
        END
      WHEN (o.delivery_result->>'provider') = 'META_CLOUD_API' AND o.template_name IS NULL THEN (SELECT service FROM prices)
      ELSE 0
    END
  ), 0) as meta_total_cost_brl
FROM public.condominios c
LEFT JOIN public.whatsapp_outbox o ON c.id = o.condominio_id
GROUP BY c.id, c.nome;
