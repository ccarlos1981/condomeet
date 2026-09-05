-- Migration: 20260814_validate_encomenda_third_party.sql
-- Enforces valid third-party recipient name on parcel discharge (status = 'delivered')

CREATE OR REPLACE FUNCTION public.fn_validate_encomenda_discharge()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'delivered' THEN
    -- Sanitize picked_up_by_name with BTRIM and convert empty string to NULL
    IF NEW.picked_up_by_name IS NOT NULL THEN
      NEW.picked_up_by_name := BTRIM(NEW.picked_up_by_name);
      IF NEW.picked_up_by_name = '' THEN
        NEW.picked_up_by_name := NULL;
      END IF;
    END IF;

    -- If third-party discharge (picked_up_by_id is NULL) and not silent discharge:
    IF NEW.picked_up_by_id IS NULL AND COALESCE(NEW.silent_discharge, false) = false THEN
      IF NEW.picked_up_by_name IS NULL THEN
        RAISE EXCEPTION 'Nome do terceiro é obrigatório para baixa de encomenda entregue a terceiro.'
          USING ERRCODE = '23502';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_validate_encomenda_discharge ON public.encomendas;

CREATE TRIGGER tr_validate_encomenda_discharge
  BEFORE INSERT OR UPDATE ON public.encomendas
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_validate_encomenda_discharge();
