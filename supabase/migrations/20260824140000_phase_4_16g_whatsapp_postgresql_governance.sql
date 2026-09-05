-- ==============================================================================
-- Migration: 20260824140000_phase_4_16g_whatsapp_postgresql_governance.sql
-- Description: FASE 4.16G — Implementação da Proteção Definitiva PostgreSQL
--              da Mensageria WhatsApp (RPC Canônica, Colunas de Governança,
--              Revogação de Inserção Direta, Trava de Cardinalidade,
--              Derivação Multi-Tenancy e Idempotência Real).
-- ==============================================================================

-- 1. ADICIONAR COLUNAS DE GOVERNANÇA À TABELA WHATSAPP_OUTBOX
ALTER TABLE public.whatsapp_outbox
  ADD COLUMN IF NOT EXISTS entity_type TEXT,
  ADD COLUMN IF NOT EXISTS entity_id UUID,
  ADD COLUMN IF NOT EXISTS caller_function TEXT,
  ADD COLUMN IF NOT EXISTS transaction_id UUID DEFAULT gen_random_uuid();

-- 2. ÍNDICES DE PERFORMANCE, CARDINALIDADE E IDEMPOTÊNCIA
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_cardinality_eval
  ON public.whatsapp_outbox (entity_type, entity_id, message_type);

CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_quota_eval
  ON public.whatsapp_outbox (condominio_id, entity_type, created_at);

CREATE UNIQUE INDEX IF NOT EXISTS idx_whatsapp_outbox_tx_phone
  ON public.whatsapp_outbox (transaction_id, recipient_phone)
  WHERE transaction_id IS NOT NULL;

