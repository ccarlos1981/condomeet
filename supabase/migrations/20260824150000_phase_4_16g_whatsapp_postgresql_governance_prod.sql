-- ==============================================================================
-- Migration: 20260824150000_phase_4_16g_whatsapp_postgresql_governance_prod.sql
-- Description: FASE 4.16G-P — Implementação Adaptada da Proteção PostgreSQL
--              da Mensageria WhatsApp para o Schema Real de PRODUÇÃO
--              (Compatibilidade com BIGINT/UUID, Nomenclatura Real de Produção,
--              RPC Canônica Outbound, RPC Canônica Inbound, Anti-Broadcast e Hardening).
-- ==============================================================================

-- 1. ADICIONAR / AJUSTAR COLUNAS DE GOVERNANÇA À TABELA WHATSAPP_OUTBOX
-- entity_id tipado como TEXT para suportar polimorficamente PKs BIGINT e UUID
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'whatsapp_outbox' AND column_name = 'entity_type'
  ) THEN
    ALTER TABLE public.whatsapp_outbox ADD COLUMN entity_type TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'whatsapp_outbox' AND column_name = 'entity_id'
  ) THEN
    ALTER TABLE public.whatsapp_outbox ADD COLUMN entity_id TEXT;
  ELSE
    ALTER TABLE public.whatsapp_outbox ALTER COLUMN entity_id TYPE TEXT USING entity_id::text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'caller_function' AND column_name = 'caller_function'
  ) THEN
    ALTER TABLE public.whatsapp_outbox ADD COLUMN IF NOT EXISTS caller_function TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'whatsapp_outbox' AND column_name = 'transaction_id'
  ) THEN
    ALTER TABLE public.whatsapp_outbox ADD COLUMN transaction_id UUID DEFAULT gen_random_uuid();
  END IF;
END $$;

-- 2. ÍNDICES DE PERFORMANCE, CARDINALIDADE E IDEMPOTÊNCIA
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_cardinality_eval
  ON public.whatsapp_outbox (entity_type, entity_id, message_type);

CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_quota_eval
  ON public.whatsapp_outbox (condominio_id, entity_type, created_at);

CREATE UNIQUE INDEX IF NOT EXISTS idx_whatsapp_outbox_tx_phone
  ON public.whatsapp_outbox (transaction_id, recipient_phone)
  WHERE transaction_id IS NOT NULL;

-- 3. LIMPAR ASSINATURAS ANTERIORES PARA EVITAR AMBIGUIDADE
DROP FUNCTION IF EXISTS public.enqueue_whatsapp_transactional_message(
    TEXT, TEXT, TEXT, JSONB, TEXT, TEXT, UUID, UUID, UUID, UUID, TIMESTAMPTZ, INTEGER
);
DROP FUNCTION IF EXISTS public.enqueue_whatsapp_transactional_message(
    TEXT, TEXT, TEXT, JSONB, TEXT, TEXT, TEXT, BIGINT, UUID, UUID, TIMESTAMPTZ, INTEGER
);
DROP FUNCTION IF EXISTS public.enqueue_whatsapp_transactional_message(
    TEXT, TEXT, TEXT, JSONB, TEXT, TEXT, TEXT, TEXT, UUID, UUID, TIMESTAMPTZ, INTEGER
);
DROP FUNCTION IF EXISTS public.record_whatsapp_incoming_message(
    TEXT, TEXT, TEXT, UUID, TEXT
);
DROP FUNCTION IF EXISTS public.record_whatsapp_incoming_message(
    TEXT, TEXT, TEXT, UUID, BIGINT
);

