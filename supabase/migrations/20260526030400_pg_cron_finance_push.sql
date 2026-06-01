-- Ativa extensões necessárias se não estiverem ativas
create extension if not exists "pg_cron" with schema "pg_catalog";
create extension if not exists "pg_net" with schema "public";

-- Deleta o job se já existir (para idempôtencia)
SELECT cron.unschedule('finance-push-worker-daily');

-- Cria o job diário (às 11:00 UTC = 08:00 BRT)
SELECT cron.schedule(
  'finance-push-worker-daily',
  '0 11 * * *',
  $$
    SELECT net.http_post(
      url:='https://[PROJECT_REF].functions.supabase.co/finance-push-worker',
      headers:=jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', current_setting('request.jwt.claim.role', true) -- Usará credenciais internas no Supabase ou precisa configurar auth
      )
    );
  $$
);
