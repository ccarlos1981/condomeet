-- Migration: 1.4 Notificação WhatsApp
-- Description: Trigger para enviar alerta via Edge Function sempre que uma encomenda chegar.

-- 1. Função que chama a Edge Function do Supabase (Final Schema Version)
CREATE OR REPLACE FUNCTION public.notify_parcel_arrival()
RETURNS TRIGGER AS $$
DECLARE
  resident_profile RECORD;
  payload JSONB;
BEGIN
  -- 1. Buscar dados do morador e unidade
  SELECT p.full_name, u.unit_number, u.block, p.unit_id INTO resident_profile 
  FROM public.profiles p
  LEFT JOIN public.units u ON p.unit_id = u.id
  WHERE p.id = NEW.resident_id;

  -- 2. Montar o JSON para a Edge Function
  payload := jsonb_build_object(
    'parcel_id', NEW.id,
    'resident_name', resident_profile.full_name,
    'unit', COALESCE(resident_profile.unit_number, 'N/A'),
    'block', COALESCE(resident_profile.block, 'N/A'),
    'unit_id', resident_profile.unit_id,
    'photo_url', NEW.photo_url,
    'resident_id', NEW.resident_id
  );

  -- 3. Chamada HTTP via pg_net (Usando o prefixo 'net' conforme detectado)
  PERFORM
    net.http_post(
      url := 'https://avypyaxthvgaybplnwxu.supabase.co/functions/v1/whatsapp-parcel-notify',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      ),
      body := payload
    );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger na tabela parcels
DROP TRIGGER IF EXISTS tr_on_parcel_inserted ON public.parcels;
CREATE TRIGGER tr_on_parcel_inserted
AFTER INSERT ON public.parcels
FOR EACH ROW
EXECUTE FUNCTION public.notify_parcel_arrival();
