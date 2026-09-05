-- ============================================================================
-- FASE 1 — EXPAND
-- ============================================================================
-- Objetivo: Renomear a VIEW convites para vw_convites_legacy e criar a tabela
--           física convites com o schema completo. O código continua usando
--           .from('convites') sem alteração de nome.
--
-- Pré-condições:
--   1. Fase 0 executada (backups existem)
--   2. VIEW public.convites existe (relkind = 'v')
--   3. Trigger trg_convites_view_insert existe na VIEW
--   4. Function fn_convites_view_insert() existe
--
-- Pós-condições:
--   1. VIEW renomeada para vw_convites_legacy (preservada para diagnóstico)
--   2. Trigger trg_convites_view_insert migrado automaticamente para a VIEW renomeada
--   3. Tabela física public.convites criada com schema completo
--   4. RLS ativado com 4 policies (morador, portaria, admin, service_role)
--   5. Índices criados
--   6. Tabela adicionada à publicação supabase_realtime
--   7. Triggers de WhatsApp NÃO criados (deferidos para Fase 3.5)
--   8. PostgREST notificado para recarregar schema cache
--
-- Rollback:
--   DROP TABLE IF EXISTS public.convites CASCADE;
--   ALTER VIEW public.vw_convites_legacy RENAME TO convites;
--   NOTIFY pgrst, 'reload schema';
--
-- Validação:
--   SELECT relname, relkind FROM pg_class
--     WHERE relname IN ('convites', 'vw_convites_legacy')
--       AND relnamespace = 'public'::regnamespace;
--   -- Esperado: convites = 'r' (table), vw_convites_legacy = 'v' (view)
--
--   SELECT COUNT(*) FROM pg_policy WHERE polrelid = 'public.convites'::regclass;
--   -- Esperado: 4
--
--   SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'convites' AND schemaname = 'public';
--   -- Esperado: 6 (1 PK + 5 indexes)
--
--   SELECT tablename FROM pg_publication_tables
--     WHERE pubname = 'supabase_realtime' AND tablename = 'convites';
--   -- Esperado: 1 row
-- ============================================================================

