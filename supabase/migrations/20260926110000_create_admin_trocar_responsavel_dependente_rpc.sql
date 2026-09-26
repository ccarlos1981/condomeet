-- ==============================================================================
-- Migration: 20260926110000_create_admin_trocar_responsavel_dependente_rpc.sql
-- Module: Base Cadastral 360º — Gate 3G.2-A (Parte 3E.2)
-- Scope: RPC public.admin_trocar_responsavel_dependente
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_trocar_responsavel_dependente(
    p_dependente_id UUID,
    p_novo_responsavel_perfil_id UUID,
    p_motivo TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_operator_id UUID;
    v_dep RECORD;
    v_novo_resp RECORD;
    v_resp_atual RECORD;
    v_is_superadmin BOOLEAN := false;
    v_is_admin BOOLEAN := false;
    v_is_own_responsible BOOLEAN := false;
    v_clean_motivo TEXT;
    v_updated_at TIMESTAMPTZ;
BEGIN
    -- 1. IDENTIFICAR OPERADOR AUTENTICADO
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. VALIDAR IDENTIFICADORES DE ENTRADA
    IF p_dependente_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do dependente é obrigatório.';
    END IF;

    IF p_novo_responsavel_perfil_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do novo responsável é obrigatório.';
    END IF;

    -- 3. LOCALIZAR DEPENDENTE
    SELECT id, condominio_id, unidade_id, responsavel_perfil_id, status, parentesco, perfil_convertido_id
    INTO v_dep
    FROM public.dependentes
    WHERE id = p_dependente_id;

    IF v_dep.id IS NULL THEN
        RAISE EXCEPTION 'Dependente não encontrado.';
    END IF;

    -- 4. GUARD: DEPENDENTE DEVE ESTAR ATIVO
    IF v_dep.status IS DISTINCT FROM 'ativo' THEN
        RAISE EXCEPTION 'Operação não permitida. Apenas dependentes ativos podem ter seu responsável alterado.';
    END IF;

    -- 5. GUARD: DEPENDENTE CONVERTIDO NÃO PERMITIDO
    IF v_dep.perfil_convertido_id IS NOT NULL THEN
        RAISE EXCEPTION 'Operação não permitida. Dependentes com perfil próprio vinculado não podem ter seu responsável alterado por esta rotina.';
    END IF;

    -- 6. GUARD: NOVO RESPONSÁVEL NÃO PODE SER O ATUAL
    IF p_novo_responsavel_perfil_id = v_dep.responsavel_perfil_id THEN
        RAISE EXCEPTION 'Operação não permitida. O novo responsável informado é idêntico ao responsável atual.';
    END IF;

    -- 7. LOCALIZAR E VALIDAR NOVO RESPONSÁVEL
    SELECT p.id, p.condominio_id, p.status_aprovacao, p.bloqueado
    INTO v_novo_resp
    FROM public.perfil p
    WHERE p.id = p_novo_responsavel_perfil_id;

    IF v_novo_resp.id IS NULL THEN
        RAISE EXCEPTION 'Novo morador responsável não encontrado.';
    END IF;

    -- GUARD: MESMO CONDOMÍNIO
    IF v_novo_resp.condominio_id IS DISTINCT FROM v_dep.condominio_id THEN
        RAISE EXCEPTION 'O novo responsável pertence a condomínio divergente do dependente.';
    END IF;

    -- GUARD: APROVADO E NÃO BLOQUEADO
    IF v_novo_resp.status_aprovacao IS DISTINCT FROM 'aprovado' OR COALESCE(v_novo_resp.bloqueado, false) = true THEN
        RAISE EXCEPTION 'Novo morador responsável com acesso bloqueado ou pendente de aprovação.';
    END IF;

    -- GUARD: VÍNCULO RESIDENCIAL ATIVO NA MESMA UNIDADE
    IF NOT EXISTS (
        SELECT 1
        FROM public.unidade_perfil up
        WHERE up.perfil_id = p_novo_responsavel_perfil_id
          AND up.unidade_id = v_dep.unidade_id
          AND up.status = 'ativo'
    ) THEN
        RAISE EXCEPTION 'Vínculo residencial inválido. O novo responsável não possui vínculo ativo com a unidade do dependente.';
    END IF;

    -- 8. AUTORIZAÇÃO DO OPERADOR (SUPERADMIN, ADMIN DO MESMO CONDOMÍNIO OU RESPONSÁVEL ATUAL)
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

    IF NOT (v_is_superadmin OR v_is_admin) THEN
        IF v_operator_id = v_dep.responsavel_perfil_id THEN
            SELECT p.id, p.condominio_id, p.status_aprovacao, p.bloqueado
            INTO v_resp_atual
            FROM public.perfil p
            WHERE p.id = v_dep.responsavel_perfil_id;

            IF v_resp_atual.id IS NOT NULL
               AND v_resp_atual.condominio_id = v_dep.condominio_id
               AND v_resp_atual.status_aprovacao = 'aprovado'
               AND COALESCE(v_resp_atual.bloqueado, false) = false
               AND EXISTS (
                   SELECT 1
                   FROM public.unidade_perfil up
                   WHERE up.perfil_id = v_dep.responsavel_perfil_id
                     AND up.unidade_id = v_dep.unidade_id
                     AND up.status = 'ativo'
               ) THEN
                v_is_own_responsible := true;
            ELSE
                RAISE EXCEPTION 'Morador responsável atual com acesso bloqueado, pendente ou sem vínculo ativo com a unidade.';
            END IF;
        END IF;
    END IF;

    IF NOT (v_is_superadmin OR v_is_admin OR v_is_own_responsible) THEN
        RAISE EXCEPTION 'Permissão negada. Apenas síndicos, administradores ou o responsável atual ativo podem transferir o dependente.';
    END IF;

    -- 9. VALIDAR MOTIVO
    v_clean_motivo := trim(COALESCE(p_motivo, ''));
    IF length(v_clean_motivo) < 3 THEN
        RAISE EXCEPTION 'Motivo da troca de responsável inválido. Mínimo de 3 caracteres.';
    END IF;
    IF length(v_clean_motivo) > 300 THEN
        RAISE EXCEPTION 'Motivo da troca de responsável inválido. Máximo de 300 caracteres.';
    END IF;

    -- 10. UPDATE RESTRITO A responsavel_perfil_id E updated_at
    UPDATE public.dependentes
    SET responsavel_perfil_id = p_novo_responsavel_perfil_id,
        updated_at = now()
    WHERE id = p_dependente_id
    RETURNING updated_at INTO v_updated_at;

    -- 11. AUDITORIA OBRIGATÓRIA EM public.perfil_audit_log
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
        'DEPENDENT_RESPONSIBLE_CHANGED',
        v_clean_motivo,
        jsonb_build_object(
            'responsavel_perfil_id', v_dep.responsavel_perfil_id
        ),
        jsonb_build_object(
            'dependente_id', p_dependente_id,
            'unidade_id', v_dep.unidade_id,
            'responsavel_anterior_id', v_dep.responsavel_perfil_id,
            'responsavel_novo_id', p_novo_responsavel_perfil_id,
            'motivo', v_clean_motivo,
            'operador', v_operator_id
        ),
        now()
    );

    -- 12. RETORNO ESTRUTURADO SANITIZADO CANÔNICO
    RETURN jsonb_build_object(
        'id', p_dependente_id,
        'condominio_id', v_dep.condominio_id,
        'unidade_id', v_dep.unidade_id,
        'responsavel_perfil_id', p_novo_responsavel_perfil_id,
        'parentesco', v_dep.parentesco,
        'status', v_dep.status,
        'updated_at', v_updated_at
    );
END;
$$;

-- Permissões de Execução
REVOKE EXECUTE ON FUNCTION public.admin_trocar_responsavel_dependente(UUID, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_trocar_responsavel_dependente(UUID, UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.admin_trocar_responsavel_dependente(UUID, UUID, TEXT) IS 'Transfere a responsabilidade de um dependente ativo para outro morador aprovado e ativo da mesma unidade residencial, com auditoria DEPENDENT_RESPONSIBLE_CHANGED (Gate 3G.2-A Parte 3E.2)';
