-- Habilita RLS na tabela ocorrencias
ALTER TABLE ocorrencias ENABLE ROW LEVEL SECURITY;

-- 1. Morador pode inserir suas próprias ocorrências
DROP POLICY IF EXISTS "Resident can insert own occurrence" ON ocorrencias;
CREATE POLICY "Resident can insert own occurrence"
  ON ocorrencias
  FOR INSERT
  WITH CHECK (
    resident_id = auth.uid()
    AND condominium_id IN (
      SELECT condominio_id FROM perfil WHERE id = auth.uid()
    )
  );

-- 2. Morador pode ver suas próprias ocorrências
DROP POLICY IF EXISTS "Resident can view own occurrences" ON ocorrencias;
CREATE POLICY "Resident can view own occurrences"
  ON ocorrencias
  FOR SELECT
  USING (
    resident_id = auth.uid()
    OR condominium_id IN (
      SELECT condominio_id FROM perfil
      WHERE id = auth.uid()
      AND papel_sistema IN ('ADMIN', 'Síndico', 'síndico', 'Sindico', 'sindico')
    )
  );

-- 3. Admin/Síndico pode atualizar (responder) qualquer ocorrência do condomínio
DROP POLICY IF EXISTS "Admin can update occurrences" ON ocorrencias;
CREATE POLICY "Admin can update occurrences"
  ON ocorrencias
  FOR UPDATE
  USING (
    condominium_id IN (
      SELECT condominio_id FROM perfil
      WHERE id = auth.uid()
      AND papel_sistema IN ('ADMIN', 'Síndico', 'síndico', 'Sindico', 'sindico')
    )
  );

-- 4. Morador pode atualizar as próprias ocorrências (caso precise editar)
DROP POLICY IF EXISTS "Resident can update own occurrence" ON ocorrencias;
CREATE POLICY "Resident can update own occurrence"
  ON ocorrencias
  FOR UPDATE
  USING (resident_id = auth.uid());
