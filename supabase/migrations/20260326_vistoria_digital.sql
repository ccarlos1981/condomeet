-- ============================================================
-- Migration: 20260326_vistoria_digital
-- Sistema de Vistoria Digital / Checklist Universal
-- Condomeet Check
-- ============================================================

-- ════════════════════════════════════════
-- 1. TEMPLATES — Modelos pré-definidos
-- ════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vistoria_templates (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome         TEXT NOT NULL,
  tipo_bem     TEXT NOT NULL CHECK (tipo_bem IN (
    'apartamento', 'casa', 'carro', 'moto', 'barco', 'equipamento', 'personalizado'
  )),
  descricao    TEXT,
  icone_emoji  TEXT DEFAULT '📋',
  is_public    BOOLEAN DEFAULT true,
  criado_por   UUID,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seções do template (cômodos/áreas)
CREATE TABLE IF NOT EXISTS public.vistoria_template_secoes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id  UUID NOT NULL REFERENCES public.vistoria_templates(id) ON DELETE CASCADE,
  nome         TEXT NOT NULL,
  posicao      SMALLINT NOT NULL DEFAULT 0,
  icone_emoji  TEXT DEFAULT '🏠'
);

-- Itens dentro de cada seção
CREATE TABLE IF NOT EXISTS public.vistoria_template_itens (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  secao_template_id   UUID NOT NULL REFERENCES public.vistoria_template_secoes(id) ON DELETE CASCADE,
  nome                TEXT NOT NULL,
  posicao             SMALLINT NOT NULL DEFAULT 0
);

