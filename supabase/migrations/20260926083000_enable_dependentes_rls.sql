-- ==============================================================================
-- Migration: 20260926083000_enable_dependentes_rls.sql
-- Module: Base Cadastral 360º — Gate 3G.2-A (Parte 2A)
-- Scope: Habilitação de RLS e Policies Mínimas de SELECT para Dependentes
-- ==============================================================================

-- 1. Habilitar Row Level Security na tabela canônica de dependentes
ALTER TABLE public.dependentes ENABLE ROW LEVEL SECURITY;

-- 2. Policy SELECT: SuperAdmin Global
CREATE POLICY dependentes_superadmin_select
ON public.dependentes
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.system_superadmins ss
        WHERE lower(ss.email) = lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text))
    )
);

-- 3. Policy SELECT: Administração do Condomínio
CREATE POLICY dependentes_admin_select
ON public.dependentes
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.perfil p
        WHERE p.id = auth.uid()
          AND p.condominio_id = dependentes.condominio_id
          AND p.status_aprovacao = 'aprovado'
          AND COALESCE(p.bloqueado, false) = false
          AND lower(COALESCE(p.papel_sistema, ''::text)) = ANY (ARRAY[
              'admin'::text,
              'síndico'::text,
              'sindico'::text,
              'subsíndico'::text,
              'subsindico'::text,
              'administradora'::text
          ])
    )
);

-- 4. Policy SELECT: Responsável pelo Dependente
CREATE POLICY dependentes_responsavel_select
ON public.dependentes
FOR SELECT
TO authenticated
USING (
    responsavel_perfil_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.unidade_perfil up
        JOIN public.perfil p ON p.id = up.perfil_id
        WHERE up.perfil_id = auth.uid()
          AND up.unidade_id = dependentes.unidade_id
          AND up.status = 'ativo'
          AND p.condominio_id = dependentes.condominio_id
          AND p.status_aprovacao = 'aprovado'
          AND COALESCE(p.bloqueado, false) = false
    )
);
