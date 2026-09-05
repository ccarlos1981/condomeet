-- ============================================================================
-- FASE 2 — MIGRATE (Migração dos Dados Legacy)
-- ============================================================================
-- Objetivo: Copiar os registros de tb_autorizacao_visitante para a tabela
--           física convites, utilizando UUID determinístico baseado no id
--           legacy para garantir idempotência absoluta.
--
-- Decisão de Negócio:
--   4 registros com condominio_id IS NULL (IDs 289, 290, 291, 292) NÃO serão
--   migrados. São registros de teste do BotConversa (condomínio RealPark,
--   2025-06-09, mesmo id_bc_visitante, sem morador associado). Permanecem
--   preservados integralmente em:
--     - public.tb_autorizacao_visitante (tabela original, inalterada)
--     - public._backup_tb_autorizacao_visitante_20260720 (backup Fase 0)
--
-- Registros esperados: COUNT(*) WHERE condominio_id IS NOT NULL
--
-- Pré-condições:
--   1. Fase 0 executada (backups existem)
--   2. Fase 1 executada (tabela convites existe, vazia, com RLS + indexes)
--   3. Extensão uuid-ossp instalada (uuid_generate_v5 disponível)
--   4. tb_autorizacao_visitante com registros íntegros (validado contra backup Fase 0)
--
-- Pós-condições:
--   1. Tabela convites com COUNT = elegíveis na origem
--   2. Todos com status = 'expired' (dados de 2025)
--   3. Todos com criado_por_portaria = TRUE
--   4. Todos com UUID determinístico derivado do id legacy
--   5. tb_autorizacao_visitante inalterada (COUNT = backup Fase 0)
--
-- Idempotência:
--   uuid_generate_v5() gera o mesmo UUID para o mesmo id legacy em toda
--   execução. ON CONFLICT (id) DO NOTHING ignora registros já inseridos.
--   A migration pode ser reexecutada com segurança quantas vezes necessário.
--
-- Rollback:
--   TRUNCATE public.convites;
--   -- Dados originais intactos em tb_autorizacao_visitante e backup Fase 0
--
-- Validação (ao final desta migration):
--   V1: COUNT(convites) = COUNT(legacy WHERE condominio_id IS NOT NULL)
--   V2: COUNT(legacy) = COUNT(backup Fase 0) — tabela não alterada
--   V3: COUNT(DISTINCT id) = COUNT(*) — sem duplicatas
--   V4: Todos os UUIDs recalculáveis via uuid_generate_v5(id legacy)
--   V5: Zero registros com condominio_id NULL no destino
--   V6: Zero registros com guest_name NULL no destino
-- ============================================================================

-- Transação gerenciada pelo Supabase migration runner

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 1: Migração dos dados com UUID determinístico
-- ─────────────────────────────────────────────────────────────────────────────
-- Namespace utilizado: RFC 4122 DNS namespace (6ba7b810-9dad-11d1-80b4-00c04fd430c8)
-- Input: id bigint da tabela legacy convertido para text
-- Resultado: UUID V5 determinístico, único e rastreável
--
-- Mapeamento de colunas:
--   id                    ← uuid_generate_v5(namespace, tav.id::text)
--   resident_id           ← tav.user_id (UUID, pode ser NULL em 60 registros)
--   user_id               ← tav.user_id (duplicado para compatibilidade)
--   condominio_id         ← tav.condominio_id (BIGINT, NOT NULL no filtro)
--   guest_name            ← COALESCE(tav.nome_visitante, '') (NOT NULL)
--   visitor_type          ← tav.tipo_de_visitante
--   validity_date         ← tav.created_at (data de criação = validade original)
--   visitor_phone         ← tav.celular_visitante
--   whatsapp              ← tav.celular_visitante (mesmo dado, dupla entrada)
--   observacao            ← tav.observacao
--   bloco_txt             ← tav.bloco_txt
--   apto_txt              ← tav.apto_txt
--   morador_nome_manual   ← tav.nome_morador_txt
--   status                ← 'expired' (todos expirados, dados de 2025)
--   criado_por_portaria   ← TRUE (todos criados via portaria Bubble)
--   created_at            ← tav.created_at (preserva timestamp original)
--   updated_at            ← tav.created_at (sem coluna de update no legacy)
--
-- Colunas destino não preenchidas (default NULL/FALSE):
--   valid_until, qr_data, documento, placa, cracha_referencia,
--   visitante_compareceu (FALSE), liberado_por, liberado_em,
--   bloco_destino, apto_destino, parent_id

INSERT INTO public.convites (
    id,
    resident_id,
    user_id,
    condominio_id,
    guest_name,
    visitor_type,
    validity_date,
    visitor_phone,
    whatsapp,
    observacao,
    bloco_txt,
    apto_txt,
    morador_nome_manual,
    status,
    criado_por_portaria,
    created_at,
    updated_at
)
SELECT
    uuid_generate_v5(
        '6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid,
        tav.id::text
    ),
    tav.user_id,
    tav.user_id,
    tav.condominio_id,
    COALESCE(tav.nome_visitante, ''),
    tav.tipo_de_visitante,
    tav.created_at,
    tav.celular_visitante,
    tav.celular_visitante,
    tav.observacao,
    tav.bloco_txt,
    tav.apto_txt,
    tav.nome_morador_txt,
    'expired',
    TRUE,
    tav.created_at,
    tav.created_at
