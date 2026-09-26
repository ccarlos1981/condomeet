-- ==============================================================================
-- Migration: 20260925201500_evolve_unidade_perfil_history_index.sql
-- Module: Base Cadastral Unificada (Gate 3C.3)
-- Purpose: Evolve unidade_perfil from static UNIQUE(perfil_id, unidade_id)
--          to partial UNIQUE index on active links, allowing multiple historical
--          occupancy cycles for the same person in the same unit.
-- ==============================================================================

-- 1. Drop the legacy static unique constraint that blocks historical re-entry
ALTER TABLE public.unidade_perfil 
DROP CONSTRAINT IF EXISTS unidade_perfil_perfil_id_unidade_id_key;

-- 2. Create partial unique index ensuring AT MOST ONE active link per (perfil_id, unidade_id)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unidade_perfil_unique_active 
ON public.unidade_perfil (perfil_id, unidade_id) 
WHERE (status = 'ativo');

-- 3. Document table evolution
COMMENT ON INDEX public.idx_unidade_perfil_unique_active IS 
'Enforces at most one active occupancy link per person and unit, while allowing unlimited inactive historical cycles.';
