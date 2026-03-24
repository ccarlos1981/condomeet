-- ═══════════════════════════════════════════════════════════
-- LISTA INTELIGENTE DE SUPERMERCADO - Schema
-- ═══════════════════════════════════════════════════════════

-- Extensions para geolocalização
CREATE EXTENSION IF NOT EXISTS cube SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS earthdistance SCHEMA extensions;

-- ═══════════════════════════════════════════
-- NÍVEL 1: Produto genérico (Arroz, Leite)
-- ═══════════════════════════════════════════
CREATE TABLE lista_products_base (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  icon_emoji TEXT DEFAULT '🛒',
  search_tokens TSVECTOR,
  is_priority BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- NÍVEL 2: Variação (Arroz Branco 5kg)
-- ═══════════════════════════════════════════
CREATE TABLE lista_product_variants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  base_id UUID REFERENCES lista_products_base(id) ON DELETE CASCADE,
  variant_name TEXT NOT NULL,
  unit TEXT DEFAULT 'kg',
  default_weight NUMERIC,
  popularity_score INT DEFAULT 0,
  search_count INT DEFAULT 0,
  add_to_list_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- NÍVEL 3: SKU real (Arroz Tio João 5kg)
-- ═══════════════════════════════════════════
CREATE TABLE lista_products_sku (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  variant_id UUID REFERENCES lista_product_variants(id) ON DELETE CASCADE,
  brand TEXT,
  weight_label TEXT,
  barcode TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- ALIASES: Normalização de nomes
-- ═══════════════════════════════════════════
CREATE TABLE lista_product_aliases (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sku_id UUID REFERENCES lista_products_sku(id) ON DELETE CASCADE,
  detected_name TEXT NOT NULL,
  source TEXT DEFAULT 'ocr'
);

-- ═══════════════════════════════════════════
-- MARCAS (dicionário p/ normalização)
-- ═══════════════════════════════════════════
CREATE TABLE lista_brands (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  aliases TEXT[],
  category TEXT
);

-- ═══════════════════════════════════════════
-- SUPERMERCADOS
-- ═══════════════════════════════════════════
CREATE TABLE lista_supermarkets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  city TEXT,
  state TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  phone TEXT,
  logo_url TEXT,
  is_chain BOOLEAN DEFAULT false,
  is_sponsored BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- PREÇOS BRUTOS (todas as coletas)
-- ═══════════════════════════════════════════
CREATE TABLE lista_prices_raw (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sku_id UUID REFERENCES lista_products_sku(id) ON DELETE CASCADE,
  supermarket_id UUID REFERENCES lista_supermarkets(id) ON DELETE CASCADE,
  price NUMERIC(10,2) NOT NULL,
  source TEXT NOT NULL CHECK (source IN ('nota_fiscal','crowd','scraping')),
  price_type TEXT DEFAULT 'regular' CHECK (price_type IN ('regular','promo','club')),
  confidence_score NUMERIC(3,2) DEFAULT 0.5,
  reported_by UUID REFERENCES auth.users(id),
  confirmations INT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- PREÇOS CONSOLIDADOS (1 por produto×mercado)
-- ═══════════════════════════════════════════
CREATE TABLE lista_prices_current (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sku_id UUID REFERENCES lista_products_sku(id) ON DELETE CASCADE,
  supermarket_id UUID REFERENCES lista_supermarkets(id) ON DELETE CASCADE,
  price NUMERIC(10,2) NOT NULL,
  price_type TEXT DEFAULT 'regular',
  confidence_score NUMERIC(3,2) DEFAULT 0.5,
  is_stale BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(sku_id, supermarket_id)
);

-- ═══════════════════════════════════════════
-- HISTÓRICO DE PREÇOS (tendências)
-- ═══════════════════════════════════════════
CREATE TABLE lista_price_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sku_id UUID REFERENCES lista_products_sku(id) ON DELETE CASCADE,
  supermarket_id UUID REFERENCES lista_supermarkets(id) ON DELETE CASCADE,
  price NUMERIC(10,2) NOT NULL,
  recorded_date DATE DEFAULT CURRENT_DATE,
  source TEXT,
  UNIQUE(sku_id, supermarket_id, recorded_date)
);

-- ═══════════════════════════════════════════
-- ESTATÍSTICAS REGIONAIS
-- ═══════════════════════════════════════════
CREATE TABLE lista_product_price_stats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sku_id UUID REFERENCES lista_products_sku(id) ON DELETE CASCADE,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  avg_price NUMERIC(10,2),
  min_price NUMERIC(10,2),
  max_price NUMERIC(10,2),
  sample_count INT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(sku_id, city, state)
);

-- ═══════════════════════════════════════════
-- PROMOÇÕES DETECTADAS
-- ═══════════════════════════════════════════
CREATE TABLE lista_promotions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  supermarket_id UUID REFERENCES lista_supermarkets(id) ON DELETE CASCADE,
  sku_id UUID REFERENCES lista_products_sku(id),
  original_price NUMERIC(10,2),
  promo_price NUMERIC(10,2) NOT NULL,
  discount_percent INT,
  starts_at TIMESTAMPTZ DEFAULT now(),
  ends_at TIMESTAMPTZ,
  is_sponsored BOOLEAN DEFAULT false,
  detected_auto BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- LISTAS DE COMPRAS
-- ═══════════════════════════════════════════
CREATE TABLE lista_shopping_lists (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT DEFAULT 'Minha Lista',
  list_type TEXT DEFAULT 'quick' CHECK (list_type IN ('quick','monthly','wholesale')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE lista_shopping_list_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  list_id UUID REFERENCES lista_shopping_lists(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES lista_product_variants(id),
  quantity INT DEFAULT 1,
  is_checked BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- CROWDSOURCING
-- ═══════════════════════════════════════════
CREATE TABLE lista_price_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  sku_id UUID REFERENCES lista_products_sku(id),
  supermarket_id UUID REFERENCES lista_supermarkets(id),
  price NUMERIC(10,2) NOT NULL,
  receipt_photo_url TEXT,
  is_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE lista_price_votes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  price_raw_id UUID REFERENCES lista_prices_raw(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  vote TEXT CHECK (vote IN ('confirm','incorrect')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(price_raw_id, user_id)
);

-- ═══════════════════════════════════════════
-- GAMIFICAÇÃO
-- ═══════════════════════════════════════════
CREATE TABLE lista_user_points (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  total_points INT DEFAULT 0,
  weekly_points INT DEFAULT 0,
  reports_count INT DEFAULT 0,
  rank_title TEXT DEFAULT 'Iniciante',
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- ALERTAS DE PREÇO
-- ═══════════════════════════════════════════
CREATE TABLE lista_price_alerts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES lista_product_variants(id),
  target_price NUMERIC(10,2),
  is_active BOOLEAN DEFAULT true,
  last_notified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- CACHE DE LISTAS (performance)
-- ═══════════════════════════════════════════
CREATE TABLE lista_list_price_cache (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  list_hash TEXT NOT NULL,
  city TEXT NOT NULL,
  result_json JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(list_hash, city)
);

-- ═══════════════════════════════════════════
-- ÍNDICES
-- ═══════════════════════════════════════════
CREATE INDEX idx_prices_current_sku ON lista_prices_current(sku_id);
CREATE INDEX idx_prices_current_market ON lista_prices_current(supermarket_id);
CREATE INDEX idx_prices_raw_created ON lista_prices_raw(created_at DESC);
CREATE INDEX idx_price_history_sku_date ON lista_price_history(sku_id, recorded_date DESC);
CREATE INDEX idx_products_base_search ON lista_products_base USING gin(search_tokens);
CREATE INDEX idx_product_aliases_name ON lista_product_aliases(detected_name);
CREATE INDEX idx_promotions_ends ON lista_promotions(ends_at);
CREATE INDEX idx_price_alerts_active ON lista_price_alerts(variant_id) WHERE is_active = true;
CREATE INDEX idx_cache_hash ON lista_list_price_cache(list_hash, city);
CREATE INDEX idx_shopping_lists_user ON lista_shopping_lists(user_id);
CREATE INDEX idx_variants_base ON lista_product_variants(base_id);
CREATE INDEX idx_sku_variant ON lista_products_sku(variant_id);

-- Trigger para auto-gerar search_tokens
CREATE OR REPLACE FUNCTION lista_update_search_tokens()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_tokens := to_tsvector('portuguese', unaccent(NEW.name));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE TRIGGER trg_products_base_search
  BEFORE INSERT OR UPDATE OF name ON lista_products_base
  FOR EACH ROW EXECUTE FUNCTION lista_update_search_tokens();

-- Trigger para marcar preços como stale (>48h)
CREATE OR REPLACE FUNCTION lista_mark_stale_prices()
RETURNS void AS $$
BEGIN
  UPDATE lista_prices_current
  SET is_stale = true
  WHERE updated_at < now() - interval '48 hours'
    AND is_stale = false;
END;
$$ LANGUAGE plpgsql;

-- Cron job para marcar stale a cada hora
SELECT cron.schedule('mark-stale-prices', '0 * * * *',
  $$SELECT lista_mark_stale_prices()$$
);
