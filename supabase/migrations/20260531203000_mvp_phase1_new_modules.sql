-- Migration: 20260531203000_mvp_phase1_new_modules
-- Description: Implement database updates for MVP Phase 1 (Central de Acordos Pix Express, Dashboard Multi-condomínio, Assembleias Paperless, Liberação de Visitantes Express)

-- ═══════════════════════════════════════════════════════════
--  1. Central de Acordos Pix Express Tables
-- ═══════════════════════════════════════════════════════════

-- 1.1. Tabela Principal de Acordos
CREATE TABLE IF NOT EXISTS public.financeiro_acordos (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id           UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
    unidade_id              UUID        NOT NULL REFERENCES public.unidades(id) ON DELETE CASCADE,
    perfil_id               UUID        NOT NULL REFERENCES public.perfil(id) ON DELETE RESTRICT,
    
    valor_original          DECIMAL(12,2) NOT NULL,
    valor_desconto          DECIMAL(12,2) DEFAULT 0.00,
    valor_acordo            DECIMAL(12,2) NOT NULL,
    parcelas_qtd            INT         NOT NULL CHECK (parcelas_qtd > 0),
    status                  TEXT        NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'ativo', 'finalizado', 'cancelado', 'atrasado')),
    
    termos_texto            TEXT        NOT NULL,
    assinatura_timestamp    TIMESTAMPTZ,
    assinatura_ip           INET,
    assinatura_user_agent   TEXT,
    
    created_at              TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at              TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 1.2. Tabela de Parcelas do Acordo
CREATE TABLE IF NOT EXISTS public.financeiro_acordo_parcelas (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    acordo_id               UUID        NOT NULL REFERENCES public.financeiro_acordos(id) ON DELETE CASCADE,
    numero_parcela          INT         NOT NULL CHECK (numero_parcela > 0),
    valor                   DECIMAL(12,2) NOT NULL,
    data_vencimento         DATE        NOT NULL,
    status                  TEXT        NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'pago', 'atrasado', 'cancelado')),
    
    gateway_invoice_id      TEXT, -- ID da fatura no Asaas
    gateway_invoice_url     TEXT, -- Link do PDF da fatura/boleto
    gateway_pix_qr_code     TEXT, -- Base64 ou string do QR Code Pix
    gateway_pix_copia_cola  TEXT, -- Chave Pix Copia e Cola
    
    data_pagamento          TIMESTAMPTZ,
    created_at              TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at              TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE (acordo_id, numero_parcela)
);

-- 1.3. Tabela de Vínculo com Faturamentos Originais
CREATE TABLE IF NOT EXISTS public.financeiro_acordo_faturamentos (
    acordo_id               UUID        REFERENCES public.financeiro_acordos(id) ON DELETE CASCADE,
    faturamento_id          UUID        REFERENCES public.faturamentos(id) ON DELETE RESTRICT,
    PRIMARY KEY (acordo_id, faturamento_id)
);

-- 1.4. Audit Log Imutável (Ledger Contábil)
CREATE TABLE IF NOT EXISTS public.financeiro_acordos_audit_log (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    acordo_id               UUID        REFERENCES public.financeiro_acordos(id) ON DELETE SET NULL,
    condominio_id           UUID        REFERENCES public.condominios(id) ON DELETE SET NULL,
    perfil_id               UUID        REFERENCES public.perfil(id) ON DELETE SET NULL,
    acao                    TEXT        NOT NULL, -- 'simulado', 'assinado', 'pagamento_parcela', 'unidade_desbloqueada', 'acordo_quebrado'
    dados                   JSONB       DEFAULT '{}'::jsonb,
    ip_address              INET,
    user_agent              TEXT,
    created_at              TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.financeiro_acordos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financeiro_acordo_parcelas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financeiro_acordo_faturamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financeiro_acordos_audit_log ENABLE ROW LEVEL SECURITY;

-- 1.5. RLS Policies

-- financeiro_acordos
CREATE POLICY "Moradores podem ver seus próprios acordos" ON public.financeiro_acordos
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.unidade_perfil up
            WHERE up.perfil_id = auth.uid()
              AND up.unidade_id = financeiro_acordos.unidade_id
        )
    );

CREATE POLICY "Moradores podem criar seus próprios acordos" ON public.financeiro_acordos
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.unidade_perfil up
            WHERE up.perfil_id = auth.uid()
              AND up.unidade_id = financeiro_acordos.unidade_id
        )
        AND perfil_id = auth.uid()
        AND status = 'pendente'
    );

CREATE POLICY "Moradores podem atualizar acordos pendentes para assinar" ON public.financeiro_acordos
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.unidade_perfil up
            WHERE up.perfil_id = auth.uid()
              AND up.unidade_id = financeiro_acordos.unidade_id
        )
        AND status = 'pendente'
    )
    WITH CHECK (
        status IN ('pendente', 'ativo')
    );

CREATE POLICY "Admins têm controle total sobre acordos do condomínio" ON public.financeiro_acordos
    FOR ALL TO authenticated
    USING (is_admin_of_condo(condominio_id));

