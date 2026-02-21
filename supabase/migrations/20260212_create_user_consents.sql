-- Migration: 1.3 Consentimento LGPD
-- Description: Creates user_consents table for LGPD compliance tracking.

-- 1. User Consents Table
CREATE TABLE IF NOT EXISTS public.user_consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    consent_type TEXT NOT NULL CHECK (consent_type IN ('terms_of_service', 'privacy_policy')),
    granted_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(user_id, consent_type)
);

-- 2. Enable RLS
ALTER TABLE public.user_consents ENABLE ROW LEVEL SECURITY;

-- 3. Policies for User Consents
CREATE POLICY "Users can view their own consents" ON public.user_consents
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own consents" ON public.user_consents
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own consents" ON public.user_consents
    FOR UPDATE USING (user_id = auth.uid());

-- 4. Index for performance
CREATE INDEX IF NOT EXISTS idx_user_consents_user_id ON public.user_consents(user_id);
CREATE INDEX IF NOT EXISTS idx_user_consents_active ON public.user_consents(user_id, consent_type) WHERE revoked_at IS NULL;
