-- =============================================
-- Migration: Popular unidade_perfil
-- Cruza perfil.bloco_txt + perfil.apto_txt com blocos + apartamentos + unidades
-- =============================================

-- 1. Primeiro, adicionar coluna status e timestamps à unidade_perfil (se não existir)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'unidade_perfil' AND column_name = 'status') THEN
    ALTER TABLE unidade_perfil ADD COLUMN status TEXT DEFAULT 'ativo' CHECK (status IN ('ativo', 'inativo'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'unidade_perfil' AND column_name = 'data_entrada') THEN
    ALTER TABLE unidade_perfil ADD COLUMN data_entrada TIMESTAMPTZ DEFAULT now();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'unidade_perfil' AND column_name = 'data_saida') THEN
    ALTER TABLE unidade_perfil ADD COLUMN data_saida TIMESTAMPTZ;
  END IF;
END $$;

-- 2. Criar índice parcial para performance (buscar apenas ativos)
CREATE INDEX IF NOT EXISTS idx_unidade_perfil_ativo 
ON unidade_perfil (unidade_id) WHERE status = 'ativo';

-- 3. Diagnóstico: verificar quantos perfis têm bloco_txt/apto_txt
DO $$
DECLARE
  total_perfis INT;
  com_bloco INT;
  sem_bloco INT;
BEGIN
  SELECT COUNT(*) INTO total_perfis FROM perfil;
  SELECT COUNT(*) INTO com_bloco FROM perfil WHERE bloco_txt IS NOT NULL AND apto_txt IS NOT NULL;
  sem_bloco := total_perfis - com_bloco;
  RAISE NOTICE '📊 Total perfis: %, Com bloco/apto: %, Sem: %', total_perfis, com_bloco, sem_bloco;
END $$;

-- 4. Diagnóstico: ver os valores únicos de bloco_txt nos perfis
DO $$
DECLARE
  r RECORD;
BEGIN
  RAISE NOTICE '📋 Valores de bloco_txt nos perfis:';
  FOR r IN 
    SELECT DISTINCT bloco_txt, COUNT(*) as qty 
    FROM perfil 
    WHERE bloco_txt IS NOT NULL 
    GROUP BY bloco_txt 
    ORDER BY bloco_txt
  LOOP
    RAISE NOTICE '  Bloco "%": % moradores', r.bloco_txt, r.qty;
  END LOOP;
END $$;

-- 5. Diagnóstico: ver os blocos cadastrados
DO $$
DECLARE
  r RECORD;
BEGIN
  RAISE NOTICE '📋 Blocos cadastrados no banco:';
  FOR r IN 
    SELECT b.nome_ou_numero, c.nome as condo_nome 
    FROM blocos b 
    JOIN condominios c ON c.id = b.condominio_id
    ORDER BY c.nome, b.nome_ou_numero
  LOOP
    RAISE NOTICE '  Bloco "%" (condo: %)', r.nome_ou_numero, r.condo_nome;
  END LOOP;
END $$;

-- 6. INSERT: vincular perfis às unidades
-- Cruza: perfil.bloco_txt = blocos.nome_ou_numero E perfil.apto_txt = apartamentos.numero
-- Dentro do mesmo condomínio
INSERT INTO unidade_perfil (perfil_id, unidade_id, status, data_entrada)
SELECT 
  p.id AS perfil_id,
  u.id AS unidade_id,
  'ativo' AS status,
  now() AS data_entrada
FROM perfil p
JOIN blocos b ON b.condominio_id = p.condominio_id 
            AND LOWER(TRIM(b.nome_ou_numero)) = LOWER(TRIM(p.bloco_txt))
JOIN apartamentos a ON a.condominio_id = p.condominio_id 
                   AND LOWER(TRIM(a.numero)) = LOWER(TRIM(p.apto_txt))
JOIN unidades u ON u.bloco_id = b.id 
              AND u.apartamento_id = a.id 
              AND u.condominio_id = p.condominio_id
WHERE p.bloco_txt IS NOT NULL 
  AND p.apto_txt IS NOT NULL
  AND p.condominio_id IS NOT NULL
ON CONFLICT (perfil_id, unidade_id) DO NOTHING;

-- 7. Relatório final
DO $$
DECLARE
  vinculados INT;
  total_perfis INT;
  sem_vinculo INT;
  r RECORD;
BEGIN
  SELECT COUNT(*) INTO vinculados FROM unidade_perfil;
  SELECT COUNT(*) INTO total_perfis FROM perfil WHERE bloco_txt IS NOT NULL AND apto_txt IS NOT NULL;
  sem_vinculo := total_perfis - vinculados;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ RESULTADO:';
  RAISE NOTICE '  Vínculos criados: %', vinculados;
  RAISE NOTICE '  Perfis com bloco/apto: %', total_perfis;
  RAISE NOTICE '  Sem match: %', sem_vinculo;
  
  IF sem_vinculo > 0 THEN
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ Perfis SEM match (primeiros 20):';
    FOR r IN 
      SELECT p.nome_completo, p.bloco_txt, p.apto_txt
      FROM perfil p
      LEFT JOIN unidade_perfil up ON up.perfil_id = p.id
      WHERE up.id IS NULL 
        AND p.bloco_txt IS NOT NULL 
        AND p.apto_txt IS NOT NULL
      LIMIT 20
    LOOP
      RAISE NOTICE '  - %: Bloco=% Apto=%', r.nome_completo, r.bloco_txt, r.apto_txt;
    END LOOP;
  END IF;
END $$;
