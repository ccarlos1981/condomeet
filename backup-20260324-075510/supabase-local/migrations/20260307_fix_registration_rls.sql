-- Migration: Fix RLS for Registration Flow (Schema 2.0)
-- Description: Garante que as novas tabelas em Português tenham permissões de INSERT para o fluxo de cadastro.

-- 1. TABELA: condominios
ALTER TABLE public.condominios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow any insert for registration" ON public.condominios;
CREATE POLICY "Allow any insert for registration" ON public.condominios
    FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Allow any select" ON public.condominios;
CREATE POLICY "Allow any select" ON public.condominios
    FOR SELECT USING (true);

-- 2. TABELA: blocos
ALTER TABLE public.blocos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow any insert for registration" ON public.blocos;
CREATE POLICY "Allow any insert for registration" ON public.blocos
    FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Allow any select" ON public.blocos;
CREATE POLICY "Allow any select" ON public.blocos
    FOR SELECT USING (true);

-- 3. TABELA: apartamentos
ALTER TABLE public.apartamentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow any insert for registration" ON public.apartamentos;
CREATE POLICY "Allow any insert for registration" ON public.apartamentos
    FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Allow any select" ON public.apartamentos;
CREATE POLICY "Allow any select" ON public.apartamentos
    FOR SELECT USING (true);

-- 4. TABELA: unidades
ALTER TABLE public.unidades ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow any insert for registration" ON public.unidades;
CREATE POLICY "Allow any insert for registration" ON public.unidades
    FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Allow any select" ON public.unidades;
CREATE POLICY "Allow any select" ON public.unidades
    FOR SELECT USING (true);

-- 5. TABELA: perfil
ALTER TABLE public.perfil ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow any insert for registration" ON public.perfil;
CREATE POLICY "Allow any insert for registration" ON public.perfil
    FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Allow any select" ON public.perfil;
CREATE POLICY "Allow any select" ON public.perfil
    FOR SELECT USING (true);

-- 6. TABELA: unidade_perfil
ALTER TABLE public.unidade_perfil ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow any insert" ON public.unidade_perfil;
CREATE POLICY "Allow any insert" ON public.unidade_perfil
    FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Allow any select" ON public.unidade_perfil;
CREATE POLICY "Allow any select" ON public.unidade_perfil
    FOR SELECT USING (true);

COMMENT ON TABLE public.condominios IS 'Acesso público para leitura e inserção durante cadastro.';
COMMENT ON TABLE public.blocos IS 'Acesso público para leitura e inserção durante cadastro.';
COMMENT ON TABLE public.apartamentos IS 'Acesso público para leitura e inserção durante cadastro.';
COMMENT ON TABLE public.unidades IS 'Acesso público para leitura e inserção durante cadastro.';
COMMENT ON TABLE public.perfil IS 'Acesso público para leitura e inserção durante cadastro.';
COMMENT ON TABLE public.unidade_perfil IS 'Acesso público para leitura e inserção durante cadastro.';
