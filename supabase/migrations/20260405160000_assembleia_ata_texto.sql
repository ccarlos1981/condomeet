-- ============================================================
-- Migration: 20260405160000_assembleia_ata_texto
-- Adiciona campo para armazenar o corpo jurídico da ATA
-- ============================================================

ALTER TABLE public.assembleias ADD COLUMN IF NOT EXISTS ata_texto TEXT;

COMMENT ON COLUMN public.assembleias.ata_texto IS 'Conteúdo gerado da ATA em formato texto livre para edição do síndico';
