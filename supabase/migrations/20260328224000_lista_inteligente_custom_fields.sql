-- Adicionar campos customizados e unidades à tabela lista_shopping_list_items

ALTER TABLE lista_shopping_list_items
ADD COLUMN custom_name TEXT,
ADD COLUMN custom_note TEXT,
ADD COLUMN unit_amount NUMERIC(10,2) DEFAULT 1,
ADD COLUMN unit_type TEXT DEFAULT 'un';