-- ════════════════════════════════════════
-- 2. VISTORIAS — Registro principal
-- ════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vistorias (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id          UUID NOT NULL,
  titulo                 TEXT NOT NULL,
  tipo_bem               TEXT NOT NULL CHECK (tipo_bem IN (
    'apartamento', 'casa', 'carro', 'moto', 'barco', 'equipamento', 'personalizado'
  )),
  endereco               TEXT,
  responsavel_nome       TEXT,
  proprietario_nome      TEXT,
  inquilino_nome         TEXT,
  template_id            UUID REFERENCES public.vistoria_templates(id) ON DELETE SET NULL,
  vistoria_referencia_id UUID REFERENCES public.vistorias(id) ON DELETE SET NULL,
  status                 TEXT NOT NULL DEFAULT 'rascunho' CHECK (status IN (
    'rascunho', 'em_andamento', 'concluida', 'assinada'
  )),
  tipo_vistoria          TEXT NOT NULL DEFAULT 'entrada' CHECK (tipo_vistoria IN (
    'entrada', 'saida', 'periodica'
  )),
  criado_por             UUID NOT NULL,
  cod_interno            TEXT NOT NULL DEFAULT substr(md5(random()::text), 1, 6),
  link_publico_token     TEXT UNIQUE DEFAULT substr(md5(random()::text || clock_timestamp()::text), 1, 12),
  plano                  TEXT NOT NULL DEFAULT 'free' CHECK (plano IN ('free', 'plus')),
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ════════════════════════════════════════
-- 3. SEÇÕES — Ambientes da vistoria
-- ════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vistoria_secoes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vistoria_id  UUID NOT NULL REFERENCES public.vistorias(id) ON DELETE CASCADE,
  nome         TEXT NOT NULL,
  posicao      SMALLINT NOT NULL DEFAULT 0,
  icone_emoji  TEXT DEFAULT '🏠',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ════════════════════════════════════════
-- 4. ITENS — Itens vistoriados
-- ════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vistoria_itens (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  secao_id     UUID NOT NULL REFERENCES public.vistoria_secoes(id) ON DELETE CASCADE,
  nome         TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'ok' CHECK (status IN (
    'ok', 'atencao', 'danificado', 'nao_existe'
  )),
  observacao   TEXT,
  posicao      SMALLINT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ════════════════════════════════════════
-- 5. FOTOS — Fotos por item
-- ════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vistoria_fotos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id      UUID NOT NULL REFERENCES public.vistoria_itens(id) ON DELETE CASCADE,
  foto_url     TEXT NOT NULL,
  legenda      TEXT,
  posicao      SMALLINT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ════════════════════════════════════════
-- 6. ASSINATURAS — Assinaturas digitais
-- ════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vistoria_assinaturas (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vistoria_id      UUID NOT NULL REFERENCES public.vistorias(id) ON DELETE CASCADE,
  nome             TEXT NOT NULL,
  papel            TEXT NOT NULL CHECK (papel IN (
    'proprietario', 'inquilino', 'responsavel', 'corretor', 'vistoriador'
  )),
  assinatura_url   TEXT,
  email            TEXT,
  ip_address       TEXT,
  assinado_em      TIMESTAMPTZ
);

-- ════════════════════════════════════════
-- 7. RLS — Templates (leitura pública)
-- ════════════════════════════════════════
ALTER TABLE public.vistoria_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone_read_templates" ON public.vistoria_templates;
CREATE POLICY "anyone_read_templates"
  ON public.vistoria_templates FOR SELECT TO authenticated
  USING (is_public = true);

DROP POLICY IF EXISTS "admin_manage_templates" ON public.vistoria_templates;
CREATE POLICY "admin_manage_templates"
  ON public.vistoria_templates
  USING (
    criado_por = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.perfil p
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  )
  WITH CHECK (
    criado_por = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.perfil p
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  );

ALTER TABLE public.vistoria_template_secoes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "read_template_secoes" ON public.vistoria_template_secoes;
CREATE POLICY "read_template_secoes"
  ON public.vistoria_template_secoes FOR SELECT TO authenticated
  USING (true);

ALTER TABLE public.vistoria_template_itens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "read_template_itens" ON public.vistoria_template_itens;
CREATE POLICY "read_template_itens"
  ON public.vistoria_template_itens FOR SELECT TO authenticated
  USING (true);

-- ════════════════════════════════════════
-- 8. RLS — Vistorias
-- ════════════════════════════════════════
ALTER TABLE public.vistorias ENABLE ROW LEVEL SECURITY;

-- Admin/Síndico: CRUD completo do condomínio
DROP POLICY IF EXISTS "admin_manage_vistorias" ON public.vistorias;
CREATE POLICY "admin_manage_vistorias"
  ON public.vistorias
  USING (
    EXISTS (
      SELECT 1 FROM public.perfil p
      WHERE p.id = auth.uid()
        AND p.condominio_id = vistorias.condominio_id
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico','Síndico (a)')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfil p
      WHERE p.id = auth.uid()
        AND p.condominio_id = vistorias.condominio_id
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico','Síndico (a)')
    )
  );

-- Morador: pode ver vistorias do condomínio + criar próprias
DROP POLICY IF EXISTS "morador_read_vistorias" ON public.vistorias;
CREATE POLICY "morador_read_vistorias"
  ON public.vistorias FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfil p
      WHERE p.id = auth.uid()
        AND p.condominio_id = vistorias.condominio_id
    )
  );

DROP POLICY IF EXISTS "morador_insert_vistorias" ON public.vistorias;
CREATE POLICY "morador_insert_vistorias"
  ON public.vistorias FOR INSERT TO authenticated
  WITH CHECK (
    criado_por = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.perfil p
      WHERE p.id = auth.uid()
        AND p.condominio_id = vistorias.condominio_id
    )
  );

DROP POLICY IF EXISTS "morador_update_own_vistorias" ON public.vistorias;
CREATE POLICY "morador_update_own_vistorias"
  ON public.vistorias FOR UPDATE TO authenticated
  USING (criado_por = auth.uid())
  WITH CHECK (criado_por = auth.uid());

DROP POLICY IF EXISTS "morador_delete_own_vistorias" ON public.vistorias;
CREATE POLICY "morador_delete_own_vistorias"
  ON public.vistorias FOR DELETE TO authenticated
  USING (criado_por = auth.uid());

