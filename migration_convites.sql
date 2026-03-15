-- =============================================
-- MIGRAÇÃO: tb_autorizacao_acesso (SB antigo) → convites (SB novo)
-- =============================================
-- Abordagem em 3 etapas:
--   ETAPA 1: Criar tabela staging no SB NOVO
--   ETAPA 2: Processar CSV localmente → gerar staging_inserts.sql
--   ETAPA 3: Transformar staging → convites (no SB NOVO)
-- =============================================
-- RESULTADO FINAL: 714 convites importados (335 used, 363 expired, 16 active)
-- Data de execução: 2026-03-13
-- =============================================


-- ═══════════════════════════════════════════════════
-- ETAPA 1 — RODAR NO SUPABASE NOVO
-- Cria uma tabela temporária para receber os dados brutos
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS _staging_autorizacao (
    id_antigo           INT,
    created_at          TIMESTAMPTZ,
    nome_morador        TEXT,
    nome_visitante      TEXT,
    celular_morador     TEXT,
    celular_visitante   TEXT,
    bloco               TEXT,
    apto                TEXT,
    tipo_visitante      TEXT,
    numero_autorizacao  TEXT,
    data_inicio         TIMESTAMPTZ,
    observacao          TEXT,
    compareceu          BOOLEAN,
    condominio_nome     TEXT,
    id_botconversa      TEXT,
    quem_solicitou      TEXT,
    registro_entrada    TEXT
);


-- ═══════════════════════════════════════════════════
-- ETAPA 2 — RODAR LOCALMENTE (Python)
-- Processar o CSV exportado do SB antigo e gerar INSERTs
-- Script: /tmp/process_csv_to_sql.py
-- Entrada: tb_autorizacao_acesso_rows.csv
-- Saída:   staging_inserts.sql (1000 registros)
-- Depois, colar o conteúdo de staging_inserts.sql no SQL Editor novo
-- ═══════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════
-- ETAPA 3 — RODAR NO SUPABASE NOVO (após importar o staging)
-- Transforma os dados e insere na tabela convites
-- ═══════════════════════════════════════════════════

-- 3a. Verificar total importado no staging
SELECT COUNT(*) AS total_staging FROM _staging_autorizacao;
-- Esperado: 1000

-- 3b. Verificar match dos condomínios
SELECT DISTINCT s.condominio_nome, c.id AS condominio_id_novo, c.nome
FROM _staging_autorizacao s
LEFT JOIN condominios c ON c.nome ILIKE '%' || 
  CASE 
    WHEN s.condominio_nome ILIKE '%Recanto%' THEN 'Recanto'
    WHEN s.condominio_nome ILIKE '%RealPark%' THEN 'Real Park'
    WHEN s.condominio_nome ILIKE '%Montserrat%' THEN 'Montserrat'
    WHEN s.condominio_nome ILIKE '%Pescar%' THEN 'Pescar'
    WHEN s.condominio_nome ILIKE '%Star%' THEN 'Star'
    ELSE s.condominio_nome
  END || '%'
ORDER BY s.condominio_nome;

-- 3c. Verificar match dos moradores (por botconversa_id)
SELECT 
  COUNT(*) AS total,
  COUNT(p.id) AS com_perfil,
  COUNT(*) - COUNT(p.id) AS sem_perfil
FROM _staging_autorizacao s
LEFT JOIN perfil p ON p.botconversa_id = s.id_botconversa
WHERE s.id_botconversa IS NOT NULL AND s.id_botconversa != '0';

-- 3d. INSERIR NA TABELA CONVITES
-- ⚠️ Rode os diagnósticos acima (3b e 3c) ANTES de rodar este INSERT