-- 4. CRIAR A RPC CANÔNICA DE GOVERNANÇA OUTBOUND
CREATE OR REPLACE FUNCTION public.enqueue_whatsapp_transactional_message(
    p_recipient_phone TEXT,
    p_payload_type TEXT,
    p_message_type TEXT,
    p_message_content JSONB,
    p_caller_function TEXT,
    p_entity_type TEXT,
    p_entity_id TEXT DEFAULT NULL,
    p_condominio_id TEXT DEFAULT NULL,
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
    v_derived_condo_id TEXT;
    v_priority INTEGER;
    v_message_hash TEXT;
    v_entity_count INTEGER;
    v_max_recipients INTEGER;
    v_recent_quota INTEGER;
    v_normalized_entity TEXT;
    v_outbox_condo_type TEXT;
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

    -- ── 5. Derivação e Validação Física da Entidade (Suporte a Prod e DEV) ────
    CASE v_normalized_entity
        -- Encomendas
        WHEN 'encomendas', 'encomenda' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de encomenda obrigatório';
            END IF;
            IF p_entity_id ~ '^[0-9]+$' THEN
                EXECUTE 'SELECT condominio_id::text FROM public.encomendas WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
            ELSE
                EXECUTE 'SELECT condominio_id::text FROM public.encomendas WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
            END IF;
            v_max_recipients := 5;

        -- Convites de Visitantes
        WHEN 'convites', 'convite' THEN
            IF p_entity_id IS NULL OR NOT (p_entity_id ~ '^[0-9a-fA-F-]{36}$') THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de convite inválido (esperado UUID): %', p_entity_id;
            END IF;
            SELECT condominio_id::text INTO v_derived_condo_id FROM public.convites WHERE id = p_entity_id::uuid;
            v_max_recipients := 3;

        -- Autorizações de Acesso / Visitantes na Portaria
        WHEN 'visitante_registros', 'visitante_registro', 'tb_autorizacao_acesso' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de autorização de acesso obrigatório';
            END IF;
            IF to_regclass('public.tb_autorizacao_acesso') IS NOT NULL THEN
                EXECUTE 'SELECT condominio_id::text FROM public.tb_autorizacao_acesso WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
            ELSIF to_regclass('public.visitante_registros') IS NOT NULL THEN
                IF p_entity_id ~ '^[0-9]+$' THEN
                    EXECUTE 'SELECT condominio_id::text FROM public.visitante_registros WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                ELSE
                    EXECUTE 'SELECT condominio_id::text FROM public.visitante_registros WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            END IF;
            v_max_recipients := 5;

        -- Alertas SOS de Emergência
        WHEN 'sos', 'sos_alerts', 'sos_alertas', 'sos_alerta' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de SOS obrigatório';
            END IF;
            IF to_regclass('public.sos') IS NOT NULL THEN
                EXECUTE 'SELECT condominio_id::text FROM public.sos WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
            ELSIF to_regclass('public.sos_alertas') IS NOT NULL THEN
                IF p_entity_id ~ '^[0-9]+$' THEN
                    EXECUTE 'SELECT condominio_id::text FROM public.sos_alertas WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                ELSE
                    EXECUTE 'SELECT condominio_id::text FROM public.sos_alertas WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            END IF;
            v_max_recipients := 10;

        -- Reservas de Áreas Comuns
        WHEN 'reservas', 'reserva', 'area_comum_evento' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de reserva obrigatório';
            END IF;
            IF to_regclass('public.area_comum_evento') IS NOT NULL THEN
                EXECUTE 'SELECT condominio_id::text FROM public.area_comum_evento WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
            ELSIF to_regclass('public.reservas') IS NOT NULL THEN
                IF p_entity_id ~ '^[0-9]+$' THEN
                    EXECUTE 'SELECT condominio_id::text FROM public.reservas WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                ELSE
                    EXECUTE 'SELECT condominio_id::text FROM public.reservas WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            END IF;
            v_max_recipients := 6;

        -- Classificados
        WHEN 'classificados', 'classificado' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de anúncio obrigatório';
            END IF;
            IF p_entity_id ~ '^[0-9]+$' THEN
                EXECUTE 'SELECT condominio_id::text FROM public.classificados WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
            ELSE
                EXECUTE 'SELECT condominio_id::text FROM public.classificados WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
            END IF;
            v_max_recipients := 6;

        -- Livro de Ocorrências
        WHEN 'ocorrencias', 'ocorrencia', 'livro_de_ocorrencia' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de ocorrência obrigatório';
            END IF;
            IF to_regclass('public.livro_de_ocorrencia') IS NOT NULL THEN
                EXECUTE 'SELECT condominio_id::text FROM public.livro_de_ocorrencia WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
            ELSIF to_regclass('public.ocorrencias') IS NOT NULL THEN
                IF p_entity_id ~ '^[0-9]+$' THEN
                    EXECUTE 'SELECT condominio_id::text FROM public.ocorrencias WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                ELSE
                    EXECUTE 'SELECT condominio_id::text FROM public.ocorrencias WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            END IF;
            v_max_recipients := 6;

        -- Fale com o Síndico
        WHEN 'fale_sindico_threads', 'fale_sindico', 'fale_conosco' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de Fale Conosco obrigatório';
            END IF;
            IF to_regclass('public.fale_conosco') IS NOT NULL THEN
                EXECUTE 'SELECT condominio_id::text FROM public.fale_conosco WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
            ELSIF to_regclass('public.fale_sindico_threads') IS NOT NULL THEN
                IF p_entity_id ~ '^[0-9]+$' THEN
                    EXECUTE 'SELECT condominio_id::text FROM public.fale_sindico_threads WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                ELSE
                    EXECUTE 'SELECT condominio_id::text FROM public.fale_sindico_threads WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            END IF;
            v_max_recipients := 6;

        -- Documentos Condominiais
        WHEN 'documentos', 'documento' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de documento obrigatório';
            END IF;
            IF p_entity_id ~ '^[0-9]+$' THEN
                EXECUTE 'SELECT condominio_id::text FROM public.documentos WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
            ELSE
                EXECUTE 'SELECT condominio_id::text FROM public.documentos WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
            END IF;
            v_max_recipients := 4;

        -- Contratos
        WHEN 'contratos', 'contrato' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de contrato obrigatório';
            END IF;
            IF to_regclass('public.contrato') IS NOT NULL THEN
                EXECUTE 'SELECT condominio_id::text FROM public.contrato WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
            ELSIF to_regclass('public.contratos') IS NOT NULL THEN
                IF p_entity_id ~ '^[0-9]+$' THEN
                    EXECUTE 'SELECT condominio_id::text FROM public.contratos WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                ELSE
                    EXECUTE 'SELECT condominio_id::text FROM public.contratos WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            END IF;
            v_max_recipients := 4;

        -- Indicações de Serviços
        WHEN 'indicacoes_servico', 'indicacao', 'ind_servico_morador' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de indicação obrigatório';
            END IF;
            IF to_regclass('public.ind_servico_morador') IS NOT NULL THEN
                EXECUTE 'SELECT condominio_id::text FROM public.ind_servico_morador WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
            ELSIF to_regclass('public.indicacoes_servico') IS NOT NULL THEN
                IF p_entity_id ~ '^[0-9]+$' THEN
                    EXECUTE 'SELECT condominio_id::text FROM public.indicacoes_servico WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                ELSE
                    EXECUTE 'SELECT condominio_id::text FROM public.indicacoes_servico WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            END IF;
            v_max_recipients := 2;

        -- Garagens / Vagas (Suporte a DEV e Produção)
        WHEN 'garage_reservations', 'garagem' THEN
            IF p_entity_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de reserva de garagem obrigatório';
            END IF;
            IF to_regclass('public.garage_reservations') IS NOT NULL AND to_regclass('public.garages') IS NOT NULL THEN
                IF p_entity_id ~ '^[0-9]+$' THEN
                    EXECUTE 'SELECT g.condominio_id::text FROM public.garage_reservations gr JOIN public.garages g ON g.id = gr.garage_id WHERE gr.id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                ELSE
                    EXECUTE 'SELECT g.condominio_id::text FROM public.garage_reservations gr JOIN public.garages g ON g.id = gr.garage_id WHERE gr.id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            ELSE
                v_derived_condo_id := p_condominio_id;
            END IF;
            v_max_recipients := 4;

        -- Perfil de Morador
        WHEN 'perfil' THEN
            IF p_entity_id IS NULL OR NOT (p_entity_id ~ '^[0-9a-fA-F-]{36}$') THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: ID de perfil inválido (esperado UUID): %', p_entity_id;
            END IF;
            SELECT condominio_id::text INTO v_derived_condo_id FROM public.perfil WHERE id = p_entity_id::uuid;

            IF p_message_type = 'WELCOME' THEN
                v_max_recipients := 6;
            ELSIF p_message_type = 'NOTICE' AND p_caller_function = 'optin-whatsapp-cron' THEN
                v_max_recipients := 2;
            ELSIF p_message_type IN ('TEXTO_LIVRE', 'RESPOSTA_MORADOR') AND p_caller_function = 'whatsapp-chatbot' THEN
                v_max_recipients := 10;
            ELSE
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Combinação não homologada de MessageType % com entidade perfil', p_message_type;
            END IF;

        -- Autenticação OTP (auth.users / Identidade Canônica E.164)
        WHEN 'auth_users', 'auth_user' THEN
            IF p_message_type <> 'OTP' THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: auth_users só pode emitir OTP';
            END IF;
            -- Quota de OTP: Máximo 5 solicitações por telefone a cada 60 minutos
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

        -- Mensagem Manual Administrativa Pontual (Síndico / Admin)
        WHEN 'manual_admin' THEN
            IF p_condominio_id IS NULL THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: condominio_id obrigatório para manual_admin';
            END IF;
            -- Quota horária de manual_admin: Máximo 15 por condomínio a cada 60 minutos
            SELECT data_type INTO v_outbox_condo_type 
            FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'whatsapp_outbox' AND column_name = 'condominio_id';

            IF v_outbox_condo_type = 'uuid' THEN
                EXECUTE 'SELECT COUNT(*) FROM public.whatsapp_outbox WHERE entity_type = ''manual_admin'' AND condominio_id = $1::uuid AND created_at > (now() - INTERVAL ''1 hour'')' USING p_condominio_id INTO v_recent_quota;
            ELSE
                EXECUTE 'SELECT COUNT(*) FROM public.whatsapp_outbox WHERE entity_type = ''manual_admin'' AND condominio_id = $1::bigint AND created_at > (now() - INTERVAL ''1 hour'')' USING p_condominio_id INTO v_recent_quota;
            END IF;

            IF v_recent_quota >= 15 THEN
                RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Quota horária de mensagens manuais excedida para este condomínio (máx 15/hora). Use Push FCM.';
            END IF;
            v_derived_condo_id := p_condominio_id;
            v_max_recipients := 5;

        -- Aviso Oficial de 2 Números
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
    PERFORM pg_advisory_xact_lock(hashtext(v_normalized_entity || ':' || COALESCE(p_entity_id, v_canonical_phone)));

    -- ── 8. Validação de Cardinalidade Atômica ────────────────────────────────
    IF v_normalized_entity NOT IN ('auth_users', 'auth_user', 'manual_admin', 'dual_number_notices', 'dual_number_notice') THEN
        SELECT COUNT(*) INTO v_entity_count
        FROM public.whatsapp_outbox
        WHERE entity_type = v_normalized_entity
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
    v_message_hash := encode(sha256((v_canonical_phone || ':' || p_payload_type || ':' || COALESCE(p_message_content->>'value', p_message_content::text) || ':' || COALESCE(v_derived_condo_id, '0'))::bytea), 'hex');

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

    -- ── 12. Inserção Segura e Polimórfica na Tabela whatsapp_outbox ──────────
    SELECT data_type INTO v_outbox_condo_type 
    FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'whatsapp_outbox' AND column_name = 'condominio_id';

    IF v_outbox_condo_type = 'uuid' THEN
        EXECUTE 'INSERT INTO public.whatsapp_outbox (
            condominio_id, recipient_phone, payload_type, message_type,
            message_content, priority, message_hash, caller_function,
            entity_type, entity_id, perfil_id, transaction_id,
            status, next_attempt_at, created_at, updated_at
        ) VALUES (
            $1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, ''pending'', $13, now(), now()
        ) RETURNING id'
        USING 
            v_derived_condo_id, v_canonical_phone, p_payload_type, p_message_type,
            p_message_content, v_priority, v_message_hash, p_caller_function,
            v_normalized_entity, p_entity_id, p_perfil_id,
            COALESCE(p_transaction_id, gen_random_uuid()), COALESCE(p_scheduled_for, now())
        INTO v_outbox_id;
    ELSE
        EXECUTE 'INSERT INTO public.whatsapp_outbox (
            condominio_id, recipient_phone, payload_type, message_type,
            message_content, priority, message_hash, caller_function,
            entity_type, entity_id, perfil_id, transaction_id,
            status, next_attempt_at, created_at, updated_at
        ) VALUES (
            $1::bigint, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, ''pending'', $13, now(), now()
        ) RETURNING id'
        USING 
            v_derived_condo_id, v_canonical_phone, p_payload_type, p_message_type,
            p_message_content, v_priority, v_message_hash, p_caller_function,
            v_normalized_entity, p_entity_id, p_perfil_id,
            COALESCE(p_transaction_id, gen_random_uuid()), COALESCE(p_scheduled_for, now())
        INTO v_outbox_id;
    END IF;

    RETURN v_outbox_id;
