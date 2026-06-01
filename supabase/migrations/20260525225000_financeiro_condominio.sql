-- Migration: Create Financial Management and Billing Schema for Condos
-- Features: Chart of Accounts, Bank Accounts, Transactions, Budgets, and Invoices (Boletos)

-- 1. Contas Bancárias do Condomínio
CREATE TABLE IF NOT EXISTS public.condominio_contas_bancarias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  banco TEXT NOT NULL,
  agencia TEXT,
  conta TEXT,
  descricao TEXT NOT NULL, -- Ex: Conta Principal, Fundo de Reserva
  saldo_inicial DECIMAL(12,2) DEFAULT 0,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Plano de Contas do Condomínio (Categorias de Receitas/Despesas)
CREATE TABLE IF NOT EXISTS public.condominio_plano_contas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  codigo TEXT NOT NULL, -- Ex: '1.1', '2.1.3'
  nome TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('receita', 'despesa')),
  parent_id UUID REFERENCES public.condominio_plano_contas(id) ON DELETE CASCADE,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(condominio_id, codigo)
);

-- 3. Lançamentos Financeiros (Livro Caixa)
CREATE TABLE IF NOT EXISTS public.condominio_lancamentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  conta_bancaria_id UUID NOT NULL REFERENCES public.condominio_contas_bancarias(id) ON DELETE RESTRICT,
  plano_conta_id UUID NOT NULL REFERENCES public.condominio_plano_contas(id) ON DELETE RESTRICT,
  tipo TEXT NOT NULL CHECK (tipo IN ('receita', 'despesa')),
  descricao TEXT NOT NULL,
  valor DECIMAL(12,2) NOT NULL,
  data_vencimento DATE NOT NULL,
  data_pagamento DATE,
  status TEXT DEFAULT 'pendente' CHECK (status IN ('pendente', 'pago', 'cancelado')),
  fornecedor_id UUID REFERENCES public.fornecedores(id) ON DELETE SET NULL,
  comprovante_url TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Orçamento Anual (Previsibilidade e Metas)
CREATE TABLE IF NOT EXISTS public.condominio_orcamentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  ano INT NOT NULL,
  mes INT NOT NULL,
  plano_conta_id UUID NOT NULL REFERENCES public.condominio_plano_contas(id) ON DELETE CASCADE,
  valor_previsto DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(condominio_id, ano, mes, plano_conta_id)
);

-- 5. Faturamentos (Boletos/Rateio)
CREATE TABLE IF NOT EXISTS public.faturamentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES public.unidades(id) ON DELETE CASCADE,
  morador_id UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
  mes_referencia DATE NOT NULL, -- '2026-05-01' para representar o mes de maio
  data_vencimento DATE NOT NULL,
  valor_total DECIMAL(12,2) NOT NULL,
  status_pagamento TEXT DEFAULT 'pendente' CHECK (status_pagamento IN ('pendente', 'pago', 'vencido', 'cancelado')),
  gateway_fatura_id TEXT, -- ID no Gateway (ex: Asaas)
  external_boleto_id TEXT, -- ID antigo/alternativo
  external_boleto_url TEXT, -- Link do antigo
  data_pagamento DATE,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. Itens do Faturamento (Composição da Cobrança)
CREATE TABLE IF NOT EXISTS public.faturamento_itens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  faturamento_id UUID NOT NULL REFERENCES public.faturamentos(id) ON DELETE CASCADE,
  descricao TEXT NOT NULL, -- 'Taxa Condominial', 'Fundo de Reserva', 'Consumo Água', 'Multa - Regra 12'
  valor DECIMAL(12,2) NOT NULL,
  tipo_item TEXT NOT NULL, -- 'ordinaria', 'extra', 'consumo', 'multa', 'reserva'
  referencia_id UUID, -- Opcional: ID da multa, da reserva ou da leitura de consumo para rastreabilidade
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes for performance
CREATE INDEX idx_lancamentos_condominio ON public.condominio_lancamentos(condominio_id);
CREATE INDEX idx_lancamentos_data ON public.condominio_lancamentos(data_vencimento);
CREATE INDEX idx_faturamentos_condominio ON public.faturamentos(condominio_id);
CREATE INDEX idx_faturamentos_unidade ON public.faturamentos(unidade_id);
CREATE INDEX idx_faturamentos_status ON public.faturamentos(status_pagamento);

-- Enable RLS
ALTER TABLE public.condominio_contas_bancarias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.condominio_plano_contas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.condominio_lancamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.condominio_orcamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faturamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faturamento_itens ENABLE ROW LEVEL SECURITY;

