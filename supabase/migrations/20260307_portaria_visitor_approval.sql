-- Migration: Portaria Visitor Approval
-- Description: Adiciona campos de liberação de visitante na tabela convites
--              e ajusta RLS para portaria poder ler e atualizar convites do condomínio.

-- 1. Adicionar campos de controle de liberação
ALTER TABLE public.convites
  ADD COLUMN IF NOT EXISTS visitante_compareceu BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS liberado_por UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS liberado_em TIMESTAMPTZ;

-- 2. RLS: Portaria (e Síndico/ADMIN) pode VER todos os convites do condomínio
DROP POLICY IF EXISTS "Portaria pode ver convites do condominio" ON public.convites;
CREATE POLICY "Portaria pode ver convites do condominio"
ON public.convites FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
    AND p.condominio_id = convites.condominio_id
    AND p.papel_sistema IN ('Portaria', 'Síndico', 'ADMIN', 'Zelador', 'Funcionário')
  )
);

-- 3. RLS: Portaria pode ATUALIZAR visitante_compareceu, liberado_por, liberado_em
DROP POLICY IF EXISTS "Portaria pode liberar visitante" ON public.convites;
CREATE POLICY "Portaria pode liberar visitante"
ON public.convites FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
    AND p.condominio_id = convites.condominio_id
    AND p.papel_sistema IN ('Portaria', 'Síndico', 'ADMIN', 'Zelador', 'Funcionário')
  )
);

-- 4. Garantir que convites está na publicação do PowerSync
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'powersync' AND schemaname = 'public' AND tablename = 'convites'
    ) THEN
        ALTER PUBLICATION powersync ADD TABLE public.convites;
    END IF;
END $$;
