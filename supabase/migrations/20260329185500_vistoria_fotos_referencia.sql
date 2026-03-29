-- Adiciona coluna fotos_referencia aos itens de vistoria para armazenar 
-- fotos da vistoria de entrada que servirão de referência na vistoria de saída

ALTER TABLE public.vistoria_itens 
ADD COLUMN IF NOT EXISTS fotos_referencia JSONB DEFAULT '[]'::jsonb;
