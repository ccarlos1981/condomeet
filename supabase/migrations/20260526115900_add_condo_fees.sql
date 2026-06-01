-- Add Juros and Multa settings to condominios
ALTER TABLE public.condominios ADD COLUMN IF NOT EXISTS multa_padrao numeric DEFAULT 2;
ALTER TABLE public.condominios ADD COLUMN IF NOT EXISTS juros_mensal_padrao numeric DEFAULT 3;
