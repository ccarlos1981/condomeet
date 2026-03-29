-- Migration: Price Alert Push Notification Trigger
-- When a new price is inserted into lista_prices_raw,
-- call the Edge Function lista-price-alert-notify to check
-- if any user's price alert has been triggered.

-- ============================================================
-- 1. Trigger Function
-- ============================================================
CREATE OR REPLACE FUNCTION public.lista_check_price_alerts()
RETURNS TRIGGER AS $$
DECLARE
  v_supa_url TEXT;
  v_svc_key  TEXT;
  v_variant_id UUID;
  v_has_alerts BOOLEAN;
BEGIN
  v_supa_url := COALESCE(
    current_setting('app.settings.supabase_url', true),
    'https://avypyaxthvgaybplnwxu.supabase.co'
  );
  v_svc_key := current_setting('app.settings.service_role_key', true);

  IF v_svc_key IS NULL OR v_svc_key = '' THEN
    RAISE WARNING 'lista_check_price_alerts: service_role_key not set. Skipping.';
    RETURN NEW;
  END IF;

  -- Get the variant_id from the SKU
  SELECT variant_id INTO v_variant_id
  FROM lista_products_sku
  WHERE id = NEW.sku_id;

  IF v_variant_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Quick check: are there any active alerts for this variant at or above this price?
  SELECT EXISTS(
    SELECT 1
    FROM lista_price_alerts
    WHERE variant_id = v_variant_id
      AND is_active = true
      AND target_price >= NEW.price
  ) INTO v_has_alerts;

  -- Only call the Edge Function if there are matching alerts
  IF v_has_alerts THEN
    PERFORM net.http_post(
      url     := v_supa_url || '/functions/v1/lista-price-alert-notify',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_svc_key
      ),
      body    := jsonb_build_object(
        'price_raw_id',    NEW.id,
        'sku_id',          NEW.sku_id,
        'price',           NEW.price,
        'supermarket_id',  NEW.supermarket_id
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'lista_check_price_alerts failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public;

-- ============================================================
-- 2. Trigger on lista_prices_raw INSERT
-- ============================================================
DROP TRIGGER IF EXISTS trg_check_price_alerts ON public.lista_prices_raw;
CREATE TRIGGER trg_check_price_alerts
  AFTER INSERT ON public.lista_prices_raw
  FOR EACH ROW EXECUTE FUNCTION public.lista_check_price_alerts();
