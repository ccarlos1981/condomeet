-- Migration: Fix infinite recursion in profiles RLS policy
-- The existing policy references profiles from within its own SELECT policy,
-- causing PostgreSQL error 42P17. Fix by using auth.uid() directly for own-row
-- access, and the JWT-based get_user_condo_id() for condominium filtering.

-- Drop the recursive policy
DROP POLICY IF EXISTS "Users can view profiles in their condominium" ON public.profiles;

-- Recreate without self-referencing subquery
-- Option 1: Users can always read their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (id = auth.uid());

-- Option 2: Users can view other profiles in same condominium (using JWT, not subquery)
CREATE POLICY "Users can view profiles in same condominium" ON public.profiles
    FOR SELECT USING (
        condominium_id = public.get_user_condo_id()
    );

-- Also fix the condominiums policy that has the same issue
DROP POLICY IF EXISTS "Users can view their own condominium" ON public.condominiums;

CREATE POLICY "Users can view their own condominium" ON public.condominiums
    FOR SELECT USING (
        id = public.get_user_condo_id()
    );
