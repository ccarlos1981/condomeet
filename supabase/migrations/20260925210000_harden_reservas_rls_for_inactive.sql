-- ==============================================================================
-- Migration: 20260925210000_harden_reservas_rls_for_inactive.sql
-- Module: Base Cadastral Unificada / Reservas (Gate 3C.4)
-- Purpose: Harden RLS on public.reservas so that inactive or blocked profiles
--          cannot create or mutate bookings even if possessing an unexpired JWT.
--          Reading historical bookings remains permitted via USING clause.
-- ==============================================================================

DROP POLICY IF EXISTS "resident_own_reservas" ON "public"."reservas";

CREATE POLICY "resident_own_reservas" ON "public"."reservas"
FOR ALL TO public
USING (user_id = (SELECT auth.uid() AS uid))
WITH CHECK (
  (user_id = (SELECT auth.uid() AS uid))
  AND EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = (SELECT auth.uid() AS uid)
      AND p.status_aprovacao = 'aprovado'
      AND COALESCE(p.bloqueado, false) = false
  )
);
