-- ============================================================================
-- MIGRATION: 20260920260000_botconversa_clean_architecture_rollout.sql
-- DESCRIÇÃO: Rollout Controlado BotConversa com Separação Estrita de Configuração
--            Permanente (botconversa_config) e Estado de Runtime (botconversa_rate_limiter).
--            Suporte a Rollout por Condomínio (CONDOMINIUM_HASH), Cooldown Dinâmico,
--            Limite Diário, Disable Reason, Observation Mode e RPC de Métricas Diárias.
-- AMBIENTE: PRODUÇÃO OFICIAL (avypyaxthvgaybplnwxu / condomeet_Antigravity)
-- GOVERNANÇA: OPERAÇÃO ASSISTIDA — SEM ALTERAÇÃO NO AGENTS.MD
-- ============================================================================

-- 1. TABELA DEDICADA DE CONFIGURAÇÃO PERMANENTE (Baixa frequência de escrita)
CREATE TABLE IF NOT EXISTS public.botconversa_config (
    id TEXT PRIMARY KEY DEFAULT 'singleton',
    enabled BOOLEAN NOT NULL DEFAULT true,
    disable_reason TEXT DEFAULT NULL,
    rollout_percent INTEGER NOT NULL DEFAULT 5,
    rollout_strategy TEXT NOT NULL DEFAULT 'CONDOMINIUM_HASH',
    cooldown_seconds INTEGER NOT NULL DEFAULT 60,
    daily_limit INTEGER NOT NULL DEFAULT 50,
    observation_mode BOOLEAN NOT NULL DEFAULT true,
    allowed_message_types TEXT[] NOT NULL DEFAULT ARRAY['WELCOME', 'NOTICE', 'VISITOR_INVITE', 'DUAL_NUMBER_NOTICE']::TEXT[],
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by TEXT DEFAULT 'system',
    CONSTRAINT chk_rollout_percent CHECK (rollout_percent >= 0 AND rollout_percent <= 100),
    CONSTRAINT chk_cooldown_seconds CHECK (cooldown_seconds >= 5 AND cooldown_seconds <= 300),
    CONSTRAINT chk_daily_limit CHECK (daily_limit >= 0),
    CONSTRAINT chk_rollout_strategy CHECK (rollout_strategy IN ('CONDOMINIUM_HASH', 'GLOBAL_HASH', 'MESSAGE_HASH'))
);

-- Inserir registro singleton padrão se não existir
INSERT INTO public.botconversa_config (
    id, enabled, disable_reason, rollout_percent, rollout_strategy, 
    cooldown_seconds, daily_limit, observation_mode, allowed_message_types
)
VALUES (
    'singleton', true, NULL, 5, 'CONDOMINIUM_HASH', 
    60, 50, true, ARRAY['WELCOME', 'NOTICE', 'VISITOR_INVITE', 'DUAL_NUMBER_NOTICE']::TEXT[]
)
ON CONFLICT (id) DO NOTHING;

-- RLS na tabela de configuração
ALTER TABLE public.botconversa_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow service_role full access on botconversa_config" ON public.botconversa_config;
CREATE POLICY "Allow service_role full access on botconversa_config" 
ON public.botconversa_config FOR ALL TO service_role USING (true);


-- 2. TABELA DE ESTADO DE RUNTIME TRANSITÓRIO (Alta concorrência de workers)
ALTER TABLE public.botconversa_rate_limiter
ADD COLUMN IF NOT EXISTS daily_sent_count INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS daily_reset_date DATE NOT NULL DEFAULT CURRENT_DATE;


-- 3. ÍNDICE RANGE NA WHATSAPP_OUTBOX PARA CONSULTAS O(LOG N) POR PERÍODO
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_created_at 
ON public.whatsapp_outbox (created_at DESC);


-- 4. RPC PARA CONSULTA DE CONFIGURAÇÃO OPERACIONAL E ESTADO EM RUNTIME
CREATE OR REPLACE FUNCTION public.get_botconversa_operational_config()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_config RECORD;
    v_limiter RECORD;
    v_now TIMESTAMPTZ := now();
    v_wait_ms INTEGER := 0;
    v_cooldown_remaining NUMERIC := 0;
