-- ==============================================================================
-- Migration: 20260919090000_convites_security_hardening_rls_and_trigger.sql
-- Módulo: Autorizações de Visitantes / public.convites
-- Objetivo: Hardening de RLS, isolamento multi-tenant estrito, eliminação de 
--           auth.uid() IS NULL e trigger de imutabilidade estrutural.
-- ==============================================================================

-- 1. Remoção de policies legadas / vulneráveis
DROP POLICY IF EXISTS "Portaria pode ver convites do condominio" ON public.convites;
DROP POLICY IF EXISTS "Portaria pode liberar visitante" ON public.convites;
DROP POLICY IF EXISTS "Allow valid invitation inserts" ON public.convites;
DROP POLICY IF EXISTS "Residents can view their own invitations" ON public.convites;
DROP POLICY IF EXISTS "Residents can update their own invitations" ON public.convites;
DROP POLICY IF EXISTS "convites_select_resident" ON public.convites;
DROP POLICY IF EXISTS "convites_select_portaria_admin" ON public.convites;
DROP POLICY IF EXISTS "convites_insert_resident" ON public.convites;
DROP POLICY IF EXISTS "convites_insert_portaria_admin" ON public.convites;
DROP POLICY IF EXISTS "convites_update_resident" ON public.convites;
DROP POLICY IF EXISTS "convites_update_portaria_admin" ON public.convites;

-- 2. SELECT: Morador (suas próprias autorizações com isolamento explícito de condomínio)
CREATE POLICY "convites_select_resident" ON public.convites
FOR SELECT TO authenticated
USING (
  resident_id = (SELECT auth.uid())
  AND condominio_id = (
    SELECT p.condominio_id
    FROM public.perfil p
    WHERE p.id = (SELECT auth.uid())
  )
);

-- 3. SELECT: Portaria / Admins (autorizações do próprio condomínio)
CREATE POLICY "convites_select_portaria_admin" ON public.convites
FOR SELECT TO authenticated
USING (
  condominio_id = (
    SELECT p.condominio_id FROM public.perfil p
    WHERE p.id = (SELECT auth.uid())
      AND lower(trim(p.papel_sistema)) IN (
        'porteiro', 'porteiro (a)', 'porteiro(a)', 'portaria',
        'síndico', 'síndico (a)', 'síndico(a)', 'sindico', 'sindico (a)', 'sindico(a)',
        'subsíndico', 'subsíndico (a)', 'subsíndico(a)', 'subsindico', 'subsindico (a)', 'subsindico(a)', 'sub-síndico',
        'admin', 'administrador', 'administradora'
      )
  )
);

-- 4. INSERT: Morador (somente para si mesmo e em seu próprio condomínio)
CREATE POLICY "convites_insert_resident" ON public.convites
FOR INSERT TO authenticated
WITH CHECK (
  resident_id = (SELECT auth.uid())
  AND condominio_id = (
    SELECT p.condominio_id FROM public.perfil p
    WHERE p.id = (SELECT auth.uid())
  )
);

-- 5. INSERT: Portaria / Admins (somente em seu próprio condomínio)
CREATE POLICY "convites_insert_portaria_admin" ON public.convites
FOR INSERT TO authenticated
WITH CHECK (
  condominio_id = (
    SELECT p.condominio_id FROM public.perfil p
    WHERE p.id = (SELECT auth.uid())
      AND lower(trim(p.papel_sistema)) IN (
        'porteiro', 'porteiro (a)', 'porteiro(a)', 'portaria',
        'síndico', 'síndico (a)', 'síndico(a)', 'sindico', 'sindico (a)', 'sindico(a)',
        'subsíndico', 'subsíndico (a)', 'subsíndico(a)', 'subsindico', 'subsindico (a)', 'subsindico(a)', 'sub-síndico',
        'admin', 'administrador', 'administradora'
      )
  )
);

-- 6. UPDATE: Morador (somente seus próprios convites e garantindo condomínio)
CREATE POLICY "convites_update_resident" ON public.convites
FOR UPDATE TO authenticated
USING (
  resident_id = (SELECT auth.uid())
  AND condominio_id = (
    SELECT p.condominio_id FROM public.perfil p
    WHERE p.id = (SELECT auth.uid())
  )
)
WITH CHECK (
  resident_id = (SELECT auth.uid())
  AND condominio_id = (
    SELECT p.condominio_id FROM public.perfil p
    WHERE p.id = (SELECT auth.uid())
  )
);

-- 7. UPDATE: Portaria / Admins (somente convites de seu próprio condomínio)
CREATE POLICY "convites_update_portaria_admin" ON public.convites
FOR UPDATE TO authenticated
USING (
  condominio_id = (
    SELECT p.condominio_id FROM public.perfil p
    WHERE p.id = (SELECT auth.uid())
      AND lower(trim(p.papel_sistema)) IN (
        'porteiro', 'porteiro (a)', 'porteiro(a)', 'portaria',
        'síndico', 'síndico (a)', 'síndico(a)', 'sindico', 'sindico (a)', 'sindico(a)',
        'subsíndico', 'subsíndico (a)', 'subsíndico(a)', 'subsindico', 'subsindico (a)', 'subsindico(a)', 'sub-síndico',
        'admin', 'administrador', 'administradora'
      )
  )
)
WITH CHECK (
  condominio_id = (
    SELECT p.condominio_id FROM public.perfil p
    WHERE p.id = (SELECT auth.uid())
      AND lower(trim(p.papel_sistema)) IN (
        'porteiro', 'porteiro (a)', 'porteiro(a)', 'portaria',
        'síndico', 'síndico (a)', 'síndico(a)', 'sindico', 'sindico (a)', 'sindico(a)',
        'subsíndico', 'subsíndico (a)', 'subsíndico(a)', 'subsindico', 'subsindico (a)', 'subsindico(a)', 'sub-síndico',
        'admin', 'administrador', 'administradora'
      )
  )
);

-- 8. Trigger de Imutabilidade Estrutural Hardened
CREATE OR REPLACE FUNCTION public.trg_convites_prevent_structural_tampering()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.condominio_id IS DISTINCT FROM OLD.condominio_id THEN
    RAISE EXCEPTION 'Segurança Condomeet: condominio_id é imutável após a criação do convite.';
  END IF;
  IF NEW.resident_id IS DISTINCT FROM OLD.resident_id THEN
    RAISE EXCEPTION 'Segurança Condomeet: resident_id é imutável após a criação do convite.';
  END IF;
  IF NEW.qr_data IS DISTINCT FROM OLD.qr_data THEN
    RAISE EXCEPTION 'Segurança Condomeet: qr_data é imutável após a criação do convite.';
  END IF;
  IF NEW.criado_por_portaria IS DISTINCT FROM OLD.criado_por_portaria THEN
    RAISE EXCEPTION 'Segurança Condomeet: criado_por_portaria é imutável após a criação do convite.';
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.trg_convites_prevent_structural_tampering() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.trg_convites_prevent_structural_tampering() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.trg_convites_prevent_structural_tampering() FROM anon;
GRANT EXECUTE ON FUNCTION public.trg_convites_prevent_structural_tampering() TO authenticated;

DROP TRIGGER IF EXISTS trg_convites_immutability ON public.convites;
CREATE TRIGGER trg_convites_immutability
BEFORE UPDATE ON public.convites
FOR EACH ROW
EXECUTE FUNCTION public.trg_convites_prevent_structural_tampering();
