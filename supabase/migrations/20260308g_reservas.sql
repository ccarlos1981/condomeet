-- Migration: 20260308g - Reservas Phase 1
-- Tables: areas_comuns, areas_comuns_horarios, reservas

-- ============================================================
-- 1. areas_comuns — common area configuration per condo
-- ============================================================
CREATE TABLE IF NOT EXISTS public.areas_comuns (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id         UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  tipo_agenda           TEXT NOT NULL,
  local                 TEXT NOT NULL DEFAULT 'Espaço comum',
  outro_local           TEXT,
  tipo_reserva          TEXT NOT NULL DEFAULT 'por_dia' CHECK (tipo_reserva IN ('por_dia', 'por_hora')),
  capacidade            INT NOT NULL DEFAULT 0,
  limite_acesso         INT NOT NULL DEFAULT 1,
  hrs_cancelar          INT NOT NULL DEFAULT 24,
  precos                JSONB NOT NULL DEFAULT '[]',
  instrucao_uso         TEXT,
  ativo                 BOOLEAN NOT NULL DEFAULT true,
  aprovacao_automatica  BOOLEAN NOT NULL DEFAULT false,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.areas_comuns ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_manage_areas_comuns"   ON public.areas_comuns;
DROP POLICY IF EXISTS "resident_read_areas_comuns"  ON public.areas_comuns;

-- Síndico/Admin full control
CREATE POLICY "admin_manage_areas_comuns"
  ON public.areas_comuns
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

-- Residents can read active areas of their condo
CREATE POLICY "resident_read_areas_comuns"
  ON public.areas_comuns FOR SELECT
  USING (
    ativo = true AND
    condominio_id IN (
      SELECT condominio_id FROM public.perfil WHERE id = auth.uid()
    )
  );

-- ============================================================
-- 2. areas_comuns_horarios — time slots for por_hora areas
-- ============================================================
CREATE TABLE IF NOT EXISTS public.areas_comuns_horarios (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  area_id          UUID NOT NULL REFERENCES public.areas_comuns(id) ON DELETE CASCADE,
  dia_semana       TEXT NOT NULL CHECK (dia_semana IN ('Seg','Ter','Qua','Qui','Sex','Sab','Dom')),
  hora_inicio      TIME NOT NULL,
  duracao_minutos  INT NOT NULL DEFAULT 60,
  ativo            BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.areas_comuns_horarios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_manage_horarios"   ON public.areas_comuns_horarios;
DROP POLICY IF EXISTS "resident_read_horarios"  ON public.areas_comuns_horarios;

CREATE POLICY "admin_manage_horarios"
  ON public.areas_comuns_horarios
  USING (
    area_id IN (
      SELECT ac.id FROM public.areas_comuns ac
      JOIN public.perfil p ON p.condominio_id = ac.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  )
  WITH CHECK (
    area_id IN (
      SELECT ac.id FROM public.areas_comuns ac
      JOIN public.perfil p ON p.condominio_id = ac.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  );

CREATE POLICY "resident_read_horarios"
  ON public.areas_comuns_horarios FOR SELECT
  USING (
    ativo = true AND
    area_id IN (
      SELECT ac.id FROM public.areas_comuns ac
      JOIN public.perfil p ON p.condominio_id = ac.condominio_id
      WHERE p.id = auth.uid()
    )
  );

-- ============================================================
-- 3. reservas — booking records (shell for Phase 2)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.reservas (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  area_id        UUID NOT NULL REFERENCES public.areas_comuns(id) ON DELETE CASCADE,
  horario_id     UUID REFERENCES public.areas_comuns_horarios(id) ON DELETE SET NULL,
  user_id        UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
  condominio_id  UUID NOT NULL,
  data_reserva   DATE NOT NULL,
  status         TEXT NOT NULL DEFAULT 'pendente'
                   CHECK (status IN ('pendente','aprovado','reprovado','cancelado')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.reservas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_manage_reservas"   ON public.reservas;
DROP POLICY IF EXISTS "resident_own_reservas"   ON public.reservas;

CREATE POLICY "admin_manage_reservas"
  ON public.reservas
  USING (
    condominio_id IN (
      SELECT condominio_id FROM public.perfil
      WHERE id = auth.uid()
        AND papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  );

CREATE POLICY "resident_own_reservas"
  ON public.reservas
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 4. Indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_areas_comuns_condo  ON public.areas_comuns (condominio_id, ativo);
CREATE INDEX IF NOT EXISTS idx_horarios_area        ON public.areas_comuns_horarios (area_id, dia_semana);
CREATE INDEX IF NOT EXISTS idx_reservas_area        ON public.reservas (area_id, data_reserva);
CREATE INDEX IF NOT EXISTS idx_reservas_user        ON public.reservas (user_id, status);
CREATE INDEX IF NOT EXISTS idx_reservas_condo       ON public.reservas (condominio_id, status);
