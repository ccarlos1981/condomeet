-- Migration: 5.1 Security & Communication Tables
-- Description: Tables for SOS alerts, occurrences, and chat messages.

-- 1. SOS Alerts Table
CREATE TABLE IF NOT EXISTS public.sos_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resident_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    condominium_id UUID REFERENCES public.condominiums(id) ON DELETE CASCADE NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'acknowledged', 'resolved')),
    acknowledged_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2. Occurrences Table
CREATE TABLE IF NOT EXISTS public.occurrences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resident_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    condominium_id UUID REFERENCES public.condominiums(id) ON DELETE CASCADE NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    photo_paths TEXT[], -- Array of photo URLs/paths
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 3. Chat Messages Table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resident_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL, -- The resident involved in the thread
    condominium_id UUID REFERENCES public.condominiums(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('admin', 'porter', 'resident')),
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 4. Enable RLS
ALTER TABLE public.sos_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.occurrences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- 5. Policies (Condominium Isolation)
-- SOS: Everyone in condo can see active alerts (for visibility), only admins/porters can update status
CREATE POLICY "Users can view SOS alerts in their condo" ON public.sos_alerts
    FOR SELECT USING (condominium_id = (SELECT condominium_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Residents can create SOS alerts" ON public.sos_alerts
    FOR INSERT WITH CHECK (auth.uid() = resident_id);

CREATE POLICY "Staff can update SOS alerts" ON public.sos_alerts
    FOR UPDATE USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'porter')
    );

-- Occurrences: Residents see their own, staff see all
CREATE POLICY "Residents can view own occurrences" ON public.occurrences
    FOR SELECT USING (auth.uid() = resident_id);

CREATE POLICY "Staff can view all occurrences in condo" ON public.occurrences
    FOR SELECT USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'porter')
        AND condominium_id = (SELECT condominium_id FROM profiles WHERE id = auth.uid())
    );

CREATE POLICY "Residents can report occurrences" ON public.occurrences
    FOR INSERT WITH CHECK (auth.uid() = resident_id);

-- Chat: Residents see messages in their thread, staff see all messages in condo
CREATE POLICY "Residents see their own chat thread" ON public.chat_messages
    FOR SELECT USING (resident_id = auth.uid());

CREATE POLICY "Staff see all chat threads in condo" ON public.chat_messages
    FOR SELECT USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'porter')
        AND condominium_id = (SELECT condominium_id FROM profiles WHERE id = auth.uid())
    );

CREATE POLICY "Users can send messages" ON public.chat_messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- 6. PowerSync Triggers
CREATE TRIGGER set_updated_at_sos
BEFORE UPDATE ON public.sos_alerts
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_occurrences
BEFORE UPDATE ON public.occurrences
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_chat
BEFORE UPDATE ON public.chat_messages
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
