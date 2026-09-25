-- ============================================================
-- Migration: 20260925_fix_album_fotos_lifecycle_and_push.sql
-- Objetivo: Ciclo de vida rascunho -> publicado, proteção contra
--           álbum sem fotos, integridade da última foto e correção
--           do momento de disparo do Push FCM.
-- Projeto Oficial: condomeet_Antigravity (avypyaxthvgaybplnwxu)
-- ============================================================

-- 1. STATUS DO ÁLBUM
-- Adiciona a coluna status com default 'publicado' para garantir
-- retrocompatibilidade total com todos os álbuns históricos existentes.
ALTER TABLE public.album_fotos
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'publicado'
  CHECK (status IN ('rascunho', 'publicado'));

-- Índice para otimização de consultas por condomínio e status
CREATE INDEX IF NOT EXISTS idx_album_fotos_condo_status
  ON public.album_fotos (condominio_id, status, created_at DESC);


-- 2. TRIGGERS DE PUSH (ESTRATÉGIA DE TRANSIÇÃO E COEXISTÊNCIA SEGURA)
-- Remove o trigger legado incondicional e versões anteriores
DROP TRIGGER IF EXISTS trg_notify_novo_album ON public.album_fotos;
DROP TRIGGER IF EXISTS trg_notify_novo_album_insert ON public.album_fotos;
DROP TRIGGER IF EXISTS trg_notify_novo_album_update ON public.album_fotos;

-- Trigger A (Transitório / Compatibilidade com Clientes Legados):
-- Dispara Push no INSERT SOMENTE se o cliente inseriu com status = 'publicado' (ou default legado)
CREATE TRIGGER trg_notify_novo_album_insert
  AFTER INSERT ON public.album_fotos
  FOR EACH ROW
  WHEN (NEW.status = 'publicado')
  EXECUTE FUNCTION public.notify_novo_album();

-- Trigger B (Definitivo / Novo Fluxo Atômico de Publicação):
-- Dispara Push no UPDATE EXCLUSIVAMENTE na transição de 'rascunho' para 'publicado' (upload 100% concluído)
CREATE TRIGGER trg_notify_novo_album_update
  AFTER UPDATE OF status ON public.album_fotos
  FOR EACH ROW
  WHEN (OLD.status = 'rascunho' AND NEW.status = 'publicado')
  EXECUTE FUNCTION public.notify_novo_album();



-- 3. PROTEÇÃO DA PUBLICAÇÃO: IMPEDIR PUBLICAÇÃO SEM FOTOS
-- Valida se existe pelo menos 1 imagem antes de permitir status = 'publicado'
CREATE OR REPLACE FUNCTION public.check_album_publicacao()
RETURNS TRIGGER AS $$
BEGIN
  IF (OLD.status = 'rascunho' AND NEW.status = 'publicado') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.album_fotos_imagens WHERE album_id = NEW.id
    ) THEN
      RAISE EXCEPTION 'Não é permitido publicar um álbum sem fotos cadastradas.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_album_publicacao ON public.album_fotos;
CREATE TRIGGER trg_check_album_publicacao
  BEFORE UPDATE OF status ON public.album_fotos
  FOR EACH ROW
  EXECUTE FUNCTION public.check_album_publicacao();


-- 4. INTEGRIDADE DA ÚLTIMA FOTO (CONSTRAINT TRIGGER DIFERIDO)
-- Avaliado ao final da transação (DEFERRABLE INITIALLY DEFERRED).
-- Permite ON DELETE CASCADE (se o álbum pai foi excluído, encerra sem erro).
-- Permite rollback de rascunho (se status != 'publicado', encerra sem erro).
-- Bloqueia edição que deixe álbum publicado com 0 fotos.
CREATE OR REPLACE FUNCTION public.check_album_fotos_min_count()
RETURNS TRIGGER AS $$
DECLARE
  v_status TEXT;
  v_count  INT;
BEGIN
  -- 1. Se o álbum pai deixou de existir (ex: via ON DELETE CASCADE), permite a exclusão livremente
  IF NOT EXISTS (SELECT 1 FROM public.album_fotos WHERE id = OLD.album_id) THEN
    RETURN NULL;
  END IF;

  -- 2. Se o álbum pai ainda existe, verificar o status
  SELECT status INTO v_status FROM public.album_fotos WHERE id = OLD.album_id;

  -- 3. Se estiver em 'rascunho', permite remoção livre (criação / rollback)
  IF v_status IS DISTINCT FROM 'publicado' THEN
    RETURN NULL;
  END IF;

  -- 4. Para álbum em status 'publicado' que permanece no banco:
  --    Verifica se restou pelo menos 1 foto associada
  SELECT COUNT(*) INTO v_count 
  FROM public.album_fotos_imagens 
  WHERE album_id = OLD.album_id;

  IF v_count = 0 THEN
    RAISE EXCEPTION 'Operação cancelada: um álbum publicado deve conter pelo menos 1 foto.';
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_album_fotos_min_count ON public.album_fotos_imagens;
CREATE CONSTRAINT TRIGGER trg_check_album_fotos_min_count
  AFTER DELETE ON public.album_fotos_imagens
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION public.check_album_fotos_min_count();


-- 5. RLS: MORADORES VISUALIZAM APENAS ÁLBUNS PUBLICADOS
-- Preserva estritamente o isolamento multi-tenant por condominio_id
DROP POLICY IF EXISTS "resident_read_album_fotos" ON public.album_fotos;
CREATE POLICY "resident_read_album_fotos"
  ON public.album_fotos FOR SELECT
  USING (
    condominio_id IN (
      SELECT condominio_id FROM public.perfil WHERE id = auth.uid()
    )
    AND status = 'publicado'
  );

DROP POLICY IF EXISTS "resident_read_album_imagens" ON public.album_fotos_imagens;
CREATE POLICY "resident_read_album_imagens"
  ON public.album_fotos_imagens FOR SELECT
  USING (
    album_id IN (
      SELECT id FROM public.album_fotos
      WHERE condominio_id IN (
        SELECT condominio_id FROM public.perfil WHERE id = auth.uid()
      )
      AND status = 'publicado'
    )
  );
