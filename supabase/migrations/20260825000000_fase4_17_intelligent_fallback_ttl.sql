-- ==============================================================================
-- FASE 4.17 — MIGRATION: FAILOVER INTELIGENTE BOTCONVERSA -> META + TTL / EXPIRAÇÃO
-- Ambiente: EXCLUSIVO DEV (avypyaxthvgaybplnwxu)
-- Data: 2026-08-25
-- ==============================================================================

-- 1. ADICIONAR COLUNAS DE CONTROLE TEMPORAL E EXPIRAÇÃO NA TABELA whatsapp_outbox
ALTER TABLE public.whatsapp_outbox
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fallback_after TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS dispatched_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS expired_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS expiration_reason TEXT,
  ADD COLUMN IF NOT EXISTS fallback_reason TEXT,
  ADD COLUMN IF NOT EXISTS provider_attempt TEXT;

-- 2. CRIAR ÍNDICES OTIMIZADOS PARA SANEAMENTO DE TTL E RECONCILIAÇÃO DE GUARDA
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_ttl_reconcile 
  ON public.whatsapp_outbox (status, fallback_after, expires_at) 
  WHERE status IN ('pending', 'dispatched_bc', 'fallback_pending', 'sending', 'sending_meta');

CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_expires_at 
  ON public.whatsapp_outbox (expires_at) 
  WHERE status IN ('pending', 'dispatched_bc', 'fallback_pending');

-- 3. FUNÇÃO AUXILIAR DE DERIVAÇÃO DE TTL ABSOLUTO (EM SEGUNDOS)
CREATE OR REPLACE FUNCTION public.get_whatsapp_message_ttl(p_message_type TEXT)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE 
    WHEN p_message_type = 'SOS' THEN 30
    WHEN p_message_type = 'OTP' THEN 60
    WHEN p_message_type = 'VISITOR_AUTHORIZED' THEN 90
    WHEN p_message_type = 'VISITOR_INVITE' THEN 180
    WHEN p_message_type IN ('PARCEL', 'PARCEL_DELIVERED', 'RESERVATION') THEN 600
    WHEN p_message_type IN ('NOTICE', 'WELCOME') THEN 900
    WHEN p_message_type = 'FINANCIAL' THEN 1800
    WHEN p_message_type IN ('TEXTO_LIVRE', 'TEMPLATE_MANUAL', 'TEXTO_LIVRE_MANUAL') THEN 600
    WHEN p_message_type = 'RESPOSTA_MORADOR' THEN 60
    WHEN p_message_type = 'DUAL_NUMBER_NOTICE' THEN 900
    ELSE 600
  END;
$$;

-- 4. FUNÇÃO AUXILIAR DE DERIVAÇÃO DE JANELA DE GUARDA PARA FALLBACK (EM SEGUNDOS)
CREATE OR REPLACE FUNCTION public.get_whatsapp_fallback_window(p_message_type TEXT)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE 
    WHEN p_message_type = 'SOS' THEN 5
    WHEN p_message_type = 'OTP' THEN 10
    WHEN p_message_type = 'VISITOR_AUTHORIZED' THEN 15
    WHEN p_message_type = 'VISITOR_INVITE' THEN 20
    WHEN p_message_type IN ('PARCEL', 'PARCEL_DELIVERED', 'RESERVATION') THEN 30
    WHEN p_message_type IN ('NOTICE', 'WELCOME') THEN 45
    WHEN p_message_type = 'FINANCIAL' THEN 60
    WHEN p_message_type IN ('TEXTO_LIVRE', 'TEMPLATE_MANUAL', 'TEXTO_LIVRE_MANUAL') THEN 30
    WHEN p_message_type = 'RESPOSTA_MORADOR' THEN 15
    WHEN p_message_type = 'DUAL_NUMBER_NOTICE' THEN 0 -- Proibido fallback Meta
    ELSE 30
  END;
$$;

