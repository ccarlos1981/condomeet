-- ============================================================
-- Migration: 20260323_visita_proprietario
-- Tabela para Registro de Entrada/Saída de Moradores (Portaria)
-- ============================================================

CREATE TABLE IF NOT EXISTS visita_proprietario (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id     UUID        NOT NULL,
  tipo              TEXT        NOT NULL CHECK (tipo IN ('entrada', 'saida')),
  morador_id        UUID,
  nome_morador      TEXT        NOT NULL,
  bloco             TEXT,
  apto              TEXT,
  cracha_referencia  TEXT,
  registrado_por    UUID,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Indexes ─────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_visita_prop_condo ON visita_proprietario(condominio_id);
CREATE INDEX IF NOT EXISTS idx_visita_prop_tipo ON visita_proprietario(tipo);
CREATE INDEX IF NOT EXISTS idx_visita_prop_created ON visita_proprietario(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_visita_prop_morador ON visita_proprietario(morador_id);
CREATE INDEX IF NOT EXISTS idx_visita_prop_bloco_apto ON visita_proprietario(bloco, apto);

-- ── RLS ─────────────────────────────────────────────────────
ALTER TABLE visita_proprietario ENABLE ROW LEVEL SECURITY;

-- Porteiro: full CRUD within own condo
DROP POLICY IF EXISTS "porteiro_crud_visita_proprietario" ON visita_proprietario;
CREATE POLICY "porteiro_crud_visita_proprietario"
ON visita_proprietario FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = visita_proprietario.condominio_id
      AND p.papel_sistema IN ('Portaria', 'Porteiro', 'portaria', 'porteiro', 'Porteiro (a)')
  )
);

-- Admin/Síndico: full access within own condo
DROP POLICY IF EXISTS "admin_select_visita_proprietario" ON visita_proprietario;
CREATE POLICY "admin_select_visita_proprietario"
ON visita_proprietario FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = visita_proprietario.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
  )
);

-- Morador: SELECT only for their own unit (bloco + apto)
DROP POLICY IF EXISTS "morador_select_visita_proprietario" ON visita_proprietario;
CREATE POLICY "morador_select_visita_proprietario"
ON visita_proprietario FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = visita_proprietario.condominio_id
      AND p.bloco_txt = visita_proprietario.bloco
      AND p.apto_txt = visita_proprietario.apto
  )
);
