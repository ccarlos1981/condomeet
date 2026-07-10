-- Migration: Secure estoque-notas bucket RLS policies to prevent cross-condo access
-- Date: 2026-07-10

-- Recreate storage policies with cross-condo validation (checking folder segment in the path name)
-- The second path segment (split_part(name, '/', 2)) represents the condominio_id.
-- We compare it with p.condominio_id::text to avoid casting errors if the segment is not a valid UUID.

DROP POLICY IF EXISTS "estoque_notas_upload" ON storage.objects;
CREATE POLICY "estoque_notas_upload"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'estoque-notes' OR bucket_id = 'estoque-notas'
  AND EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
    AND p.condominio_id::text = split_part(name, '/', 2)
    AND (
      p.papel_sistema ILIKE '%síndico%' 
      OR p.papel_sistema ILIKE '%sindico%' 
      OR p.papel_sistema ILIKE '%admin%'
      OR p.papel_sistema ILIKE '%super_admin%'
      OR p.papel_sistema ILIKE '%zelador%'
      OR p.papel_sistema ILIKE '%funcionario%'
      OR p.papel_sistema ILIKE '%porteiro%'
    )
  )
);

DROP POLICY IF EXISTS "estoque_notas_select" ON storage.objects;
CREATE POLICY "estoque_notas_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'estoque-notas'
  AND EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
    AND p.condominio_id::text = split_part(name, '/', 2)
    AND (
      p.papel_sistema ILIKE '%síndico%' 
      OR p.papel_sistema ILIKE '%sindico%' 
      OR p.papel_sistema ILIKE '%admin%'
      OR p.papel_sistema ILIKE '%super_admin%'
      OR p.papel_sistema ILIKE '%zelador%'
      OR p.papel_sistema ILIKE '%funcionario%'
      OR p.papel_sistema ILIKE '%porteiro%'
    )
  )
);

DROP POLICY IF EXISTS "estoque_notas_update" ON storage.objects;
CREATE POLICY "estoque_notas_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'estoque-notas'
  AND EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
    AND p.condominio_id::text = split_part(name, '/', 2)
    AND (
      p.papel_sistema ILIKE '%síndico%' 
      OR p.papel_sistema ILIKE '%sindico%' 
      OR p.papel_sistema ILIKE '%admin%'
      OR p.papel_sistema ILIKE '%super_admin%'
      OR p.papel_sistema ILIKE '%zelador%'
      OR p.papel_sistema ILIKE '%funcionario%'
      OR p.papel_sistema ILIKE '%porteiro%'
    )
  )
);

DROP POLICY IF EXISTS "estoque_notas_delete" ON storage.objects;
CREATE POLICY "estoque_notas_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'estoque-notas'
  AND EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
    AND p.condominio_id::text = split_part(name, '/', 2)
    AND (
      p.papel_sistema ILIKE '%síndico%' 
      OR p.papel_sistema ILIKE '%sindico%' 
      OR p.papel_sistema ILIKE '%admin%'
      OR p.papel_sistema ILIKE '%super_admin%'
      OR p.papel_sistema ILIKE '%zelador%'
      OR p.papel_sistema ILIKE '%funcionario%'
      OR p.papel_sistema ILIKE '%porteiro%'
    )
  )
);
