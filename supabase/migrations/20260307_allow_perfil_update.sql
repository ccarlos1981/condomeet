-- Migration: Allow UPDATE on perfil table
-- Description: Permite que o Síndico (ou qualquer usuário autenticado por enquanto) atualize o status de aprovação.

ALTER TABLE public.perfil ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow any update" ON public.perfil;
CREATE POLICY "Allow any update" ON public.perfil
    FOR UPDATE USING (true) WITH CHECK (true);

COMMENT ON TABLE public.perfil IS 'Acesso público para leitura, inserção e atualização durante o fluxo de aprovação.';
