-- ==============================================================================
-- Migration: 20260925233000_create_veiculos_canonical_foundation.sql
-- Module: Base Cadastral Unificada — Gate 3D.2-A
-- Purpose: Canonical Vehicle Foundation (public.veiculos)
--          - Strong multi-tenant isolation and tenant guard trigger
--          - Partial unique index for active plate per condominium
--          - Plate normalization and Brazilian traditional/Mercosul validation
--          - Administrative RLS and security definer RPCs
--          - Audit logging in public.perfil_audit_log
-- ==============================================================================

-- 1. TABELA CANÔNICA DE VEÍCULOS
CREATE TABLE IF NOT EXISTS public.veiculos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE RESTRICT,
    unidade_id UUID NOT NULL REFERENCES public.unidades(id) ON DELETE RESTRICT,
    perfil_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE RESTRICT,
    placa TEXT NOT NULL,
    tipo TEXT NOT NULL DEFAULT 'carro' CHECK (tipo IN ('carro', 'moto', 'utilitario', 'outro')),
    marca TEXT NOT NULL,
    modelo TEXT NOT NULL,
    cor TEXT NOT NULL,
    ano INTEGER NULL,
    observacao TEXT NULL,
    vaga_numero TEXT NULL,
    status TEXT NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo', 'inativo')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. ÍNDICES DE PERFORMANCE E INTEGRIDADE
CREATE INDEX IF NOT EXISTS idx_veiculos_condominio_id ON public.veiculos(condominio_id);
CREATE INDEX IF NOT EXISTS idx_veiculos_unidade_id ON public.veiculos(unidade_id);
CREATE INDEX IF NOT EXISTS idx_veiculos_perfil_id ON public.veiculos(perfil_id);
CREATE INDEX IF NOT EXISTS idx_veiculos_busca_placa ON public.veiculos(condominio_id, placa);

-- Regra de Unicidade: Exatamente UMA placa ATIVA por condomínio
CREATE UNIQUE INDEX IF NOT EXISTS idx_veiculos_condominio_placa_ativa 
ON public.veiculos (condominio_id, placa) 
WHERE status = 'ativo';

-- 3. TRIGGER GUARD DE INTEGRIDADE MULTI-TENANT E NORMALIZAÇÃO DE PLACA
CREATE OR REPLACE FUNCTION public.tr_fn_veiculos_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_placa TEXT;
    v_p_condo UUID;
    v_u_condo UUID;
BEGIN
    -- 3.1 Normalização estrita da placa (remover caracteres especiais, uppercase)
    v_clean_placa := UPPER(REGEXP_REPLACE(COALESCE(NEW.placa, ''), '[^A-Za-z0-9]', '', 'g'));
    
    -- 3.2 Validação estrita do padrão de placas brasileiras:
    -- Tradicional: 3 letras + 4 dígitos (ex: ABC1234)
    -- Mercosul: 3 letras + 1 dígito + 1 letra + 2 dígitos (ex: ABC1D23)
    IF NOT (v_clean_placa ~ '^[A-Z]{3}[0-9]{4}$' OR v_clean_placa ~ '^[A-Z]{3}[0-9][A-Z][0-9]{2}$') THEN
        RAISE EXCEPTION 'Placa veicular inválida (%). O formato deve ser o padrão brasileiro tradicional (ex: ABC1234) ou Mercosul (ex: ABC1D23).', NEW.placa;
    END IF;
    NEW.placa := v_clean_placa;

    -- 3.3 Validação de strings textuais obrigatórias
    IF TRIM(COALESCE(NEW.marca, '')) = '' THEN
        RAISE EXCEPTION 'A marca do veículo é obrigatória.';
    END IF;
    NEW.marca := TRIM(NEW.marca);

    IF TRIM(COALESCE(NEW.modelo, '')) = '' THEN
        RAISE EXCEPTION 'O modelo do veículo é obrigatório.';
    END IF;
    NEW.modelo := TRIM(NEW.modelo);

    IF TRIM(COALESCE(NEW.cor, '')) = '' THEN
        RAISE EXCEPTION 'A cor do veículo é obrigatória.';
    END IF;
    NEW.cor := TRIM(NEW.cor);

    IF NEW.ano IS NOT NULL AND (NEW.ano < 1900 OR NEW.ano > EXTRACT(YEAR FROM now()) + 2) THEN
        RAISE EXCEPTION 'Ano do veículo inválido (%). Deve situar-se entre 1900 e o próximo ano civil.', NEW.ano;
    END IF;

    -- 3.4 Proteção de Integridade Multi-Tenant (Tenant Guard)
    SELECT condominio_id INTO v_p_condo FROM public.perfil WHERE id = NEW.perfil_id;
    IF v_p_condo IS NULL THEN
        RAISE EXCEPTION 'Perfil associado não encontrado.';
    END IF;
    IF v_p_condo IS DISTINCT FROM NEW.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador indicado pertence a condomínio divergente.';
    END IF;

    SELECT condominio_id INTO v_u_condo FROM public.unidades WHERE id = NEW.unidade_id;
    IF v_u_condo IS NULL THEN
        RAISE EXCEPTION 'Unidade associada não encontrada.';
    END IF;
    IF v_u_condo IS DISTINCT FROM NEW.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. A unidade indicada pertence a condomínio divergente.';
    END IF;

    -- 3.5 Atualização de timestamp
    NEW.updated_at := timezone('utc'::text, now());

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_veiculos_guard ON public.veiculos;
CREATE TRIGGER tr_veiculos_guard
BEFORE INSERT OR UPDATE ON public.veiculos
FOR EACH ROW
EXECUTE FUNCTION public.tr_fn_veiculos_guard();

