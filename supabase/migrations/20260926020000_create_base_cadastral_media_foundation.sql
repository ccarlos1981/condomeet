-- ==============================================================================
-- CONDOMEET — BASE CADASTRAL 360º — GATE 3F.2-A
-- FUNDAÇÃO CANÔNICA DE MÍDIA (PETS + VEÍCULOS)
-- Migration: 20260926020000_create_base_cadastral_media_foundation.sql
-- 
-- Arquitetura:
-- 1. Colunas foto_path em public.pets e public.veiculos (TEXT NULL)
-- 2. Bucket privado 'base-cadastral-media' (public = false, 5MB, jpeg/png/webp)
-- 3. Storage RLS Policies multi-tenant isoladas por condominio_id
-- 4. RPCs administrativas transacionais SECURITY DEFINER
-- 5. Imutabilidade estrita de inativos e trilha de auditoria em perfil_audit_log
-- ==============================================================================

-- 1. DDL: EVOLUÇÃO DAS TABELAS DE PETS E VEÍCULOS
ALTER TABLE public.pets
ADD COLUMN IF NOT EXISTS foto_path TEXT NULL;

COMMENT ON COLUMN public.pets.foto_path IS 
'Path relativo da imagem no Supabase Storage no bucket base-cadastral-media ({condominio_id}/pets/{pet_id}/{timestamp}_{uuid}.jpg).';

ALTER TABLE public.veiculos
ADD COLUMN IF NOT EXISTS foto_path TEXT NULL;

COMMENT ON COLUMN public.veiculos.foto_path IS 
'Path relativo da imagem no Supabase Storage no bucket base-cadastral-media ({condominio_id}/veiculos/{veiculo_id}/{timestamp}_{uuid}.jpg).';

-- 2. CONFIGURAÇÃO DO BUCKET PRIVADO NO STORAGE
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'base-cadastral-media',
    'base-cadastral-media',
    false,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- 3. STORAGE RLS POLICIES EM storage.objects

-- 3.1 SELECT Policy (Leitura privada restrita a administradores do mesmo condomínio e SuperAdmins)
DROP POLICY IF EXISTS "base_cadastral_media_select" ON storage.objects;
CREATE POLICY "base_cadastral_media_select"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'base-cadastral-media'
    AND (
        EXISTS (
            SELECT 1 FROM public.system_superadmins sa
            WHERE LOWER(sa.email) = LOWER(COALESCE((auth.jwt() ->> 'email'::text), ''))
        )
        OR EXISTS (
            SELECT 1 FROM public.perfil p
            WHERE p.id = auth.uid()
              AND p.condominio_id::text = split_part(name, '/', 1)
              AND COALESCE(p.bloqueado, false) = false
              AND p.status_aprovacao = 'aprovado'
              AND LOWER(COALESCE(p.papel_sistema, '')) IN (
                  'admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora'
              )
        )
    )
);

-- 3.2 INSERT Policy (Upload restrito a administradores do mesmo condomínio e SuperAdmins)
DROP POLICY IF EXISTS "base_cadastral_media_insert" ON storage.objects;
CREATE POLICY "base_cadastral_media_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'base-cadastral-media'
    AND split_part(name, '/', 2) IN ('pets', 'veiculos')
    AND split_part(name, '/', 3) <> ''
    AND split_part(name, '/', 4) <> ''
    AND (
        EXISTS (
            SELECT 1 FROM public.system_superadmins sa
            WHERE LOWER(sa.email) = LOWER(COALESCE((auth.jwt() ->> 'email'::text), ''))
        )
        OR EXISTS (
            SELECT 1 FROM public.perfil p
            WHERE p.id = auth.uid()
              AND p.condominio_id::text = split_part(name, '/', 1)
              AND COALESCE(p.bloqueado, false) = false
              AND p.status_aprovacao = 'aprovado'
              AND LOWER(COALESCE(p.papel_sistema, '')) IN (
                  'admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora'
              )
        )
    )
);

