-- Migration: 1.5 Add Phone to Profiles
-- Description: Adiciona o campo de telefone para notificações de WhatsApp.

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS phone TEXT;

-- Comentário para o Supabase dashboard
COMMENT ON COLUMN public.profiles.phone IS 'Telefone formatado (ex: 5511999999999) para alertas de WhatsApp';
