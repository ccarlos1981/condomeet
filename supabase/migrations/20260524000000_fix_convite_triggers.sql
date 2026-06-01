-- ============================================================
-- Migration: Fix Convite Triggers
-- 1. Remove botconversa_id requirements from tr_fn_convite_created and tr_fn_convite_liberado
-- 2. Fix typo NEW.visitor_phone -> NEW.whatsapp in tr_fn_convite_created
-- ============================================================

CREATE OR REPLACE FUNCTION public.tr_fn_convite_created()
RETURNS TRIGGER AS $$
DECLARE
  v_payload JSONB;
BEGIN
  -- Only fire for new convites with status 'active'
  IF NEW.status <> 'active' THEN
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
      'qr_data',             COALESCE(NEW.qr_data, ''),
      'observacao',          COALESCE(NEW.observacao, ''),
      'bloco_destino',       COALESCE(NEW.bloco_destino, ''),
      'apto_destino',        COALESCE(NEW.apto_destino, ''),
      'morador_nome_manual', COALESCE(NEW.morador_nome_manual, '')
    );

    PERFORM net.http_post(
      url     := 'https://avypyaxthvgaybplnwxu.supabase.co/functions/v1/convite-whatsapp-notify',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer sb_secret_BT14O-HTuhmMKKfkyWZGIw_QasPxvpE'
      ),
      body    := v_payload
    );

    RETURN NEW;
  END IF;

  -- ── CASE 2: Normal convite (resident-created) ────────────────────
  -- Build payload (default action = 'created')
  v_payload := jsonb_build_object(
    'convite_id',     NEW.id,
    'resident_id',    NEW.resident_id,
    'condominio_id',  NEW.condominio_id,
    'guest_name',     COALESCE(NEW.guest_name, ''),
    'visitor_phone',  COALESCE(NEW.visitor_phone, ''),
    'validity_date',  COALESCE(NEW.validity_date::text, ''),
    'qr_data',        COALESCE(NEW.qr_data, '')
  );

  PERFORM net.http_post(
    url     := 'https://avypyaxthvgaybplnwxu.supabase.co/functions/v1/convite-whatsapp-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer sb_secret_BT14O-HTuhmMKKfkyWZGIw_QasPxvpE'
    ),
    body    := v_payload
  );

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'tr_fn_convite_created failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION public.tr_fn_convite_liberado()
RETURNS TRIGGER AS $$
DECLARE
  v_payload JSONB;
BEGIN
  -- Only fire when visitante_compareceu changes from false/null to true
  IF NOT (NEW.visitante_compareceu IS TRUE
          AND (OLD.visitante_compareceu IS NOT TRUE)) THEN
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
    url     := 'https://avypyaxthvgaybplnwxu.supabase.co/functions/v1/convite-whatsapp-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer sb_secret_BT14O-HTuhmMKKfkyWZGIw_QasPxvpE'
    ),
    body    := v_payload
  );

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'tr_fn_convite_liberado failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
