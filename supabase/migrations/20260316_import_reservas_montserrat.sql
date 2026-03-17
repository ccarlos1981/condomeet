-- Migration: Import 177 historical reservations from old system for Condomínio Montserrat
-- Maps old area_comum_id (4=Mudança, 5=Obra, 6=Salão de Festa) to new areas_comuns UUIDs
-- Maps users by bloco_txt + apto_txt in perfil table

DO $$
DECLARE
  v_condo_id UUID := '4828f5f6-454c-438c-9ef3-9f1bf5a7ab94'; -- Montserrat
  v_area_salao UUID;
  v_area_obra UUID;
  v_area_mudanca UUID;
  v_user_id UUID;
  v_area_id UUID;
  v_count INT := 0;
  v_skipped INT := 0;
  rec RECORD;
BEGIN
  -- 1. Look up area UUIDs
  SELECT id INTO v_area_salao FROM public.areas_comuns
    WHERE condominio_id = v_condo_id AND tipo_agenda = 'Salão de Festa' LIMIT 1;
  SELECT id INTO v_area_obra FROM public.areas_comuns
    WHERE condominio_id = v_condo_id AND tipo_agenda = 'Obra' LIMIT 1;
  SELECT id INTO v_area_mudanca FROM public.areas_comuns
    WHERE condominio_id = v_condo_id AND tipo_agenda = 'Mudança' LIMIT 1;

  IF v_area_salao IS NULL THEN RAISE EXCEPTION 'Salão de Festa not found for Montserrat'; END IF;
  IF v_area_mudanca IS NULL THEN RAISE EXCEPTION 'Mudança not found for Montserrat'; END IF;
  -- Obra might be NULL if not created, we'll skip those records

  RAISE NOTICE 'Areas found - Salão: %, Obra: %, Mudança: %', v_area_salao, v_area_obra, v_area_mudanca;

  -- 2. Create temp table with old data
  CREATE TEMP TABLE tmp_reservas_import (
    old_id INT,
    created_at TIMESTAMPTZ,
    old_area_id INT, -- 4=Mudança, 5=Obra, 6=Salão de Festa
    aprovado BOOLEAN,
    data_evento TIMESTAMPTZ,
    nome_evento TEXT,
    usuario_txt TEXT,
    bloco_txt TEXT,
    apto_txt TEXT,
    perfil_tipo TEXT
  );

  -- Insert all 177 records
  INSERT INTO tmp_reservas_import VALUES
  (503,'2026-03-15 10:18:55-03',6,false,'2026-03-21','Salão de Festa','Fernanda Castro','A','901','Morador (a)'),
  (502,'2026-03-13 11:24:30-03',6,true,'2026-03-20','Salão de Festa',NULL,'A','602','Usuário não cadastrado'),
  (501,'2026-03-12 13:57:48-03',6,true,'2026-03-15','Salão de Festa','Junia','A','204','Locatário (a)'),
  (500,'2026-03-11 15:38:14-03',6,true,'2026-04-04','Salão de Festa',NULL,'A','105','Usuário não cadastrado'),
  (499,'2026-03-11 15:35:10-03',6,false,'2026-03-27','Salão de Festa',NULL,'A','602','Usuário não cadastrado'),
  (489,'2026-03-06 18:41:02-03',6,true,'2026-03-07','Salão de Festa','ARILSON Araujo','A','306','Morador (a)'),
  (488,'2026-03-06 18:40:14-03',6,true,'2026-03-07','Salão de Festa','ARILSON Araujo','A','306','Morador (a)'),
  (486,'2026-02-28 12:36:25-03',6,true,'2026-03-08','Salão de Festa','Cintia','A','604','Morador (a)'),
  (401,'2026-02-03 17:51:35-03',4,false,'2026-02-06','Mudança','Izabelle','A','503','Locatário (a)'),
  (400,'2026-01-21 16:55:10-03',4,true,'2026-01-24','Mudança','Caio','B','703','Locatário (a)'),
  (397,'2026-01-08 08:15:40-03',6,true,'2026-01-17','Salão de Festa','Cintia','A','604','Morador (a)'),
  (384,'2025-12-19 13:00:48-03',6,false,'2025-12-25','Salão de Festa','Silmaria','B','306','Morador (a)'),
  (383,'2025-12-18 10:20:08-03',4,true,'2025-12-20','Mudança','João Luiz','A','204','Locatário (a)'),
  (382,'2025-12-11 16:41:02-03',4,true,'2026-01-08','Mudança 301B','Santos','B','301','ADMIN'),
  (381,'2025-12-11 16:40:53-03',4,true,'2026-01-07','Mudança 301B','Santos','B','9999','ADMIN'),
  (379,'2025-12-04 21:30:43-03',4,true,'2025-12-08','Mudança','Diana','A','503','Morador (a)'),
  (377,'2025-12-01 13:24:43-03',6,true,'2025-12-06','Salão de Festa','Washington','A','302','Morador (a)'),
  (374,'2025-11-24 15:41:57-03',6,true,'2025-12-14','Malena','Andre','A','604','Morador (a)'),
  (372,'2025-11-18 14:43:40-03',6,true,'2025-12-24','Salão de Festa','Silmaria','B','306','Morador (a)'),
  (371,'2025-11-16 21:23:45-03',6,true,'2025-11-22','Salão de Festa','Fernanda Castro','A','901','Morador (a)'),
  (370,'2025-11-15 16:46:10-03',6,true,'2025-12-26','Salão de Festa','Alessandra','B','601','Locatário (a)'),
  (369,'2025-11-12 12:41:36-03',6,true,'2025-11-28','Salão de Festa','Ayrton lima do nascimento','A','706','Morador (a)'),
  (367,'2025-11-04 16:37:02-03',6,true,'2025-11-07','Salão de Festa','Junia','A','204','Locatário (a)'),
  (351,'2025-09-23 18:34:58-03',4,true,'2025-09-25','MUDANÇA 102 B','Morador Ñ cadastrado','B','102','Porteiro (a)'),
  (348,'2025-09-06 14:56:57-03',6,true,'2025-11-01','Salão de Festa','Artur Carvalho','A','705','Morador (a)'),
  (347,'2025-09-06 12:25:20-03',6,true,'2025-11-15','Salão de Festa manha e tarde','Cintia Aguiar','A','203','Morador (a)'),
  (346,'2025-09-05 16:33:52-03',6,true,'2025-09-20','Salão de Festa','Bruno Vaz','B','302','Morador (a)'),
  (345,'2025-09-05 08:05:42-03',6,true,'2025-09-13','Salão de Festa','José Antônio de Carvalho','B','103','Morador (a)'),
  (342,'2025-09-03 20:02:23-03',6,true,'2025-09-28','Salão de Festa','Sidney Silva','B','501','Morador (a)'),
  (341,'2025-08-28 21:38:47-03',4,true,'2025-09-01','Mudança','Muriell Marques','A','106','Morador (a)'),
  (338,'2025-06-25 15:48:00-03',4,true,'2025-06-29','Mudança','Adriana Ricardo Leonarde','A','206','ADMIN'),
  (337,'2025-06-10 17:13:00-03',4,true,'2025-06-30','Mudança','Silvia','A','104','Morador (a)'),
  (336,'2025-06-07 08:58:00-03',6,true,'2025-06-27','Salão de Festa','ARILSON Araujo','A','306','Morador (a)'),
  (335,'2025-06-04 16:38:00-03',6,true,'2025-06-26','Salão de Festa','Artur Carvalho','A','705','Morador (a)'),
  (334,'2025-06-03 15:02:00-03',6,true,'2025-06-20','Salão de Festa','Athos Araújo','B','504','Morador (a)'),
  (333,'2025-05-07 11:19:00-03',4,true,'2025-05-07','MUDANCA','Priscila','A','104','Morador (a)'),
  (332,'2025-05-03 11:36:00-03',6,true,'2025-05-03','AYRTON LIMA','Ayrton lima do nascimento','A','706','Morador (a)'),
  (331,'2025-04-29 13:57:00-03',6,true,'2025-05-09','BARBARA AP 403 A SALAO DE FESTA','Thyago Veloso Ferreira','A','403','Morador (a)'),
  (329,'2025-04-11 12:06:00-03',4,true,'2025-04-14','Mudança','Bruna Petrini','A','902','Morador (a)'),
  (328,'2025-04-09 08:18:00-03',6,true,'2025-04-25','Salão de Festa','Athos Araújo','B','504','Morador (a)'),
  (327,'2025-04-02 13:42:00-03',6,true,'2025-04-12','ADMINISTRAÇÃO','Adriana Ricardo Leonarde','A','206','ADMIN'),
  (326,'2025-04-01 16:25:00-03',4,true,'2025-04-03','Mudança','Alex Dunder Koch','A','803','Locatário (a)'),
  (325,'2025-03-16 13:08:00-03',6,true,'2025-03-22','Salão de Festa','Adriana Ricardo Leonarde','A','206','ADMIN'),
  (324,'2025-03-15 11:32:00-03',4,true,'2025-03-30','Mudança','Alex Dunder Koch','A','803','Locatário (a)'),
  (323,'2025-03-14 08:49:00-03',6,true,'2025-04-05','Salão de Festa','Cintia Aguiar','A','203','Morador (a)'),
  (322,'2025-03-12 22:10:00-03',6,true,'2025-04-04','Salão de Festa','Athos Araújo','B','504','Morador (a)'),
  (321,'2025-03-11 15:36:00-03',6,true,'2025-03-27','SALAO 203 B','Rosilene Luiza Rangel','B','203','Morador (a)'),
  (320,'2025-03-11 07:28:00-03',4,true,'2025-03-16','Mudança405 B','Maria','B','405','Morador (a)'),
  (319,'2025-03-10 17:42:00-03',6,true,'2025-03-14','Salão de Festa','Ilma Glaucia Reis da luz','A','504','Morador (a)'),
  (318,'2025-02-23 13:41:00-03',6,true,'2025-03-21','Aniversário infantil','FranciscoAdelmo Maceno','A','102','Morador (a)'),
  (317,'2025-02-21 14:09:00-03',4,true,'2025-03-05','405 B','Maria','B','405','Morador (a)'),
  (316,'2025-02-21 14:05:00-03',4,true,'2025-03-05','405 B','Maria','B','405','Morador (a)'),
  (315,'2025-02-18 09:36:00-03',4,true,'2025-02-26','MUDANCA','Maria','B','405','Morador (a)'),
  (314,'2025-02-06 20:35:00-03',6,true,'2025-03-13','Aniversário Letícia','ARILSON Araujo','A','306','Morador (a)'),
  (313,'2025-02-03 18:49:00-03',4,true,'2025-02-04','Mudança','Anastacio','B','404','Morador (a)'),
  (312,'2025-01-29 22:52:00-03',6,true,'2025-01-30','Salão de Festa','João Paulo','B','801','Morador (a)'),
  (311,'2025-01-25 21:10:00-03',6,true,'2025-02-21','Salão de Festa','ARILSON Araujo','A','306','Morador (a)'),
  (310,'2025-01-20 09:55:00-03',4,true,'2025-01-20','RAMON ORNELAS','Osvaldo da Silva Ornelas Neto','B','603','Morador (a)'),
  (309,'2025-01-06 12:15:00-03',6,true,'2025-01-17','Salão de Festa','José Antônio de Carvalho','B','103','Morador (a)'),
  (308,'2025-01-02 18:27:00-03',6,true,'2025-01-16','Salão de Festa','Athos Araújo','B','504','Morador (a)'),
  (307,'2024-12-26 10:11:00-03',4,true,'2024-12-27','MUDANCA','Renata Lemos','B','803','Morador (a)'),
  (306,'2024-12-15 16:46:00-03',6,true,'2024-12-20','Salão de Festa','Athos Araújo','B','504','Morador (a)'),
  (305,'2024-11-29 10:52:00-03',6,true,'2024-12-23','ADM','Adriana Ricardo Leonarde','A','206','ADMIN'),
  (304,'2024-11-22 11:57:00-03',6,true,'2024-12-30','Salão de Festa','Bruno de Souza Oliveira Mariz','A','904','Morador (a)'),
  (303,'2024-11-20 09:01:00-03',6,true,'2024-12-06','Salão de Festa','Cátia Alves','B','204','Morador (a)'),
  (302,'2024-11-17 09:39:00-03',5,true,'2024-11-17','Obra','Bruno Vaz','B','302','Morador (a)'),
  (301,'2024-10-25 13:29:00-03',6,true,'2024-11-14','Salão de Festa (Bloco A)','Mariana Bernardes','A','402','Morador (a)'),
  (300,'2024-10-09 10:58:00-03',6,true,'2024-10-19','Salão de Festa (Bloco A)','Andre','A','604','Morador (a)'),
  (299,'2024-09-24 20:22:00-03',6,true,'2024-09-27','Salão de Festa (João Paulo)','João Paulo','B','801','Morador (a)'),
  (298,'2024-09-20 16:43:00-03',6,true,'2024-10-18','Salão de Festa (Bloco A)','Larissa','A','1003','Locatário (a)'),
  (297,'2024-09-12 16:42:00-03',6,true,'2024-09-26','Salão de Festa (Bloco A)','Maria Eduarda','B','304','Morador (a)'),
  (296,'2024-09-10 11:43:00-03',6,true,'2024-09-20','SALAO 901 B','Márcia Maria F. Prates','B','901','Morador (a)'),
  (295,'2024-08-20 14:20:00-03',6,true,'2024-08-22','Salão de Festa (Bloco A)','Ashley Amorim','A','706','Morador (a)'),
  (294,'2024-08-08 11:29:00-03',6,true,'2024-08-09','Salão de Festa (Bloco A)','Athos Araújo','B','504','Morador (a)'),
  (293,'2024-08-07 15:54:00-03',6,true,'2024-08-08','Salão de Festa (Bloco A)','Athos Araújo','B','504','Morador (a)'),
  (292,'2024-08-05 21:30:00-03',6,true,'2024-08-29','Salão de Festa (Bloco A)','Athos Araújo','B','504','Morador (a)'),
  (291,'2024-07-29 14:08:00-03',6,true,'2024-07-30','Reunião Funcionários','Adriana Ricardo Leonarde','A','206','ADMIN'),
  (290,'2024-07-24 14:26:00-03',6,true,'2024-09-13','Aniversário José Maurício 40 anos','Jose Dorninger','B','106','Morador (a)'),
  (289,'2024-07-14 08:55:00-03',6,true,'2024-08-10','Salão de Festa (Bloco A)','Marcos Mognatti','B','905','Morador (a)'),
  (288,'2024-07-13 13:30:00-03',6,true,'2024-08-02','Salão de Festa (Bloco A)','Priscila','A','104','Morador (a)'),
  (287,'2024-07-04 11:26:00-03',6,true,'2024-07-11','Salão de Festa (Bloco A)','KASSANDRA SUGUINO','B','903','Morador (a)'),
  (286,'2024-07-01 06:36:00-03',4,true,'2024-07-04','Mudança','FABIO LIMA ALVES','A','1002','Morador (a)'),
  (285,'2024-06-17 18:14:00-03',5,true,'2024-06-17','Obra','FABIO LIMA ALVES','A','1002','Morador (a)'),
  (284,'2024-05-25 17:23:00-03',6,true,'2024-06-01','Salão de Festa (Bloco A)','Lígia Amorim','B','805','Morador (a)'),
  (283,'2024-05-07 11:49:00-03',6,true,'2024-05-07','Salão de Festa (Bloco A)','Pedro Amaral','B','805','Locatário (a)'),
  (282,'2024-05-05 13:02:00-03',6,true,'2024-05-11','SALAO 102 A','FranciscoAdelmo Maceno','A','102','Morador (a)'),
  (281,'2024-05-01 15:35:00-03',6,true,'2024-06-29','Salão de Festa (Bloco A)','Silmária Dávalos','B','306','Morador (a)'),
  (280,'2024-04-21 13:08:00-03',6,true,'2024-05-24','102 A SALAO','FranciscoAdelmo Maceno','A','102','Morador (a)'),
  (279,'2024-04-12 10:06:00-03',6,true,'2024-04-26','Salão de Festa (Bloco A)','Ashley Amorim','A','706','Morador (a)'),
  (278,'2024-04-11 10:40:00-03',6,true,'2024-05-31','Salão de Festa (Bloco A)','Medeiros','B','505','Locatário (a)'),
  (277,'2024-04-05 16:02:00-03',6,true,'2024-04-27','Salão de Festa (Bloco A)','Fernanda Castro','A','901','Morador (a)'),
  (276,'2024-04-05 15:12:00-03',6,true,'2024-04-19','Salão (506A)','Michelle costa','A','506','Morador (a)'),
  (275,'2024-04-04 09:53:00-03',4,true,'2024-04-05','Mudança','Danielle Corrêa Wan Meyl','A','802','Morador (a)'),
  (274,'2024-03-29 18:12:00-03',6,true,'2024-03-30','Salão de Festa (Bloco A)','Danielle Corrêa Wan Meyl','A','802','Morador (a)'),
  (273,'2024-03-22 08:26:00-03',6,true,'2024-03-23','Salão de Festa (Bloco A)','Athos Araújo','B','504','Morador (a)'),
  (272,'2024-03-21 10:03:00-03',6,true,'2024-03-26','Salão de Festa (Bloco A)','Pedro Amaral','B','805','Locatário (a)'),
  (271,'2024-02-27 10:24:00-03',6,true,'2024-03-01','SALAO 104 B','Leandro Ornelas','B','104','Morador (a)'),
  (270,'2024-02-26 11:27:00-03',4,true,'2024-02-26','MUDANCA','Airton M','B','702','Morador (a)'),
  (269,'2024-02-01 10:32:00-03',6,true,'2024-02-23','102 A','FranciscoAdelmo Maceno','A','102','Morador (a)'),
  (268,'2024-01-30 15:39:00-03',4,true,'2024-01-30','Mudança5O4-A','Ilma Glaucia Reis da luz','A','504','Morador (a)'),
  (267,'2024-01-11 18:25:00-03',6,true,'2024-01-26','Salão de Festa (Bloco A)','Athos Araújo','B','504','Morador (a)'),
  (266,'2024-01-11 12:38:00-03',6,true,'2024-01-18','Salão de Festa (Bloco A)','José Antônio de Carvalho','B','103','Morador (a)'),
  (265,'2024-01-08 20:19:00-03',6,true,'2024-01-11','Salão de Festa (Bloco A)','Roberta','A','301','Morador (a)'),
  (264,'2024-01-07 12:15:00-03',6,true,'2024-01-07','Salão de Festa (Bloco A)','Athos Araújo','B','504','Morador (a)'),
  (263,'2023-12-20 15:57:00-03',4,true,'2023-12-20','Mudança','Simone Barbosa','A','304','Morador (a)'),
  (262,'2023-12-12 08:21:00-03',4,true,'2023-12-19','Mudança','ARILSON Araujo','A','306','Morador (a)'),
  (261,'2023-12-11 11:35:00-03',6,true,'2023-12-22','Salão de Festa (Bloco A)','Bruno Vaz','B','302','Morador (a)'),
  (260,'2023-12-10 17:30:00-03',4,true,'2023-12-11','MUDANCA','Emilly Victoria','A','504','Morador (a)'),
  (259,'2023-12-10 14:12:00-03',6,true,'2023-12-21','Salão de Festa (Bloco A)','Adriana Ricardo Leonarde','A','206','ADMIN'),
  (258,'2023-12-04 20:55:00-03',4,true,'2023-12-08','Mudança','Ayrton lima do nascimento','A','706','Morador (a)'),
  (257,'2023-12-01 09:47:00-03',6,true,'2023-12-09','SIMONE 304A','Simone Barbosa','A','304','Morador (a)'),
  (256,'2023-11-30 21:44:00-03',4,true,'2023-12-04','Mudança','Artur Carvalho','A','705','Morador (a)'),
  (255,'2023-11-16 11:06:00-03',6,true,'2023-12-01','Salão de Festa (Bloco A)','Tania Regina Ferreira dos Santos','B','201','Morador (a)'),
  (254,'2023-11-05 06:44:00-03',4,true,'2023-11-30','Mudança','André','B','202','Morador (a)'),
  (253,'2023-11-04 11:04:00-03',4,true,'2023-11-06','Mudança','Isis Oliveira','A','501','Morador (a)'),
  (252,'2023-10-28 08:19:00-03',6,true,'2023-11-24','Salão de Festa (Bloco A)','Cátia Alves','B','204','Morador (a)'),
  (251,'2023-10-21 23:56:00-03',6,true,'2023-10-26','Salão de Festa (Bloco A) / AGE','Adriana Ricardo Leonarde','A','206','ADMIN'),
  (250,'2023-10-21 23:54:00-03',6,true,'2023-11-03','Salão de Festa (Bloco A)','Bruno Vaz','B','302','Morador (a)'),
  (249,'2023-10-21 12:28:00-03',6,true,'2023-10-21','Salão de Festa (Bloco A)','Pedro Amaral','B','805','Locatário (a)'),
  (248,'2023-10-01 15:46:00-03',6,true,'2023-10-28','Salão de Festa (Bloco A)','Emilly Victoria','A','504','Morador (a)'),
  (247,'2023-09-29 19:25:00-03',6,true,'2023-10-13','Salão de Festa (Bloco A)','BEATRIZ DA CRUZ OLBERTZ','A','703','Morador (a)'),
  (246,'2023-09-19 11:34:00-03',6,true,'2023-09-23','Salão de Festa (Bloco A)','BEATRIZ DA CRUZ OLBERTZ','A','703','Morador (a)'),
  (245,'2023-09-05 13:19:00-03',4,true,'2023-09-07','mudanca','Rosivan','A','1003','Morador (a)'),
  (244,'2023-08-21 07:20:00-03',6,true,'2023-09-06','Salão de Festa (Bloco A)','Athos Araújo','B','504','Morador (a)'),
  (243,'2023-08-01 15:27:00-03',6,true,'2023-08-12','Salão de Festa (Bloco A)','Cintia Aguiar','A','203','Morador (a)'),
  (242,'2023-07-27 07:59:00-03',4,true,'2023-07-27','Mudança 805 A','Adriano Vargas','A','805','Morador (a)'),
  (241,'2023-07-13 17:58:00-03',6,true,'2023-07-24','Salão de Festa (Bloco A)','Ana Said','B','606','Morador (a)'),
  (240,'2023-07-12 22:25:00-03',6,true,'2023-09-08','Salão de Festa (Bloco A)','Mariana Bernardes','A','402','Morador (a)'),
  (239,'2023-07-06 14:58:00-03',6,true,'2023-07-16','Mudança','Eduardo Medeiros Rubik','A','805','Morador (a)'),
  (238,'2023-07-06 13:41:00-03',4,true,'2023-07-05','Mudança','Eduardo Medeiros Rubik','A','805','Morador (a)'),
  (237,'2023-07-05 14:44:00-03',4,true,'2023-07-06','Mudança/ período da tarde','Eduardo Medeiros Rubik','A','805','Morador (a)'),
  (236,'2023-07-03 08:26:00-03',4,true,'2023-07-05','805 A Mudança','Eduardo Medeiros Rubik','A','805','Morador (a)'),
  (235,'2023-07-03 08:23:00-03',4,true,'2023-07-05','PELA MANHA','Eduardo Medeiros Rubik','A','805','Morador (a)'),
  (234,'2023-06-14 17:55:00-03',4,true,'2023-06-15','Mudança','Jucilene lima','B','503','Morador (a)'),
  (233,'2023-06-14 16:22:00-03',6,true,'2023-07-14','Salão de Festa (Bloco A)','Cátia Alves','B','204','Morador (a)'),
  (232,'2023-06-11 15:01:00-03',6,true,'2023-06-16','Salão de Festa (Bloco A)','Giuliana van Tol','A','701','Locatário (a)'),
  (231,'2023-06-07 16:21:00-03',4,true,'2023-06-11','Mudança','Medeiros','B','505','Locatário (a)'),
  (230,'2023-05-23 11:22:00-03',6,true,'2023-06-23','EVENTO','Thyago Veloso Ferreira','A','403','Morador (a)'),
  (229,'2023-05-23 11:19:00-03',6,true,'2023-06-25','EVENTO','Thyago Veloso Ferreira','A','403','Morador (a)'),
  (228,'2023-05-20 10:25:00-03',4,true,'2023-05-22','Mudança','Evellyn Araujo','B','505','Morador (a)'),
  (227,'2023-04-11 21:21:00-03',6,true,'2023-04-14','Salão de Festa (Bloco A)','Henrique Silva','A','303','Morador (a)'),
  (226,'2023-03-30 17:20:00-03',6,true,'2023-03-30','Salão de Festa (Bloco A)','Athos Araújo','B','504','Morador (a)'),
  (225,'2023-03-29 17:58:00-03',6,true,'2023-04-07','Salão de Festa (Bloco A)','Henrique Silva','A','303','Morador (a)'),
  (224,'2023-03-02 09:43:00-03',4,true,'2023-03-14','MUDANÇA','Cláudio Antônio de Campos','B','704','Morador (a)'),
  (223,'2023-03-01 12:56:00-03',6,true,'2023-03-02','FESTA','Gabriel Leão','A','301','Morador (a)'),
  (222,'2023-02-15 15:56:00-03',6,true,'2023-02-16','Mudança','Pedro Amaral','B','805','Locatário (a)'),
  (221,'2023-02-10 07:37:00-03',6,true,'2023-02-24','Salão de Festa (Bloco A)','Evellyn Araujo','B','505','Morador (a)'),
  (220,'2023-02-07 22:19:00-03',6,true,'2023-03-10','Salão de Festa (Bloco A)','Silvana','A','1001','Morador (a)'),
  (219,'2023-02-02 09:38:00-03',6,true,'2023-02-06','adm montserrat','Adriana Ricardo Leonarde','A','206','ADMIN'),
  (218,'2022-12-07 13:03:00-03',6,true,'2022-12-07','MUDANCAS','Renata Lemos','B','803','Renata Lemos'),
  (217,'2022-12-04 11:01:00-03',6,true,'2022-12-17','Confraternização','Huldson araujo da silva','B','504','Huldson araujo da silva'),
  (216,'2022-11-27 18:35:00-03',6,true,'2022-12-02','Salão de Festa 1','Vinícius Almeida','A','303','Morador (a)'),
  (215,'2022-11-19 18:46:00-03',6,true,'2022-11-27','Salão de Festa 1','Marcos Mognatti','B','905','Morador (a)'),
  (214,'2022-10-17 17:52:00-03',6,true,'2022-12-24','Salão de Festa 1 (A)','Cátia Alves','B','204','Morador (a)'),
  (213,'2022-10-03 07:01:00-03',6,true,'2022-10-29','Salão de Festa','Emilly Victoria','A','504','Morador (a)'),
  (212,'2022-10-03 06:58:00-03',6,true,'2022-10-08','Salão de Festa bloco A','Huldson araujo da silva','B','504','Morador (a)'),
  (211,'2022-10-03 06:51:00-03',6,true,'2022-10-03','Isaías','Izaias Pereira Pinto Filho','A','903','Morador (a)'),
  (210,'2022-08-02 21:55:00-03',6,true,'2022-08-13','Confraternização Luiza','Luiza Rachel Leonarde Padrao Aguiar','A','206','Morador (a)'),
  (209,'2022-06-10 10:28:00-03',6,true,'2022-06-27','Salão de Festa','Adriana Ricardo Leonarde','A','206','Morador (a)'),
  (208,'2022-05-08 06:32:00-03',6,true,'2022-05-15','Reunião',NULL,'A','403',''),
  (207,'2022-05-08 06:32:00-03',6,true,'2022-05-15','Reunião',NULL,'A','403',''),
  (206,'2022-05-03 12:58:00-03',6,true,'2022-06-18','salao de festa/tania brandao','Huldson araujo da silva','B','504',''),
  (205,'2022-04-25 09:43:00-03',6,true,'2022-04-25','Bruno Apto 803A',NULL,'A','803',''),
  (204,'2022-04-10 09:31:00-03',6,true,'2022-04-11','Musculação','Thyago Veloso Ferreira','A','403',''),
  (202,'2025-08-20 17:52:01-03',6,true,'2025-08-23','Salão de Festa','Mariana','A','402','Morador (a)'),
  (200,'2025-08-12 18:27:59-03',6,true,'2025-09-13','Salão de festa','José Antônio de Carvalho','B','103','Morador (a)'),
  (177,'2025-07-29 18:03:38-03',6,true,'2025-08-16','Salão de festa','Adriana Ricardo Leonarde','A','206','ADMIN'),
  (171,'2025-07-25 11:35:49-03',6,true,'2025-08-02','Salão de festa','Adriana Ricardo Leonarde','A','206','ADMIN'),
  (166,'2025-07-23 16:18:26-03',6,true,'2025-08-09','Salão de festa','João Paulo','B','801','Morador (a)'),
  (163,'2025-07-16 15:08:30-03',6,true,'2025-07-26','Salão de festa','Tiago Falconiery','B','802','Morador (a)'),
  (162,'2025-07-14 14:13:48-03',6,true,'2025-07-19','Salão de festa','Artur Carvalho','A','705','Morador (a)'),
  (75,'2025-07-01 09:00:03-03',4,true,'2025-07-01','Mudança','Silvia','A','104','Morador (a)'),
  (74,'2025-06-28 09:00:03-03',6,true,'2025-06-28','Salão de Festa','ARILSON Araujo','A','306','Morador (a)'),
  (73,'2025-06-27 09:00:03-03',6,true,'2025-06-27','Salão de Festa','Artur Carvalho','A','705','Morador (a)'),
  (72,'2025-06-21 09:00:03-03',6,true,'2025-06-21','Salão de Festa','Athos Araújo','B','504','Morador (a)');

  -- 3. Insert into reservas, matching users by bloco+apto
  FOR rec IN SELECT * FROM tmp_reservas_import ORDER BY old_id LOOP
    -- Determine area_id
    CASE rec.old_area_id
      WHEN 6 THEN v_area_id := v_area_salao;
      WHEN 5 THEN v_area_id := v_area_obra;
      WHEN 4 THEN v_area_id := v_area_mudanca;
      ELSE v_area_id := NULL;
    END CASE;

    IF v_area_id IS NULL THEN
      v_skipped := v_skipped + 1;
      RAISE NOTICE 'SKIP old_id=% - area not found (old_area_id=%)', rec.old_id, rec.old_area_id;
      CONTINUE;
    END IF;

    -- Try to find user by bloco+apto in perfil
    SELECT id INTO v_user_id
      FROM public.perfil
      WHERE condominio_id = v_condo_id
        AND UPPER(TRIM(bloco_txt)) = UPPER(TRIM(rec.bloco_txt))
        AND TRIM(apto_txt) = TRIM(rec.apto_txt)
      ORDER BY created_at DESC
      LIMIT 1;

    IF v_user_id IS NULL THEN
      v_skipped := v_skipped + 1;
      RAISE NOTICE 'SKIP old_id=% - no perfil for bloco=% apto=% (user=%)', rec.old_id, rec.bloco_txt, rec.apto_txt, rec.usuario_txt;
      CONTINUE;
    END IF;

    -- Insert reservation
    INSERT INTO public.reservas (area_id, user_id, condominio_id, data_reserva, status, nome_evento, created_at, updated_at)
    VALUES (
      v_area_id,
      v_user_id,
      v_condo_id,
      rec.data_evento::DATE,
      CASE WHEN rec.aprovado THEN 'aprovado' ELSE 'pendente' END,
      rec.nome_evento,
      rec.created_at,
      rec.created_at
    );

    v_count := v_count + 1;
  END LOOP;

  DROP TABLE tmp_reservas_import;

  RAISE NOTICE '=== IMPORT COMPLETE: % reservas imported, % skipped ===', v_count, v_skipped;
END $$;
