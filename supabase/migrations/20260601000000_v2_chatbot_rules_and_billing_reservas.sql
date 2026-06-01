-- Migration: V2 Chatbot Rules and Booking Billing Integration
-- Tables: condominio_regras, areas_comuns (new column), reservas (new columns)

-- ── 1. CONDOMINIO REGRAS (Regimento Interno por Tópicos) ──
CREATE TABLE IF NOT EXISTS public.condominio_regras (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  categoria     TEXT        NOT NULL, -- ex: 'Silêncio', 'Mudanças', 'Animais'
  titulo        TEXT        NOT NULL, -- ex: 'Mudanças aos sábados'
  conteudo      TEXT        NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.condominio_regras ENABLE ROW LEVEL SECURITY;

-- Index
CREATE INDEX IF NOT EXISTS idx_regras_condominio ON public.condominio_regras(condominio_id);

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_condominio_regras 
  BEFORE UPDATE ON public.condominio_regras 
  FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

-- RLS Policies
DROP POLICY IF EXISTS "admin_regras_all" ON public.condominio_regras;
DROP POLICY IF EXISTS "morador_regras_select" ON public.condominio_regras;

-- Admins/síndicos can do everything on their condo's rules
CREATE POLICY "admin_regras_all" ON public.condominio_regras
  FOR ALL USING (
    public._is_admin_or_sindico()
    AND condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
  )
  WITH CHECK (
    public._is_admin_or_sindico()
    AND condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
  );

-- Residents can view rules of their condo
CREATE POLICY "morador_regras_select" ON public.condominio_regras
  FOR SELECT USING (
    condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
  );

-- ── 2. FULL TEXT SEARCH FUNCTION ──
CREATE OR REPLACE FUNCTION public.buscar_regras_condominio(p_condominio_id UUID, p_busca TEXT)
RETURNS SETOF public.condominio_regras
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT *
  FROM public.condominio_regras
  WHERE condominio_id = p_condominio_id
    AND (
      to_tsvector('portuguese', conteudo || ' ' || titulo) @@ websearch_to_tsquery('portuguese', p_busca)
      OR conteudo ILIKE '%' || p_busca || '%'
      OR titulo ILIKE '%' || p_busca || '%'
    )
  ORDER BY created_at DESC;
$$;

-- ── 3. COLUMNS ON AREAS_COMUNS AND RESERVAS ──

-- Add reservation fee to areas_comuns
ALTER TABLE public.areas_comuns ADD COLUMN IF NOT EXISTS taxa_reserva DECIMAL(12,2) NOT NULL DEFAULT 0.00;

-- Add billing fields to reservas
ALTER TABLE public.reservas ADD COLUMN IF NOT EXISTS valor_reserva DECIMAL(12,2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.reservas ADD COLUMN IF NOT EXISTS status_pagamento TEXT NOT NULL DEFAULT 'isento'
  CHECK (status_pagamento IN ('isento', 'pendente', 'faturado', 'pago'));