BEGIN
    SELECT * INTO v_config
    FROM public.botconversa_config
    WHERE id = 'singleton';

    IF NOT FOUND THEN
        -- Fallback seguro se não houver registro
        RETURN jsonb_build_object(
            'enabled', false,
            'disable_reason', 'CONFIG_NOT_FOUND',
            'rollout_percent', 0,
            'rollout_strategy', 'CONDOMINIUM_HASH',
            'cooldown_seconds', 60,
            'daily_limit', 50,
            'daily_sent_today', 0,
            'daily_remaining', 50,
            'observation_mode', true,
            'allowed_message_types', ARRAY['WELCOME', 'NOTICE', 'VISITOR_INVITE', 'DUAL_NUMBER_NOTICE']::TEXT[],
            'cooldown_active', false,
            'cooldown_remaining_sec', 0,
            'last_sent_at', NULL
        );
    END IF;

    SELECT * INTO v_limiter
    FROM public.botconversa_rate_limiter
    WHERE id = 'singleton';

    IF v_limiter IS NOT NULL AND v_now < v_limiter.cooldown_until THEN
        v_wait_ms := CAST(EXTRACT(EPOCH FROM (v_limiter.cooldown_until - v_now)) * 1000 AS INTEGER);
        v_cooldown_remaining := ROUND(v_wait_ms / 1000.0, 1);
    END IF;

    RETURN jsonb_build_object(
        'enabled', v_config.enabled,
        'disable_reason', v_config.disable_reason,
        'rollout_percent', v_config.rollout_percent,
        'rollout_strategy', v_config.rollout_strategy,
        'cooldown_seconds', v_config.cooldown_seconds,
        'daily_limit', v_config.daily_limit,
        'daily_sent_today', COALESCE(v_limiter.daily_sent_count, 0),
        'daily_remaining', GREATEST(v_config.daily_limit - COALESCE(v_limiter.daily_sent_count, 0), 0),
        'daily_reset_date', COALESCE(v_limiter.daily_reset_date, CURRENT_DATE),
        'observation_mode', v_config.observation_mode,
        'allowed_message_types', v_config.allowed_message_types,
        'last_sent_at', v_limiter.last_sent_at,
        'cooldown_until', v_limiter.cooldown_until,
        'cooldown_active', (v_cooldown_remaining > 0),
        'cooldown_remaining_sec', v_cooldown_remaining
    );
END;
$$;


-- 5. RPC ATÔMICA PARA REQUISIÇÃO DE SLOT (ACQUIRE)
CREATE OR REPLACE FUNCTION public.acquire_botconversa_slot(
    p_instance_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_config RECORD;
    v_limiter RECORD;
    v_now TIMESTAMPTZ := now();
    v_wait_ms INTEGER;
    v_time_since_last NUMERIC := NULL;
    v_daily_sent INTEGER;
BEGIN
    -- 1. Leitura da Configuração Permanente
    SELECT * INTO v_config
    FROM public.botconversa_config
    WHERE id = 'singleton';

    IF NOT FOUND OR NOT v_config.enabled THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'BOTCONVERSA_DISABLED',
            'disable_reason', COALESCE(v_config.disable_reason, 'MANUAL_DEACTIVATION'),
            'botconversa_enabled', false,
            'observation_mode', COALESCE(v_config.observation_mode, true),
            'wait_ms', 0
        );
    END IF;

    -- 2. Lock Atômico no Estado Transitório de Concorrência
    SELECT * INTO v_limiter 
    FROM public.botconversa_rate_limiter 
    WHERE id = 'singleton' 
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.botconversa_rate_limiter (id, consecutive_sent_count, cooldown_until, daily_sent_count, daily_reset_date)
        VALUES ('singleton', 0, v_now, 0, CURRENT_DATE)
        RETURNING * INTO v_limiter;
    END IF;

    -- 3. Reset Diário Automático
    IF v_limiter.daily_reset_date < CURRENT_DATE THEN
        UPDATE public.botconversa_rate_limiter
        SET daily_sent_count = 0,
            daily_reset_date = CURRENT_DATE,
            updated_at = v_now
        WHERE id = 'singleton';
        v_daily_sent := 0;
    ELSE
        v_daily_sent := v_limiter.daily_sent_count;
    END IF;

    -- 4. Cálculo do tempo desde o último envio
    IF v_limiter.last_sent_at IS NOT NULL THEN
        v_time_since_last := ROUND(EXTRACT(EPOCH FROM (v_now - v_limiter.last_sent_at))::NUMERIC, 1);
    END IF;

    -- 5. Verificação de Limite Diário
    IF v_daily_sent >= v_config.daily_limit THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'DAILY_LIMIT_REACHED',
            'botconversa_enabled', v_config.enabled,
            'daily_sent_count', v_daily_sent,
            'daily_limit', v_config.daily_limit,
            'daily_remaining', 0,
            'observation_mode', v_config.observation_mode,
            'wait_ms', 0
        );
    END IF;

    -- 6. Verificação de Cooldown Ativo (Pacing Dinâmico)
    IF v_now < v_limiter.cooldown_until THEN
        v_wait_ms := CAST(EXTRACT(EPOCH FROM (v_limiter.cooldown_until - v_now)) * 1000 AS INTEGER);
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'COOLDOWN_ACTIVE',
            'wait_ms', GREATEST(v_wait_ms, 500),
            'cooldown_until', v_limiter.cooldown_until,
            'cooldown_remaining_sec', ROUND(v_wait_ms / 1000.0, 1),
            'last_sent_at', v_limiter.last_sent_at,
            'time_since_last_sec', v_time_since_last,
            'botconversa_enabled', v_config.enabled,
            'rollout_percent', v_config.rollout_percent,
            'rollout_strategy', v_config.rollout_strategy,
            'daily_sent_count', v_daily_sent,
            'daily_limit', v_config.daily_limit,
            'daily_remaining', GREATEST(v_config.daily_limit - v_daily_sent, 0),
            'observation_mode', v_config.observation_mode
        );
    END IF;

    -- 7. Slot Liberado com Sucesso
    RETURN jsonb_build_object(
        'allowed', true,
        'wait_ms', 0,
        'botconversa_enabled', v_config.enabled,
        'rollout_percent', v_config.rollout_percent,
        'rollout_strategy', v_config.rollout_strategy,
        'cooldown_seconds', v_config.cooldown_seconds,
        'daily_sent_count', v_daily_sent,
        'daily_limit', v_config.daily_limit,
        'daily_remaining', GREATEST(v_config.daily_limit - v_daily_sent, 0),
        'last_sent_at', v_limiter.last_sent_at,
        'time_since_last_sec', v_time_since_last,
        'observation_mode', v_config.observation_mode
    );
