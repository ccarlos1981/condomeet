-- Migration: 20260322 - Álbum de Fotos Feature
-- Creates: album_fotos, album_fotos_imagens, album_fotos_reacoes,
--          album_fotos_comentarios, album_fotos_visualizacoes
--          + Storage bucket + RLS + push trigger

-- ============================================================
-- 1. ENUM for event type
-- ============================================================
DO $$ BEGIN
  CREATE TYPE tipo_evento_album AS ENUM ('evento', 'manutencao', 'reuniao', 'outros');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- 2. album_fotos — main album record created by síndico
-- ============================================================
CREATE TABLE IF NOT EXISTS public.album_fotos (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id  UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  autor_id       UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
  titulo         TEXT NOT NULL CHECK (char_length(titulo) <= 100),
  descricao      TEXT NOT NULL DEFAULT '',
  tipo_evento    tipo_evento_album NOT NULL DEFAULT 'evento',
  data_evento    DATE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.album_fotos ENABLE ROW LEVEL SECURITY;

-- Síndico / Admin: full CRUD for their condo
DROP POLICY IF EXISTS "admin_manage_album_fotos" ON public.album_fotos;
CREATE POLICY "admin_manage_album_fotos"
  ON public.album_fotos
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

-- Residents: read albums from their condo
DROP POLICY IF EXISTS "resident_read_album_fotos" ON public.album_fotos;
CREATE POLICY "resident_read_album_fotos"
  ON public.album_fotos FOR SELECT
  USING (
    condominio_id IN (
      SELECT condominio_id FROM public.perfil WHERE id = auth.uid()
    )
  );

-- ============================================================
-- 3. album_fotos_imagens — photos in each album (max 5 enforced app-side)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.album_fotos_imagens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id    UUID NOT NULL REFERENCES public.album_fotos(id) ON DELETE CASCADE,
  imagem_url  TEXT NOT NULL,
  ordem       SMALLINT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.album_fotos_imagens ENABLE ROW LEVEL SECURITY;

-- Admin manage images
DROP POLICY IF EXISTS "admin_manage_album_imagens" ON public.album_fotos_imagens;
CREATE POLICY "admin_manage_album_imagens"
  ON public.album_fotos_imagens
  USING (
    album_id IN (
      SELECT af.id FROM public.album_fotos af
      JOIN public.perfil p ON p.condominio_id = af.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  )
  WITH CHECK (
    album_id IN (
      SELECT af.id FROM public.album_fotos af
      JOIN public.perfil p ON p.condominio_id = af.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  );

-- Residents read images from their condo albums
DROP POLICY IF EXISTS "resident_read_album_imagens" ON public.album_fotos_imagens;
CREATE POLICY "resident_read_album_imagens"
  ON public.album_fotos_imagens FOR SELECT
  USING (
    album_id IN (
      SELECT id FROM public.album_fotos
      WHERE condominio_id IN (
        SELECT condominio_id FROM public.perfil WHERE id = auth.uid()
      )
    )
  );

-- ============================================================
-- 4. album_fotos_reacoes — emoji reactions (❤️ 👏 😍 🎉)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.album_fotos_reacoes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id    UUID NOT NULL REFERENCES public.album_fotos(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
  emoji       TEXT NOT NULL CHECK (emoji IN ('❤️','👏','😍','🎉')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (album_id, user_id, emoji)
);

ALTER TABLE public.album_fotos_reacoes ENABLE ROW LEVEL SECURITY;

-- Users can toggle their own reactions
DROP POLICY IF EXISTS "user_manage_album_reacoes" ON public.album_fotos_reacoes;
CREATE POLICY "user_manage_album_reacoes"
  ON public.album_fotos_reacoes
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Everyone can see reactions from their condo albums
DROP POLICY IF EXISTS "resident_read_album_reacoes" ON public.album_fotos_reacoes;
CREATE POLICY "resident_read_album_reacoes"
  ON public.album_fotos_reacoes FOR SELECT
  USING (
    album_id IN (
      SELECT id FROM public.album_fotos
      WHERE condominio_id IN (
        SELECT condominio_id FROM public.perfil WHERE id = auth.uid()
      )
    )
  );

-- ============================================================
-- 5. album_fotos_comentarios — comments with optional reply
-- ============================================================
CREATE TABLE IF NOT EXISTS public.album_fotos_comentarios (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id        UUID NOT NULL REFERENCES public.album_fotos(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
  parent_id       UUID REFERENCES public.album_fotos_comentarios(id) ON DELETE CASCADE,
  conteudo        TEXT NOT NULL CHECK (char_length(conteudo) <= 500),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.album_fotos_comentarios ENABLE ROW LEVEL SECURITY;

-- Users insert their own comments
DROP POLICY IF EXISTS "user_insert_album_comentario" ON public.album_fotos_comentarios;
CREATE POLICY "user_insert_album_comentario"
  ON public.album_fotos_comentarios FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND album_id IN (
      SELECT id FROM public.album_fotos
      WHERE condominio_id IN (
        SELECT condominio_id FROM public.perfil WHERE id = auth.uid()
      )
    )
  );

-- Users delete their own comments
DROP POLICY IF EXISTS "user_delete_album_comentario" ON public.album_fotos_comentarios;
CREATE POLICY "user_delete_album_comentario"
  ON public.album_fotos_comentarios FOR DELETE
  USING (user_id = auth.uid());

-- Admin delete any comment from their condo
DROP POLICY IF EXISTS "admin_delete_album_comentario" ON public.album_fotos_comentarios;
CREATE POLICY "admin_delete_album_comentario"
  ON public.album_fotos_comentarios FOR DELETE
  USING (
    album_id IN (
      SELECT af.id FROM public.album_fotos af
      JOIN public.perfil p ON p.condominio_id = af.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  );

-- Everyone can read comments from their condo albums
DROP POLICY IF EXISTS "resident_read_album_comentarios" ON public.album_fotos_comentarios;
CREATE POLICY "resident_read_album_comentarios"
  ON public.album_fotos_comentarios FOR SELECT
  USING (
    album_id IN (
      SELECT id FROM public.album_fotos
      WHERE condominio_id IN (
        SELECT condominio_id FROM public.perfil WHERE id = auth.uid()
      )
    )
  );

-- ============================================================
-- 6. album_fotos_visualizacoes — view tracking
-- ============================================================
CREATE TABLE IF NOT EXISTS public.album_fotos_visualizacoes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id    UUID NOT NULL REFERENCES public.album_fotos(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
  viewed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (album_id, user_id)
);

ALTER TABLE public.album_fotos_visualizacoes ENABLE ROW LEVEL SECURITY;

-- Users insert their own view record
DROP POLICY IF EXISTS "user_mark_album_viewed" ON public.album_fotos_visualizacoes;
CREATE POLICY "user_mark_album_viewed"
  ON public.album_fotos_visualizacoes FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Users read their own views
DROP POLICY IF EXISTS "user_read_own_views" ON public.album_fotos_visualizacoes;
CREATE POLICY "user_read_own_views"
  ON public.album_fotos_visualizacoes FOR SELECT
  USING (user_id = auth.uid());

-- Admin can see all views for their condo albums
DROP POLICY IF EXISTS "admin_read_album_views" ON public.album_fotos_visualizacoes;
CREATE POLICY "admin_read_album_views"
  ON public.album_fotos_visualizacoes FOR SELECT
  USING (
    album_id IN (
      SELECT af.id FROM public.album_fotos af
      JOIN public.perfil p ON p.condominio_id = af.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN','admin','Síndico','sindico','Subsíndico','subsindico')
    )
  );

-- ============================================================
-- 7. Storage Bucket — album-fotos
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('album-fotos', 'album-fotos', true)
ON CONFLICT (id) DO NOTHING;

-- Upload policy: only Síndico/Admin
DROP POLICY IF EXISTS "admin_upload_album_foto" ON storage.objects;
CREATE POLICY "admin_upload_album_foto"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'album-fotos'
  AND EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND (
        p.papel_sistema ILIKE '%síndico%' OR p.papel_sistema ILIKE '%sindico%'
        OR p.papel_sistema ILIKE '%subsíndico%' OR p.papel_sistema ILIKE '%subsindico%'
        OR p.papel_sistema = 'admin' OR p.papel_sistema = 'ADMIN'
      )
  )
);

-- Read policy: all authenticated users
DROP POLICY IF EXISTS "authenticated_view_album_foto" ON storage.objects;
CREATE POLICY "authenticated_view_album_foto"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'album-fotos');

-- Delete policy: only Síndico/Admin
DROP POLICY IF EXISTS "admin_delete_album_foto" ON storage.objects;
CREATE POLICY "admin_delete_album_foto"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'album-fotos'
  AND EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND (
        p.papel_sistema ILIKE '%síndico%' OR p.papel_sistema ILIKE '%sindico%'
        OR p.papel_sistema ILIKE '%subsíndico%' OR p.papel_sistema ILIKE '%subsindico%'
        OR p.papel_sistema = 'admin' OR p.papel_sistema = 'ADMIN'
      )
  )
);

-- ============================================================
-- 8. Indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_album_fotos_condo
  ON public.album_fotos (condominio_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_album_fotos_imagens_album
  ON public.album_fotos_imagens (album_id, ordem);

CREATE INDEX IF NOT EXISTS idx_album_fotos_reacoes_album
  ON public.album_fotos_reacoes (album_id);

CREATE INDEX IF NOT EXISTS idx_album_fotos_comentarios_album
  ON public.album_fotos_comentarios (album_id, created_at);

CREATE INDEX IF NOT EXISTS idx_album_fotos_comentarios_parent
  ON public.album_fotos_comentarios (parent_id);

CREATE INDEX IF NOT EXISTS idx_album_fotos_visualizacoes_album
  ON public.album_fotos_visualizacoes (album_id);

-- ============================================================
-- 9. Trigger — push-notify residents on new album
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_novo_album()
RETURNS TRIGGER AS $$
DECLARE
  v_supa_url TEXT;
  v_svc_key  TEXT;
BEGIN
  v_supa_url := COALESCE(
    current_setting('app.settings.supabase_url', true),
    'https://avypyaxthvgaybplnwxu.supabase.co'
  );
  v_svc_key := current_setting('app.settings.service_role_key', true);

  IF v_svc_key IS NULL OR v_svc_key = '' THEN
    RAISE WARNING 'notify_novo_album: service_role_key not set. Skipping push.';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/album-push-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := jsonb_build_object(
      'album_id',      NEW.id,
      'condominio_id', NEW.condominio_id,
      'titulo',        NEW.titulo
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_novo_album failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_novo_album ON public.album_fotos;
CREATE TRIGGER trg_notify_novo_album
  AFTER INSERT ON public.album_fotos
  FOR EACH ROW EXECUTE FUNCTION public.notify_novo_album();

-- ============================================================
-- 10. updated_at auto-update trigger
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_album_fotos_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_album_fotos_updated_at ON public.album_fotos;
CREATE TRIGGER trg_album_fotos_updated_at
  BEFORE UPDATE ON public.album_fotos
  FOR EACH ROW EXECUTE FUNCTION public.update_album_fotos_updated_at();
