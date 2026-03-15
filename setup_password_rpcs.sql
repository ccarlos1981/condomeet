-- ================================================================
-- FLUXO "ATUALIZE SUA SENHA" — Moradores Migrados
-- Execute este script no Supabase NOVO → SQL Editor
-- ================================================================

-- 1. Verifica se o email precisa configurar senha (chamável sem autenticação)
CREATE OR REPLACE FUNCTION check_needs_password_setup(user_email TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM perfil 
    WHERE email = lower(trim(user_email)) 
    AND needs_password_setup = true
  );
END;
$$;
GRANT EXECUTE ON FUNCTION check_needs_password_setup TO anon;
GRANT EXECUTE ON FUNCTION check_needs_password_setup TO authenticated;

-- 2. Define a senha e marca como configurada
CREATE OR REPLACE FUNCTION setup_user_password(user_email TEXT, new_password TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE uid UUID;
BEGIN
  -- Valida que é elegível
  IF NOT EXISTS (
    SELECT 1 FROM perfil 
    WHERE email = lower(trim(user_email)) AND needs_password_setup = true
  ) THEN
    RAISE EXCEPTION 'Not eligible for password setup';
  END IF;

  -- Valida tamanho mínimo da senha
  IF length(new_password) < 4 THEN
    RAISE EXCEPTION 'Password too short';
  END IF;

  -- Busca o ID do usuário no auth
  SELECT id INTO uid FROM auth.users WHERE email = lower(trim(user_email));
  IF uid IS NULL THEN
    RAISE EXCEPTION 'User not found in auth';
  END IF;

  -- Atualiza a senha
  UPDATE auth.users 
  SET encrypted_password = crypt(new_password, gen_salt('bf')),
      updated_at = now()
  WHERE id = uid;

  -- Marca como concluído
  UPDATE perfil 
  SET needs_password_setup = false 
  WHERE email = lower(trim(user_email));
END;
$$;
GRANT EXECUTE ON FUNCTION setup_user_password TO anon;
GRANT EXECUTE ON FUNCTION setup_user_password TO authenticated;
