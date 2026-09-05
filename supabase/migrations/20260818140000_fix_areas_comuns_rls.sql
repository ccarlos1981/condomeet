-- Migration: 20260818140000_fix_areas_comuns_rls.sql
-- Description: Update is_admin_of_condo helper function to support superadmins and expanded role names, and update areas_comuns RLS policies.

CREATE OR REPLACE FUNCTION public.is_admin_of_condo(condo_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_role text;
  v_condo_id uuid;
  v_user_admin_id uuid;
  v_email text;
BEGIN
  -- 1. Get user profile
  SELECT papel_sistema, condominio_id, administradora_id, email
    INTO v_role, v_condo_id, v_user_admin_id, v_email
    FROM perfil
   WHERE id = auth.uid();

  IF v_role IS NULL AND v_email IS NULL THEN
    RETURN false;
  END IF;

  -- 2. SUPERADMIN BYPASS
  IF EXISTS (
    SELECT 1 FROM public.system_superadmins s
    WHERE lower(s.email) = lower(v_email)
  ) THEN
    RETURN true;
  END IF;

  -- 3. ADMINISTRADORA BYPASS
  IF lower(v_role) = 'administradora' AND v_user_admin_id IS NOT NULL THEN
     RETURN EXISTS (
       SELECT 1 FROM public.condominios WHERE id = condo_id AND administradora_id = v_user_admin_id
     );
  END IF;

  -- 4. SÍNDICO / ADMIN STANDARD CHECK
  RETURN v_condo_id = condo_id
     AND lower(v_role) = ANY(ARRAY[
       'síndico', 'sindico', 'admin', 'administrador',
       'síndico (a)', 'sindico (a)', 'síndico(a)', 'sindico(a)',
       'subsíndico', 'subsindico', 'subsíndico (a)', 'subsindico (a)', 'subsíndico(a)', 'subsindico(a)'
     ]);
END;
$function$;

-- Update admin_manage_areas_comuns RLS policy to use is_admin_of_condo
DROP POLICY IF EXISTS "admin_manage_areas_comuns" ON public.areas_comuns;

CREATE POLICY "admin_manage_areas_comuns"
  ON public.areas_comuns
  FOR ALL
  USING (is_admin_of_condo(condominio_id))
  WITH CHECK (is_admin_of_condo(condominio_id));

-- Resident read policy for active areas
DROP POLICY IF EXISTS "resident_read_areas_comuns" ON public.areas_comuns;

CREATE POLICY "resident_read_areas_comuns"
  ON public.areas_comuns
  FOR SELECT
  USING (
    ativo = true AND
    (
      is_admin_of_condo(condominio_id) OR
      condominio_id IN (SELECT p.condominio_id FROM public.perfil p WHERE p.id = auth.uid())
    )
  );
