-- Migration: 20260824100000_implement_botconversa_first_failover.sql
-- Description: Criação da tabela whatsapp_health_status e do rate limiter atômico global do BotConversa

-- 1. Tabela whatsapp_health_status (Saneamento de dependência histórica)
CREATE TABLE IF NOT EXISTS public.whatsapp_health_status (
    id TEXT PRIMARY KEY DEFAULT 'singleton',
    status TEXT NOT NULL DEFAULT 'ok',
    api_status TEXT NOT NULL DEFAULT 'ok',
    whatsapp_connection_status TEXT NOT NULL DEFAULT 'connected',
    connection_source TEXT NOT NULL DEFAULT 'system',
    confidence_level TEXT NOT NULL DEFAULT 'high',
    last_check_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_heartbeat TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_api_success_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_api_failure_at TIMESTAMPTZ,
    last_disconnected_at TIMESTAMPTZ,
    last_reconnected_at TIMESTAMPTZ,
    fail_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    last_alert_at TIMESTAMPTZ
);

INSERT INTO public.whatsapp_health_status (id)
VALUES ('singleton')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.whatsapp_health_status ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow service_role full access on whatsapp_health_status" ON public.whatsapp_health_status;
CREATE POLICY "Allow service_role full access on whatsapp_health_status" 
ON public.whatsapp_health_status FOR ALL TO service_role USING (true);

DROP POLICY IF EXISTS "Allow authenticated read on whatsapp_health_status" ON public.whatsapp_health_status;
CREATE POLICY "Allow authenticated read on whatsapp_health_status" 
ON public.whatsapp_health_status FOR SELECT TO authenticated USING (true);

-- 2. Tabela botconversa_rate_limiter (Rate limit global de 2 msgs + 15–30s cooldown)
CREATE TABLE IF NOT EXISTS public.botconversa_rate_limiter (
    id TEXT PRIMARY KEY DEFAULT 'singleton',
    consecutive_sent_count INTEGER NOT NULL DEFAULT 0,
    cooldown_until TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_sent_at TIMESTAMPTZ,
    last_worker_instance TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.botconversa_rate_limiter (id)
VALUES ('singleton')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.botconversa_rate_limiter ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow service_role full access on botconversa_rate_limiter" ON public.botconversa_rate_limiter;
CREATE POLICY "Allow service_role full access on botconversa_rate_limiter" 
ON public.botconversa_rate_limiter FOR ALL TO service_role USING (true);

-- 3. Stored Procedure: acquire_botconversa_slot (Pre-Send slot check)
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

    -- Se estiver em período de cooldown ativo, calcular tempo restante de espera
    IF v_now < v_limiter.cooldown_until THEN
        v_wait_ms := CAST(EXTRACT(EPOCH FROM (v_limiter.cooldown_until - v_now)) * 1000 AS INTEGER);
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'COOLDOWN_ACTIVE',
            'wait_ms', GREATEST(v_wait_ms, 500)
        );
    END IF;

    RETURN jsonb_build_object(
        'allowed', true,
        'current_count', v_limiter.consecutive_sent_count
    );
END;
$$;

-- 4. Stored Procedure: confirm_botconversa_sent (Post-Send confirm & cooldown trigger)
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

    IF v_new_count >= 2 THEN
        -- Limite de 2 envios atingido: calcular jitter aleatório entre 15s e 30s
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
            'cooldown_sec', v_jitter_sec
        );
    ELSE
        -- Primeiro envio do bloco de 2
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

-- 5. Hardening de Permissões (Security Definer Restrito)
REVOKE ALL ON FUNCTION public.acquire_botconversa_slot(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.acquire_botconversa_slot(TEXT) TO service_role, postgres;

REVOKE ALL ON FUNCTION public.confirm_botconversa_sent(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_botconversa_sent(TEXT) TO service_role, postgres;