-- 4. HABILITAÇÃO DE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.veiculos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS veiculos_admin_select ON public.veiculos;
CREATE POLICY veiculos_admin_select ON public.veiculos
FOR SELECT TO authenticated
USING (
    condominio_id IN (
        SELECT p.condominio_id 
        FROM public.perfil p 
        WHERE p.id = auth.uid() 
          AND LOWER(COALESCE(p.papel_sistema, '')) IN (
              'admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora'
          )
    )
    OR EXISTS (
        SELECT 1 FROM public.system_superadmins ss
        JOIN auth.users u ON lower(u.email) = lower(ss.email)
        WHERE u.id = auth.uid()
    )
);

-- 5. OPERAÇÕES ADMINISTRATIVAS (RPCS CANÔNICAS)

-- 5.1 admin_cadastrar_veiculo
CREATE OR REPLACE FUNCTION public.admin_cadastrar_veiculo(
    p_perfil_id UUID,
    p_unidade_id UUID,
    p_placa TEXT,
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
    v_target_profile RECORD;
    v_target_unit RECORD;
    v_condo_id UUID;
    v_clean_placa TEXT;
    v_veiculo_id UUID;
BEGIN
    -- 1. Autenticação do operador
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. Autorização administrativa (Síndico / Admin / Superadmin)
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem cadastrar veículos.';
            END IF;
        END IF;
    END IF;

    -- 3. Validação dos parâmetros básicos
    IF p_perfil_id IS NULL THEN
        RAISE EXCEPTION 'O morador responsável é obrigatório.';
    END IF;
    IF p_unidade_id IS NULL THEN
        RAISE EXCEPTION 'A unidade residencial é obrigatória.';
    END IF;

    -- 4. Validar perfil e unidade alvo
    SELECT id, condominio_id, status_aprovacao, bloqueado, nome_completo
    INTO v_target_profile
    FROM public.perfil
    WHERE id = p_perfil_id;

    IF v_target_profile.id IS NULL THEN
        RAISE EXCEPTION 'Morador alvo não encontrado.';
    END IF;

    v_condo_id := v_target_profile.condominio_id;

    -- Isolamento Multi-Tenant do operador
    IF v_op.condominio_id IS NOT NULL AND v_condo_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    SELECT id, condominio_id
    INTO v_target_unit
    FROM public.unidades
    WHERE id = p_unidade_id;

    IF v_target_unit.id IS NULL THEN
        RAISE EXCEPTION 'Unidade residencial não encontrada.';
    END IF;

    IF v_target_unit.condominio_id IS DISTINCT FROM v_condo_id THEN
        RAISE EXCEPTION 'A unidade selecionada pertence a condomínio divergente do morador.';
    END IF;

    -- 5. Normalizar e validar placa
    v_clean_placa := UPPER(REGEXP_REPLACE(COALESCE(p_placa, ''), '[^A-Za-z0-9]', '', 'g'));
    IF NOT (v_clean_placa ~ '^[A-Z]{3}[0-9]{4}$' OR v_clean_placa ~ '^[A-Z]{3}[0-9][A-Z][0-9]{2}$') THEN
        RAISE EXCEPTION 'Placa veicular inválida (%). Padrões aceitos: ABC1234 ou ABC1D23.', p_placa;
    END IF;

    -- 6. Checagem de colisão de placa ativa no mesmo condomínio
    IF EXISTS (
        SELECT 1 FROM public.veiculos
        WHERE condominio_id = v_condo_id
          AND placa = v_clean_placa
          AND status = 'ativo'
    ) THEN
        RAISE EXCEPTION 'Já existe um veículo ativo com a placa % cadastrado neste condomínio.', v_clean_placa;
    END IF;

    -- 7. Inserção do veículo
    INSERT INTO public.veiculos (
        condominio_id,
        unidade_id,
        perfil_id,
        placa,
        tipo,
        marca,
        modelo,
        cor,
        ano,
        observacao,
        vaga_numero,
        status
    ) VALUES (
        v_condo_id,
        p_unidade_id,
        p_perfil_id,
        v_clean_placa,
        LOWER(TRIM(p_tipo)),
        TRIM(p_marca),
        TRIM(p_modelo),
        TRIM(p_cor),
        p_ano,
        NULLIF(TRIM(p_observacao), ''),
        NULLIF(TRIM(p_vaga_numero), ''),
        'ativo'
    ) RETURNING id INTO v_veiculo_id;

    -- 8. Auditoria obrigatória em perfil_audit_log
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
        v_condo_id,
        p_perfil_id,
        v_operator_id,
        p_unidade_id,
        'VEHICLE_CREATED',
        p_observacao,
        '{}'::jsonb,
        jsonb_build_object(
            'veiculo_id', v_veiculo_id,
            'placa', v_clean_placa,
            'tipo', LOWER(TRIM(p_tipo)),
            'marca', TRIM(p_marca),
            'modelo', TRIM(p_modelo),
            'cor', TRIM(p_cor),
            'ano', p_ano,
            'vaga_numero', NULLIF(TRIM(p_vaga_numero), ''),
            'status', 'ativo'
        ),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'veiculo_id', v_veiculo_id,
        'placa', v_clean_placa,
        'message', 'Veículo cadastrado com sucesso.'
    );
