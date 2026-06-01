-- Migration: Add gateway_account_id to condominios for Split Payments (Sub-contas)

ALTER TABLE public.condominios 
ADD COLUMN IF NOT EXISTS gateway_account_id TEXT;

COMMENT ON COLUMN public.condominios.gateway_account_id IS 'ID of the Sub-account (Wallet) in the Payment Gateway (e.g., Asaas) for receiving the 97% split.';
