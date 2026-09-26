-- ==============================================================================
-- Migration: 20260926010000_create_pets_canonical_foundation.sql
-- Module: Base Cadastral Unificada — Gate 3E.2-A
-- Purpose: Canonical Pets Foundation (public.pets)
--          - Strong multi-tenant isolation and tenant guard trigger
--          - Relationships: condominio_id, perfil_id (tutor), unidade_id
--          - Domain constraints (especie, sexo, porte, status)
--          - Administrative RLS (SuperAdmin via JWT, Síndico/Admin of same condo)
--          - Security definer RPCs (cadastrar, atualizar, inativar, reativar, transferir)
--          - Strict immutability for inactive pets
--          - Audit logging in public.perfil_audit_log
-- ==============================================================================

-- 1. TABELA CANÔNICA DE PETS
CREATE TABLE IF NOT EXISTS public.pets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE RESTRICT,
    unidade_id UUID NOT NULL REFERENCES public.unidades(id) ON DELETE RESTRICT,
    perfil_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE RESTRICT,
    nome TEXT NOT NULL,
    especie TEXT NOT NULL CHECK (especie IN ('cao', 'gato', 'ave', 'roedor', 'reptil', 'peixe', 'outro')),
    raca TEXT NULL,
    sexo TEXT NULL CHECK (sexo IS NULL OR sexo IN ('macho', 'femea')),
    porte TEXT NULL CHECK (porte IS NULL OR porte IN ('pequeno', 'medio', 'grande', 'nao_se_aplica')),
    cor TEXT NULL,
    data_nascimento DATE NULL,
    castrado BOOLEAN NULL,
    vacinado BOOLEAN NULL,
    observacao TEXT NULL,
    status TEXT NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo', 'inativo')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. ÍNDICES DE PERFORMANCE E INTEGRIDADE
CREATE INDEX IF NOT EXISTS idx_pets_condominio_id ON public.pets(condominio_id);
CREATE INDEX IF NOT EXISTS idx_pets_unidade_id ON public.pets(unidade_id);
CREATE INDEX IF NOT EXISTS idx_pets_perfil_id ON public.pets(perfil_id);
CREATE INDEX IF NOT EXISTS idx_pets_condominio_status ON public.pets(condominio_id, status);

-- 3. TRIGGER GUARD DE INTEGRIDADE MULTI-TENANT E NORMALIZAÇÃO DE CAMPOS
CREATE OR REPLACE FUNCTION public.tr_fn_pets_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_nome TEXT;
    v_p_condo UUID;
    v_u_condo UUID;
BEGIN
    -- 3.1 Normalização e validação de nome obrigatório
    v_clean_nome := TRIM(COALESCE(NEW.nome, ''));
    IF v_clean_nome = '' THEN
        RAISE EXCEPTION 'O nome do pet é obrigatório.';
    END IF;
    NEW.nome := v_clean_nome;

    -- 3.2 Normalização de espécie
    NEW.especie := LOWER(TRIM(COALESCE(NEW.especie, '')));
    IF NEW.especie NOT IN ('cao', 'gato', 'ave', 'roedor', 'reptil', 'peixe', 'outro') THEN
        RAISE EXCEPTION 'Espécie de pet inválida (%). Espécies aceitas: cao, gato, ave, roedor, reptil, peixe, outro.', NEW.especie;
    END IF;

    -- 3.3 Normalização de sexo (se informado)
    IF NEW.sexo IS NOT NULL THEN
        NEW.sexo := LOWER(TRIM(NEW.sexo));
        IF NEW.sexo NOT IN ('macho', 'femea') THEN
            RAISE EXCEPTION 'Sexo do pet inválido (%). Opções aceitas: macho, femea.', NEW.sexo;
        END IF;
    END IF;

    -- 3.4 Normalização de porte (se informado)
    IF NEW.porte IS NOT NULL THEN
        NEW.porte := LOWER(TRIM(NEW.porte));
        IF NEW.porte NOT IN ('pequeno', 'medio', 'grande', 'nao_se_aplica') THEN
            RAISE EXCEPTION 'Porte do pet inválido (%). Opções aceitas: pequeno, medio, grande, nao_se_aplica.', NEW.porte;
        END IF;
    END IF;

    -- 3.5 Validação de data de nascimento não futura
    IF NEW.data_nascimento IS NOT NULL AND NEW.data_nascimento > CURRENT_DATE THEN
        RAISE EXCEPTION 'A data de nascimento do pet não pode estar no futuro (%).', NEW.data_nascimento;
    END IF;

    -- 3.6 Limpeza de campos textuais opcionais
    NEW.raca := NULLIF(TRIM(COALESCE(NEW.raca, '')), '');
    NEW.cor := NULLIF(TRIM(COALESCE(NEW.cor, '')), '');
    NEW.observacao := NULLIF(TRIM(COALESCE(NEW.observacao, '')), '');

    -- 3.7 Proteção de Integridade Multi-Tenant (Tenant Guard)
    SELECT condominio_id INTO v_p_condo FROM public.perfil WHERE id = NEW.perfil_id;
    IF v_p_condo IS NULL THEN
        RAISE EXCEPTION 'Perfil do tutor não encontrado.';
    END IF;
    IF v_p_condo IS DISTINCT FROM NEW.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O tutor indicado pertence a condomínio divergente.';
    END IF;

    SELECT condominio_id INTO v_u_condo FROM public.unidades WHERE id = NEW.unidade_id;
    IF v_u_condo IS NULL THEN
        RAISE EXCEPTION 'Unidade residencial não encontrada.';
    END IF;
    IF v_u_condo IS DISTINCT FROM NEW.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. A unidade indicada pertence a condomínio divergente.';
    END IF;

    -- 3.8 Atualização de timestamp
    NEW.updated_at := timezone('utc'::text, now());

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_pets_guard ON public.pets;
CREATE TRIGGER tr_pets_guard
BEFORE INSERT OR UPDATE ON public.pets
FOR EACH ROW
EXECUTE FUNCTION public.tr_fn_pets_guard();

