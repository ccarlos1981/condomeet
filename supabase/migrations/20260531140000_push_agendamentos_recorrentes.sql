-- Migration: 20260531140000 - Push Notification Scheduler
-- Table: push_agendamentos_recorrentes

CREATE TABLE IF NOT EXISTS public.push_agendamentos_recorrentes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dia_semana TEXT NOT NULL CHECK (dia_semana IN ('seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom')),
  horario TIME NOT NULL, -- Format: HH:MM:SS
  assunto TEXT NOT NULL,
  mensagem TEXT NOT NULL,
  ativo BOOLEAN DEFAULT false NOT NULL,
  last_sent_at DATE, -- Prevents duplicate execution on same calendar date
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  condominio_id UUID REFERENCES public.condominios(id) ON DELETE CASCADE
);

-- Index and Unique constraints
CREATE UNIQUE INDEX IF NOT EXISTS idx_push_agendamentos_global 
  ON public.push_agendamentos_recorrentes (dia_semana) 
  WHERE condominio_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_push_agendamentos_condo 
  ON public.push_agendamentos_recorrentes (condominio_id, dia_semana) 
  WHERE condominio_id IS NOT NULL;

-- Enable RLS
ALTER TABLE public.push_agendamentos_recorrentes ENABLE ROW LEVEL SECURITY;

-- Policy: Authenticated users with Admin/Sindico role can view and manage scheduled pushes
CREATE POLICY "Admins can manage scheduled pushes" 
  ON public.push_agendamentos_recorrentes
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM perfil 
      WHERE perfil.id = auth.uid() 
        AND (perfil.papel_sistema ILIKE '%sindico%' OR perfil.papel_sistema ILIKE '%síndico%' OR perfil.papel_sistema ILIKE '%admin%')
    )
  );

-- Trigger to handle updated_at
CREATE TRIGGER set_updated_at_push_agendamentos_recorrentes 
  BEFORE UPDATE ON public.push_agendamentos_recorrentes 
  FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

-- Seed initial 7 days of the week for global pushes (condominio_id IS NULL)
INSERT INTO public.push_agendamentos_recorrentes (dia_semana, horario, assunto, mensagem, ativo) 
VALUES
  ('seg', '09:00:00', 'Mensagem de Segunda-feira', 'Que tenhamos uma ótima e produtiva semana!', false),
  ('ter', '09:00:00', 'Mensagem de Terça-feira', 'Tenha uma ótima terça-feira!', false),
  ('qua', '09:00:00', 'Mensagem de Quarta-feira', 'Tenha uma excelente quarta-feira!', false),
  ('qui', '09:00:00', 'Mensagem de Quinta-feira', 'Tenha uma ótima quinta-feira!', false),
  ('sex', '09:00:00', 'Mensagem de Sexta-feira', 'Sextou! Um excelente final de semana para todos!', false),
  ('sab', '09:00:00', 'Mensagem de Sábado', 'Desejamos a todos um ótimo sábado!', false),
  ('dom', '09:00:00', 'Mensagem de Domingo', 'Desejamos a todos um ótimo domingo!', false)
ON CONFLICT DO NOTHING;
