-- Migration: 1.6 Add Botconversa ID to Profiles
-- Description: Adiciona o campo de ID do Botconversa para integração com cadastros existentes.

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS botconversa_id TEXT;

-- Comentário para o Supabase dashboard
COMMENT ON COLUMN public.profiles.phone IS 'ID do assinante no Botconversa para disparos via API';
