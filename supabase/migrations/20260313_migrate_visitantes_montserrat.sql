-- Migration: Import visitor records from old Supabase (condomeetBD)
-- Run this SQL in the OLD database (condomeetBD) SQL Editor.
-- It will produce INSERT statements that you copy and run in the NEW database (condomeet_Antigravity).
--
-- HOW TO USE:
-- 1. Copy this entire SQL
-- 2. Paste in OLD Supabase SQL Editor → Run
-- 3. The result will be a single column "insert_sql" with one INSERT per row
-- 4. Copy ALL the result rows
-- 5. Paste in NEW Supabase SQL Editor → Run

SELECT
  'INSERT INTO visitante_registros (condominio_id, entrada_at, nome, cpf_rg, whatsapp, tipo_visitante, empresa, bloco, apto, observacao, foto_url, saida_at, created_at) VALUES ('
  || '''4828f5f6-454c-438c-9ef3-9f1bf5a7ab94'''  -- condominio_id (Montserrat)
  || ', ' || COALESCE('''' || created_at::text || '''', 'NULL')  -- entrada_at
  || ', ' || COALESCE('''' || REPLACE(TRIM(nome_visitante), '''', '''''') || '''', 'NULL')  -- nome
  || ', ' || COALESCE('''' || REPLACE(TRIM(identidade_do_visitante), '''', '''''') || '''', 'NULL')  -- cpf_rg
  || ', ' || CASE WHEN wp_visitante IS NOT NULL AND TRIM(wp_visitante) != '' AND TRIM(wp_visitante) != ' '
                  THEN '''' || REPLACE(TRIM(wp_visitante), '''', '''''') || ''''
                  ELSE 'NULL' END  -- whatsapp
  || ', ' || COALESCE('''' || REPLACE(TRIM(tipo_visitante), '''', '''''') || '''', 'NULL')  -- tipo_visitante
  || ', ' || CASE WHEN empresa_da_visita IS NOT NULL AND TRIM(empresa_da_visita) != ''
                  THEN '''' || REPLACE(TRIM(empresa_da_visita), '''', '''''') || ''''
                  ELSE 'NULL' END  -- empresa
  || ', ' || COALESCE('''' || REPLACE(TRIM(bloco_da_visita), '''', '''''') || '''', 'NULL')  -- bloco
  || ', ' || COALESCE('''' || REPLACE(TRIM(apto_da_visita), '''', '''''') || '''', 'NULL')  -- apto
  || ', ' || CASE WHEN observacao IS NOT NULL AND TRIM(observacao) != ''
                  THEN '''' || REPLACE(TRIM(observacao), '''', '''''') || ''''
                  ELSE 'NULL' END  -- observacao
  || ', ' || CASE WHEN foto_visitante IS NOT NULL AND TRIM(foto_visitante) != ''
                  THEN '''' || 'https:' || REPLACE(TRIM(foto_visitante), '''', '''''') || ''''
                  ELSE 'NULL' END  -- foto_url (prepend https:)
  || ', ' || COALESCE('''' || data_saida::text || '''', 'NULL')  -- saida_at
  || ', now()'  -- created_at
  || ');' AS insert_sql
FROM tb_aut_entrada_saida
WHERE condominio_txt = 'montserrat'
ORDER BY created_at;
