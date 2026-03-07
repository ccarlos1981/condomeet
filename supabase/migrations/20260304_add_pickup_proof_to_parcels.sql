-- Migration: Add pickup_proof_url to parcels
-- Description: Adds a column to store the PIN or Photo path as proof of delivery.

ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS pickup_proof_url TEXT;

-- Update RLS if necessary (usually not needed for just a new column if broad policies exist)
COMMENT ON COLUMN public.parcels.pickup_proof_url IS 'Caminho da foto ou PIN usado como comprovante de retirada.';
