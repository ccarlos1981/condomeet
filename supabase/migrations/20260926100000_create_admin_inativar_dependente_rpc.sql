-- ==============================================================================
-- Migration: 20260926100000_create_admin_inativar_dependente_rpc.sql
-- Module: Base Cadastral 360º — Gate 3G.2-A (Parte 3C.1)
-- Scope: RPC public.admin_inativar_dependente
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_inativar_dependente(
    p_dependente_id UUID,
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
    v_resp RECORD;
    v_is_superadmin BOOLEAN;
    v_is_admin BOOLEAN;
    v_is_own_responsible BOOLEAN := false;
    v_clean_motivo TEXT;
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

    SELECT id, condominio_id, unidade_id, responsavel_perfil_id, status, parentesco, perfil_convertido_id, foto_path
    INTO v_dep
    FROM public.dependentes
    WHERE id = p_dependente_id;

    IF v_dep.id IS NULL THEN
        RAISE EXCEPTION 'Dependente não encontrado.';
    END IF;

    -- 3. STATUS ATIVO (APENAS ATIVO PODE SER INATIVADO)
    IF v_dep.status IS DISTINCT FROM 'ativo' THEN
        RAISE EXCEPTION 'Operação não permitida. O dependente já se encontra inativo.';
    END IF;

    -- 4. DEPENDENTE CONVERTIDO
    IF v_dep.perfil_convertido_id IS NOT NULL THEN
        RAISE EXCEPTION 'Operação não permitida. Dependentes com perfil próprio vinculado não podem ser inativados por esta rotina.';
    END IF;

    -- 5. AUTORIZAÇÃO DO OPERADOR (SUPERADMIN, ADMIN DO MESMO CONDOMÍNIO OU PRÓPRIO RESPONSÁVEL)
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
        RAISE EXCEPTION 'Permissão negada. Apenas síndicos, administradores ou o próprio responsável podem inativar dependentes.';
    END IF;

    -- 6. VALIDAR MOTIVO
    v_clean_motivo := trim(COALESCE(p_motivo, ''));
    IF length(v_clean_motivo) < 3 THEN
        RAISE EXCEPTION 'Motivo da inativação inválido. Mínimo de 3 caracteres.';
    END IF;
    IF length(v_clean_motivo) > 300 THEN
        RAISE EXCEPTION 'Motivo da inativação inválido. Máximo de 300 caracteres.';
    END IF;

    -- 7. INATIVAÇÃO (CAMPOS PERMITIDOS SOMENTE, PRESERVANDO HISTÓRICO E FOTO)
    UPDATE public.dependentes
    SET status = 'inativo',
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
        'DEPENDENT_INACTIVATED',
        v_clean_motivo,
        jsonb_build_object(
            'status', v_dep.status
        ),
        jsonb_build_object(
            'dependente_id', p_dependente_id,
            'unidade_id', v_dep.unidade_id,
            'parentesco', v_dep.parentesco,
            'motivo', v_clean_motivo,
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
        'parentesco', v_dep.parentesco,
        'status', 'inativo',
        'updated_at', v_updated_at
    );
END;
$$;

-- Permissões de Execução
REVOKE EXECUTE ON FUNCTION public.admin_inativar_dependente(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_inativar_dependente(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.admin_inativar_dependente(UUID, TEXT) IS 'Inativa dependente ativo com registro obrigatório de motivo, preservação de histórico, guard multi-tenant e auditoria DEPENDENT_INACTIVATED (Gate 3G.2-A Parte 3C.1)';
