-- ==============================================================================
-- Migration: 20260925200000_create_perfil_audit_log.sql
-- Module: Base Cadastral Unificada (Gate 3C.3)
-- Purpose: Create public.perfil_audit_log for administrative cadastral audit trail
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.perfil_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
    perfil_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
    operador_id UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
    unidade_id UUID REFERENCES public.unidades(id) ON DELETE SET NULL,
    acao TEXT NOT NULL,
    motivo TEXT NULL,
    estado_anterior JSONB DEFAULT '{}'::jsonb,
    estado_posterior JSONB DEFAULT '{}'::jsonb,
    ip_address INET NULL,
    user_agent TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for high-performance audit query by condominium, resident, and recency
CREATE INDEX IF NOT EXISTS idx_perfil_audit_log_lookup 
ON public.perfil_audit_log (condominio_id, perfil_id, created_at DESC);

-- Enable Row Level Security (Mandatory Invariant 2)
ALTER TABLE public.perfil_audit_log ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Only authorized administrators/síndicos of the same condominium can view audit logs
DROP POLICY IF EXISTS perfil_audit_log_admin_select ON public.perfil_audit_log;
CREATE POLICY perfil_audit_log_admin_select ON public.perfil_audit_log
FOR SELECT TO authenticated
USING (
    condominio_id IN (
        SELECT p.condominio_id 
        FROM public.perfil p 
        WHERE p.id = auth.uid() 
          AND LOWER(COALESCE(p.papel_sistema, '')) IN (
              'admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora'
          )
    )
);

-- Note on INSERT/UPDATE/DELETE: No public or client INSERT/UPDATE/DELETE policies are granted.
-- Cadastral mutations are written exclusively via vetted SECURITY DEFINER RPCs or service role.
