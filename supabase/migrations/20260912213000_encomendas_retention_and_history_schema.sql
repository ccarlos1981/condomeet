-- ============================================================================
-- CONDOMEET — RETENÇÃO E HISTÓRICO DE ENCOMENDAS
-- ONDA A: INFRAESTRUTURA DE BANCO DE DADOS (APROVADA E CONTROLADA)
-- Data: 2026-09-12
-- Target: condomeet_Antigravity (avypyaxthvgaybplnwxu)
-- ============================================================================

-- 1. TABELA HISTÓRICA: public.encomendas_historico
CREATE TABLE IF NOT EXISTS public.encomendas_historico (
    -- 19 Colunas Originais com Paridade 1:1 com public.encomendas
    id                  UUID PRIMARY KEY,
    resident_id         UUID,
    condominio_id       UUID NOT NULL,
    status              TEXT NOT NULL,
    arrival_time        TIMESTAMPTZ,
    delivery_time       TIMESTAMPTZ,
    photo_url           TEXT,
    pickup_proof_url    TEXT,
    created_at          TIMESTAMPTZ NOT NULL,
    tipo                TEXT,
    tracking_code       TEXT,
    observacao          TEXT,
    registered_by       UUID,
    picked_up_by_id     UUID,
    picked_up_by_name   TEXT,
    bloco               TEXT,
    apto                TEXT,
    silent_discharge    BOOLEAN DEFAULT false,
    discharged_by       UUID,

    -- 4 Colunas Exclusivas de Governança e Auditoria
    archived_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    archive_batch_id    UUID NOT NULL,
    archive_reason      TEXT NOT NULL,
    archived_by         TEXT NOT NULL DEFAULT 'SYSTEM_CRON',

    -- Constraints de Integridade e Auditoria
    CONSTRAINT fk_encomendas_historico_condominio 
        FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE RESTRICT,
    CONSTRAINT chk_encomendas_historico_reason 
        CHECK (archive_reason IN (
            'DELIVERED_RETENTION_10D',
            'PENDING_RETENTION_3M',
            'LEGACY_ARCHIVED_MIGRATION',
            'MANUAL_ARCHIVE'
        )),
    CONSTRAINT chk_encomendas_historico_tipo 
        CHECK (tipo IS NULL OR tipo = ANY (ARRAY['caixa'::text, 'envelope'::text, 'pacote'::text, 'notif_judicial'::text]))
);

COMMENT ON TABLE public.encomendas_historico IS 'Tabela espelho dedicada para retenção permanente e auditoria de encomendas descarregadas da tabela operacional.';
COMMENT ON COLUMN public.encomendas_historico.archive_batch_id IS 'Identificador UUID do lote da rotina de retenção que moveu o registro.';
COMMENT ON COLUMN public.encomendas_historico.archive_reason IS 'Motivo auditável do arquivamento (DELIVERED_RETENTION_10D, PENDING_RETENTION_3M, LEGACY_ARCHIVED_MIGRATION, MANUAL_ARCHIVE).';

