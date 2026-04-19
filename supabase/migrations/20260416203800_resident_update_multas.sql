-- Migration to allow residents to update read status

CREATE POLICY "resident_update_read_multas"
  ON public.notificacoes_multas FOR UPDATE
  USING (
    unidade_id IN (
      SELECT unidade_id FROM public.unidade_perfil WHERE perfil_id = auth.uid()
    )
  );

-- Note: We are allowing update to be filtered by auth.uid(). 
-- Strictly speaking we could use a WITH CHECK but `USING` is sufficient for updates 
-- where the resident shouldn't be changing `unidade_id` anyway.
