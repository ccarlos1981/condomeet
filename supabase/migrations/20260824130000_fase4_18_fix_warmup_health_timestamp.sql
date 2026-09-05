-- ============================================================================
-- FASE 4.18.1 — CORREÇÃO CIRÚRGICA DA RPC check_and_increment_warmup_cap
-- OBJETIVO: Substituir referências a 'updated_at' por 'last_check_at'
-- ============================================================================

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
            last_check_at = now()
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
            last_check_at = now()
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