-- Triggers for updated_at
CREATE TRIGGER set_updated_at_condominio_contas_bancarias BEFORE UPDATE ON public.condominio_contas_bancarias FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_condominio_lancamentos BEFORE UPDATE ON public.condominio_lancamentos FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_faturamentos BEFORE UPDATE ON public.faturamentos FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

-- RLS Policies

-- Admins/Sindicos can do everything on their condo's financial data
CREATE POLICY "Admins can view financial accounts" ON public.condominio_contas_bancarias FOR SELECT USING (EXISTS (SELECT 1 FROM perfil WHERE perfil.id = auth.uid() AND perfil.condominio_id = condominio_contas_bancarias.condominio_id AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')));
CREATE POLICY "Admins can modify financial accounts" ON public.condominio_contas_bancarias FOR ALL USING (EXISTS (SELECT 1 FROM perfil WHERE perfil.id = auth.uid() AND perfil.condominio_id = condominio_contas_bancarias.condominio_id AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')));

CREATE POLICY "Admins can view chart of accounts" ON public.condominio_plano_contas FOR SELECT USING (EXISTS (SELECT 1 FROM perfil WHERE perfil.id = auth.uid() AND perfil.condominio_id = condominio_plano_contas.condominio_id AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')));
CREATE POLICY "Admins can modify chart of accounts" ON public.condominio_plano_contas FOR ALL USING (EXISTS (SELECT 1 FROM perfil WHERE perfil.id = auth.uid() AND perfil.condominio_id = condominio_plano_contas.condominio_id AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')));

CREATE POLICY "Admins can view transactions" ON public.condominio_lancamentos FOR SELECT USING (EXISTS (SELECT 1 FROM perfil WHERE perfil.id = auth.uid() AND perfil.condominio_id = condominio_lancamentos.condominio_id AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')));
CREATE POLICY "Admins can modify transactions" ON public.condominio_lancamentos FOR ALL USING (EXISTS (SELECT 1 FROM perfil WHERE perfil.id = auth.uid() AND perfil.condominio_id = condominio_lancamentos.condominio_id AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')));

CREATE POLICY "Admins can view budgets" ON public.condominio_orcamentos FOR SELECT USING (EXISTS (SELECT 1 FROM perfil WHERE perfil.id = auth.uid() AND perfil.condominio_id = condominio_orcamentos.condominio_id AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')));
CREATE POLICY "Admins can modify budgets" ON public.condominio_orcamentos FOR ALL USING (EXISTS (SELECT 1 FROM perfil WHERE perfil.id = auth.uid() AND perfil.condominio_id = condominio_orcamentos.condominio_id AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')));

CREATE POLICY "Admins can view all faturamentos" ON public.faturamentos FOR SELECT USING (EXISTS (SELECT 1 FROM perfil WHERE perfil.id = auth.uid() AND perfil.condominio_id = faturamentos.condominio_id AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')));
CREATE POLICY "Admins can modify faturamentos" ON public.faturamentos FOR ALL USING (EXISTS (SELECT 1 FROM perfil WHERE perfil.id = auth.uid() AND perfil.condominio_id = faturamentos.condominio_id AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')));

CREATE POLICY "Admins can view all faturamento_itens" ON public.faturamento_itens FOR SELECT USING (EXISTS (SELECT 1 FROM faturamentos f JOIN perfil p ON p.condominio_id = f.condominio_id WHERE f.id = faturamento_itens.faturamento_id AND p.id = auth.uid() AND (p.papel_sistema ILIKE '%sindico%' OR p.papel_sistema ILIKE '%síndico%' OR p.papel_sistema ILIKE '%admin%')));
CREATE POLICY "Admins can modify faturamento_itens" ON public.faturamento_itens FOR ALL USING (EXISTS (SELECT 1 FROM faturamentos f JOIN perfil p ON p.condominio_id = f.condominio_id WHERE f.id = faturamento_itens.faturamento_id AND p.id = auth.uid() AND (p.papel_sistema ILIKE '%sindico%' OR p.papel_sistema ILIKE '%síndico%' OR p.papel_sistema ILIKE '%admin%')));

-- Residents can view their own faturamentos
CREATE POLICY "Residents can view own faturamentos" ON public.faturamentos FOR SELECT USING (EXISTS (SELECT 1 FROM public.unidade_perfil up WHERE up.perfil_id = auth.uid() AND up.unidade_id = faturamentos.unidade_id));
CREATE POLICY "Residents can view own faturamento_itens" ON public.faturamento_itens FOR SELECT USING (EXISTS (SELECT 1 FROM faturamentos f JOIN public.unidade_perfil up ON up.unidade_id = f.unidade_id WHERE f.id = faturamento_itens.faturamento_id AND up.perfil_id = auth.uid()));

