-- ============================================================
-- Migration: 20260315_convite_whatsapp_trigger
-- Trigger: Sends WhatsApp notification via convite-whatsapp-notify
--          when a new convite is created
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

  -- Check if resident has botconversa_id
  SELECT botconversa_id INTO v_resident_botconversa
  FROM public.perfil
  WHERE id = NEW.resident_id;

  IF v_resident_botconversa IS NULL OR v_resident_botconversa = '' THEN
    RAISE WARNING 'tr_fn_convite_created: no botconversa_id for resident %', NEW.resident_id;
    RETURN NEW;
  END IF;

  -- Build payload
  v_payload := jsonb_build_object(
    'convite_id',     NEW.id,
    'resident_id',    NEW.resident_id,
    'condominio_id',  NEW.condominio_id,
    'guest_name',     COALESCE(NEW.guest_name, ''),
    'visitor_phone',  COALESCE(NEW.visitor_phone, ''),
    'validity_date',  COALESCE(NEW.validity_date::text, ''),
    'qr_data',        COALESCE(NEW.qr_data, '')
  );

  -- Call Edge Function via pg_net (hardcoded — Supabase managed não permite current_setting)
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

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS tr_convite_created ON public.convites;

-- Create the trigger
CREATE TRIGGER tr_convite_created
  AFTER INSERT ON public.convites
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_convite_created();