END;
$$;


-- 6. RPC ATÔMICA PARA CONFIRMAÇÃO DE ENVIO REAL (CONFIRM)
CREATE OR REPLACE FUNCTION public.confirm_botconversa_sent(
    p_instance_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_config RECORD;
    v_limiter RECORD;
    v_now TIMESTAMPTZ := now();
    v_new_daily_count INTEGER;
    v_cooldown_sec INTEGER := 60;
    v_cooldown_until TIMESTAMPTZ;
BEGIN
    -- Obter cooldown_seconds configurado
    SELECT cooldown_seconds, daily_limit INTO v_config
    FROM public.botconversa_config
    WHERE id = 'singleton';

    IF FOUND AND v_config.cooldown_seconds IS NOT NULL THEN
        v_cooldown_sec := v_config.cooldown_seconds;
    END IF;

    v_cooldown_until := v_now + (v_cooldown_sec * INTERVAL '1 second');

    SELECT * INTO v_limiter 
    FROM public.botconversa_rate_limiter 
    WHERE id = 'singleton' 
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.botconversa_rate_limiter (
            id, consecutive_sent_count, cooldown_until, last_sent_at, 
            daily_sent_count, daily_reset_date, last_worker_instance
        )
        VALUES (
            'singleton', 0, v_cooldown_until, v_now, 
            1, CURRENT_DATE, p_instance_id
        )
        RETURNING * INTO v_limiter;
        v_new_daily_count := 1;
    ELSE
        -- Reset se mudou o dia
        IF v_limiter.daily_reset_date < CURRENT_DATE THEN
            v_new_daily_count := 1;
        ELSE
            v_new_daily_count := v_limiter.daily_sent_count + 1;
        END IF;

        UPDATE public.botconversa_rate_limiter
        SET consecutive_sent_count = 0, -- Envio estritamente individual
            cooldown_until = v_cooldown_until,
            last_sent_at = v_now,
            daily_sent_count = v_new_daily_count,
            daily_reset_date = CURRENT_DATE,
            last_worker_instance = p_instance_id,
            updated_at = v_now
        WHERE id = 'singleton';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'cooldown_sec', v_cooldown_sec,
        'cooldown_until', v_cooldown_until,
        'last_sent_at', v_now,
        'daily_sent_count', v_new_daily_count,
        'daily_limit', COALESCE(v_config.daily_limit, 50),
        'daily_remaining', GREATEST(COALESCE(v_config.daily_limit, 50) - v_new_daily_count, 0)
    );
END;
$$;


