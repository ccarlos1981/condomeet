-- Migration: 20260320 - Change encomendas RLS to unit-based visibility
-- Moradores now see ALL parcels for their unit (bloco/apto), not just their own.
-- This allows all residents of the same apartment to see each other's parcels.

DROP POLICY IF EXISTS morador_select_proprias_encomendas ON public.encomendas;

CREATE POLICY morador_select_proprias_encomendas
ON public.encomendas
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
    AND p.condominio_id = encomendas.condominio_id
    AND (
      -- Unit-based matching: resident sees all parcels for their unit
      (
        p.bloco_txt IS NOT NULL AND p.apto_txt IS NOT NULL
        AND p.bloco_txt = encomendas.bloco
        AND p.apto_txt = encomendas.apto
      )
      -- Fallback: parcels directly assigned to this resident (e.g. legacy data)
      OR encomendas.resident_id = auth.uid()
    )
  )
);
