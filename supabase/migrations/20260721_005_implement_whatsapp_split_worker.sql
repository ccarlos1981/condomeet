-- =================================================================
-- Migration: 20260721_005_implement_whatsapp_split_worker
-- Description: Expand worker leases, parameterize lease locks and outbox claims.
--              Maintains full backward compatibility using function overloading.
-- =================================================================

-- 1. Drop check constraint and Insert New Leases for Split-Worker Channels
ALTER TABLE public.worker_leases DROP CONSTRAINT IF EXISTS check_singleton_lease;

INSERT INTO public.worker_leases (id, worker_status, worker_instance_id)
VALUES 
  ('high_priority', 'IDLE', NULL),
  ('low_priority', 'IDLE', NULL)
ON CONFLICT (id) DO NOTHING;

-- 2. Parameterized Version of acquire_worker_lease (Supports custom lease IDs)
CREATE OR REPLACE FUNCTION public.acquire_worker_lease(
    p_instance_id UUID,
    p_lease_duration_sec INT,
    p_lease_id TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_lease record;
    v_now timestamptz := now();
    v_expired boolean;
BEGIN
    -- Obtain transaction-level row lock on the specified lease record
    SELECT * INTO v_lease FROM public.worker_leases WHERE id = p_lease_id FOR UPDATE;
    
    -- If lease ID does not exist, return false
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
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
        WHERE id = p_lease_id;
        
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Overloaded version for backward compatibility (defaults to 'singleton')
CREATE OR REPLACE FUNCTION public.acquire_worker_lease(
    p_instance_id UUID,
    p_lease_duration_sec INT
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.acquire_worker_lease(p_instance_id, p_lease_duration_sec, 'singleton');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Parameterized Version of release_worker_lease (Supports custom lease IDs)
CREATE OR REPLACE FUNCTION public.release_worker_lease(
    p_instance_id UUID,
    p_lease_id TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.worker_leases
    SET worker_status = 'IDLE',
        worker_instance_id = NULL
    WHERE id = p_lease_id AND worker_instance_id = p_instance_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Overloaded version for backward compatibility (defaults to 'singleton')
CREATE OR REPLACE FUNCTION public.release_worker_lease(
    p_instance_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.release_worker_lease(p_instance_id, 'singleton');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Parameterized Version of claim_single_whatsapp_message (Supports priority bounds)
CREATE OR REPLACE FUNCTION public.claim_single_whatsapp_message(
    p_min_priority INT,
    p_max_priority INT
)
RETURNS SETOF public.whatsapp_outbox AS $$
DECLARE
  v_rec public.whatsapp_outbox;
BEGIN
  -- Obtain a short-lived transaction-level advisory lock to ensure serialization
  -- during the select-update phase
  PERFORM pg_advisory_xact_lock(998878);

  RETURN QUERY
  UPDATE public.whatsapp_outbox
  SET status = 'sending',
      processing_started_at = now()
  WHERE id = (
      SELECT id 
      FROM public.whatsapp_outbox
      WHERE status = 'pending' 
        AND priority >= p_min_priority
        AND priority <= p_max_priority
        AND next_attempt_at <= now()
      ORDER BY priority ASC, created_at ASC
      LIMIT 1
      FOR UPDATE SKIP LOCKED
  )
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Overloaded version for backward compatibility (claims all priorities [1, 99])
CREATE OR REPLACE FUNCTION public.claim_single_whatsapp_message()
RETURNS SETOF public.whatsapp_outbox AS $$
BEGIN
  RETURN QUERY SELECT * FROM public.claim_single_whatsapp_message(1, 99);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
