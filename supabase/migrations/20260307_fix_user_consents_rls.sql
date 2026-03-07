-- Fix RLS for user_consents
-- Description: Ensures authenticated users can manage their own consents and table is in PowerSync publication.

-- 1. Drop existing policies to start fresh
DROP POLICY IF EXISTS "Users can view their own consents" ON public.user_consents;
DROP POLICY IF EXISTS "Users can insert their own consents" ON public.user_consents;
DROP POLICY IF EXISTS "Users can update their own consents" ON public.user_consents;

-- 2. Simple but robust policies
-- We use casting just to be 100% sure although Supabase handles UUIDs well.
CREATE POLICY "Users can view their own consents" ON public.user_consents
    FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own consents" ON public.user_consents
    FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own consents" ON public.user_consents
    FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- 3. Grants
GRANT ALL ON public.user_consents TO authenticated;
GRANT ALL ON public.user_consents TO service_role;

-- 4. PowerSync Integration
-- Ensure the table is in the publication for sync to work both ways
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'powersync' AND schemaname = 'public' AND tablename = 'user_consents'
    ) THEN
        ALTER PUBLICATION powersync ADD TABLE public.user_consents;
    END IF;
END $$;
