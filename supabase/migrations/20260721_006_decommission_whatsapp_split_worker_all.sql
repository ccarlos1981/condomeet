-- =============================================================================
-- Migration: 20260721_006_decommission_whatsapp_split_worker_all
-- Description: Expurge legacy functions and 'singleton' worker lease.
--              Consolidates queue=high and queue=low as the only operational modes.
-- =============================================================================

-- 1. Remove the lease singleton from worker_leases
DELETE FROM public.worker_leases WHERE id = 'singleton';

-- 2. Remove overloaded legacy functions (no parameters for lease or bounds)
DROP FUNCTION IF EXISTS public.acquire_worker_lease(UUID, INT);
DROP FUNCTION IF EXISTS public.release_worker_lease(UUID);
DROP FUNCTION IF EXISTS public.claim_single_whatsapp_message();