INSERT INTO convites (
  id, resident_id, condominio_id, 
  guest_name, validity_date, qr_data, 
  visitor_type, visitor_phone, observation, 
  status, created_at, updated_at
)
SELECT
  gen_random_uuid(),
  
  -- resident_id: buscar por botconversa_id, senão por celular+bloco+apto
  COALESCE(
    (SELECT id FROM perfil WHERE botconversa_id = s.id_botconversa AND s.id_botconversa != '0' LIMIT 1),
    (SELECT id FROM perfil 
     WHERE whatsapp = s.celular_morador 
       AND bloco_txt = s.bloco 
       AND apto_txt = s.apto
     LIMIT 1)
  ),
  
  -- condominio_id: buscar pelo nome (RealPark → Real Park)
  (SELECT id FROM condominios WHERE nome ILIKE '%' || 
    CASE 
      WHEN s.condominio_nome ILIKE '%Recanto%' THEN 'Recanto'
      WHEN s.condominio_nome ILIKE '%RealPark%' THEN 'Real Park'
      WHEN s.condominio_nome ILIKE '%Montserrat%' THEN 'Montserrat'
      WHEN s.condominio_nome ILIKE '%Pescar%' THEN 'Pescar'
      WHEN s.condominio_nome ILIKE '%Star%' THEN 'Star'
      ELSE s.condominio_nome
    END || '%'
   LIMIT 1),
  
  -- guest_name
  COALESCE(s.nome_visitante, s.observacao, s.tipo_visitante, 'Visitante'),
  -- validity_date
  COALESCE(s.data_inicio, s.created_at),
  -- qr_data
  s.numero_autorizacao,
  -- visitor_type
  s.tipo_visitante,
  -- visitor_phone
  s.celular_visitante,
  -- observation
  s.observacao,
  
  -- status
  CASE 
    WHEN s.compareceu = true THEN 'used'
    WHEN COALESCE(s.data_inicio, s.created_at) < NOW() THEN 'expired'
    ELSE 'active'
  END,
  
  -- created_at / updated_at
  s.created_at,
  s.created_at

FROM _staging_autorizacao s
WHERE 
  -- resident_id deve existir
  COALESCE(
    (SELECT id FROM perfil WHERE botconversa_id = s.id_botconversa AND s.id_botconversa != '0' LIMIT 1),
    (SELECT id FROM perfil 
     WHERE whatsapp = s.celular_morador 
       AND bloco_txt = s.bloco 
       AND apto_txt = s.apto
     LIMIT 1)
  ) IS NOT NULL
  -- condominio_id deve existir
  AND s.condominio_nome IS NOT NULL
  AND (SELECT id FROM condominios WHERE nome ILIKE '%' || 
    CASE 
      WHEN s.condominio_nome ILIKE '%Recanto%' THEN 'Recanto'
      WHEN s.condominio_nome ILIKE '%RealPark%' THEN 'Real Park'
      WHEN s.condominio_nome ILIKE '%Montserrat%' THEN 'Montserrat'
      WHEN s.condominio_nome ILIKE '%Pescar%' THEN 'Pescar'
      WHEN s.condominio_nome ILIKE '%Star%' THEN 'Star'
      ELSE s.condominio_nome
    END || '%'
   LIMIT 1) IS NOT NULL;

-- 3e. Relatório final
SELECT 
  COUNT(*) AS total_convites_importados,
  COUNT(*) FILTER (WHERE status = 'used') AS usados,
  COUNT(*) FILTER (WHERE status = 'expired') AS expirados,
  COUNT(*) FILTER (WHERE status = 'active') AS ativos
FROM convites;

-- 3f. Registros que NÃO foram importados (sem perfil ou condomínio)
SELECT s.id_antigo, s.nome_morador, s.celular_morador, s.bloco, s.apto, s.condominio_nome
FROM _staging_autorizacao s
WHERE COALESCE(
    (SELECT id FROM perfil WHERE botconversa_id = s.id_botconversa AND s.id_botconversa != '0' LIMIT 1),
    (SELECT id FROM perfil 
     WHERE whatsapp = s.celular_morador 
       AND bloco_txt = s.bloco 
       AND apto_txt = s.apto
     LIMIT 1)
  ) IS NULL
  OR s.condominio_nome IS NULL
  OR (SELECT id FROM condominios WHERE nome ILIKE '%' || 
    CASE 
      WHEN s.condominio_nome ILIKE '%Recanto%' THEN 'Recanto'
      WHEN s.condominio_nome ILIKE '%RealPark%' THEN 'Real Park'
      WHEN s.condominio_nome ILIKE '%Montserrat%' THEN 'Montserrat'
      WHEN s.condominio_nome ILIKE '%Pescar%' THEN 'Pescar'
      WHEN s.condominio_nome ILIKE '%Star%' THEN 'Star'
      ELSE s.condominio_nome
    END || '%'
   LIMIT 1) IS NULL
LIMIT 20;

-- 3g. Limpar tabela staging (OPCIONAL - rode depois de validar tudo)
-- DROP TABLE IF EXISTS _staging_autorizacao;
