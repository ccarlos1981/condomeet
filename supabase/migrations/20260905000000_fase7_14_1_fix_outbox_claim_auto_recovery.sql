-- ============================================================================
-- FASE 7.14.1 — CORREÇÃO DEFINITIVA DO AUTO-RECOVERY NA RPC DE CLAIM DA OUTBOX
-- Prevenção de violação de constraint 23505 (idx_whatsapp_outbox_dedup_pending)
-- AMBIENTE: condomeet_Antigravity (avypyaxthvgaybplnwxu)
-- ============================================================================

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

    -- 1. Auto-recovery seguro de mensagens presas em 'sending' ou 'sending_meta' por > 2 minutos
    -- 1.1 Encerrar mensagens presas cujo message_hash já possui outro registro ativo em 'pending'
    --     ou que possua duplicata entre as próprias mensagens presas (mantendo apenas uma para recovery)
    WITH stuck_candidates AS (
        SELECT id, message_hash,
               ROW_NUMBER() OVER (PARTITION BY message_hash ORDER BY created_at ASC) as rn
        FROM public.whatsapp_outbox
        WHERE status IN ('sending', 'sending_meta')
          AND processing_started_at IS NOT NULL
          AND processing_started_at < v_two_min_ago
          AND (expires_at IS NULL OR expires_at > now())
    )
    UPDATE public.whatsapp_outbox o
    SET status = 'failed',
        error_message = 'Auto-recovery: encerrado pois ja existe registro ativo em pending com mesmo message_hash',
        processing_started_at = NULL,
        updated_at = now()
    WHERE o.id IN (
        SELECT sc.id
        FROM stuck_candidates sc
        WHERE sc.rn > 1
           OR EXISTS (
               SELECT 1 
               FROM public.whatsapp_outbox p
               WHERE p.status = 'pending'
                 AND p.message_hash = sc.message_hash
                 AND p.id <> sc.id
           )
    );

    -- 1.2 Recuperar para 'pending' as demais mensagens presas sem colisão
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
