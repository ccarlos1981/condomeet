-- Migration: 20260920230000_add_min_version_columns_to_app_version_policy.sql
-- Descrição: Permite min_android_build e min_ios_build como NULL (modo SemVer) e adiciona colunas opcionais min_android_version e min_ios_version

-- 1. Permitir NULL nos campos de build (necessário para modo puramente SemVer)
ALTER TABLE public.app_version_policy
  ALTER COLUMN min_android_build DROP NOT NULL,
  ALTER COLUMN min_ios_build DROP NOT NULL;

-- 2. Atualizar constraints de validação de build para aceitar NULL
ALTER TABLE public.app_version_policy
  DROP CONSTRAINT IF EXISTS valid_android_build,
  ADD CONSTRAINT valid_android_build CHECK (min_android_build IS NULL OR (min_android_build BETWEEN 1 AND 50000));

ALTER TABLE public.app_version_policy
  DROP CONSTRAINT IF EXISTS valid_ios_build,
  ADD CONSTRAINT valid_ios_build CHECK (min_ios_build IS NULL OR (min_ios_build BETWEEN 1 AND 50000));

-- 3. Adicionar colunas opcionais de versão mínima (NULL, sem valor default fixo)
ALTER TABLE public.app_version_policy
  ADD COLUMN IF NOT EXISTS min_android_version TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS min_ios_version TEXT DEFAULT NULL;
