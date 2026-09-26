-- ==============================================================================
-- CONDOMEET — BASE CADASTRAL 360º — GATE 3J
-- INFRAESTRUTURA CANÔNICA DE FOTO DO MORADOR
-- Migration: 20260926160000_create_admin_resident_photo_infrastructure.sql
-- 
-- Arquitetura:
-- 1. Evolução da Storage RLS policy para autorizar moradores em base-cadastral-media
-- 2. RPC administrativa transacional public.admin_salvar_foto_morador
-- 3. RPC administrativa transacional public.admin_remover_foto_morador
-- 4. Trilha de auditoria em public.perfil_audit_log (RESIDENT_PHOTO_UPDATED / RESIDENT_PHOTO_REMOVED)
-- 5. Imutabilidade estrita de perfis inativos (ex-moradores)
-- ==============================================================================

-- 1. EVOLUÇÃO DA STORAGE RLS POLICY (UPLOAD EM BASE-CADASTRAL-MEDIA)
DROP POLICY IF EXISTS "base_cadastral_media_insert" ON storage.objects;
CREATE POLICY "base_cadastral_media_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'base-cadastral-media'
    AND split_part(name, '/', 2) IN ('pets', 'veiculos', 'moradores')
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

-- 2. RPCS ADMINISTRATIVAS TRANSACIONAIS — MÓDULO MORADORES

