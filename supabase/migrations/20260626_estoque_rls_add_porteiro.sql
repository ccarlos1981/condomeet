-- Migration: adiciona 'porteiro' aos papéis com acesso ao módulo de estoque
-- Data: 2026-06-26
-- Motivo: Porteiro não estava incluído na função has_estoque_access(),
--         causando erro 403 (RLS violation) ao tentar acessar o estoque.
-- CORRIGIDO (2026-07-02): SECURITY DEFINER → SECURITY INVOKER para que
--         auth.uid() funcione corretamente dentro de políticas RLS.

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