-- financeiro_acordo_parcelas
CREATE POLICY "Moradores podem ver parcelas dos seus acordos" ON public.financeiro_acordo_parcelas
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.financeiro_acordos a
            JOIN public.unidade_perfil up ON up.unidade_id = a.unidade_id
            WHERE a.id = financeiro_acordo_parcelas.acordo_id
              AND up.perfil_id = auth.uid()
        )
    );

CREATE POLICY "Admins têm controle total sobre parcelas" ON public.financeiro_acordo_parcelas
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.financeiro_acordos a
            WHERE a.id = financeiro_acordo_parcelas.acordo_id
              AND is_admin_of_condo(a.condominio_id)
        )
    );

-- financeiro_acordo_faturamentos
CREATE POLICY "Moradores podem ver faturamentos dos seus acordos" ON public.financeiro_acordo_faturamentos
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.financeiro_acordos a
            JOIN public.unidade_perfil up ON up.unidade_id = a.unidade_id
            WHERE a.id = financeiro_acordo_faturamentos.acordo_id
              AND up.perfil_id = auth.uid()
        )
    );

CREATE POLICY "Moradores podem inserir faturamentos dos seus acordos" ON public.financeiro_acordo_faturamentos
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.financeiro_acordos a
            JOIN public.unidade_perfil up ON up.unidade_id = a.unidade_id
            WHERE a.id = financeiro_acordo_faturamentos.acordo_id
              AND up.perfil_id = auth.uid()
        )
    );

CREATE POLICY "Admins têm controle total sobre faturamentos de acordos" ON public.financeiro_acordo_faturamentos
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.financeiro_acordos a
            WHERE a.id = financeiro_acordo_faturamentos.acordo_id
              AND is_admin_of_condo(a.condominio_id)
        )
    );

-- financeiro_acordos_audit_log (MUTABLE=FALSE, append-only)
CREATE POLICY "Admins podem ler audit logs" ON public.financeiro_acordos_audit_log
    FOR SELECT TO authenticated
    USING (is_admin_of_condo(condominio_id));

CREATE POLICY "Moradores podem ler seus próprios audit logs" ON public.financeiro_acordos_audit_log
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.unidade_perfil up
            WHERE up.perfil_id = auth.uid()
              AND up.unidade_id = (
                  SELECT unidade_id FROM public.financeiro_acordos a 
                  WHERE a.id = financeiro_acordos_audit_log.acordo_id
              )
        )
    );

-- 1.6. Triggers para updated_at e PowerSync
CREATE TRIGGER set_updated_at_financeiro_acordos BEFORE UPDATE ON public.financeiro_acordos FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_financeiro_acordo_parcelas BEFORE UPDATE ON public.financeiro_acordo_parcelas FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