FROM public.tb_autorizacao_visitante tav
WHERE tav.condominio_id IS NOT NULL
ON CONFLICT (id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 2: Validações pós-migração
-- ─────────────────────────────────────────────────────────────────────────────
-- As validações abaixo utilizam DO blocks com RAISE para reportar resultados
-- e falhar a migration caso alguma inconsistência seja detectada.

DO $$
DECLARE
    v_convites_count     INTEGER;
    v_eligible_count     INTEGER;
    v_legacy_count       INTEGER;
    v_backup_count       INTEGER;
    v_distinct_ids       INTEGER;
    v_uuid_check         INTEGER;
    v_null_condo         INTEGER;
    v_null_guest_name    INTEGER;
BEGIN
    -- Contagens dinâmicas (sem valores fixos)
    SELECT COUNT(*) INTO v_convites_count FROM public.convites;
    SELECT COUNT(*) INTO v_eligible_count FROM public.tb_autorizacao_visitante WHERE condominio_id IS NOT NULL;
    SELECT COUNT(*) INTO v_legacy_count FROM public.tb_autorizacao_visitante;
    SELECT COUNT(*) INTO v_backup_count FROM public._backup_tb_autorizacao_visitante_20260720;
    SELECT COUNT(DISTINCT id) INTO v_distinct_ids FROM public.convites;

    -- V4: Todos os UUIDs são recalculáveis a partir do id legacy
    SELECT COUNT(*) INTO v_uuid_check
    FROM public.convites c
    JOIN public.tb_autorizacao_visitante tav
      ON c.id = uuid_generate_v5(
          '6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid,
          tav.id::text
      );

    SELECT COUNT(*) INTO v_null_condo FROM public.convites WHERE condominio_id IS NULL;
    SELECT COUNT(*) INTO v_null_guest_name FROM public.convites WHERE guest_name IS NULL;

    -- Relatório
    RAISE NOTICE '=== VALIDAÇÃO FASE 2 ===';
    RAISE NOTICE 'V1: convites COUNT            = %', v_convites_count;
    RAISE NOTICE 'V1: elegíveis na origem        = %', v_eligible_count;
    RAISE NOTICE 'V2: legacy COUNT (atual)       = %', v_legacy_count;
    RAISE NOTICE 'V2: backup COUNT (Fase 0)      = %', v_backup_count;
    RAISE NOTICE 'V3: convites DISTINCT id       = %', v_distinct_ids;
    RAISE NOTICE 'V4: UUIDs rastreáveis          = %', v_uuid_check;
    RAISE NOTICE 'V5: NULL condominio_id destino = %', v_null_condo;
    RAISE NOTICE 'V6: NULL guest_name destino    = %', v_null_guest_name;

    -- V1: Registros migrados = registros elegíveis na origem
    IF v_convites_count != v_eligible_count THEN
        RAISE EXCEPTION 'FASE 2 FALHOU: % registros migrados, mas % elegíveis na origem',
            v_convites_count, v_eligible_count;
    END IF;

    -- V2: Tabela legacy não foi alterada (comparação com backup Fase 0)
    IF v_legacy_count != v_backup_count THEN
        RAISE EXCEPTION 'FASE 2 FALHOU: legacy tem % registros, backup Fase 0 tem % (tabela foi alterada)',
            v_legacy_count, v_backup_count;
    END IF;

    -- V3: Sem duplicidades
    IF v_distinct_ids != v_convites_count THEN
        RAISE EXCEPTION 'FASE 2 FALHOU: % IDs distintos de % total (duplicidades detectadas)',
            v_distinct_ids, v_convites_count;
    END IF;

    -- V4: Todos os UUIDs são rastreáveis ao id legacy
    IF v_uuid_check != v_convites_count THEN
        RAISE EXCEPTION 'FASE 2 FALHOU: % UUIDs rastreáveis de % total (integridade comprometida)',
            v_uuid_check, v_convites_count;
    END IF;

    -- V5: Nenhum registro com condominio_id NULL no destino
    IF v_null_condo > 0 THEN
        RAISE EXCEPTION 'FASE 2 FALHOU: % registros com condominio_id NULL no destino', v_null_condo;
    END IF;

    -- V6: Nenhum registro com guest_name NULL no destino
    IF v_null_guest_name > 0 THEN
        RAISE EXCEPTION 'FASE 2 FALHOU: % registros com guest_name NULL no destino', v_null_guest_name;
    END IF;

    RAISE NOTICE '=== FASE 2 VALIDADA COM SUCESSO ===';
END $$;
