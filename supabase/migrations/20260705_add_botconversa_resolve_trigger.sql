-- Migration: Recriar triggers de resolução e invalidação do BotConversa no Perfil
-- Date: 2026-07-05
-- Description: Garante que a alteração de whatsapp invalide o cache e que a trigger tr_perfil_resolve_botconversa resolva e salve o botconversa_id.

-- 1. Invalidação do botconversa_id antes de atualizar o whatsapp (BEFORE UPDATE)
CREATE OR REPLACE FUNCTION public.tr_fn_invalidate_botconversa_id()
RETURNS trigger AS $$
BEGIN
  IF NEW.whatsapp IS DISTINCT FROM OLD.whatsapp THEN
    NEW.botconversa_id := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_perfil_invalidate_botconversa_id ON public.perfil;

CREATE TRIGGER tr_perfil_invalidate_botconversa_id
  BEFORE UPDATE OF whatsapp ON public.perfil
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_invalidate_botconversa_id();

-- 2. Resolução do botconversa_id após inserir ou atualizar o whatsapp (AFTER INSERT OR UPDATE)
DROP TRIGGER IF EXISTS tr_perfil_resolve_botconversa ON public.perfil;

CREATE TRIGGER tr_perfil_resolve_botconversa
  AFTER INSERT OR UPDATE OF whatsapp ON public.perfil
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_fn_resolve_botconversa();
