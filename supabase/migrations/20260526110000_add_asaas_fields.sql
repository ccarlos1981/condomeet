-- Add Asaas customer ID to the perfil table
ALTER TABLE public.perfil ADD COLUMN IF NOT EXISTS gateway_customer_id text;

-- Add Asaas generated URLs and PIX data to faturamentos
ALTER TABLE public.faturamentos ADD COLUMN IF NOT EXISTS gateway_invoice_url text;
ALTER TABLE public.faturamentos ADD COLUMN IF NOT EXISTS gateway_pix_qr_code text;
ALTER TABLE public.faturamentos ADD COLUMN IF NOT EXISTS gateway_pix_copia_cola text;
