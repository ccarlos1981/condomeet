-- Migration: 20260824120000_create_whatsapp_dual_number_notices.sql
-- Description: Criação da tabela de controle e RPC atômica idempotente para DUAL_NUMBER_NOTICE

-- 1. Criação da Tabela de Controle
CREATE TABLE IF NOT EXISTS public.whatsapp_dual_number_notices (
    recipient_phone TEXT PRIMARY KEY,
    perfil_id UUID,
    condominio_id BIGINT,
    trigger_outbox_id UUID REFERENCES public.whatsapp_outbox(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'enqueued' CHECK (status IN ('enqueued', 'sent', 'confirmed')),
    enqueued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    response_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Habilitação de RLS e Políticas de Segurança
ALTER TABLE public.whatsapp_dual_number_notices ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.whatsapp_dual_number_notices FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.whatsapp_dual_number_notices TO service_role, postgres;

-- 3. Índices de Performance e Consulta
CREATE INDEX IF NOT EXISTS idx_whatsapp_dual_number_notices_status 
ON public.whatsapp_dual_number_notices (status);

CREATE INDEX IF NOT EXISTS idx_whatsapp_dual_number_notices_condo 
ON public.whatsapp_dual_number_notices (condominio_id);

-- 4. RPC Segura e Atômica para Enfileiramento
CREATE OR REPLACE FUNCTION public.enqueue_dual_number_notice_if_needed(
    p_recipient_phone TEXT,
    p_perfil_id UUID DEFAULT NULL,
    p_condominio_id BIGINT DEFAULT NULL,
    p_trigger_outbox_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_phone_clean TEXT;
    v_canonical_phone TEXT;
    v_inserted BOOLEAN := false;
    v_outbox_id UUID;
    v_message_text TEXT;
    v_hash TEXT;
BEGIN
    -- 1. Normalização rigorosa do telefone
    v_phone_clean := regexp_replace(COALESCE(p_recipient_phone, ''), '\D', '', 'g');
    IF length(v_phone_clean) < 10 THEN
        RETURN jsonb_build_object('enqueued', false, 'reason', 'INVALID_PHONE');
    END IF;

    IF NOT (v_phone_clean LIKE '55%') THEN
        v_canonical_phone := '55' || v_phone_clean;
    ELSE
        v_canonical_phone := v_phone_clean;
    END IF;

    -- 2. Inserção Atômica Idempotente na tabela de controle
    INSERT INTO public.whatsapp_dual_number_notices (
        recipient_phone,
        perfil_id,
        condominio_id,
        trigger_outbox_id,
        status,
        enqueued_at,
        created_at,
        updated_at
    )
    VALUES (
        v_canonical_phone,
        p_perfil_id,
        p_condominio_id,
        p_trigger_outbox_id,
        'enqueued',
        now(),
        now(),
        now()
    )
    ON CONFLICT (recipient_phone) DO NOTHING
    RETURNING true INTO v_inserted;

    -- Se já existia registro (conflito), encerra imediatamente sem duplicar
    IF NOT COALESCE(v_inserted, false) THEN
        RETURN jsonb_build_object(
            'enqueued', false,
            'reason', 'ALREADY_EXISTS_OR_PREVIOUSLY_ENQUEUED',
            'recipient_phone', v_canonical_phone
        );
    END IF;

    -- 3. Texto homologado da mensagem
    v_message_text := '📱 *Aviso importante do Condomeet*' || E'\n\n' ||
                      'O Condomeet utiliza dois números de WhatsApp para enviar as notificações do seu condomínio.' || E'\n\n' ||
                      'Para garantir que você receba todas as nossas comunicações, recomendamos cadastrar os dois números nos seus contatos.' || E'\n\n' ||
                      '*Números oficiais de notificações:*' || E'\n\n' ||
                      '+55 62 9918-8555' || E'\n' ||
                      '+55 61 98251-6083' || E'\n\n' ||
                      'Tudo bem para você?' || E'\n\n' ||
                      'Responda *OK* para confirmar.';

    -- 4. Cálculo determinístico do Hash
    v_hash := encode(sha256((v_canonical_phone || 'text' || v_message_text || COALESCE(p_condominio_id::text, '0'))::bytea), 'hex');

    -- 5. Enfileiramento na whatsapp_outbox com delay de 2 minutos e prioridade 25 (queue=low)
    INSERT INTO public.whatsapp_outbox (
        recipient_phone,
        condominio_id,
        perfil_id,
        priority,
        message_type,
        payload_type,
        operational_type,
        message_content,
        message_hash,
        status,
        retry_count,
        max_retries,
        next_attempt_at,
        created_at,
        updated_at
    )
    VALUES (
        v_canonical_phone,
        p_condominio_id,
        p_perfil_id,
        25,
        'DUAL_NUMBER_NOTICE',
        'text',
        'transactional',
        jsonb_build_object(
            'value', v_message_text,
            'allow_meta_fallback', false
        ),
        v_hash,
        'pending',
        0,
        3,
        now() + INTERVAL '2 minutes',
        now(),
        now()
    )
    RETURNING id INTO v_outbox_id;

    RETURN jsonb_build_object(
        'enqueued', true,
        'outbox_id', v_outbox_id,
        'recipient_phone', v_canonical_phone,
        'delay_sec', 120
    );
END;
$$;

-- 5. Permissões Estritas na RPC
REVOKE ALL ON FUNCTION public.enqueue_dual_number_notice_if_needed(TEXT, UUID, BIGINT, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enqueue_dual_number_notice_if_needed(TEXT, UUID, BIGINT, UUID) TO service_role, postgres;
