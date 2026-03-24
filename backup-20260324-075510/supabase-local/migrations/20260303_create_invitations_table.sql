-- Migration: 1.6 Create Invitations Table
-- Description: Tabela para gerenciar convites digitais de visitantes.

CREATE TABLE IF NOT EXISTS public.invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resident_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    condominium_id UUID NOT NULL REFERENCES public.condominiums(id) ON DELETE CASCADE,
    guest_name TEXT NOT NULL,
    validity_date TIMESTAMPTZ NOT NULL,
    qr_data TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'expired')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
CREATE POLICY "Residentes podem ver seus próprios convites"
ON public.invitations FOR SELECT
USING (auth.uid() = resident_id);

CREATE POLICY "Residentes podem criar convites"
ON public.invitations FOR INSERT
WITH CHECK (auth.uid() = resident_id);

CREATE POLICY "Porteiros e Síndicos podem ver todos os convites do condomínio"
ON public.invitations FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND condominium_id = invitations.condominium_id
        AND role IN ('porter', 'admin', 'syndic')
    )
);

CREATE POLICY "Porteiros podem marcar convites como usados"
ON public.invitations FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND condominium_id = invitations.condominium_id
        AND role IN ('porter', 'admin', 'syndic')
    )
)
WITH CHECK (status = 'used');

-- Gatilho para updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER tr_invitations_updated_at
    BEFORE UPDATE ON public.invitations
    FOR EACH ROW
    EXECUTE PROCEDURE public.handle_updated_at();

-- Comentário para o Dashboard
COMMENT ON TABLE public.invitations IS 'Convites digitais gerados por moradores para acesso de visitantes.';
