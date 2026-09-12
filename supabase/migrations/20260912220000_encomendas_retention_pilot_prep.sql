-- ==============================================================================
-- CONDOMEET — ONDA C1: PREPARAÇÃO SEGURA PARA PILOTO DE RETENÇÃO DE ENCOMENDAS
-- Migration: 20260912220000_encomendas_retention_pilot_prep.sql
-- 
-- 1. Trigger de Chegada (tr_fn_encomenda_arrived):
--    - Proteção para permitir restauração segura (condomeet.is_restoring_parcel)
--    - Disparo de chegada restrito a encomendas com status = 'pending'
--
-- 2. RPC de Retenção (archive_expired_encomendas):
--    - Adiciona parâmetro p_condominio_id UUID DEFAULT NULL
--    - Proteção estrita contra escopo global acidental (status = 'INVALID_SCOPE' se NULL)
--    - Suporte a lote exato (GREATEST(1, ...)) para testes cirúrgicos de piloto
-- ==============================================================================

-- 1. ATUALIZAÇÃO DO TRIGGER DE CHEGADA COM PROTEÇÃO PARA RESTORE
CREATE OR REPLACE FUNCTION public.tr_fn_encomenda_arrived()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- 1. Ignorar notificações caso a transação esteja em contexto de restauração
  IF current_setting('condomeet.is_restoring_parcel', true) = 'true' THEN
    RETURN NEW;
  END IF;

  -- 2. Apenas encomendas com status 'pending' representam chegada operacional
  IF NEW.status IS DISTINCT FROM 'pending' THEN
    RETURN NEW;
  END IF;

  -- 3. Validação de bloco/apto diretamente do registro da encomenda
  -- Pula notificação se bloco e apto estiverem vazios/nulos
  IF COALESCE(NEW.bloco, '') = '' AND COALESCE(NEW.apto, '') = '' THEN
    RAISE WARNING 'tr_fn_encomenda_arrived: skipping push — no bloco/apto on encomenda %', NEW.id;
    RETURN NEW;
  END IF;

  -- 4. Disparo de notificações de chegada operacional (FCM Push + WhatsApp)
  PERFORM public.push_notify_parcel(
    p_parcel_id  := NEW.id,
    p_event      := 'arrived',
    p_condominio := NEW.condominio_id,
    p_bloco      := COALESCE(NEW.bloco, ''),
    p_apto       := COALESCE(NEW.apto, ''),
    p_tipo       := COALESCE(NEW.tipo, 'pacote')
  );

  RETURN NEW;
END;
$$;

