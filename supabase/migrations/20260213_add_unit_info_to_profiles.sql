-- Migration: 2.1 Add Unit Info to Profiles
-- Description: Adds unit_number and block to profiles for resident lookup.

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS unit_number TEXT,
ADD COLUMN IF NOT EXISTS block TEXT;

-- Update RLS (Policies already exist in 1.2, but we ensure columns are visible)
-- Note: In 1.2, we had:
-- CREATE POLICY "Users can view profiles in their condominium" ON public.profiles
--     FOR SELECT USING (condominium_id = (SELECT condominium_id FROM public.profiles WHERE id = auth.uid()));

-- Add a comment for documentation
COMMENT ON COLUMN public.profiles.unit_number IS 'Número da unidade/apartamento do morador.';
COMMENT ON COLUMN public.profiles.block IS 'Bloco ou torre do morador.';