-- 5. ATUALIZAR A RPC CANÔNICA DE GOVERNANÇA OUTBOUND (enqueue_whatsapp_transactional_message)
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
    v_derived_condo_id TEXT;
    v_priority INTEGER;
    v_message_hash TEXT;
    v_entity_count INTEGER;
    v_max_recipients INTEGER;
    v_recent_quota INTEGER;
    v_normalized_entity TEXT;
    v_outbox_condo_type TEXT;
    v_expires_at TIMESTAMPTZ;
    v_ttl_seconds INTEGER;
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
        'whatsapp-outbox-worker',
        'smartSend'
    ) THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: caller_function não autorizado (%)', p_caller_function;
    END IF;

    -- ── 3. Validação do MessageType e Matriz Caller -> MessageType ───────────
    IF p_message_type NOT IN (
        'PARCEL', 'PARCEL_DELIVERED', 'VISITOR_INVITE', 'VISITOR_AUTHORIZED',
        'OTP', 'SOS', 'RESERVATION', 'NOTICE', 'WELCOME', 'FINANCIAL',
        'TEXTO_LIVRE', 'RESPOSTA_MORADOR', 'DUAL_NUMBER_NOTICE',
        'TEMPLATE_MANUAL', 'TEXTO_LIVRE_MANUAL'
    ) THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: message_type não homologado (%)', p_message_type;
    END IF;

    -- Validação da matriz estrita caller -> MessageType
    IF p_caller_function = 'whatsapp-parcel-notify' AND p_message_type NOT IN ('PARCEL', 'PARCEL_DELIVERED') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: whatsapp-parcel-notify não pode emitir %', p_message_type;
    ELSIF p_caller_function IN ('convite-whatsapp-notify', 'visitor-register-whatsapp-notify') AND p_message_type NOT IN ('VISITOR_INVITE', 'VISITOR_AUTHORIZED') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: % não pode emitir %', p_caller_function, p_message_type;
    ELSIF p_caller_function = 'whatsapp-guest' AND p_message_type NOT IN ('VISITOR_INVITE', 'VISITOR_AUTHORIZED') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: whatsapp-guest não pode emitir %', p_message_type;
    ELSIF p_caller_function = 'password-reset-whatsapp' AND p_message_type NOT IN ('OTP') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: password-reset-whatsapp só pode emitir OTP';
    ELSIF p_caller_function = 'sos-push-notify' AND p_message_type NOT IN ('SOS') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: sos-push-notify só pode emitir SOS';
    ELSIF p_caller_function IN ('welcome-notify', 'approval-notify') AND p_message_type NOT IN ('WELCOME', 'NOTICE') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: % só pode emitir WELCOME/NOTICE', p_caller_function;
    ELSIF p_caller_function = 'dual-number-routine' AND p_message_type NOT IN ('DUAL_NUMBER_NOTICE') THEN
        RAISE EXCEPTION 'GOVERNANCE_BLOCKED: dual-number-routine só pode emitir DUAL_NUMBER_NOTICE';
    END IF;

    -- ── 4. Normalização do nome da entidade ──────────────────────────────────
    v_normalized_entity := LOWER(TRIM(COALESCE(p_entity_type, 'perfil')));

    -- ── 5. Derivação e Validação Física da Entidade (Suporte a Prod e DEV) ────
    CASE v_normalized_entity
        WHEN 'encomendas', 'encomenda' THEN
            IF p_entity_id IS NOT NULL THEN
                IF p_entity_id ~ '^[0-9]+$' THEN
                    EXECUTE 'SELECT condominio_id::text FROM public.encomendas WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                ELSE
                    EXECUTE 'SELECT condominio_id::text FROM public.encomendas WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            END IF;
            v_derived_condo_id := COALESCE(v_derived_condo_id, p_condominio_id);
            v_max_recipients := 5;

        WHEN 'convites', 'convite', 'visitantes', 'visitante', 'tb_autorizacao_visitante', 'autorizacoes_visitantes' THEN
            IF p_entity_id IS NOT NULL THEN
                IF p_entity_id ~ '^[0-9]+$' THEN
                    EXECUTE 'SELECT condominio_id::text FROM public.convites WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                ELSE
                    EXECUTE 'SELECT condominio_id::text FROM public.convites WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            END IF;
            v_derived_condo_id := COALESCE(v_derived_condo_id, p_condominio_id);
            v_max_recipients := 5;

        WHEN 'perfil', 'perfis', 'usuarios', 'usuario' THEN
            IF p_entity_id IS NOT NULL THEN
                EXECUTE 'SELECT condominio_id::text FROM public.perfil WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
            END IF;
            v_derived_condo_id := COALESCE(v_derived_condo_id, p_condominio_id);
            v_max_recipients := 5;

        WHEN 'reservas', 'reserva', 'tb_reservas' THEN
            IF p_entity_id IS NOT NULL THEN
                IF to_regclass('public.reservas') IS NOT NULL THEN
                    IF p_entity_id ~ '^[0-9]+$' THEN
                        EXECUTE 'SELECT condominio_id::text FROM public.reservas WHERE id = $1::bigint' USING p_entity_id INTO v_derived_condo_id;
                    ELSE
                        EXECUTE 'SELECT condominio_id::text FROM public.reservas WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                    END IF;
                ELSIF to_regclass('public.tb_reservas') IS NOT NULL THEN
                    EXECUTE 'SELECT condominio_id::text FROM public.tb_reservas WHERE id = $1::uuid' USING p_entity_id INTO v_derived_condo_id;
                END IF;
            END IF;
            v_derived_condo_id := COALESCE(v_derived_condo_id, p_condominio_id);
            v_max_recipients := 5;

        WHEN 'auth_users', 'auth_user' THEN
            v_derived_condo_id := p_condominio_id;
            v_max_recipients := 3;

        WHEN 'manual_admin' THEN
            v_derived_condo_id := p_condominio_id;
            v_max_recipients := 5;

        WHEN 'dual_number_notices', 'dual_number_notice' THEN
            v_derived_condo_id := p_condominio_id;
            v_max_recipients := 1;

        ELSE
            v_derived_condo_id := p_condominio_id;
            v_max_recipients := 5;
    END CASE;

    -- ── 6. Multi-Tenancy Guard ───────────────────────────────────────────────
    IF v_normalized_entity NOT IN ('auth_users', 'auth_user', 'manual_admin', 'dual_number_notices', 'dual_number_notice') THEN
        IF v_derived_condo_id IS NULL AND p_condominio_id IS NOT NULL THEN
            v_derived_condo_id := p_condominio_id;
        END IF;
    END IF;

    -- ── 7. Advisory Lock Transacional por Entidade (Anti-Race Condition) ─────
    PERFORM pg_advisory_xact_lock(hashtext(v_normalized_entity || ':' || COALESCE(p_entity_id, v_canonical_phone)));

    -- ── 8. Derivação de Prioridade de Fila ───────────────────────────────────
    IF p_priority IS NOT NULL THEN
        v_priority := p_priority;
    ELSE
        CASE p_message_type
            WHEN 'SOS', 'OTP' THEN v_priority := 1;
            WHEN 'VISITOR_INVITE', 'VISITOR_AUTHORIZED' THEN v_priority := 2;
            WHEN 'PARCEL', 'PARCEL_DELIVERED', 'RESERVATION', 'TEXTO_LIVRE', 'RESPOSTA_MORADOR', 'TEMPLATE_MANUAL', 'TEXTO_LIVRE_MANUAL' THEN v_priority := 10;
            WHEN 'NOTICE', 'WELCOME' THEN v_priority := 15;
            WHEN 'FINANCIAL' THEN v_priority := 20;
            WHEN 'DUAL_NUMBER_NOTICE' THEN v_priority := 25;
            ELSE v_priority := 15;
        END CASE;
    END IF;

    -- ── 9. Cálculo do Deadline Absoluto (expires_at) ─────────────────────────
    IF p_expires_at IS NOT NULL THEN
        v_expires_at := p_expires_at;
    ELSE
        v_ttl_seconds := public.get_whatsapp_message_ttl(p_message_type);
        v_expires_at := now() + (v_ttl_seconds || ' seconds')::interval;
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
            status, next_attempt_at, expires_at, created_at, updated_at
        ) VALUES (
            $1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, ''pending'', $13, $14, now(), now()
        ) RETURNING id'
        USING 
            v_derived_condo_id, v_canonical_phone, p_payload_type, p_message_type,
            p_message_content, v_priority, v_message_hash, p_caller_function,
            v_normalized_entity, p_entity_id, p_perfil_id,
            COALESCE(p_transaction_id, gen_random_uuid()), COALESCE(p_scheduled_for, now()),
            v_expires_at
        INTO v_outbox_id;
    ELSE
        EXECUTE 'INSERT INTO public.whatsapp_outbox (
            condominio_id, recipient_phone, payload_type, message_type,
            message_content, priority, message_hash, caller_function,
            entity_type, entity_id, perfil_id, transaction_id,
            status, next_attempt_at, expires_at, created_at, updated_at
        ) VALUES (
            $1::bigint, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, ''pending'', $13, $14, now(), now()
        ) RETURNING id'
        USING 
            v_derived_condo_id, v_canonical_phone, p_payload_type, p_message_type,
            p_message_content, v_priority, v_message_hash, p_caller_function,
            v_normalized_entity, p_entity_id, p_perfil_id,
            COALESCE(p_transaction_id, gen_random_uuid()), COALESCE(p_scheduled_for, now()),
            v_expires_at
        INTO v_outbox_id;
    END IF;

    RETURN v_outbox_id;
