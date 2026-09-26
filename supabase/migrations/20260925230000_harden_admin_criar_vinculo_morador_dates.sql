-- ==============================================================================
-- Migration: 20260925230000_harden_admin_criar_vinculo_morador_dates.sql
-- Module: Base Cadastral Unificada (Gate 3C.7-B)
-- Purpose: Hardening of temporal validation in public.admin_criar_vinculo_morador
--          to strictly require that new entry date for the SAME unit must be
--          strictly posterior to the previous exit date (data_saida >= p_data_entrada).
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_criar_vinculo_morador(
    p_perfil_id UUID,
    p_unidade_id UUID,
    p_data_entrada TIMESTAMPTZ,
    p_tipo_morador TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_operator_id UUID;
    v_op RECORD;
    v_target RECORD;
    v_unit RECORD;
    v_clean_tipo TEXT;
    v_new_link_id UUID;
    v_allowed_tipos TEXT[] := ARRAY[
        'Proprietário (a)',
        'Inquilino (a)',
        'Morador (a)',
        'Dependente',
        'Cônjuge',
        'Família',
        'Proprietário não morador',
        'Locador',
        'Locatário',
        'Síndico'
    ];
BEGIN
    -- 1. IDENTIFICAR OPERADOR AUTENTICADO
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. VALIDAÇÃO DO OPERADOR (SÍNDICO / ADMIN DO CONDOMÍNIO OU SUPERADMIN)
    SELECT id, email, condominio_id, papel_sistema, status_aprovacao, bloqueado
    INTO v_op
    FROM public.perfil
    WHERE id = v_operator_id;

    IF v_op.id IS NULL OR v_op.condominio_id IS NULL THEN
        -- Verificar se é SuperAdmin Centralizado (ADR-002)
        IF NOT EXISTS (
            SELECT 1 FROM public.system_superadmins s
            WHERE lower(s.email) = lower(coalesce(v_op.email, ''))
               OR lower(s.email) = lower(coalesce(auth.jwt()->>'email', ''))
        ) THEN
            RAISE EXCEPTION 'Operador não cadastrado ou sem condomínio associado.';
        END IF;
    END IF;

    IF v_op.id IS NOT NULL THEN
        IF v_op.status_aprovacao IS DISTINCT FROM 'aprovado' OR COALESCE(v_op.bloqueado, false) = true THEN
            RAISE EXCEPTION 'Operador com acesso bloqueado ou pendente de aprovação.';
        END IF;

        IF LOWER(COALESCE(v_op.papel_sistema, '')) NOT IN ('admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora') THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.system_superadmins s
                WHERE lower(s.email) = lower(coalesce(v_op.email, ''))
                   OR lower(s.email) = lower(coalesce(auth.jwt()->>'email', ''))
            ) THEN
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem criar vínculos de morador.';
            END IF;
        END IF;
    END IF;

    -- 3. VALIDAÇÃO DOS PARÂMETROS BÁSICOS
    IF p_perfil_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do morador é obrigatório.';
    END IF;

    IF p_unidade_id IS NULL THEN
        RAISE EXCEPTION 'A unidade residencial é obrigatória.';
    END IF;

    IF p_data_entrada IS NULL THEN
        RAISE EXCEPTION 'A data de entrada é obrigatória.';
    END IF;

    -- Tolerância de data futura máxima: 30 dias
    IF p_data_entrada > (now() + interval '30 days') THEN
        RAISE EXCEPTION 'A data de entrada não pode ser superior a 30 dias no futuro.';
    END IF;

    -- 4. BLOQUEIO DE CONCORRÊNCIA E VALIDAÇÃO DO PERFIL ALVO
    SELECT id, condominio_id, status_aprovacao, bloqueado, papel_sistema, tipo_morador, bloco_txt, apto_txt, nome_completo
    INTO v_target
    FROM public.perfil
    WHERE id = p_perfil_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Morador alvo não encontrado.';
    END IF;

    -- Isolamento Multi-Tenant Estrito (Invariante Suprema 2)
    IF v_op.condominio_id IS NOT NULL AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    -- Bloqueio administrativo disciplinar ativo
    IF COALESCE(v_target.bloqueado, false) = true OR v_target.status_aprovacao = 'bloqueado' THEN
        RAISE EXCEPTION 'Este usuário possui um bloqueio administrativo ativo. Reative o acesso antes de criar um novo vínculo residencial.';
    END IF;

    -- Não permitir perfis pendentes ou reprovados
    IF v_target.status_aprovacao IN ('pendente', 'rejeitado', 'reprovado') THEN
        RAISE EXCEPTION 'Operação não permitida para cadastros pendentes ou reprovados.';
    END IF;

    -- Validar elegibilidade de status: deve ser inativo ou proprietário não morador
    IF v_target.status_aprovacao NOT IN ('inativo', 'aprovado') THEN
        RAISE EXCEPTION 'Status cadastral incompatível para criação de novo vínculo: %.', v_target.status_aprovacao;
    END IF;

    -- 5. VALIDAÇÃO DE VÍNCULO ATIVO EXISTENTE (UMA RESIDÊNCIA ATIVA NO FLUXO DE RETORNO)
    IF EXISTS (
        SELECT 1 FROM public.unidade_perfil
        WHERE perfil_id = p_perfil_id AND status = 'ativo'
    ) THEN
        RAISE EXCEPTION 'Este morador já possui um vínculo residencial ativo.';
    END IF;

    -- 6. VALIDAÇÃO DA UNIDADE RESIDENCIAL
    SELECT u.id, u.condominio_id, b.nome_ou_numero as bloco_nome, a.numero as apto_numero
    INTO v_unit
    FROM public.unidades u
    JOIN public.blocos b ON b.id = u.bloco_id
    JOIN public.apartamentos a ON a.id = u.apartamento_id
    WHERE u.id = p_unidade_id;

    IF v_unit.id IS NULL THEN
        RAISE EXCEPTION 'Unidade residencial não encontrada no sistema.';
    END IF;

    -- Isolamento Multi-Tenant da Unidade
    IF v_unit.condominio_id IS DISTINCT FROM v_target.condominio_id THEN
        RAISE EXCEPTION 'A unidade selecionada pertence a um condomínio diferente do morador.';
    END IF;

    -- 7. VALIDAÇÃO DO TIPO DE MORADOR
    v_clean_tipo := TRIM(COALESCE(p_tipo_morador, ''));
    IF v_clean_tipo = '' THEN
        -- Fallback seguro se não informado
        IF v_target.tipo_morador IS NOT NULL AND v_target.tipo_morador <> 'Proprietário não morador' THEN
            v_clean_tipo := v_target.tipo_morador;
        ELSE
            v_clean_tipo := 'Morador (a)';
        END IF;
    END IF;

    IF NOT (v_clean_tipo = ANY(v_allowed_tipos)) THEN
        RAISE EXCEPTION 'Tipo de morador inválido: "%". Valores permitidos: %', v_clean_tipo, array_to_string(v_allowed_tipos, ', ');
    END IF;

    -- 8. VALIDAÇÃO DE SOBREPOSIÇÃO TEMPORAL NA MESMA UNIDADE (Gate 3C.7-B Hardening)
    -- Nova data de entrada deve ser ESTRITAMENTE POSTERIOR à data de saída anterior (>= rejeita)
    IF EXISTS (
        SELECT 1 FROM public.unidade_perfil
        WHERE perfil_id = p_perfil_id
          AND unidade_id = p_unidade_id
          AND data_saida IS NOT NULL
          AND data_saida >= p_data_entrada
    ) THEN
        RAISE EXCEPTION 'Para esta unidade, a data de entrada do novo vínculo deve ser posterior à última data de saída.';
    END IF;

    -- 9. INSERT DO NOVO PERÍODO (RETORNO = NOVO VÍNCULO / NOVO PERÍODO)
    v_new_link_id := gen_random_uuid();

    INSERT INTO public.unidade_perfil (
        id,
        perfil_id,
        unidade_id,
        status,
        data_entrada,
        data_saida,
        created_at
    ) VALUES (
        v_new_link_id,
        p_perfil_id,
        p_unidade_id,
        'ativo',
        p_data_entrada,
        NULL,
        now()
    );

    -- 10. UPDATE DO PERFIL DO MORADOR
    UPDATE public.perfil
    SET status_aprovacao = 'aprovado',
        bloqueado = false,
        bloco_txt = v_unit.bloco_nome,
        apto_txt = v_unit.apto_numero,
        tipo_morador = v_clean_tipo,
        updated_at = now()
    WHERE id = p_perfil_id;

    -- 11. REGISTRO ATÔMICO DE AUDITORIA
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
        p_perfil_id,
        v_operator_id,
        p_unidade_id,
        'UNIT_LINK_CREATED',
        'Novo vínculo residencial atribuído pelo administrador',
        jsonb_build_object(
            'status_aprovacao', v_target.status_aprovacao,
            'bloqueado', v_target.bloqueado,
            'tipo_morador', v_target.tipo_morador,
            'bloco_txt', v_target.bloco_txt,
            'apto_txt', v_target.apto_txt
        ),
        jsonb_build_object(
            'status_aprovacao', 'aprovado',
            'bloqueado', false,
            'tipo_morador', v_clean_tipo,
            'bloco_txt', v_unit.bloco_nome,
            'apto_txt', v_unit.apto_numero,
            'unidade_id', p_unidade_id,
            'data_entrada', p_data_entrada,
            'vinculo_id', v_new_link_id
        ),
        now()
    );

    -- 12. RETORNO ESTRUTURADO SANITIZADO
    RETURN jsonb_build_object(
        'success', true,
        'action', 'UNIT_LINK_CREATED',
        'profile_id', p_perfil_id,
        'link_id', v_new_link_id,
        'unit_id', p_unidade_id,
        'profile_status', 'aprovado',
        'link_status', 'ativo',
        'resident_type', v_clean_tipo,
        'block', v_unit.bloco_nome,
        'apartment', v_unit.apto_numero,
        'entry_date', p_data_entrada,
        'message', 'Novo vínculo residencial criado com sucesso.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_criar_vinculo_morador(UUID, UUID, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_criar_vinculo_morador(UUID, UUID, TIMESTAMPTZ, TEXT) TO authenticated, service_role;

COMMENT ON FUNCTION public.admin_criar_vinculo_morador(UUID, UUID, TIMESTAMPTZ, TEXT) 
IS 'Cria um novo período/vínculo residencial ativo com validação temporal estrita de nova entrada > saída anterior (Gate 3C.7-B).';
