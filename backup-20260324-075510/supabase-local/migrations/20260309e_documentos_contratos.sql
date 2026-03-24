-- ============================================================
-- Documentos e Contratos — migration (idempotente)
-- ============================================================

-- ── 1. PASTAS DE DOCUMENTOS ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.doc_pastas (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  nome          TEXT        NOT NULL,
  observacao    TEXT,
  created_at    TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ── 2. DOCUMENTOS ────────────────────────────────────────────
-- Cria com colunas mínimas; as extras são adicionadas com ALTER abaixo
CREATE TABLE IF NOT EXISTS public.documentos (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  titulo        TEXT        NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Adiciona colunas extras (seguro se já existirem)
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS pasta_id          UUID        REFERENCES public.doc_pastas(id) ON DELETE SET NULL;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS categoria         TEXT;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS tipo              TEXT        NOT NULL DEFAULT 'obrigatorio';
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS arquivo_url       TEXT;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS arquivo_nome      TEXT;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS data_expedicao    DATE;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS data_validade     DATE;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS lembrar_30        BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS lembrar_60        BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS lembrar_90        BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS avisar_moradores  BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS mostrar_moradores BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS descricao         TEXT;

-- Garante constraint de tipo (ignora se já existir)
DO $$ BEGIN
  ALTER TABLE public.documentos ADD CONSTRAINT documentos_tipo_check
    CHECK (tipo IN ('obrigatorio','manutencao','outros'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_doc_pastas_condo ON public.doc_pastas(condominio_id);
CREATE INDEX IF NOT EXISTS idx_documentos_condo ON public.documentos(condominio_id);
CREATE INDEX IF NOT EXISTS idx_documentos_pasta ON public.documentos(pasta_id);

-- ── 3. PASTAS DE CONTRATOS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contrato_pastas (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  nome          TEXT        NOT NULL,
  observacao    TEXT,
  created_at    TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ── 4. CONTRATOS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contratos (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  titulo        TEXT        NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS pasta_id          UUID        REFERENCES public.contrato_pastas(id) ON DELETE SET NULL;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS categoria         TEXT;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS tipo              TEXT        NOT NULL DEFAULT 'obrigatorio';
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS arquivo_url       TEXT;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS arquivo_nome      TEXT;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS data_expedicao    DATE;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS data_validade     DATE;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS lembrar_30        BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS lembrar_60        BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS lembrar_90        BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS avisar_moradores  BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS mostrar_moradores BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE public.contratos ADD COLUMN IF NOT EXISTS descricao         TEXT;

DO $$ BEGIN
  ALTER TABLE public.contratos ADD CONSTRAINT contratos_tipo_check
    CHECK (tipo IN ('obrigatorio','manutencao','outros'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_contrato_pastas_condo ON public.contrato_pastas(condominio_id);
CREATE INDEX IF NOT EXISTS idx_contratos_condo       ON public.contratos(condominio_id);
CREATE INDEX IF NOT EXISTS idx_contratos_pasta       ON public.contratos(pasta_id);

-- ── 5. RLS ───────────────────────────────────────────────────
ALTER TABLE public.doc_pastas      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documentos      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contrato_pastas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contratos       ENABLE ROW LEVEL SECURITY;

-- Helper
CREATE OR REPLACE FUNCTION public._is_admin_or_sindico()
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid())
         IN ('ADMIN','Síndico','Síndico (a)','sindico')
  OR (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid()) ILIKE '%sindico%';
$$;

-- doc_pastas
DROP POLICY IF EXISTS "admin_doc_pastas_all"  ON public.doc_pastas;
DROP POLICY IF EXISTS "morador_ve_doc_pastas" ON public.doc_pastas;

CREATE POLICY "admin_doc_pastas_all" ON public.doc_pastas
  FOR ALL USING (public._is_admin_or_sindico()
    AND condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid()));

CREATE POLICY "morador_ve_doc_pastas" ON public.doc_pastas
  FOR SELECT USING (
    condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.documentos d
      WHERE d.pasta_id = doc_pastas.id AND d.mostrar_moradores = true
    )
  );

-- documentos
DROP POLICY IF EXISTS "admin_documentos_all"  ON public.documentos;
DROP POLICY IF EXISTS "morador_ve_documentos" ON public.documentos;

CREATE POLICY "admin_documentos_all" ON public.documentos
  FOR ALL USING (public._is_admin_or_sindico()
    AND condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid()));

CREATE POLICY "morador_ve_documentos" ON public.documentos
  FOR SELECT USING (
    mostrar_moradores = true
    AND condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
  );

-- contrato_pastas
DROP POLICY IF EXISTS "admin_contrato_pastas_all" ON public.contrato_pastas;

CREATE POLICY "admin_contrato_pastas_all" ON public.contrato_pastas
  FOR ALL USING (public._is_admin_or_sindico()
    AND condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid()));

-- contratos
DROP POLICY IF EXISTS "admin_contratos_all" ON public.contratos;

CREATE POLICY "admin_contratos_all" ON public.contratos
  FOR ALL USING (public._is_admin_or_sindico()
    AND condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid()));