END;
$$;

-- 6. ATUALIZAR A RPC CANÔNICA DE CLAIM (claim_single_whatsapp_message) COM SUPORTE A RECONCILIAÇÃO E TTL
CREATE OR REPLACE FUNCTION public.claim_single_whatsapp_message(
    p_min_priority INT,
    p_max_priority INT
)
RETURNS SETOF public.whatsapp_outbox AS $$
DECLARE
  v_rec public.whatsapp_outbox;
BEGIN
  -- Obtain a short-lived transaction-level advisory lock to serialize workers
  PERFORM pg_advisory_xact_lock(998878);

  -- 1. Saneamento Atômico de Linhas com TTL Expirado (Anti-Backlog)
  UPDATE public.whatsapp_outbox
  SET status = 'expired',
      expired_at = now(),
      expiration_reason = 'TTL_EXCEEDED_IN_QUEUE',
      updated_at = now()
  WHERE status IN ('pending', 'dispatched_bc', 'fallback_pending')
    AND expires_at IS NOT NULL
    AND expires_at <= now();

  -- 2. Claim Atômico do Próximo Registro Elegível:
  --    a) Mensagem 'pending' cujo next_attempt_at chegou e expires_at > now()
  --    b) Mensagem 'dispatched_bc' cuja janela de guarda fallback_after estourou e expires_at > now()
  --    c) Mensagem 'fallback_pending' pronta para envio Meta e expires_at > now()
  RETURN QUERY
  UPDATE public.whatsapp_outbox
  SET status = CASE 
                 WHEN status = 'dispatched_bc' THEN 'sending_meta'
                 WHEN status = 'fallback_pending' THEN 'sending_meta'
                 ELSE 'sending'
               END,
      processing_started_at = now(),
      updated_at = now()
  WHERE id = (
      SELECT id 
      FROM public.whatsapp_outbox
      WHERE (
          -- Eligible pending message
          (status = 'pending' AND next_attempt_at <= now())
          OR
          -- Eligible dispatched_bc message awaiting Meta failover
          (status = 'dispatched_bc' AND fallback_after IS NOT NULL AND fallback_after <= now())
          OR
          -- Eligible explicit fallback_pending
          (status = 'fallback_pending' AND next_attempt_at <= now())
        )
        AND priority >= p_min_priority
        AND priority <= p_max_priority
        AND (expires_at IS NULL OR expires_at > now())
      ORDER BY priority ASC, created_at ASC
      LIMIT 1
      FOR UPDATE SKIP LOCKED
  )
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Overload para compatibilidade retroativa [1, 99]
CREATE OR REPLACE FUNCTION public.claim_single_whatsapp_message()
RETURNS SETOF public.whatsapp_outbox AS $$
BEGIN
  RETURN QUERY SELECT * FROM public.claim_single_whatsapp_message(1, 99);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. FUNÇÃO DE LIMPEZA EM LOTE DE MENSAGENS EXPIRADAS (HOUSEKEEPING)
CREATE OR REPLACE FUNCTION public.purge_expired_whatsapp_messages(p_limit INT DEFAULT 100)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  WITH expired_rows AS (
    SELECT id 
    FROM public.whatsapp_outbox
    WHERE status IN ('pending', 'dispatched_bc', 'fallback_pending')
      AND expires_at IS NOT NULL
      AND expires_at <= now()
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.whatsapp_outbox o
  SET status = 'expired',
      expired_at = now(),
      expiration_reason = 'TTL_EXCEEDED_HOUSEKEEPING_PURGE',
      updated_at = now()
  FROM expired_rows r
  WHERE o.id = r.id;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
