-- Migration: 20260308b - Encomendas Baixa Fields
-- Adds picked_up_by_id and picked_up_by_name to track WHO picked up the parcel

ALTER TABLE public.encomendas
  ADD COLUMN IF NOT EXISTS picked_up_by_id   UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS picked_up_by_name TEXT;

COMMENT ON COLUMN public.encomendas.picked_up_by_id   IS 'UUID do morador que retirou a encomenda (se cadastrado)';
COMMENT ON COLUMN public.encomendas.picked_up_by_name IS 'Nome do terceiro que retirou (quando não é morador cadastrado)';
