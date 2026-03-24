-- ═══════════════════════════════════════════════════════════
-- LISTA INTELIGENTE - Seed: TOP 137 produtos + marcas
-- ═══════════════════════════════════════════════════════════

-- ══════════ MARCAS ══════════
INSERT INTO lista_brands (name, aliases, category) VALUES
('Camil', ARRAY['CAMIL','camil'], 'cereais'),
('Tio João', ARRAY['TIO JOAO','TIO JOÃO','tio joao'], 'cereais'),
('Prato Fino', ARRAY['PRATO FINO','prato fino'], 'cereais'),
('Kicaldo', ARRAY['KICALDO','kicaldo'], 'cereais'),
('Dona Benta', ARRAY['DONA BENTA','dona benta'], 'farinhas'),
('Yoki', ARRAY['YOKI','yoki'], 'farinhas'),
('Barilla', ARRAY['BARILLA','barilla'], 'massas'),
('Adria', ARRAY['ADRIA','adria'], 'massas'),
('Renata', ARRAY['RENATA','renata'], 'massas'),
('Nissin', ARRAY['NISSIN','nissin','MIOJO'], 'massas'),
('Pilão', ARRAY['PILAO','PILÃO','pilao'], 'café'),
('Melitta', ARRAY['MELITTA','melitta'], 'café'),
('3 Corações', ARRAY['3 CORACOES','TRES CORACOES','3 coracoes'], 'café'),
('Italac', ARRAY['ITALAC','italac'], 'laticínios'),
('Piracanjuba', ARRAY['PIRACANJUBA','piracanjuba'], 'laticínios'),
('Parmalat', ARRAY['PARMALAT','parmalat'], 'laticínios'),
('Nescau', ARRAY['NESCAU','nescau'], 'café_manhã'),
('Toddy', ARRAY['TODDY','toddy'], 'café_manhã'),
('União', ARRAY['UNIAO','UNIÃO','uniao'], 'açúcar'),
('Nestlé', ARRAY['NESTLE','NESTLÉ','nestle'], 'geral'),
('Liza', ARRAY['LIZA','liza'], 'óleos'),
('Soya', ARRAY['SOYA','soya'], 'óleos'),
('Gallo', ARRAY['GALLO','gallo'], 'óleos'),
('Knorr', ARRAY['KNORR','knorr'], 'temperos'),
('Hellmanns', ARRAY['HELLMANNS','HELLMANN''S','hellmanns'], 'temperos'),
('Heinz', ARRAY['HEINZ','heinz'], 'temperos'),
('Elefante', ARRAY['ELEFANTE','elefante'], 'temperos'),
('Seara', ARRAY['SEARA','seara'], 'carnes'),
('Sadia', ARRAY['SADIA','sadia'], 'carnes'),
('Perdigão', ARRAY['PERDIGAO','PERDIGÃO','perdigao'], 'carnes'),
('Friboi', ARRAY['FRIBOI','friboi'], 'carnes'),
('Qualy', ARRAY['QUALY','qualy'], 'laticínios'),
('Vigor', ARRAY['VIGOR','vigor'], 'laticínios'),
('Danone', ARRAY['DANONE','danone'], 'laticínios'),
('Ypê', ARRAY['YPE','YPÊ','ype'], 'limpeza'),
('Omo', ARRAY['OMO','omo'], 'limpeza'),
('Comfort', ARRAY['COMFORT','comfort'], 'limpeza'),
('Veja', ARRAY['VEJA','veja'], 'limpeza'),
('Neve', ARRAY['NEVE','neve'], 'higiene'),
('Colgate', ARRAY['COLGATE','colgate'], 'higiene'),
('Dove', ARRAY['DOVE','dove'], 'higiene'),
('Rexona', ARRAY['REXONA','rexona'], 'higiene'),
('Coca-Cola', ARRAY['COCA COLA','COCA-COLA','coca cola'], 'bebidas'),
('Guaraná Antarctica', ARRAY['GUARANA ANTARCTICA','guarana antarctica'], 'bebidas');

-- ══════════ PRODUTOS BASE + VARIANTES ══════════
-- Helper: usando DO block para inserir base → variantes de forma limpa

DO $$
DECLARE
  v_base_id UUID;