-- ═══════════════════════════════════════════════════════════
--  2. Dashboard Multi-condomínio RPC
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_consolidated_condo_metrics(condo_ids UUID[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Verifica se o usuário autenticado tem permissão de administração para TODOS os condo_ids solicitados
  IF EXISTS (
    SELECT 1 FROM unnest(condo_ids) AS cid
    WHERE NOT is_admin_of_condo(cid)
  ) THEN
    RAISE EXCEPTION 'Acesso negado para um ou mais condomínios solicitados.';
  END IF;

  SELECT json_build_object(
    'timestamp', now(),
    'metrics', (
      SELECT json_agg(
        json_build_object(
          'condominio_id', c.id,
          'nome', c.nome,
          'total_unidades', (SELECT COUNT(*) FROM public.unidades WHERE condominio_id = c.id),
          'inadimplencia_valor', COALESCE((SELECT SUM(valor_total) FROM public.faturamentos WHERE condominio_id = c.id AND status_pagamento = 'vencido'), 0.00),
          'encomendas_pendentes', (SELECT COUNT(*) FROM public.encomendas WHERE condominio_id = c.id AND status = 'pending'),
          'sos_ativos', (SELECT COUNT(*) FROM public.sos_alertas WHERE condominium_id = c.id AND status = 'active')
        )
      )
      FROM public.condominios c
      WHERE c.id = ANY(condo_ids)
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;

-- ═══════════════════════════════════════════════════════════
--  3. Assembleias Paperless Checks & View
-- ═══════════════════════════════════════════════════════════

-- 3.1. Elegibilidade Eleitoral Check Function
CREATE OR REPLACE FUNCTION public.check_vote_eligibility()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_bloqueada boolean;
  v_status_assembleia text;
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

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_vote_eligibility ON public.assembleia_votos;
CREATE TRIGGER trg_check_vote_eligibility
  BEFORE INSERT OR UPDATE ON public.assembleia_votos
  FOR EACH ROW EXECUTE FUNCTION public.check_vote_eligibility();

-- 3.2. View de Contagem de Votos Secreta
CREATE OR REPLACE VIEW public.view_assembleia_votos_agregados AS
SELECT 
  v.assembleia_id,
  v.pauta_id,
  v.voto,
  COUNT(*) as total_votos,
  SUM(v.peso_aplicado) as total_peso
FROM public.assembleia_votos v
GROUP BY v.assembleia_id, v.pauta_id, v.voto;

-- ═══════════════════════════════════════════════════════════
--  4. Liberação de Visitantes Express via WhatsApp
-- ═══════════════════════════════════════════════════════════

ALTER TABLE public.visitante_registros 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'liberado' CHECK (status IN ('aguardando_aprovacao', 'liberado', 'rejeitado')),
ADD COLUMN IF NOT EXISTS aprovado_por UUID REFERENCES public.perfil(id),
ADD COLUMN IF NOT EXISTS aprovado_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS canal_liberacao TEXT DEFAULT 'manual_portaria' CHECK (canal_liberacao IN ('app', 'whatsapp', 'manual_portaria'));

-- ═══════════════════════════════════════════════════════════
--  5. PowerSync Publication Updates
-- ═══════════════════════════════════════════════════════════

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'powersync'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables
            WHERE pubname = 'powersync' AND schemaname = 'public' AND tablename = 'financeiro_acordos'
        ) THEN
            ALTER PUBLICATION powersync ADD TABLE public.financeiro_acordos;
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables
            WHERE pubname = 'powersync' AND schemaname = 'public' AND tablename = 'financeiro_acordo_parcelas'
        ) THEN
            ALTER PUBLICATION powersync ADD TABLE public.financeiro_acordo_parcelas;
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables
            WHERE pubname = 'powersync' AND schemaname = 'public' AND tablename = 'financeiro_acordo_faturamentos'
        ) THEN
            ALTER PUBLICATION powersync ADD TABLE public.financeiro_acordo_faturamentos;
        END IF;
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════
--  6. Trigger handle_after_parcela_paga
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_after_parcela_paga()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_acordo RECORD;
  v_faturamento RECORD;
BEGIN
  IF NEW.status = 'pago' AND OLD.status != 'pago' THEN
    SELECT * INTO v_acordo FROM public.financeiro_acordos WHERE id = NEW.acordo_id;
    IF NOT FOUND THEN
      RETURN NEW;
    END IF;

    IF NEW.numero_parcela = 1 THEN
      UPDATE public.financeiro_acordos 
      SET status = 'ativo', 
          updated_at = NOW() 
      WHERE id = v_acordo.id;

      UPDATE public.unidades 
      SET bloqueada_assembleia = false, 
          updated_at = NOW() 
      WHERE id = v_acordo.unidade_id;

      FOR v_faturamento IN 
        SELECT faturamento_id 
        FROM public.financeiro_acordo_faturamentos 
        WHERE acordo_id = v_acordo.id
      LOOP
        UPDATE public.faturamentos 
        SET status_pagamento = 'cancelado', 
            updated_at = NOW() 
        WHERE id = v_faturamento.faturamento_id;
      END LOOP;

      INSERT INTO public.financeiro_acordos_audit_log (
        acordo_id,
        condominio_id,
        perfil_id,
        acao,
        dados,
        created_at
      ) VALUES (
        v_acordo.id,
        v_acordo.condominio_id,
        v_acordo.perfil_id,
        'unidade_desbloqueada',
        jsonb_build_object(
          'parcela_id', NEW.id,
          'numero_parcela', NEW.numero_parcela,
          'valor_pago', NEW.valor
        ),
        NOW()
      );
    ELSE
      INSERT INTO public.financeiro_acordos_audit_log (
        acordo_id,
        condominio_id,
        perfil_id,
        acao,
        dados,
        created_at
      ) VALUES (
        v_acordo.id,
        v_acordo.condominio_id,
        v_acordo.perfil_id,
        'pagamento_parcela',
        jsonb_build_object(
          'parcela_id', NEW.id,
          'numero_parcela', NEW.numero_parcela,
          'valor_pago', NEW.valor
        ),
        NOW()
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.financeiro_acordo_parcelas 
      WHERE acordo_id = v_acordo.id AND status != 'pago'
    ) THEN
      UPDATE public.financeiro_acordos 
      SET status = 'finalizado', 
          updated_at = NOW() 
      WHERE id = v_acordo.id;

      INSERT INTO public.financeiro_acordos_audit_log (
        acordo_id,
        condominio_id,
        perfil_id,
        acao,
        dados,
        created_at
      ) VALUES (
        v_acordo.id,
        v_acordo.condominio_id,
        v_acordo.perfil_id,
        'finalizado',
        jsonb_build_object(
          'mensagem', 'Todas as parcelas do acordo foram pagas'
        ),
        NOW()
      );
    END IF;

  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_after_parcela_paga ON public.financeiro_acordo_parcelas;
CREATE TRIGGER trg_after_parcela_paga
  AFTER UPDATE ON public.financeiro_acordo_parcelas
  FOR EACH ROW EXECUTE FUNCTION public.handle_after_parcela_paga();
