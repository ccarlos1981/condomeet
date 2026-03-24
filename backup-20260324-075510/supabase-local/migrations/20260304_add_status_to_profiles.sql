-- Migration: Add status to profiles
-- Description: Adds a status column to support resident onboarding approval flow.

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('active', 'pending', 'rejected'));

-- Update existing profiles to active
UPDATE public.profiles SET status = 'active' WHERE status IS NULL OR status = 'pending';

-- Add comment
COMMENT ON COLUMN public.profiles.status IS 'Status da conta do usuário para controle de acesso (active, pending, rejected).';
