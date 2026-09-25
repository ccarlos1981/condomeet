-- ==============================================================================
-- CONDOMEET — FASE 1: CANCELAMENTO DE ENCOMENDA (WEB + MOBILE + RPC + AUDITORIA)
-- Migration: 20260924173000_encomendas_cancellation.sql
--
-- 1. Adiciona colunas de auditoria de cancelamento em public.encomendas
-- 2. Cria índice parcial para buscas operacionais de canceladas
-- 3. Cria a RPC atômica public.cancel_encomenda com validação estrita de pending_del
-- 4. Atualiza cirurgicamente public.get_encomendas_stats para respeitar:
--    CANCELLED != PENDING, CANCELLED != DELIVERED, CANCELLED != ARCHIVED
-- ==============================================================================

-- 1. Colunas de auditoria cirúrgica em public.encomendas
ALTER TABLE public.encomendas 
    ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS cancelled_by UUID NULL REFERENCES public.perfil(id),
    ADD COLUMN IF NOT EXISTS cancellation_reason TEXT NULL DEFAULT 'REGISTERED_BY_MISTAKE';

COMMENT ON COLUMN public.encomendas.cancelled_at IS 'Data/hora exata em que a encomenda foi cancelada pela portaria/administração.';
COMMENT ON COLUMN public.encomendas.cancelled_by IS 'UUID do perfil do operador (portaria/admin/síndico) que efetuou o cancelamento.';
COMMENT ON COLUMN public.encomendas.cancellation_reason IS 'Motivo auditável do cancelamento (ex: REGISTERED_BY_MISTAKE).';

-- 2. Índices parciais de performance e auditoria
CREATE INDEX IF NOT EXISTS idx_encomendas_condo_cancelled 
    ON public.encomendas (condominio_id, status) 
    WHERE status = 'cancelled';

CREATE INDEX IF NOT EXISTS idx_encomendas_cancelled_by 
    ON public.encomendas (cancelled_by) 
    WHERE cancelled_by IS NOT NULL;