-- 2. SUBSTITUIÇÃO DA RPC archive_expired_encomendas COM FILTRO POR CONDOMÍNIO
-- Dropar assinatura legada de 2 parâmetros para evitar sobrecarga ambígua
DROP FUNCTION IF EXISTS public.archive_expired_encomendas(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION public.archive_expired_encomendas(
    p_batch_size INTEGER DEFAULT 500,
    p_max_batches INTEGER DEFAULT 20,
    p_condominio_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_batch_size INTEGER;
    v_max_batches INTEGER;
    v_batch_id UUID := gen_random_uuid();
    v_log_id UUID;
    v_start_time TIMESTAMPTZ := clock_timestamp();
    v_selected_ids UUID[];
    v_selected_count INTEGER := 0;
    v_verified_count INTEGER := 0;
    v_deleted_count INTEGER := 0;
    v_batch_delivered INTEGER := 0;
    v_batch_pending INTEGER := 0;
    v_total_archived INTEGER := 0;
    v_total_delivered_10d INTEGER := 0;
    v_total_pending_3m INTEGER := 0;
    v_batches_done INTEGER := 0;
    v_status TEXT := 'SUCCESS';
    v_error_msg TEXT := NULL;
    v_has_more_pending BOOLEAN := FALSE;
BEGIN
    -- Proteção contra execução global acidental nesta fase
    IF p_condominio_id IS NULL THEN
        RETURN jsonb_build_object(
            'status', 'INVALID_SCOPE',
            'message', 'Execução global bloqueada. O parâmetro p_condominio_id é obrigatório para execução segura nesta fase.'
        );
    END IF;

    -- Permite lotes a partir de 1 registro para validação cirúrgica de piloto
    v_batch_size := GREATEST(1, LEAST(COALESCE(p_batch_size, 500), 2000));
    v_max_batches := GREATEST(1, LEAST(COALESCE(p_max_batches, 20), 100));

    -- Lock consultivo exclusivo para garantir que apenas uma rotina processe por vez
    IF NOT pg_try_advisory_xact_lock(hashtext('archive_expired_encomendas_lock')) THEN
        RETURN jsonb_build_object(
            'status', 'SKIPPED',
            'message', 'Outra rotina de arquivamento já está em execução neste momento.'
        );
    END IF;

    -- Registro inicial de execução no log de auditoria
    INSERT INTO public.encomendas_archive_log (
        batch_id, started_at, status, executed_by
    ) VALUES (
        v_batch_id, v_start_time, 'RUNNING', format('PILOT_CONDO_%s', p_condominio_id)
    ) RETURNING id INTO v_log_id;

    -- Processamento em lotes atômicos com validação estrita pré-exclusão
    FOR i IN 1..v_max_batches LOOP
        BEGIN
            -- 1. Selecionar IDs elegíveis exclusivamente do condomínio alvo
            SELECT ARRAY(
                SELECT id
                FROM public.encomendas
                WHERE condominio_id = p_condominio_id
                  AND (
                    (status = 'delivered' AND delivery_time < NOW() - INTERVAL '10 days')
                    OR
                    (status = 'pending' AND created_at < NOW() - INTERVAL '3 months')
                )
                ORDER BY created_at ASC
                FOR UPDATE SKIP LOCKED
                LIMIT v_batch_size
            ) INTO v_selected_ids;

            v_selected_count := COALESCE(array_length(v_selected_ids, 1), 0);

            -- Se não houver mais registros elegíveis, encerra o loop de lotes
            IF v_selected_count = 0 THEN
                EXIT;
            END IF;

            -- 2. Copiar integralmente para a tabela de histórico
            INSERT INTO public.encomendas_historico (
                id, resident_id, condominio_id, status, arrival_time, delivery_time,
                photo_url, pickup_proof_url, created_at, tipo, tracking_code, observacao,
                registered_by, picked_up_by_id, picked_up_by_name, bloco, apto,
                silent_discharge, discharged_by, archived_at, archive_batch_id, archive_reason, archived_by
            )
            SELECT 
                e.id, e.resident_id, e.condominio_id, e.status, e.arrival_time, e.delivery_time,
                e.photo_url, e.pickup_proof_url, e.created_at, e.tipo, e.tracking_code, e.observacao,
                e.registered_by, e.picked_up_by_id, e.picked_up_by_name, e.bloco, e.apto,
                e.silent_discharge, e.discharged_by, NOW(), v_batch_id,
                CASE 
                    WHEN e.status = 'delivered' THEN 'DELIVERED_RETENTION_10D'
                    ELSE 'PENDING_RETENTION_3M'
                END,
                'PILOT_CRON'
            FROM public.encomendas e
            WHERE e.id = ANY(v_selected_ids)
            ON CONFLICT (id) DO NOTHING;

            -- 3. Validação de integridade estrita: confirmar persistência no histórico
            SELECT COUNT(*) INTO v_verified_count
            FROM public.encomendas_historico h
            WHERE h.id = ANY(v_selected_ids);

            IF v_verified_count <> v_selected_count THEN
                RAISE EXCEPTION 'Validação de integridade falhou no lote %: selecionados=%, confirmados no histórico=%',
                    i, v_selected_count, v_verified_count;
            END IF;

            -- 4. Exclusão segura apenas dos registros confirmados no histórico
            WITH deleted AS (
                DELETE FROM public.encomendas e
                WHERE e.id = ANY(v_selected_ids)
                  AND EXISTS (
                      SELECT 1 FROM public.encomendas_historico h WHERE h.id = e.id
                  )
                RETURNING e.status
            )
            SELECT 
                COUNT(*),
                COUNT(CASE WHEN status = 'delivered' THEN 1 END),
                COUNT(CASE WHEN status = 'pending' THEN 1 END)
            INTO v_deleted_count, v_batch_delivered, v_batch_pending
            FROM deleted;

            IF v_deleted_count <> v_selected_count THEN
                RAISE EXCEPTION 'Divergência na exclusão do lote %: selecionados=%, excluídos=%',
                    i, v_selected_count, v_deleted_count;
            END IF;

            -- 5. Acumular contadores de execução com sucesso
            v_total_archived := v_total_archived + v_deleted_count;
            v_total_delivered_10d := v_total_delivered_10d + v_batch_delivered;
            v_total_pending_3m := v_total_pending_3m + v_batch_pending;
            v_batches_done := v_batches_done + 1;

        EXCEPTION WHEN OTHERS THEN
            v_error_msg := format('Erro no lote %s (IDs: %s a %s): %s', 
                i, v_selected_ids[1], v_selected_ids[v_selected_count], SQLERRM);
            v_status := 'FAILED';
            EXIT;
        END;
    END LOOP;

    -- 6. Avaliar status de conclusão (SUCCESS vs PARTIAL)
    IF v_status <> 'FAILED' THEN
        IF v_batches_done = v_max_batches THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.encomendas
                WHERE condominio_id = p_condominio_id
                  AND (
                    (status = 'delivered' AND delivery_time < NOW() - INTERVAL '10 days')
                    OR
                    (status = 'pending' AND created_at < NOW() - INTERVAL '3 months')
                )
            ) INTO v_has_more_pending;

            IF v_has_more_pending THEN
                v_status := 'PARTIAL';
            ELSE
                v_status := 'SUCCESS';
            END IF;
        ELSE
            v_status := 'SUCCESS';
        END IF;
    END IF;

    -- 7. Atualizar registro final de auditoria
    UPDATE public.encomendas_archive_log
    SET finished_at = clock_timestamp(),
        duration_ms = EXTRACT(MILLISECONDS FROM (clock_timestamp() - v_start_time))::INTEGER,
        rows_archived = v_total_archived,
        rows_delivered_10d = v_total_delivered_10d,
        rows_pending_3m = v_total_pending_3m,
        batches_processed = v_batches_done,
        status = v_status,
        error_message = v_error_msg
    WHERE id = v_log_id;

    -- 8. Retorno estruturado de execução
    RETURN jsonb_build_object(
        'status', v_status,
        'batch_id', v_batch_id,
        'condominio_id', p_condominio_id,
        'rows_archived', v_total_archived,
        'rows_delivered_10d', v_total_delivered_10d,
        'rows_pending_3m', v_total_pending_3m,
        'batches_processed', v_batches_done,
        'duration_ms', EXTRACT(MILLISECONDS FROM (clock_timestamp() - v_start_time))::INTEGER,
        'error_message', v_error_msg
    );
END;
$$;

-- Permissões estritas: apenas service_role pode executar
REVOKE EXECUTE ON FUNCTION public.archive_expired_encomendas(INTEGER, INTEGER, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.archive_expired_encomendas(INTEGER, INTEGER, UUID) TO service_role;

COMMENT ON FUNCTION public.archive_expired_encomendas(INTEGER, INTEGER, UUID) IS 
'Executa arquivamento cirúrgico de encomendas vencidas por condomínio. Escopo global bloqueado por segurança na fase de piloto.';
