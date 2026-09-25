-- ============================================================
-- Migration: 20260925150000_notify_novo_album_add_tipo_evento.sql
-- Objetivo: Incluir tipo_evento no payload enviado para album-push-notify
--           permitindo título dinâmico do push no mobile.
-- Projeto Oficial: condomeet_Antigravity (avypyaxthvgaybplnwxu)
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_novo_album()
RETURNS TRIGGER AS $$
DECLARE
  v_supa_url TEXT;
  v_svc_key  TEXT;
BEGIN
  v_supa_url := COALESCE(
    current_setting('app.settings.supabase_url', true),
    'https://avypyaxthvgaybplnwxu.supabase.co'
  );
  SELECT decrypted_secret
  INTO v_svc_key
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_service_role_key'
  LIMIT 1;

  IF v_svc_key IS NULL OR v_svc_key = '' THEN
    RAISE WARNING 'notify_novo_album: service_role_key not set. Skipping push.';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/album-push-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := jsonb_build_object(
      'album_id',      NEW.id,
      'condominio_id', NEW.condominio_id,
      'titulo',        NEW.titulo,
      'tipo_evento',   NEW.tipo_evento
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_novo_album failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';
