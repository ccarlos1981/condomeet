-- ============================================================================
-- Migration: 20260826130000_evolucao_modulo_documentos.sql
-- Descrição: Evolução Estrutural do Módulo Documentos — Tipos Configuráveis,
--            Priorização por Condomínio, Integridade Multi-Tenant e Anti-Duplicidade.
-- ============================================================================

-- ── 1. TABELA DE TIPOS DE DOCUMENTOS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.documento_tipos (
  id                        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id             UUID        REFERENCES public.condominios(id) ON DELETE CASCADE,
  nome                      TEXT        NOT NULL,
  descricao                 TEXT,
  categoria_padrao          TEXT        NOT NULL DEFAULT 'Outros',
  icone                     TEXT        NOT NULL DEFAULT 'file-text',
  is_system                 BOOLEAN     NOT NULL DEFAULT false,
  ativo                     BOOLEAN     NOT NULL DEFAULT true,
  ordem                     INTEGER     NOT NULL DEFAULT 100,
  recorrente                BOOLEAN     NOT NULL DEFAULT false,
  normalmente_tem_validade  BOOLEAN     NOT NULL DEFAULT false,
  permite_lembrete          BOOLEAN     NOT NULL DEFAULT true,
  permite_exibir_moradores  BOOLEAN     NOT NULL DEFAULT true,
  permite_notificacao       BOOLEAN     NOT NULL DEFAULT true,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Regra estrutural: tipos de sistema NÃO possuem condomínio; tipos customizados OBRIGATORIAMENTE possuem
  CONSTRAINT check_documento_tipos_is_system_condo CHECK (
    (is_system = true AND condominio_id IS NULL)
    OR
    (is_system = false AND condominio_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_documento_tipos_condo ON public.documento_tipos(condominio_id);
CREATE INDEX IF NOT EXISTS idx_documento_tipos_ativo ON public.documento_tipos(ativo);

-- Unicidade para tipos de sistema
CREATE UNIQUE INDEX IF NOT EXISTS uq_documento_tipos_system_nome
  ON public.documento_tipos(lower(trim(nome)))
  WHERE condominio_id IS NULL;

-- Unicidade para tipos de condomínio
CREATE UNIQUE INDEX IF NOT EXISTS uq_documento_tipos_condo_nome
  ON public.documento_tipos(condominio_id, lower(trim(nome)))
  WHERE condominio_id IS NOT NULL;

-- ── 2. TABELA DE PRIORIZAÇÃO DELIBERADA POR CONDOMÍNIO ───────────────────────
CREATE TABLE IF NOT EXISTS public.documento_tipo_prioridades (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id   UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  tipo_id         UUID        NOT NULL REFERENCES public.documento_tipos(id) ON DELETE CASCADE,
  is_prioritario  BOOLEAN     NOT NULL DEFAULT true,
  ordem           INTEGER     NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_condo_tipo_prioridade UNIQUE (condominio_id, tipo_id)
);

CREATE INDEX IF NOT EXISTS idx_doc_prioridades_condo ON public.documento_tipo_prioridades(condominio_id, ordem);

-- ── 3. EVOLUÇÃO NÃO DESTRUTIVA DA TABELA DOCUMENTOS ──────────────────────────
-- tipo_id = fonte canônica; tipo = campo legado de compatibilidade
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS tipo_id UUID REFERENCES public.documento_tipos(id) ON DELETE SET NULL;
ALTER TABLE public.documentos ADD COLUMN IF NOT EXISTS sem_validade BOOLEAN NOT NULL DEFAULT false;

-- CHECK CONSTRAINT: sem_validade = true exige data_validade IS NULL e todos lembretes = false
DO $$ BEGIN
  ALTER TABLE public.documentos ADD CONSTRAINT check_documentos_sem_validade_consistente
    CHECK (
      sem_validade = false
      OR (
        data_validade IS NULL
        AND lembrar_30 = false
        AND lembrar_60 = false
        AND lembrar_90 = false
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_documentos_tipo_id ON public.documentos(tipo_id);

-- Relaxa a constraint antiga de enum fixo em documentos.tipo sem remover a coluna
ALTER TABLE public.documentos DROP CONSTRAINT IF EXISTS documentos_tipo_check;

-- ── 4. SEED DOS TIPOS PADRÃO DO SISTEMA (IS_SYSTEM = TRUE) ───────────────────
INSERT INTO public.documento_tipos (
  nome, descricao, categoria_padrao, icone, is_system, ordem, recorrente, normalmente_tem_validade
) VALUES
  ('Convenção do Condomínio', 'Estatuto e regras fundamentais do condomínio', 'Institucional', 'book', true, 10, false, false),
  ('Regimento Interno', 'Normas de convivência, uso de áreas e sanções', 'Institucional', 'scroll', true, 20, false, false),
  ('Ata de Assembleia', 'Registro oficial de decisões e deliberações assembleares', 'Assembleia', 'users', true, 30, false, false),
  ('Edital de Convocação', 'Convocação formal de assembleias ordinárias e extraordinárias', 'Assembleia', 'megaphone', true, 40, false, false),
  ('Balancete Mensal', 'Demonstrativo mensal de receitas, despesas e saldo bancário', 'Financeiro', 'dollar-sign', true, 50, true, false),
  ('Prestação de Contas', 'Relatório contábil anual ou periódico para aprovação', 'Financeiro', 'file-spreadsheet', true, 60, true, false),
  ('Previsão Orçamentária', 'Planejamento financeiro e estimativa orçamentária', 'Financeiro', 'bar-chart', true, 70, false, false),
  ('Nota Fiscal / Comprovante', 'Notas fiscais de serviços, produtos e manutenções', 'Fiscal', 'receipt', true, 80, false, false),
  ('Apólice de Seguro', 'Contrato de seguro predial obrigatório e coberturas', 'Segurança', 'shield-check', true, 90, false, true),
  ('AVCB / CLCB (Bombeiros)', 'Auto de Vistoria do Corpo de Bombeiros', 'Segurança', 'flame', true, 100, false, true),
  ('Laudo Técnico / Inspeção', 'Laudos de engenharia, para-raios, gás, estanqueidade, etc.', 'Manutenção', 'clipboard-check', true, 110, false, true),
  ('Certificado de Limpeza / Dedetização', 'Comprovantes periódicos de caixas d''água e pragas', 'Manutenção', 'sparkles', true, 120, true, true),
  ('Licença de Operação / Alvará', 'Alvará de funcionamento e licenças municipais/estaduais', 'Jurídico', 'award', true, 130, false, true),
  ('Planta e Projetos', 'Plantas arquitetônicas, estruturais, elétricas e hidráulicas', 'Obras', 'compass', true, 140, false, false),
  ('Orçamento / Cotação', 'Propostas comerciais de prestadores e fornecedores', 'Financeiro', 'calculator', true, 150, false, false),
  ('Contrato de Prestação de Serviços', 'Contratos de terceirização, portaria, elevadores, etc.', 'Contratos', 'file-signature', true, 160, false, true),
  ('Outros Documentos', 'Documentos administrativos diversos', 'Outros', 'file-text', true, 999, false, false)
ON CONFLICT DO NOTHING;

-- ── 5. GARANTIAS DE INTEGRIDADE MULTI-TENANT NO MOTOR DO POSTGRESQL ──────────

-- 5.1. Isolamento documentos.condominio_id ↔ documentos.tipo_id
CREATE OR REPLACE FUNCTION public.tr_fn_check_documento_tipo_condominio()
RETURNS TRIGGER AS $$
DECLARE
  v_tipo_condo_id UUID;
BEGIN
  IF NEW.tipo_id IS NOT NULL THEN
    SELECT condominio_id INTO v_tipo_condo_id
    FROM public.documento_tipos
    WHERE id = NEW.tipo_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Tipo de documento % não existe.', NEW.tipo_id;
    END IF;

    IF v_tipo_condo_id IS NOT NULL AND v_tipo_condo_id != NEW.condominio_id THEN
      RAISE EXCEPTION 'Violação de isolamento multi-tenant: o tipo de documento % pertence a outro condomínio.', NEW.tipo_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_documentos_tipo_condo_guard ON public.documentos;
CREATE TRIGGER tr_documentos_tipo_condo_guard
  BEFORE INSERT OR UPDATE OF tipo_id, condominio_id ON public.documentos
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_check_documento_tipo_condominio();

-- 5.2. Isolamento documento_tipo_prioridades.condominio_id ↔ tipo_id
CREATE OR REPLACE FUNCTION public.tr_fn_check_documento_prioridade_tipo_condominio()
RETURNS TRIGGER AS $$
DECLARE
  v_tipo_condo_id UUID;
BEGIN
  SELECT condominio_id INTO v_tipo_condo_id
  FROM public.documento_tipos
  WHERE id = NEW.tipo_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tipo de documento % não existe.', NEW.tipo_id;
  END IF;

  IF v_tipo_condo_id IS NOT NULL AND v_tipo_condo_id != NEW.condominio_id THEN
    RAISE EXCEPTION 'Violação de isolamento multi-tenant: não é permitido priorizar tipo de documento de outro condomínio.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_doc_prioridades_condo_guard ON public.documento_tipo_prioridades;
CREATE TRIGGER tr_doc_prioridades_condo_guard
  BEFORE INSERT OR UPDATE OF tipo_id, condominio_id ON public.documento_tipo_prioridades
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_check_documento_prioridade_tipo_condominio();

-- 5.3. Bloqueio de DELETE para tipos em uso (Regra: Desativar com ativo = false)
CREATE OR REPLACE FUNCTION public.tr_fn_check_documento_tipo_delete()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.is_system = true OR OLD.condominio_id IS NULL THEN
    RAISE EXCEPTION 'Tipos padrão do sistema não podem ser excluídos.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.documentos WHERE tipo_id = OLD.id) THEN
    RAISE EXCEPTION 'Este tipo está vinculado a documentos existentes e não pode ser excluído. Desative-o marcando como inativo (ativo = false).';
  END IF;

  DELETE FROM public.documento_tipo_prioridades WHERE tipo_id = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_documento_tipo_delete_guard ON public.documento_tipos;
CREATE TRIGGER tr_documento_tipo_delete_guard
  BEFORE DELETE ON public.documento_tipos
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_check_documento_tipo_delete();

-- ── 6. TRIGGER ANTI-DUPLICIDADE DE NOTIFICAÇÕES ───────────────────────────────
CREATE OR REPLACE FUNCTION public.tr_fn_documento_avisar_moradores()
RETURNS TRIGGER AS $$
BEGIN
  -- 1. NOVO DOCUMENTO: INSERT com avisar_moradores = true
  IF (TG_OP = 'INSERT' AND NEW.avisar_moradores = true) THEN
    PERFORM public.push_notify_documento(
      NEW.id,
      NEW.condominio_id,
      NEW.titulo,
      'novo_documento'
    );
  END IF;

  -- 2. PUBLICAÇÃO POSTERIOR: UPDATE onde avisar_moradores passou de false/null -> true
  -- Transições true -> true (edições cotidianas) e true -> false NÃO disparam notificação.
  IF (TG_OP = 'UPDATE' AND NEW.avisar_moradores = true AND (OLD.avisar_moradores IS NOT TRUE)) THEN
    PERFORM public.push_notify_documento(
      NEW.id,
      NEW.condominio_id,
      NEW.titulo,
      'novo_documento'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';

DROP TRIGGER IF EXISTS tr_documento_avisar_moradores ON public.documentos;
CREATE TRIGGER tr_documento_avisar_moradores
  AFTER INSERT OR UPDATE ON public.documentos
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_documento_avisar_moradores();

-- ── 7. POLÍTICAS DE ROW LEVEL SECURITY (RLS) ─────────────────────────────────
ALTER TABLE public.documento_tipos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documento_tipo_prioridades ENABLE ROW LEVEL SECURITY;

-- 7.1. documento_tipos
DROP POLICY IF EXISTS "documento_tipos_select_policy" ON public.documento_tipos;
CREATE POLICY "documento_tipos_select_policy" ON public.documento_tipos
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND (
      condominio_id IS NULL
      OR public.is_admin_of_condo(condominio_id)
      OR condominio_id = (SELECT perfil.condominio_id FROM public.perfil WHERE perfil.id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "documento_tipos_admin_insert" ON public.documento_tipos;
CREATE POLICY "documento_tipos_admin_insert" ON public.documento_tipos
  FOR INSERT
  WITH CHECK (
    condominio_id IS NOT NULL
    AND is_system = false
    AND public.is_admin_of_condo(condominio_id)
  );

DROP POLICY IF EXISTS "documento_tipos_admin_update" ON public.documento_tipos;
CREATE POLICY "documento_tipos_admin_update" ON public.documento_tipos
  FOR UPDATE
  USING (
    condominio_id IS NOT NULL
    AND is_system = false
    AND public.is_admin_of_condo(condominio_id)
  )
  WITH CHECK (
    condominio_id IS NOT NULL
    AND is_system = false
    AND public.is_admin_of_condo(condominio_id)
  );

DROP POLICY IF EXISTS "documento_tipos_admin_delete" ON public.documento_tipos;
CREATE POLICY "documento_tipos_admin_delete" ON public.documento_tipos
  FOR DELETE
  USING (
    condominio_id IS NOT NULL
    AND is_system = false
    AND public.is_admin_of_condo(condominio_id)
  );

-- 7.2. documento_tipo_prioridades
DROP POLICY IF EXISTS "doc_prioridades_select" ON public.documento_tipo_prioridades;
CREATE POLICY "doc_prioridades_select" ON public.documento_tipo_prioridades
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND (
      public.is_admin_of_condo(condominio_id)
      OR condominio_id = (SELECT perfil.condominio_id FROM public.perfil WHERE perfil.id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "doc_prioridades_admin_all" ON public.documento_tipo_prioridades;
CREATE POLICY "doc_prioridades_admin_all" ON public.documento_tipo_prioridades
  FOR ALL
  USING (public.is_admin_of_condo(condominio_id))
  WITH CHECK (public.is_admin_of_condo(condominio_id));