-- Transação gerenciada pelo Supabase migration runner

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 1: Renomear a VIEW convites → vw_convites_legacy
-- ─────────────────────────────────────────────────────────────────────────────
-- O trigger trg_convites_view_insert acompanha automaticamente a VIEW renomeada.
-- Nenhum código depende funcionalmente desta VIEW (todos os fluxos estão quebrados).
-- A VIEW é preservada apenas para consultas de diagnóstico e rollback.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_class
        WHERE relname = 'convites'
          AND relkind = 'v'
          AND relnamespace = 'public'::regnamespace
    ) THEN
        ALTER VIEW public.convites RENAME TO vw_convites_legacy;
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 2: Criar tabela física convites com schema completo
-- ─────────────────────────────────────────────────────────────────────────────
-- Colunas derivadas de:
--   - Migrations do repositório (Schema 2.0)
--   - Código Flutter (invitation_repository_impl.dart)
--   - Código Web morador (visitantes-client.tsx)
--   - Código Web portaria (autorizar-visitante-portaria-client.tsx)
--   - Código Web checkin (visitor-list.tsx)
--
-- Nota: resident_id é nullable porque a portaria pode criar convites
--       sem morador identificado (selectedResident === '__none__').
CREATE TABLE IF NOT EXISTS public.convites (
    id                    UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    resident_id           UUID,
    condominio_id         BIGINT         NOT NULL,
    guest_name            TEXT           NOT NULL DEFAULT '',
    visitor_type          TEXT,
    validity_date         TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    valid_until           TIMESTAMPTZ,
    qr_data               TEXT,
    visitor_phone         TEXT,
    whatsapp              TEXT,
    observacao            TEXT,
    documento             TEXT,
    placa                 TEXT,
    cracha_referencia     TEXT,
    visitante_compareceu  BOOLEAN        DEFAULT FALSE,
    liberado_por          UUID,
    liberado_em           TIMESTAMPTZ,
    status                TEXT           DEFAULT 'active',
    criado_por_portaria   BOOLEAN        DEFAULT FALSE,
    bloco_destino         TEXT,
    apto_destino          TEXT,
    morador_nome_manual   TEXT,
    parent_id             UUID,
    user_id               UUID,
    bloco_txt             TEXT,
    apto_txt              TEXT,
    created_at            TIMESTAMPTZ    DEFAULT NOW(),
    updated_at            TIMESTAMPTZ    DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 3: Índices
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_convites_resident_id    ON public.convites (resident_id);
CREATE INDEX IF NOT EXISTS idx_convites_condominio_id  ON public.convites (condominio_id);
CREATE INDEX IF NOT EXISTS idx_convites_status         ON public.convites (status);
CREATE INDEX IF NOT EXISTS idx_convites_created_at     ON public.convites (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_convites_validity_date  ON public.convites (validity_date);

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 4: Row Level Security
-- ─────────────────────────────────────────────────────────────────────────────
-- RLS é ativado incondicionalmente. Se já estiver ativo, o comando é no-op.
ALTER TABLE public.convites ENABLE ROW LEVEL SECURITY;

-- 4.1 Morador: CRUD sobre seus próprios convites
-- Permite que o morador crie, leia, atualize e delete convites onde
-- resident_id = auth.uid() (UUID do Supabase Auth).
DROP POLICY IF EXISTS "convites_morador_crud" ON public.convites;
CREATE POLICY "convites_morador_crud"
    ON public.convites
    FOR ALL
    TO authenticated
    USING (resident_id = auth.uid())
    WITH CHECK (resident_id = auth.uid());

-- 4.2 Portaria: acesso total aos convites do mesmo condomínio
-- Roles de portaria verificadas contra valores reais em produção.
DROP POLICY IF EXISTS "convites_portaria_all" ON public.convites;
CREATE POLICY "convites_portaria_all"
    ON public.convites
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.perfil p
            WHERE p.id = auth.uid()
              AND p.condominio_id = convites.condominio_id
              AND p.papel_sistema = 'Porteiro (a)'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.perfil p
            WHERE p.id = auth.uid()
              AND p.condominio_id = convites.condominio_id
              AND p.papel_sistema = 'Porteiro (a)'
        )
    );

-- 4.3 Admin/Síndico: acesso total aos convites do mesmo condomínio
-- Inclui ADMIN e Síndico (a) — valores reais em produção.
DROP POLICY IF EXISTS "convites_admin_all" ON public.convites;
CREATE POLICY "convites_admin_all"
    ON public.convites
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.perfil p
            WHERE p.id = auth.uid()
              AND p.condominio_id = convites.condominio_id
              AND p.papel_sistema IN ('ADMIN', 'Síndico (a)')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.perfil p
            WHERE p.id = auth.uid()
              AND p.condominio_id = convites.condominio_id
              AND p.papel_sistema IN ('ADMIN', 'Síndico (a)')
        )
    );

-- 4.4 Service Role: acesso total irrestrito
-- Necessário para Edge Functions (convite-whatsapp-notify, lgpd-archive)
-- e para o Supabase Admin/Dashboard.
DROP POLICY IF EXISTS "convites_service_all" ON public.convites;
CREATE POLICY "convites_service_all"
    ON public.convites
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 5: Realtime
-- ─────────────────────────────────────────────────────────────────────────────
-- Adiciona a tabela convites à publicação supabase_realtime para habilitar
-- assinaturas de postgres_changes no web (visitor-list.tsx:211).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'convites'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.convites;
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 6: Notificar PostgREST para recarregar schema cache
-- ─────────────────────────────────────────────────────────────────────────────
-- Garante que o PostgREST reconheça imediatamente que 'convites' agora é uma
-- tabela física com colunas novas, sem aguardar o reload periódico (~60s).
NOTIFY pgrst, 'reload schema';
