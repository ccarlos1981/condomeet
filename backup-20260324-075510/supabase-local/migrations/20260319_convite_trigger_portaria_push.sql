-- ============================================================
-- Migration: 20260319_convite_trigger_portaria_push
-- Fix trigger to properly handle portaria-created convites:
--   1. Send action='portaria_created' when criado_por_portaria=true
--   2. Include extra fields (visitor_type, bloco_destino, apto_destino, etc.)
--   3. Don't bail on missing botconversa_id for portaria convites (push doesn't need it)
-- ============================================================

CREATE OR REPLACE FUNCTION public.tr_fn_convite_created()
RETURNS TRIGGER AS $$
DECLARE
  v_resident_botconversa TEXT;
  v_payload              JSONB;
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
  -- Check if resident has botconversa_id
  SELECT botconversa_id INTO v_resident_botconversa
  FROM public.perfil
  WHERE id = NEW.resident_id;

  IF v_resident_botconversa IS NULL OR v_resident_botconversa = '' THEN
    RAISE WARNING 'tr_fn_convite_created: no botconversa_id for resident %', NEW.resident_id;
    RETURN NEW;
  END IF;

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
