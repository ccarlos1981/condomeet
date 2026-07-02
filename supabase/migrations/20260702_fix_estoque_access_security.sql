-- Migration: corrige has_estoque_access para SECURITY INVOKER
-- Data: 2026-07-02
-- Motivo: A função estava definida como SECURITY DEFINER sem SET search_path,
--         fazendo com que auth.uid() retornasse NULL dentro do contexto de
--         avaliação das políticas RLS (INSERT/UPDATE), causando o erro:
--         "new row violates row-level security policy for table estoque_categorias"
--
-- Solução: trocar para SECURITY INVOKER, que é o padrão recomendado pelo Supabase
--         para funções helper usadas em políticas RLS. Com SECURITY INVOKER,
--         a função roda com o contexto do usuário autenticado, e auth.uid()
--         retorna o UID correto.

CREATE OR REPLACE FUNCTION has_estoque_access(p_condo_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM perfil p 
    WHERE p.id = auth.uid() 
    AND p.condominio_id = p_condo_id
    AND (
      p.papel_sistema ILIKE '%síndico%' 
      OR p.papel_sistema ILIKE '%sindico%' 
      OR p.papel_sistema ILIKE '%admin%'
      OR p.papel_sistema ILIKE '%super_admin%'
      OR p.papel_sistema ILIKE '%zelador%'
      OR p.papel_sistema ILIKE '%funcionario%'
      OR p.papel_sistema ILIKE '%funcionário%'
      OR p.papel_sistema ILIKE '%porteiro%'
    )
  );
END;
$$;
