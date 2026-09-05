-- Migration: 20260818150000_fix_documentos_contratos_rls.sql
-- Description: Atualização das políticas RLS para public.documentos, public.doc_pastas, public.contratos e public.contrato_pastas utilizando a função centralizada e homologada public.is_admin_of_condo(condominio_id).

-- ── 1. PUBLIC.DOCUMENTOS ────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_documentos_all" ON public.documentos;

CREATE POLICY "admin_documentos_all"
  ON public.documentos
  FOR ALL
  USING (
    public.is_admin_of_condo(condominio_id)
  )
  WITH CHECK (
    public.is_admin_of_condo(condominio_id)
  );

-- A política "morador_ve_documentos" permanece intacta e inalterada:
-- FOR SELECT USING (mostrar_moradores = true AND condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid()))

-- ── 2. PUBLIC.DOC_PASTAS ────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_doc_pastas_all" ON public.doc_pastas;

CREATE POLICY "admin_doc_pastas_all"
  ON public.doc_pastas
  FOR ALL
  USING (
    public.is_admin_of_condo(condominio_id)
  )
  WITH CHECK (
    public.is_admin_of_condo(condominio_id)
  );

-- ── 3. PUBLIC.CONTRATOS ─────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_contratos_all" ON public.contratos;

CREATE POLICY "admin_contratos_all"
  ON public.contratos
  FOR ALL
  USING (
    public.is_admin_of_condo(condominio_id)
  )
  WITH CHECK (
    public.is_admin_of_condo(condominio_id)
  );

-- ── 4. PUBLIC.CONTRATO_PASTAS ───────────────────────────────────────
DROP POLICY IF EXISTS "admin_contrato_pastas_all" ON public.contrato_pastas;

CREATE POLICY "admin_contrato_pastas_all"
  ON public.contrato_pastas
  FOR ALL
  USING (
    public.is_admin_of_condo(condominio_id)
  )
  WITH CHECK (
    public.is_admin_of_condo(condominio_id)
  );
