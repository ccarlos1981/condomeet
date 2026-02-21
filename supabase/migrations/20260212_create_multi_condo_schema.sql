-- Migration: 1.2 Schema Multi-Condomínio
-- Description: Creates condominiums and profiles with RLS isolation.

-- 1. Condominiums Table
CREATE TABLE IF NOT EXISTS public.condominiums (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2. Profiles Table (Extends Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    condominium_id UUID REFERENCES public.condominiums(id) ON DELETE CASCADE NOT NULL,
    full_name TEXT,
    role TEXT NOT NULL CHECK (role IN ('admin', 'porter', 'resident')),
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 3. Enable RLS
ALTER TABLE public.condominiums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. Access Helper Function
-- This function checks if the current user has access to a specific condominium.
-- In a real Supabase environment, this might use JWT claims or join checks.
CREATE OR REPLACE FUNCTION public.check_condo_access(target_condo_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.condominium_id = target_condo_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Policies for Condominiums
CREATE POLICY "Users can view their own condominium" ON public.condominiums
    FOR SELECT USING (check_condo_access(id));

-- 6. Policies for Profiles
CREATE POLICY "Users can view profiles in their condominium" ON public.profiles
    FOR SELECT USING (condominium_id = (SELECT condominium_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (id = auth.uid());

-- 7. Soft Delete & Sync Helpers (Standard PowerSync requirements)
-- (Add triggers for updated_at if needed)
