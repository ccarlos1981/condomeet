-- =================================================================
-- Migration: 20260707_create_whatsapp_outbox_schema
-- Objective: Setup Whatsapp Outbox Fila, Runtime Configuration, 
--            Unitary Claim Function, and log retention maintenance.
-- =================================================================

-- 1. Table for Runtime State, Heartbeat & Configuration
CREATE TABLE IF NOT EXISTS public.whatsapp_runtime (
    id TEXT PRIMARY KEY DEFAULT 'singleton',
    operational_mode TEXT NOT NULL DEFAULT 'NORMAL', -- 'NORMAL', 'SAFE_MODE', 'MAINTENANCE', 'DISABLED'
    circuit_state TEXT NOT NULL DEFAULT 'CLOSED', -- 'CLOSED', 'OPEN', 'HALF_OPEN'
    consecutive_failures INT NOT NULL DEFAULT 0,
    failure_threshold INT NOT NULL DEFAULT 5,
    last_failure_at TIMESTAMPTZ,
    last_reason TEXT,
    
    -- Active Worker Telemetry
    worker_status TEXT NOT NULL DEFAULT 'STOPPED', -- 'RUNNING', 'IDLE', 'STOPPED', 'CIRCUIT_OPEN'
    last_heartbeat TIMESTAMPTZ DEFAULT now(),
    worker_started_at TIMESTAMPTZ,
    worker_instance_id UUID,
    
    state_changed_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT check_singleton CHECK (id = 'singleton')
);

-- Seed runtime config singleton
INSERT INTO public.whatsapp_runtime (id) 
VALUES ('singleton') 
ON CONFLICT (id) DO NOTHING;

-- 2. Table for WhatsApp Outbox Queue & Audit Trail
CREATE TABLE IF NOT EXISTS public.whatsapp_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    recipient_phone TEXT NOT NULL,
    perfil_id UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
    condominio_id UUID REFERENCES public.condominios(id) ON DELETE SET NULL,
    message_type TEXT NOT NULL, -- 'text', 'file', 'interactive_buttons'
    message_content JSONB NOT NULL, -- Message specific details (text body, media url, etc)
    priority INT NOT NULL DEFAULT 10, -- 1: SOS/Visitor, 10: Encomenda/Boas-vindas, 20: Cron Reminders
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'sending', 'sent', 'failed', 'cancelled'
    error_message TEXT,
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 3,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processing_started_at TIMESTAMPTZ,
    last_attempt_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    message_hash TEXT NOT NULL,
    delivery_result JSONB
);

-- Trigger to update updated_at automatically on whatsapp_outbox
CREATE OR REPLACE FUNCTION public.set_whatsapp_outbox_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_set_whatsapp_outbox_updated_at
  BEFORE UPDATE ON public.whatsapp_outbox
  FOR EACH ROW
  EXECUTE FUNCTION public.set_whatsapp_outbox_updated_at();

-- 3. Unique Index for Deduplication of Pending Messages
CREATE UNIQUE INDEX IF NOT EXISTS idx_whatsapp_outbox_dedup_pending
ON public.whatsapp_outbox (message_hash)
WHERE status = 'pending';

-- Performance Indices
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_queue 
ON public.whatsapp_outbox(status, priority, next_attempt_at) 
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_stuck_recovery
ON public.whatsapp_outbox(status, processing_started_at)
WHERE status = 'sending';

-- 4. Unitary Claim function with concurrency protection (Row Lock & Advisory Lock)
CREATE OR REPLACE FUNCTION public.claim_single_whatsapp_message()
RETURNS SETOF public.whatsapp_outbox AS $$
DECLARE
  v_rec public.whatsapp_outbox;
BEGIN
  -- Obtain a short-lived transaction-level advisory lock to ensure serialization
  -- during the select-update phase (Lock ID: 998878 to avoid deadlock with worker session lock 998877)
  PERFORM pg_advisory_xact_lock(998878);

  RETURN QUERY
  UPDATE public.whatsapp_outbox
  SET status = 'sending',
      processing_started_at = now()
  WHERE id = (
      SELECT id 
      FROM public.whatsapp_outbox
      WHERE status = 'pending' 
        AND next_attempt_at <= now()
      ORDER BY priority ASC, created_at ASC
      LIMIT 1
      FOR UPDATE SKIP LOCKED
  )
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Outbox Log Retention Cleanup (Extended database maintenance)
CREATE OR REPLACE FUNCTION public.clean_old_botconversa_logs()
RETURNS void AS $$
BEGIN
  -- Cleanup old botconversa telemetry logs (30 days retention)
  DELETE FROM public.botconversa_monitoring 
  WHERE timestamp < now() - INTERVAL '30 days';

  -- Cleanup old final status outbox records (30 days retention)
  DELETE FROM public.whatsapp_outbox 
  WHERE status IN ('sent', 'failed', 'cancelled') 
    AND created_at < now() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC wrappers for Session Advisory Locks
CREATE OR REPLACE FUNCTION public.try_advisory_lock(lock_id bigint)
RETURNS boolean AS $$
BEGIN
  RETURN pg_try_advisory_lock(lock_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.unlock_advisory_lock(lock_id bigint)
RETURNS boolean AS $$
BEGIN
  RETURN pg_advisory_unlock(lock_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
