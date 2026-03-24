-- Migration: 20260308 - Encomendas Web Fields
-- Description: Adds new fields to support the web registration form (tipo, tracking_code, observacao)
--              onto the ENCOMENDAS table (used by the Flutter app and Schema 2.0).
--              Also sets up Supabase Storage bucket policies for parcel photos.

-- ============================================================
-- 1. New columns on encomendas table
-- ============================================================

ALTER TABLE public.encomendas
  ADD COLUMN IF NOT EXISTS tipo TEXT CHECK (tipo IN ('caixa', 'envelope', 'pacote', 'notif_judicial')),
  ADD COLUMN IF NOT EXISTS tracking_code TEXT,
  ADD COLUMN IF NOT EXISTS observacao TEXT,
  ADD COLUMN IF NOT EXISTS registered_by UUID REFERENCES public.perfil(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.encomendas.tipo          IS 'Tipo da encomenda: caixa, envelope, pacote ou notif_judicial';
COMMENT ON COLUMN public.encomendas.tracking_code IS 'Código de rastreio dos Correios ou transportadora';
COMMENT ON COLUMN public.encomendas.observacao    IS 'Observação livre sobre a encomenda';
COMMENT ON COLUMN public.encomendas.registered_by IS 'UUID do porteiro que registrou a encomenda';

-- ============================================================
-- 2. RLS: allow portaria/admin to INSERT on encomendas
-- ============================================================

ALTER TABLE public.encomendas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "portaria_insert_encomenda" ON public.encomendas;
CREATE POLICY "portaria_insert_encomenda"
ON public.encomendas FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = public.encomendas.condominio_id
      AND (
        p.papel_sistema ILIKE '%portaria%' OR p.papel_sistema ILIKE '%porteiro%'
        OR p.papel_sistema ILIKE '%síndico%' OR p.papel_sistema ILIKE '%sindico%'
        OR p.papel_sistema = 'admin'
      )
  )
);

-- Portaria can SELECT all encomendas in their condominium
DROP POLICY IF EXISTS "portaria_select_encomendas" ON public.encomendas;
CREATE POLICY "portaria_select_encomendas"
ON public.encomendas FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = public.encomendas.condominio_id
      AND (
        p.papel_sistema ILIKE '%portaria%' OR p.papel_sistema ILIKE '%porteiro%'
        OR p.papel_sistema ILIKE '%síndico%' OR p.papel_sistema ILIKE '%sindico%'
        OR p.papel_sistema = 'admin'
      )
  )
);

-- Moradores can see only THEIR encomendas
DROP POLICY IF EXISTS "morador_select_proprias_encomendas" ON public.encomendas;
CREATE POLICY "morador_select_proprias_encomendas"
ON public.encomendas FOR SELECT TO authenticated
USING (resident_id = auth.uid());

-- Portaria can UPDATE (mark as delivered)
DROP POLICY IF EXISTS "portaria_update_encomenda" ON public.encomendas;
CREATE POLICY "portaria_update_encomenda"
ON public.encomendas FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = public.encomendas.condominio_id
      AND (
        p.papel_sistema ILIKE '%portaria%' OR p.papel_sistema ILIKE '%porteiro%'
        OR p.papel_sistema ILIKE '%síndico%' OR p.papel_sistema ILIKE '%sindico%'
        OR p.papel_sistema = 'admin'
      )
  )
);

-- ============================================================
-- 3. Supabase Storage — create bucket parcel-photos
-- ============================================================

-- Create the bucket (idempotent)
INSERT INTO storage.buckets (id, name, public)
VALUES ('parcel-photos', 'parcel-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Upload policy: portaria can upload
DROP POLICY IF EXISTS "portaria_upload_parcel_photo" ON storage.objects;
CREATE POLICY "portaria_upload_parcel_photo"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'parcel-photos'
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

DROP POLICY IF EXISTS "authenticated_view_parcel_photo" ON storage.objects;
CREATE POLICY "authenticated_view_parcel_photo"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'parcel-photos');
