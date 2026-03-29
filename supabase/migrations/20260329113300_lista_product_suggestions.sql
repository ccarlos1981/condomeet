-- Migration for Product Crowdsourcing (OCR Unmatched Items)
CREATE TABLE IF NOT EXISTS public.lista_product_suggestions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    supermarket_id UUID REFERENCES public.lista_supermarkets(id) ON DELETE SET NULL,
    raw_name TEXT NOT NULL,
    unit_price NUMERIC,
    total_price NUMERIC,
    quantity NUMERIC,
    status TEXT DEFAULT 'pending'::text,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS Policies
ALTER TABLE public.lista_product_suggestions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own suggestions"
    ON public.lista_product_suggestions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own suggestions"
    ON public.lista_product_suggestions FOR SELECT
    USING (auth.uid() = user_id);
