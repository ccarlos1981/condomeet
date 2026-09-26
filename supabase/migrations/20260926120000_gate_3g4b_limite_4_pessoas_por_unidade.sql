-- ==============================================================================
-- Migration: 20260926120000_gate_3g4b_limite_4_pessoas_por_unidade.sql
-- Module: Base Cadastral 360º — Gate 3G.4-B
-- Scope: Limite canônico de 4 pessoas por unidade residencial
-- Purpose: Helper de contagem + capacity guard em 3 RPCs
-- ==============================================================================

-- ============================================================================
-- PARTE 1: HELPER CANÔNICO DE CONTAGEM
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_contar_ocupantes_unidade(
    p_unidade_id UUID
)
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT (
        COALESCE(
            (SELECT COUNT(DISTINCT up.perfil_id)
             FROM public.unidade_perfil up
             WHERE up.unidade_id = p_unidade_id
               AND up.status = 'ativo'),
            0
        ) + COALESCE(
            (SELECT COUNT(*)
             FROM public.dependentes d
             WHERE d.unidade_id = p_unidade_id
               AND d.status = 'ativo'
               AND d.perfil_convertido_id IS NULL),
            0
        )
    )::INTEGER;
$$;

COMMENT ON FUNCTION public.fn_contar_ocupantes_unidade(UUID)
IS 'Retorna total de ocupantes ativos da unidade (moradores com vínculo ativo + dependentes ativos não-convertidos). Gate 3G.4-B.';

