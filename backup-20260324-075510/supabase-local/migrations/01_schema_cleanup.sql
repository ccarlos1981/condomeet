-- ==============================================================================
-- 1. LIMPEZA DE TABELAS OBSOLETAS (VERSÃO EM INGLÊS)
-- ATENÇÃO: Se você tinha dados de teste nessas tabelas, eles serão apagados.
-- O aplicativo agora usa exclusivamente as tabelas em português (perfil, condominios, etc)
-- ==============================================================================

DROP TABLE IF EXISTS "profiles" CASCADE;
DROP TABLE IF EXISTS "condominiums" CASCADE;
DROP TABLE IF EXISTS "units" CASCADE;
DROP TABLE IF EXISTS "blocks" CASCADE;
DROP TABLE IF EXISTS "apartments" CASCADE;
DROP TABLE IF EXISTS "area_bookings" CASCADE;
DROP TABLE IF EXISTS "occurrences" CASCADE;
DROP TABLE IF EXISTS "sos_alerts" CASCADE;
DROP TABLE IF EXISTS "chat_messages" CASCADE;
DROP TABLE IF EXISTS "invitations" CASCADE;
DROP TABLE IF EXISTS "documents" CASCADE;
DROP TABLE IF EXISTS "common_areas" CASCADE;
DROP TABLE IF EXISTS "inventory_items" CASCADE;
DROP TABLE IF EXISTS "assemblies" CASCADE;
DROP TABLE IF EXISTS "assembly_options" CASCADE;
DROP TABLE IF EXISTS "assembly_votes" CASCADE;

-- ==============================================================================
-- 2. ADIÇÃO DE NOVA COLUNA PARA TIPOS DE CONDOMÍNIO (PRÉDIO, CASA_RUA, CASA_QUADRA)
-- ==============================================================================

-- Verifica se a coluna já não existe e adiciona
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'condominios' 
        AND column_name = 'tipo_estrutura'
    ) THEN
        ALTER TABLE "condominios" ADD COLUMN "tipo_estrutura" TEXT DEFAULT 'predio' NOT NULL;
    END IF;
END $$;
