-- ============================================================================
-- GATE 3D.2-B.1: HOTFIX RLS SELECT PUBLIC.VEICULOS
-- ============================================================================
-- Objetivo: Corrigir a policy veiculos_admin_select para eliminar dependência
-- direta de leitura da tabela auth.users pela role authenticated.
--
-- Causa raiz:
-- O JOIN com auth.users em RLS para a role authenticated causava ERROR 42501
-- (permission denied for table users), pois authenticated não tem SELECT em auth.users.
--
-- Correção canônica (ADR-002 / padrão Condomeet):
-- Utilizar auth.jwt() ->> 'email' para validar contra public.system_superadmins,
-- preservando a regra de tenant e acesso administrativo local do condomínio.
-- ============================================================================

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
        WHERE LOWER(ss.email) = LOWER(COALESCE((auth.jwt() ->> 'email'::text), ''))
    )
);

COMMENT ON POLICY veiculos_admin_select ON public.veiculos IS 
'Permite leitura de veículos por administradores do mesmo condomínio e superadmins globais via JWT claim sem ler auth.users diretamente.';
