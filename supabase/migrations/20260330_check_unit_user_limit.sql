-- Migration: Limite de 4 usuários aprovados por unidade
-- Cria uma RPC que verifica quantos perfis aprovados existem em uma unidade específica.
-- Usada durante o cadastro para bloquear registro quando a unidade já tem 4 aprovados.

CREATE OR REPLACE FUNCTION public.check_unit_user_limit(
  p_condominio_id UUID,
  p_bloco_id UUID,
  p_apartamento_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_unidade_id UUID;
  v_count INTEGER;
  v_limit INTEGER := 4;
BEGIN
  -- 1. Busca a unidade
  SELECT id INTO v_unidade_id
  FROM unidades
  WHERE condominio_id = p_condominio_id
    AND bloco_id = p_bloco_id
    AND apartamento_id = p_apartamento_id
  LIMIT 1;

  IF v_unidade_id IS NULL THEN
    RETURN json_build_object('allowed', false, 'count', 0, 'limit', v_limit, 'error', 'Unidade não encontrada');
  END IF;

  -- 2. Conta os perfis APROVADOS vinculados a essa unidade
  SELECT COUNT(*) INTO v_count
  FROM unidade_perfil up
  JOIN perfil p ON p.id = up.perfil_id
  WHERE up.unidade_id = v_unidade_id
    AND p.status_aprovacao = 'aprovado';

  -- 3. Retorna o resultado
  IF v_count >= v_limit THEN
    RETURN json_build_object('allowed', false, 'count', v_count, 'limit', v_limit, 'error', NULL);
  ELSE
    RETURN json_build_object('allowed', true, 'count', v_count, 'limit', v_limit, 'error', NULL);
  END IF;
END;
$$;

-- Permite que usuários anônimos (durante cadastro) e autenticados chamem a função
GRANT EXECUTE ON FUNCTION public.check_unit_user_limit(UUID, UUID, UUID) TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.check_unit_user_limit IS 
'Verifica se uma unidade já atingiu o limite de 4 usuários aprovados. Retorna JSON com allowed, count, limit.';
