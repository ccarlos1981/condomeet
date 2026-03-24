-- Migration: Add email to perfil and create verification RPC
-- This allows checking if an email is already in use securely.

-- 1. Add email column to perfil if it doesn't exist
ALTER TABLE public.perfil ADD COLUMN IF NOT EXISTS email TEXT;

-- 2. Create index for faster search
CREATE INDEX IF NOT EXISTS idx_perfil_email ON public.perfil (email);

-- 3. Create a secure RPC function to check email existence
-- This function runs with SECURITY DEFINER to bypass RLS safely for this specific check
CREATE OR REPLACE FUNCTION public.check_email_exists(email_to_check TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.perfil WHERE LOWER(email) = LOWER(email_to_check)
    UNION
    SELECT 1 FROM auth.users WHERE LOWER(email) = LOWER(email_to_check)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Grant execution permissions to everyone (even non-logged users)
GRANT EXECUTE ON FUNCTION public.check_email_exists TO anon, authenticated, service_role;

-- NOTE: After applying this, you might want to backfill the email column 
-- for existing profiles where it's NULL, using auth.users data.
-- UPDATE public.perfil p SET email = u.email FROM auth.users u WHERE p.id = u.id AND p.email IS NULL;
