-- Adiciona campos para o modelo de cobrança (Fixo vs Rateio) na tabela condominios

ALTER TABLE public.condominios 
ADD COLUMN IF NOT EXISTS modelo_cobranca_padrao TEXT DEFAULT 'fixo' CHECK (modelo_cobranca_padrao IN ('fixo', 'rateio_despesas')),
ADD COLUMN IF NOT EXISTS valor_cota_padrao DECIMAL(12,2) DEFAULT 0.00;

COMMENT ON COLUMN public.condominios.modelo_cobranca_padrao IS 'Define se o condomínio usa uma cota fixa ou rateia as despesas mensais';
COMMENT ON COLUMN public.condominios.valor_cota_padrao IS 'Valor base da cota caso o modelo seja fixo';