-- 3.3 DELETE Policy (Remoção restrita a administradores do mesmo condomínio e SuperAdmins)
DROP POLICY IF EXISTS "base_cadastral_media_delete" ON storage.objects;
CREATE POLICY "base_cadastral_media_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'base-cadastral-media'
    AND (
        EXISTS (
            SELECT 1 FROM public.system_superadmins sa
            WHERE LOWER(sa.email) = LOWER(COALESCE((auth.jwt() ->> 'email'::text), ''))
        )
        OR EXISTS (
            SELECT 1 FROM public.perfil p
            WHERE p.id = auth.uid()
              AND p.condominio_id::text = split_part(name, '/', 1)
              AND COALESCE(p.bloqueado, false) = false
              AND p.status_aprovacao = 'aprovado'
              AND LOWER(COALESCE(p.papel_sistema, '')) IN (
                  'admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora'
              )
        )
    )
);

-- 4. RPCS ADMINISTRATIVAS TRANSACIONAIS — MÓDULO PETS

-- 4.1 public.admin_salvar_foto_pet
CREATE OR REPLACE FUNCTION public.admin_salvar_foto_pet(
    p_pet_id UUID,
    p_foto_path TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_operator_id UUID;
    v_op RECORD;
    v_pet RECORD;
    v_path_condo TEXT;
    v_path_entity TEXT;
    v_path_entity_id TEXT;
    v_path_filename TEXT;
    v_foto_path_anterior TEXT;
BEGIN
    -- 1. Autenticação do operador
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. Autorização administrativa (Síndico / Admin / SuperAdmin)
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem salvar fotos.';
            END IF;
        END IF;
    END IF;

    -- 3. Parâmetros obrigatórios
    IF p_pet_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do pet é obrigatório.';
    END IF;

    IF p_foto_path IS NULL OR TRIM(p_foto_path) = '' THEN
        RAISE EXCEPTION 'O caminho da foto (foto_path) é obrigatório.';
    END IF;

    -- 4. Carregar registro do pet
    SELECT id, condominio_id, unidade_id, perfil_id, nome, status, foto_path
    INTO v_pet
    FROM public.pets
    WHERE id = p_pet_id;

    IF v_pet.id IS NULL THEN
        RAISE EXCEPTION 'Pet não encontrado.';
    END IF;

    -- 5. Validação multi-tenant do operador
    IF v_op.id IS NOT NULL AND v_op.condominio_id IS NOT NULL THEN
        IF v_op.condominio_id IS DISTINCT FROM v_pet.condominio_id THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.system_superadmins s
                WHERE lower(s.email) = lower(coalesce(v_op.email, ''))
                   OR lower(s.email) = lower(coalesce(auth.jwt()->>'email', ''))
            ) THEN
                RAISE EXCEPTION 'Operação negada. O pet pertence a outro condomínio.';
            END IF;
        END IF;
    END IF;

    -- 6. Invariante soberana: Inativo = Histórico Imutável
    IF v_pet.status IS DISTINCT FROM 'ativo' THEN
        RAISE EXCEPTION 'Operação não permitida. O pet encontra-se inativo e seu registro histórico é imutável.';
    END IF;

    -- 7. Validação rígida da estrutura canônica do path: {condominio_id}/pets/{pet_id}/{filename}
    v_path_condo     := split_part(TRIM(p_foto_path), '/', 1);
    v_path_entity    := split_part(TRIM(p_foto_path), '/', 2);
    v_path_entity_id := split_part(TRIM(p_foto_path), '/', 3);
    v_path_filename  := split_part(TRIM(p_foto_path), '/', 4);

    IF v_path_condo IS DISTINCT FROM v_pet.condominio_id::text THEN
        RAISE EXCEPTION 'Caminho inválido. O condomínio no path diverge do condomínio do pet.';
    END IF;

    IF v_path_entity IS DISTINCT FROM 'pets' THEN
        RAISE EXCEPTION 'Caminho inválido. A entidade no path deve ser "pets".';
    END IF;

    IF v_path_entity_id IS DISTINCT FROM v_pet.id::text THEN
        RAISE EXCEPTION 'Caminho inválido. O identificador do pet no path diverge do pet informado.';
    END IF;

    IF v_path_filename IS NULL OR TRIM(v_path_filename) = '' THEN
        RAISE EXCEPTION 'Caminho inválido. Nome do arquivo ausente no path.';
    END IF;

    IF split_part(TRIM(p_foto_path), '/', 5) <> '' THEN
        RAISE EXCEPTION 'Caminho inválido. A estrutura do path não pode exceder 4 segmentos.';
    END IF;

    IF LOWER(TRIM(p_foto_path)) !~ '\.(jpe?g|png|webp)$' THEN
        RAISE EXCEPTION 'Formato de imagem não suportado no path. Apenas JPG, JPEG, PNG ou WebP são aceitos.';
    END IF;

    -- 8. Atualização do registro
    v_foto_path_anterior := v_pet.foto_path;

    UPDATE public.pets
    SET foto_path = TRIM(p_foto_path),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_pet_id;

    -- 9. Registro de auditoria formal
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
        v_pet.condominio_id,
        v_pet.perfil_id,
        v_operator_id,
        v_pet.unidade_id,
        'PET_PHOTO_UPDATED',
        'Atualização de foto do pet',
        jsonb_build_object(
            'pet_id', v_pet.id,
            'nome', v_pet.nome,
            'foto_path', v_foto_path_anterior
        ),
        jsonb_build_object(
            'pet_id', v_pet.id,
            'nome', v_pet.nome,
            'foto_path_anterior', v_foto_path_anterior,
            'foto_path_novo', TRIM(p_foto_path)
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'pet_id', v_pet.id,
        'foto_path_anterior', v_foto_path_anterior,
        'foto_path_novo', TRIM(p_foto_path)
    );
