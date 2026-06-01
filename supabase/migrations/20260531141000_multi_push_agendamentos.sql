-- Migration: 20260531141000 - Multi-push recurrent schedule support
-- Drop old unique constraints that allowed only one push per day of week
DROP INDEX IF EXISTS public.idx_push_agendamentos_global;
DROP INDEX IF EXISTS public.idx_push_agendamentos_condo;

-- Create new unique constraints including the 'horario' field, allowing multiple pushes per day
CREATE UNIQUE INDEX IF NOT EXISTS idx_push_agendamentos_global_time 
  ON public.push_agendamentos_recorrentes (dia_semana, horario) 
  WHERE condominio_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_push_agendamentos_condo_time 
  ON public.push_agendamentos_recorrentes (condominio_id, dia_semana, horario) 
  WHERE condominio_id IS NOT NULL;
