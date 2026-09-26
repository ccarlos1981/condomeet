-- ==============================================================================
-- Migration: 20260926093000_create_admin_atualizar_dependente_rpc.sql
-- Module: Base Cadastral 360º — Gate 3G.2-A (Parte 3B.1)
-- Scope: RPC public.admin_atualizar_dependente
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_atualizar_dependente(
    p_dependente_id UUID,
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
    v_dep RECORD;
    v_resp RECORD;
    v_is_superadmin BOOLEAN;
    v_is_admin BOOLEAN;
    v_is_own_responsible BOOLEAN := false;
    v_clean_nome TEXT;
    v_observacao TEXT;
    v_updated_at TIMESTAMPTZ;
BEGIN
    -- 1. IDENTIFICAR OPERADOR AUTENTICADO
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. LOCALIZAR DEPENDENTE
    IF p_dependente_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do dependente é obrigatório.';
    END IF;

    SELECT id, condominio_id, unidade_id, responsavel_perfil_id, status, parentesco
    INTO v_dep
    FROM public.dependentes
    WHERE id = p_dependente_id;

    IF v_dep.id IS NULL THEN
        RAISE EXCEPTION 'Dependente não encontrado.';
    END IF;

    -- 3. IMUTABILIDADE DO INATIVO
    IF v_dep.status IS DISTINCT FROM 'ativo' THEN
        RAISE EXCEPTION 'Operação não permitida. Dependentes inativos não podem ser atualizados.';
    END IF;

    -- 4. AUTORIZAÇÃO DO OPERADOR (SUPERADMIN, ADMIN DO MESMO CONDOMÍNIO OU PRÓPRIO RESPONSÁVEL)
    v_is_superadmin := EXISTS (
        SELECT 1
        FROM public.system_superadmins ss
        WHERE lower(ss.email) = lower(COALESCE((auth.jwt() ->> 'email'), ''))
    );

    v_is_admin := EXISTS (
        SELECT 1
        FROM public.perfil p
        WHERE p.id = v_operator_id
          AND p.condominio_id = v_dep.condominio_id
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

    IF v_operator_id = v_dep.responsavel_perfil_id THEN
        SELECT p.id, p.condominio_id, p.status_aprovacao, p.bloqueado
        INTO v_resp
        FROM public.perfil p
        WHERE p.id = v_dep.responsavel_perfil_id;

        IF v_resp.id IS NOT NULL
           AND v_resp.condominio_id = v_dep.condominio_id
           AND v_resp.status_aprovacao = 'aprovado'
           AND COALESCE(v_resp.bloqueado, false) = false
           AND EXISTS (
               SELECT 1
               FROM public.unidade_perfil up
               WHERE up.perfil_id = v_dep.responsavel_perfil_id
                 AND up.unidade_id = v_dep.unidade_id
                 AND up.status = 'ativo'
           ) THEN
            v_is_own_responsible := true;
        END IF;
    END IF;

    IF NOT (v_is_superadmin OR v_is_admin OR v_is_own_responsible) THEN
        RAISE EXCEPTION 'Permissão negada. Apenas síndicos, administradores ou o próprio responsável podem atualizar dependentes.';
    END IF;

    -- 5. VALIDAR DADOS
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

    -- 6. DUPLICIDADE (OUTRO DEPENDENTE ATIVO NA MESMA UNIDADE)
    IF EXISTS (
        SELECT 1
        FROM public.dependentes d
        WHERE d.unidade_id = v_dep.unidade_id
          AND lower(trim(d.nome_completo)) = lower(v_clean_nome)
          AND d.data_nascimento = p_data_nascimento
          AND d.status = 'ativo'
          AND d.id <> p_dependente_id
    ) THEN
        RAISE EXCEPTION 'Já existe outro dependente ativo com este nome e data de nascimento na mesma unidade.';
    END IF;

    -- 7. UPDATE (CAMPOS PERMITIDOS SOMENTE)
    UPDATE public.dependentes
    SET nome_completo = v_clean_nome,
        parentesco = p_parentesco,
        data_nascimento = p_data_nascimento,
        observacao = v_observacao,
        updated_at = now()
    WHERE id = p_dependente_id
    RETURNING updated_at INTO v_updated_at;

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
        v_dep.condominio_id,
        v_dep.responsavel_perfil_id,
        CASE WHEN EXISTS (SELECT 1 FROM public.perfil p WHERE p.id = v_operator_id) THEN v_operator_id ELSE NULL END,
        v_dep.unidade_id,
        'DEPENDENT_UPDATED',
        NULL,
        jsonb_build_object(
            'parentesco', v_dep.parentesco
        ),
        jsonb_build_object(
            'dependente_id', p_dependente_id,
            'unidade_id', v_dep.unidade_id,
            'parentesco', p_parentesco,
            'operador', v_operator_id
        ),
        now()
    );

    -- 9. RETORNO ESTRUTURADO SANITIZADO
    RETURN jsonb_build_object(
        'id', p_dependente_id,
        'condominio_id', v_dep.condominio_id,
        'unidade_id', v_dep.unidade_id,
        'responsavel_perfil_id', v_dep.responsavel_perfil_id,
        'nome_completo', v_clean_nome,
        'parentesco', p_parentesco,
        'data_nascimento', p_data_nascimento,
        'status', v_dep.status,
        'updated_at', v_updated_at
    );

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Já existe outro dependente ativo com este nome e data de nascimento na mesma unidade.';
END;
$$;

-- Permissões de Execução
REVOKE EXECUTE ON FUNCTION public.admin_atualizar_dependente(UUID, TEXT, TEXT, DATE, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_atualizar_dependente(UUID, TEXT, TEXT, DATE, TEXT) TO authenticated;

COMMENT ON FUNCTION public.admin_atualizar_dependente(UUID, TEXT, TEXT, DATE, TEXT) IS 'Atualiza dados cadastrais de dependente ativo com validação de parentesco, dados civis, guard multi-tenant e auditoria DEPENDENT_UPDATED (Gate 3G.2-A Parte 3B.1)';
