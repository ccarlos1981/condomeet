-- Migração SQL V2: Estrutura Avançada de Conversas e Auditoria de Envio Manual

-- 1. Adicionar colunas operacionais e de auditoria manual na tabela whatsapp_outbox
ALTER TABLE public.whatsapp_outbox 
  ADD COLUMN IF NOT EXISTS operational_type text, -- 'ENCOMENDA_RECEBIDA', 'VISITANTE_AGUARDANDO', etc.
  ADD COLUMN IF NOT EXISTS manual_sent_by text, -- E-mail do administrador
  ADD COLUMN IF NOT EXISTS manual_sent_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS manual_reason text;

-- 2. Tabela de Conversas Otimizada para o Chat
CREATE TABLE IF NOT EXISTS public.whatsapp_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id uuid REFERENCES public.condominios(id) ON DELETE SET NULL,
  perfil_id uuid REFERENCES public.perfil(id) ON DELETE SET NULL,
  telefone text UNIQUE NOT NULL,
  last_message_at timestamp with time zone NOT NULL DEFAULT now(),
  last_message_preview text,
  unread_count integer NOT NULL DEFAULT 0,
  window_open_until timestamp with time zone,
  current_provider text NOT NULL DEFAULT 'META_CLOUD_API',
  status text NOT NULL DEFAULT 'active', -- 'active', 'archived'
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- 3. Função Trigger para Sincronização Automática Conversas a partir do Outbox
CREATE OR REPLACE FUNCTION public.update_whatsapp_conversations_trigger()
RETURNS TRIGGER AS $$
DECLARE
  p_condominio_id uuid;
  p_perfil_id uuid;
  p_window_until timestamp with time zone := NULL;
  p_preview text;
BEGIN
  -- Tenta resolver condomínio e perfil a partir do outbox
  p_perfil_id := NEW.perfil_id;
  p_condominio_id := NEW.condominio_id;
  
  -- Se perfil_id for nulo, tenta localizar no banco pelo número de telefone
  IF p_perfil_id IS NULL THEN
    SELECT id, condominio_id INTO p_perfil_id, p_condominio_id 
    FROM public.perfil 
    WHERE whatsapp = NEW.recipient_phone OR whatsapp = REPLACE(NEW.recipient_phone, '55', '')
    LIMIT 1;
  END IF;

  -- Se a mensagem foi recebida, a janela de 24 horas está aberta
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

-- Trigger associado à tabela whatsapp_outbox
DROP TRIGGER IF EXISTS update_whatsapp_conversations_on_outbox ON public.whatsapp_outbox;
CREATE TRIGGER update_whatsapp_conversations_on_outbox
  AFTER INSERT OR UPDATE OF status ON public.whatsapp_outbox
  FOR EACH ROW
  EXECUTE FUNCTION public.update_whatsapp_conversations_trigger();

-- 4. Atualizar a view whatsapp_metrics_view para englobar novas colunas e métricas
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
  
  -- Cálculo de latência média
  COALESCE(AVG(EXTRACT(EPOCH FROM (sent_at - created_at))) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API'), 0) as meta_avg_latency_sec,
  
  -- Quantidade de conversas abertas hoje (janela de 24h ativa)
  (SELECT COUNT(*) FROM public.whatsapp_conversations WHERE window_open_until >= now()) as active_conversations_today,
  
  -- Economia gerada acumulada (estimativa de R$ 0,08 economizado por mensagem comparado a SMS/Broker tradicional)
  COALESCE(COUNT(*) FILTER (WHERE status = 'sent' AND (delivery_result->>'provider') = 'META_CLOUD_API') * 0.0800, 0) as meta_savings_brl,

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