-- 3. CRIAR A RPC CANÔNICA DE GOVERNANÇA E ENFILEIRAMENTO ATÔMICO
CREATE OR REPLACE FUNCTION public.enqueue_whatsapp_transactional_message(
    p_recipient_phone TEXT,
    p_payload_type TEXT,
    p_message_type TEXT,
    p_message_content JSONB,
    p_caller_function TEXT,
    p_entity_type TEXT,
    p_entity_id UUID DEFAULT NULL,
    p_condominio_id UUID DEFAULT NULL,
    p_perfil_id UUID DEFAULT NULL,
    p_transaction_id UUID DEFAULT NULL,
    p_scheduled_for TIMESTAMPTZ DEFAULT now(),
    p_priority INTEGER DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_outbox_id UUID;
    v_canonical_phone TEXT;
    v_derived_condo_id UUID;
    v_priority INTEGER;
    v_message_hash TEXT;
    v_entity_count INTEGER;
    v_max_recipients INTEGER;
    v_recent_quota INTEGER;
    v_normalized_entity TEXT;
BEGIN
    -- ── 1. Normalização rigorosa do Telefone Canônico E.164 ──────────────────
    v_canonical_phone := regexp_replace(COALESCE(p_recipient_phone, ''), '\D', '', 'g');
    IF NOT (v_canonical_phone LIKE '55%') THEN
        v_canonical_phone := '55' || v_canonical_phone;
    END IF;
    IF length(v_canonical_phone) < 12 OR length(v_canonical_phone) > 13 THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Telefone inválido (%)', p_recipient_phone;
    END IF;

    -- ── 2. Validação da Whitelist Fechada de Caller Functions ────────────────
    IF p_caller_function NOT IN (
        'whatsapp-parcel-notify',
        'convite-whatsapp-notify',
        'visitor-register-whatsapp-notify',
        'whatsapp-guest',
        'password-reset-whatsapp',
        'sos-push-notify',
        'garagem-notify',
        'classificados-notify',
        'optin-whatsapp-cron',
        'whatsapp-chatbot',
        'indicacoes-notify',
        'documentos-vencimento-check',
        'reserva-notify',
        'welcome-notify',
        'approval-notify',
        'fale-sindico-notify',
        'ocorrencia-notify',
        'botconversa-send',
        'dual-number-routine',
        'whatsapp-outbox-worker'
    ) THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: caller_function não autorizado (%)', p_caller_function;
    END IF;

    -- ── 3. Validação do MessageType e Matriz Caller -> MessageType ───────────
    IF p_message_type NOT IN (
        'PARCEL', 'PARCEL_DELIVERED', 'VISITOR_INVITE', 'VISITOR_AUTHORIZED',
        'OTP', 'SOS', 'RESERVATION', 'NOTICE', 'WELCOME', 'FINANCIAL',
        'TEXTO_LIVRE', 'RESPOSTA_MORADOR', 'DUAL_NUMBER_NOTICE'
    ) THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: message_type não homologado (%)', p_message_type;
    END IF;

    -- Validação da matriz estrita caller -> MessageType
    IF p_caller_function = 'whatsapp-parcel-notify' AND p_message_type NOT IN ('PARCEL', 'PARCEL_DELIVERED') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: whatsapp-parcel-notify não pode emitir %', p_message_type;
    ELSIF p_caller_function IN ('convite-whatsapp-notify', 'visitor-register-whatsapp-notify') AND p_message_type NOT IN ('VISITOR_INVITE', 'VISITOR_AUTHORIZED') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: % não pode emitir %', p_caller_function, p_message_type;
    ELSIF p_caller_function = 'whatsapp-guest' AND p_message_type NOT IN ('VISITOR_INVITE') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: whatsapp-guest não pode emitir %', p_message_type;
    ELSIF p_caller_function = 'password-reset-whatsapp' AND p_message_type NOT IN ('OTP') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: password-reset-whatsapp só pode emitir OTP';
    ELSIF p_caller_function = 'sos-push-notify' AND p_message_type NOT IN ('SOS') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: sos-push-notify só pode emitir SOS';
    ELSIF p_caller_function IN ('welcome-notify', 'approval-notify') AND p_message_type NOT IN ('WELCOME') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: % só pode emitir WELCOME', p_caller_function;
    ELSIF p_caller_function = 'dual-number-routine' AND p_message_type NOT IN ('DUAL_NUMBER_NOTICE') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: dual-number-routine só pode emitir DUAL_NUMBER_NOTICE';
    END IF;

    -- ── 4. Normalização do nome da entidade ──────────────────────────────────
    v_normalized_entity := LOWER(TRIM(p_entity_type));

    -- ── 5. Derivação e Validação Física da Entidade de Negócio ───────────────
    CASE v_normalized_entity
        WHEN 'encomendas', 'encomenda' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.encomendas WHERE id = p_entity_id;
            v_max_recipients := 5; -- Até 5 destinatários por evento (chegada / retirada)

        WHEN 'convites', 'convite' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.convites WHERE id = p_entity_id;
            v_max_recipients := 3;

        WHEN 'visitante_registros', 'visitante_registro' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.visitante_registros WHERE id = p_entity_id;
            v_max_recipients := 5;

        WHEN 'sos_alerts', 'sos_alertas', 'sos_alerta' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.sos_alertas WHERE id = p_entity_id;
            v_max_recipients := 10;

        WHEN 'garage_reservations', 'garagem' THEN
            SELECT g.condominio_id INTO v_derived_condo_id 
            FROM public.garage_reservations gr 
            JOIN public.garages g ON g.id = gr.garage_id 
            WHERE gr.id = p_entity_id;
            v_max_recipients := 4;

        WHEN 'classificados', 'classificado' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.classificados WHERE id = p_entity_id;
            v_max_recipients := 6;

        WHEN 'ocorrencias', 'ocorrencia', 'occurrences' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.ocorrencias WHERE id = p_entity_id;
            v_max_recipients := 6;

        WHEN 'fale_sindico_threads', 'fale_sindico' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.fale_sindico_threads WHERE id = p_entity_id;
            v_max_recipients := 6;

        WHEN 'documentos', 'documento' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.documentos WHERE id = p_entity_id;
            v_max_recipients := 4;

        WHEN 'contratos', 'contrato' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.contratos WHERE id = p_entity_id;
            v_max_recipients := 4;

        WHEN 'indicacoes_servico', 'indicacao' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.indicacoes_servico WHERE id = p_entity_id;
            v_max_recipients := 2;

        WHEN 'reservas', 'reserva' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.reservas WHERE id = p_entity_id;
            v_max_recipients := 6;

        WHEN 'perfil' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.perfil WHERE id = p_entity_id;
            IF p_message_type = 'WELCOME' THEN
                v_max_recipients := 6;
            ELSIF p_message_type = 'NOTICE' AND p_caller_function = 'optin-whatsapp-cron' THEN
                v_max_recipients := 2;
            ELSIF p_message_type IN ('TEXTO_LIVRE', 'RESPOSTA_MORADOR') AND p_caller_function = 'whatsapp-chatbot' THEN
                v_max_recipients := 10;
            ELSE
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Combinação não homologada de MessageType % com entidade perfil', p_message_type;
            END IF;

        WHEN 'auth_users', 'auth_user' THEN
            IF p_message_type <> 'OTP' THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: auth_users só pode emitir OTP';
            END IF;
            -- Quota de OTP: Máximo 5 por telefone a cada 60 minutos
            SELECT COUNT(*) INTO v_recent_quota
            FROM public.whatsapp_outbox
            WHERE message_type = 'OTP'
              AND recipient_phone = v_canonical_phone
              AND created_at > (now() - INTERVAL '1 hour');
            IF v_recent_quota >= 5 THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Limite de OTP excedido para este telefone (máx 5/hora)';
            END IF;
            v_derived_condo_id := p_condominio_id;
            v_max_recipients := 999;

        WHEN 'manual_admin' THEN
            IF p_condominio_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: condominio_id obrigatório para manual_admin';
            END IF;
            -- Quota horária de manual_admin: Máximo 15 por condomínio a cada 60 minutos
            SELECT COUNT(*) INTO v_recent_quota
            FROM public.whatsapp_outbox
            WHERE entity_type = 'manual_admin'
              AND condominio_id = p_condominio_id
              AND created_at > (now() - INTERVAL '1 hour');
            IF v_recent_quota >= 15 THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Quota horária de mensagens manuais excedida para este condomínio (máx 15/hora). Use Push FCM.';
            END IF;
            v_derived_condo_id := p_condominio_id;
            v_max_recipients := 5;

        WHEN 'dual_number_notices', 'dual_number_notice' THEN
            v_derived_condo_id := p_condominio_id;
            v_max_recipients := 1;

        ELSE
            RAISE EXCEPTION 'GOVERNANCE_BLOCKED: entity_type não homologado (%)', p_entity_type;
    END CASE;

    -- ── 6. Multi-Tenancy Guard ───────────────────────────────────────────────
    IF v_normalized_entity NOT IN ('auth_users', 'auth_user', 'manual_admin', 'dual_number_notices', 'dual_number_notice') THEN
        IF v_derived_condo_id IS NULL THEN
            RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Entidade % (%) não encontrada no banco de dados', p_entity_type, p_entity_id;
        END IF;
        IF p_condominio_id IS NOT NULL AND p_condominio_id <> v_derived_condo_id THEN
            RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Violação de multi-tenancy. Entidade % pertence ao condomínio %, não %', p_entity_id, v_derived_condo_id, p_condominio_id;
        END IF;
    END IF;

    -- ── 7. Advisory Lock Transacional por Entidade (Anti-Race Condition) ─────
    PERFORM pg_advisory_xact_lock(hashtext(v_normalized_entity || ':' || COALESCE(p_entity_id::text, v_canonical_phone)));

    -- ── 8. Validação de Cardinalidade Atômica ────────────────────────────────
    IF v_normalized_entity NOT IN ('auth_users', 'auth_user', 'manual_admin', 'dual_number_notices', 'dual_number_notice') THEN
        SELECT COUNT(*) INTO v_entity_count
        FROM public.whatsapp_outbox
        WHERE entity_type IN (v_normalized_entity, CASE WHEN v_normalized_entity LIKE '%s' THEN substring(v_normalized_entity from 1 for length(v_normalized_entity)-1) ELSE v_normalized_entity || 's' END)
          AND entity_id = p_entity_id
          AND message_type = p_message_type
          AND status IN ('pending', 'sending', 'sent');

        IF v_entity_count >= v_max_recipients THEN
            RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Cardinalidade máxima excedida para % % (máx: %)', p_entity_type, p_message_type, v_max_recipients;
        END IF;
    END IF;

    -- ── 9. Derivação de Prioridade de Fila ───────────────────────────────────
    IF p_priority IS NOT NULL THEN
        v_priority := p_priority;
    ELSE
        CASE p_message_type
            WHEN 'SOS', 'OTP' THEN v_priority := 1;
            WHEN 'VISITOR_INVITE', 'VISITOR_AUTHORIZED' THEN v_priority := 2;
            WHEN 'PARCEL', 'PARCEL_DELIVERED', 'RESERVATION', 'TEXTO_LIVRE', 'RESPOSTA_MORADOR' THEN v_priority := 10;
            WHEN 'NOTICE', 'WELCOME' THEN v_priority := 15;
            WHEN 'FINANCIAL' THEN v_priority := 20;
            WHEN 'DUAL_NUMBER_NOTICE' THEN v_priority := 25;
            ELSE v_priority := 15;
        END CASE;
    END IF;

    -- ── 10. Cálculo Determinístico do Hash ───────────────────────────────────
    v_message_hash := encode(sha256((v_canonical_phone || ':' || p_payload_type || ':' || COALESCE(p_message_content->>'value', p_message_content::text) || ':' || COALESCE(v_derived_condo_id::text, '0'))::bytea), 'hex');

    -- ── 11. Idempotência Transacional (transaction_id) ───────────────────────
    IF p_transaction_id IS NOT NULL THEN
        SELECT id INTO v_outbox_id
        FROM public.whatsapp_outbox
        WHERE transaction_id = p_transaction_id
          AND recipient_phone = v_canonical_phone
        LIMIT 1;

        IF v_outbox_id IS NOT NULL THEN
            RETURN v_outbox_id;
        END IF;
    END IF;

    -- ── 12. Inserção Segura na Tabela whatsapp_outbox ────────────────────────
    INSERT INTO public.whatsapp_outbox (
        condominio_id,
        recipient_phone,
        payload_type,
        message_type,
        message_content,
        priority,
        message_hash,
        caller_function,
        entity_type,
        entity_id,
        perfil_id,
        transaction_id,
        status,
        next_attempt_at,
        created_at,
        updated_at
    ) VALUES (
        v_derived_condo_id,
        v_canonical_phone,
        p_payload_type,
        p_message_type,
        p_message_content,
        v_priority,
        v_message_hash,
        p_caller_function,
        v_normalized_entity,
        p_entity_id,
        p_perfil_id,
        COALESCE(p_transaction_id, gen_random_uuid()),
        'pending',
        COALESCE(p_scheduled_for, now()),
        now(),
        now()
    ) RETURNING id INTO v_outbox_id;

    RETURN v_outbox_id;
END;
$$;

-- 4. MATRIZ DE PERMISSÕES E HARDENING DE SEGURANÇA
-- Revogação de inserção direta na tabela whatsapp_outbox
REVOKE INSERT, DELETE, TRUNCATE ON public.whatsapp_outbox FROM anon, authenticated, service_role;

-- Manter SELECT e UPDATE para service_role (Worker precisa ler e atualizar status)
GRANT SELECT, UPDATE ON public.whatsapp_outbox TO service_role;

-- Permissões estritas na RPC Canônica
REVOKE EXECUTE ON FUNCTION public.enqueue_whatsapp_transactional_message FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enqueue_whatsapp_transactional_message TO authenticated, service_role;
