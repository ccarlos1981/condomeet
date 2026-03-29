-- Retira as Foreign Keys antigas que apontavam pro auth.users
ALTER TABLE garages DROP CONSTRAINT IF EXISTS garages_owner_id_fkey;
ALTER TABLE garage_reservations DROP CONSTRAINT IF EXISTS garage_reservations_user_id_fkey;
ALTER TABLE garage_reviews DROP CONSTRAINT IF EXISTS garage_reviews_reviewer_id_fkey;
ALTER TABLE garage_earnings DROP CONSTRAINT IF EXISTS garage_earnings_owner_id_fkey;

-- Recria apontando para o perfil (necessário pro Flutter conseguir buscar a fotinha do morador!)
ALTER TABLE garages ADD CONSTRAINT garages_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.perfil(id) ON DELETE CASCADE;
ALTER TABLE garage_reservations ADD CONSTRAINT garage_reservations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.perfil(id) ON DELETE CASCADE;
ALTER TABLE garage_reviews ADD CONSTRAINT garage_reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.perfil(id) ON DELETE CASCADE;
ALTER TABLE garage_earnings ADD CONSTRAINT garage_earnings_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.perfil(id) ON DELETE CASCADE;
