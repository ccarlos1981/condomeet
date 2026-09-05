-- ============================================================================
-- FASE 4.19 — GOVERNANÇA DE ONBOARDING, CAP DE WELCOME E AVISO AOS RESPONSÁVEIS
-- ============================================================================

-- 1. ESTRUTURA PARA CAP DIÁRIO INDEPENDENTE DE WELCOME
ALTER TABLE public.whatsapp_health_status
ADD COLUMN IF NOT EXISTS welcome_warmup_daily_cap INTEGER DEFAULT 20,
ADD COLUMN IF NOT EXISTS welcome_warmup_sent_today INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS welcome_warmup_date_reset DATE DEFAULT CURRENT_DATE;

-- 2. RPC ATÔMICA PARA CONTROLE DO LIMITE DIÁRIO DE WELCOME (ANTI-RACE CONDITION)
CREATE OR REPLACE FUNCTION public.check_and_increment_welcome_warmup_cap(
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
BEGIN
    -- Advisory Lock atômico específico para concorrência de WELCOME
    PERFORM pg_advisory_xact_lock(hashtext('welcome_warmup_cap_lock'));

    SELECT welcome_warmup_daily_cap, welcome_warmup_sent_today, welcome_warmup_date_reset
    INTO v_rec
    FROM public.whatsapp_health_status
    WHERE id = p_instance_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'can_send_welcome', false,
            'reason', 'HEALTH_STATUS_NOT_FOUND',
            'sent_today', 0,
            'daily_cap', 20
        );
    END IF;

    v_cap := COALESCE(v_rec.welcome_warmup_daily_cap, 20);

    -- Reset diário automático se mudou a data
    IF v_rec.welcome_warmup_date_reset < CURRENT_DATE THEN
        UPDATE public.whatsapp_health_status
        SET welcome_warmup_sent_today = 0,
            welcome_warmup_date_reset = CURRENT_DATE,
            last_check_at = now()
        WHERE id = p_instance_id;
        v_current_count := 0;
    ELSE
        v_current_count := COALESCE(v_rec.welcome_warmup_sent_today, 0);
    END IF;

    -- Avalia se ainda está dentro do teto específico
    IF v_current_count < v_cap THEN
        v_can_send := true;
        -- Incrementa o contador de boas-vindas enviadas hoje
        UPDATE public.whatsapp_health_status
        SET welcome_warmup_sent_today = welcome_warmup_sent_today + 1,
            last_check_at = now()
        WHERE id = p_instance_id;
        v_current_count := v_current_count + 1;
    ELSE
        v_can_send := false;
    END IF;

    RETURN jsonb_build_object(
        'can_send_welcome', v_can_send,
        'sent_today', v_current_count,
        'daily_cap', v_cap,
        'reason', CASE 
                    WHEN NOT v_can_send THEN 'WELCOME_WARMUP_CAP_EXCEEDED'
                    ELSE 'OK'
                  END
    );
END;
$$;

-- Permissões na RPC de cap de Welcome
REVOKE EXECUTE ON FUNCTION public.check_and_increment_welcome_warmup_cap(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_and_increment_welcome_warmup_cap(TEXT) TO authenticated, service_role;

-- 3. ATUALIZAÇÃO DA RPC CANÔNICA DE GOVERNANÇA (enqueue_whatsapp_transactional_message)
-- Permite que welcome-notify emita NOTICE para perfis de responsáveis do condomínio
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
    p_priority INTEGER DEFAULT NULL,
    p_expires_at TIMESTAMPTZ DEFAULT NULL
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
        'parcel-photo-delayed',
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
    IF p_caller_function IN ('whatsapp-parcel-notify', 'parcel-photo-delayed') AND p_message_type NOT IN ('PARCEL', 'PARCEL_DELIVERED') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: % não pode emitir %', p_caller_function, p_message_type;
    ELSIF p_caller_function IN ('convite-whatsapp-notify', 'visitor-register-whatsapp-notify') AND p_message_type NOT IN ('VISITOR_INVITE', 'VISITOR_AUTHORIZED') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: % não pode emitir %', p_caller_function, p_message_type;
    ELSIF p_caller_function = 'whatsapp-guest' AND p_message_type NOT IN ('VISITOR_AUTHORIZED', 'VISITOR_INVITE') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: whatsapp-guest não pode emitir %', p_message_type;
    ELSIF p_caller_function = 'password-reset-whatsapp' AND p_message_type NOT IN ('OTP') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: password-reset-whatsapp só pode emitir OTP';
    ELSIF p_caller_function = 'sos-push-notify' AND p_message_type NOT IN ('SOS') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: sos-push-notify só pode emitir SOS';
    ELSIF p_caller_function = 'welcome-notify' AND p_message_type NOT IN ('WELCOME', 'NOTICE') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: welcome-notify só pode emitir WELCOME ou NOTICE';
    ELSIF p_caller_function = 'approval-notify' AND p_message_type NOT IN ('WELCOME') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: approval-notify só pode emitir WELCOME';
    ELSIF p_caller_function = 'dual-number-routine' AND p_message_type NOT IN ('DUAL_NUMBER_NOTICE') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: dual-number-routine só pode emitir DUAL_NUMBER_NOTICE';
    END IF;

    -- ── 4. Normalização do nome da entidade ──────────────────────────────────
    v_normalized_entity := LOWER(TRIM(p_entity_type));

    -- ── 5. Derivação e Validação Física da Entidade de Negócio ───────────────
    CASE v_normalized_entity
        WHEN 'encomendas', 'encomenda' THEN
            SELECT condominio_id INTO v_derived_condo_id FROM public.encomendas WHERE id = p_entity_id;
            v_max_recipients := 5;

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
            ELSIF p_message_type = 'NOTICE' AND p_caller_function IN ('optin-whatsapp-cron', 'welcome-notify') THEN
                v_max_recipients := 6;
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
        expires_at,
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
        p_expires_at,
        now(),
        now()
    ) RETURNING id INTO v_outbox_id;

    RETURN v_outbox_id;
END;
$$;

-- Permissões estritas na RPC Canônica
REVOKE EXECUTE ON FUNCTION public.enqueue_whatsapp_transactional_message FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enqueue_whatsapp_transactional_message TO authenticated, service_role;
