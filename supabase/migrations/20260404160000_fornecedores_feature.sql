-- Migration: Create Fornecedores table

CREATE TABLE IF NOT EXISTS public.fornecedores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID REFERENCES public.condominios(id) ON DELETE CASCADE NOT NULL,
    tipo TEXT NOT NULL CHECK (tipo IN ('Pessoa Física', 'Pessoa Jurídica')),
    documento TEXT,
    nome TEXT NOT NULL,
    telefone TEXT,
    observacoes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.fornecedores ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Only admins/sindicos of the condo can view/edit/delete/insert
CREATE POLICY "Admins can view fornecedores" 
ON public.fornecedores FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM perfil
        WHERE perfil.id = auth.uid()
        AND perfil.condominio_id = fornecedores.condominio_id
        AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')
    )
);

CREATE POLICY "Admins can insert fornecedores" 
ON public.fornecedores FOR INSERT 
WITH CHECK (
    EXISTS (
        SELECT 1 FROM perfil
        WHERE perfil.id = auth.uid()
        AND perfil.condominio_id = fornecedores.condominio_id
        AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')
    )
);

CREATE POLICY "Admins can update fornecedores" 
ON public.fornecedores FOR UPDATE 
USING (
    EXISTS (
        SELECT 1 FROM perfil
        WHERE perfil.id = auth.uid()
        AND perfil.condominio_id = fornecedores.condominio_id
        AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')
    )
);

CREATE POLICY "Admins can delete fornecedores" 
ON public.fornecedores FOR DELETE 
USING (
    EXISTS (
        SELECT 1 FROM perfil
        WHERE perfil.id = auth.uid()
        AND perfil.condominio_id = fornecedores.condominio_id
        AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')
    )
);

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_fornecedores
    BEFORE UPDATE ON public.fornecedores
    FOR EACH ROW
    EXECUTE FUNCTION handle_updated_at();