BEGIN
  -- === GRÃOS E BÁSICOS ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Arroz', 'cereais', '🍚', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Arroz Branco 1kg', 'kg', 1), (v_base_id, 'Arroz Branco 5kg', 'kg', 5),
    (v_base_id, 'Arroz Integral 1kg', 'kg', 1), (v_base_id, 'Arroz Parboilizado 5kg', 'kg', 5);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Feijão', 'cereais', '🫘', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Feijão Carioca 1kg', 'kg', 1), (v_base_id, 'Feijão Preto 1kg', 'kg', 1),
    (v_base_id, 'Feijão Fradinho 1kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Lentilha', 'cereais', '🫘', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Lentilha 500g', 'g', 500);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Grão de Bico', 'cereais', '🫘', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Grão de Bico 500g', 'g', 500);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Milho para Pipoca', 'cereais', '🍿', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Milho Pipoca 500g', 'g', 500);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Farinha de Trigo', 'farinhas', '🌾', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Farinha de Trigo 1kg', 'kg', 1), (v_base_id, 'Farinha de Trigo 5kg', 'kg', 5);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Farinha de Mandioca', 'farinhas', '🌾', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Farinha de Mandioca 500g', 'g', 500), (v_base_id, 'Farinha de Mandioca 1kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Fubá', 'farinhas', '🌽', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Fubá 500g', 'g', 500), (v_base_id, 'Fubá 1kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Aveia', 'cereais', '🥣', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Aveia Flocos 250g', 'g', 250), (v_base_id, 'Aveia Farinha 250g', 'g', 250);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Amido de Milho', 'farinhas', '🌽', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Amido de Milho 200g', 'g', 200);

  -- === MASSAS ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Macarrão Espaguete', 'massas', '🍝', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Espaguete 500g', 'g', 500);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Macarrão Parafuso', 'massas', '🍝', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Parafuso 500g', 'g', 500);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Macarrão Instantâneo', 'massas', '🍜', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Miojo 80g', 'g', 80);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Massa Lasanha', 'massas', '🍝', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Lasanha 500g', 'g', 500);

  -- === CAFÉ DA MANHÃ ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Café', 'café_manhã', '☕', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Café Moído 250g', 'g', 250), (v_base_id, 'Café Moído 500g', 'g', 500),
    (v_base_id, 'Café Solúvel 200g', 'g', 200);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Leite', 'laticínios', '🥛', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Leite Integral 1L', 'L', 1), (v_base_id, 'Leite Desnatado 1L', 'L', 1),
    (v_base_id, 'Leite Sem Lactose 1L', 'L', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Leite em Pó', 'laticínios', '🥛', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Leite em Pó 400g', 'g', 400), (v_base_id, 'Leite em Pó 800g', 'g', 800);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Achocolatado', 'café_manhã', '🍫', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Achocolatado 400g', 'g', 400), (v_base_id, 'Achocolatado 800g', 'g', 800);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Pão de Forma', 'café_manhã', '🍞', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Pão Integral', 'un', 1), (v_base_id, 'Pão Tradicional', 'un', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Biscoito', 'café_manhã', '🍪', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Cream Cracker 400g', 'g', 400), (v_base_id, 'Maisena 400g', 'g', 400),
    (v_base_id, 'Recheado 130g', 'g', 130);

  -- === AÇÚCAR E DOCES ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Açúcar', 'açúcar_doces', '🧂', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Açúcar Refinado 1kg', 'kg', 1), (v_base_id, 'Açúcar Cristal 5kg', 'kg', 5),
    (v_base_id, 'Açúcar Demerara 1kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Leite Condensado', 'açúcar_doces', '🥫', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Leite Condensado 395g', 'g', 395);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Creme de Leite', 'açúcar_doces', '🥫', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Creme de Leite 200g', 'g', 200);

  -- === ÓLEOS E TEMPEROS ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Óleo de Soja', 'óleos_temperos', '🫗', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Óleo de Soja 900ml', 'ml', 900);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Azeite', 'óleos_temperos', '🫒', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Azeite Extra Virgem 500ml', 'ml', 500), (v_base_id, 'Azeite Extra Virgem 250ml', 'ml', 250);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Sal', 'óleos_temperos', '🧂', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Sal Refinado 1kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Maionese', 'óleos_temperos', '🥫', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Maionese 500g', 'g', 500);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Molho de Tomate', 'óleos_temperos', '🍅', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Molho de Tomate 340g', 'g', 340);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Extrato de Tomate', 'óleos_temperos', '🍅', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Extrato de Tomate 340g', 'g', 340);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Ketchup', 'óleos_temperos', '🥫', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Ketchup 400g', 'g', 400);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Vinagre', 'óleos_temperos', '🫗', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Vinagre 750ml', 'ml', 750);

  -- === CARNES ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Carne Moída', 'carnes', '🥩', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Carne Moída Patinho kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Alcatra', 'carnes', '🥩', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Alcatra kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Picanha', 'carnes', '🥩', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Picanha kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Frango Inteiro', 'carnes', '🍗', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Frango Inteiro kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Peito de Frango', 'carnes', '🍗', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Peito de Frango kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Linguiça', 'carnes', '🌭', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Linguiça Toscana kg', 'kg', 1), (v_base_id, 'Linguiça Calabresa kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Salsicha', 'carnes', '🌭', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Salsicha 500g', 'g', 500);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Ovo', 'carnes', '🥚', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Ovo Dúzia', 'un', 12), (v_base_id, 'Ovo 30 unidades', 'un', 30);

  -- === LATICÍNIOS ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Manteiga', 'laticínios', '🧈', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Manteiga 200g', 'g', 200);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Margarina', 'laticínios', '🧈', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Margarina 500g', 'g', 500), (v_base_id, 'Margarina 250g', 'g', 250);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Queijo Mussarela', 'laticínios', '🧀', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Mussarela Fatiada kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Requeijão', 'laticínios', '🧀', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Requeijão 200g', 'g', 200);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Iogurte', 'laticínios', '🥛', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Iogurte Natural 170g', 'g', 170), (v_base_id, 'Iogurte Bandeja 540g', 'g', 540);

  -- === HORTIFRUTI ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Banana', 'hortifruti', '🍌', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Banana Prata kg', 'kg', 1), (v_base_id, 'Banana Nanica kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Maçã', 'hortifruti', '🍎', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Maçã Fuji kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Laranja', 'hortifruti', '🍊', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Laranja Pera kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Tomate', 'hortifruti', '🍅', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Tomate kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Cebola', 'hortifruti', '🧅', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Cebola kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Batata', 'hortifruti', '🥔', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Batata Inglesa kg', 'kg', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Alho', 'hortifruti', '🧄', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Alho kg', 'kg', 1);

  -- === BEBIDAS ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Água Mineral', 'bebidas', '💧', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Água 500ml', 'ml', 500), (v_base_id, 'Água 1.5L', 'L', 1.5), (v_base_id, 'Água 5L', 'L', 5);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Refrigerante', 'bebidas', '🥤', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Refrigerante Cola 2L', 'L', 2), (v_base_id, 'Refrigerante Guaraná 2L', 'L', 2);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Suco', 'bebidas', '🧃', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Suco de Laranja 1L', 'L', 1), (v_base_id, 'Suco de Uva 1L', 'L', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Cerveja', 'bebidas', '🍺', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Cerveja Lata 350ml', 'ml', 350);

  -- === HIGIENE ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Papel Higiênico', 'higiene', '🧻', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Papel Higiênico 4 rolos', 'un', 4), (v_base_id, 'Papel Higiênico 12 rolos', 'un', 12);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Creme Dental', 'higiene', '🪥', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Creme Dental 90g', 'g', 90);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Sabonete', 'higiene', '🧼', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Sabonete 90g', 'g', 90);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Shampoo', 'higiene', '🧴', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Shampoo 350ml', 'ml', 350);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Desodorante', 'higiene', '🧴', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Desodorante Aerosol 150ml', 'ml', 150), (v_base_id, 'Desodorante Roll-on 50ml', 'ml', 50);

  -- === LIMPEZA ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Detergente', 'limpeza', '🧹', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Detergente 500ml', 'ml', 500);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Sabão em Pó', 'limpeza', '🧹', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Sabão em Pó 1kg', 'kg', 1), (v_base_id, 'Sabão em Pó 2kg', 'kg', 2);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Amaciante', 'limpeza', '🧹', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Amaciante 2L', 'L', 2);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Água Sanitária', 'limpeza', '🧹', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Água Sanitária 1L', 'L', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Desinfetante', 'limpeza', '🧹', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Desinfetante 500ml', 'ml', 500);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Esponja', 'limpeza', '🧽', true) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Esponja 3un', 'un', 3);

  -- === CONGELADOS ===
  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Pizza Congelada', 'congelados', '🍕', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES
    (v_base_id, 'Pizza Mussarela', 'un', 1), (v_base_id, 'Pizza Calabresa', 'un', 1);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Hambúrguer', 'congelados', '🍔', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Hambúrguer 672g', 'g', 672);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Nuggets', 'congelados', '🍗', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Nuggets 300g', 'g', 300);

  INSERT INTO lista_products_base (name, category, icon_emoji, is_priority) VALUES ('Sorvete', 'congelados', '🍦', false) RETURNING id INTO v_base_id;
  INSERT INTO lista_product_variants (base_id, variant_name, unit, default_weight) VALUES (v_base_id, 'Sorvete 2L', 'L', 2);

END $$;

-- ══════════ SUPERMERCADOS (grandes redes do Brasil) ══════════
INSERT INTO lista_supermarkets (name, is_chain) VALUES
('Carrefour', true),
('Pão de Açúcar', true),
('Extra', true),
('Assaí Atacadista', true),
('Atacadão', true),
('Sam''s Club', true),
('Big Bompreço', true),
('Guanabara', true),
('Bretas', true),
('Mateus Supermercados', true);
