-- Tabela para controlar quais lembretes já foram enviados (evitar duplicatas)
CREATE TABLE IF NOT EXISTS public.reserva_notificacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reserva_id UUID NOT NULL REFERENCES public.reservas(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN ('7_dias', '1_dia')),
  canal TEXT NOT NULL DEFAULT 'push' CHECK (canal IN ('whatsapp', 'push', 'falha')),
  enviado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS reserva_notificacoes_unique
  ON public.reserva_notificacoes (reserva_id, tipo);

-- RLS: apenas service role pode ler/gravar (Edge Function usa service role key)
ALTER TABLE public.reserva_notificacoes ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────────
-- pg_cron: agendar execução diária às 8h (BRT = 11h UTC)
-- Execute este bloco DEPOIS de habilitar pg_cron e pg_net no projeto Supabase:
--
-- SELECT cron.schedule(
--   'reservas-lembretes',
--   '0 11 * * *',
--   $$
--     SELECT net.http_post(
--       url     := 'https://SEU_PROJECT_ID.supabase.co/functions/v1/reservas-reminder',
--       headers := jsonb_build_object(
--                    'Content-Type',  'application/json',
--                    'Authorization', 'Bearer SEU_SERVICE_ROLE_KEY'
--                  ),
--       body    := '{}'::jsonb
--     );
--   $$
-- );
-- ─────────────────────────────────────────────────────────────────────────
