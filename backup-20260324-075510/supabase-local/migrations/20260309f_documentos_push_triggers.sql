-- ============================================================
-- Migration: 20260309f — Trigger push ao inserir/atualizar documento
-- com avisar_moradores = true
-- ============================================================

-- Helper: chama a Edge Function documentos-push-notify via pg_net
CREATE OR REPLACE FUNCTION public.push_notify_documento(
  p_documento_id  UUID,
  p_condominio_id UUID,
  p_titulo        TEXT,
  p_tipo_evento   TEXT DEFAULT 'novo_documento'
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
    RAISE WARNING 'push_notify_documento: service_role_key não configurado. Pulando notificação.';
    RETURN;
  END IF;

  payload := jsonb_build_object(
    'documento_id',  p_documento_id,
    'condominio_id', p_condominio_id,
    'titulo',        p_titulo,
    'tipo_evento',   p_tipo_evento
  );

  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/documentos-push-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := payload
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'push_notify_documento falhou: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── Trigger function ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tr_fn_documento_avisar_moradores()
RETURNS TRIGGER AS $$
BEGIN
  -- Disparar se:
  -- INSERT com avisar_moradores = true
  -- UPDATE onde avisar_moradores passou de false → true
  IF (TG_OP = 'INSERT' AND NEW.avisar_moradores = true)
     OR (TG_OP = 'UPDATE' AND NEW.avisar_moradores = true AND
         (OLD.avisar_moradores IS DISTINCT FROM true)) THEN

    PERFORM public.push_notify_documento(
      p_documento_id  := NEW.id,
      p_condominio_id := NEW.condominio_id,
      p_titulo        := NEW.titulo,
      p_tipo_evento   := 'novo_documento'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── Attach trigger ─────────────────────────────────────────
DROP TRIGGER IF EXISTS tr_documento_avisar_moradores ON public.documentos;
CREATE TRIGGER tr_documento_avisar_moradores
  AFTER INSERT OR UPDATE ON public.documentos
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_documento_avisar_moradores();
