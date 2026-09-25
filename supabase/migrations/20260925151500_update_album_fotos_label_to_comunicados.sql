-- ============================================================
-- Migration: 20260925151500_update_album_fotos_label_to_comunicados.sql
-- Objetivo: Atualizar exclusivamente o label de "album_fotos" para "Comunicados"
--           no campo features_config da tabela public.condominios.
--           Preserva integralmente: id, route, icon, order, visible, roles
--           e todos os demais itens do menu/configuração.
-- Projeto Oficial: condomeet_Antigravity (avypyaxthvgaybplnwxu)
-- ============================================================

CREATE OR REPLACE FUNCTION public._temp_update_menu_array(arr jsonb)
RETURNS jsonb AS $$
  SELECT COALESCE(
    (
      SELECT jsonb_agg(
        CASE 
          WHEN elem->>'id' = 'album_fotos' AND elem->>'label' = 'Álbum de Fotos'
          THEN elem || jsonb_build_object('label', 'Comunicados')
          ELSE elem
        END
        ORDER BY ord
      )
      FROM jsonb_array_elements(arr) WITH ORDINALITY AS t(elem, ord)
    ),
    '[]'::jsonb
  );
$$ LANGUAGE sql IMMUTABLE;

DO $$
DECLARE
  r RECORD;
  v_cfg JSONB;
BEGIN
  FOR r IN 
    SELECT id, features_config 
    FROM public.condominios 
    WHERE features_config::text LIKE '%album_fotos%' 
      AND features_config::text LIKE '%Álbum de Fotos%'
  LOOP
    v_cfg := r.features_config;
    
    -- 1. Atualiza functions se existir
    IF v_cfg ? 'functions' AND jsonb_typeof(v_cfg->'functions') = 'array' THEN
      v_cfg := jsonb_set(v_cfg, '{functions}', public._temp_update_menu_array(v_cfg->'functions'));
    END IF;
    
    -- 2. Atualiza resident_menu se existir
    IF v_cfg ? 'resident_menu' AND jsonb_typeof(v_cfg->'resident_menu') = 'array' THEN
      v_cfg := jsonb_set(v_cfg, '{resident_menu}', public._temp_update_menu_array(v_cfg->'resident_menu'));
    END IF;

    -- 3. Atualiza admin_menu se existir
    IF v_cfg ? 'admin_menu' AND jsonb_typeof(v_cfg->'admin_menu') = 'array' THEN
      v_cfg := jsonb_set(v_cfg, '{admin_menu}', public._temp_update_menu_array(v_cfg->'admin_menu'));
    END IF;

    UPDATE public.condominios 
    SET features_config = v_cfg 
    WHERE id = r.id;
  END LOOP;
END $$;

DROP FUNCTION IF EXISTS public._temp_update_menu_array(jsonb);
