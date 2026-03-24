-- ============================================================
-- Migration: 20260313_lgpd_archive_cron
-- LGPD: arquivamento automático de encomendas e convites > 90 dias
-- Executa todo dia às 03:00 horário de Brasília (= 06:00 UTC)
-- ============================================================

-- ⚠️ Pré-requisitos:
--    1. Habilite a extensão pg_cron:  Database → Extensions → pg_cron → Enable
--    2. Habilite a extensão pg_net:   Database → Extensions → pg_net → Enable
--    3. Deploy da Edge Function:      supabase functions deploy lgpd-archive

-- Remove job existente se houver (idempotente)
SELECT cron.unschedule('lgpd-archive-daily')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'lgpd-archive-daily'
);

-- Agenda o job diário às 06:00 UTC (03:00 Brasília)
-- Horário de madrugada para não impactar performance
SELECT cron.schedule(
  'lgpd-archive-daily',              -- nome do job
  '0 6 * * *',                       -- 06:00 UTC = 03:00 Brasília
  $$
    SELECT net.http_post(
      url     := COALESCE(
                   current_setting('app.settings.supabase_url', true),
                   'https://avypyaxthvgaybplnwxu.supabase.co'
                 ) || '/functions/v1/lgpd-archive',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      ),
      body    := '{}'::jsonb
    );
  $$
);
