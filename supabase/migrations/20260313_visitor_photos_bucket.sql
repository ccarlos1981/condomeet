-- ============================================================
-- Storage bucket for visitor photos
-- ============================================================

-- Create the bucket (idempotent)
INSERT INTO storage.buckets (id, name, public)
VALUES ('visitor-photos', 'visitor-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Upload policy: portaria can upload
DROP POLICY IF EXISTS "portaria_upload_visitor_photo" ON storage.objects;
CREATE POLICY "portaria_upload_visitor_photo"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'visitor-photos'
  AND EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND (
        p.papel_sistema ILIKE '%portaria%' OR p.papel_sistema ILIKE '%porteiro%'
        OR p.papel_sistema ILIKE '%síndico%' OR p.papel_sistema ILIKE '%sindico%'
        OR p.papel_sistema = 'admin'
      )
  )
);

-- Read policy: any authenticated user can see visitor photos
DROP POLICY IF EXISTS "authenticated_view_visitor_photo" ON storage.objects;
CREATE POLICY "authenticated_view_visitor_photo"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'visitor-photos');
