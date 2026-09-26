-- ==============================================================================
-- Migration: 20260926180000_gate_3o_atomic_approval_rejection_block_rpcs.sql
-- Module: Base Cadastral Unificada — Gate 3O
-- Scope: RPCs PostgreSQL SECURITY DEFINER para Aprovação, Rejeição e Bloqueio Atômicos
--        1. public.admin_aprovar_morador
--        2. public.admin_rejeitar_morador
--        3. public.admin_toggle_block_morador
-- Purpose:
--   - Execução 100% atômica no banco de dados na mesma transação PostgreSQL
--   - Registro compulsório de auditoria em public.perfil_audit_log
--   - Isolamento multi-tenant estrito e proteção contra auto-modificação
--   - Preservação do trigger canônico tr_fn_perfil_approved (notifica apenas pendente -> aprovado)
--   - Eliminação de qualquer regime non-atomic ou mutação desprovida de auditoria
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. RPC: public.admin_aprovar_morador
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_aprovar_morador(
    p_resident_id UUID,
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
    v_clean_motivo TEXT;
    v_updated_at TIMESTAMPTZ;
BEGIN
    -- 1.1 Identificar operador autenticado
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 1.2 Verificar privilégio SuperAdmin (ADR-002)
    v_is_superadmin := EXISTS (
        SELECT 1
        FROM public.system_superadmins ss
        WHERE lower(ss.email) = lower(COALESCE((auth.jwt() ->> 'email'), ''))
    );

    -- 1.3 Validar operador local do condomínio (se não for SuperAdmin)
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
            RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem aprovar moradores.';
        END IF;
    END IF;

    -- 1.4 Proteção contra auto-aprovação do próprio operador
    IF p_resident_id = v_operator_id THEN
        RAISE EXCEPTION 'Operação inválida. Não é permitido aprovar o próprio usuário operador.';
    END IF;

    -- 1.5 Localizar e travar perfil alvo com FOR UPDATE
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

    -- 1.6 Isolamento multi-tenant estrito
    IF NOT v_is_superadmin AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    -- 1.7 Validações de máquina de estados
    IF v_target.status_aprovacao = 'aprovado' THEN
        RAISE EXCEPTION 'Este morador já se encontra aprovado.';
    END IF;

    IF v_target.status_aprovacao = 'bloqueado' OR COALESCE(v_target.bloqueado, false) = true THEN
        RAISE EXCEPTION 'Moradores bloqueados devem ser reativados na ação de desbloqueio, não aprovados.';
    END IF;

    IF v_target.status_aprovacao = 'inativo' THEN
        RAISE EXCEPTION 'Moradores inativos devem receber um novo vínculo residencial, não aprovação direta.';
    END IF;

    IF v_target.status_aprovacao NOT IN ('pendente', 'rejeitado', 'reprovado') THEN
        RAISE EXCEPTION 'Status atual do morador não permite aprovação.';
    END IF;

    -- 1.8 Obter unidade ativa do morador (se houver) para contexto no audit log
    SELECT unidade_id INTO v_active_unit_id
    FROM public.unidade_perfil
    WHERE perfil_id = p_resident_id
      AND condominio_id = v_target.condominio_id
      AND status = 'ativo'
    ORDER BY created_at DESC
    LIMIT 1;

    -- 1.9 Atualizar perfil para aprovado
    -- Nota: O trigger tr_fn_perfil_approved dispara notificação SOMENTE se OLD.status_aprovacao = 'pendente'
    UPDATE public.perfil
    SET status_aprovacao = 'aprovado',
        updated_at = now()
    WHERE id = p_resident_id
    RETURNING updated_at INTO v_updated_at;

    -- 1.10 Sanitizar motivo da auditoria
    v_clean_motivo := NULLIF(trim(COALESCE(p_motivo, '')), '');
    IF v_clean_motivo IS NULL THEN
        IF v_target.status_aprovacao IN ('rejeitado', 'reprovado') THEN
            v_clean_motivo := 'Aprovação de cadastro previamente rejeitado';
        ELSE
            v_clean_motivo := 'Aprovação cadastral pelo gestor';
        END IF;
    END IF;

    -- 1.11 Gravar auditoria atômica obrigatória
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
        'RESIDENT_APPROVED',
        v_clean_motivo,
        jsonb_build_object(
            'status_aprovacao', v_target.status_aprovacao,
            'bloqueado', COALESCE(v_target.bloqueado, false)
        ),
        jsonb_build_object(
            'status_aprovacao', 'aprovado',
            'bloqueado', COALESCE(v_target.bloqueado, false)
        ),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', p_resident_id,
        'condominio_id', v_target.condominio_id,
        'new_status', 'aprovado',
        'updated_at', v_updated_at
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. RPC: public.admin_rejeitar_morador
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_rejeitar_morador(
    p_resident_id UUID,
    p_motivo TEXT
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
    v_clean_motivo TEXT;
    v_updated_at TIMESTAMPTZ;
BEGIN
    -- 2.1 Identificar operador autenticado
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2.2 Motivo obrigatório com mínimo de 3 caracteres
    v_clean_motivo := trim(COALESCE(p_motivo, ''));
    IF length(v_clean_motivo) < 3 THEN
        RAISE EXCEPTION 'O motivo da rejeição é obrigatório (mínimo de 3 caracteres).';
    END IF;

    -- 2.3 Verificar privilégio SuperAdmin (ADR-002)
    v_is_superadmin := EXISTS (
        SELECT 1
        FROM public.system_superadmins ss
        WHERE lower(ss.email) = lower(COALESCE((auth.jwt() ->> 'email'), ''))
    );

    -- 2.4 Validar operador local do condomínio (se não for SuperAdmin)
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
            RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem rejeitar moradores.';
        END IF;
    END IF;

    -- 2.5 Proteção contra auto-rejeição do próprio operador
    IF p_resident_id = v_operator_id THEN
        RAISE EXCEPTION 'Operação inválida. Não é permitido rejeitar o próprio usuário operador.';
    END IF;

    -- 2.6 Localizar e travar perfil alvo com FOR UPDATE
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

    -- 2.7 Isolamento multi-tenant estrito
    IF NOT v_is_superadmin AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    -- 2.8 Validações de máquina de estados (apenas pendente pode ser rejeitado)
    IF v_target.status_aprovacao IN ('rejeitado', 'reprovado') THEN
        RAISE EXCEPTION 'Este morador já se encontra rejeitado.';
    END IF;

    IF v_target.status_aprovacao = 'aprovado' THEN
        RAISE EXCEPTION 'Moradores aprovados devem ser bloqueados ou inativados, não rejeitados.';
    END IF;

    IF v_target.status_aprovacao = 'bloqueado' OR COALESCE(v_target.bloqueado, false) = true THEN
        RAISE EXCEPTION 'Moradores bloqueados não podem ser rejeitados.';
    END IF;

    IF v_target.status_aprovacao = 'inativo' THEN
        RAISE EXCEPTION 'Moradores inativos não podem ser rejeitados.';
    END IF;

    IF v_target.status_aprovacao <> 'pendente' THEN
        RAISE EXCEPTION 'Status atual do morador não permite rejeição (apenas cadastros pendentes).';
    END IF;

    -- 2.9 Obter unidade ativa do morador (se houver) para contexto no audit log
    SELECT unidade_id INTO v_active_unit_id
    FROM public.unidade_perfil
    WHERE perfil_id = p_resident_id
      AND condominio_id = v_target.condominio_id
      AND status = 'ativo'
    ORDER BY created_at DESC
    LIMIT 1;

    -- 2.10 Atualizar perfil para rejeitado
    UPDATE public.perfil
    SET status_aprovacao = 'rejeitado',
        updated_at = now()
    WHERE id = p_resident_id
    RETURNING updated_at INTO v_updated_at;

    -- 2.11 Gravar auditoria atômica obrigatória
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
        'RESIDENT_REJECTED',
        v_clean_motivo,
        jsonb_build_object(
            'status_aprovacao', v_target.status_aprovacao,
            'bloqueado', COALESCE(v_target.bloqueado, false)
        ),
        jsonb_build_object(
            'status_aprovacao', 'rejeitado',
            'bloqueado', COALESCE(v_target.bloqueado, false)
        ),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', p_resident_id,
        'condominio_id', v_target.condominio_id,
        'new_status', 'rejeitado',
        'updated_at', v_updated_at
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. RPC: public.admin_toggle_block_morador
-- ------------------------------------------------------------------------------
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
    -- 3.1 Identificar operador autenticado
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 3.2 Validar parâmetro de ação
    v_clean_action := lower(trim(COALESCE(p_action, '')));
    IF v_clean_action NOT IN ('block', 'unblock') THEN
        RAISE EXCEPTION 'Ação inválida (%). Esperado: block ou unblock.', p_action;
    END IF;

    -- 3.3 Verificar privilégio SuperAdmin (ADR-002)
    v_is_superadmin := EXISTS (
        SELECT 1
        FROM public.system_superadmins ss
        WHERE lower(ss.email) = lower(COALESCE((auth.jwt() ->> 'email'), ''))
    );

    -- 3.4 Validar operador local do condomínio (se não for SuperAdmin)
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

    -- 3.5 Proteção contra auto-bloqueio do próprio operador
    IF p_resident_id = v_operator_id THEN
        RAISE EXCEPTION 'Operação inválida. Não é permitido bloquear ou reativar o próprio usuário operador.';
    END IF;

    -- 3.6 Localizar e travar perfil alvo com FOR UPDATE
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

    -- 3.7 Isolamento multi-tenant estrito
    IF NOT v_is_superadmin AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    -- 3.8 Validações de máquina de estados e definição de novos valores
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

    -- 3.9 Obter unidade ativa do morador (se houver) para contexto no audit log
    SELECT unidade_id INTO v_active_unit_id
    FROM public.unidade_perfil
    WHERE perfil_id = p_resident_id
      AND condominio_id = v_target.condominio_id
      AND status = 'ativo'
    ORDER BY created_at DESC
    LIMIT 1;

    -- 3.10 Atualizar perfil com novos status e flag
    -- Nota: Na reativação ('bloqueado' -> 'aprovado'), o trigger tr_fn_perfil_approved
    -- verifica que OLD.status_aprovacao = 'bloqueado' e retorna silenciosamente sem notificar.
    UPDATE public.perfil
    SET status_aprovacao = v_new_status,
        bloqueado = v_new_bloqueado,
        updated_at = now()
    WHERE id = p_resident_id
    RETURNING updated_at INTO v_updated_at;

    -- 3.11 Gravar auditoria atômica obrigatória
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

-- ------------------------------------------------------------------------------
-- 4. Permissões de Execução (authenticated only)
-- ------------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.admin_aprovar_morador(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_aprovar_morador(UUID, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_rejeitar_morador(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_rejeitar_morador(UUID, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_toggle_block_morador(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_toggle_block_morador(UUID, TEXT, TEXT) TO authenticated;

-- Comentários de Governança
COMMENT ON FUNCTION public.admin_aprovar_morador(UUID, TEXT) IS 'Aprovação atômica de morador com validação multi-tenant, trigger seguro e auditoria compulsória RESIDENT_APPROVED (Gate 3O)';
COMMENT ON FUNCTION public.admin_rejeitar_morador(UUID, TEXT) IS 'Rejeição atômica de morador com validação multi-tenant, motivo compulsório e auditoria RESIDENT_REJECTED (Gate 3O)';
COMMENT ON FUNCTION public.admin_toggle_block_morador(UUID, TEXT, TEXT) IS 'Bloqueio e desbloqueio atômico de morador com validação multi-tenant e auditoria compulsória RESIDENT_BLOCKED / RESIDENT_UNBLOCKED (Gate 3O)';
