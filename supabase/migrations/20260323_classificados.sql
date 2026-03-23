-- ============================================================
-- Migration: 20260323_classificados
-- Sistema de Classificados (Marketplace) do Condomínio
-- ============================================================

-- ── Tabela principal ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS classificados (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id   UUID        NOT NULL,
  criado_por      UUID        NOT NULL,
  titulo          TEXT        NOT NULL,
  descricao       TEXT,
  categoria       TEXT        NOT NULL CHECK (categoria IN (
    'eletronicos', 'moveis', 'roupas', 'veiculos',
    'servicos', 'imoveis', 'carros_e_pecas', 'outros'
  )),
  marca_modelo    TEXT,
  preco           DECIMAL(10,2),
  condicao        TEXT        CHECK (condicao IN ('novo', 'usado')),
  mostrar_telefone BOOLEAN    DEFAULT true,
  foto_url        TEXT,
  status          TEXT        NOT NULL DEFAULT 'pendente' CHECK (status IN (
    'pendente', 'aprovado', 'rejeitado', 'vendido', 'expirado'
  )),
  aprovado_por    UUID,
  aprovado_em     TIMESTAMPTZ,
  expira_em       TIMESTAMPTZ,
  cod_interno     TEXT        NOT NULL DEFAULT substr(md5(random()::text), 1, 5),
  visualizacoes   INT         NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Tabela de favoritos ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS classificados_favoritos (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  classificado_id UUID        NOT NULL REFERENCES classificados(id) ON DELETE CASCADE,
  usuario_id      UUID        NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(classificado_id, usuario_id)
);

-- ── Indexes ─────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_class_condo       ON classificados(condominio_id);
CREATE INDEX IF NOT EXISTS idx_class_status      ON classificados(status);
CREATE INDEX IF NOT EXISTS idx_class_categoria   ON classificados(categoria);
CREATE INDEX IF NOT EXISTS idx_class_criado_por  ON classificados(criado_por);
CREATE INDEX IF NOT EXISTS idx_class_expira_em   ON classificados(expira_em);
CREATE INDEX IF NOT EXISTS idx_class_created     ON classificados(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_class_fav_user    ON classificados_favoritos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_class_fav_class   ON classificados_favoritos(classificado_id);

-- ── RLS — classificados ─────────────────────────────────────
ALTER TABLE classificados ENABLE ROW LEVEL SECURITY;

-- Morador: SELECT anúncios aprovados do próprio condomínio
DROP POLICY IF EXISTS "morador_select_classificados" ON classificados;
CREATE POLICY "morador_select_classificados"
ON classificados FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = classificados.condominio_id
  )
);

-- Morador: INSERT próprios anúncios
DROP POLICY IF EXISTS "morador_insert_classificados" ON classificados;
CREATE POLICY "morador_insert_classificados"
ON classificados FOR INSERT TO authenticated
WITH CHECK (
  criado_por = auth.uid()
  AND EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = classificados.condominio_id
  )
);

-- Morador: UPDATE/DELETE apenas próprios anúncios
DROP POLICY IF EXISTS "morador_update_classificados" ON classificados;
CREATE POLICY "morador_update_classificados"
ON classificados FOR UPDATE TO authenticated
USING (
  criado_por = auth.uid()
)
WITH CHECK (
  criado_por = auth.uid()
);

DROP POLICY IF EXISTS "morador_delete_classificados" ON classificados;
CREATE POLICY "morador_delete_classificados"
ON classificados FOR DELETE TO authenticated
USING (
  criado_por = auth.uid()
);

-- Síndico/Admin: UPDATE todos do condomínio (para aprovar/rejeitar)
DROP POLICY IF EXISTS "admin_update_classificados" ON classificados;
CREATE POLICY "admin_update_classificados"
ON classificados FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = classificados.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
  )
);

-- ── RLS — classificados_favoritos ───────────────────────────
ALTER TABLE classificados_favoritos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_manage_favoritos" ON classificados_favoritos;
CREATE POLICY "user_manage_favoritos"
ON classificados_favoritos FOR ALL TO authenticated
USING (
  usuario_id = auth.uid()
)
WITH CHECK (
  usuario_id = auth.uid()
);

-- Permitir SELECT de favoritos para contar totais
DROP POLICY IF EXISTS "user_select_all_favoritos" ON classificados_favoritos;
CREATE POLICY "user_select_all_favoritos"
ON classificados_favoritos FOR SELECT TO authenticated
USING (true);

-- ── Trigger para atualizar updated_at ───────────────────────
CREATE OR REPLACE FUNCTION update_classificados_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  -- Auto-set expira_em quando aprovado
  IF NEW.status = 'aprovado' AND (OLD.status IS NULL OR OLD.status != 'aprovado') THEN
    NEW.aprovado_em = NOW();
    NEW.expira_em = NOW() + INTERVAL '60 days';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_classificados_updated_at ON classificados;
CREATE TRIGGER trg_classificados_updated_at
BEFORE UPDATE ON classificados
FOR EACH ROW
EXECUTE FUNCTION update_classificados_updated_at();

-- ── Storage bucket ──────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('classificados-fotos', 'classificados-fotos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: authenticated users can upload
DROP POLICY IF EXISTS "auth_upload_classificados_fotos" ON storage.objects;
CREATE POLICY "auth_upload_classificados_fotos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'classificados-fotos');

DROP POLICY IF EXISTS "public_read_classificados_fotos" ON storage.objects;
CREATE POLICY "public_read_classificados_fotos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'classificados-fotos');

DROP POLICY IF EXISTS "auth_delete_classificados_fotos" ON storage.objects;
CREATE POLICY "auth_delete_classificados_fotos"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'classificados-fotos');
