-- =================================================================
-- Migration: 20260315_perfil_approved_whatsapp
-- Trigger: Sends WhatsApp notification via botconversa-send
--          when perfil.status_aprovacao changes to 'aprovado'
-- =================================================================

CREATE OR REPLACE FUNCTION public.tr_fn_perfil_approved()
RETURNS TRIGGER AS $$
DECLARE
  v_condo_nome     TEXT;
  v_tipo_estrutura TEXT;
  v_bloco_label    TEXT;
  v_apto_label     TEXT;
  v_cod_interno    TEXT;
  v_msg            TEXT;
  v_payload        JSONB;
  v_supabase_url   TEXT;
  v_secret_key     TEXT;
BEGIN
  -- Only fire when status_aprovacao transitions to 'aprovado'
  IF NEW.status_aprovacao <> 'aprovado' THEN
    RETURN NEW;
  END IF;
  IF OLD.status_aprovacao = 'aprovado' THEN
    RETURN NEW;
  END IF;

  -- Must have botconversa_id to send WhatsApp
  IF NEW.botconversa_id IS NULL OR NEW.botconversa_id = '' THEN
    RAISE WARNING 'tr_fn_perfil_approved: no botconversa_id for perfil %', NEW.id;
    RETURN NEW;
  END IF;

  -- Fetch condominium name and tipo_estrutura
  SELECT nome, COALESCE(tipo_estrutura, 'predio')
    INTO v_condo_nome, v_tipo_estrutura
  FROM public.condominios
  WHERE id = NEW.condominio_id;

  IF v_condo_nome IS NULL THEN
    v_condo_nome := 'seu condomínio';
    v_tipo_estrutura := 'predio';
  END IF;

  -- Compute dynamic labels based on tipo_estrutura
  CASE v_tipo_estrutura
    WHEN 'casa_quadra' THEN v_bloco_label := 'Quadra'; v_apto_label := 'Lote';
    WHEN 'casa_rua'    THEN v_bloco_label := 'Rua';    v_apto_label := 'Número';
    ELSE                     v_bloco_label := 'Bloco';  v_apto_label := 'Apto';
  END CASE;

  -- Anti-ban code (5 random chars)
  v_cod_interno := substr(md5(random()::text), 1, 5);

  -- Build message
  v_msg := '😄' || E'\n'
    || v_condo_nome || E'\n'
    || E'\n'
    || 'Seu cadastro foi aprovado e/ou ativado.' || E'\n'
    || E'\n'
    || 'Agora você poderá acessar o aplicativo Condomeet no ' || v_condo_nome || '.' || E'\n'
    || E'\n'
    || 'Sua unidade está em:' || E'\n'
    || E'\n'
    || v_bloco_label || ': ' || COALESCE(NEW.bloco_txt, '-') || E'\n'
    || v_apto_label || ': ' || COALESCE(NEW.apto_txt, '-') || E'\n'
    || E'\n'
    || 'Condomeet agradece!' || E'\n'
    || 'Cód interno: ' || v_cod_interno;

  -- Build payload for botconversa-send
  v_payload := jsonb_build_object(
    'msg',               v_msg,
    'tipo',              'texto',
    'condominio_id',     NEW.condominio_id,
    'modo_envio',        'por_botconversa',
    'botconversa_id',    NEW.botconversa_id,
    'tipo_notificacao',  'aprovacao'
  );

  -- Get Supabase connection details
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_secret_key   := current_setting('app.settings.service_role_key', true);

  -- Call botconversa-send via pg_net
  PERFORM net.http_post(
    url     := v_supabase_url || '/functions/v1/botconversa-send',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_secret_key
    ),
    body    := v_payload
  );

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  -- Non-fatal: log and continue (never block the approval)
  RAISE WARNING 'tr_fn_perfil_approved failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop if exists, then create trigger
DROP TRIGGER IF EXISTS tr_perfil_approved ON public.perfil;
CREATE TRIGGER tr_perfil_approved
  AFTER UPDATE OF status_aprovacao ON public.perfil
  FOR EACH ROW
  WHEN (NEW.status_aprovacao = 'aprovado' AND OLD.status_aprovacao IS DISTINCT FROM 'aprovado')
  EXECUTE FUNCTION public.tr_fn_perfil_approved();
