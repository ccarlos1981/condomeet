-- Migration: Create Administradoras table and update RLS for Multi-Tenant bypass

-- 1. Create Administradoras Table
CREATE TABLE IF NOT EXISTS public.administradoras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    cnpj TEXT UNIQUE,
    email TEXT,
    telefone TEXT,
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for administradoras
ALTER TABLE public.administradoras ENABLE ROW LEVEL SECURITY;

-- 2. Add administradora_id to condominios
ALTER TABLE public.condominios 
ADD COLUMN IF NOT EXISTS administradora_id UUID REFERENCES public.administradoras(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_condominios_administradora ON public.condominios(administradora_id);

-- 3. Add administradora_id to perfil
ALTER TABLE public.perfil 
ADD COLUMN IF NOT EXISTS administradora_id UUID REFERENCES public.administradoras(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_perfil_administradora ON public.perfil(administradora_id);

-- 4. Update the core RLS function to support Administradora Bypass
CREATE OR REPLACE FUNCTION public.is_admin_of_condo(condo_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
  v_condo_id uuid;
  v_user_admin_id uuid;
  v_target_condo_admin_id uuid;
BEGIN
  -- Get current user's profile
  SELECT papel_sistema, condominio_id, administradora_id
    INTO v_role, v_condo_id, v_user_admin_id
    FROM perfil
   WHERE id = auth.uid();

  -- 1. ADMINISTRADORA BYPASS
  -- If user is an 'administradora' staff and is linked to an administradora,
  -- check if the target condominium belongs to this administradora.
  IF lower(v_role) = 'administradora' AND v_user_admin_id IS NOT NULL THEN
     SELECT administradora_id INTO v_target_condo_admin_id FROM condominios WHERE id = condo_id;
     RETURN v_target_condo_admin_id = v_user_admin_id;
  END IF;

  -- 2. SÍNDICO/ADMIN STANDARD CHECK
  -- Check if the user belongs directly to this condo AND has an admin-level role
  RETURN v_condo_id = condo_id
     AND lower(v_role) = ANY(ARRAY[
       'síndico', 'sindico', 'admin',
       'síndico (a)', 'sindico (a)',
       'síndico(a)', 'sindico(a)'
     ]);
END;
$$;

-- Note: The `is_admin_of_condo` function is heavily used in RLS policies across the system 
-- (e.g., condominios, fornecedores, etc.). By updating this single function, 
-- we instantly grant Administradoras access to all those resources without having 
-- to rewrite dozens of RLS policies.

-- 5. Policies for Administradoras Table
-- Admins/Sindicos cannot see administradoras directly. 
-- Only users belonging to the administradora can see their own data.
CREATE POLICY "Staff can view own administradora" ON public.administradoras
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM perfil 
      WHERE perfil.id = auth.uid() 
      AND perfil.administradora_id = administradoras.id
    )
  );

CREATE POLICY "Staff can update own administradora" ON public.administradoras
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM perfil 
      WHERE perfil.id = auth.uid() 
      AND perfil.administradora_id = administradoras.id
    )
  );

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_administradoras
  BEFORE UPDATE ON public.administradoras
  FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

