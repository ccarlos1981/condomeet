-- Allow síndico/admin to see all profiles in their condominium
-- (needed for web admin aprovações page)

CREATE OR REPLACE FUNCTION public.get_user_condo_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT condominio_id FROM public.perfil WHERE id = auth.uid() LIMIT 1;
$$;

-- Policy: síndico can read all profiles in their condo
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'perfil'
      AND policyname = 'sindico_read_condo_profiles'
  ) THEN
    CREATE POLICY sindico_read_condo_profiles ON public.perfil
      FOR SELECT
      USING (
        condominio_id = public.get_user_condo_id()
        AND (
          -- anyone can read their own profile
          id = auth.uid()
          OR
          -- síndico/admin can read all profiles in their condo
          EXISTS (
            SELECT 1 FROM public.perfil AS me
            WHERE me.id = auth.uid()
              AND me.condominio_id = perfil.condominio_id
              AND (
                me.papel_sistema ILIKE '%síndico%'
                OR me.papel_sistema ILIKE '%sindico%'
                OR me.papel_sistema ILIKE '%admin%'
              )
          )
        )
      );
  END IF;
END $$;

-- Policy: síndico can update status_aprovacao for profiles in their condo
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'perfil'
      AND policyname = 'sindico_update_approval_status'
  ) THEN
    CREATE POLICY sindico_update_approval_status ON public.perfil
      FOR UPDATE
      USING (
        condominio_id = public.get_user_condo_id()
        AND EXISTS (
          SELECT 1 FROM public.perfil AS me
          WHERE me.id = auth.uid()
            AND me.condominio_id = perfil.condominio_id
            AND (
              me.papel_sistema ILIKE '%síndico%'
              OR me.papel_sistema ILIKE '%sindico%'
              OR me.papel_sistema ILIKE '%admin%'
            )
        )
      )
      WITH CHECK (true);
  END IF;
END $$;
