-- ============================================================================
-- GATE 3D.2-B.3: HARDENING DE IMUTABILIDADE DE VEÍCULO INATIVO
-- ============================================================================
-- Decisão Canônica Aprovada:
-- VEÍCULO ATIVO: Editar, Corrigir placa, Inativar.
-- VEÍCULO INATIVO: SOMENTE Reativar.
--
-- Princípio:
-- Veículo inativo representa registro histórico encerrado.
-- Dados cadastrais e placa de veículo inativo não podem sofrer mutação
-- até que o veículo seja formalmente reativado.
-- ============================================================================

-- 1. admin_atualizar_veiculo (Hardening contra edição de veículo inativo)
CREATE OR REPLACE FUNCTION public.admin_atualizar_veiculo(
    p_veiculo_id UUID,
    p_tipo TEXT,
    p_marca TEXT,
    p_modelo TEXT,
    p_cor TEXT,
    p_ano INTEGER DEFAULT NULL,
    p_observacao TEXT DEFAULT NULL,
    p_vaga_numero TEXT DEFAULT NULL
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
    v_old_state JSONB;
    v_new_state JSONB;
BEGIN
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    SELECT id, email, condominio_id, papel_sistema, status_aprovacao, bloqueado
    INTO v_op
    FROM public.perfil
    WHERE id = v_operator_id;

    IF v_op.id IS NULL OR v_op.condominio_id IS NULL THEN
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem atualizar veículos.';
            END IF;
        END IF;
    END IF;

    SELECT * INTO v_target
    FROM public.veiculos
    WHERE id = p_veiculo_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Veículo não encontrado.';
    END IF;

    IF v_op.condominio_id IS NOT NULL AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O veículo pertence a outro condomínio.';
    END IF;

    -- Guarda de Imutabilidade: Veículo inativo não pode ser editado
    IF v_target.status = 'inativo' THEN
        RAISE EXCEPTION 'Veículo inativo não pode ser editado. Reative o veículo antes de alterar seus dados.';
    END IF;

    v_old_state := jsonb_build_object(
        'veiculo_id', v_target.id,
        'placa', v_target.placa,
        'tipo', v_target.tipo,
        'marca', v_target.marca,
        'modelo', v_target.modelo,
        'cor', v_target.cor,
        'ano', v_target.ano,
        'observacao', v_target.observacao,
        'vaga_numero', v_target.vaga_numero,
        'status', v_target.status
    );

    UPDATE public.veiculos
    SET tipo = LOWER(TRIM(p_tipo)),
        marca = TRIM(p_marca),
        modelo = TRIM(p_modelo),
        cor = TRIM(p_cor),
        ano = p_ano,
        observacao = NULLIF(TRIM(p_observacao), ''),
        vaga_numero = NULLIF(TRIM(p_vaga_numero), ''),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_veiculo_id;

    v_new_state := jsonb_build_object(
        'veiculo_id', v_target.id,
        'placa', v_target.placa,
        'tipo', LOWER(TRIM(p_tipo)),
        'marca', TRIM(p_marca),
        'modelo', TRIM(p_modelo),
        'cor', TRIM(p_cor),
        'ano', p_ano,
        'observacao', NULLIF(TRIM(p_observacao), ''),
        'vaga_numero', NULLIF(TRIM(p_vaga_numero), ''),
        'status', v_target.status
    );

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
        v_target.perfil_id,
        v_operator_id,
        v_target.unidade_id,
        'VEHICLE_UPDATED',
        COALESCE(NULLIF(TRIM(p_observacao), ''), 'Atualização de cadastro de veículo'),
        v_old_state,
        v_new_state,
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'veiculo_id', v_target.id,
        'message', 'Dados do veículo atualizados com sucesso.'
    );
END;
$$;

-- 2. admin_corrigir_placa_veiculo (Hardening contra retificação de placa em veículo inativo)
CREATE OR REPLACE FUNCTION public.admin_corrigir_placa_veiculo(
    p_veiculo_id UUID,
    p_nova_placa TEXT,
    p_motivo TEXT
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
    v_clean_placa TEXT;
    v_old_placa TEXT;
BEGIN
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    SELECT id, email, condominio_id, papel_sistema, status_aprovacao, bloqueado
    INTO v_op
    FROM public.perfil
    WHERE id = v_operator_id;

    IF v_op.id IS NULL OR v_op.condominio_id IS NULL THEN
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem corrigir placas de veículos.';
            END IF;
        END IF;
    END IF;

    IF TRIM(COALESCE(p_motivo, '')) = '' THEN
        RAISE EXCEPTION 'O motivo da retificação da placa é obrigatório para auditoria.';
    END IF;

    SELECT * INTO v_target
    FROM public.veiculos
    WHERE id = p_veiculo_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Veículo não encontrado.';
    END IF;

    IF v_op.condominio_id IS NOT NULL AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O veículo pertence a outro condomínio.';
    END IF;

    -- Guarda de Imutabilidade: Veículo inativo não pode ter placa corrigida
    IF v_target.status = 'inativo' THEN
        RAISE EXCEPTION 'Veículo inativo não pode ter a placa corrigida. Reative o veículo antes de realizar a correção.';
    END IF;

    v_clean_placa := UPPER(REGEXP_REPLACE(COALESCE(p_nova_placa, ''), '[^A-Za-z0-9]', '', 'g'));
    IF NOT (v_clean_placa ~ '^[A-Z]{3}[0-9]{4}$' OR v_clean_placa ~ '^[A-Z]{3}[0-9][A-Z][0-9]{2}$') THEN
        RAISE EXCEPTION 'Nova placa veicular inválida (%). Padrões aceitos: ABC1234 ou ABC1D23.', p_nova_placa;
    END IF;

    IF v_clean_placa = v_target.placa THEN
        RETURN jsonb_build_object('success', true, 'message', 'A nova placa é idêntica à placa atual. Nenhuma alteração realizada.');
    END IF;

    -- Verificar colisão de placa ativa
    IF v_target.status = 'ativo' AND EXISTS (
        SELECT 1 FROM public.veiculos
        WHERE condominio_id = v_target.condominio_id
          AND placa = v_clean_placa
          AND status = 'ativo'
          AND id <> v_target.id
    ) THEN
        RAISE EXCEPTION 'Já existe outro veículo ativo com a placa % cadastrado neste condomínio.', v_clean_placa;
    END IF;

    v_old_placa := v_target.placa;

    UPDATE public.veiculos
    SET placa = v_clean_placa,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_veiculo_id;

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
        v_target.perfil_id,
        v_operator_id,
        v_target.unidade_id,
        'VEHICLE_PLATE_CORRECTED',
        TRIM(p_motivo),
        jsonb_build_object('veiculo_id', v_target.id, 'placa', v_old_placa),
        jsonb_build_object('veiculo_id', v_target.id, 'placa', v_clean_placa),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'veiculo_id', v_target.id,
        'placa_anterior', v_old_placa,
        'nova_placa', v_clean_placa,
        'message', 'Placa do veículo retificada com sucesso.'
    );
END;
$$;

COMMENT ON FUNCTION public.admin_atualizar_veiculo IS 
'Atualiza dados cadastrais de veículo ativo com auditoria. Rejeita veículos inativos.';

COMMENT ON FUNCTION public.admin_corrigir_placa_veiculo IS 
'Retifica erro de digitação de placa veicular em veículo ativo com auditoria. Rejeita veículos inativos.';
