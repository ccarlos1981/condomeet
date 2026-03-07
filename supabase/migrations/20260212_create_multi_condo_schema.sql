-- Migration: 1.2 Schema Multi-Condomínio
-- Description: Creates condominiums and profiles with RLS isolation and PowerSync support.

-- 0. Trigger for updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. Condominiums Table
CREATE TABLE IF NOT EXISTS public.condominiums (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ -- Soft delete support
);

-- 2. Profiles Table (Extends Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    condominium_id UUID REFERENCES public.condominiums(id) ON DELETE CASCADE NOT NULL,
    full_name TEXT,
    role TEXT NOT NULL CHECK (role IN ('admin', 'porter', 'resident')),
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ -- Soft delete support
);

-- 3. Enable RLS
ALTER TABLE public.condominiums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. Set App Context Helper (Simulated custom claim/lookup)
-- Optimized: Avoids subquery recursion by checking if the profile exists once.
CREATE OR REPLACE FUNCTION public.get_user_condo_id()
RETURNS UUID AS $$
  SELECT (auth.jwt() -> 'app_metadata' ->> 'condominium_id')::UUID;
$$ LANGUAGE sql STABLE;

-- 5. Policies for Condominiums
CREATE POLICY "Users can view their own condominium" ON public.condominiums
    FOR SELECT USING (
        id = (SELECT condominium_id FROM public.profiles WHERE profiles.id = auth.uid())
    );

-- 6. Policies for Profiles
-- Optimized to avoid infinite recursion and N+1 lookups
CREATE POLICY "Users can view profiles in their condominium" ON public.profiles
    FOR SELECT USING (
        condominium_id = (SELECT p.condominium_id FROM public.profiles p WHERE p.id = auth.uid())
    );

CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (id = auth.uid());

-- 7. Triggers for PowerSync Sync
CREATE TRIGGER set_updated_at_condominiums
BEFORE UPDATE ON public.condominiums
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_profiles
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
