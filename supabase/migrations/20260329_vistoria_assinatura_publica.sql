-- ============================================================
-- Migration: 20260329_vistoria_assinatura_publica
-- Assinatura pública de vistorias via link externo
-- Permite que inquilinos/proprietários assinem via navegador
-- ============================================================

-- ════════════════════════════════════════
-- 1. RPC: Buscar vistoria pública pelo token
-- Retorna todos os dados necessários para exibição
-- ════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_vistoria_publica(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_vistoria record;
  v_result jsonb;
  v_secoes jsonb;
  v_assinaturas jsonb;
  v_condo_nome text;
BEGIN
  -- Buscar vistoria pelo token
  SELECT * INTO v_vistoria
  FROM vistorias
  WHERE link_publico_token = p_token;

  IF v_vistoria IS NULL THEN
    RETURN NULL;
  END IF;

  -- Buscar nome do condomínio
  SELECT nome INTO v_condo_nome
  FROM condominios
  WHERE id = v_vistoria.condominio_id;

  -- Buscar seções com itens e fotos
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', s.id,
      'nome', s.nome,
      'icone_emoji', s.icone_emoji,
      'posicao', s.posicao,
      'itens', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', i.id,
            'nome', i.nome,
            'status', i.status,
            'observacao', i.observacao,
            'posicao', i.posicao,
            'fotos', COALESCE((
              SELECT jsonb_agg(
                jsonb_build_object(
                  'id', f.id,
                  'foto_url', f.foto_url,
                  'legenda', f.legenda
                ) ORDER BY f.posicao
              )
              FROM vistoria_fotos f WHERE f.item_id = i.id
            ), '[]'::jsonb)
          ) ORDER BY i.posicao
        )
        FROM vistoria_itens i WHERE i.secao_id = s.id
      ), '[]'::jsonb)
    ) ORDER BY s.posicao
  ), '[]'::jsonb) INTO v_secoes
  FROM vistoria_secoes s
  WHERE s.vistoria_id = v_vistoria.id;

  -- Buscar assinaturas existentes
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'nome', a.nome,
      'papel', a.papel,
      'assinatura_url', a.assinatura_url,
      'email', a.email,
      'cpf', a.cpf,
      'assinado_em', a.assinado_em
    )
  ), '[]'::jsonb) INTO v_assinaturas
  FROM vistoria_assinaturas a
  WHERE a.vistoria_id = v_vistoria.id;

  -- Montar resultado
  v_result := jsonb_build_object(
    'id', v_vistoria.id,
    'titulo', v_vistoria.titulo,
    'tipo_bem', v_vistoria.tipo_bem,
    'tipo_vistoria', v_vistoria.tipo_vistoria,
    'endereco', v_vistoria.endereco,
    'cod_interno', v_vistoria.cod_interno,
    'status', v_vistoria.status,
    'responsavel_nome', v_vistoria.responsavel_nome,
    'proprietario_nome', v_vistoria.proprietario_nome,
    'inquilino_nome', v_vistoria.inquilino_nome,
    'plano', v_vistoria.plano,
    'created_at', v_vistoria.created_at,
    'condo_nome', v_condo_nome,
    'secoes', v_secoes,
    'assinaturas', v_assinaturas
  );

  RETURN v_result;
END;
$$;

-- ════════════════════════════════════════
-- 2. Adicionar coluna CPF na tabela de assinaturas
-- ════════════════════════════════════════
ALTER TABLE public.vistoria_assinaturas
  ADD COLUMN IF NOT EXISTS cpf text;

-- ════════════════════════════════════════
-- 3. RPC: Assinar vistoria publicamente
-- Grava assinatura + atualiza status
-- ════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.assinar_vistoria_publica(
  p_token text,
  p_nome text,
  p_cpf text,
  p_email text,
  p_papel text,
  p_assinatura_url text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_vistoria_id uuid;
  v_vistoria_status text;
  v_assinatura_id uuid;
BEGIN
  -- Buscar vistoria pelo token
  SELECT id, status INTO v_vistoria_id, v_vistoria_status
  FROM vistorias
  WHERE link_publico_token = p_token;

  IF v_vistoria_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Vistoria não encontrada');
  END IF;

  -- Verificar se já está assinada (não permitir duplicatas do mesmo email)
  IF EXISTS (
    SELECT 1 FROM vistoria_assinaturas
    WHERE vistoria_id = v_vistoria_id
      AND email = p_email
      AND assinatura_url IS NOT NULL
  ) THEN
    RETURN jsonb_build_object('error', 'Este e-mail já assinou esta vistoria');
  END IF;

  -- Inserir assinatura
  INSERT INTO vistoria_assinaturas (
    vistoria_id, nome, papel, assinatura_url, email, cpf, assinado_em
  ) VALUES (
    v_vistoria_id, p_nome, p_papel, p_assinatura_url, p_email, p_cpf, NOW()
  ) RETURNING id INTO v_assinatura_id;

  -- Atualizar status da vistoria para 'assinada'
  UPDATE vistorias
  SET status = 'assinada', updated_at = NOW()
  WHERE id = v_vistoria_id;

  RETURN jsonb_build_object(
    'success', true,
    'assinatura_id', v_assinatura_id
  );
END;
$$;

-- ════════════════════════════════════════
-- 4. Grants: Permitir chamada anônima das RPCs
-- (necessário para acesso via web sem login)
-- ════════════════════════════════════════
GRANT EXECUTE ON FUNCTION public.get_vistoria_publica(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_vistoria_publica(text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.assinar_vistoria_publica(text, text, text, text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.assinar_vistoria_publica(text, text, text, text, text, text) TO authenticated;
