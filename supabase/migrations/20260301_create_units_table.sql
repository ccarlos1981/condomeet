-- Migration: 4.1 Create Units Table and Refactor Profiles
-- Description: Normalizes unit information and adds blocking capability.

-- 1. Create Units Table
CREATE TABLE IF NOT EXISTS public.units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id UUID REFERENCES public.condominiums(id) ON DELETE CASCADE NOT NULL,
    block TEXT NOT NULL,
    unit_number TEXT NOT NULL,
    is_blocked BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ,
    UNIQUE(condominium_id, block, unit_number)
);

-- 2. Enable RLS on Units
ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view units in their condominium" ON public.units
    FOR SELECT USING (
        condominium_id = (SELECT p.condominium_id FROM public.profiles p WHERE p.id = auth.uid())
    );

-- 3. Trigger for units updated_at
CREATE TRIGGER set_updated_at_units
BEFORE UPDATE ON public.units
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 4. Migrate existing data from profiles to units
INSERT INTO public.units (condominium_id, block, unit_number)
SELECT DISTINCT condominium_id, block, unit_number
FROM public.profiles
WHERE block IS NOT NULL AND unit_number IS NOT NULL
ON CONFLICT (condominium_id, block, unit_number) DO NOTHING;

-- 5. Add unit_id to profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS unit_id UUID REFERENCES public.units(id) ON DELETE SET NULL;

-- 6. Link profiles to their new units
UPDATE public.profiles p
SET unit_id = u.id
FROM public.units u
WHERE p.condominium_id = u.condominium_id 
  AND p.block = u.block 
  AND p.unit_number = u.unit_number;

-- 7. Add logic to check if unit is blocked in RLS helpers (Optional but good)
CREATE OR REPLACE FUNCTION public.is_unit_blocked(u_id UUID)
RETURNS BOOLEAN AS $$
  SELECT is_blocked FROM public.units WHERE id = u_id;
$$ LANGUAGE sql STABLE;

-- 8. Add comments
COMMENT ON TABLE public.units IS 'Unidades (apartamentos/casas) do condomínio.';
COMMENT ON COLUMN public.units.is_blocked IS 'Se verdadeiro, impede o acesso de todos os moradores da unidade.';
