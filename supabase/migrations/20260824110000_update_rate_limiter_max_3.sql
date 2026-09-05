-- Migration: 20260824110000_update_rate_limiter_max_3.sql
-- Description: Homologação da regra oficial do BotConversa: Máximo de 3 mensagens consecutivas + Cooldown de 15–30s

-- 1. Atualização da Stored Procedure: confirm_botconversa_sent
CREATE OR REPLACE FUNCTION public.confirm_botconversa_sent(
    p_instance_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_limiter RECORD;
    v_now TIMESTAMPTZ := now();
    v_new_count INTEGER;
    v_jitter_sec INTEGER;
BEGIN
    SELECT * INTO v_limiter 
    FROM public.botconversa_rate_limiter 
    WHERE id = 'singleton' 
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.botconversa_rate_limiter (id, consecutive_sent_count, cooldown_until)
        VALUES ('singleton', 0, v_now)
        RETURNING * INTO v_limiter;
    END IF;

    v_new_count := v_limiter.consecutive_sent_count + 1;

    -- Regra Homologada: Limite absoluto de 3 mensagens consecutivas aceitas
    IF v_new_count >= 3 THEN
        -- Limite atingido: calcular jitter aleatório entre 15s e 30s
        v_jitter_sec := 15 + floor(random() * 16)::INTEGER; -- Faixa [15, 30]
        
        UPDATE public.botconversa_rate_limiter
        SET consecutive_sent_count = 0,
            cooldown_until = v_now + (v_jitter_sec * INTERVAL '1 second'),
            last_sent_at = v_now,
            last_worker_instance = p_instance_id,
            updated_at = v_now
        WHERE id = 'singleton';

        RETURN jsonb_build_object(
            'cooldown_triggered', true,
            'cooldown_sec', v_jitter_sec,
            'max_limit_reached', 3
        );
    ELSE
        -- Envios 1 ou 2 do bloco de 3
        UPDATE public.botconversa_rate_limiter
        SET consecutive_sent_count = v_new_count,
            last_sent_at = v_now,
            last_worker_instance = p_instance_id,
            updated_at = v_now
        WHERE id = 'singleton';

        RETURN jsonb_build_object(
            'cooldown_triggered', false,
            'consecutive_count', v_new_count
        );
    END IF;
END;
$$;

-- 2. Atualização da Stored Procedure: acquire_botconversa_slot
CREATE OR REPLACE FUNCTION public.acquire_botconversa_slot(
    p_instance_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_limiter RECORD;
    v_now TIMESTAMPTZ := now();
    v_wait_ms INTEGER;
BEGIN
    SELECT * INTO v_limiter 
    FROM public.botconversa_rate_limiter 
    WHERE id = 'singleton' 
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.botconversa_rate_limiter (id, consecutive_sent_count, cooldown_until)
        VALUES ('singleton', 0, v_now)
        RETURNING * INTO v_limiter;
    END IF;

    -- 1. Se estiver em período de cooldown ativo, calcular tempo restante de espera
    IF v_now < v_limiter.cooldown_until THEN
        v_wait_ms := CAST(EXTRACT(EPOCH FROM (v_limiter.cooldown_until - v_now)) * 1000 AS INTEGER);
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'COOLDOWN_ACTIVE',
            'wait_ms', GREATEST(v_wait_ms, 500)
        );
    END IF;

    -- 2. Hard Limit Safety: Se o contador for >= 3 sem reset, força cooldown preventivo
    IF v_limiter.consecutive_sent_count >= 3 THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'HARD_LIMIT_REACHED',
            'wait_ms', 15000
        );
    END IF;

    RETURN jsonb_build_object(
        'allowed', true,
        'current_count', v_limiter.consecutive_sent_count
    );
END;
$$;

-- 3. Permissões de Segurança Estritas
REVOKE ALL ON FUNCTION public.acquire_botconversa_slot(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.acquire_botconversa_slot(TEXT) TO service_role, postgres;

REVOKE ALL ON FUNCTION public.confirm_botconversa_sent(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_botconversa_sent(TEXT) TO service_role, postgres;