-- ════════════════════════════════════════
-- 9. RLS — Seções, Itens, Fotos, Assinaturas
-- ════════════════════════════════════════
ALTER TABLE public.vistoria_secoes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_manage_vistoria_secoes" ON public.vistoria_secoes;
CREATE POLICY "authenticated_manage_vistoria_secoes"
  ON public.vistoria_secoes
  USING (
    vistoria_id IN (
      SELECT v.id FROM public.vistorias v
      WHERE v.criado_por = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.perfil p
          WHERE p.id = auth.uid()
            AND p.condominio_id = v.condominio_id
            AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico','Síndico (a)')
        )
    )
  )
  WITH CHECK (
    vistoria_id IN (
      SELECT v.id FROM public.vistorias v
      WHERE v.criado_por = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.perfil p
          WHERE p.id = auth.uid()
            AND p.condominio_id = v.condominio_id
            AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico','Síndico (a)')
        )
    )
  );

-- Read seções for anyone that can read the parent vistoria
DROP POLICY IF EXISTS "read_vistoria_secoes" ON public.vistoria_secoes;
CREATE POLICY "read_vistoria_secoes"
  ON public.vistoria_secoes FOR SELECT TO authenticated
  USING (
    vistoria_id IN (
      SELECT v.id FROM public.vistorias v
      JOIN public.perfil p ON p.condominio_id = v.condominio_id
      WHERE p.id = auth.uid()
    )
  );

ALTER TABLE public.vistoria_itens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_manage_vistoria_itens" ON public.vistoria_itens;
CREATE POLICY "authenticated_manage_vistoria_itens"
  ON public.vistoria_itens
  USING (
    secao_id IN (
      SELECT s.id FROM public.vistoria_secoes s
      JOIN public.vistorias v ON v.id = s.vistoria_id
      WHERE v.criado_por = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.perfil p
          WHERE p.id = auth.uid()
            AND p.condominio_id = v.condominio_id
            AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico','Síndico (a)')
        )
    )
  )
  WITH CHECK (
    secao_id IN (
      SELECT s.id FROM public.vistoria_secoes s
      JOIN public.vistorias v ON v.id = s.vistoria_id
      WHERE v.criado_por = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.perfil p
          WHERE p.id = auth.uid()
            AND p.condominio_id = v.condominio_id
            AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico','Síndico (a)')
        )
    )
  );

DROP POLICY IF EXISTS "read_vistoria_itens" ON public.vistoria_itens;
CREATE POLICY "read_vistoria_itens"
  ON public.vistoria_itens FOR SELECT TO authenticated
  USING (
    secao_id IN (
      SELECT s.id FROM public.vistoria_secoes s
      JOIN public.vistorias v ON v.id = s.vistoria_id
      JOIN public.perfil p ON p.condominio_id = v.condominio_id
      WHERE p.id = auth.uid()
    )
  );

ALTER TABLE public.vistoria_fotos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_manage_vistoria_fotos" ON public.vistoria_fotos;
CREATE POLICY "authenticated_manage_vistoria_fotos"
  ON public.vistoria_fotos
  USING (
    item_id IN (
      SELECT i.id FROM public.vistoria_itens i
      JOIN public.vistoria_secoes s ON s.id = i.secao_id
      JOIN public.vistorias v ON v.id = s.vistoria_id
      WHERE v.criado_por = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.perfil p
          WHERE p.id = auth.uid()
            AND p.condominio_id = v.condominio_id
            AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico','Síndico (a)')
        )
    )
  )
  WITH CHECK (
    item_id IN (
      SELECT i.id FROM public.vistoria_itens i
      JOIN public.vistoria_secoes s ON s.id = i.secao_id
      JOIN public.vistorias v ON v.id = s.vistoria_id
      WHERE v.criado_por = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.perfil p
          WHERE p.id = auth.uid()
            AND p.condominio_id = v.condominio_id
            AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico','Síndico (a)')
        )
    )
  );

