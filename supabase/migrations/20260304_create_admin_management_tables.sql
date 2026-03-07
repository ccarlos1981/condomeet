-- Inventory Management
CREATE TABLE IF NOT EXISTS public.inventory_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominium_id UUID NOT NULL REFERENCES public.condominiums(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT, -- e.g., 'Cleaning', 'Tools', 'Maintenance'
    current_quantity INTEGER NOT NULL DEFAULT 0,
    min_quantity INTEGER DEFAULT 0, -- For alerts
    is_consumable BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on inventory_items
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view inventory in their condominium" ON public.inventory_items
    FOR SELECT USING (auth.uid() IN (
        SELECT id FROM public.profiles WHERE condominium_id = inventory_items.condominium_id
    ));

CREATE POLICY "Admins can manage inventory" ON public.inventory_items
    FOR ALL USING (auth.uid() IN (
        SELECT id FROM public.profiles WHERE condominium_id = inventory_items.condominium_id AND role IN ('admin', 'porter')
    ));

CREATE TABLE IF NOT EXISTS public.inventory_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
    resident_id UUID REFERENCES public.profiles(id), -- If a resident/staff borrowed it
    transaction_type TEXT NOT NULL, -- 'in', 'out_permanent', 'out_temporary', 'return'
    quantity INTEGER NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on inventory_transactions
ALTER TABLE public.inventory_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view transactions in their condominium" ON public.inventory_transactions
    FOR SELECT USING (auth.uid() IN (
        SELECT p.id FROM public.profiles p
        JOIN public.inventory_items i ON i.id = inventory_transactions.item_id
        WHERE p.condominium_id = i.condominium_id
    ));

CREATE POLICY "Admins can manage transactions" ON public.inventory_transactions
    FOR ALL USING (auth.uid() IN (
        SELECT p.id FROM public.profiles p
        JOIN public.inventory_items i ON i.id = inventory_transactions.item_id
        WHERE p.condominium_id = i.condominium_id AND p.role IN ('admin', 'porter')
    ));

-- Assemblies
CREATE TABLE IF NOT EXISTS public.assemblies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominium_id UUID NOT NULL REFERENCES public.condominiums(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft', -- 'draft', 'active', 'closed'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on assemblies
ALTER TABLE public.assemblies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view assemblies in their condominium" ON public.assemblies
    FOR SELECT USING (auth.uid() IN (
        SELECT id FROM public.profiles WHERE condominium_id = assemblies.condominium_id
    ));

CREATE POLICY "Admins can manage assemblies" ON public.assemblies
    FOR ALL USING (auth.uid() IN (
        SELECT id FROM public.profiles WHERE condominium_id = assemblies.condominium_id AND role = 'admin'
    ));

CREATE TABLE IF NOT EXISTS public.assembly_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assembly_id UUID NOT NULL REFERENCES public.assemblies(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on assembly_options
ALTER TABLE public.assembly_options ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view options for assemblies" ON public.assembly_options
    FOR SELECT USING (auth.uid() IN (
        SELECT p.id FROM public.profiles p
        JOIN public.assemblies a ON a.id = assembly_options.assembly_id
        WHERE p.condominium_id = a.condominium_id
    ));

CREATE POLICY "Admins can manage options" ON public.assembly_options
    FOR ALL USING (auth.uid() IN (
        SELECT p.id FROM public.profiles p
        JOIN public.assemblies a ON a.id = assembly_options.assembly_id
        WHERE p.condominium_id = a.condominium_id AND p.role = 'admin'
    ));

CREATE TABLE IF NOT EXISTS public.assembly_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assembly_id UUID NOT NULL REFERENCES public.assemblies(id) ON DELETE CASCADE,
    option_id UUID NOT NULL REFERENCES public.assembly_options(id) ON DELETE CASCADE,
    resident_id UUID NOT NULL REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(assembly_id, resident_id) -- One vote per assembly per resident
);

-- Enable RLS on assembly_votes
ALTER TABLE public.assembly_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view votes in their assemblies" ON public.assembly_votes
    FOR SELECT USING (auth.uid() IN (
        SELECT p.id FROM public.profiles p
        JOIN public.assemblies a ON a.id = assembly_votes.assembly_id
        WHERE p.condominium_id = a.condominium_id
    ));

CREATE POLICY "Users can cast votes in their assemblies" ON public.assembly_votes
    FOR INSERT WITH CHECK (auth.uid() = resident_id AND auth.uid() IN (
        SELECT p.id FROM public.profiles p
        JOIN public.assemblies a ON a.id = assembly_votes.assembly_id
        WHERE p.condominium_id = a.condominium_id AND a.status = 'active'
    ));