-- 7. RPC PARA MÉTRICAS OPERACIONAIS DIÁRIAS (Substitui View para performance O(log N))
CREATE OR REPLACE FUNCTION public.get_whatsapp_botconversa_daily_metrics(
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_start_tz TIMESTAMPTZ;
    v_end_tz TIMESTAMPTZ;
    v_config RECORD;
    v_limiter RECORD;
    v_total_messages INTEGER := 0;
    v_meta_count INTEGER := 0;
    v_botconversa_count INTEGER := 0;
    v_evolution_count INTEGER := 0;
    v_cooldown_delays INTEGER := 0;
    v_daily_limit_rollovers INTEGER := 0;
    v_reasons_breakdown JSONB;
BEGIN
    -- Delimitação estrita do dia em America/Sao_Paulo convertida para UTC
    v_start_tz := (p_date::TEXT || ' 00:00:00 America/Sao_Paulo')::TIMESTAMPTZ;
    v_end_tz := v_start_tz + INTERVAL '1 day';

    -- Obter Configuração Permanente
    SELECT * INTO v_config
    FROM public.botconversa_config
    WHERE id = 'singleton';

    -- Obter Estado Transitório de Runtime
    SELECT * INTO v_limiter
    FROM public.botconversa_rate_limiter
    WHERE id = 'singleton';

    -- Contagem de Mensagens Processadas no Dia
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE (delivery_result->>'provider') = 'META_CLOUD_API'),
        COUNT(*) FILTER (WHERE (delivery_result->>'provider') = 'BOTCONVERSA'),
        COUNT(*) FILTER (WHERE (delivery_result->>'provider') = 'EVOLUTION'),
        COUNT(*) FILTER (WHERE (delivery_result->>'routing_reason') = 'DAILY_LIMIT_REACHED')
    INTO 
        v_total_messages,
        v_meta_count,
        v_botconversa_count,
        v_evolution_count,
        v_daily_limit_rollovers
    FROM public.whatsapp_outbox
    WHERE created_at >= v_start_tz AND created_at < v_end_tz;

    -- Contagem de reagendamentos por cooldown registrados na outbox
    SELECT COUNT(*)
    INTO v_cooldown_delays
    FROM public.whatsapp_outbox
    WHERE created_at >= v_start_tz AND created_at < v_end_tz
      AND (delivery_result->>'reason') = 'COOLDOWN_ACTIVE_RESCHEDULED';

    -- Agrupamento dos Motivos de Roteamento
    SELECT jsonb_object_agg(COALESCE(reason_label, 'SEM_MOTIVO'), count_val)
    INTO v_reasons_breakdown
    FROM (
        SELECT 
            COALESCE(delivery_result->>'routing_reason', delivery_result->>'reason', 'SEM_MOTIVO') as reason_label,
            COUNT(*) as count_val
        FROM public.whatsapp_outbox
        WHERE created_at >= v_start_tz AND created_at < v_end_tz
        GROUP BY 1
    ) sub;

    RETURN jsonb_build_object(
        'date', p_date,
        'total_messages', v_total_messages,
        'meta_messages', v_meta_count,
        'botconversa_messages', v_botconversa_count,
        'evolution_messages', v_evolution_count,
        'meta_percentage', CASE WHEN v_total_messages > 0 THEN ROUND((v_meta_count::NUMERIC / v_total_messages) * 100, 2) ELSE 0 END,
        'botconversa_percentage', CASE WHEN v_total_messages > 0 THEN ROUND((v_botconversa_count::NUMERIC / v_total_messages) * 100, 2) ELSE 0 END,
        'routing_reasons', COALESCE(v_reasons_breakdown, '{}'::JSONB),
        'daily_limit_configured', COALESCE(v_config.daily_limit, 50),
        'daily_sent_count', COALESCE(v_limiter.daily_sent_count, 0),
        'daily_remaining', GREATEST(COALESCE(v_config.daily_limit, 50) - COALESCE(v_limiter.daily_sent_count, 0), 0),
        'cooldown_delays_count', v_cooldown_delays,
        'daily_limit_rollovers_count', v_daily_limit_rollovers,
        'botconversa_enabled', COALESCE(v_config.enabled, true),
        'disable_reason', v_config.disable_reason,
        'rollout_percent', COALESCE(v_config.rollout_percent, 5),
        'rollout_strategy', COALESCE(v_config.rollout_strategy, 'CONDOMINIUM_HASH'),
        'cooldown_seconds', COALESCE(v_config.cooldown_seconds, 60),
        'observation_mode', COALESCE(v_config.observation_mode, true)
    );
END;
$$;


-- 8. PERMISSÕES DE SEGURANÇA ESTRITAS
REVOKE ALL ON FUNCTION public.get_botconversa_operational_config() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_botconversa_operational_config() TO service_role, postgres;

REVOKE ALL ON FUNCTION public.acquire_botconversa_slot(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.acquire_botconversa_slot(TEXT) TO service_role, postgres;

REVOKE ALL ON FUNCTION public.confirm_botconversa_sent(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_botconversa_sent(TEXT) TO service_role, postgres;

REVOKE ALL ON FUNCTION public.get_whatsapp_botconversa_daily_metrics(DATE) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_whatsapp_botconversa_daily_metrics(DATE) TO service_role, postgres;
