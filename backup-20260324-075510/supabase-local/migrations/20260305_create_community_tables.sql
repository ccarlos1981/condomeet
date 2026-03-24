-- Create Common Areas table
CREATE TABLE public.common_areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominium_id UUID NOT NULL REFERENCES public.condominiums(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    icon_path TEXT,
    capacity INTEGER,
    rules TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create Area Bookings table
CREATE TABLE public.area_bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominium_id UUID NOT NULL REFERENCES public.condominiums(id) ON DELETE CASCADE,
    area_id UUID NOT NULL REFERENCES public.common_areas(id) ON DELETE CASCADE,
    resident_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    booking_date DATE NOT NULL,
    status TEXT DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create Documents table
CREATE TABLE public.documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominium_id UUID NOT NULL REFERENCES public.condominiums(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('minutes', 'regulations', 'forms', 'others')),
    file_url TEXT NOT NULL,
    file_extension TEXT NOT NULL,
    upload_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.common_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.area_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

-- RLS Policies for common_areas
CREATE POLICY "Common areas are visible to everyone in the same condo" ON public.common_areas
    FOR SELECT USING (
        condominium_id IN (
            SELECT condominium_id FROM public.profiles WHERE id = auth.uid()
        )
    );

-- RLS Policies for area_bookings
CREATE POLICY "Residents can view bookings in their condo" ON public.area_bookings
    FOR SELECT USING (
        condominium_id IN (
            SELECT condominium_id FROM public.profiles WHERE id = auth.uid()
        )
    );

CREATE POLICY "Residents can create their own bookings" ON public.area_bookings
    FOR INSERT WITH CHECK (
        auth.uid() = resident_id AND
        condominium_id IN (
            SELECT condominium_id FROM public.profiles WHERE id = auth.uid()
        )
    );

CREATE POLICY "Residents can cancel their own bookings" ON public.area_bookings
    FOR UPDATE USING (auth.uid() = resident_id);

-- RLS Policies for documents
CREATE POLICY "Documents are visible to everyone in the same condo" ON public.documents
    FOR SELECT USING (
        condominium_id IN (
            SELECT condominium_id FROM public.profiles WHERE id = auth.uid()
        )
    );

-- PowerSync updated_at triggers
CREATE TRIGGER set_updated_at_common_areas
BEFORE UPDATE ON public.common_areas
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_area_bookings
BEFORE UPDATE ON public.area_bookings
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_documents
BEFORE UPDATE ON public.documents
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Add to PowerSync publication (Assuming publication name is 'powersync')
-- ALTER PUBLICATION powersync ADD TABLE public.common_areas, public.area_bookings, public.documents;
