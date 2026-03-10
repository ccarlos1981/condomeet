-- Allow síndico/admin to update their condominium record (e.g. features_config)

CREATE OR REPLACE FUNCTION is_admin_of_condo(condo_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
  v_condo_id uuid;
BEGIN
  SELECT papel_sistema, condominio_id
    INTO v_role, v_condo_id
    FROM perfil
   WHERE id = auth.uid();

  -- Check if the user belongs to this condo AND has an admin-level role
  RETURN v_condo_id = condo_id
     AND lower(v_role) = ANY(ARRAY[
       'síndico', 'sindico', 'admin',
       'síndico (a)', 'sindico (a)',
       'síndico(a)', 'sindico(a)'
     ]);
END;
$$;

-- UPDATE policy: síndico ou admin podem atualizar seu próprio condomínio
DROP POLICY IF EXISTS "Sindico can update their condominium" ON condominios;
CREATE POLICY "Sindico can update their condominium"
  ON condominios
  FOR UPDATE
  USING (is_admin_of_condo(id))
  WITH CHECK (is_admin_of_condo(id));
