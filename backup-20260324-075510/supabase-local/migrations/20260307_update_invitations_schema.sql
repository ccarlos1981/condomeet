-- Migration: Update convites table for Visitor Authorization
-- Description: Adds visitor_type, visitor_phone, and observation columns.

ALTER TABLE public.convites 
ADD COLUMN IF NOT EXISTS visitor_type TEXT,
ADD COLUMN IF NOT EXISTS visitor_phone TEXT,
ADD COLUMN IF NOT EXISTS observation TEXT;

-- Update RLS Policies for convites
ALTER TABLE public.convites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Residents can view their own invitations" ON public.convites;
CREATE POLICY "Residents can view their own invitations" ON public.convites
    FOR SELECT TO authenticated USING (resident_id = auth.uid());

DROP POLICY IF EXISTS "Residents can create their own invitations" ON public.convites;
CREATE POLICY "Residents can create their own invitations" ON public.convites
    FOR INSERT TO authenticated WITH CHECK (resident_id = auth.uid());

DROP POLICY IF EXISTS "Residents can update their own invitations" ON public.convites;
CREATE POLICY "Residents can update their own invitations" ON public.convites
    FOR UPDATE TO authenticated USING (resident_id = auth.uid());

-- Ensure table is in PowerSync publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'powersync' AND schemaname = 'public' AND tablename = 'convites'
    ) THEN
        ALTER PUBLICATION powersync ADD TABLE public.convites;
    END IF;
END $$;
