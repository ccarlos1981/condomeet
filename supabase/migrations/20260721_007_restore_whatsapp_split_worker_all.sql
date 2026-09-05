-- =============================================================================
-- Migration: 20260721_007_restore_whatsapp_split_worker_all
-- Description: Rollback migration for Phase 2 Decommissioning.
--              Restores 'singleton' lease lock and backward compatibility functions.
-- =============================================================================

-- 1. Restore 'singleton' lease in worker_leases
INSERT INTO public.worker_leases (id, worker_status, worker_instance_id)
VALUES ('singleton', 'IDLE', NULL)
ON CONFLICT (id) DO NOTHING;

-- 2. Restore overloaded version of acquire_worker_lease (backward compatibility)
CREATE OR REPLACE FUNCTION public.acquire_worker_lease(
    p_instance_id UUID,
    p_lease_duration_sec INT
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.acquire_worker_lease(p_instance_id, p_lease_duration_sec, 'singleton');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Restore overloaded version of release_worker_lease (backward compatibility)
CREATE OR REPLACE FUNCTION public.release_worker_lease(
    p_instance_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.release_worker_lease(p_instance_id, 'singleton');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Restore overloaded version of claim_single_whatsapp_message (backward compatibility)
CREATE OR REPLACE FUNCTION public.claim_single_whatsapp_message()
RETURNS SETOF public.whatsapp_outbox AS $$
BEGIN
  RETURN QUERY SELECT * FROM public.claim_single_whatsapp_message(1, 99);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
