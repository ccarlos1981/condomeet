-- =================================================================
-- Migration: 20260710132100_implement_worker_leases_and_locks
-- Description: Create dedicated worker_leases table, provider runtime configuration,
--              and Lease Lock database functions.
-- =================================================================

-- 1. Create Dedicated Worker Leases Table
CREATE TABLE IF NOT EXISTS public.worker_leases (
    id TEXT PRIMARY KEY DEFAULT 'singleton',
    worker_instance_id UUID,
    last_heartbeat TIMESTAMPTZ DEFAULT now(),
    worker_status TEXT NOT NULL DEFAULT 'IDLE',
    worker_started_at TIMESTAMPTZ,
    CONSTRAINT check_singleton_lease CHECK (id = 'singleton')
);

-- Seed worker lease
INSERT INTO public.worker_leases (id) 
VALUES ('singleton') 
ON CONFLICT (id) DO NOTHING;

-- 2. Create Message Provider Runtime Configuration Table
CREATE TABLE IF NOT EXISTS public.message_provider_runtime (
    id TEXT PRIMARY KEY DEFAULT 'singleton',
    active_provider TEXT NOT NULL DEFAULT 'BOTCONVERSA', -- 'BOTCONVERSA', 'META_CLOUD_API'
    fallback_provider TEXT NOT NULL DEFAULT 'META_CLOUD_API',
    botconversa_enabled BOOLEAN NOT NULL DEFAULT true,
    cloud_api_enabled BOOLEAN NOT NULL DEFAULT true,
    automatic_failover_enabled BOOLEAN NOT NULL DEFAULT false, -- Disabled by default
    last_provider_change_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_provider_change_reason TEXT,
    manual_override BOOLEAN NOT NULL DEFAULT false,
    manual_provider TEXT,
    CONSTRAINT check_singleton_provider CHECK (id = 'singleton')
);

-- Seed provider runtime
INSERT INTO public.message_provider_runtime (id) 
VALUES ('singleton') 
ON CONFLICT (id) DO NOTHING;

-- 3. Function to Acquire Worker Lease (transaction-safe, PgBouncer compatible)
CREATE OR REPLACE FUNCTION public.acquire_worker_lease(
    p_instance_id UUID,
    p_lease_duration_sec INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_lease record;
    v_now timestamptz := now();
    v_expired boolean;
BEGIN
    -- Obtain transaction-level row lock on the singleton lease record
    SELECT * INTO v_lease FROM public.worker_leases WHERE id = 'singleton' FOR UPDATE;
    
    -- Evaluate expiration
    v_expired := (v_lease.worker_instance_id IS NULL)
              OR (v_lease.worker_status IN ('STOPPED', 'IDLE'))
              OR (v_lease.last_heartbeat < v_now - (p_lease_duration_sec * INTERVAL '1 second'));
              
    -- Acquire or renew
    IF v_expired OR (v_lease.worker_instance_id = p_instance_id) THEN
        UPDATE public.worker_leases
        SET worker_instance_id = p_instance_id,
            worker_status = 'RUNNING',
            last_heartbeat = v_now,
            worker_started_at = CASE WHEN v_lease.worker_instance_id = p_instance_id THEN v_lease.worker_started_at ELSE v_now END
        WHERE id = 'singleton';
        
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Function to Release Worker Lease
CREATE OR REPLACE FUNCTION public.release_worker_lease(
    p_instance_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.worker_leases
    SET worker_status = 'IDLE',
        worker_instance_id = NULL
    WHERE id = 'singleton' AND worker_instance_id = p_instance_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Row Level Security Policies
ALTER TABLE public.worker_leases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_provider_runtime ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow service role to do everything on leases" ON public.worker_leases FOR ALL TO service_role USING (true);
CREATE POLICY "Allow service role to do everything on runtime" ON public.message_provider_runtime FOR ALL TO service_role USING (true);

CREATE POLICY "Allow authenticated read on leases" ON public.worker_leases FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read on runtime" ON public.message_provider_runtime FOR SELECT TO authenticated USING (true);

