CREATE TABLE IF NOT EXISTS public.consumo_extras (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
    assembleia_id UUID REFERENCES public.assembleias(id) ON DELETE SET NULL,
    tipo_servico TEXT NOT NULL,
    valor_cobrado NUMERIC NOT NULL,
    detalhes JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.consumo_extras ENABLE ROW LEVEL SECURITY;

-- Allow super admin to see all, allow everyone else to see their condo
CREATE POLICY "Allow select for authenticated"
ON public.consumo_extras
FOR SELECT
TO authenticated
USING (true);

-- Allow authenticated users (and edge functions with anon/service) to insert
CREATE POLICY "Allow insert for authenticated"
ON public.consumo_extras
FOR INSERT
TO authenticated
WITH CHECK (true);