END;
$$;

-- 5.2 admin_atualizar_veiculo (Preserva identidade da placa)
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
        p_observacao,
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

-- 5.3 admin_corrigir_placa_veiculo (Correção controlada de erro material de digitação)
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
        'message', 'Placa retificada com sucesso.'
    );
END;
$$;

-- 5.4 admin_inativar_veiculo
CREATE OR REPLACE FUNCTION public.admin_inativar_veiculo(
    p_veiculo_id UUID,
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem inativar veículos.';
            END IF;
        END IF;
    END IF;

    IF TRIM(COALESCE(p_motivo, '')) = '' THEN
        RAISE EXCEPTION 'O motivo da inativação do veículo é obrigatório para auditoria.';
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

    IF v_target.status = 'inativo' THEN
        RAISE EXCEPTION 'O veículo informado já se encontra inativo.';
    END IF;

    UPDATE public.veiculos
    SET status = 'inativo',
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
        'VEHICLE_INACTIVATED',
        TRIM(p_motivo),
        jsonb_build_object('veiculo_id', v_target.id, 'placa', v_target.placa, 'status', 'ativo'),
        jsonb_build_object('veiculo_id', v_target.id, 'placa', v_target.placa, 'status', 'inativo'),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'veiculo_id', v_target.id,
        'placa', v_target.placa,
        'status', 'inativo',
        'message', 'Veículo inativado com sucesso.'
    );
END;
$$;

-- 5.5 admin_reativar_veiculo
CREATE OR REPLACE FUNCTION public.admin_reativar_veiculo(
    p_veiculo_id UUID,
    p_motivo TEXT DEFAULT NULL
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem reativar veículos.';
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

    IF v_target.status = 'ativo' THEN
        RAISE EXCEPTION 'O veículo informado já se encontra ativo.';
    END IF;

    -- Verificar colisão de placa ativa
    IF EXISTS (
        SELECT 1 FROM public.veiculos
        WHERE condominio_id = v_target.condominio_id
          AND placa = v_target.placa
          AND status = 'ativo'
          AND id <> v_target.id
    ) THEN
        RAISE EXCEPTION 'Não é possível reativar. Já existe outro veículo ativo com a placa % neste condomínio.', v_target.placa;
    END IF;

    UPDATE public.veiculos
    SET status = 'ativo',
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
        'VEHICLE_REACTIVATED',
        TRIM(COALESCE(p_motivo, 'Reativação de veículo cadastrado')),
        jsonb_build_object('veiculo_id', v_target.id, 'placa', v_target.placa, 'status', 'inativo'),
        jsonb_build_object('veiculo_id', v_target.id, 'placa', v_target.placa, 'status', 'ativo'),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'veiculo_id', v_target.id,
        'placa', v_target.placa,
        'status', 'ativo',
        'message', 'Veículo reativado com sucesso.'
    );
END;
$$;