-- 3. RPC Atômica de Cancelamento: public.cancel_encomenda
CREATE OR REPLACE FUNCTION public.cancel_encomenda(
    p_encomenda_id UUID,
    p_reason TEXT DEFAULT 'REGISTERED_BY_MISTAKE'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_condo_id UUID;
    v_status TEXT;
    v_bloco TEXT;
    v_apto TEXT;
    v_tipo TEXT;
    v_rows_affected INTEGER;
BEGIN
    -- A. Autenticação mandatória
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Acesso não autenticado' USING ERRCODE = '42501';
    END IF;

    IF p_encomenda_id IS NULL THEN
        RAISE EXCEPTION 'ID da encomenda é obrigatório' USING ERRCODE = '22023';
    END IF;

    -- B. Localização e bloqueio pessimista (FOR UPDATE) para serialização de concorrência
    SELECT condominio_id, status, bloco, apto, tipo
      INTO v_condo_id, v_status, v_bloco, v_apto, v_tipo
      FROM public.encomendas
     WHERE id = p_encomenda_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'NOT_FOUND',
            'message', 'Encomenda não encontrada.'
        );
    END IF;

    -- C. Autorização estrita baseada em pending_del (Invariante 2, ADR-002 e ADR-003)
    IF NOT public.has_condo_feature_access(v_condo_id, 'pending_del') THEN
        RAISE EXCEPTION 'Acesso negado: perfil não autorizado para cancelamento de encomendas'
            USING ERRCODE = '42501';
    END IF;

    -- D. Validação de ciclo de vida e Idempotência estrita
    IF v_status = 'cancelled' THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'ALREADY_CANCELLED',
            'message', 'Esta encomenda já foi cancelada anteriormente.'
        );
    END IF;

    IF v_status = 'delivered' THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'ALREADY_DELIVERED',
            'message', 'Não é possível cancelar uma encomenda que já foi entregue.'
        );
    END IF;

    IF v_status <> 'pending' THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'INVALID_STATUS',
            'message', 'Apenas encomendas com status Aguardando podem ser canceladas.'
        );
    END IF;

    -- E. Mutação atômica condicionada a status = pending
    UPDATE public.encomendas
       SET status = 'cancelled',
           cancelled_at = clock_timestamp(),
           cancelled_by = v_uid,
           cancellation_reason = COALESCE(NULLIF(TRIM(p_reason), ''), 'REGISTERED_BY_MISTAKE')
     WHERE id = p_encomenda_id
       AND status = 'pending';

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'CONCURRENT_CONFLICT',
            'message', 'A encomenda foi alterada concorrentemente por outro operador.'
        );
    END IF;

    -- F. Disparo da notificação push FCM para a unidade via push_notify_parcel
    PERFORM public.push_notify_parcel(
        p_parcel_id  := p_encomenda_id,
        p_event      := 'cancelled',
        p_condominio := v_condo_id,
        p_bloco      := COALESCE(v_bloco, ''),
        p_apto       := COALESCE(v_apto, ''),
        p_tipo       := COALESCE(v_tipo, 'pacote')
    );

    RETURN jsonb_build_object(
        'success', true,
        'parcel_id', p_encomenda_id,
        'status', 'cancelled'
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cancel_encomenda(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_encomenda(UUID, TEXT) TO authenticated, service_role;

COMMENT ON FUNCTION public.cancel_encomenda(UUID, TEXT) IS 
'Cancela atomicamente uma encomenda com status pending, registrando auditoria e acionando push corretivo aos moradores.';

-- 4. Atualização cirúrgica de get_encomendas_stats
CREATE OR REPLACE FUNCTION public.get_encomendas_stats(
    p_condominio_id UUID,
    p_bloco TEXT DEFAULT NULL,
    p_apto TEXT DEFAULT NULL
)
RETURNS TABLE (
    total BIGINT,
    pending BIGINT,
    delivered BIGINT,
    archived BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_has_bloco BOOLEAN;
    v_has_apto BOOLEAN;
    v_clean_bloco TEXT;
    v_clean_apto TEXT;
    v_pending BIGINT;
    v_delivered BIGINT;
    v_total BIGINT;
    v_archived BIGINT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Acesso não autenticado' USING ERRCODE = '42501';
    END IF;
    IF p_condominio_id IS NULL THEN
        RAISE EXCEPTION 'condominio_id é obrigatório' USING ERRCODE = '22023';
    END IF;

    -- Validação centralizada de autorização dinâmica da funcionalidade
    IF NOT public.has_condo_feature_access(p_condominio_id, 'pending_del') THEN
        RAISE EXCEPTION 'Acesso negado: perfil não autorizado para estatísticas de encomendas' USING ERRCODE = '42501';
    END IF;

    v_clean_bloco := NULLIF(TRIM(COALESCE(p_bloco, '')), '');
    v_clean_apto  := NULLIF(TRIM(COALESCE(p_apto, '')), '');
    v_has_bloco   := v_clean_bloco IS NOT NULL;
    v_has_apto    := v_clean_apto IS NOT NULL;

    IF v_has_bloco AND v_has_apto THEN
        SELECT count(*) INTO v_pending FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'pending' AND e.bloco = v_clean_bloco AND e.apto = v_clean_apto;
        SELECT count(*) INTO v_delivered FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'delivered' AND e.bloco = v_clean_bloco AND e.apto = v_clean_apto;
        SELECT count(*) INTO v_archived FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'archived' AND e.bloco = v_clean_bloco AND e.apto = v_clean_apto;
        SELECT count(*) INTO v_total FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.bloco = v_clean_bloco AND e.apto = v_clean_apto AND e.status <> 'cancelled';
    ELSIF v_has_bloco THEN
        SELECT count(*) INTO v_pending FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'pending' AND e.bloco = v_clean_bloco;
        SELECT count(*) INTO v_delivered FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'delivered' AND e.bloco = v_clean_bloco;
        SELECT count(*) INTO v_archived FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'archived' AND e.bloco = v_clean_bloco;
        SELECT count(*) INTO v_total FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.bloco = v_clean_bloco AND e.status <> 'cancelled';
    ELSIF v_has_apto THEN
        SELECT count(*) INTO v_pending FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'pending' AND e.apto = v_clean_apto;
        SELECT count(*) INTO v_delivered FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'delivered' AND e.apto = v_clean_apto;
        SELECT count(*) INTO v_archived FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'archived' AND e.apto = v_clean_apto;
        SELECT count(*) INTO v_total FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.apto = v_clean_apto AND e.status <> 'cancelled';
    ELSE
        SELECT count(*) INTO v_pending FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'pending';
        SELECT count(*) INTO v_delivered FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'delivered';
        SELECT count(*) INTO v_archived FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status = 'archived';
        SELECT count(*) INTO v_total FROM public.encomendas e WHERE e.condominio_id = p_condominio_id AND e.status <> 'cancelled';
    END IF;

    RETURN QUERY SELECT v_total, v_pending, v_delivered, v_archived;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_encomendas_stats(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_encomendas_stats(UUID, TEXT, TEXT) TO authenticated, service_role;