-- 2.1 public.admin_salvar_foto_morador
CREATE OR REPLACE FUNCTION public.admin_salvar_foto_morador(
    p_perfil_id UUID,
    p_foto_path TEXT,
    p_motivo TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', pg_temp
AS $$
DECLARE
    v_operator_id UUID;
    v_is_superadmin BOOLEAN;
    v_op RECORD;
    v_resident RECORD;
    v_path_condo TEXT;
    v_path_entity TEXT;
    v_path_entity_id TEXT;
    v_path_filename TEXT;
    v_foto_path_anterior TEXT;
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

    -- 3. Validar operador local do condomínio (caso não seja SuperAdmin)
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

        IF LOWER(COALESCE(v_op.papel_sistema, '')) NOT IN ('admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora') THEN
            RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem atualizar fotos de moradores.';
        END IF;
    END IF;

    -- 4. Parâmetros obrigatórios
    IF p_perfil_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do morador é obrigatório.';
    END IF;

    IF p_foto_path IS NULL OR TRIM(p_foto_path) = '' THEN
        RAISE EXCEPTION 'O caminho da foto (foto_path) é obrigatório.';
    END IF;

    -- 5. Localizar e travar perfil alvo com FOR UPDATE
    SELECT id, condominio_id, nome_completo, foto_url, status_aprovacao, bloqueado
    INTO v_resident
    FROM public.perfil
    WHERE id = p_perfil_id
    FOR UPDATE;

    IF v_resident.id IS NULL THEN
        RAISE EXCEPTION 'Morador alvo não encontrado.';
    END IF;

    -- 6. Isolamento multi-tenant estrito
    IF NOT v_is_superadmin AND v_resident.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    -- 7. Invariante soberana: Inativo = Histórico Imutável
    IF v_resident.status_aprovacao = 'inativo' THEN
        RAISE EXCEPTION 'Operação não permitida. O morador encontra-se inativo e seu registro histórico é imutável.';
    END IF;

    -- 8. Validação rígida da estrutura canônica do path: {condominio_id}/moradores/{perfil_id}/{filename}
    v_path_condo     := split_part(TRIM(p_foto_path), '/', 1);
    v_path_entity    := split_part(TRIM(p_foto_path), '/', 2);
    v_path_entity_id := split_part(TRIM(p_foto_path), '/', 3);
    v_path_filename  := split_part(TRIM(p_foto_path), '/', 4);

    IF v_path_condo IS DISTINCT FROM v_resident.condominio_id::text THEN
        RAISE EXCEPTION 'Caminho inválido. O condomínio no path diverge do condomínio do morador.';
    END IF;

    IF v_path_entity IS DISTINCT FROM 'moradores' THEN
        RAISE EXCEPTION 'Caminho inválido. A entidade no path deve ser "moradores".';
    END IF;

    IF v_path_entity_id IS DISTINCT FROM v_resident.id::text THEN
        RAISE EXCEPTION 'Caminho inválido. O identificador do morador no path diverge do morador informado.';
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

    -- 9. Atualização do registro
    v_foto_path_anterior := v_resident.foto_url;

    UPDATE public.perfil
    SET foto_url = TRIM(p_foto_path),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_perfil_id;

    -- 10. Auditoria atômica obrigatória em public.perfil_audit_log
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
        v_resident.condominio_id,
        p_perfil_id,
        v_operator_id,
        NULL,
        'RESIDENT_PHOTO_UPDATED',
        COALESCE(NULLIF(TRIM(p_motivo), ''), 'Atualização de foto do morador'),
        jsonb_build_object(
            'foto_url', v_foto_path_anterior
        ),
        jsonb_build_object(
            'foto_url', TRIM(p_foto_path)
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'perfil_id', v_resident.id,
        'foto_path_anterior', v_foto_path_anterior,
        'foto_path_novo', TRIM(p_foto_path)
    );
END;
$$;

-- 2.2 public.admin_remover_foto_morador
CREATE OR REPLACE FUNCTION public.admin_remover_foto_morador(
    p_perfil_id UUID,
    p_motivo TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', pg_temp
AS $$
DECLARE
    v_operator_id UUID;
    v_is_superadmin BOOLEAN;
    v_op RECORD;
    v_resident RECORD;
    v_foto_path_anterior TEXT;
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

    -- 3. Validar operador local do condomínio (caso não seja SuperAdmin)
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

        IF LOWER(COALESCE(v_op.papel_sistema, '')) NOT IN ('admin', 'síndico', 'sindico', 'subsíndico', 'subsindico', 'administradora') THEN
            RAISE EXCEPTION 'Permissão negada. Apenas síndicos e administradores podem remover fotos de moradores.';
        END IF;
    END IF;

    -- 4. Parâmetros obrigatórios
    IF p_perfil_id IS NULL THEN
        RAISE EXCEPTION 'O identificador do morador é obrigatório.';
    END IF;

    -- 5. Localizar e travar perfil alvo com FOR UPDATE
    SELECT id, condominio_id, nome_completo, foto_url, status_aprovacao, bloqueado
    INTO v_resident
    FROM public.perfil
    WHERE id = p_perfil_id
    FOR UPDATE;

    IF v_resident.id IS NULL THEN
        RAISE EXCEPTION 'Morador alvo não encontrado.';
    END IF;

    -- 6. Isolamento multi-tenant estrito
    IF NOT v_is_superadmin AND v_resident.condominio_id IS DISTINCT FROM v_op.condominio_id THEN
        RAISE EXCEPTION 'Violação multi-tenant. O morador alvo pertence a outro condomínio.';
    END IF;

    -- 7. Invariante soberana: Inativo = Histórico Imutável
    IF v_resident.status_aprovacao = 'inativo' THEN
        RAISE EXCEPTION 'Operação não permitida. O morador encontra-se inativo e seu registro histórico é imutável.';
    END IF;

    v_foto_path_anterior := v_resident.foto_url;

    -- 8. Se não havia foto cadastrada, encerra com sucesso idempotente
    IF v_foto_path_anterior IS NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'perfil_id', v_resident.id,
            'foto_path_anterior', NULL
        );
    END IF;

    -- 9. Remover referência no banco
    UPDATE public.perfil
    SET foto_url = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_perfil_id;

    -- 10. Auditoria atômica obrigatória em public.perfil_audit_log
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
        v_resident.condominio_id,
        p_perfil_id,
        v_operator_id,
        NULL,
        'RESIDENT_PHOTO_REMOVED',
        COALESCE(NULLIF(TRIM(p_motivo), ''), 'Remoção de foto do morador'),
        jsonb_build_object(
            'foto_url', v_foto_path_anterior
        ),
        jsonb_build_object(
            'foto_url', NULL
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'perfil_id', v_resident.id,
        'foto_path_anterior', v_foto_path_anterior
    );
END;
$$;

-- 3. PERMISSÕES DE EXECUÇÃO
REVOKE EXECUTE ON FUNCTION public.admin_salvar_foto_morador(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_salvar_foto_morador(UUID, TEXT, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_remover_foto_morador(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_remover_foto_morador(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.admin_salvar_foto_morador(UUID, TEXT, TEXT) IS 'Salva o storage path relativo da foto do morador no bucket base-cadastral-media com guard multi-tenant e auditoria atômica RESIDENT_PHOTO_UPDATED (Gate 3J)';
COMMENT ON FUNCTION public.admin_remover_foto_morador(UUID, TEXT) IS 'Remove a foto do morador com guard multi-tenant e auditoria atômica RESIDENT_PHOTO_REMOVED (Gate 3J)';