REVOKE EXECUTE ON FUNCTION public.fn_contar_ocupantes_unidade(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_contar_ocupantes_unidade(UUID) TO authenticated, service_role;

-- ============================================================================
-- PARTE 2: admin_cadastrar_dependente COM CAPACITY GUARD
-- ============================================================================

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
    v_ocupacao_atual INTEGER;
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

    -- 6B. LOCK DA UNIDADE + VALIDAÇÃO DE CAPACIDADE (Gate 3G.4-B)
    PERFORM 1 FROM public.unidades WHERE id = p_unidade_id FOR UPDATE;

    v_ocupacao_atual := public.fn_contar_ocupantes_unidade(p_unidade_id);
    IF v_ocupacao_atual >= 4 THEN
        RAISE EXCEPTION 'Limite de 4 pessoas por unidade atingido. A unidade já possui % ocupante(s) ativo(s).', v_ocupacao_atual;
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

COMMENT ON FUNCTION public.admin_cadastrar_dependente(UUID, UUID, TEXT, TEXT, DATE, TEXT) IS 'Cadastra dependente vinculado a morador e unidade com validação de parentesco, dados civis, guard multi-tenant, capacity guard de 4 pessoas/unidade e auditoria DEPENDENT_CREATED (Gate 3G.2-A Parte 3A.1 + Gate 3G.4-B)';

-- ============================================================================
-- PARTE 3: admin_reativar_dependente COM CAPACITY GUARD
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_reativar_dependente(
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
    v_ocupacao_atual INTEGER;
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

    SELECT id, condominio_id, unidade_id, responsavel_perfil_id, nome_completo, parentesco, data_nascimento, status, perfil_convertido_id, foto_path
    INTO v_dep
    FROM public.dependentes
    WHERE id = p_dependente_id;

    IF v_dep.id IS NULL THEN
        RAISE EXCEPTION 'Dependente não encontrado.';
    END IF;

    -- 3. STATUS INATIVO (APENAS INATIVO PODE SER REATIVADO)
    IF v_dep.status IS DISTINCT FROM 'inativo' THEN
        RAISE EXCEPTION 'Operação não permitida. O dependente já se encontra ativo.';
    END IF;

    -- 4. DEPENDENTE CONVERTIDO
    IF v_dep.perfil_convertido_id IS NOT NULL THEN
        RAISE EXCEPTION 'Operação não permitida. Dependentes com perfil próprio vinculado não podem ser reativados por esta rotina.';
    END IF;

    -- 5. VALIDAÇÃO DO RESPONSÁVEL
    SELECT p.id, p.condominio_id, p.status_aprovacao, p.bloqueado
    INTO v_resp
    FROM public.perfil p
    WHERE p.id = v_dep.responsavel_perfil_id;

    IF v_resp.id IS NULL THEN
        RAISE EXCEPTION 'Morador responsável não encontrado.';
    END IF;

    IF v_resp.condominio_id IS DISTINCT FROM v_dep.condominio_id THEN
        RAISE EXCEPTION 'O morador responsável pertence a condomínio divergente.';
    END IF;

    IF v_resp.status_aprovacao IS DISTINCT FROM 'aprovado' OR COALESCE(v_resp.bloqueado, false) = true THEN
        RAISE EXCEPTION 'Morador responsável com acesso bloqueado ou pendente de aprovação.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.unidade_perfil up
        WHERE up.perfil_id = v_dep.responsavel_perfil_id
          AND up.unidade_id = v_dep.unidade_id
          AND up.status = 'ativo'
    ) THEN
        RAISE EXCEPTION 'Vínculo residencial inválido. O responsável não possui vínculo ativo com a unidade do dependente.';
    END IF;

    -- 6. AUTORIZAÇÃO DO OPERADOR (SUPERADMIN, ADMIN DO MESMO CONDOMÍNIO OU PRÓPRIO RESPONSÁVEL)
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
        v_is_own_responsible := true;
    END IF;

    IF NOT (v_is_superadmin OR v_is_admin OR v_is_own_responsible) THEN
        RAISE EXCEPTION 'Permissão negada. Apenas síndicos, administradores ou o próprio responsável podem reativar dependentes.';
    END IF;

    -- 7. VALIDAR MOTIVO
    v_clean_motivo := trim(COALESCE(p_motivo, ''));
    IF length(v_clean_motivo) < 3 THEN
        RAISE EXCEPTION 'Motivo da reativação inválido. Mínimo de 3 caracteres.';
    END IF;
    IF length(v_clean_motivo) > 300 THEN
        RAISE EXCEPTION 'Motivo da reativação inválido. Máximo de 300 caracteres.';
    END IF;

    -- 8. DUPLICIDADE ANTES DA REATIVAÇÃO
    IF EXISTS (
        SELECT 1
        FROM public.dependentes d
        WHERE d.unidade_id = v_dep.unidade_id
          AND lower(trim(d.nome_completo)) = lower(trim(v_dep.nome_completo))
          AND d.data_nascimento = v_dep.data_nascimento
          AND d.status = 'ativo'
          AND d.id <> p_dependente_id
    ) THEN
        RAISE EXCEPTION 'Operação não permitida. Já existe um dependente ativo com o mesmo nome e data de nascimento nesta unidade.';
    END IF;

    -- 8B. LOCK DA UNIDADE + VALIDAÇÃO DE CAPACIDADE (Gate 3G.4-B)
    PERFORM 1 FROM public.unidades WHERE id = v_dep.unidade_id FOR UPDATE;

    v_ocupacao_atual := public.fn_contar_ocupantes_unidade(v_dep.unidade_id);
    IF v_ocupacao_atual >= 4 THEN
        RAISE EXCEPTION 'Limite de 4 pessoas por unidade atingido. A unidade já possui % ocupante(s) ativo(s).', v_ocupacao_atual;
    END IF;

    -- 9. REATIVAÇÃO (CAMPOS PERMITIDOS SOMENTE, PRESERVANDO HISTÓRICO E DADOS ORIGINAIS)
    UPDATE public.dependentes
    SET status = 'ativo',
        updated_at = now()
    WHERE id = p_dependente_id
    RETURNING updated_at INTO v_updated_at;

    -- 10. AUDITORIA OBRIGATÓRIA EM public.perfil_audit_log
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
        'DEPENDENT_REACTIVATED',
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

    -- 11. RETORNO ESTRUTURADO SANITIZADO
    RETURN jsonb_build_object(
        'id', p_dependente_id,
        'condominio_id', v_dep.condominio_id,
        'unidade_id', v_dep.unidade_id,
        'responsavel_perfil_id', v_dep.responsavel_perfil_id,
        'parentesco', v_dep.parentesco,
        'status', 'ativo',
        'updated_at', v_updated_at
    );
END;
$$;

-- Permissões de Execução
REVOKE EXECUTE ON FUNCTION public.admin_reativar_dependente(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_reativar_dependente(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.admin_reativar_dependente(UUID, TEXT) IS 'Reativa dependente inativo com verificação de responsável, unicidade ativa, capacity guard de 4 pessoas/unidade, registro de motivo e auditoria DEPENDENT_REACTIVATED (Gate 3G.2-A Parte 3D.1 + Gate 3G.4-B)';

-- ============================================================================
-- PARTE 4: admin_criar_vinculo_morador COM CAPACITY GUARD
-- ============================================================================

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
    v_ocupacao_atual INTEGER;
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

    -- 8B. LOCK DA UNIDADE DESTINO + VALIDAÇÃO DE CAPACIDADE (Gate 3G.4-B)
    PERFORM 1 FROM public.unidades WHERE id = p_unidade_id FOR UPDATE;

    v_ocupacao_atual := public.fn_contar_ocupantes_unidade(p_unidade_id);
    IF v_ocupacao_atual >= 4 THEN
        RAISE EXCEPTION 'Limite de 4 pessoas por unidade atingido. A unidade já possui % ocupante(s) ativo(s).', v_ocupacao_atual;
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
IS 'Cria um novo período/vínculo residencial ativo com validação temporal estrita, capacity guard de 4 pessoas/unidade e lock de concorrência (Gate 3C.7-B + Gate 3G.4-B).';
