-- Migration: 20260308f - Avisos (Announcements) Feature
-- Creates: avisos, avisos_lidos tables + RLS + push trigger

-- ============================================================
-- 1. avisos — notice posted by the condominium admin
-- ============================================================
CREATE TABLE IF NOT EXISTS public.avisos (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id  UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  autor_id       UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
  titulo         TEXT NOT NULL CHECK (char_length(titulo) <= 40),
  corpo          TEXT NOT NULL DEFAULT '',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.avisos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_manage_avisos"  ON public.avisos;
DROP POLICY IF EXISTS "resident_read_avisos" ON public.avisos;

-- Síndico / Admin can INSERT, SELECT, DELETE for their condo
CREATE POLICY "admin_manage_avisos"
  ON public.avisos
  USING (
    condominio_id IN (
      SELECT condominio_id FROM public.perfil
      WHERE id = auth.uid()
        AND papel_sistema IN ('ADMIN', 'admin', 'Síndico', 'sindico', 'Subsíndico', 'subsindico')
    )
  )
  WITH CHECK (
    condominio_id IN (
      SELECT condominio_id FROM public.perfil
      WHERE id = auth.uid()
        AND papel_sistema IN ('ADMIN', 'admin', 'Síndico', 'sindico', 'Subsíndico', 'subsindico')
    )
  );

-- All residents/portaria can read avisos from their condo
CREATE POLICY "resident_read_avisos"
  ON public.avisos FOR SELECT
  USING (
    condominio_id IN (
      SELECT condominio_id FROM public.perfil WHERE id = auth.uid()
    )
  );

-- ============================================================
-- 2. avisos_lidos — tracks which users have read each aviso
-- ============================================================
CREATE TABLE IF NOT EXISTS public.avisos_lidos (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aviso_id  UUID NOT NULL REFERENCES public.avisos(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
  lido_em   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (aviso_id, user_id)
);

ALTER TABLE public.avisos_lidos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_mark_read"    ON public.avisos_lidos;
DROP POLICY IF EXISTS "user_view_read"    ON public.avisos_lidos;
DROP POLICY IF EXISTS "admin_view_reads"  ON public.avisos_lidos;

-- Users can INSERT their own read records
CREATE POLICY "user_mark_read"
  ON public.avisos_lidos FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Users can SELECT their own read records
CREATE POLICY "user_view_read"
  ON public.avisos_lidos FOR SELECT
  USING (user_id = auth.uid());

-- Admin can read all read records for their condo's avisos (for % read stats)
CREATE POLICY "admin_view_reads"
  ON public.avisos_lidos FOR SELECT
  USING (
    aviso_id IN (
      SELECT a.id FROM public.avisos a
      JOIN public.perfil p ON p.condominio_id = a.condominio_id
      WHERE p.id = auth.uid()
        AND p.papel_sistema IN ('ADMIN', 'admin', 'Síndico', 'sindico', 'Subsíndico', 'subsindico')
    )
  );

-- ============================================================
-- 3. Indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_avisos_condo    ON public.avisos (condominio_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_avisos_lidos_user ON public.avisos_lidos (user_id);
CREATE INDEX IF NOT EXISTS idx_avisos_lidos_aviso ON public.avisos_lidos (aviso_id);

-- ============================================================
-- 4. Trigger — call edge function to push-notify residents
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_novo_aviso()
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
    RAISE WARNING 'notify_novo_aviso: service_role_key not set. Skipping push.';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/avisos-push-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := jsonb_build_object(
      'aviso_id',      NEW.id,
      'condominio_id', NEW.condominio_id,
      'titulo',        NEW.titulo
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_novo_aviso failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_novo_aviso ON public.avisos;
CREATE TRIGGER trg_notify_novo_aviso
  AFTER INSERT ON public.avisos
  FOR EACH ROW EXECUTE FUNCTION public.notify_novo_aviso();
