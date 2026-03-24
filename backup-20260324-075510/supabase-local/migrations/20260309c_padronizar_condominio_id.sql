-- ====================================================
-- Migration: Padronizar condominium_id → condominio_id
-- Tabelas afetadas: ocorrencias, sos_alertas
-- ====================================================

-- ── ocorrencias ───────────────────────────────────────

-- 1. Remover políticas RLS antigas (referenciam condominium_id)
DROP POLICY IF EXISTS "Resident can view own occurrences" ON ocorrencias;
DROP POLICY IF EXISTS "Resident can insert own occurrences" ON ocorrencias;
DROP POLICY IF EXISTS "Admin can update occurrences" ON ocorrencias;

-- 2. Renomear coluna
ALTER TABLE ocorrencias RENAME COLUMN condominium_id TO condominio_id;

-- 3. Recriar políticas com nome correto
CREATE POLICY "Resident can view own occurrences"
  ON ocorrencias
  FOR SELECT
  USING (
    resident_id = auth.uid()
    OR condominio_id IN (
      SELECT condominio_id FROM perfil
      WHERE id = auth.uid()
        AND papel_sistema IN ('ADMIN', 'Síndico', 'síndico', 'Sindico', 'sindico', 'admin')
    )
  );

CREATE POLICY "Resident can insert own occurrences"
  ON ocorrencias
  FOR INSERT
  WITH CHECK (resident_id = auth.uid());

CREATE POLICY "Admin can update occurrences"
  ON ocorrencias
  FOR UPDATE
  USING (
    condominio_id IN (
      SELECT condominio_id FROM perfil
      WHERE id = auth.uid()
        AND papel_sistema IN ('ADMIN', 'Síndico', 'síndico', 'Sindico', 'sindico', 'admin')
    )
  );

-- ── sos_alertas ───────────────────────────────────────

-- 1. Remover políticas RLS antigas
DROP POLICY IF EXISTS "Users can view SOS alerts in their condo" ON sos_alertas;
DROP POLICY IF EXISTS "Residents can create SOS alerts" ON sos_alertas;
DROP POLICY IF EXISTS "Residents can view own SOS alerts" ON sos_alertas;

-- 2. Renomear coluna
ALTER TABLE sos_alertas RENAME COLUMN condominium_id TO condominio_id;

-- 3. Recriar políticas com nome correto
CREATE POLICY "Residents can create SOS alerts"
  ON sos_alertas
  FOR INSERT
  WITH CHECK (resident_id = auth.uid());

CREATE POLICY "Users can view SOS alerts in their condo"
  ON sos_alertas
  FOR SELECT
  USING (
    condominio_id IN (
      SELECT condominio_id FROM perfil WHERE id = auth.uid()
    )
  );

CREATE POLICY "Admin can update SOS alerts"
  ON sos_alertas
  FOR UPDATE
  USING (
    condominio_id IN (
      SELECT condominio_id FROM perfil
      WHERE id = auth.uid()
        AND papel_sistema IN ('ADMIN', 'Síndico', 'síndico', 'Sindico', 'sindico', 'admin')
    )
  );
