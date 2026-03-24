-- ============================================================
-- Migration: 20260315_contatos_visitantes
-- Tabela de agenda de contatos de visitantes por morador
-- ============================================================

-- Limpar tabela anterior (caso exista com schema incorreto)
DROP TABLE IF EXISTS contatos_visitantes CASCADE;

CREATE TABLE contatos_visitantes (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        NOT NULL,
  condominio_id  UUID        NOT NULL,
  nome           TEXT        NOT NULL,
  celular        TEXT        NOT NULL,
  botconversa_id TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Evita duplicatas: mesmo morador + mesmo celular
CREATE UNIQUE INDEX IF NOT EXISTS idx_contatos_visitantes_unique
  ON contatos_visitantes(user_id, celular);

CREATE INDEX IF NOT EXISTS idx_contatos_visitantes_user
  ON contatos_visitantes(user_id);

CREATE INDEX IF NOT EXISTS idx_contatos_visitantes_condo
  ON contatos_visitantes(condominio_id);

-- ═══════════════════════════════════════════════════════════
--  RLS
-- ═══════════════════════════════════════════════════════════

ALTER TABLE contatos_visitantes ENABLE ROW LEVEL SECURITY;

-- Morador: CRUD apenas dos seus próprios contatos
DROP POLICY IF EXISTS "user_crud_contatos_visitantes" ON contatos_visitantes;
CREATE POLICY "user_crud_contatos_visitantes"
ON contatos_visitantes FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Service role: acesso total (para Edge Functions)
DROP POLICY IF EXISTS "service_all_contatos_visitantes" ON contatos_visitantes;
CREATE POLICY "service_all_contatos_visitantes"
ON contatos_visitantes FOR ALL TO service_role
USING (true)
WITH CHECK (true);