END;
$$;

-- 4.2 public.admin_remover_foto_pet
CREATE OR REPLACE FUNCTION public.admin_remover_foto_pet(
    p_pet_id UUID,
    p_motivo TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_operator_id UUID;
    v_op RECORD;
    v_pet RECORD;
    v_foto_path_anterior TEXT;
BEGIN
    -- 1. Autenticação do operador
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. Autorização administrativa
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem remover fotos.';
            END IF;
        END IF;
    END IF;

    -- 3. Parâmetro obrigatório
    IF p_pet_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do pet é obrigatório.';
    END IF;

    -- 4. Carregar registro do pet
    SELECT id, condominio_id, unidade_id, perfil_id, nome, status, foto_path
    INTO v_pet
    FROM public.pets
    WHERE id = p_pet_id;

    IF v_pet.id IS NULL THEN
        RAISE EXCEPTION 'Pet não encontrado.';
    END IF;

    -- 5. Validação multi-tenant
    IF v_op.id IS NOT NULL AND v_op.condominio_id IS NOT NULL THEN
        IF v_op.condominio_id IS DISTINCT FROM v_pet.condominio_id THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.system_superadmins s
                WHERE lower(s.email) = lower(coalesce(v_op.email, ''))
                   OR lower(s.email) = lower(coalesce(auth.jwt()->>'email', ''))
            ) THEN
                RAISE EXCEPTION 'Operação negada. O pet pertence a outro condomínio.';
            END IF;
        END IF;
    END IF;

    -- 6. Invariante soberana: Inativo = Histórico Imutável
    IF v_pet.status IS DISTINCT FROM 'ativo' THEN
        RAISE EXCEPTION 'Operação não permitida. O pet encontra-se inativo e seu registro histórico é imutável.';
    END IF;

    v_foto_path_anterior := v_pet.foto_path;

    -- Se não havia foto cadastrada, encerra com sucesso idempontente
    IF v_foto_path_anterior IS NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'pet_id', v_pet.id,
            'foto_path_anterior', NULL
        );
    END IF;

    -- 7. Remover referência do banco
    UPDATE public.pets
    SET foto_path = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_pet_id;

    -- 8. Registro de auditoria
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
        v_pet.condominio_id,
        v_pet.perfil_id,
        v_operator_id,
        v_pet.unidade_id,
        'PET_PHOTO_REMOVED',
        COALESCE(NULLIF(TRIM(p_motivo), ''), 'Remoção de foto do pet'),
        jsonb_build_object(
            'pet_id', v_pet.id,
            'nome', v_pet.nome,
            'foto_path', v_foto_path_anterior
        ),
        jsonb_build_object(
            'pet_id', v_pet.id,
            'nome', v_pet.nome,
            'foto_path_removido', v_foto_path_anterior,
            'foto_path', NULL
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'pet_id', v_pet.id,
        'foto_path_anterior', v_foto_path_anterior
    );
END;
$$;

