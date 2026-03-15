-- ============================================================
-- Migration: 20260313_enquetes
-- Tabelas para Enquetes (Surveys/Polls) do Condomínio
-- ============================================================

-- ── enquetes: a enquete em si ──────────────────────────────
CREATE TABLE IF NOT EXISTS enquetes (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID        NOT NULL,
  pergunta      TEXT        NOT NULL,
  tipo_resposta TEXT        NOT NULL DEFAULT 'unica',  -- 'unica' | 'multipla'
  ativa         BOOLEAN     DEFAULT false,
  validade      DATE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_enquetes_condo ON enquetes(condominio_id);

-- ── enquete_opcoes: opções de resposta ─────────────────────
CREATE TABLE IF NOT EXISTS enquete_opcoes (
  id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  enquete_id  UUID    NOT NULL REFERENCES enquetes(id) ON DELETE CASCADE,
  texto       TEXT    NOT NULL,
  ordem       INT     DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_enquete_opcoes_enquete ON enquete_opcoes(enquete_id);

-- ── enquete_respostas: respostas dos moradores ─────────────
CREATE TABLE IF NOT EXISTS enquete_respostas (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  enquete_id  UUID        NOT NULL REFERENCES enquetes(id) ON DELETE CASCADE,
  opcao_id    UUID        NOT NULL REFERENCES enquete_opcoes(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL,
  bloco       TEXT,
  apto        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_enquete_respostas_enquete ON enquete_respostas(enquete_id);
CREATE INDEX IF NOT EXISTS idx_enquete_respostas_user ON enquete_respostas(user_id);

-- Prevent duplicate votes (same user, same option)
CREATE UNIQUE INDEX IF NOT EXISTS idx_enquete_resp_unique
  ON enquete_respostas(enquete_id, opcao_id, user_id);

-- For 'unica' type: prevent multiple options per user per enquete
-- (enforced at application level since multipla allows multiple)

-- ═══════════════════════════════════════════════════════════
--  RLS
-- ═══════════════════════════════════════════════════════════

-- ── enquetes ───────────────────────────────────────────────
ALTER TABLE enquetes ENABLE ROW LEVEL SECURITY;

-- Admin: full CRUD
DROP POLICY IF EXISTS "admin_crud_enquetes" ON enquetes;
CREATE POLICY "admin_crud_enquetes"
ON enquetes FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = enquetes.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
  )
);

-- Moradores: SELECT only active enquetes
DROP POLICY IF EXISTS "morador_select_enquetes" ON enquetes;
CREATE POLICY "morador_select_enquetes"
ON enquetes FOR SELECT TO authenticated
USING (
  enquetes.ativa = true
  AND EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = enquetes.condominio_id
  )
);

-- ── enquete_opcoes ─────────────────────────────────────────
ALTER TABLE enquete_opcoes ENABLE ROW LEVEL SECURITY;

-- Admin: full CRUD via enquete ownership
DROP POLICY IF EXISTS "admin_crud_enquete_opcoes" ON enquete_opcoes;
CREATE POLICY "admin_crud_enquete_opcoes"
ON enquete_opcoes FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM enquetes e
    JOIN perfil p ON p.id = auth.uid()
      AND p.condominio_id = e.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
    WHERE e.id = enquete_opcoes.enquete_id
  )
);

-- Moradores: SELECT options for active enquetes
DROP POLICY IF EXISTS "morador_select_enquete_opcoes" ON enquete_opcoes;
CREATE POLICY "morador_select_enquete_opcoes"
ON enquete_opcoes FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM enquetes e
    JOIN perfil p ON p.id = auth.uid() AND p.condominio_id = e.condominio_id
    WHERE e.id = enquete_opcoes.enquete_id
      AND e.ativa = true
  )
);

-- ── enquete_respostas ──────────────────────────────────────
ALTER TABLE enquete_respostas ENABLE ROW LEVEL SECURITY;

-- Admin: SELECT all responses for their condo
DROP POLICY IF EXISTS "admin_select_enquete_respostas" ON enquete_respostas;
CREATE POLICY "admin_select_enquete_respostas"
ON enquete_respostas FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM enquetes e
    JOIN perfil p ON p.id = auth.uid()
      AND p.condominio_id = e.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
    WHERE e.id = enquete_respostas.enquete_id
  )
);

-- Moradores: INSERT own response + SELECT own responses
DROP POLICY IF EXISTS "morador_insert_enquete_respostas" ON enquete_respostas;
CREATE POLICY "morador_insert_enquete_respostas"
ON enquete_respostas FOR INSERT TO authenticated
WITH CHECK (
  enquete_respostas.user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM enquetes e
    JOIN perfil p ON p.id = auth.uid() AND p.condominio_id = e.condominio_id
    WHERE e.id = enquete_respostas.enquete_id
      AND e.ativa = true
  )
);

DROP POLICY IF EXISTS "morador_select_own_respostas" ON enquete_respostas;
CREATE POLICY "morador_select_own_respostas"
ON enquete_respostas FOR SELECT TO authenticated
USING (
  enquete_respostas.user_id = auth.uid()
);