-- 4. HABILITAÇÃO DE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pets_admin_select ON public.pets;
CREATE POLICY pets_admin_select ON public.pets
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
        WHERE LOWER(ss.email) = LOWER(COALESCE((auth.jwt() ->> 'email'::text), ''))
    )
);

COMMENT ON POLICY pets_admin_select ON public.pets IS 
'Permite leitura de pets por administradores do mesmo condomínio e superadmins globais via JWT claim sem ler auth.users diretamente.';

-- 5. OPERAÇÕES ADMINISTRATIVAS (RPCS CANÔNICAS)

-- 5.1 admin_cadastrar_pet
CREATE OR REPLACE FUNCTION public.admin_cadastrar_pet(
    p_perfil_id UUID,
    p_unidade_id UUID,
    p_nome TEXT,
    p_especie TEXT,
    p_raca TEXT DEFAULT NULL,
    p_sexo TEXT DEFAULT NULL,
    p_porte TEXT DEFAULT NULL,
    p_cor TEXT DEFAULT NULL,
    p_data_nascimento DATE DEFAULT NULL,
    p_castrado BOOLEAN DEFAULT NULL,
    p_vacinado BOOLEAN DEFAULT NULL,
    p_observacao TEXT DEFAULT NULL
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
    v_pet_id UUID;
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem cadastrar pets.';
            END IF;
        END IF;
    END IF;

    -- 3. Validação dos parâmetros básicos
    IF p_perfil_id IS NULL THEN
        RAISE EXCEPTION 'O morador tutor responsável é obrigatório.';
    END IF;
    IF p_unidade_id IS NULL THEN
        RAISE EXCEPTION 'A unidade residencial é obrigatória.';
    END IF;
    IF TRIM(COALESCE(p_nome, '')) = '' THEN
        RAISE EXCEPTION 'O nome do pet é obrigatório.';
    END IF;
    IF LOWER(TRIM(COALESCE(p_especie, ''))) NOT IN ('cao', 'gato', 'ave', 'roedor', 'reptil', 'peixe', 'outro') THEN
        RAISE EXCEPTION 'Espécie de pet inválida (%). Espécies aceitas: cao, gato, ave, roedor, reptil, peixe, outro.', p_especie;
    END IF;
    IF p_data_nascimento IS NOT NULL AND p_data_nascimento > CURRENT_DATE THEN
        RAISE EXCEPTION 'A data de nascimento do pet não pode estar no futuro (%).', p_data_nascimento;
    END IF;

    -- 4. Validar perfil e unidade alvo
    SELECT id, condominio_id, status_aprovacao, bloqueado, nome_completo
    INTO v_target_profile
    FROM public.perfil
    WHERE id = p_perfil_id;

    IF v_target_profile.id IS NULL THEN
        RAISE EXCEPTION 'Tutor alvo não encontrado.';
    END IF;

    v_condo_id := v_target_profile.condominio_id;

    -- Isolamento Multi-Tenant do operador
    IF v_op.condominio_id IS NOT NULL AND v_condo_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O tutor alvo pertence a outro condomínio.';
    END IF;

    SELECT id, condominio_id
    INTO v_target_unit
    FROM public.unidades
    WHERE id = p_unidade_id;

    IF v_target_unit.id IS NULL THEN
        RAISE EXCEPTION 'Unidade residencial não encontrada.';
    END IF;

    IF v_target_unit.condominio_id IS DISTINCT FROM v_condo_id THEN
        RAISE EXCEPTION 'A unidade selecionada pertence a condomínio divergente do tutor.';
    END IF;

    -- 5. Validação de Vínculo Residencial Ativo do Tutor com a Unidade
    IF NOT EXISTS (
        SELECT 1 FROM public.unidade_perfil up
        WHERE up.perfil_id = p_perfil_id
          AND up.unidade_id = p_unidade_id
          AND up.status = 'ativo'
    ) THEN
        RAISE EXCEPTION 'Vínculo residencial inválido. O tutor não possui vínculo ativo com a unidade selecionada.';
    END IF;

    -- 6. Inserção do pet
    INSERT INTO public.pets (
        condominio_id,
        unidade_id,
        perfil_id,
        nome,
        especie,
        raca,
        sexo,
        porte,
        cor,
        data_nascimento,
        castrado,
        vacinado,
        observacao,
        status
    ) VALUES (
        v_condo_id,
        p_unidade_id,
        p_perfil_id,
        TRIM(p_nome),
        LOWER(TRIM(p_especie)),
        NULLIF(TRIM(p_raca), ''),
        NULLIF(LOWER(TRIM(p_sexo)), ''),
        NULLIF(LOWER(TRIM(p_porte)), ''),
        NULLIF(TRIM(p_cor), ''),
        p_data_nascimento,
        p_castrado,
        p_vacinado,
        NULLIF(TRIM(p_observacao), ''),
        'ativo'
    ) RETURNING id INTO v_pet_id;

    -- 7. Auditoria obrigatória em perfil_audit_log
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
        'PET_CREATED',
        p_observacao,
        '{}'::jsonb,
        jsonb_build_object(
            'pet_id', v_pet_id,
            'nome', TRIM(p_nome),
            'especie', LOWER(TRIM(p_especie)),
            'raca', NULLIF(TRIM(p_raca), ''),
            'sexo', NULLIF(LOWER(TRIM(p_sexo)), ''),
            'porte', NULLIF(LOWER(TRIM(p_porte)), ''),
            'cor', NULLIF(TRIM(p_cor), ''),
            'data_nascimento', p_data_nascimento,
            'castrado', p_castrado,
            'vacinado', p_vacinado,
            'status', 'ativo'
        ),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'pet_id', v_pet_id,
        'nome', TRIM(p_nome),
        'message', 'Pet cadastrado com sucesso.'
    );
