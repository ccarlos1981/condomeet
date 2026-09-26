-- ==============================================================================
-- Migration: 20260925203000_create_rpc_admin_inativar_morador.sql
-- Module: Base Cadastral Unificada (Gate 3C.3)
-- Purpose: Canonical transactional RPC for resident/occupancy inactivation
--          guaranteeing ACID atomic updates, multi-tenant guard, concurrency lock,
--          institutional protection, and administrative audit logging.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_inativar_morador(
    p_perfil_id UUID,
    p_vinculo_id UUID,
    p_data_saida TIMESTAMPTZ,
    p_motivo TEXT,
    p_continua_proprietario BOOLEAN DEFAULT false
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
    v_link RECORD;
    v_u_condo_id UUID;
    v_remaining_count INT;
    v_rem_bloco TEXT;
    v_rem_apto TEXT;
    v_is_institutional BOOLEAN;
    v_is_blocked BOOLEAN;
    v_new_profile_status TEXT;
    v_action TEXT;
    v_clean_motivo TEXT;
BEGIN
    -- 1. IDENTIFICAR OPERADOR AUTENTICADO
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. VALIDAÇÃO DO OPERADOR (SÍNDICO / ADMIN DO CONDOMÍNIO)
    SELECT id, condominio_id, papel_sistema, status_aprovacao, bloqueado
    INTO v_op
    FROM public.perfil
    WHERE id = v_operator_id;

    IF v_op.id IS NULL OR v_op.condominio_id IS NULL THEN
        RAISE EXCEPTION 'Operador não cadastrado ou sem condomínio associado.';
    END IF;

    IF v_op.status_aprovacao IS DISTINCT FROM 'aprovado' OR COALESCE(v_op.bloqueado, false) = true THEN
        RAISE EXCEPTION 'Operador com acesso bloqueado ou pendente de aprovação.';
    END IF;

    IF LOWER(COALESCE(v_op.papel_sistema, '')) NOT IN ('admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora') THEN
        RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem inativar moradores.';
    END IF;

    -- 3. PROTEÇÃO CONTRA AUTO-INATIVAÇÃO
    IF p_perfil_id = v_operator_id THEN
        RAISE EXCEPTION 'Operação inválida. Não é permitido inativar o próprio usuário operador.';
    END IF;

    -- 4. VALIDAÇÃO DE ENTRADAS
    v_clean_motivo := TRIM(COALESCE(p_motivo, ''));
    IF v_clean_motivo = '' THEN
        RAISE EXCEPTION 'O motivo da inativação é obrigatório.';
    END IF;

    IF p_data_saida IS NULL THEN
        RAISE EXCEPTION 'A data de saída é obrigatória.';
    END IF;

    -- Tolerância máxima de 5 minutos para relógios de clientes
    IF p_data_saida > (now() + interval '5 minutes') THEN
        RAISE EXCEPTION 'A data de saída não pode ser uma data futura.';
    END IF;

    -- 5. BLOQUEIO DE CONCORRÊNCIA E VALIDAÇÃO DO PERFIL ALVO
    SELECT id, condominio_id, status_aprovacao, bloqueado, papel_sistema, tipo_morador, bloco_txt, apto_txt, nome_completo
    INTO v_target
    FROM public.perfil
    WHERE id = p_perfil_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Morador alvo não encontrado.';
    END IF;

    -- Isolamento Multi-Tenant Estrito
    IF v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    -- 6. BLOQUEIO DE CONCORRÊNCIA E VALIDAÇÃO DO VÍNCULO FÍSICO
    SELECT *
    INTO v_link
    FROM public.unidade_perfil
    WHERE id = p_vinculo_id
    FOR UPDATE;

    IF v_link.id IS NULL THEN
        RAISE EXCEPTION 'Vínculo imobiliário não encontrado.';
    END IF;

    IF v_link.perfil_id IS DISTINCT FROM p_perfil_id THEN
        RAISE EXCEPTION 'O vínculo imobiliário informado não pertence ao morador indicado.';
    END IF;

    -- Validar se a unidade pertence ao mesmo condomínio do operador/morador
    SELECT u.condominio_id
    INTO v_u_condo_id
    FROM public.unidades u
    WHERE u.id = v_link.unidade_id;

    IF v_u_condo_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'A unidade informada pertence a condomínio divergente.';
    END IF;

    IF v_link.status IS DISTINCT FROM 'ativo' THEN
        RAISE EXCEPTION 'O vínculo imobiliário informado já se encontra inativo.';
    END IF;

    IF p_data_saida < v_link.data_entrada THEN
        RAISE EXCEPTION 'A data de saída não pode ser anterior à data de entrada no imóvel.';
    END IF;

    -- 7. RAMIFICAÇÃO A: PROPRIETÁRIO QUE CONTINUA PROPRIETÁRIO (NÃO-RESIDENTE)
    IF COALESCE(p_continua_proprietario, false) = true THEN
        IF v_target.tipo_morador NOT ILIKE '%propriet%' THEN
            RAISE EXCEPTION 'A opção de manter propriedade só é válida para cadastros classificados como Proprietário.';
        END IF;

        v_action := 'RESIDENT_TYPE_CHANGED';
        v_new_profile_status := v_target.status_aprovacao;

        -- Atualiza tipo_morador para canônico existente no banco
        UPDATE public.perfil
        SET tipo_morador = 'Proprietário não morador',
            updated_at = now()
        WHERE id = p_perfil_id;

        -- Registra log de auditoria
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
            v_op.condominio_id,
            p_perfil_id,
            v_operator_id,
            v_link.unidade_id,
            v_action,
            v_clean_motivo,
            jsonb_build_object(
                'status_aprovacao', v_target.status_aprovacao,
                'bloqueado', v_target.bloqueado,
                'tipo_morador', v_target.tipo_morador,
                'link_status', v_link.status
            ),
            jsonb_build_object(
                'status_aprovacao', v_target.status_aprovacao,
                'bloqueado', v_target.bloqueado,
                'tipo_morador', 'Proprietário não morador',
                'link_status', 'ativo'
            ),
            now()
        );

        RETURN jsonb_build_object(
            'success', true,
            'action', v_action,
            'profile_id', p_perfil_id,
            'link_id', p_vinculo_id,
            'profile_status', v_target.status_aprovacao,
            'link_status', 'ativo',
            'resident_type', 'Proprietário não morador',
            'has_other_active_link', true,
            'message', 'Perfil atualizado para Proprietário não morador. Vínculo ativo preservado.'
        );
    END IF;

    -- 8. RAMIFICAÇÃO B: INATIVAÇÃO REGULAR DE VÍNCULO IMOBILIÁRIO
    v_action := 'UNIT_INACTIVATED';

    -- Inativar vínculo físico
    UPDATE public.unidade_perfil
    SET status = 'inativo',
        data_saida = p_data_saida
    WHERE id = p_vinculo_id;

    -- Contabilizar vínculos ativos remanescentes
    SELECT COUNT(*) INTO v_remaining_count
    FROM public.unidade_perfil
    WHERE perfil_id = p_perfil_id
      AND status = 'ativo';

    IF v_remaining_count > 1 THEN
        -- Proteção: Mais de uma unidade remanescente sem definição de unidade primária
        RAISE EXCEPTION 'O morador possui mais de um vínculo ativo remanescente. Não é possível determinar a unidade principal automaticamente.';
    ELSIF v_remaining_count = 1 THEN
        -- Morador ainda possui exatamente UMA outra unidade ativa:
        -- Mantém acesso intacto e sincroniza bloco_txt/apto_txt com a unidade remanescente
        SELECT b.nome_ou_numero, a.numero
        INTO v_rem_bloco, v_rem_apto
        FROM public.unidade_perfil up
        JOIN public.unidades u ON u.id = up.unidade_id
        LEFT JOIN public.blocos b ON b.id = u.bloco_id
        LEFT JOIN public.apartamentos a ON a.id = u.apartamento_id
        WHERE up.perfil_id = p_perfil_id AND up.status = 'ativo'
        LIMIT 1;

        UPDATE public.perfil
        SET bloco_txt = v_rem_bloco,
            apto_txt = v_rem_apto,
            updated_at = now()
        WHERE id = p_perfil_id;

        v_new_profile_status := v_target.status_aprovacao;
    ELSE
        -- ÚLTIMO VÍNCULO RESIDENCIAL ENCERRADO (v_remaining_count = 0)
        v_is_institutional := LOWER(COALESCE(v_target.papel_sistema, '')) IN (
            'admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora'
        );
        v_is_blocked := (v_target.status_aprovacao = 'bloqueado' OR COALESCE(v_target.bloqueado, false) = true);

        IF v_is_blocked THEN
            -- Preserva sanção administrativa disciplinar intacta
            UPDATE public.perfil
            SET bloco_txt = NULL,
                apto_txt = NULL,
                updated_at = now()
            WHERE id = p_perfil_id;
            v_new_profile_status := 'bloqueado';
        ELSIF v_is_institutional THEN
            -- Preserva privilégios administrativos institucionais
            UPDATE public.perfil
            SET bloco_txt = NULL,
                apto_txt = NULL,
                updated_at = now()
            WHERE id = p_perfil_id;
            v_new_profile_status := v_target.status_aprovacao;
        ELSE
            -- Morador comum, inquilino ou dependente sem vínculo ativo:
            -- Transição canônica para status_aprovacao = 'inativo' e limpeza de endereço
            UPDATE public.perfil
            SET status_aprovacao = 'inativo',
                bloqueado = false,
                bloco_txt = NULL,
                apto_txt = NULL,
                updated_at = now()
            WHERE id = p_perfil_id;
            v_new_profile_status := 'inativo';
        END IF;
    END IF;

    -- 9. REGISTRO ATÔMICO DE AUDITORIA
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
        v_op.condominio_id,
        p_perfil_id,
        v_operator_id,
        v_link.unidade_id,
        v_action,
        v_clean_motivo,
        jsonb_build_object(
            'status_aprovacao', v_target.status_aprovacao,
            'bloqueado', v_target.bloqueado,
            'bloco_txt', v_target.bloco_txt,
            'apto_txt', v_target.apto_txt,
            'tipo_morador', v_target.tipo_morador,
            'link_status', v_link.status,
            'link_data_entrada', v_link.data_entrada,
            'link_data_saida', v_link.data_saida
        ),
        jsonb_build_object(
            'status_aprovacao', v_new_profile_status,
            'bloqueado', CASE WHEN v_is_blocked THEN true ELSE false END,
            'bloco_txt', CASE WHEN v_remaining_count = 1 THEN v_rem_bloco ELSE NULL END,
            'apto_txt', CASE WHEN v_remaining_count = 1 THEN v_rem_apto ELSE NULL END,
            'tipo_morador', v_target.tipo_morador,
            'link_status', 'inativo',
            'link_data_entrada', v_link.data_entrada,
            'link_data_saida', p_data_saida
        ),
        now()
    );

    -- 10. RETORNO ESTRUTURADO SANITIZADO
    RETURN jsonb_build_object(
        'success', true,
        'action', v_action,
        'profile_id', p_perfil_id,
        'link_id', p_vinculo_id,
        'profile_status', v_new_profile_status,
        'link_status', 'inativo',
        'has_other_active_link', (v_remaining_count > 0),
        'message', 'Vínculo inativado com sucesso.'
    );
END;
$$;

-- Restrição de privilégios de execução
REVOKE ALL ON FUNCTION public.admin_inativar_morador(UUID, UUID, TIMESTAMPTZ, TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_inativar_morador(UUID, UUID, TIMESTAMPTZ, TEXT, BOOLEAN) TO authenticated, service_role;
