-- ==============================================================================
-- Migration: 20260926183000_gate_3o_hotfix_block_rpc.sql
-- Module: Base Cadastral Unificada — Gate 3O Hotfix
-- Scope: Correção da referência de coluna na RPC public.admin_toggle_block_morador
-- Causa Raiz:
--   A RPC anterior referenciava `condominio_id` diretamente na tabela `public.unidade_perfil`.
--   A tabela `public.unidade_perfil` relaciona perfis e unidades residenciais,
--   não possuindo a coluna `condominio_id`.
--   O isolamento de condomínio para unidades deve ser feito via JOIN com `public.unidades u`
--   onde `u.condominio_id = v_target.condominio_id`.
-- Invariantes Preservadas:
--   - Transação atômica PostgreSQL
--   - Auditoria compulsória em public.perfil_audit_log (RESIDENT_BLOCKED / RESIDENT_UNBLOCKED)
--   - Isolamento multi-tenant estrito
--   - Proteção contra auto-bloqueio (auth.uid() = p_resident_id)
--   - Preservação integral do perfil e vínculos
--   - Silêncio na reativação (sem triggers de boas-vindas)
--   - SECURITY DEFINER e search_path seguro (public, pg_temp)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_toggle_block_morador(
    p_resident_id UUID,
    p_action TEXT,
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
    v_active_unit_id UUID;
    v_clean_action TEXT;
    v_clean_motivo TEXT;
    v_new_status TEXT;
    v_new_bloqueado BOOLEAN;
    v_acao_audit TEXT;
    v_is_blocked BOOLEAN;
    v_updated_at TIMESTAMPTZ;
BEGIN
    -- 1. Identificar operador autenticado
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. Validar parâmetro de ação
    v_clean_action := lower(trim(COALESCE(p_action, '')));
    IF v_clean_action NOT IN ('block', 'unblock') THEN
        RAISE EXCEPTION 'Ação inválida (%). Esperado: block ou unblock.', p_action;
    END IF;

    -- 3. Verificar privilégio SuperAdmin (ADR-002)
    v_is_superadmin := EXISTS (
        SELECT 1
        FROM public.system_superadmins ss
        WHERE lower(ss.email) = lower(COALESCE((auth.jwt() ->> 'email'), ''))
    );

    -- 4. Validar operador local do condomínio (se não for SuperAdmin)
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

        IF LOWER(COALESCE(v_op.papel_sistema, '')) NOT IN ('admin', 'administrador', 'administradora', 'síndico', 'sindico', 'subsíndico', 'subsindico') THEN
            RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem bloquear ou reativar moradores.';
        END IF;
    END IF;

    -- 5. Proteção contra auto-bloqueio do próprio operador
    IF p_resident_id = v_operator_id THEN
        RAISE EXCEPTION 'Operação inválida. Não é permitido bloquear ou reativar o próprio usuário operador.';
    END IF;

    -- 6. Localizar e travar perfil alvo com FOR UPDATE
    IF p_resident_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do morador é obrigatório.';
    END IF;

    SELECT id, condominio_id, status_aprovacao, bloqueado, nome_completo, papel_sistema
    INTO v_target
    FROM public.perfil
    WHERE id = p_resident_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Morador alvo não encontrado.';
    END IF;

    -- 7. Isolamento multi-tenant estrito
    IF NOT v_is_superadmin AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    -- 8. Validações de máquina de estados e definição de novos valores
    v_is_blocked := (v_target.status_aprovacao = 'bloqueado' OR COALESCE(v_target.bloqueado, false) = true);

    IF v_clean_action = 'block' THEN
        IF v_is_blocked THEN
            RAISE EXCEPTION 'Este morador já se encontra bloqueado.';
        END IF;

        IF v_target.status_aprovacao = 'pendente' THEN
            RAISE EXCEPTION 'Cadastros pendentes devem ser aprovados ou rejeitados na esteira de aprovações, não bloqueados.';
        END IF;

        IF v_target.status_aprovacao = 'inativo' THEN
            RAISE EXCEPTION 'Moradores inativos não podem ser bloqueados.';
        END IF;

        v_new_status := 'bloqueado';
        v_new_bloqueado := true;
        v_acao_audit := 'RESIDENT_BLOCKED';
        v_clean_motivo := COALESCE(NULLIF(trim(p_motivo), ''), 'Bloqueio administrativo de acesso');
    ELSE
        -- unblock
        IF NOT v_is_blocked THEN
            RAISE EXCEPTION 'Este morador não se encontra bloqueado.';
        END IF;

        v_new_status := 'aprovado';
        v_new_bloqueado := false;
        v_acao_audit := 'RESIDENT_UNBLOCKED';
        v_clean_motivo := COALESCE(NULLIF(trim(p_motivo), ''), 'Reativação administrativa de acesso');
    END IF;

    -- 9. Obter unidade ativa do morador (se houver) para contexto no audit log
    -- CANONICAL FIX: unidade_perfil não possui condominio_id diretamente;
    -- o relacionamento canônico com o condomínio dá-se via JOIN com public.unidades u.
    SELECT up.unidade_id INTO v_active_unit_id
    FROM public.unidade_perfil up
    JOIN public.unidades u ON u.id = up.unidade_id
    WHERE up.perfil_id = p_resident_id
      AND u.condominio_id = v_target.condominio_id
      AND up.status = 'ativo'
    ORDER BY up.created_at DESC
    LIMIT 1;

    -- 10. Atualizar perfil com novos status e flag
    UPDATE public.perfil
    SET status_aprovacao = v_new_status,
        bloqueado = v_new_bloqueado,
        updated_at = now()
    WHERE id = p_resident_id
    RETURNING updated_at INTO v_updated_at;

    -- 11. Gravar auditoria atômica obrigatória
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
        v_active_unit_id,
        v_acao_audit,
        v_clean_motivo,
        jsonb_build_object(
            'status_aprovacao', v_target.status_aprovacao,
            'bloqueado', COALESCE(v_target.bloqueado, false)
        ),
        jsonb_build_object(
            'status_aprovacao', v_new_status,
            'bloqueado', v_new_bloqueado
        ),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', p_resident_id,
        'condominio_id', v_target.condominio_id,
        'action', v_clean_action,
        'new_status', v_new_status,
        'new_bloqueado', v_new_bloqueado,
        'updated_at', v_updated_at
    );
END;
$$;

-- Permissões de Execução (authenticated only)
REVOKE EXECUTE ON FUNCTION public.admin_toggle_block_morador(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_toggle_block_morador(UUID, TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION public.admin_toggle_block_morador(UUID, TEXT, TEXT) IS 'Bloqueio e desbloqueio atômico de morador com validação multi-tenant via unidades e auditoria compulsória RESIDENT_BLOCKED / RESIDENT_UNBLOCKED (Gate 3O Hotfix)';
