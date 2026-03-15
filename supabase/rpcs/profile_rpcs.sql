-- =============================================
-- RPCs: change_apartment + update_profile
-- Rodar no Supabase SQL Editor
-- =============================================

-- RPC 1: Mudar de Apartamento
-- Valida a unidade, inativa vínculo antigo, cria novo, bloqueia morador
CREATE OR REPLACE FUNCTION change_apartment(
  p_user_id UUID,
  p_new_bloco_txt TEXT,
  p_new_apto_txt TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_condo_id UUID;
  v_bloco_id UUID;
  v_apto_id UUID;
  v_unidade_id UUID;
  v_old_bloco TEXT;
  v_old_apto TEXT;
BEGIN
  -- 1. Buscar condomínio do morador
  SELECT condominio_id, bloco_txt, apto_txt
  INTO v_condo_id, v_old_bloco, v_old_apto
  FROM perfil
  WHERE id = p_user_id;

  IF v_condo_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Perfil não encontrado');
  END IF;

  -- 2. Se é o mesmo bloco+apto, não faz nada
  IF LOWER(TRIM(v_old_bloco)) = LOWER(TRIM(p_new_bloco_txt)) 
     AND LOWER(TRIM(v_old_apto)) = LOWER(TRIM(p_new_apto_txt)) THEN
    RETURN json_build_object('success', false, 'error', 'Você já está neste apartamento');
  END IF;

  -- 3. Validar: o bloco existe?
  SELECT id INTO v_bloco_id
  FROM blocos
  WHERE condominio_id = v_condo_id
    AND LOWER(TRIM(nome_ou_numero)) = LOWER(TRIM(p_new_bloco_txt));

  IF v_bloco_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bloco não encontrado: ' || p_new_bloco_txt);
  END IF;

  -- 4. Validar: o apartamento existe?
  SELECT id INTO v_apto_id
  FROM apartamentos
  WHERE condominio_id = v_condo_id
    AND LOWER(TRIM(numero)) = LOWER(TRIM(p_new_apto_txt));

  IF v_apto_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Apartamento não encontrado: ' || p_new_apto_txt);
  END IF;

  -- 5. Validar: a unidade (bloco+apto) existe?
  SELECT id INTO v_unidade_id
  FROM unidades
  WHERE condominio_id = v_condo_id
    AND bloco_id = v_bloco_id
    AND apartamento_id = v_apto_id;

  IF v_unidade_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unidade não encontrada para este bloco/apartamento');
  END IF;

  -- 6. Inativar vínculo(s) antigo(s)
  UPDATE unidade_perfil
  SET status = 'inativo',
      data_saida = now()
  WHERE perfil_id = p_user_id
    AND status = 'ativo';

  -- 7. Criar novo vínculo
  INSERT INTO unidade_perfil (perfil_id, unidade_id, status, data_entrada)
  VALUES (p_user_id, v_unidade_id, 'ativo', now())
  ON CONFLICT (perfil_id, unidade_id) DO UPDATE
  SET status = 'ativo', data_entrada = now(), data_saida = NULL;

  -- 8. Atualizar perfil
  UPDATE perfil
  SET bloco_txt = p_new_bloco_txt,
      apto_txt = p_new_apto_txt,
      status_aprovacao = 'pendente',
      updated_at = now()
  WHERE id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Apartamento alterado. Aguarde aprovação do síndico.',
    'old_bloco', v_old_bloco,
    'old_apto', v_old_apto,
    'new_bloco', p_new_bloco_txt,
    'new_apto', p_new_apto_txt
  );
END;
$$;

-- RPC 2: Atualizar Perfil (sem mudar apto)
-- Edita nome, whatsapp, tipo_morador
CREATE OR REPLACE FUNCTION update_profile(
  p_user_id UUID,
  p_nome_completo TEXT DEFAULT NULL,
  p_whatsapp TEXT DEFAULT NULL,
  p_tipo_morador TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE perfil
  SET nome_completo  = COALESCE(p_nome_completo, nome_completo),
      whatsapp       = COALESCE(p_whatsapp, whatsapp),
      tipo_morador   = COALESCE(p_tipo_morador, tipo_morador),
      updated_at     = now()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Perfil não encontrado');
  END IF;

  RETURN json_build_object('success', true, 'message', 'Perfil atualizado com sucesso');
END;
$$;