END;
$$;

-- 5.2 admin_atualizar_pet (Preserva imutabilidade de pet inativo)
CREATE OR REPLACE FUNCTION public.admin_atualizar_pet(
    p_pet_id UUID,
    p_nome TEXT,
    p_especie TEXT,
    p_raca TEXT DEFAULT NULL,
    p_sexo TEXT DEFAULT NULL,
    p_porte TEXT DEFAULT NULL,
    p_cor TEXT DEFAULT NULL,
    p_data_nascimento DATE DEFAULT NULL,
    p_castrado BOOLEAN DEFAULT NULL,
    p_vacinado BOOLEAN DEFAULT NULL,
    p_observacao TEXT DEFAULT NULL
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem atualizar pets.';
            END IF;
        END IF;
    END IF;

    SELECT * INTO v_target
    FROM public.pets
    WHERE id = p_pet_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Pet não encontrado.';
    END IF;

    IF v_op.condominio_id IS NOT NULL AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O pet pertence a outro condomínio.';
    END IF;

    -- Guarda de Imutabilidade: Pet inativo não pode ser editado
    IF v_target.status = 'inativo' THEN
        RAISE EXCEPTION 'Pet inativo não pode ser editado. Reative o pet antes de alterar seus dados.';
    END IF;

    IF TRIM(COALESCE(p_nome, '')) = '' THEN
        RAISE EXCEPTION 'O nome do pet é obrigatório.';
    END IF;
    IF LOWER(TRIM(COALESCE(p_especie, ''))) NOT IN ('cao', 'gato', 'ave', 'roedor', 'reptil', 'peixe', 'outro') THEN
        RAISE EXCEPTION 'Espécie de pet inválida (%). Espécies aceitas: cao, gato, ave, roedor, reptil, peixe, outro.', p_especie;
    END IF;
    IF p_data_nascimento IS NOT NULL AND p_data_nascimento > CURRENT_DATE THEN
        RAISE EXCEPTION 'A data de nascimento do pet não pode estar no futuro (%).', p_data_nascimento;
    END IF;

    v_old_state := jsonb_build_object(
        'pet_id', v_target.id,
        'nome', v_target.nome,
        'especie', v_target.especie,
        'raca', v_target.raca,
        'sexo', v_target.sexo,
        'porte', v_target.porte,
        'cor', v_target.cor,
        'data_nascimento', v_target.data_nascimento,
        'castrado', v_target.castrado,
        'vacinado', v_target.vacinado,
        'observacao', v_target.observacao,
        'status', v_target.status
    );

    UPDATE public.pets
    SET nome = TRIM(p_nome),
        especie = LOWER(TRIM(p_especie)),
        raca = NULLIF(TRIM(p_raca), ''),
        sexo = NULLIF(LOWER(TRIM(p_sexo)), ''),
        porte = NULLIF(LOWER(TRIM(p_porte)), ''),
        cor = NULLIF(TRIM(p_cor), ''),
        data_nascimento = p_data_nascimento,
        castrado = p_castrado,
        vacinado = p_vacinado,
        observacao = NULLIF(TRIM(p_observacao), ''),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_pet_id;

    v_new_state := jsonb_build_object(
        'pet_id', v_target.id,
        'nome', TRIM(p_nome),
        'especie', LOWER(TRIM(p_especie)),
        'raca', NULLIF(TRIM(p_raca), ''),
        'sexo', NULLIF(LOWER(TRIM(p_sexo)), ''),
        'porte', NULLIF(LOWER(TRIM(p_porte)), ''),
        'cor', NULLIF(TRIM(p_cor), ''),
        'data_nascimento', p_data_nascimento,
        'castrado', p_castrado,
        'vacinado', p_vacinado,
        'observacao', NULLIF(TRIM(p_observacao), ''),
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
        'PET_UPDATED',
        COALESCE(NULLIF(TRIM(p_observacao), ''), 'Atualização de cadastro de pet'),
        v_old_state,
        v_new_state,
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'pet_id', v_target.id,
        'message', 'Dados do pet atualizados com sucesso.'
    );
END;
$$;

-- 5.3 admin_inativar_pet (Exige motivo e rejeita pet já inativo)
CREATE OR REPLACE FUNCTION public.admin_inativar_pet(
    p_pet_id UUID,
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem inativar pets.';
            END IF;
        END IF;
    END IF;

    IF TRIM(COALESCE(p_motivo, '')) = '' THEN
        RAISE EXCEPTION 'O motivo da inativação do pet é obrigatório para auditoria.';
    END IF;

    SELECT * INTO v_target
    FROM public.pets
    WHERE id = p_pet_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Pet não encontrado.';
    END IF;

    IF v_op.condominio_id IS NOT NULL AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O pet pertence a outro condomínio.';
    END IF;

    IF v_target.status = 'inativo' THEN
        RAISE EXCEPTION 'Este pet já se encontra inativo.';
    END IF;

    v_old_state := jsonb_build_object(
        'pet_id', v_target.id,
        'nome', v_target.nome,
        'especie', v_target.especie,
        'status', v_target.status
    );

    UPDATE public.pets
    SET status = 'inativo',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_pet_id;

    v_new_state := jsonb_build_object(
        'pet_id', v_target.id,
        'nome', v_target.nome,
        'especie', v_target.especie,
        'status', 'inativo'
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
        'PET_INACTIVATED',
        TRIM(p_motivo),
        v_old_state,
        v_new_state,
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'pet_id', v_target.id,
        'message', 'Pet inativado com sucesso.'
    );
END;
$$;

-- 5.4 admin_reativar_pet (Reativa pet inativo e rejeita pet já ativo)
CREATE OR REPLACE FUNCTION public.admin_reativar_pet(
    p_pet_id UUID,
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem reativar pets.';
            END IF;
        END IF;
    END IF;

    SELECT * INTO v_target
    FROM public.pets
    WHERE id = p_pet_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Pet não encontrado.';
    END IF;

    IF v_op.condominio_id IS NOT NULL AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O pet pertence a outro condomínio.';
    END IF;

    IF v_target.status = 'ativo' THEN
        RAISE EXCEPTION 'Este pet já se encontra ativo.';
    END IF;

    v_old_state := jsonb_build_object(
        'pet_id', v_target.id,
        'nome', v_target.nome,
        'status', 'inativo'
    );

    UPDATE public.pets
    SET status = 'ativo',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_pet_id;

    v_new_state := jsonb_build_object(
        'pet_id', v_target.id,
        'nome', v_target.nome,
        'status', 'ativo'
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
        'PET_REACTIVATED',
        COALESCE(NULLIF(TRIM(p_motivo), ''), 'Reativação de cadastro de pet'),
        v_old_state,
        v_new_state,
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'pet_id', v_target.id,
        'message', 'Pet reativado com sucesso.'
    );
END;
$$;

-- 5.5 admin_transferir_unidade_pet (Transfere unidade com mesmo pet_id e validação de vínculo do tutor)
CREATE OR REPLACE FUNCTION public.admin_transferir_unidade_pet(
    p_pet_id UUID,
    p_nova_unidade_id UUID,
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
    v_target_unit RECORD;
    v_old_unidade_id UUID;
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem transferir unidades de pets.';
            END IF;
        END IF;
    END IF;

    IF p_nova_unidade_id IS NULL THEN
        RAISE EXCEPTION 'A nova unidade residencial é obrigatória.';
    END IF;

    SELECT * INTO v_target
    FROM public.pets
    WHERE id = p_pet_id
    FOR UPDATE;

    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Pet não encontrado.';
    END IF;

    IF v_op.condominio_id IS NOT NULL AND v_target.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O pet pertence a outro condomínio.';
    END IF;

    -- Guarda de Imutabilidade: Pet inativo não pode ter unidade transferida
    IF v_target.status = 'inativo' THEN
        RAISE EXCEPTION 'Pet inativo não pode ter sua unidade transferida. Reative o pet antes de realizar a transferência.';
    END IF;

    IF p_nova_unidade_id = v_target.unidade_id THEN
        RETURN jsonb_build_object('success', true, 'message', 'O pet já se encontra vinculado a esta unidade. Nenhuma alteração realizada.');
    END IF;

    -- Validar que a nova unidade existe e pertence ao mesmo condomínio
    SELECT id, condominio_id
    INTO v_target_unit
    FROM public.unidades
    WHERE id = p_nova_unidade_id;

    IF v_target_unit.id IS NULL THEN
        RAISE EXCEPTION 'Nova unidade residencial não encontrada.';
    END IF;

    IF v_target_unit.condominio_id IS DISTINCT FROM v_target.condominio_id THEN
        RAISE EXCEPTION 'A nova unidade selecionada pertence a condomínio divergente.';
    END IF;

    -- Validar que o tutor possui vínculo residencial ativo na nova unidade
    IF NOT EXISTS (
        SELECT 1 FROM public.unidade_perfil up
        WHERE up.perfil_id = v_target.perfil_id
          AND up.unidade_id = p_nova_unidade_id
          AND up.status = 'ativo'
    ) THEN
        RAISE EXCEPTION 'Vínculo residencial inválido. O tutor não possui vínculo ativo com a nova unidade selecionada.';
    END IF;

    v_old_unidade_id := v_target.unidade_id;

    UPDATE public.pets
    SET unidade_id = p_nova_unidade_id,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_pet_id;

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
        p_nova_unidade_id,
        'PET_UNIT_CHANGED',
        COALESCE(NULLIF(TRIM(p_motivo), ''), 'Transferência de unidade do pet'),
        jsonb_build_object('pet_id', v_target.id, 'unidade_id', v_old_unidade_id, 'nome', v_target.nome),
        jsonb_build_object('pet_id', v_target.id, 'unidade_id', p_nova_unidade_id, 'nome', v_target.nome),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'pet_id', v_target.id,
        'unidade_anterior', v_old_unidade_id,
        'nova_unidade', p_nova_unidade_id,
        'message', 'Unidade do pet transferida com sucesso.'
    );
END;
$$;

COMMENT ON TABLE public.pets IS 
'Armazena os registros canônicos de animais de estimação vinculados ao condomínio, tutor e unidade residencial.';

COMMENT ON FUNCTION public.admin_cadastrar_pet IS 
'Cadastra um novo pet ativo com validação multi-tenant, validação de vínculo residencial ativo do tutor e auditoria.';

COMMENT ON FUNCTION public.admin_atualizar_pet IS 
'Atualiza dados cadastrais de pet ativo com auditoria. Rejeita pets inativos.';

COMMENT ON FUNCTION public.admin_inativar_pet IS 
'Inativa pet ativo com motivo obrigatório e auditoria. Rejeita pets já inativos.';

COMMENT ON FUNCTION public.admin_reativar_pet IS 
'Reativa pet inativo restaurando status ativo com auditoria. Rejeita pets já ativos.';

COMMENT ON FUNCTION public.admin_transferir_unidade_pet IS 
'Transfere a unidade de residência do pet preservando tutor e pet_id, com validação de vínculo residencial ativo do tutor e auditoria.';
