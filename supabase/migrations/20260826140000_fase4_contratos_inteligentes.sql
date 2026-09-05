-- ============================================================================
-- MIGRATION: FASE 4.1 — CONTRATOS INTELIGENTES (FUNDAÇÃO E BANCO)
-- Data: 26/08/2026
-- Objetivo: Evolução estrutural do módulo Contratos com vínculo de fornecedor,
--           valor mensal, vigência por prazo indeterminado, constraints e RLS.
-- ============================================================================

-- 1. Evolução da tabela public.fornecedores (Adição de campo ativo para soft-delete)
ALTER TABLE public.fornecedores
  ADD COLUMN IF NOT EXISTS ativo BOOLEAN NOT NULL DEFAULT true;

-- 2. Novas Colunas em public.contratos
ALTER TABLE public.contratos
  ADD COLUMN IF NOT EXISTS fornecedor_id UUID REFERENCES public.fornecedores(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS fornecedor_nome TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS valor_mensal NUMERIC(12,2) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS sem_validade BOOLEAN NOT NULL DEFAULT false;

-- 3. Constraints de Integridade em public.contratos

-- 3.1. Precedência e Isolamento Canônico de Fornecedor:
--      fornecedor_id (canônico) e fornecedor_nome (avulso) são mutuamente exclusivos.
ALTER TABLE public.contratos
  DROP CONSTRAINT IF EXISTS check_contratos_fornecedor_consistente;

ALTER TABLE public.contratos
  ADD CONSTRAINT check_contratos_fornecedor_consistente CHECK (
    fornecedor_id IS NULL OR fornecedor_nome IS NULL
  );

-- 3.2. Consistência de Sem Validade:
--      Se sem_validade = true, data_validade DEVE ser NULL e lembretes DEVEM ser false.
ALTER TABLE public.contratos
  DROP CONSTRAINT IF EXISTS check_contratos_sem_validade_consistente;

ALTER TABLE public.contratos
  ADD CONSTRAINT check_contratos_sem_validade_consistente CHECK (
    sem_validade = false
    OR (
      data_validade IS NULL
      AND lembrar_30 = false
      AND lembrar_60 = false
      AND lembrar_90 = false
    )
  );

-- 3.3. Valor Positivo:
--      valor_mensal deve ser NULL ou >= 0.
ALTER TABLE public.contratos
  DROP CONSTRAINT IF EXISTS check_contratos_valor_positivo;

ALTER TABLE public.contratos
  ADD CONSTRAINT check_contratos_valor_positivo CHECK (
    valor_mensal IS NULL OR valor_mensal >= 0
  );

-- 4. Índices de Performance e Consulta
CREATE INDEX IF NOT EXISTS idx_contratos_condo_validade 
  ON public.contratos(condominio_id, data_validade);

CREATE INDEX IF NOT EXISTS idx_contratos_fornecedor_id 
  ON public.contratos(fornecedor_id);

-- 5. Trigger de Segurança Multi-Tenant (Fornecedor x Condomínio)
CREATE OR REPLACE FUNCTION public.fn_contratos_fornecedor_condo_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_fornecedor_condo UUID;
BEGIN
  IF NEW.fornecedor_id IS NOT NULL THEN
    SELECT condominio_id INTO v_fornecedor_condo
    FROM public.fornecedores
    WHERE id = NEW.fornecedor_id;

    IF v_fornecedor_condo IS NULL OR v_fornecedor_condo != NEW.condominio_id THEN
      RAISE EXCEPTION 'VIOLAÇÃO MULTI-TENANT: O fornecedor % não pertence ao condomínio %',
        NEW.fornecedor_id, NEW.condominio_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_contratos_fornecedor_condo_guard ON public.contratos;
CREATE TRIGGER tr_contratos_fornecedor_condo_guard
  BEFORE INSERT OR UPDATE OF fornecedor_id, condominio_id ON public.contratos
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_contratos_fornecedor_condo_guard();

-- 6. Trigger de Proteção contra Deleção de Fornecedor com Contratos Vinculados
CREATE OR REPLACE FUNCTION public.fn_fornecedores_delete_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.contratos
  WHERE fornecedor_id = OLD.id;

  IF v_count > 0 THEN
    RAISE EXCEPTION 'BLOQUEIO DE INTEGRIDADE: Não é permitido excluir o fornecedor "%" pois existem % contrato(s) vinculados a ele. Desative-o alterando ativo = false.',
      OLD.nome, v_count;
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS tr_fornecedores_delete_guard ON public.fornecedores;
CREATE TRIGGER tr_fornecedores_delete_guard
  BEFORE DELETE ON public.fornecedores
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_fornecedores_delete_guard();

-- 7. RLS em public.contratos com Função Canônica is_admin_of_condo
ALTER TABLE public.contratos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_contratos_all" ON public.contratos;
DROP POLICY IF EXISTS "contratos_select_policy" ON public.contratos;
DROP POLICY IF EXISTS "contratos_admin_mutation_policy" ON public.contratos;
DROP POLICY IF EXISTS "contratos_moradores_select_policy" ON public.contratos;

-- 7.1. Política de Seleção:
--      Administradores/Síndicos visualizam todos os contratos do condomínio.
--      Moradores visualizam apenas contratos com mostrar_moradores = true no seu condomínio.
CREATE POLICY "contratos_select_policy" ON public.contratos
  FOR SELECT TO authenticated
  USING (
    (
      auth.uid() IS NOT NULL
      AND condominio_id = (SELECT perfil.condominio_id FROM public.perfil WHERE perfil.id = auth.uid())
      AND mostrar_moradores = true
    )
    OR public.is_admin_of_condo(condominio_id)
  );

-- 7.2. Política de Mutação (INSERT / UPDATE / DELETE):
--      Exclusiva para administradores do condomínio autenticado via is_admin_of_condo.
CREATE POLICY "contratos_admin_mutation_policy" ON public.contratos
  FOR ALL TO authenticated
  USING (
    auth.uid() IS NOT NULL
    AND public.is_admin_of_condo(condominio_id)
  )
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND public.is_admin_of_condo(condominio_id)
  );
