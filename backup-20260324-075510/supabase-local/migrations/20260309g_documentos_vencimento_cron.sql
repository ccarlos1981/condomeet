-- ============================================================
-- Migration: 20260309g — pg_cron: check documentos vencimento
-- Executa todo dia às 08:00 horário de Brasília (= 11:00 UTC)
-- ============================================================

-- ⚠️ Habilite a extensão pg_cron antes de rodar este script:
--    Database → Extensions → pg_cron → Enable
-- ⚠️ Garanta que a extensão pg_net também esteja habilitada.

-- Remove job existente se houver (idempotente)
SELECT cron.unschedule('check-documentos-vencimento')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'check-documentos-vencimento'
);

-- Agenda o job diário
SELECT cron.schedule(
  'check-documentos-vencimento',   -- nome do job
  '0 11 * * *',                    -- 11:00 UTC = 08:00 Brasília
  $$
    SELECT net.http_post(
      url     := COALESCE(
                   current_setting('app.settings.supabase_url', true),
                   'https://avypyaxthvgaybplnwxu.supabase.co'
                 ) || '/functions/v1/documentos-vencimento-check',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      ),
      body    := '{}'::jsonb
    );
  $$
);