-- 2. ÍNDICES ESTRITOS (5 índices aprovados)
CREATE INDEX IF NOT EXISTS idx_encomendas_historico_condo_delivery 
ON public.encomendas_historico (condominio_id, delivery_time DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_encomendas_historico_condo_bloco_apto 
ON public.encomendas_historico (condominio_id, bloco, apto);

CREATE INDEX IF NOT EXISTS idx_encomendas_historico_resident 
ON public.encomendas_historico (resident_id);

CREATE INDEX IF NOT EXISTS idx_encomendas_historico_batch 
ON public.encomendas_historico (archive_batch_id);

-- 3. TABELA DE LOG: public.encomendas_archive_log
CREATE TABLE IF NOT EXISTS public.encomendas_archive_log (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id                UUID NOT NULL,
    started_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at             TIMESTAMPTZ,
    duration_ms             INTEGER,
    rows_archived           INTEGER NOT NULL DEFAULT 0,
    rows_delivered_10d      INTEGER NOT NULL DEFAULT 0,
    rows_pending_3m         INTEGER NOT NULL DEFAULT 0,
    rows_legacy_archived    INTEGER NOT NULL DEFAULT 0,
    batches_processed       INTEGER NOT NULL DEFAULT 0,
    status                  TEXT NOT NULL DEFAULT 'RUNNING',
    error_message           TEXT,
    executed_by             TEXT NOT NULL DEFAULT 'SYSTEM_CRON',

    CONSTRAINT chk_archive_log_status 
        CHECK (status IN ('RUNNING', 'SUCCESS', 'PARTIAL', 'FAILED'))
);

CREATE INDEX IF NOT EXISTS idx_encomendas_archive_log_batch 
ON public.encomendas_archive_log (batch_id);

COMMENT ON TABLE public.encomendas_archive_log IS 'Log operacional e métricas de auditoria para execuções da rotina de retenção de encomendas.';

-- 4. RLS E POLICIES NA TABELA HISTÓRICA
ALTER TABLE public.encomendas_historico ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.encomendas_historico FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.encomendas_historico TO authenticated;
GRANT ALL ON public.encomendas_historico TO service_role;

-- Policy 1: Admin e Portaria (somente registros do próprio condomínio)
DROP POLICY IF EXISTS "portaria_admin_select_encomendas_historico" ON public.encomendas_historico;
CREATE POLICY "portaria_admin_select_encomendas_historico"
ON public.encomendas_historico FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.perfil p
        WHERE p.id = auth.uid()
          AND p.condominio_id = encomendas_historico.condominio_id
          AND p.status_aprovacao = 'aprovado'
          AND COALESCE(p.bloqueado, false) = false
          AND (
              p.papel_sistema ILIKE ANY (ARRAY[
                  '%portaria%', '%porteiro%', '%síndico%', '%sindico%', 
                  '%subsíndico%', '%subsindico%', '%admin%', '%administrador%', '%administradora%'
              ])
          )
    )
);

-- Policy 2: Moradores (somente encomendas próprias da unidade residencial)
DROP POLICY IF EXISTS "morador_select_proprio_encomendas_historico" ON public.encomendas_historico;
CREATE POLICY "morador_select_proprio_encomendas_historico"
ON public.encomendas_historico FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.perfil p
        WHERE p.id = auth.uid()
          AND p.condominio_id = encomendas_historico.condominio_id
          AND p.status_aprovacao = 'aprovado'
          AND COALESCE(p.bloqueado, false) = false
          AND (
              encomendas_historico.resident_id = auth.uid()
              OR (
                  p.bloco_txt IS NOT NULL 
                  AND p.apto_txt IS NOT NULL 
                  AND p.bloco_txt = encomendas_historico.bloco 
                  AND p.apto_txt = encomendas_historico.apto
              )
          )
    )
);

