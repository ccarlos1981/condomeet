-- Migration: Update check_vote_eligibility trigger & update RLS for proxies
-- Target: 20260601010000_v2_assembleia_procuracoes_and_jitsi.sql

-- 1. Update the check_vote_eligibility function
CREATE OR REPLACE FUNCTION public.check_vote_eligibility()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_bloqueada boolean;
  v_status_assembleia text;
  v_is_resident boolean;
  v_procuracao_id uuid;
BEGIN
  -- 1. Verifica se a unidade está bloqueada na tabela unidades
  SELECT bloqueada_assembleia INTO v_bloqueada FROM public.unidades WHERE id = NEW.unit_id;
  IF v_bloqueada = true THEN
    RAISE EXCEPTION 'Unidade inadimplente ou impedida de votar nesta assembleia (Art. 1.335 do Código Civil).';
  END IF;

  -- 2. Verifica se a assembleia está em status de votação aberta
  SELECT status INTO v_status_assembleia FROM public.assembleias WHERE id = NEW.assembleia_id;
  IF v_status_assembleia != 'votacao_aberta' THEN
    RAISE EXCEPTION 'A votação para esta assembleia não está ativa.';
  END IF;

  -- 3. Verifica se o votante é morador da unidade
  SELECT EXISTS (
    SELECT 1 FROM public.unidade_perfil 
    WHERE perfil_id = NEW.votante_user_id AND unidade_id = NEW.unit_id
  ) INTO v_is_resident;

  IF NOT v_is_resident THEN
    -- Se não for morador direto, verifica se possui procuração aprovada para esta assembleia
    SELECT id INTO v_procuracao_id 
    FROM public.assembleia_procuracoes
    WHERE assembleia_id = NEW.assembleia_id
      AND outorgante_unit_id = NEW.unit_id
      AND outorgado_user_id = NEW.votante_user_id
      AND status = 'aprovada'
    LIMIT 1;

    IF v_procuracao_id IS NOT NULL THEN
      NEW.por_procuracao := true;
      NEW.procuracao_id := v_procuracao_id;
    ELSE
      RAISE EXCEPTION 'Você não tem permissão para votar por esta unidade. Outorgue uma procuração ou verifique seu cadastro.';
    END IF;
  ELSE
    -- Se for morador direto, garante que por_procuracao e procuracao_id sejam nulos/falsos
    NEW.por_procuracao := false;
    NEW.procuracao_id := NULL;
  END IF;

  RETURN NEW;
END;
$$;

-- Ensure the trigger is attached
DROP TRIGGER IF EXISTS trg_check_vote_eligibility ON public.assembleia_votos;
CREATE TRIGGER trg_check_vote_eligibility
  BEFORE INSERT OR UPDATE ON public.assembleia_votos
  FOR EACH ROW EXECUTE FUNCTION public.check_vote_eligibility();

-- 2. Update RLS policies for assembleia_votos to support proxies
DROP POLICY IF EXISTS "morador_update_voto" ON public.assembleia_votos;
CREATE POLICY "morador_update_voto"
ON public.assembleia_votos FOR UPDATE TO authenticated
USING (
  votante_user_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.unidade_perfil up
    WHERE up.perfil_id = auth.uid()
      AND up.unidade_id = assembleia_votos.unit_id
  )
  OR EXISTS (
    SELECT 1 FROM public.assembleia_procuracoes ap
    WHERE ap.assembleia_id = assembleia_votos.assembleia_id
      AND ap.outorgante_unit_id = assembleia_votos.unit_id
      AND ap.outorgado_user_id = auth.uid()
      AND ap.status = 'aprovada'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.assembleias a
    WHERE a.id = assembleia_votos.assembleia_id
      AND a.status = 'votacao_aberta'
      AND NOW() BETWEEN a.dt_inicio_votacao AND a.dt_fim_votacao
  )
);

DROP POLICY IF EXISTS "morador_select_own_voto" ON public.assembleia_votos;
CREATE POLICY "morador_select_own_voto"
ON public.assembleia_votos FOR SELECT TO authenticated
USING (
  votante_user_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.unidade_perfil up
    WHERE up.perfil_id = auth.uid()
      AND up.unidade_id = assembleia_votos.unit_id
  )
  OR EXISTS (
    SELECT 1 FROM public.assembleia_procuracoes ap
    WHERE ap.assembleia_id = assembleia_votos.assembleia_id
      AND ap.outorgante_unit_id = assembleia_votos.unit_id
      AND ap.outorgado_user_id = auth.uid()
      AND ap.status = 'aprovada'
  )
);

-- 3. Add foreign key constraints for joint queries in PostgREST
ALTER TABLE public.assembleia_procuracoes
  DROP CONSTRAINT IF EXISTS fk_procuracoes_outorgante_unit,
  DROP CONSTRAINT IF EXISTS fk_procuracoes_outorgante_user,
  DROP CONSTRAINT IF EXISTS fk_procuracoes_outorgado_user;

ALTER TABLE public.assembleia_procuracoes
  ADD CONSTRAINT fk_procuracoes_outorgante_unit FOREIGN KEY (outorgante_unit_id) REFERENCES public.unidades(id) ON DELETE CASCADE,
  ADD CONSTRAINT fk_procuracoes_outorgante_user FOREIGN KEY (outorgante_user_id) REFERENCES public.perfil(id) ON DELETE CASCADE,
  ADD CONSTRAINT fk_procuracoes_outorgado_user FOREIGN KEY (outorgado_user_id) REFERENCES public.perfil(id) ON DELETE CASCADE;

-- 4. Update the tipo_transmissao check constraint on public.assembleias to support Jitsi & videoconferencia
ALTER TABLE public.assembleias DROP CONSTRAINT IF EXISTS assembleias_tipo_transmissao_check;
ALTER TABLE public.assembleias ADD CONSTRAINT assembleias_tipo_transmissao_check CHECK (tipo_transmissao = ANY (ARRAY['agora'::text, 'youtube'::text, 'jitsi'::text, 'videoconferencia'::text]));
