-- Migration: 20260824130000_fix_convite_pgnet_auth_headers.sql
-- Description: Corrige a autenticacao das chamadas pg_net nos triggers de visitantes,
-- substituindo o token estatico invalido pela resolucao dinamica padronizada de service_role_key.

-- 1. tr_fn_convite_created
CREATE OR REPLACE FUNCTION public.tr_fn_convite_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_payload  JSONB;
  v_supa_url TEXT;
  v_svc_key  TEXT;
BEGIN
  -- Only fire for new convites with status 'active'
  IF NEW.status <> 'active' THEN
    RETURN NEW;
  END IF;

  -- If parent_id is not null, skip trigger to avoid sending duplicate WhatsApp messages
  IF NEW.parent_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  v_supa_url := COALESCE(
    current_setting('app.settings.supabase_url', true),
    'https://avypyaxthvgaybplnwxu.supabase.co'
  );
  v_svc_key := COALESCE(
    current_setting('app.settings.service_role_key', true),
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2eXB5YXh0aHZnYXlicGxud3h1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjIxOTk3NCwiZXhwIjoyMDg3Nzk1OTc0fQ.Y-t_4wRc8HNGPbmZJM4leUaB6m3rqMIZB75wr1VlK9s'
  );

  IF v_svc_key IS NULL OR v_svc_key = '' THEN
    RAISE WARNING 'tr_fn_convite_created: service_role_key not set. Skipping notification.';
    RETURN NEW;
  END IF;

  -- ── CASE 1: Portaria-created convite ──────────────────────────────
  IF COALESCE(NEW.criado_por_portaria, false) = true THEN
    v_payload := jsonb_build_object(
      'action',              'portaria_created',
      'convite_id',          NEW.id,
      'resident_id',         COALESCE(NEW.resident_id::text, ''),
      'condominio_id',       NEW.condominio_id,
      'guest_name',          COALESCE(NEW.guest_name, ''),
      'visitor_phone',       COALESCE(NEW.whatsapp, ''),
      'visitor_type',        COALESCE(NEW.visitor_type, ''),
      'validity_date',       COALESCE(NEW.validity_date::text, ''),
      'valid_until',         COALESCE(NEW.valid_until::text, ''),
      'qr_data',             COALESCE(NEW.qr_data, ''),
      'observacao',          COALESCE(NEW.observacao, ''),
      'bloco_destino',       COALESCE(NEW.bloco_destino, ''),
      'apto_destino',        COALESCE(NEW.apto_destino, ''),
      'morador_nome_manual', COALESCE(NEW.morador_nome_manual, '')
    );

    PERFORM net.http_post(
      url     := v_supa_url || '/functions/v1/convite-whatsapp-notify',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_svc_key
      ),
      body    := v_payload
    );

    RETURN NEW;
  END IF;

  -- ── CASE 2: Normal convite (resident-created) ────────────────────
  v_payload := jsonb_build_object(
    'convite_id',     NEW.id,
    'resident_id',    NEW.resident_id,
    'condominio_id',  NEW.condominio_id,
    'guest_name',     COALESCE(NEW.guest_name, ''),
    'visitor_phone',  COALESCE(NEW.visitor_phone, ''),
    'validity_date',  COALESCE(NEW.validity_date::text, ''),
    'valid_until',    COALESCE(NEW.valid_until::text, ''),
    'qr_data',        COALESCE(NEW.qr_data, '')
  );

  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/convite-whatsapp-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := v_payload
  );

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'tr_fn_convite_created failed: %', SQLERRM;
  RETURN NEW;
END;
$function$;


-- 2. tr_fn_convite_liberado
CREATE OR REPLACE FUNCTION public.tr_fn_convite_liberado()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_payload  JSONB;
  v_supa_url TEXT;
  v_svc_key  TEXT;
BEGIN
  -- Only fire when visitante_compareceu changes from false/null to true
  IF NOT (NEW.visitante_compareceu IS TRUE
          AND (OLD.visitante_compareceu IS NOT TRUE)) THEN
    RETURN NEW;
  END IF;

  v_supa_url := COALESCE(
    current_setting('app.settings.supabase_url', true),
    'https://avypyaxthvgaybplnwxu.supabase.co'
  );
  v_svc_key := COALESCE(
    current_setting('app.settings.service_role_key', true),
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2eXB5YXh0aHZnYXlicGxud3h1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjIxOTk3NCwiZXhwIjoyMDg3Nzk1OTc0fQ.Y-t_4wRc8HNGPbmZJM4leUaB6m3rqMIZB75wr1VlK9s'
  );

  IF v_svc_key IS NULL OR v_svc_key = '' THEN
    RAISE WARNING 'tr_fn_convite_liberado: service_role_key not set. Skipping notification.';
    RETURN NEW;
  END IF;

  -- Build payload with action identifier
  v_payload := jsonb_build_object(
    'action',         'entry_released',
    'convite_id',     NEW.id,
    'resident_id',    NEW.resident_id,
    'condominio_id',  NEW.condominio_id,
    'guest_name',     COALESCE(NEW.guest_name, ''),
    'visitor_phone',  COALESCE(NEW.whatsapp, ''),
    'visitor_type',   COALESCE(NEW.visitor_type, ''),
    'validity_date',  COALESCE(NEW.validity_date::text, ''),
    'qr_data',        COALESCE(NEW.qr_data, ''),
    'created_at',     COALESCE(NEW.created_at::text, ''),
    'liberado_em',    COALESCE(NEW.liberado_em::text, '')
  );

  -- Call Edge Function via pg_net
  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/convite-whatsapp-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := v_payload
  );

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'tr_fn_convite_liberado failed: %', SQLERRM;
  RETURN NEW;
END;
$function$;


-- 3. tr_fn_visitor_unexpected_whatsapp
CREATE OR REPLACE FUNCTION public.tr_fn_visitor_unexpected_whatsapp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_payload  JSONB;
  v_supa_url TEXT;
  v_svc_key  TEXT;
BEGIN
  -- Only fire when status is 'aguardando_aprovacao' and canal_liberacao is 'whatsapp'
  IF NEW.status <> 'aguardando_aprovacao' OR NEW.canal_liberacao <> 'whatsapp' THEN
    RETURN NEW;
  END IF;

  v_supa_url := COALESCE(
    current_setting('app.settings.supabase_url', true),
    'https://avypyaxthvgaybplnwxu.supabase.co'
  );
  v_svc_key := COALESCE(
    current_setting('app.settings.service_role_key', true),
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2eXB5YXh0aHZnYXlicGxud3h1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjIxOTk3NCwiZXhwIjoyMDg3Nzk1OTc0fQ.Y-t_4wRc8HNGPbmZJM4leUaB6m3rqMIZB75wr1VlK9s'
  );

  IF v_svc_key IS NULL OR v_svc_key = '' THEN
    RAISE WARNING 'tr_fn_visitor_unexpected_whatsapp: service_role_key not set. Skipping notification.';
    RETURN NEW;
  END IF;

  -- Build payload
  v_payload := jsonb_build_object(
    'action',         'send_approval_request',
    'visitor_id',     NEW.id,
    'condominio_id',  NEW.condominio_id,
    'nome',           NEW.nome,
    'bloco',          COALESCE(NEW.bloco, ''),
    'apto',           COALESCE(NEW.apto, '')
  );

  -- Call Edge Function via pg_net
  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/whatsapp-guest',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := v_payload
  );

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'tr_fn_visitor_unexpected_whatsapp failed: %', SQLERRM;
  RETURN NEW;
END;
$function$;
