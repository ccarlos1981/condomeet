-- Migração SQL V3: Padronização de Colunas e Economia da Janela de 24h

-- 1. Renomear coluna message_type existente para payload_type (tipo técnico de mídia)
ALTER TABLE public.whatsapp_outbox RENAME COLUMN message_type TO payload_type;

-- 2. Criar a nova coluna message_type para representar o tipo operacional do evento
ALTER TABLE public.whatsapp_outbox ADD COLUMN message_type text;

-- Atualizar registros antigos para compatibilidade (mensagem padrão é texto operacional geral)
UPDATE public.whatsapp_outbox SET message_type = 'TEXTO_LIVRE' WHERE message_type IS NULL;

-- 3. Atualizar a função Trigger para sincronizar as conversas usando a nova nomenclatura
CREATE OR REPLACE FUNCTION public.update_whatsapp_conversations_trigger()
RETURNS TRIGGER AS $$
DECLARE
  p_condominio_id uuid;
  p_perfil_id uuid;
  p_window_until timestamp with time zone := NULL;
  p_preview text;
BEGIN
  p_perfil_id := NEW.perfil_id;
  p_condominio_id := NEW.condominio_id;
  
  IF p_perfil_id IS NULL THEN
    SELECT id, condominio_id INTO p_perfil_id, p_condominio_id 
    FROM public.perfil 
    WHERE whatsapp = NEW.recipient_phone OR whatsapp = REPLACE(NEW.recipient_phone, '55', '')
    LIMIT 1;
  END IF;

  IF NEW.status = 'received' THEN
    p_window_until := now() + interval '24 hours';
  END IF;

  p_preview := COALESCE(NEW.message_content->>'value', 'Mensagem de mídia');

  INSERT INTO public.whatsapp_conversations (
    condominio_id,
    perfil_id,
    telefone,
    last_message_at,
    last_message_preview,
    unread_count,
    window_open_until,
    current_provider,
    status
  ) VALUES (
    p_condominio_id,
    p_perfil_id,
    NEW.recipient_phone,
    NEW.created_at,
    p_preview,
    CASE WHEN NEW.status = 'received' THEN 1 ELSE 0 END,
    p_window_until,
    COALESCE(NEW.delivery_result->>'provider', 'META_CLOUD_API'),
    'active'
  )
  ON CONFLICT (telefone) DO UPDATE SET
    condominio_id = COALESCE(NEW.condominio_id, whatsapp_conversations.condominio_id),
    perfil_id = COALESCE(NEW.perfil_id, whatsapp_conversations.perfil_id),
    last_message_at = NEW.created_at,
    last_message_preview = p_preview,
    unread_count = CASE 
      WHEN NEW.status = 'received' THEN whatsapp_conversations.unread_count + 1 
      ELSE whatsapp_conversations.unread_count 
    END,
    window_open_until = COALESCE(p_window_until, whatsapp_conversations.window_open_until),
    current_provider = COALESCE(NEW.delivery_result->>'provider', whatsapp_conversations.current_provider),
    updated_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Atualizar a view whatsapp_metrics_view para calcular a economia gerada pela janela de 24h
DROP VIEW IF EXISTS public.whatsapp_metrics_view;

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
  
  -- Latência média
  COALESCE(AVG(EXTRACT(EPOCH FROM (sent_at - created_at))) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API'), 0) as meta_avg_latency_sec,
  
  -- Conversas ativas de 24h hoje
  (SELECT COUNT(*) FROM public.whatsapp_conversations WHERE window_open_until >= now()) as active_conversations_today,
  
  -- Economia gerada pela janela de 24h (quantidade de mensagens livres x valor do template Utility que seria cobrado)
  COALESCE(
    COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API' AND template_name IS NULL) 
    * (SELECT price FROM prices WHERE category = 'utility'), 
    0
  ) as meta_savings_brl,

  -- Cálculo de custos
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
