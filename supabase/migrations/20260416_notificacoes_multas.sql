-- Migration: 20260416 - Notificacoes e Multas Feature

CREATE TABLE IF NOT EXISTS public.notificacoes_multas (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id  UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  unidade_id     UUID NOT NULL REFERENCES public.unidades(id) ON DELETE CASCADE,
  autor_id       UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
  tipo           TEXT NOT NULL CHECK (tipo IN ('NOTIFICACAO', 'MULTA')),
  titulo         TEXT NOT NULL,
  descricao      TEXT,
  valor          NUMERIC(10, 2), -- Valor (null se não for multa ou não tiver valor)
  status         TEXT DEFAULT 'pendente', -- pendente, pago, recorrido, cancelado
  data_ocorrencia TIMESTAMPTZ DEFAULT NOW(),
  anexo_url      TEXT,
  lido_em        TIMESTAMPTZ,
  lido_por       UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notificacoes_multas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_manage_multas" ON public.notificacoes_multas;
DROP POLICY IF EXISTS "resident_read_multas" ON public.notificacoes_multas;

-- Síndico / Admin can INSERT, SELECT, UPDATE, DELETE for their condo
CREATE POLICY "admin_manage_multas"
  ON public.notificacoes_multas
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

-- All residents from that specific unit can read their fines/notifications
CREATE POLICY "resident_read_multas"
  ON public.notificacoes_multas FOR SELECT
  USING (
    unidade_id IN (
      SELECT unidade_id FROM public.unidade_perfil WHERE perfil_id = auth.uid()
    )
  );

-- Trigger to notify residents via Edge Function
CREATE OR REPLACE FUNCTION public.notify_nova_notificacao_multa()
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
    RAISE WARNING 'notify_nova_notificacao_multa: service_role_key not set. Skipping push.';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := v_supa_url || '/functions/v1/multas-push-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
    ),
    body    := jsonb_build_object(
      'registro_id',   NEW.id,
      'condominio_id', NEW.condominio_id,
      'unidade_id',    NEW.unidade_id,
      'tipo',          NEW.tipo,
      'titulo',        NEW.titulo
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_nova_notificacao_multa failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_nova_notificacao_multa ON public.notificacoes_multas;
CREATE TRIGGER trg_notify_nova_notificacao_multa
  AFTER INSERT ON public.notificacoes_multas
  FOR EACH ROW EXECUTE FUNCTION public.notify_nova_notificacao_multa();
