-- Migration: 20260308c - Encomendas Push Notification Triggers
-- Triggers on encomendas for:
--   1. ARRIVED — when a new parcel is inserted
--   2. DELIVERED — when status changes to 'delivered'
-- Both call the parcel-push-notify Edge Function via pg_net

-- ============================================================
-- Helper function: notify via Edge Function
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
  payload JSONB;
BEGIN
  payload := jsonb_build_object(
    'parcel_id',         p_parcel_id,
    'event',             p_event,
    'condominio_id',     p_condominio,
    'bloco',             p_bloco,
    'apto',              p_apto,
    'tipo',              p_tipo,
    'picked_up_by_name', COALESCE(p_picked_by, '')
  );

  PERFORM net.http_post(
    url     := current_setting('app.settings.supabase_url', true) || '/functions/v1/parcel-push-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body    := payload
  );
EXCEPTION WHEN OTHERS THEN
  -- Non-fatal: log and continue
  RAISE WARNING 'push_notify_parcel failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Trigger: ARRIVED — AFTER INSERT on encomendas
-- ============================================================
CREATE OR REPLACE FUNCTION public.tr_fn_encomenda_arrived()
RETURNS TRIGGER AS $$
DECLARE
  v_bloco TEXT;
  v_apto  TEXT;
BEGIN
  -- Resolve bloco/apto from the resident's perfil
  SELECT bloco_txt, apto_txt INTO v_bloco, v_apto
  FROM public.perfil
  WHERE id = NEW.resident_id
  LIMIT 1;

  PERFORM public.push_notify_parcel(
    p_parcel_id  := NEW.id,
    p_event      := 'arrived',
    p_condominio := NEW.condominio_id,
    p_bloco      := COALESCE(v_bloco, ''),
    p_apto       := COALESCE(v_apto, ''),
    p_tipo       := COALESCE(NEW.tipo, 'pacote')
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_encomenda_arrived ON public.encomendas;
CREATE TRIGGER tr_encomenda_arrived
  AFTER INSERT ON public.encomendas
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_encomenda_arrived();

-- ============================================================
-- Trigger: DELIVERED — AFTER UPDATE WHEN status → 'delivered'
-- ============================================================
CREATE OR REPLACE FUNCTION public.tr_fn_encomenda_delivered()
RETURNS TRIGGER AS $$
DECLARE
  v_bloco TEXT;
  v_apto  TEXT;
BEGIN
  -- Only fire when transitioning to delivered
  IF NEW.status <> 'delivered' OR OLD.status = 'delivered' THEN
    RETURN NEW;
  END IF;

  SELECT bloco_txt, apto_txt INTO v_bloco, v_apto
  FROM public.perfil
  WHERE id = NEW.resident_id
  LIMIT 1;

  PERFORM public.push_notify_parcel(
    p_parcel_id  := NEW.id,
    p_event      := 'delivered',
    p_condominio := NEW.condominio_id,
    p_bloco      := COALESCE(v_bloco, ''),
    p_apto       := COALESCE(v_apto, ''),
    p_tipo       := COALESCE(NEW.tipo, 'pacote'),
    p_picked_by  := NEW.picked_up_by_name
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_encomenda_delivered ON public.encomendas;
CREATE TRIGGER tr_encomenda_delivered
  AFTER UPDATE ON public.encomendas
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_encomenda_delivered();
