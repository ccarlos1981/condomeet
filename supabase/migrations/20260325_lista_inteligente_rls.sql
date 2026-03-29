-- ═══════════════════════════════════════════════════════════
-- LISTA INTELIGENTE - RLS Policies
-- ═══════════════════════════════════════════════════════════

-- Produtos (leitura pública, escrita admin)
ALTER TABLE lista_products_base ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Produtos base: leitura pública" ON lista_products_base FOR SELECT USING (true);

ALTER TABLE lista_product_variants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Variantes: leitura pública" ON lista_product_variants FOR SELECT USING (true);

ALTER TABLE lista_products_sku ENABLE ROW LEVEL SECURITY;
CREATE POLICY "SKUs: leitura pública" ON lista_products_sku FOR SELECT USING (true);
CREATE POLICY "SKUs: insert autenticado" ON lista_products_sku FOR INSERT TO authenticated WITH CHECK (true);


ALTER TABLE lista_product_aliases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Aliases: leitura pública" ON lista_product_aliases FOR SELECT USING (true);

ALTER TABLE lista_brands ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Marcas: leitura pública" ON lista_brands FOR SELECT USING (true);

-- Supermercados (leitura pública)
ALTER TABLE lista_supermarkets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Supermercados: leitura pública" ON lista_supermarkets FOR SELECT USING (true);

-- Preços (leitura pública)
ALTER TABLE lista_prices_raw ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Preços raw: leitura autenticada" ON lista_prices_raw FOR SELECT TO authenticated USING (true);
CREATE POLICY "Preços raw: insert autenticado" ON lista_prices_raw FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reported_by);

ALTER TABLE lista_prices_current ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Preços current: leitura pública" ON lista_prices_current FOR SELECT USING (true);

ALTER TABLE lista_price_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Histórico: leitura autenticada" ON lista_price_history FOR SELECT TO authenticated USING (true);

ALTER TABLE lista_product_price_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Stats: leitura pública" ON lista_product_price_stats FOR SELECT USING (true);

-- Promoções (leitura pública)
ALTER TABLE lista_promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Promoções: leitura pública" ON lista_promotions FOR SELECT USING (true);

-- Listas (privadas por usuário)
ALTER TABLE lista_shopping_lists ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Listas: próprio usuário" ON lista_shopping_lists FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE lista_shopping_list_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Itens lista: próprio usuário" ON lista_shopping_list_items FOR ALL TO authenticated
  USING (list_id IN (SELECT id FROM lista_shopping_lists WHERE user_id = auth.uid()))
  WITH CHECK (list_id IN (SELECT id FROM lista_shopping_lists WHERE user_id = auth.uid()));

-- Crowdsourcing
ALTER TABLE lista_price_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Reports: leitura autenticada" ON lista_price_reports FOR SELECT TO authenticated USING (true);
CREATE POLICY "Reports: insert próprio" ON lista_price_reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

ALTER TABLE lista_price_votes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Votes: leitura autenticada" ON lista_price_votes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Votes: insert próprio" ON lista_price_votes FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Votes: update próprio" ON lista_price_votes FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- Gamificação (leitura pública, update próprio)
ALTER TABLE lista_user_points ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Pontos: leitura pública" ON lista_user_points FOR SELECT USING (true);
CREATE POLICY "Pontos: insert próprio" ON lista_user_points FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Pontos: update próprio" ON lista_user_points FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- Alertas (privados)
ALTER TABLE lista_price_alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Alertas: próprio usuário" ON lista_price_alerts FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Cache (leitura pública, gerenciado por functions)
ALTER TABLE lista_list_price_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Cache: leitura pública" ON lista_list_price_cache FOR SELECT USING (true);
