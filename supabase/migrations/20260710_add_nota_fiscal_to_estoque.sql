-- Migration: Add nota_fiscal_path to estoque_movimentacoes and create private storage bucket
-- Date: 2026-07-10

-- 1. Add column to public.estoque_movimentacoes
ALTER TABLE public.estoque_movimentacoes 
ADD COLUMN IF NOT EXISTS nota_fiscal_path text;

-- 2. Create the private bucket 'estoque-notas' (public = false)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'estoque-notas', 
  'estoque-notas', 
  false, 
  10485760, -- 10MB limit in bytes
  ARRAY['application/pdf', 'image/jpeg', 'image/png']
)
ON CONFLICT (id) DO UPDATE 
SET public = false,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['application/pdf', 'image/jpeg', 'image/png'];

-- 3. Storage RLS policies for 'estoque-notas'
-- Allow authenticated users to upload files
DROP POLICY IF EXISTS "estoque_notas_upload" ON storage.objects;
CREATE POLICY "estoque_notas_upload"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'estoque-notas');

-- Allow authenticated users to view/select files (needed for generating signed URLs)
DROP POLICY IF EXISTS "estoque_notas_select" ON storage.objects;
CREATE POLICY "estoque_notas_select"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'estoque-notas');

-- Allow authenticated users to update files (in case they replace/overwrite)
DROP POLICY IF EXISTS "estoque_notas_update" ON storage.objects;
CREATE POLICY "estoque_notas_update"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'estoque-notas');

-- Allow authenticated users to delete files
DROP POLICY IF EXISTS "estoque_notas_delete" ON storage.objects;
CREATE POLICY "estoque_notas_delete"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'estoque-notas');