DROP POLICY IF EXISTS "read_vistoria_fotos" ON public.vistoria_fotos;
CREATE POLICY "read_vistoria_fotos"
  ON public.vistoria_fotos FOR SELECT TO authenticated
  USING (
    item_id IN (
      SELECT i.id FROM public.vistoria_itens i
      JOIN public.vistoria_secoes s ON s.id = i.secao_id
      JOIN public.vistorias v ON v.id = s.vistoria_id
      JOIN public.perfil p ON p.condominio_id = v.condominio_id
      WHERE p.id = auth.uid()
    )
  );

ALTER TABLE public.vistoria_assinaturas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_manage_vistoria_assinaturas" ON public.vistoria_assinaturas;
CREATE POLICY "authenticated_manage_vistoria_assinaturas"
  ON public.vistoria_assinaturas
  USING (
    vistoria_id IN (
      SELECT v.id FROM public.vistorias v
      WHERE v.criado_por = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.perfil p
          WHERE p.id = auth.uid()
            AND p.condominio_id = v.condominio_id
            AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico','Síndico (a)')
        )
    )
  )
  WITH CHECK (
    vistoria_id IN (
      SELECT v.id FROM public.vistorias v
      WHERE v.criado_por = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.perfil p
          WHERE p.id = auth.uid()
            AND p.condominio_id = v.condominio_id
            AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico','Síndico (a)')
        )
    )
  );

DROP POLICY IF EXISTS "read_vistoria_assinaturas" ON public.vistoria_assinaturas;
CREATE POLICY "read_vistoria_assinaturas"
  ON public.vistoria_assinaturas FOR SELECT TO authenticated
  USING (
    vistoria_id IN (
      SELECT v.id FROM public.vistorias v
      JOIN public.perfil p ON p.condominio_id = v.condominio_id
      WHERE p.id = auth.uid()
    )
  );

-- ════════════════════════════════════════
-- 10. STORAGE — Bucket para fotos
-- ════════════════════════════════════════
INSERT INTO storage.buckets (id, name, public)
VALUES ('vistoria-fotos', 'vistoria-fotos', true)
ON CONFLICT (id) DO NOTHING;

-- Upload: authenticated users
DROP POLICY IF EXISTS "auth_upload_vistoria_fotos" ON storage.objects;
CREATE POLICY "auth_upload_vistoria_fotos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'vistoria-fotos');

-- Read: public
DROP POLICY IF EXISTS "public_read_vistoria_fotos" ON storage.objects;
CREATE POLICY "public_read_vistoria_fotos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'vistoria-fotos');

-- Delete: authenticated users (own photos)
DROP POLICY IF EXISTS "auth_delete_vistoria_fotos" ON storage.objects;
CREATE POLICY "auth_delete_vistoria_fotos"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'vistoria-fotos');

-- Bucket for signatures
INSERT INTO storage.buckets (id, name, public)
VALUES ('vistoria-assinaturas', 'vistoria-assinaturas', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "auth_upload_vistoria_assinaturas" ON storage.objects;
CREATE POLICY "auth_upload_vistoria_assinaturas"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'vistoria-assinaturas');

DROP POLICY IF EXISTS "public_read_vistoria_assinaturas" ON storage.objects;
CREATE POLICY "public_read_vistoria_assinaturas"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'vistoria-assinaturas');

