-- =================================================================
-- Migration: 20260314_convites_add_columns
-- Adds: visitor_type, visitante_compareceu, whatsapp, observacao,
--        liberado_em to convites table (align web with mobile)
-- =================================================================

-- Add visitor_type column
ALTER TABLE convites ADD COLUMN IF NOT EXISTS visitor_type TEXT;

-- Add visitante_compareceu flag
ALTER TABLE convites ADD COLUMN IF NOT EXISTS visitante_compareceu BOOLEAN DEFAULT FALSE;

-- Add liberado_em timestamp
ALTER TABLE convites ADD COLUMN IF NOT EXISTS liberado_em TIMESTAMPTZ;

-- Add whatsapp for visitor contact
ALTER TABLE convites ADD COLUMN IF NOT EXISTS whatsapp TEXT;

-- Add observacao for notes
ALTER TABLE convites ADD COLUMN IF NOT EXISTS observacao TEXT;
