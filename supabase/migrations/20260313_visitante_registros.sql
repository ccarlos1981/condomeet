-- ============================================================
-- Migration: 20260313_visitante_registros
-- Tabela para Registro de Visitantes na Portaria
-- ============================================================

CREATE TABLE IF NOT EXISTS visitante_registros (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id   UUID        NOT NULL,
  nome            TEXT        NOT NULL,
  cpf_rg          TEXT,
  whatsapp        TEXT,
  tipo_visitante  TEXT,
  empresa         TEXT,
  bloco           TEXT,
  apto            TEXT,
  observacao      TEXT,
  foto_url        TEXT,
  entrada_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  saida_at        TIMESTAMPTZ,
  registrado_por  UUID,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_visitante_reg_condo ON visitante_registros(condominio_id);
CREATE INDEX IF NOT EXISTS idx_visitante_reg_cpf ON visitante_registros(cpf_rg);
CREATE INDEX IF NOT EXISTS idx_visitante_reg_entrada ON visitante_registros(entrada_at DESC);

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE visitante_registros ENABLE ROW LEVEL SECURITY;

-- Porteiro: full CRUD
DROP POLICY IF EXISTS "porteiro_crud_visitante_registros" ON visitante_registros;
CREATE POLICY "porteiro_crud_visitante_registros"
ON visitante_registros FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = visitante_registros.condominio_id
      AND p.papel_sistema IN ('Portaria', 'Porteiro', 'portaria', 'porteiro', 'Porteiro (a)')
  )
);

-- Admin: SELECT
DROP POLICY IF EXISTS "admin_select_visitante_registros" ON visitante_registros;
CREATE POLICY "admin_select_visitante_registros"
ON visitante_registros FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = visitante_registros.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
  )
);
