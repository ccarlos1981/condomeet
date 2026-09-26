-- ============================================================================
-- Migration: 20260925190000_decouple_approval_notify_from_reactivation.sql
-- Objetivo:  1. Desacoplar approval-notify da reativação administrativa.
--               Dispara notificação SOMENTE na transição estrita:
--               OLD.status_aprovacao = 'pendente' AND NEW.status_aprovacao = 'aprovado'.
--               Reativações ('bloqueado' -> 'aprovado') não enviam WhatsApp/Push.
--            2. Eliminar completamente o hardcode da service_role_key.
--               Obtém a credencial dinamicamente via Supabase Vault (vault.decrypted_secrets).
-- Projeto:   condomeet_Antigravity (avypyaxthvgaybplnwxu)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.tr_fn_perfil_approved()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_supabase_url   TEXT;
  v_secret_key     TEXT;
  v_payload        JSONB;
BEGIN
  -- 1. Guarda NULL-Safe: Só notifica se a origem for estritamente 'pendente'
  IF OLD.status_aprovacao IS DISTINCT FROM 'pendente' THEN
    RETURN NEW;
  END IF;

  -- 2. Guarda NULL-Safe: Só notifica se o novo status for estritamente 'aprovado'
  IF NEW.status_aprovacao IS DISTINCT FROM 'aprovado' THEN
    RETURN NEW;
  END IF;

  -- 3. Obter URL do projeto Supabase
  v_supabase_url := coalesce(
    current_setting('app.settings.supabase_url', true),
    'https://avypyaxthvgaybplnwxu.supabase.co'
  );

  -- 4. Obter credencial de forma segura e dinâmica a partir do Supabase Vault
  SELECT decrypted_secret
  INTO v_secret_key
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_service_role_key'
  LIMIT 1;

  -- 5. Tratamento defensivo caso o secret não esteja acessível
  IF v_secret_key IS NULL OR trim(v_secret_key) = '' THEN
    RAISE WARNING 'tr_fn_perfil_approved: supabase_service_role_key não encontrada no Vault. Notificação cancelada.';
    RETURN NEW;
  END IF;

  -- 6. Construir payload estruturado
  v_payload := jsonb_build_object(
    'perfil_id',     NEW.id,
    'condominio_id', NEW.condominio_id
  );

  -- 7. Disparar notificação de primeira aprovação via Edge Function
  PERFORM net.http_post(
    url     := v_supabase_url || '/functions/v1/approval-notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_secret_key
    ),
    body    := v_payload
  );

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  -- Não bloqueia a transação de aprovação em caso de indisponibilidade de rede
  RAISE WARNING 'tr_fn_perfil_approved failed: %', SQLERRM;
  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.tr_fn_perfil_approved() IS 
'Dispara notificação de aprovação (WhatsApp/Push) SOMENTE na transição pendente -> aprovado com credencial segura do Supabase Vault. Reativações são silenciosas.';
