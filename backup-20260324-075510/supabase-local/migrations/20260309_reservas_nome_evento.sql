-- Add nome_evento to reservas for the booking form
ALTER TABLE public.reservas ADD COLUMN IF NOT EXISTS nome_evento TEXT;
