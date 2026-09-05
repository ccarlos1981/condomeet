-- ============================================================================
-- MIGRATION: FASE 4.3 — TABELA DE IDEMPOTÊNCIA DE ALERTAS DE CONTRATOS
-- Data: 26/08/2026
-- Objetivo: Garantir idempotência estrita (anti-spam) para notificações
--           de vencimento de contratos enviadas aos administradores.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.contrato_notificacoes_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  contrato_id UUID NOT NULL REFERENCES public.contratos(id) ON DELETE CASCADE,
  tipo_alerta TEXT NOT NULL, -- '90_DIAS', '30_DIAS', 'VENCE_HOJE', 'VENCIDO'
  data_referencia DATE NOT NULL,
  destinatario_id UUID REFERENCES public.perfil(id) ON DELETE CASCADE,
  enviado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_contrato_alerta_destinatario UNIQUE (contrato_id, tipo_alerta, data_referencia, destinatario_id)
);

CREATE INDEX IF NOT EXISTS idx_contrato_notif_lookup 
  ON public.contrato_notificacoes_log(contrato_id, tipo_alerta, data_referencia);

CREATE INDEX IF NOT EXISTS idx_contrato_notif_condo 
  ON public.contrato_notificacoes_log(condominio_id);

-- RLS
ALTER TABLE public.contrato_notificacoes_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "contrato_notif_admin_select" ON public.contrato_notificacoes_log
  FOR SELECT TO authenticated
  USING (public.is_admin_of_condo(condominio_id));