-- 5. RPCS ADMINISTRATIVAS TRANSACIONAIS — MÓDULO VEÍCULOS

-- 5.1 public.admin_salvar_foto_veiculo
CREATE OR REPLACE FUNCTION public.admin_salvar_foto_veiculo(
    p_veiculo_id UUID,
    p_foto_path TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_operator_id UUID;
    v_op RECORD;
    v_veic RECORD;
    v_path_condo TEXT;
    v_path_entity TEXT;
    v_path_entity_id TEXT;
    v_path_filename TEXT;
    v_foto_path_anterior TEXT;
BEGIN
    -- 1. Autenticação do operador
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. Autorização administrativa (Síndico / Admin / SuperAdmin)
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem salvar fotos.';
            END IF;
        END IF;
    END IF;

    -- 3. Parâmetros obrigatórios
    IF p_veiculo_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do veículo é obrigatório.';
    END IF;

    IF p_foto_path IS NULL OR TRIM(p_foto_path) = '' THEN
        RAISE EXCEPTION 'O caminho da foto (foto_path) é obrigatório.';
    END IF;

    -- 4. Carregar registro do veículo
    SELECT id, condominio_id, unidade_id, perfil_id, placa, status, foto_path
    INTO v_veic
    FROM public.veiculos
    WHERE id = p_veiculo_id;

    IF v_veic.id IS NULL THEN
        RAISE EXCEPTION 'Veículo não encontrado.';
    END IF;

    -- 5. Validação multi-tenant
    IF v_op.id IS NOT NULL AND v_op.condominio_id IS NOT NULL THEN
        IF v_op.condominio_id IS DISTINCT FROM v_veic.condominio_id THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.system_superadmins s
                WHERE lower(s.email) = lower(coalesce(v_op.email, ''))
                   OR lower(s.email) = lower(coalesce(auth.jwt()->>'email', ''))
            ) THEN
                RAISE EXCEPTION 'Operação negada. O veículo pertence a outro condomínio.';
            END IF;
        END IF;
    END IF;

    -- 6. Invariante soberana: Inativo = Histórico Imutável
    IF v_veic.status IS DISTINCT FROM 'ativo' THEN
        RAISE EXCEPTION 'Operação não permitida. O veículo encontra-se inativo e seu registro histórico é imutável.';
    END IF;

    -- 7. Validação rígida da estrutura canônica do path: {condominio_id}/veiculos/{veiculo_id}/{filename}
    v_path_condo     := split_part(TRIM(p_foto_path), '/', 1);
    v_path_entity    := split_part(TRIM(p_foto_path), '/', 2);
    v_path_entity_id := split_part(TRIM(p_foto_path), '/', 3);
    v_path_filename  := split_part(TRIM(p_foto_path), '/', 4);

    IF v_path_condo IS DISTINCT FROM v_veic.condominio_id::text THEN
        RAISE EXCEPTION 'Caminho inválido. O condomínio no path diverge do condomínio do veículo.';
    END IF;

    IF v_path_entity IS DISTINCT FROM 'veiculos' THEN
        RAISE EXCEPTION 'Caminho inválido. A entidade no path deve ser "veiculos".';
    END IF;

    IF v_path_entity_id IS DISTINCT FROM v_veic.id::text THEN
        RAISE EXCEPTION 'Caminho inválido. O identificador do veículo no path diverge do veículo informado.';
    END IF;

    IF v_path_filename IS NULL OR TRIM(v_path_filename) = '' THEN
        RAISE EXCEPTION 'Caminho inválido. Nome do arquivo ausente no path.';
    END IF;

    IF split_part(TRIM(p_foto_path), '/', 5) <> '' THEN
        RAISE EXCEPTION 'Caminho inválido. A estrutura do path não pode exceder 4 segmentos.';
    END IF;

    IF LOWER(TRIM(p_foto_path)) !~ '\.(jpe?g|png|webp)$' THEN
        RAISE EXCEPTION 'Formato de imagem não suportado no path. Apenas JPG, JPEG, PNG ou WebP são aceitos.';
    END IF;

    -- 8. Atualização do registro
    v_foto_path_anterior := v_veic.foto_path;

    UPDATE public.veiculos
    SET foto_path = TRIM(p_foto_path),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_veiculo_id;

    -- 9. Registro de auditoria formal
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
        v_veic.condominio_id,
        v_veic.perfil_id,
        v_operator_id,
        v_veic.unidade_id,
        'VEHICLE_PHOTO_UPDATED',
        'Atualização de foto do veículo',
        jsonb_build_object(
            'veiculo_id', v_veic.id,
            'placa', v_veic.placa,
            'foto_path', v_foto_path_anterior
        ),
        jsonb_build_object(
            'veiculo_id', v_veic.id,
            'placa', v_veic.placa,
            'foto_path_anterior', v_foto_path_anterior,
            'foto_path_novo', TRIM(p_foto_path)
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'veiculo_id', v_veic.id,
        'foto_path_anterior', v_foto_path_anterior,
        'foto_path_novo', TRIM(p_foto_path)
    );
