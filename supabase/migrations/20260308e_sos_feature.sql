-- Migration: 20260308e - SOS Emergency Feature (v2 - corrigida)
-- Nota: a tabela sos_alertas já existe no schema 2.0.
-- Esta migration adiciona: RLS, trigger de notificação push, e a tabela sos_contatos.
-- A coluna de papel do usuário na tabela perfil se chama: papel_sistema

-- ============================================================
-- 1. sos_alertas — RLS e trigger (tabela já existe)
-- ============================================================

ALTER TABLE public.sos_alertas ENABLE ROW LEVEL SECURITY;

-- Limpa policies antigas se existirem
DROP POLICY IF EXISTS "resident_insert_own_sos"  ON public.sos_alertas;
DROP POLICY IF EXISTS "resident_view_own_sos"    ON public.sos_alertas;
DROP POLICY IF EXISTS "sindico_view_condo_sos"   ON public.sos_alertas;
DROP POLICY IF EXISTS "sindico_update_condo_sos" ON public.sos_alertas;

-- Resident pode inserir seu próprio SOS
CREATE POLICY "resident_insert_own_sos"
  ON public.sos_alertas FOR INSERT
  WITH CHECK (resident_id = auth.uid());

-- Resident pode ver seus próprios alertas
CREATE POLICY "resident_view_own_sos"
  ON public.sos_alertas FOR SELECT
  USING (resident_id = auth.uid());

-- Síndico / Subsíndico / Admin pode ver alertas do seu condomínio
CREATE POLICY "sindico_view_condo_sos"
  ON public.sos_alertas FOR SELECT
  USING (
    condominium_id IN (
      SELECT condominio_id FROM public.perfil
      WHERE id = auth.uid()
        AND papel_sistema IN ('ADMIN', 'Síndico', 'Subsíndico', 'sindico', 'subsindico', 'admin')
    )
  );

-- Síndico / Admin pode atualizar alertas (ex: marcar como resolvido)
CREATE POLICY "sindico_update_condo_sos"
  ON public.sos_alertas FOR UPDATE
  USING (
    condominium_id IN (
      SELECT condominio_id FROM public.perfil
      WHERE id = auth.uid()
        AND papel_sistema IN ('ADMIN', 'Síndico', 'Subsíndico', 'sindico', 'subsindico', 'admin')
    )
  );

-- ============================================================
-- 2. sos_contatos — tabela nova de contatos de confiança
-- ============================================================

CREATE TABLE IF NOT EXISTS public.sos_contatos (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL UNIQUE REFERENCES public.perfil(id) ON DELETE CASCADE,
  contato1_nome           TEXT,
  contato1_whatsapp       TEXT,
  contato2_nome           TEXT,
  contato2_whatsapp       TEXT,
  aceite_responsabilidade BOOLEAN NOT NULL DEFAULT FALSE,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.sos_contatos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_read_own_contatos"   ON public.sos_contatos;
DROP POLICY IF EXISTS "user_insert_own_contatos" ON public.sos_contatos;
DROP POLICY IF EXISTS "user_update_own_contatos" ON public.sos_contatos;

CREATE POLICY "user_read_own_contatos"
  ON public.sos_contatos FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "user_insert_own_contatos"
  ON public.sos_contatos FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_update_own_contatos"
  ON public.sos_contatos FOR UPDATE
  USING (user_id = auth.uid());

-- ============================================================
-- 3. Trigger para notificação push ao síndico quando SOS é acionado
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_sos_alert()
RETURNS TRIGGER AS $$
DECLARE
  v_supa_url  TEXT;
  v_svc_key   TEXT;
  payload     JSONB;
BEGIN
  v_supa_url := COALESCE(
    current_setting('app.settings.supabase_url', true),
    'https://avypyaxthvgaybplnwxu.supabase.co'
  );
  v_svc_key := current_setting('app.settings.service_role_key', true);

  IF v_svc_key IS NULL OR v_svc_key = '' THEN
    RAISE WARNING 'notify_sos_alert: service_role_key not set. Pulando notificação push.';
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'sos_id',         NEW.id,
    'resident_id',    NEW.resident_id,
    'condominium_id', NEW.condominium_id
  );

  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/sos-push-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := payload
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_sos_alert falhou: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_sos_alert ON public.sos_alertas;
CREATE TRIGGER trg_notify_sos_alert
  AFTER INSERT ON public.sos_alertas
  FOR EACH ROW EXECUTE FUNCTION public.notify_sos_alert();
