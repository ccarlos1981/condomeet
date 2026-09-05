-- ============================================================================
-- FASE 0 — BACKUP E SNAPSHOT
-- ============================================================================
-- Objetivo: Criar snapshots imutáveis de todos os artefatos antes de qualquer
--           alteração estrutural no módulo de visitantes.
--
-- Pré-condições:
--   1. VIEW public.convites existe (relkind = 'v')
--   2. Tabela public.tb_autorizacao_visitante existe (relkind = 'r')
--   3. Function public.fn_convites_view_insert() existe
--   4. Trigger trg_convites_view_insert existe na VIEW convites
--
-- Pós-condições:
--   1. Tabela _backup_tb_autorizacao_visitante_20260720 criada com cópia integral
--   2. Tabela _backup_convites_migration_metadata criada com definições salvas
--   3. Nenhum artefato original foi alterado
--   4. Contagem de registros preservada e registrada
--
-- Rollback:
--   DROP TABLE IF EXISTS public._backup_tb_autorizacao_visitante_20260720;
--   DROP TABLE IF EXISTS public._backup_convites_migration_metadata;
--
-- Validação:
--   SELECT COUNT(*) FROM public._backup_tb_autorizacao_visitante_20260720;
--   -- Esperado: 74
--   SELECT COUNT(*) FROM public._backup_convites_migration_metadata;
--   -- Esperado: 4 (view_definition, function_definition, trigger_definition, record_count)
-- ============================================================================

-- Transação gerenciada pelo Supabase migration runner (não usar BEGIN/COMMIT explícito)

-- 0.1 Backup integral da tabela de dados legacy
CREATE TABLE IF NOT EXISTS public._backup_tb_autorizacao_visitante_20260720 AS
SELECT * FROM public.tb_autorizacao_visitante;

-- 0.2 Tabela de metadados da migração (para rollback e auditoria)
CREATE TABLE IF NOT EXISTS public._backup_convites_migration_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 0.3 Salvar definição da VIEW convites
INSERT INTO public._backup_convites_migration_metadata (key, value)
VALUES (
    'view_definition',
    (SELECT pg_get_viewdef('public.convites'::regclass, true))
)
ON CONFLICT (key) DO NOTHING;

-- 0.4 Salvar definição COMPLETA da function fn_convites_view_insert (inclui assinatura, RETURNS, LANGUAGE)
INSERT INTO public._backup_convites_migration_metadata (key, value)
VALUES (
    'function_definition',
    (SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'fn_convites_view_insert' AND pronamespace = 'public'::regnamespace)
)
ON CONFLICT (key) DO NOTHING;

-- 0.5 Salvar definição do trigger trg_convites_view_insert
INSERT INTO public._backup_convites_migration_metadata (key, value)
VALUES (
    'trigger_definition',
    (SELECT pg_get_triggerdef(t.oid) FROM pg_trigger t JOIN pg_class c ON t.tgrelid = c.oid WHERE c.relname = 'convites' AND t.tgname = 'trg_convites_view_insert')
)
ON CONFLICT (key) DO NOTHING;

-- 0.6 Registrar contagem de registros para validação
INSERT INTO public._backup_convites_migration_metadata (key, value)
VALUES (
    'record_count',
    (SELECT COUNT(*)::TEXT FROM public.tb_autorizacao_visitante)
)
ON CONFLICT (key) DO NOTHING;