-- 5. RPC DE RETENÇÃO (INFRAESTRUTURA — NÃO EXECUTADA NESTA ONDA)
CREATE OR REPLACE FUNCTION public.archive_expired_encomendas(
    p_batch_size INTEGER DEFAULT 500,
    p_max_batches INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    -- Parâmetros sanitizados com limites seguros
    v_batch_size INTEGER;
    v_max_batches INTEGER;

    -- Identificadores e auditoria
    v_batch_id UUID := gen_random_uuid();
    v_log_id UUID;
    v_start_time TIMESTAMPTZ := clock_timestamp();

    -- Variáveis de controle de lote
    v_selected_ids UUID[];
    v_selected_count INTEGER := 0;
    v_verified_count INTEGER := 0;
    v_deleted_count INTEGER := 0;

    -- Variáveis de contagem por lote
    v_batch_delivered INTEGER := 0;
    v_batch_pending INTEGER := 0;

    -- Acumuladores globais da execução
    v_total_archived INTEGER := 0;
    v_total_delivered_10d INTEGER := 0;
    v_total_pending_3m INTEGER := 0;
    v_batches_done INTEGER := 0;

    -- Controle de status e erro
    v_status TEXT := 'SUCCESS';
    v_error_msg TEXT := NULL;
    v_has_more_pending BOOLEAN := FALSE;
BEGIN
    -- 1. Validação e Clamping Seguro de Parâmetros
    -- batch_size: mín 100, padrão 500, máx 2.000 (evita locks excessivos e pico de WAL)
    v_batch_size := GREATEST(100, LEAST(COALESCE(p_batch_size, 500), 2000));
    -- max_batches: mín 1, padrão 20, máx 100 (evita execução infinita)
    v_max_batches := GREATEST(1, LEAST(COALESCE(p_max_batches, 20), 100));

    -- 2. Proteção de Concorrência: Trava transacional não bloqueante
    IF NOT pg_try_advisory_xact_lock(hashtext('archive_expired_encomendas_lock')) THEN
        RETURN jsonb_build_object(
            'status', 'SKIPPED',
            'message', 'Outra rotina de arquivamento já está em execução neste momento.'
        );
    END IF;

    -- 3. Inicialização Atômica do Log
    INSERT INTO public.encomendas_archive_log (
        batch_id, started_at, status, executed_by
    ) VALUES (
        v_batch_id, v_start_time, 'RUNNING', 'SYSTEM_CRON'
    ) RETURNING id INTO v_log_id;

    -- 4. Processamento em Lotes com Subtransação Isolada por Lote
    FOR i IN 1..v_max_batches LOOP
        BEGIN
            -- 4.1. Seleciona IDs elegíveis travando contra portaria concorrente
            SELECT ARRAY(
                SELECT id
                FROM public.encomendas
                WHERE (
                    (status = 'delivered' AND delivery_time < NOW() - INTERVAL '10 days')
                    OR
                    (status = 'pending' AND created_at < NOW() - INTERVAL '3 months')
                )
                ORDER BY created_at ASC
                FOR UPDATE SKIP LOCKED
                LIMIT v_batch_size
            ) INTO v_selected_ids;

            v_selected_count := COALESCE(array_length(v_selected_ids, 1), 0);

            -- Se não há mais registros elegíveis, encerra o loop
            IF v_selected_count = 0 THEN
                EXIT;
            END IF;

            -- 4.2. Copia integralmente os registros para o histórico
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
                'SYSTEM_CRON'
            FROM public.encomendas e
            WHERE e.id = ANY(v_selected_ids)
            ON CONFLICT (id) DO NOTHING;

            -- 4.3. Validação Rigorosa: 100% dos IDs selecionados DEVEM existir no histórico
            SELECT COUNT(*) INTO v_verified_count
            FROM public.encomendas_historico h
            WHERE h.id = ANY(v_selected_ids);

            IF v_verified_count <> v_selected_count THEN
                RAISE EXCEPTION 'Validação de integridade falhou no lote %: selecionados=%, confirmados no histórico=%',
                    i, v_selected_count, v_verified_count;
            END IF;

            -- 4.4. Remove da operacional SOMENTE com confirmação de presença no histórico
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

            -- Validação do delete: contagem deve bater com a seleção
            IF v_deleted_count <> v_selected_count THEN
                RAISE EXCEPTION 'Divergência na exclusão do lote %: selecionados=%, excluídos=%',
                    i, v_selected_count, v_deleted_count;
            END IF;

            -- 4.5. Acumula contadores globais com segurança
            v_total_archived := v_total_archived + v_deleted_count;
            v_total_delivered_10d := v_total_delivered_10d + v_batch_delivered;
            v_total_pending_3m := v_total_pending_3m + v_batch_pending;
            v_batches_done := v_batches_done + 1;

        EXCEPTION WHEN OTHERS THEN
            -- Rollback automático da subtransação deste lote específico
            v_error_msg := format('Erro no lote %s (IDs: %s a %s): %s', 
                i, v_selected_ids[1], v_selected_ids[v_selected_count], SQLERRM);
            v_status := 'FAILED';
            EXIT; -- Interrompe o processamento preservando lotes anteriores comitados
        END;
    END LOOP;

    -- 5. Determinação Determinística de Status (SUCCESS vs PARTIAL)
    IF v_status <> 'FAILED' THEN
        -- Se o loop executou todos os lotes permitidos, verifica se a fila ainda contém registros
        IF v_batches_done = v_max_batches THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.encomendas
                WHERE (
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

    -- 6. Atualização Definitiva do Log (Garantida de Sobreviver)
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

    -- 7. Retorno Estruturado
    RETURN jsonb_build_object(
        'status', v_status,
        'batch_id', v_batch_id,
        'rows_archived', v_total_archived,
        'rows_delivered_10d', v_total_delivered_10d,
        'rows_pending_3m', v_total_pending_3m,
        'batches_processed', v_batches_done,
        'duration_ms', EXTRACT(MILLISECONDS FROM (clock_timestamp() - v_start_time))::INTEGER,
        'error_message', v_error_msg
    );
END;
$$;

-- Permissões estritas da RPC
REVOKE ALL ON FUNCTION public.archive_expired_encomendas(INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.archive_expired_encomendas(INTEGER, INTEGER) TO service_role;
