-- Migration: Create user_devices for app telemetry and version observability
-- Project: condomeet_Antigravity (avypyaxthvgaybplnwxu)

CREATE TABLE IF NOT EXISTS public.user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    app_version TEXT NOT NULL,
    build_number INTEGER NOT NULL,
    device_identifier_hash TEXT NOT NULL,
    device_model TEXT,
    os_version TEXT,
    fcm_token TEXT,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_login_at TIMESTAMPTZ DEFAULT now(),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_device_hash UNIQUE (user_id, device_identifier_hash, platform)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_condo_build 
ON public.user_devices (condominio_id, build_number, platform);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_seen 
ON public.user_devices (user_id, last_seen_at DESC);

-- Habilitar RLS
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

-- 1. Políticas de Usuário Próprio com Validação de Integridade de Condomínio
DROP POLICY IF EXISTS "user_devices_insert_own" ON public.user_devices;
CREATE POLICY "user_devices_insert_own" ON public.user_devices
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND condominio_id = public.get_meu_condominio_id()
    );

DROP POLICY IF EXISTS "user_devices_update_own" ON public.user_devices;
CREATE POLICY "user_devices_update_own" ON public.user_devices
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id
        AND condominio_id = public.get_meu_condominio_id()
    );

DROP POLICY IF EXISTS "user_devices_select_own" ON public.user_devices;
CREATE POLICY "user_devices_select_own" ON public.user_devices
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_devices_delete_own" ON public.user_devices;
CREATE POLICY "user_devices_delete_own" ON public.user_devices
    FOR DELETE USING (auth.uid() = user_id);

-- 2. Políticas Administrativas Canônicas
DROP POLICY IF EXISTS "user_devices_select_admin" ON public.user_devices;
CREATE POLICY "user_devices_select_admin" ON public.user_devices
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.system_superadmins WHERE email = auth.jwt()->>'email'
        )
        OR
        public.is_admin_of_condo(condominio_id)
    );
