-- Migration: Allow Anonymous Seeding for Development Bypass
-- This allows the app to seed a test condominium and profile when using the dev bypass.
-- WARNING: This should be disabled or restricted in production.

-- Allow anonymous inserts into condominiums
CREATE POLICY "Allow anonymous insert for dev seeding" ON public.condominiums
    FOR INSERT 
    WITH CHECK (true);

-- Allow anonymous inserts into profiles
CREATE POLICY "Allow anonymous insert for dev seeding" ON public.profiles
    FOR INSERT 
    WITH CHECK (true);

-- Also need to allow anonymous SELECT to check if tables are empty
CREATE POLICY "Allow anonymous select for dev check" ON public.condominiums
    FOR SELECT USING (true);

CREATE POLICY "Allow anonymous select for dev check" ON public.profiles
    FOR SELECT USING (true);
