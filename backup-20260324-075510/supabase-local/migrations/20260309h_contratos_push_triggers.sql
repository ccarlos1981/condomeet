-- ============================================================
-- Migration: 20260309h — Trigger push ao inserir/atualizar contrato
-- com avisar_moradores = true
-- ============================================================

-- Helper: chama a Edge Function contratos-push-notify via pg_net
CREATE OR REPLACE FUNCTION public.push_notify_contrato(
  p_contrato_id   UUID,
  p_condominio_id UUID,
  p_titulo        TEXT,
  p_tipo_evento   TEXT DEFAULT 'novo_contrato'
)
RETURNS VOID AS $$
DECLARE
  v_supa_url TEXT;
  v_svc_key  TEXT;
  payload    JSONB;
BEGIN
  v_supa_url := COALESCE(
    current_setting('app.settings.supabase_url', true),
    'https://avypyaxthvgaybplnwxu.supabase.co'
  );
  v_svc_key := current_setting('app.settings.service_role_key', true);

  IF v_svc_key IS NULL OR v_svc_key = '' THEN
    RAISE WARNING 'push_notify_contrato: service_role_key não configurado. Pulando notificação.';
    RETURN;
  END IF;

  payload := jsonb_build_object(
    'contrato_id',   p_contrato_id,
    'condominio_id', p_condominio_id,
    'titulo',        p_titulo,
    'tipo_evento',   p_tipo_evento
  );

  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/contratos-push-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := payload
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'push_notify_contrato falhou: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function
CREATE OR REPLACE FUNCTION public.tr_fn_contrato_avisar_moradores()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT' AND NEW.avisar_moradores = true)
     OR (TG_OP = 'UPDATE' AND NEW.avisar_moradores = true AND
         (OLD.avisar_moradores IS DISTINCT FROM true)) THEN
    PERFORM public.push_notify_contrato(
      p_contrato_id   := NEW.id,
      p_condominio_id := NEW.condominio_id,
      p_titulo        := NEW.titulo,
      p_tipo_evento   := 'novo_contrato'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger
DROP TRIGGER IF EXISTS tr_contrato_avisar_moradores ON public.contratos;
CREATE TRIGGER tr_contrato_avisar_moradores
  AFTER INSERT OR UPDATE ON public.contratos
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_contrato_avisar_moradores();
