-- ==============================================================================
-- Migration: 20260926090000_create_admin_cadastrar_dependente_rpc.sql
-- Module: Base Cadastral 360º — Gate 3G.2-A (Parte 3A.1)
-- Scope: RPC public.admin_cadastrar_dependente
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_cadastrar_dependente(
    p_unidade_id UUID,
    p_responsavel_perfil_id UUID,
    p_nome_completo TEXT,
    p_parentesco TEXT,
    p_data_nascimento DATE,
    p_observacao TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_operator_id UUID;
    v_condominio_id UUID;
    v_resp RECORD;
    v_is_superadmin BOOLEAN;
    v_is_admin BOOLEAN;
    v_is_own_responsible BOOLEAN;
    v_clean_nome TEXT;
    v_observacao TEXT;
    v_dependente_id UUID;
BEGIN
    -- 1. IDENTIFICAR OPERADOR AUTENTICADO
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. VALIDAR UNIDADE E DERIVAR CONDOMÍNIO
    IF p_unidade_id IS NULL THEN
        RAISE EXCEPTION 'A unidade residencial é obrigatória.';
    END IF;

    SELECT u.condominio_id
    INTO v_condominio_id
    FROM public.unidades u
    WHERE u.id = p_unidade_id;

    IF v_condominio_id IS NULL THEN
        RAISE EXCEPTION 'Unidade residencial não encontrada ou sem condomínio associado.';
    END IF;

    -- 3. VALIDAR MORADOR RESPONSÁVEL
    IF p_responsavel_perfil_id IS NULL THEN
        RAISE EXCEPTION 'O morador responsável é obrigatório.';
    END IF;

    SELECT p.id, p.condominio_id, p.status_aprovacao, p.bloqueado
    INTO v_resp
    FROM public.perfil p
    WHERE p.id = p_responsavel_perfil_id;

    IF v_resp.id IS NULL THEN
        RAISE EXCEPTION 'Morador responsável não encontrado.';
    END IF;

    IF v_resp.condominio_id IS DISTINCT FROM v_condominio_id THEN
        RAISE EXCEPTION 'O morador responsável pertence a condomínio divergente da unidade.';
    END IF;

    IF v_resp.status_aprovacao IS DISTINCT FROM 'aprovado' OR COALESCE(v_resp.bloqueado, false) = true THEN
        RAISE EXCEPTION 'Morador responsável com acesso bloqueado ou pendente de aprovação.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.unidade_perfil up
        WHERE up.perfil_id = p_responsavel_perfil_id
          AND up.unidade_id = p_unidade_id
          AND up.status = 'ativo'
    ) THEN
        RAISE EXCEPTION 'Vínculo residencial inválido. O responsável não possui vínculo ativo com a unidade selecionada.';
    END IF;

    -- 4. AUTORIZAÇÃO DO OPERADOR (SUPERADMIN, ADMIN DO CONDOMÍNIO OU PRÓPRIO RESPONSÁVEL)
    v_is_superadmin := EXISTS (
        SELECT 1
        FROM public.system_superadmins ss
        WHERE lower(ss.email) = lower(COALESCE((auth.jwt() ->> 'email'), ''))
    );

    v_is_admin := EXISTS (
        SELECT 1
        FROM public.perfil p
        WHERE p.id = v_operator_id
          AND p.condominio_id = v_condominio_id
          AND p.status_aprovacao = 'aprovado'
          AND COALESCE(p.bloqueado, false) = false
          AND lower(COALESCE(p.papel_sistema, '')) = ANY (ARRAY[
              'admin',
              'síndico',
              'sindico',
              'subsíndico',
              'subsindico',
              'administradora'
          ])
    );

    v_is_own_responsible := (v_operator_id = p_responsavel_perfil_id);

    IF NOT (v_is_superadmin OR v_is_admin OR v_is_own_responsible) THEN
        RAISE EXCEPTION 'Permissão negada. Apenas síndicos, administradores ou o próprio responsável podem cadastrar dependentes.';
    END IF;

    -- 5. VALIDAR DADOS DO DEPENDENTE
    v_clean_nome := trim(COALESCE(p_nome_completo, ''));
    IF length(v_clean_nome) < 2 THEN
        RAISE EXCEPTION 'Nome do dependente inválido. Mínimo de 2 caracteres.';
    END IF;

    IF p_parentesco NOT IN (
        'filho',
        'conjuge_companheiro',
        'pai_mae',
        'enteado',
        'outro_familiar',
        'outro_dependente'
    ) THEN
        RAISE EXCEPTION 'Parentesco inválido (%). Valores permitidos: filho, conjuge_companheiro, pai_mae, enteado, outro_familiar, outro_dependente.', p_parentesco;
    END IF;

    IF p_data_nascimento IS NULL THEN
        RAISE EXCEPTION 'A data de nascimento é obrigatória.';
    END IF;

    IF p_data_nascimento > CURRENT_DATE THEN
        RAISE EXCEPTION 'A data de nascimento não pode estar no futuro (%).', p_data_nascimento;
    END IF;

    v_observacao := NULLIF(trim(COALESCE(p_observacao, '')), '');
    IF v_observacao IS NOT NULL AND length(v_observacao) > 500 THEN
        RAISE EXCEPTION 'A observação deve ter no máximo 500 caracteres.';
    END IF;

    -- 6. PREVENÇÃO DE DUPLICIDADE ATIVA NA MESMA UNIDADE
    IF EXISTS (
        SELECT 1
        FROM public.dependentes d
        WHERE d.unidade_id = p_unidade_id
          AND lower(trim(d.nome_completo)) = lower(v_clean_nome)
          AND d.data_nascimento = p_data_nascimento
          AND d.status = 'ativo'
    ) THEN
        RAISE EXCEPTION 'Já existe um dependente ativo com este nome e data de nascimento na mesma unidade.';
    END IF;

    -- 7. INSERT EM public.dependentes
    v_dependente_id := gen_random_uuid();

    INSERT INTO public.dependentes (
        id,
        condominio_id,
        unidade_id,
        responsavel_perfil_id,
        nome_completo,
        parentesco,
        data_nascimento,
        observacao,
        status,
        foto_path,
        perfil_convertido_id
    ) VALUES (
        v_dependente_id,
        v_condominio_id,
        p_unidade_id,
        p_responsavel_perfil_id,
        v_clean_nome,
        p_parentesco,
        p_data_nascimento,
        v_observacao,
        'ativo',
        NULL,
        NULL
    );

    -- 8. AUDITORIA OBRIGATÓRIA EM public.perfil_audit_log
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
        v_condominio_id,
        p_responsavel_perfil_id,
        CASE WHEN EXISTS (SELECT 1 FROM public.perfil p WHERE p.id = v_operator_id) THEN v_operator_id ELSE NULL END,
        p_unidade_id,
        'DEPENDENT_CREATED',
        NULL,
        '{}'::jsonb,
        jsonb_build_object(
            'dependente_id', v_dependente_id,
            'unidade_id', p_unidade_id,
            'parentesco', p_parentesco,
            'operador', v_operator_id
        ),
        now()
    );

    -- 9. RETORNO ESTRUTURADO SANITIZADO
    RETURN jsonb_build_object(
        'id', v_dependente_id,
        'condominio_id', v_condominio_id,
        'unidade_id', p_unidade_id,
        'responsavel_perfil_id', p_responsavel_perfil_id,
        'nome_completo', v_clean_nome,
        'parentesco', p_parentesco,
        'data_nascimento', p_data_nascimento,
        'status', 'ativo'
    );

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Já existe um dependente ativo com este nome e data de nascimento na mesma unidade.';
END;
$$;

-- Permissões de Execução
REVOKE EXECUTE ON FUNCTION public.admin_cadastrar_dependente(UUID, UUID, TEXT, TEXT, DATE, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_cadastrar_dependente(UUID, UUID, TEXT, TEXT, DATE, TEXT) TO authenticated;

COMMENT ON FUNCTION public.admin_cadastrar_dependente(UUID, UUID, TEXT, TEXT, DATE, TEXT) IS 'Cadastra dependente vinculado a morador e unidade com validação de parentesco, dados civis, guard multi-tenant e auditoria DEPENDENT_CREATED (Gate 3G.2-A Parte 3A.1)';
