-- Create system_superadmins table to centralize global admin privileges
CREATE TABLE IF NOT EXISTS public.system_superadmins (
  email text PRIMARY KEY
);

-- Enable RLS (Read-only for authenticated, write restricted to service_role)
ALTER TABLE public.system_superadmins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read access to system_superadmins"
  ON public.system_superadmins
  FOR SELECT
  TO authenticated
  USING (true);

-- Insert current superadmins
INSERT INTO public.system_superadmins (email)
VALUES 
  ('ccarlos1981+60@gmail.com'),
  ('cristiano.santos@gmx.com'),
  ('erikaosc@gmail.com')
ON CONFLICT (email) DO NOTHING;
