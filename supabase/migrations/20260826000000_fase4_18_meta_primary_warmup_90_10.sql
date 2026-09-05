-- ============================================================================
-- FASE 4.18 — ESTRATÉGIA TEMPORÁRIA 90/10 (META PRIMARY + BOTCONVERSA WARMUP)
-- AMBIENTE: EXCLUSIVAMENTE DEV (avypyaxthvgaybplnwxu / condomeet_Antigravity)
-- ============================================================================

-- 1. Adicionar colunas de controle de WARMUP na tabela whatsapp_health_status
ALTER TABLE public.whatsapp_health_status
ADD COLUMN IF NOT EXISTS warmup_mode BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS warmup_daily_cap INTEGER NOT NULL DEFAULT 20,
ADD COLUMN IF NOT EXISTS warmup_sent_today INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS warmup_date_reset DATE NOT NULL DEFAULT CURRENT_DATE;

-- 2. Função RPC atômica para verificar e incrementar o teto diário de aquecimento
CREATE OR REPLACE FUNCTION public.check_and_increment_warmup_cap(
    p_instance_id TEXT DEFAULT 'singleton'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_rec RECORD;
    v_can_send BOOLEAN := false;
    v_current_count INTEGER := 0;
    v_cap INTEGER := 20;
    v_mode BOOLEAN := false;
BEGIN
    -- Advisory Lock curto para garantir atomicidade no incremento diário
    PERFORM pg_advisory_xact_lock(hashtext('warmup_cap_lock'));

    SELECT warmup_mode, warmup_daily_cap, warmup_sent_today, warmup_date_reset
    INTO v_rec
    FROM public.whatsapp_health_status
    WHERE id = p_instance_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'warmup_mode', false,
            'can_send_warmup', false,
            'reason', 'HEALTH_STATUS_NOT_FOUND',
            'sent_today', 0,
            'daily_cap', 20
        );
    END IF;

    v_mode := v_rec.warmup_mode;
    v_cap := COALESCE(v_rec.warmup_daily_cap, 20);

    -- Reset diário automático se mudou o dia
    IF v_rec.warmup_date_reset < CURRENT_DATE THEN
        UPDATE public.whatsapp_health_status
        SET warmup_sent_today = 0,
            warmup_date_reset = CURRENT_DATE,
            updated_at = now()
        WHERE id = p_instance_id;
        v_current_count := 0;
    ELSE
        v_current_count := COALESCE(v_rec.warmup_sent_today, 0);
    END IF;

    -- Avaliar se ainda está dentro do teto
    IF v_mode AND v_current_count < v_cap THEN
        v_can_send := true;
        -- Incrementa o contador de envios de aquecimento do dia
        UPDATE public.whatsapp_health_status
        SET warmup_sent_today = warmup_sent_today + 1,
            updated_at = now()
        WHERE id = p_instance_id;
        v_current_count := v_current_count + 1;
    ELSE
        v_can_send := false;
    END IF;

    RETURN jsonb_build_object(
        'warmup_mode', v_mode,
        'can_send_warmup', v_can_send,
        'sent_today', v_current_count,
        'daily_cap', v_cap,
        'reason', CASE 
                    WHEN NOT v_mode THEN 'WARMUP_MODE_DISABLED'
                    WHEN NOT v_can_send THEN 'DAILY_CAP_EXCEEDED'
                    ELSE 'OK'
                  END
    );
END;
$$;

-- 3. Atualizar a RPC claim_single_whatsapp_message com auto-recovery e suporte a sending_meta
CREATE OR REPLACE FUNCTION public.claim_single_whatsapp_message(
    p_min_priority integer,
    p_max_priority integer
)
RETURNS SETOF whatsapp_outbox
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_two_min_ago TIMESTAMPTZ := now() - INTERVAL '2 minutes';
BEGIN
    -- Advisory lock para serializar claims concorrentes
    PERFORM pg_advisory_xact_lock(998878);

    -- 1. Auto-recovery atômico de mensagens presas em 'sending' ou 'sending_meta' por > 2 minutos
    UPDATE public.whatsapp_outbox
    SET status = 'pending',
        error_message = 'Recuperado: timeout de processamento excedido (> 2 min)',
        processing_started_at = NULL,
        updated_at = now()
    WHERE status IN ('sending', 'sending_meta')
      AND processing_started_at IS NOT NULL
      AND processing_started_at < v_two_min_ago
      AND (expires_at IS NULL OR expires_at > now());

    -- 2. Saneamento Atômico de Linhas com TTL Expirado (Anti-Backlog)
    UPDATE public.whatsapp_outbox
    SET status = 'expired',
        expired_at = now(),
        expiration_reason = 'TTL_EXCEEDED_IN_QUEUE',
        updated_at = now()
    WHERE status IN ('pending', 'dispatched_bc', 'fallback_pending', 'sending', 'sending_meta')
      AND expires_at IS NOT NULL
      AND expires_at <= now();

    -- 3. Claim Atômico do Próximo Registro Elegível:
    --    a) Mensagem 'pending' cujo next_attempt_at chegou e expires_at > now()
    --    b) Mensagem 'dispatched_bc' cuja janela de guarda fallback_after estourou e expires_at > now()
    --    c) Mensagem 'fallback_pending' pronta para envio Meta e expires_at > now()
    RETURN QUERY
    UPDATE public.whatsapp_outbox
    SET status = CASE 
                   WHEN status = 'dispatched_bc' THEN 'sending_meta'
                   WHEN status = 'fallback_pending' THEN 'sending_meta'
                   ELSE 'sending'
                 END,
        processing_started_at = now(),
        updated_at = now()
    WHERE id = (
        SELECT id 
        FROM public.whatsapp_outbox
        WHERE (
            -- Eligible pending message
            (status = 'pending' AND (next_attempt_at IS NULL OR next_attempt_at <= now()))
            OR
            -- Eligible dispatched_bc message awaiting Meta failover
            (status = 'dispatched_bc' AND fallback_after IS NOT NULL AND fallback_after <= now())
            OR
            -- Eligible explicit fallback_pending
            (status = 'fallback_pending' AND (next_attempt_at IS NULL OR next_attempt_at <= now()))
          )
          AND priority >= p_min_priority
          AND priority <= p_max_priority
          AND (expires_at IS NULL OR expires_at > now())
        ORDER BY priority ASC, created_at ASC
        LIMIT 1
        FOR UPDATE SKIP LOCKED
    )
    RETURNING *;
END;
$$;
