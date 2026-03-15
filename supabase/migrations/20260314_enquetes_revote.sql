-- ============================================================
-- Migration: 20260314_enquetes_revote
-- Adds: DELETE policy for re-voting, SELECT policy for chart data
-- ============================================================

-- Allow residents to DELETE their own responses (for re-voting)
DROP POLICY IF EXISTS "morador_delete_enquete_respostas" ON enquete_respostas;
CREATE POLICY "morador_delete_enquete_respostas"
ON enquete_respostas FOR DELETE TO authenticated
USING (
  enquete_respostas.user_id = auth.uid()
);

-- Allow residents to see ALL responses for enquetes in their condomínio (for chart)
DROP POLICY IF EXISTS "morador_select_own_respostas" ON enquete_respostas;
CREATE POLICY "morador_select_condo_respostas"
ON enquete_respostas FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM enquetes e
    JOIN perfil p ON p.id = auth.uid() AND p.condominio_id = e.condominio_id
    WHERE e.id = enquete_respostas.enquete_id
  )
);

-- Drop the old unique index (was per user+option)
DROP INDEX IF EXISTS idx_enquete_resp_unique;

-- New unique index: per unit (bloco+apto) per option per enquete
-- This prevents the same unit from having duplicate entries for the same option
CREATE UNIQUE INDEX IF NOT EXISTS idx_enquete_resp_unit_unique
  ON enquete_respostas(enquete_id, opcao_id, bloco, apto);
