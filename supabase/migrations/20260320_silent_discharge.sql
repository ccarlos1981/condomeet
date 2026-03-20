-- Migration: 20260320 - Silent Discharge Feature
-- Adds support for "Baixa Silenciosa" (silent discharge) of parcels
-- where the portaria can mark a parcel as delivered WITHOUT sending
-- any notification (push or WhatsApp) to the resident.
-- Also adds discharged_by to track which user performed the discharge.

-- ============================================================
-- 1. New columns
-- ============================================================

-- silent_discharge: when true, no notifications are sent on delivery
ALTER TABLE public.encomendas
  ADD COLUMN IF NOT EXISTS silent_discharge BOOLEAN DEFAULT false;

-- discharged_by: UUID of the user (porter) who performed the discharge
ALTER TABLE public.encomendas
  ADD COLUMN IF NOT EXISTS discharged_by UUID REFERENCES perfil(id);

COMMENT ON COLUMN public.encomendas.silent_discharge IS 'Quando true, a baixa não dispara notificação push nem WhatsApp ao morador';
COMMENT ON COLUMN public.encomendas.discharged_by    IS 'UUID do porteiro/síndico que registrou a baixa da encomenda';

-- ============================================================
-- 2. Update the DELIVERED trigger to skip notifications when
--    silent_discharge = true
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

  -- Skip notifications for silent discharges
  IF NEW.silent_discharge = true THEN
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
