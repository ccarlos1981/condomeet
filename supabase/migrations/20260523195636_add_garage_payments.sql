-- Add chave_pix to garages so owners can receive payments
ALTER TABLE public.garages 
ADD COLUMN IF NOT EXISTS chave_pix text;

-- Add payment columns to garage_reservations
ALTER TABLE public.garage_reservations
ADD COLUMN IF NOT EXISTS taxa_plataforma numeric(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS valor_liquido numeric(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'aguardando' CHECK (payment_status IN ('aguardando', 'pago', 'repassado', 'falha')),
ADD COLUMN IF NOT EXISTS payment_id text,
ADD COLUMN IF NOT EXISTS transfer_id text,
ADD COLUMN IF NOT EXISTS payment_qr_code text,
ADD COLUMN IF NOT EXISTS payment_copy_paste text;
