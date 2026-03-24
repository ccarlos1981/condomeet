-- Migration: 20260308d - Configure push notification settings
-- Run this in the Supabase SQL editor after getting your service_role key
-- from: Project Settings → API → service_role Key

-- ============================================================
-- 1. Set the app settings used by the push trigger
-- ============================================================

-- Set your project URL (already configured)
ALTER DATABASE postgres 
  SET app.settings.supabase_url = 'https://avypyaxthvgaybplnwxu.supabase.co';

-- ⚠️ REPLACE 'YOUR_SERVICE_ROLE_KEY' with the actual key from Supabase dashboard
-- Project Settings → API → service_role (secret)  
ALTER DATABASE postgres 
  SET app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';

-- Apply settings to current session immediately
SELECT set_config('app.settings.supabase_url', 'https://avypyaxthvgaybplnwxu.supabase.co', false);

-- ============================================================
-- 2. Re-create the push helper with hardcoded URL fallback
-- ============================================================
CREATE OR REPLACE FUNCTION public.push_notify_parcel(
  p_parcel_id   UUID,
  p_event       TEXT,
  p_condominio  UUID,
  p_bloco       TEXT,
  p_apto        TEXT,
  p_tipo        TEXT,
  p_picked_by   TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  payload       JSONB;
  v_supa_url    TEXT;
  v_svc_key     TEXT;
BEGIN
  -- Use hardcoded URL as primary, fall back to setting
  v_supa_url := COALESCE(
    current_setting('app.settings.supabase_url', true),
    'https://avypyaxthvgaybplnwxu.supabase.co'
  );
  v_svc_key := current_setting('app.settings.service_role_key', true);

  IF v_svc_key IS NULL OR v_svc_key = '' THEN
    RAISE WARNING 'push_notify_parcel: service_role_key not set. Skipping notification.';
    RETURN;
  END IF;

  payload := jsonb_build_object(
    'parcel_id',         p_parcel_id,
    'event',             p_event,
    'condominio_id',     p_condominio,
    'bloco',             p_bloco,
    'apto',              p_apto,
    'tipo',              p_tipo,
    'picked_up_by_name', COALESCE(p_picked_by, '')
  );

  -- 1. Push Notificações
  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/parcel-push-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := payload
  );

  -- 2. WhatsApp Notificações
  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/whatsapp-parcel-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := payload
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'push_notify_parcel failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