-- ════════════════════════════════════════
-- 11. INDEXES
-- ════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_vistorias_condo
  ON public.vistorias (condominio_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vistorias_criado_por
  ON public.vistorias (criado_por);
CREATE INDEX IF NOT EXISTS idx_vistorias_status
  ON public.vistorias (status);
CREATE INDEX IF NOT EXISTS idx_vistorias_link_publico
  ON public.vistorias (link_publico_token);
CREATE INDEX IF NOT EXISTS idx_vistorias_referencia
  ON public.vistorias (vistoria_referencia_id);

CREATE INDEX IF NOT EXISTS idx_vistoria_secoes_vistoria
  ON public.vistoria_secoes (vistoria_id, posicao);
CREATE INDEX IF NOT EXISTS idx_vistoria_itens_secao
  ON public.vistoria_itens (secao_id, posicao);
CREATE INDEX IF NOT EXISTS idx_vistoria_fotos_item
  ON public.vistoria_fotos (item_id, posicao);
CREATE INDEX IF NOT EXISTS idx_vistoria_assinaturas_vistoria
  ON public.vistoria_assinaturas (vistoria_id);

CREATE INDEX IF NOT EXISTS idx_vistoria_template_secoes_template
  ON public.vistoria_template_secoes (template_id, posicao);
CREATE INDEX IF NOT EXISTS idx_vistoria_template_itens_secao
  ON public.vistoria_template_itens (secao_template_id, posicao);

-- ════════════════════════════════════════
-- 12. TRIGGERS
-- ════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.update_vistorias_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_vistorias_updated_at ON public.vistorias;
CREATE TRIGGER trg_vistorias_updated_at
  BEFORE UPDATE ON public.vistorias
  FOR EACH ROW EXECUTE FUNCTION public.update_vistorias_updated_at();

-- Push notification on vistoria completion
CREATE OR REPLACE FUNCTION public.notify_vistoria_concluida()
RETURNS TRIGGER AS $$
DECLARE
  v_supa_url TEXT;
  v_svc_key  TEXT;
BEGIN
  -- Only fire when status changes to 'concluida' or 'assinada'
  IF NEW.status IN ('concluida', 'assinada')
     AND (OLD.status IS NULL OR OLD.status NOT IN ('concluida', 'assinada'))
  THEN
    v_supa_url := COALESCE(
      current_setting('app.settings.supabase_url', true),
      'https://avypyaxthvgaybplnwxu.supabase.co'
    );
    v_svc_key := current_setting('app.settings.service_role_key', true);

    IF v_svc_key IS NULL OR v_svc_key = '' THEN
      RAISE WARNING 'notify_vistoria: service_role_key not set';
      RETURN NEW;
    END IF;

    PERFORM net.http_post(
      url     := v_supa_url || '/functions/v1/vistoria-notify',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_svc_key
      ),
      body    := jsonb_build_object(
        'vistoria_id',   NEW.id,
        'condominio_id', NEW.condominio_id,
        'titulo',        NEW.titulo,
        'status',        NEW.status
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_vistoria failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_vistoria_concluida ON public.vistorias;
CREATE TRIGGER trg_notify_vistoria_concluida
  AFTER UPDATE ON public.vistorias
  FOR EACH ROW EXECUTE FUNCTION public.notify_vistoria_concluida();

-- ════════════════════════════════════════
-- 13. SEED — Templates pré-configurados
-- ════════════════════════════════════════

-- Helper function para seed
DO $$
DECLARE
  t_apto UUID;
  t_casa UUID;
  t_carro UUID;
  t_moto UUID;
  t_barco UUID;
  -- Seções apartamento
  s_sala UUID; s_cozinha UUID; s_quarto UUID; s_banheiro UUID;
  s_area_servico UUID; s_varanda UUID; s_garagem UUID;
  -- Seções casa
  sc_sala UUID; sc_cozinha UUID; sc_quarto1 UUID; sc_banheiro UUID;
  sc_garagem UUID; sc_quintal UUID; sc_area_servico UUID;
  -- Seções carro
  sv_ext UUID; sv_int UUID; sv_motor UUID; sv_pneus UUID; sv_docs UUID;
  -- Seções moto
  sm_car UUID; sm_motor UUID; sm_pneus UUID; sm_docs UUID;
  -- Seções barco
  sb_casco UUID; sb_convex UUID; sb_motor UUID; sb_int UUID; sb_docs UUID;
BEGIN
  -- ── APARTAMENTO ──
  INSERT INTO public.vistoria_templates (id, nome, tipo_bem, descricao, icone_emoji, is_public)
  VALUES (gen_random_uuid(), 'Apartamento', 'apartamento', 'Vistoria completa de apartamento', '🏢', true)
  RETURNING id INTO t_apto;

  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_apto, 'Sala', 0, '🛋️') RETURNING id INTO s_sala;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_apto, 'Cozinha', 1, '🍳') RETURNING id INTO s_cozinha;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_apto, 'Quarto', 2, '🛏️') RETURNING id INTO s_quarto;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_apto, 'Banheiro', 3, '🚿') RETURNING id INTO s_banheiro;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_apto, 'Área de Serviço', 4, '🧺') RETURNING id INTO s_area_servico;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_apto, 'Varanda', 5, '🌿') RETURNING id INTO s_varanda;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_apto, 'Garagem', 6, '🚗') RETURNING id INTO s_garagem;

  -- Itens Sala
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (s_sala, 'Piso', 0), (s_sala, 'Parede', 1), (s_sala, 'Teto', 2),
    (s_sala, 'Porta', 3), (s_sala, 'Janela', 4), (s_sala, 'Tomadas', 5),
    (s_sala, 'Interruptores', 6), (s_sala, 'Iluminação', 7),
    (s_sala, 'Rodapé', 8), (s_sala, 'Ar Condicionado', 9);

  -- Itens Cozinha
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (s_cozinha, 'Piso', 0), (s_cozinha, 'Parede', 1), (s_cozinha, 'Teto', 2),
    (s_cozinha, 'Armário', 3), (s_cozinha, 'Pia', 4), (s_cozinha, 'Torneira', 5),
    (s_cozinha, 'Tomadas', 6), (s_cozinha, 'Interruptores', 7),
    (s_cozinha, 'Iluminação', 8), (s_cozinha, 'Fogão/Cooktop', 9),
    (s_cozinha, 'Exaustor/Coifa', 10), (s_cozinha, 'Azulejo', 11);

  -- Itens Quarto
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (s_quarto, 'Piso', 0), (s_quarto, 'Parede', 1), (s_quarto, 'Teto', 2),
    (s_quarto, 'Porta', 3), (s_quarto, 'Janela', 4), (s_quarto, 'Tomadas', 5),
    (s_quarto, 'Interruptores', 6), (s_quarto, 'Iluminação', 7),
    (s_quarto, 'Armário/Closet', 8), (s_quarto, 'Ar Condicionado', 9);

  -- Itens Banheiro
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (s_banheiro, 'Piso', 0), (s_banheiro, 'Parede', 1), (s_banheiro, 'Teto', 2),
    (s_banheiro, 'Vaso Sanitário', 3), (s_banheiro, 'Pia/Lavatório', 4),
    (s_banheiro, 'Chuveiro', 5), (s_banheiro, 'Box/Blindex', 6),
    (s_banheiro, 'Torneira', 7), (s_banheiro, 'Espelho', 8),
    (s_banheiro, 'Tomadas', 9), (s_banheiro, 'Porta', 10),
    (s_banheiro, 'Azulejo', 11), (s_banheiro, 'Descarga', 12);

  -- Itens Área de Serviço
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (s_area_servico, 'Piso', 0), (s_area_servico, 'Parede', 1),
    (s_area_servico, 'Tanque', 2), (s_area_servico, 'Torneira', 3),
    (s_area_servico, 'Tomadas', 4), (s_area_servico, 'Ralo', 5),
    (s_area_servico, 'Máquina de Lavar (ponto)', 6);

  -- Itens Varanda
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (s_varanda, 'Piso', 0), (s_varanda, 'Parede', 1),
    (s_varanda, 'Grade/Vidro', 2), (s_varanda, 'Tomadas', 3),
    (s_varanda, 'Iluminação', 4), (s_varanda, 'Ralo', 5);

  -- Itens Garagem
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (s_garagem, 'Piso', 0), (s_garagem, 'Parede', 1),
    (s_garagem, 'Iluminação', 2), (s_garagem, 'Portão', 3),
    (s_garagem, 'Tomadas', 4);

  -- ── CASA ──
  INSERT INTO public.vistoria_templates (id, nome, tipo_bem, descricao, icone_emoji, is_public)
  VALUES (gen_random_uuid(), 'Casa', 'casa', 'Vistoria completa de casa', '🏠', true)
  RETURNING id INTO t_casa;

  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_casa, 'Sala', 0, '🛋️') RETURNING id INTO sc_sala;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_casa, 'Cozinha', 1, '🍳') RETURNING id INTO sc_cozinha;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_casa, 'Quarto', 2, '🛏️') RETURNING id INTO sc_quarto1;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_casa, 'Banheiro', 3, '🚿') RETURNING id INTO sc_banheiro;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_casa, 'Garagem', 4, '🚗') RETURNING id INTO sc_garagem;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_casa, 'Quintal', 5, '🌳') RETURNING id INTO sc_quintal;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_casa, 'Área de Serviço', 6, '🧺') RETURNING id INTO sc_area_servico;

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sc_sala, 'Piso', 0), (sc_sala, 'Parede', 1), (sc_sala, 'Teto', 2),
    (sc_sala, 'Porta', 3), (sc_sala, 'Janela', 4), (sc_sala, 'Tomadas', 5),
    (sc_sala, 'Iluminação', 6);
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sc_cozinha, 'Piso', 0), (sc_cozinha, 'Parede', 1), (sc_cozinha, 'Armário', 2),
    (sc_cozinha, 'Pia', 3), (sc_cozinha, 'Torneira', 4), (sc_cozinha, 'Tomadas', 5);
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sc_quarto1, 'Piso', 0), (sc_quarto1, 'Parede', 1), (sc_quarto1, 'Teto', 2),
    (sc_quarto1, 'Porta', 3), (sc_quarto1, 'Janela', 4), (sc_quarto1, 'Armário', 5);
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sc_banheiro, 'Piso', 0), (sc_banheiro, 'Parede', 1), (sc_banheiro, 'Vaso', 2),
    (sc_banheiro, 'Pia', 3), (sc_banheiro, 'Chuveiro', 4), (sc_banheiro, 'Box', 5);
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sc_garagem, 'Piso', 0), (sc_garagem, 'Portão', 1), (sc_garagem, 'Iluminação', 2);
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sc_quintal, 'Muro', 0), (sc_quintal, 'Portão', 1), (sc_quintal, 'Piso', 2),
    (sc_quintal, 'Iluminação', 3);
  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sc_area_servico, 'Piso', 0), (sc_area_servico, 'Tanque', 1),
    (sc_area_servico, 'Torneira', 2), (sc_area_servico, 'Tomadas', 3);

  -- ── CARRO ──
  INSERT INTO public.vistoria_templates (id, nome, tipo_bem, descricao, icone_emoji, is_public)
  VALUES (gen_random_uuid(), 'Carro', 'carro', 'Vistoria de veículo automotor', '🚗', true)
  RETURNING id INTO t_carro;

  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_carro, 'Exterior', 0, '🚗') RETURNING id INTO sv_ext;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_carro, 'Interior', 1, '💺') RETURNING id INTO sv_int;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_carro, 'Motor', 2, '⚙️') RETURNING id INTO sv_motor;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_carro, 'Pneus/Rodas', 3, '🔧') RETURNING id INTO sv_pneus;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_carro, 'Documentação', 4, '📄') RETURNING id INTO sv_docs;

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sv_ext, 'Pintura', 0), (sv_ext, 'Para-choque dianteiro', 1),
    (sv_ext, 'Para-choque traseiro', 2), (sv_ext, 'Faróis', 3),
    (sv_ext, 'Lanternas', 4), (sv_ext, 'Retrovisores', 5),
    (sv_ext, 'Vidros', 6), (sv_ext, 'Para-brisa', 7),
    (sv_ext, 'Portas', 8), (sv_ext, 'Capô', 9),
    (sv_ext, 'Porta-malas', 10);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sv_int, 'Bancos', 0), (sv_int, 'Painel', 1),
    (sv_int, 'Volante', 2), (sv_int, 'Câmbio', 3),
    (sv_int, 'Ar Condicionado', 4), (sv_int, 'Carpete/Tapetes', 5),
    (sv_int, 'Cintos de segurança', 6), (sv_int, 'Multimídia/Rádio', 7),
    (sv_int, 'Forro do teto', 8);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sv_motor, 'Motor', 0), (sv_motor, 'Óleo', 1),
    (sv_motor, 'Bateria', 2), (sv_motor, 'Correias', 3),
    (sv_motor, 'Radiador', 4), (sv_motor, 'Fluidos', 5);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sv_pneus, 'Dianteiro esquerdo', 0), (sv_pneus, 'Dianteiro direito', 1),
    (sv_pneus, 'Traseiro esquerdo', 2), (sv_pneus, 'Traseiro direito', 3),
    (sv_pneus, 'Estepe', 4), (sv_pneus, 'Calotas/Rodas', 5);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sv_docs, 'CRLV', 0), (sv_docs, 'Seguro', 1),
    (sv_docs, 'Multas pendentes', 2), (sv_docs, 'Chave reserva', 3);

  -- ── MOTO ──
  INSERT INTO public.vistoria_templates (id, nome, tipo_bem, descricao, icone_emoji, is_public)
  VALUES (gen_random_uuid(), 'Moto', 'moto', 'Vistoria de motocicleta', '🏍️', true)
  RETURNING id INTO t_moto;

  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_moto, 'Carenagem/Exterior', 0, '🏍️') RETURNING id INTO sm_car;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_moto, 'Motor/Mecânica', 1, '⚙️') RETURNING id INTO sm_motor;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_moto, 'Pneus/Rodas', 2, '🔧') RETURNING id INTO sm_pneus;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_moto, 'Documentação', 3, '📄') RETURNING id INTO sm_docs;

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sm_car, 'Pintura', 0), (sm_car, 'Farol', 1), (sm_car, 'Lanterna', 2),
    (sm_car, 'Retrovisores', 3), (sm_car, 'Guidão', 4),
    (sm_car, 'Assento', 5), (sm_car, 'Escapamento', 6);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sm_motor, 'Motor', 0), (sm_motor, 'Óleo', 1),
    (sm_motor, 'Corrente/Transmissão', 2), (sm_motor, 'Freios', 3),
    (sm_motor, 'Bateria', 4), (sm_motor, 'Embreagem', 5);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sm_pneus, 'Pneu dianteiro', 0), (sm_pneus, 'Pneu traseiro', 1),
    (sm_pneus, 'Rodas', 2);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sm_docs, 'CRLV', 0), (sm_docs, 'Seguro', 1), (sm_docs, 'Capacete', 2);

  -- ── BARCO ──
  INSERT INTO public.vistoria_templates (id, nome, tipo_bem, descricao, icone_emoji, is_public)
  VALUES (gen_random_uuid(), 'Barco', 'barco', 'Vistoria de embarcação', '⛵', true)
  RETURNING id INTO t_barco;

  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_barco, 'Casco', 0, '🚢') RETURNING id INTO sb_casco;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_barco, 'Convés', 1, '⛵') RETURNING id INTO sb_convex;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_barco, 'Motor', 2, '⚙️') RETURNING id INTO sb_motor;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_barco, 'Interior', 3, '🛏️') RETURNING id INTO sb_int;
  INSERT INTO public.vistoria_template_secoes (id, template_id, nome, posicao, icone_emoji) VALUES
    (gen_random_uuid(), t_barco, 'Documentação', 4, '📄') RETURNING id INTO sb_docs;

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sb_casco, 'Pintura', 0), (sb_casco, 'Estrutura', 1),
    (sb_casco, 'Quilha', 2), (sb_casco, 'Hélice', 3);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sb_convex, 'Piso', 0), (sb_convex, 'Corrimões', 1),
    (sb_convex, 'Iluminação', 2), (sb_convex, 'Âncora', 3);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sb_motor, 'Motor', 0), (sb_motor, 'Óleo', 1),
    (sb_motor, 'Hélice', 2), (sb_motor, 'Combustível', 3);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sb_int, 'Cabine', 0), (sb_int, 'Bancos', 1),
    (sb_int, 'Painel', 2), (sb_int, 'Iluminação', 3);

  INSERT INTO public.vistoria_template_itens (secao_template_id, nome, posicao) VALUES
    (sb_docs, 'Registro', 0), (sb_docs, 'Seguro', 1),
    (sb_docs, 'Habilitação náutica', 2);
END $$;
