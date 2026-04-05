-- Migration: Manutenções

-- ============================================================
-- 1. manutencoes — main maintenance record
-- ============================================================
CREATE TABLE IF NOT EXISTS public.manutencoes (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id     UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  autor_id          UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
  fornecedor_id     UUID, -- Para futuro relacionamento
  titulo            TEXT NOT NULL,
  descricao         TEXT,
  tipo              TEXT NOT NULL,
  status            TEXT NOT NULL,
  data_inicio       TIMESTAMPTZ,
  data_fim          TIMESTAMPTZ,
  visivel_moradores BOOLEAN NOT NULL DEFAULT false,
  valor             NUMERIC(12,2),
  recorrencia       TEXT NOT NULL DEFAULT 'Nenhuma',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.manutencoes ENABLE ROW LEVEL SECURITY;

-- ADMIN can manage their condo's maintenances
CREATE POLICY "admin_manage_manutencoes"
  ON public.manutencoes
  USING (
    condominio_id IN (
      SELECT condominio_id FROM public.perfil
      WHERE id = auth.uid()
        AND papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  )
  WITH CHECK (
    condominio_id IN (
      SELECT condominio_id FROM public.perfil
      WHERE id = auth.uid()
        AND papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  );

-- RESIDENT can read if it is visible
CREATE POLICY "resident_read_manutencoes"
  ON public.manutencoes FOR SELECT
  USING (
    visivel_moradores = true
    AND condominio_id IN (
      SELECT condominio_id FROM public.perfil WHERE id = auth.uid()
    )
  );

-- ============================================================
-- 2. manutencao_fotos
-- ============================================================
CREATE TABLE IF NOT EXISTS public.manutencao_fotos (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  manutencao_id UUID NOT NULL REFERENCES public.manutencoes(id) ON DELETE CASCADE,
  imagem_url    TEXT NOT NULL,
  ordem         SMALLINT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.manutencao_fotos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_manage_manutencao_fotos"
  ON public.manutencao_fotos
  USING (
    manutencao_id IN (
      SELECT m.id FROM public.manutencoes m
      JOIN public.perfil p ON p.condominio_id = m.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  )
  WITH CHECK (
    manutencao_id IN (
      SELECT m.id FROM public.manutencoes m
      JOIN public.perfil p ON p.condominio_id = m.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  );

CREATE POLICY "resident_read_manutencao_fotos"
  ON public.manutencao_fotos FOR SELECT
  USING (
    manutencao_id IN (
      SELECT id FROM public.manutencoes
      WHERE visivel_moradores = true 
        AND condominio_id IN (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
    )
  );

-- ============================================================
-- 3. manutencao_comentarios
-- ============================================================
CREATE TABLE IF NOT EXISTS public.manutencao_comentarios (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  manutencao_id UUID NOT NULL REFERENCES public.manutencoes(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
  conteudo      TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.manutencao_comentarios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_insert_manutencao_comentario"
  ON public.manutencao_comentarios FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND (
      manutencao_id IN (
        SELECT id FROM public.manutencoes
        WHERE visivel_moradores = true
          AND condominio_id IN (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
      )
      OR
      manutencao_id IN (
        SELECT m.id FROM public.manutencoes m
        JOIN public.perfil p ON p.condominio_id = m.condominio_id
        WHERE p.id = auth.uid()
          AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
      )
    )
  );

CREATE POLICY "everyone_read_manutencao_comentario"
  ON public.manutencao_comentarios FOR SELECT
  USING (
    manutencao_id IN (
      SELECT id FROM public.manutencoes
      WHERE visivel_moradores = true
        AND condominio_id IN (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
    )
    OR
    manutencao_id IN (
      SELECT m.id FROM public.manutencoes m
      JOIN public.perfil p ON p.condominio_id = m.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  );

CREATE POLICY "user_delete_manutencao_comentarios"
  ON public.manutencao_comentarios FOR DELETE
  USING (user_id = auth.uid());

CREATE POLICY "admin_delete_manutencao_comentarios"
  ON public.manutencao_comentarios FOR DELETE
  USING (
    manutencao_id IN (
      SELECT m.id FROM public.manutencoes m
      JOIN public.perfil p ON p.condominio_id = m.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  );

-- ============================================================
-- 4. Triggers & Indexes
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_manutencoes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_manutencoes_updated_at
  BEFORE UPDATE ON public.manutencoes
  FOR EACH ROW EXECUTE FUNCTION public.update_manutencoes_updated_at();

CREATE INDEX IF NOT EXISTS idx_manutencoes_condominio ON public.manutencoes (condominio_id, data_inicio DESC);
CREATE INDEX IF NOT EXISTS idx_manutencao_fotos_manutencao ON public.manutencao_fotos (manutencao_id, ordem);
CREATE INDEX IF NOT EXISTS idx_manutencao_comentarios_manutencao ON public.manutencao_comentarios (manutencao_id, created_at);

-- ============================================================
-- 5. Storage Bucket
-- ============================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('manutencoes', 'manutencoes', true) 
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "admin_manage_manutencoes_bucket"
ON storage.objects FOR ALL TO authenticated
USING (
  bucket_id = 'manutencoes'
  AND EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
  )
);

CREATE POLICY "authenticated_view_manutencoes_bucket"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'manutencoes');
