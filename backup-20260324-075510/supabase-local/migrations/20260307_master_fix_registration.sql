-- Migration: Final Fix for Sindico Registration and RLS
-- Description: Adiciona coluna faltante e garante permissões totais para o fluxo de cadastro e estrutura.

-- 1. ADICIONAR COLUNA FALTANTE (O que causou o erro técnico no registro)
ALTER TABLE public.condominios ADD COLUMN IF NOT EXISTS tipo_estrutura TEXT DEFAULT 'predio';

-- 2. GARANTIR EXTENSÃO UUID (Prevenção de erro de função não encontrada)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 3. PERMISSÕES TOTAIS PARA TABELAS DE ESTRUTURA (Evitar bloqueios em INSERT/SELECT/UPDATE/DELETE)
-- Aplicamos para 'anon' (quem está cadastrando) e 'authenticated' (quem já entrou)

-- Condominios
ALTER TABLE public.condominios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Full Access Condominios" ON public.condominios;
CREATE POLICY "Public Full Access Condominios" ON public.condominios FOR ALL USING (true) WITH CHECK (true);

-- Blocos
ALTER TABLE public.blocos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Full Access Blocos" ON public.blocos;
CREATE POLICY "Public Full Access Blocos" ON public.blocos FOR ALL USING (true) WITH CHECK (true);

-- Apartamentos
ALTER TABLE public.apartamentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Full Access Apartamentos" ON public.apartamentos;
CREATE POLICY "Public Full Access Apartamentos" ON public.apartamentos FOR ALL USING (true) WITH CHECK (true);

-- Unidades
ALTER TABLE public.unidades ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Full Access Unidades" ON public.unidades;
CREATE POLICY "Public Full Access Unidades" ON public.unidades FOR ALL USING (true) WITH CHECK (true);

-- Perfil
ALTER TABLE public.perfil ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Full Access Perfil" ON public.perfil;
CREATE POLICY "Public Full Access Perfil" ON public.perfil FOR ALL USING (true) WITH CHECK (true);

-- Unidade Perfil
ALTER TABLE public.unidade_perfil ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Full Access Unidade Perfil" ON public.unidade_perfil;
CREATE POLICY "Public Full Access Unidade Perfil" ON public.unidade_perfil FOR ALL USING (true) WITH CHECK (true);

COMMENT ON COLUMN public.condominios.tipo_estrutura IS 'Define se o condomínio usa Prédio (Bloco/Apto) ou Casas.';
