-- Migration: Allow Anonymous Select for Structure Tables
-- Description: Permite que usuários não logados (novos moradores) vejam blocos, apartamentos e unidades durante o cadastro.

-- 1. Políticas para a tabela 'blocos'
ALTER TABLE public.blocos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anonymous select on blocos" ON public.blocos;
CREATE POLICY "Allow anonymous select on blocos" ON public.blocos
    FOR SELECT USING (true);

-- 2. Políticas para a tabela 'apartamentos'
ALTER TABLE public.apartamentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anonymous select on apartamentos" ON public.apartamentos;
CREATE POLICY "Allow anonymous select on apartamentos" ON public.apartamentos
    FOR SELECT USING (true);

-- 3. Políticas para a tabela 'unidades'
ALTER TABLE public.unidades ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anonymous select on unidades" ON public.unidades;
CREATE POLICY "Allow anonymous select on unidades" ON public.unidades
    FOR SELECT USING (true);

COMMENT ON POLICY "Allow anonymous select on blocos" ON public.blocos IS 'Permite que novos moradores vejam os blocos disponíveis para cadastro.';
COMMENT ON POLICY "Allow anonymous select on apartamentos" ON public.apartamentos IS 'Permite que novos moradores vejam os números de apartamentos disponíveis.';
COMMENT ON POLICY "Allow anonymous select on unidades" ON public.unidades IS 'Permite validar o vínculo entre bloco e apartamento no cadastro.';
