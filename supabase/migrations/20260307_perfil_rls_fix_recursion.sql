-- Fix: Perfil RLS — Corrige recursão infinita
-- O problema: policies que fazem SELECT em "perfil" dentro de policies de "perfil" causam loop.
-- Solução: função SECURITY DEFINER que burla RLS ao buscar condominio_id do usuário atual.

-- ============================================================
-- 1. Dropar as policies recursivas criadas antes
-- ============================================================
DROP POLICY IF EXISTS "Perfil: ver proprio perfil" ON public.perfil;
DROP POLICY IF EXISTS "Perfil: gestor ve perfis do condominio" ON public.perfil;
DROP POLICY IF EXISTS "Perfil: atualizar proprio perfil" ON public.perfil;
DROP POLICY IF EXISTS "Perfil: gestor atualiza perfis do condominio" ON public.perfil;
DROP POLICY IF EXISTS "Perfil: criar proprio perfil" ON public.perfil;

-- ============================================================
-- 2. Função auxiliar SECURITY DEFINER (não aciona RLS ao executar)
-- Retorna o condominio_id do usuário atual sem causar recursão.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_meu_condominio_id()
RETURNS UUID
LANGUAGE SQL
SECURITY DEFINER
STABLE
AS $$
  SELECT condominio_id FROM public.perfil WHERE id = auth.uid() LIMIT 1;
$$;

-- ============================================================
-- 3. Recriar policies SEM recursão
-- ============================================================

-- SELECT: usuário vê o próprio perfil
CREATE POLICY "Perfil: ver proprio perfil"
ON public.perfil FOR SELECT
USING (id = auth.uid());

-- SELECT: gestor vê todos os perfis do seu condomínio
CREATE POLICY "Perfil: gestor ve perfis do condominio"
ON public.perfil FOR SELECT
USING (condominio_id = public.get_meu_condominio_id());

-- UPDATE: usuário atualiza o próprio perfil
CREATE POLICY "Perfil: atualizar proprio perfil"
ON public.perfil FOR UPDATE
USING (id = auth.uid());

-- UPDATE: síndico/admin atualiza qualquer perfil do seu condomínio
-- (usa a função para evitar recursão)
CREATE POLICY "Perfil: gestor atualiza perfis do condominio"
ON public.perfil FOR UPDATE
USING (
  condominio_id = public.get_meu_condominio_id()
  AND EXISTS (
    SELECT 1 FROM public.perfil p2
    WHERE p2.id = auth.uid()
      AND p2.papel_sistema IN ('Síndico', 'ADMIN')
      AND p2.condominio_id = public.perfil.condominio_id
  )
);

-- INSERT: qualquer autenticado pode criar o próprio perfil
CREATE POLICY "Perfil: criar proprio perfil"
ON public.perfil FOR INSERT
WITH CHECK (id = auth.uid());
