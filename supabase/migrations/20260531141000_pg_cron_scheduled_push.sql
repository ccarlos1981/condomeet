-- Migration: 20260531141000 — pg_cron: scheduled push worker
-- Executa a cada 30 minutos

-- Remove job existente se houver (idempotente)
SELECT cron.unschedule('scheduled-push-worker-cron')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'scheduled-push-worker-cron'
);

-- Agenda o job a cada 30 minutos
SELECT cron.schedule(
  'scheduled-push-worker-cron',      -- nome do job
  '*/30 * * * *',                    -- a cada 30 minutos
  $$
    SELECT net.http_post(
      url     := COALESCE(
                   current_setting('app.settings.supabase_url', true),
                   'https://avypyaxthvgaybplnwxu.supabase.co'
                 ) || '/functions/v1/scheduled-push-worker',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      ),
      body    := '{}'::jsonb
    );
  $$
);
