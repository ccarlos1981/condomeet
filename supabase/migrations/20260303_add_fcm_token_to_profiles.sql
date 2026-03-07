-- Migration: 1.7 Add FCM Token to Profiles
-- Description: Adiciona coluna para armazenar o token do Firebase Cloud Messaging para notificações push.

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Comentário para clareza
COMMENT ON COLUMN public.profiles.fcm_token IS 'Token do Firebase Cloud Messaging para notificações push (Fallback do WhatsApp).';

-- Índice para busca rápida (opcional, se formos buscar pelo token)
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON public.profiles(fcm_token);
