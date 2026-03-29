ALTER TABLE public.lista_supermarkets 
ADD COLUMN IF NOT EXISTS google_place_id TEXT UNIQUE;
