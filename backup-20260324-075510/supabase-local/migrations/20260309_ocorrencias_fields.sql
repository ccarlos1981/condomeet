-- Migração: Adiciona campos de assunto e resposta admin às ocorrências
-- Data: 2026-03-09

-- Adiciona campo assunto (título curto da ocorrência)
ALTER TABLE ocorrencias
  ADD COLUMN IF NOT EXISTS assunto TEXT,
  ADD COLUMN IF NOT EXISTS photo_url TEXT,
  ADD COLUMN IF NOT EXISTS admin_response TEXT,
  ADD COLUMN IF NOT EXISTS admin_response_at TIMESTAMPTZ;

-- Atualiza RLS para leitura (moradores veem só as próprias, admin vê todas)
-- A política de insert/select existente já cobre isso via occurrence_repository_impl
-- Mas garantimos que o admin pode fazer UPDATE na resposta:
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'ocorrencias'
    AND policyname = 'Admin can respond to occurrences'
  ) THEN
    CREATE POLICY "Admin can respond to occurrences"
      ON ocorrencias
      FOR UPDATE
      USING (
        condominium_id IN (
          SELECT condominio_id FROM perfil
          WHERE id = auth.uid()
          AND papel_sistema IN ('ADMIN', 'Síndico')
        )
      );
  END IF;
END $$;
