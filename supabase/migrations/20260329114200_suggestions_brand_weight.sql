ALTER TABLE public.lista_product_suggestions 
ADD COLUMN IF NOT EXISTS brand TEXT,
ADD COLUMN IF NOT EXISTS weight_label TEXT;