END;
$$;

-- 5. CRIAR A RPC CANÔNICA DE GRAVAÇÃO DE MENSAGEM INBOUND
CREATE OR REPLACE FUNCTION public.record_whatsapp_incoming_message(
    p_recipient_phone TEXT,
    p_message_text TEXT,
    p_first_name TEXT DEFAULT 'Morador',
    p_perfil_id UUID DEFAULT NULL,
    p_condominio_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_id UUID;
    v_canonical_phone TEXT;
    v_derived_condo_id TEXT;
    v_outbox_condo_type TEXT;
    v_message_content JSONB;
BEGIN
    -- ── 1. Normalização rigorosa do Telefone Canônico E.164 ──────────────────
    v_canonical_phone := regexp_replace(COALESCE(p_recipient_phone, ''), '\D', '', 'g');
    IF NOT (v_canonical_phone LIKE '55%') THEN
        v_canonical_phone := '55' || v_canonical_phone;
    END IF;
    IF length(v_canonical_phone) < 12 OR length(v_canonical_phone) > 13 THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Telefone inválido (%)', p_recipient_phone;
    END IF;

    -- ── 2. Derivação / validação segura de condomínio via perfil ─────────────
    IF p_perfil_id IS NOT NULL THEN
        SELECT condominio_id::text INTO v_derived_condo_id 
        FROM public.perfil 
        WHERE id = p_perfil_id;
        
        IF v_derived_condo_id IS NULL THEN
            v_derived_condo_id := p_condominio_id;
        ELSIF p_condominio_id IS NOT NULL AND p_condominio_id <> v_derived_condo_id THEN
            RAISE EXCEPTION 'GOVERNANCE_BLOCKED: Violação de multi-tenancy. Perfil % pertence ao condomínio %, não %', p_perfil_id, v_derived_condo_id, p_condominio_id;
        END IF;
    ELSE
        v_derived_condo_id := p_condominio_id;
    END IF;

    -- ── 3. Montar payload estruturado fixo ───────────────────────────────────
    v_message_content := jsonb_build_object(
        'value', COALESCE(p_message_text, ''),
        'firstName', COALESCE(p_first_name, 'Morador')
    );

    -- ── 4. Inserção polimórfica estrita: status='received', message_type='RESPOSTA_MORADOR'
    SELECT data_type INTO v_outbox_condo_type 
    FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'whatsapp_outbox' AND column_name = 'condominio_id';

    IF v_outbox_condo_type = 'uuid' THEN
        EXECUTE 'INSERT INTO public.whatsapp_outbox (
            condominio_id, recipient_phone, payload_type, message_type,
            message_content, status, perfil_id, sent_at, created_at, updated_at,
            message_hash
        ) VALUES (
            $1::uuid, $2, ''text'', ''RESPOSTA_MORADOR'',
            $3, ''received'', $4, now(), now(), now(),
            ''received_'' || $2 || ''_'' || extract(epoch from now())::text || ''_'' || substr(md5(random()::text), 1, 6)
        ) RETURNING id'
        USING v_derived_condo_id, v_canonical_phone, v_message_content, p_perfil_id
        INTO v_id;
    ELSE
        EXECUTE 'INSERT INTO public.whatsapp_outbox (
            condominio_id, recipient_phone, payload_type, message_type,
            message_content, status, perfil_id, sent_at, created_at, updated_at,
            message_hash
        ) VALUES (
            $1::bigint, $2, ''text'', ''RESPOSTA_MORADOR'',
            $3, ''received'', $4, now(), now(), now(),
            ''received_'' || $2 || ''_'' || extract(epoch from now())::text || ''_'' || substr(md5(random()::text), 1, 6)
        ) RETURNING id'
        USING v_derived_condo_id, v_canonical_phone, v_message_content, p_perfil_id
        INTO v_id;
    END IF;

    RETURN v_id;
END;
$$;

-- 6. MATRIZ DE PERMISSÕES E HARDENING DE SEGURANÇA
REVOKE INSERT, DELETE, TRUNCATE ON public.whatsapp_outbox FROM anon, authenticated, service_role;
GRANT SELECT, UPDATE ON public.whatsapp_outbox TO service_role;

REVOKE EXECUTE ON FUNCTION public.enqueue_whatsapp_transactional_message(
    TEXT, TEXT, TEXT, JSONB, TEXT, TEXT, TEXT, TEXT, UUID, UUID, TIMESTAMPTZ, INTEGER
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enqueue_whatsapp_transactional_message(
    TEXT, TEXT, TEXT, JSONB, TEXT, TEXT, TEXT, TEXT, UUID, UUID, TIMESTAMPTZ, INTEGER
) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.record_whatsapp_incoming_message(
    TEXT, TEXT, TEXT, UUID, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_whatsapp_incoming_message(
    TEXT, TEXT, TEXT, UUID, TEXT
) TO authenticated, service_role;
