-- ============================================================================
-- FASE FINAL — CLEANUP (Remoção da Estrutura Legacy)
-- ============================================================================
-- Objetivo: Remover de forma definitiva a VIEW e FUNCTION legadas, e a tabela 
--           física legacy tb_autorizacao_visitante, consolidando a migração.
--
-- Pré-condições de Segurança:
--   1. Tabela convites de produção existe e está consistente.
--   2. Backup da Fase 0 (tb_autorizacao_visitante) existe e está populado.
--   3. Metadados para rollback existem e estão íntegros.
--
-- Pós-condições:
--   1. vw_convites_legacy removida do banco de dados.
--   2. fn_convites_view_insert() removida do banco de dados.
--   3. tb_autorizacao_visitante removida do banco de dados.
--   4. Backups permanentes da Fase 0 intactos para auditoria histórica.
--
-- Rollback (Dinâmico):
--   Recupera dinamicamente a definição original da VIEW, FUNCTION e TRIGGER 
--   a partir do metadata salvo na Fase 0 e os reconstrói de forma consistente.
-- ============================================================================

-- Transação gerenciada pelo Supabase migration runner

-- ─────────────────────────────────────────────────────────────────────────────
-- ETAPA 1: Validações Pré-Remoção (Garantia de Consistência)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  -- 1. Garantir que a tabela nova convites existe
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'convites' AND schemaname = 'public') THEN
      RAISE EXCEPTION 'SEGURANÇA: A nova tabela convites não existe. Abortando cleanup.';
  END IF;

  -- 2. Garantir que a tabela nova possui colunas essenciais migratórias
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'convites' AND column_name = 'observacao') THEN
      RAISE EXCEPTION 'SEGURANÇA: A nova tabela convites não possui a coluna observacao. Abortando cleanup.';
  END IF;

  -- 3. Garantir que o backup permanente da Fase 0 existe
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = '_backup_tb_autorizacao_visitante_20260720' AND schemaname = 'public') THEN
      RAISE EXCEPTION 'SEGURANÇA: Tabela de backup permanente da Fase 0 não encontrada. Abortando cleanup.';
  END IF;

  -- 4. Garantir que o backup possui dados íntegros
  IF (SELECT COUNT(*) FROM public._backup_tb_autorizacao_visitante_20260720) = 0 THEN
      RAISE EXCEPTION 'SEGURANÇA: A tabela de backup permanente está vazia. Abortando cleanup.';
  END IF;

  -- 5. Garantir que a tabela de metadados para rollback existe
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = '_backup_convites_migration_metadata' AND schemaname = 'public') THEN
      RAISE EXCEPTION 'SEGURANÇA: Tabela de metadados de migração não encontrada. Abortando cleanup.';
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- ETAPA 2: Remoção Controlada dos Recursos Legados
-- ─────────────────────────────────────────────────────────────────────────────

-- 2.1 Remover a VIEW legacy (CASCADE remove também o trigger associado)
DROP VIEW IF EXISTS public.vw_convites_legacy CASCADE;

-- 2.2 Remover a trigger function legada
DROP FUNCTION IF EXISTS public.fn_convites_view_insert();

-- 2.3 Remover a tabela física legada
DROP TABLE IF EXISTS public.tb_autorizacao_visitante;

-- ─────────────────────────────────────────────────────────────────────────────
-- ETAPA 3: Validação Pós-Cleanup (Confirmação de Ausência)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  -- 1. Confirmar que vw_convites_legacy não existe
  IF EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'vw_convites_legacy' AND schemaname = 'public') THEN
      RAISE EXCEPTION 'Fase Final Falhou: a view vw_convites_legacy ainda existe.';
  END IF;

  -- 2. Confirmar que tb_autorizacao_visitante não existe
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'tb_autorizacao_visitante' AND schemaname = 'public') THEN
      RAISE EXCEPTION 'Fase Final Falhou: a tabela tb_autorizacao_visitante ainda existe.';
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- ETAPA 4: Notificação e atualização do cache do PostgREST
-- ─────────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
