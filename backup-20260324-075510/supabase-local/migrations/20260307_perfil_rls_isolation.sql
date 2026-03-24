-- Migration: Perfil RLS — Isolamento por condomínio
-- Garante que NUNCA um perfil de um condomínio seja visível para outro condomínio.

-- Habilitar RLS na tabela perfil (se ainda não estiver ativa)
ALTER TABLE public.perfil ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- POLÍTICA 1: Usuário pode ver o seu próprio perfil
-- ============================================================
DROP POLICY IF EXISTS "Perfil: ver proprio perfil" ON public.perfil;
CREATE POLICY "Perfil: ver proprio perfil"
ON public.perfil FOR SELECT
USING (id = auth.uid());

-- ============================================================
-- POLÍTICA 2: Síndico/Admin/Portaria podem ver perfis do SEU condomínio
-- ============================================================
DROP POLICY IF EXISTS "Perfil: gestor ve perfis do condominio" ON public.perfil;
CREATE POLICY "Perfil: gestor ve perfis do condominio"
ON public.perfil FOR SELECT
USING (
  condominio_id IN (
    SELECT condominio_id FROM public.perfil
    WHERE id = auth.uid()
    AND papel_sistema IN ('Síndico', 'ADMIN', 'Portaria', 'Zelador', 'Funcionário')
  )
);

-- ============================================================
-- POLÍTICA 3: Usuário pode ATUALIZAR apenas o seu próprio perfil
-- ============================================================
DROP POLICY IF EXISTS "Perfil: atualizar proprio perfil" ON public.perfil;
CREATE POLICY "Perfil: atualizar proprio perfil"
ON public.perfil FOR UPDATE
USING (id = auth.uid());

-- ============================================================
-- POLÍTICA 4: Síndico/Admin pode ATUALIZAR perfis do seu condomínio
-- (para aprovar, bloquear, etc.)
-- ============================================================
DROP POLICY IF EXISTS "Perfil: gestor atualiza perfis do condominio" ON public.perfil;
CREATE POLICY "Perfil: gestor atualiza perfis do condominio"
ON public.perfil FOR UPDATE
USING (
  condominio_id IN (
    SELECT condominio_id FROM public.perfil
    WHERE id = auth.uid()
    AND papel_sistema IN ('Síndico', 'ADMIN')
  )
);

-- ============================================================
-- POLÍTICA 5: INSERT — qualquer usuário autenticado pode criar perfil
-- (durante o cadastro, antes de ter papel definido)
-- ============================================================
DROP POLICY IF EXISTS "Perfil: criar proprio perfil" ON public.perfil;
CREATE POLICY "Perfil: criar proprio perfil"
ON public.perfil FOR INSERT
WITH CHECK (id = auth.uid());
