-- Allow any condo member to see reservations for their condo's areas
-- Purpose: calendar date blocking - non-sensitive (only dates, not who booked)
DROP POLICY IF EXISTS "resident_read_area_bookings" ON public.reservas;

CREATE POLICY "resident_read_area_bookings"
  ON public.reservas FOR SELECT
  USING (
    area_id IN (
      SELECT ac.id FROM public.areas_comuns ac
      JOIN public.perfil p ON p.condominio_id = ac.condominio_id
      WHERE p.id = auth.uid()
    )
  );
