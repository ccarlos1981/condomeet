-- ============================================================
-- Migration: 20260313_registro_turno
-- Tabelas para Registro de Turno da Portaria
-- ============================================================

-- ── 1. ASSUNTOS DE TURNO ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.turno_assuntos (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id   UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  titulo          TEXT        NOT NULL,
  observacao      TEXT,
  ativo           BOOLEAN     NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_turno_assuntos_condo ON public.turno_assuntos(condominio_id);

-- ── 2. INVENTÁRIO DA PORTARIA ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.turno_inventario (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  assunto_id      UUID        NOT NULL REFERENCES public.turno_assuntos(id) ON DELETE CASCADE,
  condominio_id   UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  nome            TEXT        NOT NULL,
  quantidade      NUMERIC     NOT NULL DEFAULT 0,
  unidade         TEXT        NOT NULL DEFAULT 'Unidade',
  observacao      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_turno_inventario_assunto ON public.turno_inventario(assunto_id);
CREATE INDEX IF NOT EXISTS idx_turno_inventario_condo   ON public.turno_inventario(condominio_id);

-- ── 3. RLS ───────────────────────────────────────────────────
ALTER TABLE public.turno_assuntos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.turno_inventario ENABLE ROW LEVEL SECURITY;

-- Admin/Síndico: full CRUD on turno_assuntos
DROP POLICY IF EXISTS "admin_crud_turno_assuntos" ON public.turno_assuntos;
CREATE POLICY "admin_crud_turno_assuntos"
ON public.turno_assuntos FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = turno_assuntos.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
  )
);

-- Admin/Síndico: full CRUD on turno_inventario
DROP POLICY IF EXISTS "admin_crud_turno_inventario" ON public.turno_inventario;
CREATE POLICY "admin_crud_turno_inventario"
ON public.turno_inventario FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = turno_inventario.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
  )
);

-- Porteiro: SELECT only
DROP POLICY IF EXISTS "porteiro_select_turno_assuntos" ON public.turno_assuntos;
CREATE POLICY "porteiro_select_turno_assuntos"
ON public.turno_assuntos FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = turno_assuntos.condominio_id
      AND p.papel_sistema IN ('Portaria', 'Porteiro', 'portaria', 'porteiro')
  )
);

DROP POLICY IF EXISTS "porteiro_select_turno_inventario" ON public.turno_inventario;
CREATE POLICY "porteiro_select_turno_inventario"
ON public.turno_inventario FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = turno_inventario.condominio_id
      AND p.papel_sistema IN ('Portaria', 'Porteiro', 'portaria', 'porteiro')
  )
);

-- ══════════════════════════════════════════════════════════════
-- FASE 2: REGISTROS DE TURNO
-- ══════════════════════════════════════════════════════════════

-- ── 4. REGISTROS DE TURNO ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.turno_registros (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id   UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  porteiro_id     UUID        NOT NULL REFERENCES public.perfil(id),
  porteiro_nome   TEXT        NOT NULL,
  observacao      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_turno_registros_condo ON public.turno_registros(condominio_id);
CREATE INDEX IF NOT EXISTS idx_turno_registros_porteiro ON public.turno_registros(porteiro_id);

-- ── 5. ITENS CONFERIDOS POR REGISTRO ─────────────────────────
CREATE TABLE IF NOT EXISTS public.turno_registro_itens (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  registro_id     UUID        NOT NULL REFERENCES public.turno_registros(id) ON DELETE CASCADE,
  inventario_id   UUID        NOT NULL REFERENCES public.turno_inventario(id) ON DELETE CASCADE,
  confere         BOOLEAN     NOT NULL DEFAULT true,
  qtd_informada   NUMERIC,
  comentario      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_turno_reg_itens_registro ON public.turno_registro_itens(registro_id);

-- ── 6. RLS FASE 2 ────────────────────────────────────────────
ALTER TABLE public.turno_registros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.turno_registro_itens ENABLE ROW LEVEL SECURITY;

-- Porteiro: INSERT + SELECT registros
DROP POLICY IF EXISTS "porteiro_crud_turno_registros" ON public.turno_registros;
CREATE POLICY "porteiro_crud_turno_registros"
ON public.turno_registros FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = turno_registros.condominio_id
      AND p.papel_sistema IN ('Portaria', 'Porteiro', 'portaria', 'porteiro')
  )
);

DROP POLICY IF EXISTS "porteiro_crud_turno_registro_itens" ON public.turno_registro_itens;
CREATE POLICY "porteiro_crud_turno_registro_itens"
ON public.turno_registro_itens FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.turno_registros r
    JOIN public.perfil p ON p.id = auth.uid()
    WHERE r.id = turno_registro_itens.registro_id
      AND p.condominio_id = r.condominio_id
      AND p.papel_sistema IN ('Portaria', 'Porteiro', 'portaria', 'porteiro')
  )
);

-- Admin: SELECT tudo
DROP POLICY IF EXISTS "admin_select_turno_registros" ON public.turno_registros;
CREATE POLICY "admin_select_turno_registros"
ON public.turno_registros FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = turno_registros.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
  )
);

DROP POLICY IF EXISTS "admin_select_turno_registro_itens" ON public.turno_registro_itens;
CREATE POLICY "admin_select_turno_registro_itens"
ON public.turno_registro_itens FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.turno_registros r
    JOIN public.perfil p ON p.id = auth.uid()
    WHERE r.id = turno_registro_itens.registro_id
      AND p.condominio_id = r.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
  )
);
