-- ==============================================================================
-- Migration: 20260926190000_gate_3p_link_correction_and_transfer_rpcs.sql
-- Module: Base Cadastral Unificada — Gate 3P (P2 Final)
-- Scope:
--   1. public.admin_corrigir_datas_vinculo_morador (P2-A Retificação de datas de vínculo)
--   2. public.admin_transferir_unidade_morador (P2-B Transferência de unidade)
-- Purpose:
--   - Execução 100% atômica no banco de dados
--   - Auditoria compulsória em public.perfil_audit_log (UNIT_LINK_ENTRY_DATE_CORRECTED, UNIT_LINK_EXIT_DATE_CORRECTED, UNIT_LINK_DATES_CORRECTED, UNIT_TRANSFERRED)
--   - Limite canônico de capacidade (4 pessoas/unidade via fn_contar_ocupantes_unidade)
--   - Isolamento multi-tenant estrito derivado de public.unidades(condominio_id)
--   - Preservação da máquina de estados cadastral (perfil permanece ativo)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. RPC: public.admin_corrigir_datas_vinculo_morador (P2-A)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_corrigir_datas_vinculo_morador(
    p_vinculo_id UUID,
    p_data_entrada TIMESTAMPTZ,
    p_data_saida TIMESTAMPTZ DEFAULT NULL,
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
    v_link RECORD;
    v_target RECORD;
    v_unit RECORD;
    v_clean_motivo TEXT;
    v_entrada_changed BOOLEAN;
    v_saida_changed BOOLEAN;
    v_acao_audit TEXT;
BEGIN
    -- 1. Identificar operador autenticado
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. Verificar privilégio SuperAdmin (ADR-002)
    v_is_superadmin := EXISTS (
        SELECT 1
        FROM public.system_superadmins ss
        WHERE lower(ss.email) = lower(COALESCE((auth.jwt() ->> 'email'), ''))
    );

    -- 3. Validar operador local do condomínio (se não for SuperAdmin)
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
            RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem retificar vínculos de moradores.';
        END IF;
    END IF;

    -- 4. Validar parâmetros
    IF p_vinculo_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do vínculo é obrigatório.';
    END IF;

    IF p_data_entrada IS NULL THEN
        RAISE EXCEPTION 'A data de entrada é obrigatória.';
    END IF;

    v_clean_motivo := trim(COALESCE(p_motivo, ''));
    IF length(v_clean_motivo) < 3 THEN
        RAISE EXCEPTION 'O motivo da retificação é obrigatório (mínimo de 3 caracteres).';
    END IF;

    -- 5. Localizar e travar vínculo imobiliário
    SELECT *
    INTO v_link
    FROM public.unidade_perfil
    WHERE id = p_vinculo_id
    FOR UPDATE;

    IF v_link.id IS NULL THEN
        RAISE EXCEPTION 'Vínculo imobiliário não encontrado.';
    END IF;

    -- 6. Localizar perfil alvo
    SELECT id, condominio_id, status_aprovacao, bloqueado, nome_completo
    INTO v_target
    FROM public.perfil
    WHERE id = v_link.perfil_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Morador associado ao vínculo não encontrado.';
    END IF;

    -- 7. Localizar unidade
    SELECT u.id, u.condominio_id, b.nome_ou_numero as bloco_nome, a.numero as apto_numero
    INTO v_unit
    FROM public.unidades u
    JOIN public.blocos b ON b.id = u.bloco_id
    JOIN public.apartamentos a ON a.id = u.apartamento_id
    WHERE u.id = v_link.unidade_id;

    IF v_unit.id IS NULL THEN
        RAISE EXCEPTION 'Unidade residencial associada não encontrada.';
    END IF;

    -- 8. Isolamento multi-tenant estrito
    IF NOT v_is_superadmin THEN
        IF v_target.condominio_id IS DISTINCT FROM v_op.condominio_id OR
           v_unit.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
            RAISE EXCEPTION 'Violação multi-tenant. O vínculo pertence a outro condomínio.';
        END IF;
    END IF;

    IF v_unit.condominio_id IS DISTINCT FROM v_target.condominio_id THEN
        RAISE EXCEPTION 'Inconsistência de condomínio entre o morador e a unidade residencial.';
    END IF;

    -- 9. Validações temporais e de integridade
    IF p_data_saida IS NOT NULL AND p_data_entrada > p_data_saida THEN
        RAISE EXCEPTION 'A data de entrada não pode ser posterior à data de saída.';
    END IF;

    IF v_link.status = 'inativo' AND p_data_saida IS NULL THEN
        RAISE EXCEPTION 'Para vínculos inativos (histórico encerrado), a data de saída é obrigatória.';
    END IF;

    IF v_link.status = 'ativo' AND p_data_saida IS NOT NULL THEN
        RAISE EXCEPTION 'Vínculos ativos não devem possuir data de saída. Para encerrar o vínculo, utilize a inativação ou transferência.';
    END IF;

    -- Verificar se cria sobreposição com outro vínculo da MESMA unidade para este mesmo morador
    IF EXISTS (
        SELECT 1
        FROM public.unidade_perfil up
        WHERE up.perfil_id = v_link.perfil_id
          AND up.id <> v_link.id
          AND up.unidade_id = v_link.unidade_id
          AND (
            (up.data_saida IS NOT NULL AND (
                (p_data_saida IS NOT NULL AND p_data_entrada <= up.data_saida AND p_data_saida >= up.data_entrada)
                OR (p_data_saida IS NULL AND p_data_entrada <= up.data_saida)
            ))
            OR (up.data_saida IS NULL AND (
                (p_data_saida IS NOT NULL AND p_data_saida >= up.data_entrada)
                OR (p_data_saida IS NULL)
            ))
          )
    ) THEN
        RAISE EXCEPTION 'A retificação de datas cria sobreposição temporal com outro período registrado para esta mesma unidade.';
    END IF;

    -- 10. Identificar o que mudou
    v_entrada_changed := (v_link.data_entrada IS DISTINCT FROM p_data_entrada);
    v_saida_changed := (v_link.data_saida IS DISTINCT FROM p_data_saida);

    IF NOT v_entrada_changed AND NOT v_saida_changed THEN
        RAISE EXCEPTION 'Nenhuma alteração de data foi detectada.';
    END IF;

    IF v_entrada_changed AND NOT v_saida_changed THEN
        v_acao_audit := 'UNIT_LINK_ENTRY_DATE_CORRECTED';
    ELSIF v_saida_changed AND NOT v_entrada_changed THEN
        v_acao_audit := 'UNIT_LINK_EXIT_DATE_CORRECTED';
    ELSE
        v_acao_audit := 'UNIT_LINK_DATES_CORRECTED';
    END IF;

    -- 11. Atualizar vínculo
    UPDATE public.unidade_perfil
    SET data_entrada = p_data_entrada,
        data_saida = p_data_saida
    WHERE id = p_vinculo_id;

    -- 12. Gravar auditoria compulsória
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
        v_unit.condominio_id,
        v_link.perfil_id,
        v_operator_id,
        v_link.unidade_id,
        v_acao_audit,
        v_clean_motivo,
        jsonb_build_object(
            'vinculo_id', p_vinculo_id,
            'bloco_txt', v_unit.bloco_nome,
            'apto_txt', v_unit.apto_numero,
            'status', v_link.status,
            'data_entrada', v_link.data_entrada,
            'data_saida', v_link.data_saida
        ),
        jsonb_build_object(
            'vinculo_id', p_vinculo_id,
            'bloco_txt', v_unit.bloco_nome,
            'apto_txt', v_unit.apto_numero,
            'status', v_link.status,
            'data_entrada', p_data_entrada,
            'data_saida', p_data_saida
        ),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'vinculo_id', p_vinculo_id,
        'perfil_id', v_link.perfil_id,
        'data_entrada', p_data_entrada,
        'data_saida', p_data_saida,
        'acao_audit', v_acao_audit
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. RPC: public.admin_transferir_unidade_morador (P2-B)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_transferir_unidade_morador(
    p_perfil_id UUID,
    p_nova_unidade_id UUID,
    p_data_transferencia TIMESTAMPTZ DEFAULT NULL,
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
    v_source_link RECORD;
    v_source_unit RECORD;
    v_dest_unit RECORD;
    v_clean_motivo TEXT;
    v_transfer_date TIMESTAMPTZ;
    v_dest_occupants INTEGER;
    v_new_link_id UUID;
BEGIN
    -- 1. Identificar operador autenticado
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. Verificar privilégio SuperAdmin (ADR-002)
    v_is_superadmin := EXISTS (
        SELECT 1
        FROM public.system_superadmins ss
        WHERE lower(ss.email) = lower(COALESCE((auth.jwt() ->> 'email'), ''))
    );

    -- 3. Validar operador local do condomínio (se não for SuperAdmin)
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
            RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem transferir unidades de moradores.';
        END IF;
    END IF;

    -- 4. Validar parâmetros básicos
    IF p_perfil_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do morador é obrigatório.';
    END IF;

    IF p_nova_unidade_id IS NULL THEN
        RAISE EXCEPTION 'A unidade residencial de destino é obrigatória.';
    END IF;

    v_clean_motivo := trim(COALESCE(p_motivo, ''));
    IF length(v_clean_motivo) < 3 THEN
        RAISE EXCEPTION 'O motivo da transferência é obrigatório (mínimo de 3 caracteres).';
    END IF;

    v_transfer_date := COALESCE(p_data_transferencia, now());

    -- 5. Localizar e travar morador alvo
    SELECT id, condominio_id, status_aprovacao, bloqueado, nome_completo, bloco_txt, apto_txt, tipo_morador
    INTO v_target
    FROM public.perfil
    WHERE id = p_perfil_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Morador alvo não encontrado.';
    END IF;

    -- Isolamento multi-tenant do morador
    IF NOT v_is_superadmin AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    IF v_target.status_aprovacao IS DISTINCT FROM 'aprovado' OR COALESCE(v_target.bloqueado, false) = true THEN
        RAISE EXCEPTION 'Apenas moradores com cadastro aprovado e sem bloqueio ativo podem ser transferidos.';
    END IF;

    -- 6. Validar e travar vínculo residencial ativo de origem
    SELECT *
    INTO v_source_link
    FROM public.unidade_perfil
    WHERE perfil_id = p_perfil_id
      AND status = 'ativo'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF v_source_link.id IS NULL THEN
        RAISE EXCEPTION 'O morador não possui um vínculo residencial ativo para transferência.';
    END IF;

    -- 7. Validar unidade residencial de origem
    SELECT u.id, u.condominio_id, b.nome_ou_numero as bloco_nome, a.numero as apto_numero
    INTO v_source_unit
    FROM public.unidades u
    JOIN public.blocos b ON b.id = u.bloco_id
    JOIN public.apartamentos a ON a.id = u.apartamento_id
    WHERE u.id = v_source_link.unidade_id;

    -- 8. Validar unidade residencial de destino
    SELECT u.id, u.condominio_id, u.bloqueada, b.nome_ou_numero as bloco_nome, a.numero as apto_numero
    INTO v_dest_unit
    FROM public.unidades u
    JOIN public.blocos b ON b.id = u.bloco_id
    JOIN public.apartamentos a ON a.id = u.apartamento_id
    WHERE u.id = p_nova_unidade_id;

    IF v_dest_unit.id IS NULL THEN
        RAISE EXCEPTION 'Unidade residencial de destino não encontrada.';
    END IF;

    IF v_dest_unit.condominio_id IS DISTINCT FROM v_target.condominio_id THEN
        RAISE EXCEPTION 'A unidade de destino pertence a um condomínio diferente do morador.';
    END IF;

    IF v_dest_unit.id = v_source_unit.id THEN
        RAISE EXCEPTION 'A unidade de destino deve ser diferente da unidade atual.';
    END IF;

    IF COALESCE(v_dest_unit.bloqueada, false) = true THEN
        RAISE EXCEPTION 'A unidade de destino está bloqueada por restrição administrativa.';
    END IF;

    -- 9. Validar capacidade máxima da unidade de destino (limite de 4 pessoas)
    v_dest_occupants := public.fn_contar_ocupantes_unidade(p_nova_unidade_id);
    IF v_dest_occupants >= 4 THEN
        RAISE EXCEPTION 'A unidade de destino atingiu o limite máximo de 4 ocupantes (%/4 pessoas).', v_dest_occupants;
    END IF;

    -- 10. Validações temporais da transferência
    IF v_source_link.data_entrada IS NOT NULL AND v_source_link.data_entrada > v_transfer_date THEN
        RAISE EXCEPTION 'A data de transferência não pode ser anterior à data de entrada no imóvel atual (%).',
            to_char(v_source_link.data_entrada, 'DD/MM/YYYY');
    END IF;

    -- Se já morou no destino anteriormente, a nova data deve ser posterior à saída anterior
    IF EXISTS (
        SELECT 1
        FROM public.unidade_perfil
        WHERE perfil_id = p_perfil_id
          AND unidade_id = p_nova_unidade_id
          AND data_saida IS NOT NULL
          AND data_saida >= v_transfer_date
    ) THEN
        RAISE EXCEPTION 'Para a unidade de destino, a data da nova transferência deve ser posterior à última data de saída registrada.';
    END IF;

    -- 11. Atomicidade: Encerrar vínculo de origem
    UPDATE public.unidade_perfil
    SET status = 'inativo',
        data_saida = v_transfer_date
    WHERE id = v_source_link.id;

    -- 12. Atomicidade: Criar novo vínculo de destino
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
        p_nova_unidade_id,
        'ativo',
        v_transfer_date,
        NULL,
        now()
    );

    -- 13. Atomicidade: Atualizar perfil com novos bloco_txt e apto_txt (preserva status ativo)
    UPDATE public.perfil
    SET bloco_txt = v_dest_unit.bloco_nome,
        apto_txt = v_dest_unit.apto_numero,
        updated_at = now()
    WHERE id = p_perfil_id;

    -- 14. Opcional/Consistência: Sincronizar unidade_id dos veículos e pets ativos para o novo endereço
    UPDATE public.veiculos
    SET unidade_id = p_nova_unidade_id,
        updated_at = now()
    WHERE perfil_id = p_perfil_id
      AND status = 'ativo';

    UPDATE public.pets
    SET unidade_id = p_nova_unidade_id,
        updated_at = now()
    WHERE perfil_id = p_perfil_id
      AND status = 'ativo';

    -- 15. Auditoria compulsória em perfil_audit_log
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
        p_nova_unidade_id,
        'UNIT_TRANSFERRED',
        v_clean_motivo,
        jsonb_build_object(
            'vinculo_origem_id', v_source_link.id,
            'unidade_origem_id', v_source_unit.id,
            'bloco_origem', v_source_unit.bloco_nome,
            'apto_origem', v_source_unit.apto_numero,
            'data_entrada_origem', v_source_link.data_entrada
        ),
        jsonb_build_object(
            'vinculo_destino_id', v_new_link_id,
            'unidade_destino_id', v_dest_unit.id,
            'bloco_destino', v_dest_unit.bloco_nome,
            'apto_destino', v_dest_unit.apto_numero,
            'data_transferencia', v_transfer_date
        ),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'perfil_id', p_perfil_id,
        'vinculo_origem_id', v_source_link.id,
        'vinculo_destino_id', v_new_link_id,
        'nova_unidade_id', p_nova_unidade_id,
        'bloco_destino', v_dest_unit.bloco_nome,
        'apto_destino', v_dest_unit.apto_numero,
        'data_transferencia', v_transfer_date
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. Permissões de Execução (authenticated only)
-- ------------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.admin_corrigir_datas_vinculo_morador(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_corrigir_datas_vinculo_morador(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_transferir_unidade_morador(UUID, UUID, TIMESTAMPTZ, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_transferir_unidade_morador(UUID, UUID, TIMESTAMPTZ, TEXT) TO authenticated;

COMMENT ON FUNCTION public.admin_corrigir_datas_vinculo_morador(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
IS 'Retificação material atômica de datas de vínculo residencial com auditoria compulsória (Gate 3P / P2-A)';

COMMENT ON FUNCTION public.admin_transferir_unidade_morador(UUID, UUID, TIMESTAMPTZ, TEXT)
IS 'Transferência atômica de unidade residencial com guarda de capacidade 4/4 e auditoria UNIT_TRANSFERRED (Gate 3P / P2-B)';