END;
$$;

-- 5.2 public.admin_remover_foto_veiculo
CREATE OR REPLACE FUNCTION public.admin_remover_foto_veiculo(
    p_veiculo_id UUID,
    p_motivo TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_operator_id UUID;
    v_op RECORD;
    v_veic RECORD;
    v_foto_path_anterior TEXT;
BEGIN
    -- 1. Autenticação do operador
    v_operator_id := auth.uid();
    IF v_operator_id IS NULL THEN
        RAISE EXCEPTION 'Operação não autorizada. Sessão do operador não identificada.';
    END IF;

    -- 2. Autorização administrativa
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
                RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem remover fotos.';
            END IF;
        END IF;
    END IF;

    -- 3. Parâmetro obrigatório
    IF p_veiculo_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do veículo é obrigatório.';
    END IF;

    -- 4. Carregar registro do veículo
    SELECT id, condominio_id, unidade_id, perfil_id, placa, status, foto_path
    INTO v_veic
    FROM public.veiculos
    WHERE id = p_veiculo_id;

    IF v_veic.id IS NULL THEN
        RAISE EXCEPTION 'Veículo não encontrado.';
    END IF;

    -- 5. Validação multi-tenant
    IF v_op.id IS NOT NULL AND v_op.condominio_id IS NOT NULL THEN
        IF v_op.condominio_id IS DISTINCT FROM v_veic.condominio_id THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.system_superadmins s
                WHERE lower(s.email) = lower(coalesce(v_op.email, ''))
                   OR lower(s.email) = lower(coalesce(auth.jwt()->>'email', ''))
            ) THEN
                RAISE EXCEPTION 'Operação negada. O veículo pertence a outro condomínio.';
            END IF;
        END IF;
    END IF;

    -- 6. Invariante soberana: Inativo = Histórico Imutável
    IF v_veic.status IS DISTINCT FROM 'ativo' THEN
        RAISE EXCEPTION 'Operação não permitida. O veículo encontra-se inativo e seu registro histórico é imutável.';
    END IF;

    v_foto_path_anterior := v_veic.foto_path;

    -- Se não havia foto cadastrada, encerra com sucesso idempotente
    IF v_foto_path_anterior IS NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'veiculo_id', v_veic.id,
            'foto_path_anterior', NULL
        );
    END IF;

    -- 7. Remover referência do banco
    UPDATE public.veiculos
    SET foto_path = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_veiculo_id;

    -- 8. Registro de auditoria
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
        v_veic.condominio_id,
        v_veic.perfil_id,
        v_operator_id,
        v_veic.unidade_id,
        'VEHICLE_PHOTO_REMOVED',
        COALESCE(NULLIF(TRIM(p_motivo), ''), 'Remoção de foto do veículo'),
        jsonb_build_object(
            'veiculo_id', v_veic.id,
            'placa', v_veic.placa,
            'foto_path', v_foto_path_anterior
        ),
        jsonb_build_object(
            'veiculo_id', v_veic.id,
            'placa', v_veic.placa,
            'foto_path_removido', v_foto_path_anterior,
            'foto_path', NULL
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'veiculo_id', v_veic.id,
        'foto_path_anterior', v_foto_path_anterior
    );
END;
$$;

-- 6. PERMISSÕES DE EXECUÇÃO
GRANT EXECUTE ON FUNCTION public.admin_salvar_foto_pet(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remover_foto_pet(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_salvar_foto_veiculo(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remover_foto_veiculo(UUID, TEXT) TO authenticated;
