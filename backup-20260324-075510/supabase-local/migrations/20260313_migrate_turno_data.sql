-- ══════════════════════════════════════════════════════════════
-- MIGRAÇÃO AUTOMÁTICA: Dados Bubble → Novo schema
-- Gerado automaticamente a partir dos CSVs exportados
-- Banco: condomeet_Antigravity (novo)
-- ══════════════════════════════════════════════════════════════

-- Desabilitar FK temporariamente para porteiro_id
ALTER TABLE turno_registros DROP CONSTRAINT IF EXISTS turno_registros_porteiro_id_fkey;

-- Pegar o condominio_id do registro que já existe
DO $$ DECLARE v_condo_id UUID; BEGIN
  SELECT condominio_id INTO v_condo_id FROM turno_registros LIMIT 1;
  IF v_condo_id IS NULL THEN RAISE EXCEPTION 'Nenhum registro de turno encontrado para obter condominio_id!'; END IF;

  -- ── 1. ASSUNTOS ──────────────────────────────────────────────
  INSERT INTO turno_assuntos (id, condominio_id, titulo, observacao, created_at)
  VALUES ('85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, v_condo_id, 'Registo de saída', 'Aqui você escreverá como foi seu dia no seu turno.', '2026-02-22 15:11:16.961628-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;

  -- ── 2. INVENTÁRIO ────────────────────────────────────────────
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('2b44e12f-c207-4131-ac27-3a5eeece16b4'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Mouse', 1, 'Unidade', '2026-02-22 15:31:36.121466-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('b7530829-d56e-48e6-9cc7-e207577b68fd'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'WebCam', 1, 'Unidade', '2026-02-22 15:31:27.437603-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('bcab7e63-af46-4e3b-babb-c6db059d09d1'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Teclado', 1, 'Unidade', '2026-02-22 15:31:15.638958-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('a9abda91-d842-4441-acf4-ffb502391838'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Controle da TV', 2, 'Unidade', '2026-02-22 15:29:03.117859-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('85b45c98-da59-4bff-8b37-7bc83b934958'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Ar condicionado', 1, 'Unidade', '2026-02-22 15:28:42.423666-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('25dfa039-5b1f-47e2-a856-8a7d7aafc504'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'ventilador', 1, 'Unidade', '2026-02-22 15:28:35.973182-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('e5c52798-0b86-402b-a9d6-6781368de35a'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Chaves aleatórias', 4, 'Unidade', '2026-02-22 15:28:07.469036-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('b074c032-76c3-4bd9-ad6f-f71070bca54d'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Chaves no Quadro', 35, 'Unidade', '2026-02-22 15:26:23.623218-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('9cc54ea7-86fb-49cb-a77d-4363ab284c42'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Computador', 1, 'Unidade', '2026-02-22 15:25:23.924726-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('a1ee898b-ccb8-4da0-90e2-e1a14859c188'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Nobreak', 1, 'Unidade', '2026-02-22 15:25:14.102308-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('aba08067-90b9-4597-8281-0e345f38d6db'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Monitores', 3, 'Unidade', '2026-02-22 15:25:04.984817-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('d8f5055c-6f9e-4aae-b4a7-9af21fb2e955'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Filtro de água', 1, 'Unidade', '2026-02-22 15:24:51.26888-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('29da119e-9de6-4208-a384-a2ca4f2486a9'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Telefone sem fio', 1, 'Unidade', '2026-02-22 15:24:38.025825-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('dfddf3bf-d580-42dc-8db2-bc8a0bbcc202'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Interfone', 1, 'Unidade', '2026-02-22 15:24:25.076534-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('83a51d91-988b-4844-a16f-f44633e9eacb'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Rádio comunicador', 2, 'Unidade', '2026-02-22 15:15:21.248365-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('6dd2af52-087c-4a85-8567-e75a8bf7e49c'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Lápis', 1, 'Unidade', '2026-02-22 15:14:56.934718-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('4b5a217c-c843-4599-9718-81e0a3377b61'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Canetas', 7, 'Unidade', '2026-02-22 15:14:42.516223-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('6f46c3f8-27a3-4ce0-9661-0e3af320a088'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Tesoura', 1, 'Unidade', '2026-02-22 15:14:27.534473-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('13798a92-326d-41c9-bfa5-5ff2b162c6eb'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Porta Durex', 1, 'Unidade', '2026-02-22 15:14:11.518708-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('38107e5d-d807-4b1c-84ec-d2c1b17627f7'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Grampeador', 1, 'Unidade', '2026-02-22 15:13:39.274004-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('5f25cb78-baba-460f-9bac-2370b9668a86'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Controle alarme central', 1, 'Unidade', '2026-02-22 15:13:12.57748-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('a16afecc-1c84-48e4-b728-76d944e5420e'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Controle ar condicionado', 1, 'Unidade', '2026-02-22 15:12:43.055782-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_inventario (id, condominio_id, assunto_id, nome, quantidade, unidade, created_at)
  VALUES ('115829ca-b1a0-426b-84e6-c055774b11a7'::uuid, v_condo_id, '85021a4a-dcae-4db4-b28e-62e99f0c1a08'::uuid, 'Controles dos portões', 2, 'Unidade', '2026-02-22 15:12:12.713901-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;

  -- ── 3. REGISTROS DE TURNO ────────────────────────────────────
  -- (porteiro_id usa placeholder — FK desabilitada temporariamente)
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('80381098-46b9-40c2-9a76-8124ab4ce682'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Adriano Nascimento', 'Fica no posto chave do 905-b.', '2026-03-13 06:35:58.860963-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('ed309d0d-a919-45e0-9bad-88cb5b573f18'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Lucas Santos', 'observações;', '2026-03-12 18:33:11.907971-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('1fce210c-650f-4243-bca5-c84c0db3de79'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Wanderlei souza', 'Obs gerais:', '2026-03-12 06:50:25.116513-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('fdd467e7-7204-4fd3-8787-7119b552342a'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Carlos Alberto', 'Fica 01 pct para diana 503 a. Fica 01 encomenda para agp lucas. Fica 01 encomenda para patricia miranda campos sem apt e sem bloco. Fica 01 sacola para polyanna 1003 b. Fica 01 xicara grande achada. Guarda chuva carimbo. Fica 02 envelopes grandes para a dracma da adm. Fica 01 pct para zete 301 b deixou. Fica 01 encomenda para muriel na quarta gaveta. Obs: ta faltando a chave 15 da piscina. Fica 01 pacotinho para rodrigo da tec seguranca. Fica chaveiro do zete e chave 106 b. Ficam as encomendas 705 a, 506 a, 506 b, 606 b, 1002 b. Passo o plantao sem alteracao.', '2026-03-11 18:29:54.596898-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('0ae814ef-f42c-412a-9842-2a4746b03b00'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Adriano Nascimento', 'Fica no posto doc dracma.', '2026-03-11 06:50:52.262133-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('4b21cbc3-1e04-4676-9ca8-4f496b9718d3'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Lucas Santos', 'Passo o posto sem alterações para o agp Adriano.', '2026-03-10 18:47:50.486136-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('eb53dead-4daf-408b-a31a-184e1ddb75dd'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Wanderlei souza', 'Observações gerais:', '2026-03-10 06:55:03.342872-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('fb857669-91ee-43e6-8dc8-2ddc318a25da'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Carlos Alberto', 'Chaves de fenda. Pct 503 a. Cx para silvana. Pct para agp lucas. Carimbo. 01 pct 402 b deixou para milleni. Guarda chuva. 01 encomenda para marcelo pedra. 01 camisa azul achada. Passo o plantao sem alteracao.', '2026-03-09 18:38:13.448859-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('54b7362b-934c-4993-ae48-57b8619c774b'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Adriano Nascimento', 'Fica no posto blusa encontrada no parquinho.', '2026-03-09 06:43:57.652102-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('5042d21e-de69-4624-94cd-b4f287b131a2'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Lucas Santos', 'Passo o posto sem alterações para o agp Adriano.', '2026-03-08 18:55:07.84368-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('2545d285-f263-4e5e-8d65-365ff61af85a'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Wanderlei souza', 'Observações gerais:', '2026-03-08 06:52:19.061035-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('e67c13f0-4fe5-4bc1-bcfd-82e809823409'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Carlos Alberto', 'Fica 01 cx para silvana da mary kay perfumes. 01 carimbo. 01 galao de agua 406 a. 01 encomenda para agp lucas. 01 pct para diana 503 a. Chaves de fendas. Saquinho para caes. Fica 01 pct para malena 604 a. Fica 01 encomenda para 406 b nedja. Chave do salao bloco a ta com 306 a.', '2026-03-07 17:49:42.005147-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('2cb5581d-78ae-4faa-9a6f-c19919fc3772'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Adriano Nascimento', 'Passo o posto para agp carlos sem alteracao.', '2026-03-07 06:59:14.223554-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('7405015d-1498-46aa-ba6a-1f4eed757de7'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Lucas Santos', 'Observações.', '2026-03-06 18:18:11.66996-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('44f03338-8372-4ce3-bf04-91eeb27e8109'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Wanderlei souza', 'Obs gerais.', '2026-03-06 07:02:19.097372-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('7dac1c27-1f9b-44c3-926d-fd08d525ccf4'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Carlos Alberto', 'Fica 01 carimbo. 01 sacola 1001 a silvana. 01 pct 503 a diana. 01 encomenda para agp lucas. Chaves 106 b, 605 a, 905 b, 706 b, 501 b. De carro. Chaves de fendas.', '2026-03-05 18:47:44.833587-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('dad3a1b0-592a-416b-a311-983d1990ba56'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Adriano Nascimento', 'Passo o posto para agp carlos sem alteracao.', '2026-03-05 07:39:10.489721-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('75a85629-cf8a-418a-9116-bea5ceec2b15'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Lucas Santos', 'Passo o posto sem alterações para o agp Adriano.', '2026-03-04 18:43:44.747664-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('9a9bdedd-f66c-45fe-a042-bbeb51e89e2b'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Wanderlei souza', 'Obs.', '2026-03-04 06:53:49.429883-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('90f8f9ab-f368-425a-97c6-efc6dc1143d0'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Carlos Alberto', 'Fica chaves 206 a, chave 102 b, chave 1003 a. Chaves de fendas. Saquinho para cachorro. Carimbo. Fica 01 pct para diana 503 a. Fica 01 sacola 1003 a. Sacola farmacia 1004 a. Fica 01 pct proteina. 01 carrinho 104 b de crianca. Fica encomendas 702 a, 905 a, 201 b, 806 b, 905 b, 305 b. Passo o plantao sem alteracao.', '2026-03-03 18:27:05.778997-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('f1ffa082-76bc-45f8-9404-dc89a4b40f0e'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Adriano Nascimento', 'Passo o posto para o agp carlos sem alteração!', '2026-03-03 06:40:23.202708-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('37998d2a-9c16-45be-b39a-3b0d69d0338f'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Lucas Santos', 'Observações.', '2026-03-02 18:51:28.10519-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('78a3fb53-67c1-4d77-89fe-5abd7d70ccc6'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Wanderlei souza', 'Obs gerais.', '2026-03-02 06:56:11.903376-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('c088addf-416d-4c22-ba88-bd592aa65c2d'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Carlos Alberto', 'Fica 01 carimbo. 01 sacola para silvana. Fica 01 encomenda pet para diana 503 a. Fica 02 batom simone 403 b deixou para o sobrinho do romulo pegar. Fica 01 pct da farmacia 1002 a. Fica 01 revista 806 a. Encomendas 701 a, fica 02 804 a 402 b, fica 5 301 b, 201 b iptu, 202 b 404 b. Sem alteracao.', '2026-03-01 18:41:19.471559-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('e35144a3-05cf-4a53-8740-6b9bbf71c08b'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Adriano Nascimento', 'Passo o posto para o agp carlos sem alteração!', '2026-03-01 07:21:45.788662-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('125d6292-93ea-4a1f-b308-a52840c652b0'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Lucas Santos', 'Passo o posto sem alterações para o agp Adriano.', '2026-02-28 18:26:50.784198-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('aa67b3fd-1eb6-4ada-bf45-851d1c2bb651'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Wanderlei souza', 'Obs gerais.', '2026-02-28 07:13:24.73912-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('131e4b9c-22f5-4387-bc3d-d5b83e0f105c'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Carlos Alberto', 'Fica 01 carimbo. 01 sacola para silvana 1001 a. Fica 02 saquinhos 604 a. Fica 01 sacola marrom leandro 104 b deixou para jonatha pegar. Fica 01 encomenda para marcelo pedra. Guarda chuva. Fica 01 chave 106 b. Chaves de fenda. Observacao: esta faltando a chave 26. Passo o plantao sem alteracao.', '2026-02-27 18:44:32.025016-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('5befece1-971d-4c2b-8659-3c3cea4f7504'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Adriano Nascimento', 'Passo o posto para o agp carlos sem alteração!', '2026-02-27 06:37:31.441101-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('9bc7371d-fd67-4143-8353-a4ba342922bc'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Lucas Santos', 'Passo o posto sem alterações para o agp Adriano.', '2026-02-26 18:26:59.142585-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('70520b53-7f80-41f9-9ef2-1ffbd806015e'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Wanderlei souza', 'Obs.', '2026-02-26 06:49:30.273589-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('bbf8d90c-49cd-41f3-9b32-c5ad1d11ad3a'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Carlos Alberto', 'Fica 01 carimbo. Guarda chuva. 01 sacola para silvana 1001 a. 01 sacola para poliana pegar deixado por 303 a. 01 pct para michelline. Fica uma tag para carro 801 a valmares tag numero e2caf7. 01 encomenda para marcelo pedra.', '2026-02-25 18:28:11.731417-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('b36cdffb-5882-45f5-833c-6c07a001f5af'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Adriano Nascimento', 'Passo o posto para o agp carlos sem alteração!', '2026-02-25 06:41:01.981116-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('1ea1803a-af33-4eec-87bb-febc43c06c17'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Lucas Santos', 'Passo o posto sem alterações para o agp Adriano.', '2026-02-24 18:23:35.536147-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('0c184741-fd91-4220-bbe1-e8149d86b743'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Wanderlei souza', 'Enc. rec.', '2026-02-24 06:49:16.743462-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('7b94234b-ed89-4ed2-8caa-e0bde52c9edd'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Carlos Alberto', 'Passo ponto sem alteração.', '2026-02-23 18:59:49.760271-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('fcd8752a-0b33-4408-bc89-4caf0c21cf54'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Carlos Alberto', 'Fica 1 Sacola para Silvana. 1 Sacola 303a deixou para Poliana. 2 Malas escolar para 905B. 1 Lata de tinta 206B. 1 sacola para Luciana 501B. 1 Carimbo. Chaves 1003A 106B.', '2026-02-23 18:32:22.443491-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('2be531a2-c4f0-48bd-9d20-cac8accd750f'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Adriano Nascimento', 'Passo o posto para o AGP Carlos sem alteração!', '2026-02-23 06:43:32.296388-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registros (id, condominio_id, porteiro_id, porteiro_nome, observacao, created_at)
  VALUES ('4cc3bfd6-a35a-4067-a812-c561fd54364f'::uuid, v_condo_id, '00000000-0000-0000-0000-000000000000'::uuid, 'Lucas Santos', 'Passo o posto sem alterações para o AGP Adriano.', '2026-02-22 18:23:24.441791-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;

  -- ── 4. ITENS CONFERIDOS ──────────────────────────────────────
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('e3aaccb6-3010-4df4-89fa-6aec0acc41eb'::uuid, '1fce210c-650f-4243-bca5-c84c0db3de79'::uuid, 'e5c52798-0b86-402b-a9d6-6781368de35a'::uuid, false, 6, 'ZETE E 102B', '2026-03-12 06:50:25.246791-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('3f941e5a-3a7e-4792-92a6-f1ede325bded'::uuid, '1fce210c-650f-4243-bca5-c84c0db3de79'::uuid, 'b074c032-76c3-4bd9-ad6f-f71070bca54d'::uuid, false, 34, 'FALTANDO A 15', '2026-03-12 06:50:25.246791-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('5c7eae05-3b74-4973-a36a-85f88a3197e4'::uuid, 'eb53dead-4daf-408b-a31a-184e1ddb75dd'::uuid, 'e5c52798-0b86-402b-a9d6-6781368de35a'::uuid, false, 6, 'mais 1003a, 103b.', '2026-03-10 06:55:03.476002-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('0fbc45d7-6127-47f6-8530-bec69e1eddd9'::uuid, '2545d285-f263-4e5e-8d65-365ff61af85a'::uuid, 'e5c52798-0b86-402b-a9d6-6781368de35a'::uuid, false, 6, 'MAIS 1003A, 102B.', '2026-03-08 06:52:19.181098-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('b8f452a4-73af-47b5-9161-c8dc8910f2f5'::uuid, '44f03338-8372-4ce3-bf04-91eeb27e8109'::uuid, 'e5c52798-0b86-402b-a9d6-6781368de35a'::uuid, false, 6, 'mais 102b, 1003a', '2026-03-06 07:02:19.22493-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('50856f7a-996a-4b39-9fc4-28bc0b66b936'::uuid, '9a9bdedd-f66c-45fe-a042-bbeb51e89e2b'::uuid, 'e5c52798-0b86-402b-a9d6-6781368de35a'::uuid, false, 6, 'MAIS 1003A, 102B', '2026-03-04 06:53:49.557643-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('4b6898f5-b962-4e07-8a02-8e291de30853'::uuid, '78a3fb53-67c1-4d77-89fe-5abd7d70ccc6'::uuid, 'e5c52798-0b86-402b-a9d6-6781368de35a'::uuid, false, 7, '102B, 1003A, ZETE', '2026-03-02 06:56:12.026487-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('53cc4091-b70c-481a-9f2e-f5ef280d273b'::uuid, 'aa67b3fd-1eb6-4ada-bf45-851d1c2bb651'::uuid, 'e5c52798-0b86-402b-a9d6-6781368de35a'::uuid, false, 7, 'mais 102b, zete, 1003a', '2026-02-28 07:13:24.874265-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('35d31e1d-4fd4-464c-a986-e1a761901d79'::uuid, '70520b53-7f80-41f9-9ef2-1ffbd806015e'::uuid, 'e5c52798-0b86-402b-a9d6-6781368de35a'::uuid, false, 1, '+102B', '2026-02-26 06:49:30.389727-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('eaee6896-892a-4d48-9842-707bde092718'::uuid, '0c184741-fd91-4220-bbe1-e8149d86b743'::uuid, 'e5c52798-0b86-402b-a9d6-6781368de35a'::uuid, false, 2, '102b, 1003a', '2026-02-24 06:49:16.855658-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO turno_registro_itens (id, registro_id, inventario_id, confere, qtd_informada, comentario, created_at)
  VALUES ('6dbfd4d3-ef80-468a-9be9-bb53f6e2df2a'::uuid, '0c184741-fd91-4220-bbe1-e8149d86b743'::uuid, 'b074c032-76c3-4bd9-ad6f-f71070bca54d'::uuid, false, 2, 'mais 102b, 1003a', '2026-02-24 06:49:16.855658-03'::timestamptz)
  ON CONFLICT (id) DO NOTHING;

  RAISE NOTICE '🎉 Migração completa!';
END $$;

-- Recriar FK (sem constraint para dados históricos sem porteiro_id válido)
-- A coluna porteiro_nome já tem o nome correto para consulta