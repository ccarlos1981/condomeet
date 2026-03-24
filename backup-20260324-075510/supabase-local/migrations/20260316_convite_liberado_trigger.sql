-- ============================================================
-- Migration: 20260316_convite_liberado_trigger
-- Trigger: Sends WhatsApp notification via convite-whatsapp-notify
--          when porteiro releases visitor entry
--          (visitante_compareceu changes to TRUE)
-- ============================================================

CREATE OR REPLACE FUNCTION public.tr_fn_convite_liberado()
RETURNS TRIGGER AS $$
DECLARE
  v_resident_botconversa TEXT;
  v_payload              JSONB;
BEGIN
  -- Only fire when visitante_compareceu changes from false/null to true
  IF NOT (NEW.visitante_compareceu IS TRUE
          AND (OLD.visitante_compareceu IS NOT TRUE)) THEN
    RETURN NEW;
  END IF;

  -- Check if resident has botconversa_id
  SELECT botconversa_id INTO v_resident_botconversa
  FROM public.perfil
  WHERE id = NEW.resident_id;

  IF v_resident_botconversa IS NULL OR v_resident_botconversa = '' THEN
    RAISE WARNING 'tr_fn_convite_liberado: no botconversa_id for resident %', NEW.resident_id;
    RETURN NEW;
  END IF;

  -- Build payload with action identifier
  v_payload := jsonb_build_object(
    'action',         'entry_released',
    'convite_id',     NEW.id,
    'resident_id',    NEW.resident_id,
    'condominio_id',  NEW.condominio_id,
    'guest_name',     COALESCE(NEW.guest_name, ''),
    'visitor_phone',  COALESCE(NEW.visitor_phone, ''),
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

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS tr_convite_liberado ON public.convites;

-- Create the trigger (fires on UPDATE of visitante_compareceu)
CREATE TRIGGER tr_convite_liberado
  AFTER UPDATE OF visitante_compareceu ON public.convites
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_convite_liberado();
