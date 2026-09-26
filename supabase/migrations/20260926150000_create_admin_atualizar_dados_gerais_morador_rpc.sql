-- ==============================================================================
-- Migration: 20260926150000_create_admin_atualizar_dados_gerais_morador_rpc.sql
-- Module: Base Cadastral 360º — Gate 3I.5-B
-- Scope: RPC public.admin_atualizar_dados_gerais_morador
-- Purpose: Atualização atômica de dados gerais do morador + auditoria em perfil_audit_log
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_atualizar_dados_gerais_morador(
    p_resident_id UUID,
    p_nome_completo TEXT,
    p_whatsapp TEXT,
    p_tipo_morador TEXT,
    p_papel_sistema TEXT,
    p_motivo TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_operator_id UUID;
    v_is_superadmin BOOLEAN;
    v_op RECORD;
    v_target RECORD;
    v_clean_nome TEXT;
    v_clean_whatsapp TEXT;
    v_clean_tipo_morador TEXT;
    v_clean_papel TEXT;
    v_updated_at TIMESTAMPTZ;
BEGIN
    -- 1. IDENTIFICAR OPERADOR AUTENTICADO
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. VERIFICAR PRIVILÉGIO SUPERADMIN (ADR-002)
    v_is_superadmin := EXISTS (
        SELECT 1
        FROM public.system_superadmins ss
        WHERE lower(ss.email) = lower(COALESCE((auth.jwt() ->> 'email'), ''))
    );

    -- 3. VALIDAR OPERADOR LOCAL DO CONDOMÍNIO (CASO NÃO SEJA SUPERADMIN)
    SELECT id, email, condominio_id, papel_sistema, status_aprovacao, bloqueado
    INTO v_op
    FROM public.perfil
    WHERE id = v_operator_id;

    IF NOT v_is_superadmin THEN
        IF v_op.id IS NULL OR v_op.condominio_id IS NULL THEN
            RAISE EXCEPTION 'Operador não cadastrado ou sem condomínio associado.';
        END IF;

        IF v_op.status_aprovacao IS DISTINCT FROM 'aprovado' OR COALESCE(v_op.bloqueado, false) = true THEN
            RAISE EXCEPTION 'Operador com acesso bloqueado ou pendente de aprovação.';
        END IF;

        IF LOWER(COALESCE(v_op.papel_sistema, '')) NOT IN ('admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora') THEN
            RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem atualizar dados cadastrais de moradores.';
        END IF;
    END IF;

    -- 4. LOCALIZAR E TRAVAR PERFIL ALVO COM FOR UPDATE
    IF p_resident_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do morador é obrigatório.';
    END IF;

    SELECT id, condominio_id, nome_completo, whatsapp, tipo_morador, papel_sistema, status_aprovacao
    INTO v_target
    FROM public.perfil
    WHERE id = p_resident_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Morador alvo não encontrado.';
    END IF;

    -- 5. ISOLAMENTO MULTI-TENANT ESTRITO
    IF NOT v_is_superadmin AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    -- 6. VALIDAÇÕES DEFENSIVAS DE ENTRADA
    -- Nome Completo
    v_clean_nome := trim(COALESCE(p_nome_completo, ''));
    IF length(v_clean_nome) < 2 THEN
        RAISE EXCEPTION 'Nome completo inválido. Mínimo de 2 caracteres.';
    END IF;

    -- WhatsApp (E.164 canônico brasileiro)
    v_clean_whatsapp := trim(COALESCE(p_whatsapp, ''));
    IF v_clean_whatsapp !~ '^\+55[1-9]{2}[0-9]{8,9}$' THEN
        RAISE EXCEPTION 'Número de WhatsApp inválido (%). Esperado formato internacional E.164 brasileiro (+55DDDNÚMERO).', v_clean_whatsapp;
    END IF;

    -- Tipo de Morador
    v_clean_tipo_morador := trim(COALESCE(p_tipo_morador, ''));
    IF v_clean_tipo_morador = '' THEN
        RAISE EXCEPTION 'O tipo de morador é obrigatório.';
    END IF;

    -- Papel no Sistema
    v_clean_papel := trim(COALESCE(p_papel_sistema, ''));
    IF lower(v_clean_papel) IN ('admin', 'administrador', 'administradora') THEN
        v_clean_papel := 'Admin';
    END IF;

    IF v_clean_papel NOT IN ('Morador', 'Síndico', 'Subsíndico', 'Porteiro', 'Zelador', 'Admin') THEN
        RAISE EXCEPTION 'Papel de sistema inválido (%). Valores aceitos: Morador, Síndico, Subsíndico, Porteiro, Zelador, Admin.', v_clean_papel;
    END IF;

    -- Trava Canônica de Promoção para Admin
    IF v_clean_papel = 'Admin' AND COALESCE(v_target.papel_sistema, '') <> 'Admin' THEN
        IF NOT (
            v_is_superadmin OR
            (v_op.id IS NOT NULL AND lower(COALESCE(v_op.papel_sistema, '')) IN ('admin', 'administrador', 'administradora', 'síndico', 'sindico'))
        ) THEN
            RAISE EXCEPTION 'Permissão negada. Somente Síndico ou Administrador podem atribuir a função de Admin.';
        END IF;
    END IF;

    -- 7. UPDATE EXCLUSIVO DOS QUATRO CAMPOS PERMITIDOS
    UPDATE public.perfil
    SET nome_completo = v_clean_nome,
        whatsapp = v_clean_whatsapp,
        tipo_morador = v_clean_tipo_morador,
        papel_sistema = v_clean_papel,
        updated_at = now()
    WHERE id = p_resident_id
    RETURNING updated_at INTO v_updated_at;

    -- 8. AUDITORIA ATÔMICA OBRIGATÓRIA EM public.perfil_audit_log
    INSERT INTO public.perfil_audit_log (
        condominio_id,
        perfil_id,
        operador_id,
        unidade_id,
        acao,
        motivo,
        estado_anterior,
        estado_posterior,
        created_at
    ) VALUES (
        v_target.condominio_id,
        p_resident_id,
        v_operator_id,
        NULL,
        'RESIDENT_GENERAL_DATA_UPDATED',
        NULLIF(trim(COALESCE(p_motivo, '')), ''),
        jsonb_build_object(
            'nome_completo', COALESCE(v_target.nome_completo, ''),
            'whatsapp', COALESCE(v_target.whatsapp, ''),
            'tipo_morador', COALESCE(v_target.tipo_morador, ''),
            'papel_sistema', COALESCE(v_target.papel_sistema, '')
        ),
        jsonb_build_object(
            'nome_completo', v_clean_nome,
            'whatsapp', v_clean_whatsapp,
            'tipo_morador', v_clean_tipo_morador,
            'papel_sistema', v_clean_papel
        ),
        now()
    );

    -- 9. RETORNO ESTRUTURADO SANITIZADO
    RETURN jsonb_build_object(
        'success', true,
        'id', p_resident_id,
        'condominio_id', v_target.condominio_id,
        'nome_completo', v_clean_nome,
        'whatsapp', v_clean_whatsapp,
        'tipo_morador', v_clean_tipo_morador,
        'papel_sistema', v_clean_papel,
        'updated_at', v_updated_at
    );
END;
$$;

-- Permissões de Execução
REVOKE EXECUTE ON FUNCTION public.admin_atualizar_dados_gerais_morador(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_atualizar_dados_gerais_morador(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION public.admin_atualizar_dados_gerais_morador(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) IS 'Atualização atômica dos dados cadastrais gerais do morador com guard multi-tenant, validação de permissões administrativas e auditoria compulsória RESIDENT_GENERAL_DATA_UPDATED (Gate 3I.5-B)';
