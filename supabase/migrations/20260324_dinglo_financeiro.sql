-- ============================================================
-- DINGLO FINANCIAL MODULE - Database Schema
-- Applied: 2026-03-24
-- ============================================================

-- 1. Contas bancárias
CREATE TABLE public.dinglo_contas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  banco TEXT NOT NULL,
  descricao TEXT,
  tipo TEXT DEFAULT 'corrente',
  saldo_inicial DECIMAL(12,2) DEFAULT 0,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Cartões de crédito
CREATE TABLE public.dinglo_cartoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  conta_id UUID REFERENCES public.dinglo_contas(id) ON DELETE SET NULL,
  bandeira TEXT NOT NULL,
  nome TEXT NOT NULL,
  limite DECIMAL(12,2) DEFAULT 0,
  dia_vencimento INT,
  dia_fechamento INT,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Categorias de gastos
CREATE TABLE public.dinglo_categorias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  icone TEXT,
  cor TEXT,
  tipo TEXT DEFAULT 'despesa',
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Lançamentos (transações)
CREATE TABLE public.dinglo_lancamentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  conta_id UUID REFERENCES public.dinglo_contas(id) ON DELETE SET NULL,
  cartao_id UUID REFERENCES public.dinglo_cartoes(id) ON DELETE SET NULL,
  categoria_id UUID REFERENCES public.dinglo_categorias(id) ON DELETE SET NULL,
  tipo TEXT NOT NULL,
  descricao TEXT NOT NULL,
  valor DECIMAL(12,2) NOT NULL,
  data_lancamento DATE NOT NULL,
  data_vencimento DATE,
  status TEXT DEFAULT 'pendente',
  parcela_atual INT,
  parcela_total INT,
  parcela_grupo_id UUID,
  comprovante_url TEXT,
  tags TEXT[],
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Despesas fixas
CREATE TABLE public.dinglo_despesas_fixas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  categoria_id UUID REFERENCES public.dinglo_categorias(id) ON DELETE SET NULL,
  descricao TEXT NOT NULL,
  valor DECIMAL(12,2) NOT NULL,
  dia_vencimento INT,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Metas
CREATE TABLE public.dinglo_metas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  valor_alvo DECIMAL(12,2) NOT NULL,
  valor_atual DECIMAL(12,2) DEFAULT 0,
  data_alvo DATE,
  status TEXT DEFAULT 'ativa',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. Plano do usuário
CREATE TABLE public.dinglo_plano_usuario (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  plano TEXT DEFAULT 'basico',
  ativo BOOLEAN DEFAULT true,
  data_inicio TIMESTAMPTZ DEFAULT now(),
  data_fim TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_dinglo_contas_user ON public.dinglo_contas(user_id);
CREATE INDEX idx_dinglo_cartoes_user ON public.dinglo_cartoes(user_id);
CREATE INDEX idx_dinglo_categorias_user ON public.dinglo_categorias(user_id);
CREATE INDEX idx_dinglo_lancamentos_user ON public.dinglo_lancamentos(user_id);
CREATE INDEX idx_dinglo_lancamentos_data ON public.dinglo_lancamentos(data_lancamento);
CREATE INDEX idx_dinglo_lancamentos_tipo ON public.dinglo_lancamentos(tipo);
CREATE INDEX idx_dinglo_despesas_fixas_user ON public.dinglo_despesas_fixas(user_id);
CREATE INDEX idx_dinglo_metas_user ON public.dinglo_metas(user_id);

-- RLS
ALTER TABLE public.dinglo_contas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dinglo_cartoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dinglo_categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dinglo_lancamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dinglo_despesas_fixas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dinglo_metas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dinglo_plano_usuario ENABLE ROW LEVEL SECURITY;

-- RLS Policies (all tables: user_id = auth.uid())
CREATE POLICY "Users can view own accounts" ON public.dinglo_contas FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own accounts" ON public.dinglo_contas FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own accounts" ON public.dinglo_contas FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own accounts" ON public.dinglo_contas FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own cards" ON public.dinglo_cartoes FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own cards" ON public.dinglo_cartoes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own cards" ON public.dinglo_cartoes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own cards" ON public.dinglo_cartoes FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own and default categories" ON public.dinglo_categorias FOR SELECT USING (auth.uid() = user_id OR is_default = true);
CREATE POLICY "Users can create own categories" ON public.dinglo_categorias FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own categories" ON public.dinglo_categorias FOR UPDATE USING (auth.uid() = user_id AND is_default = false);
CREATE POLICY "Users can delete own categories" ON public.dinglo_categorias FOR DELETE USING (auth.uid() = user_id AND is_default = false);

CREATE POLICY "Users can view own transactions" ON public.dinglo_lancamentos FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own transactions" ON public.dinglo_lancamentos FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own transactions" ON public.dinglo_lancamentos FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own transactions" ON public.dinglo_lancamentos FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own recurring" ON public.dinglo_despesas_fixas FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own recurring" ON public.dinglo_despesas_fixas FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own recurring" ON public.dinglo_despesas_fixas FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own recurring" ON public.dinglo_despesas_fixas FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own goals" ON public.dinglo_metas FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own goals" ON public.dinglo_metas FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own goals" ON public.dinglo_metas FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own goals" ON public.dinglo_metas FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own plan" ON public.dinglo_plano_usuario FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own plan" ON public.dinglo_plano_usuario FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own plan" ON public.dinglo_plano_usuario FOR UPDATE USING (auth.uid() = user_id);

-- Seed default categories
INSERT INTO public.dinglo_categorias (user_id, nome, icone, cor, tipo, is_default) VALUES
  (NULL, 'Alimentação', 'restaurant', '#FF6B6B', 'despesa', true),
  (NULL, 'Transporte', 'directions_car', '#4ECDC4', 'despesa', true),
  (NULL, 'Moradia', 'home', '#45B7D1', 'despesa', true),
  (NULL, 'Saúde', 'local_hospital', '#96CEB4', 'despesa', true),
  (NULL, 'Educação', 'school', '#FFEAA7', 'despesa', true),
  (NULL, 'Lazer', 'sports_esports', '#DDA0DD', 'despesa', true),
  (NULL, 'Vestuário', 'checkroom', '#F8B500', 'despesa', true),
  (NULL, 'Supermercado', 'shopping_cart', '#FF7F50', 'despesa', true),
  (NULL, 'Assinaturas', 'subscriptions', '#7B68EE', 'despesa', true),
  (NULL, 'Pets', 'pets', '#20B2AA', 'despesa', true),
  (NULL, 'Outros', 'more_horiz', '#A9A9A9', 'despesa', true),
  (NULL, 'Salário', 'payments', '#2ECC71', 'receita', true),
  (NULL, 'Freelance', 'work', '#3498DB', 'receita', true),
  (NULL, 'Investimentos', 'trending_up', '#F39C12', 'receita', true),
  (NULL, 'Outros', 'more_horiz', '#95A5A6', 'receita', true);
