-- Migration: Fale com o Síndico
-- Feature de chat direto entre morador e síndico/administração
-- Completamente separada de ocorrências

-- =============================================
-- 1. TABELA DE THREADS (uma por assunto/conversa)
-- =============================================
CREATE TABLE IF NOT EXISTS public.fale_sindico_threads (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id   UUID        NOT NULL REFERENCES public.condominios(id) ON DELETE CASCADE,
  resident_id     UUID        NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
  tipo            TEXT        NOT NULL CHECK (tipo IN ('reclamacao', 'elogio', 'pendencia', 'sugestao', 'duvida')),
  assunto         TEXT        NOT NULL,
  status          TEXT        NOT NULL DEFAULT 'aberto' CHECK (status IN ('aberto', 'respondido', 'fechado')),
  ultima_mensagem_em TIMESTAMPTZ DEFAULT now() NOT NULL,
  created_at      TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- =============================================
-- 2. TABELA DE MENSAGENS (cada mensagem do chat)
-- =============================================
CREATE TABLE IF NOT EXISTS public.fale_sindico_mensagens (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id   UUID        NOT NULL REFERENCES public.fale_sindico_threads(id) ON DELETE CASCADE,
  sender_id   UUID        NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
  is_admin    BOOLEAN     NOT NULL DEFAULT false,
  texto       TEXT        NOT NULL,
  arquivo_url TEXT,
  created_at  TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- =============================================
-- 3. ÍNDICES PARA PERFORMANCE
-- =============================================
CREATE INDEX IF NOT EXISTS idx_fs_threads_condominio  ON public.fale_sindico_threads(condominio_id);
CREATE INDEX IF NOT EXISTS idx_fs_threads_resident    ON public.fale_sindico_threads(resident_id);
CREATE INDEX IF NOT EXISTS idx_fs_threads_status      ON public.fale_sindico_threads(status);
CREATE INDEX IF NOT EXISTS idx_fs_mensagens_thread    ON public.fale_sindico_mensagens(thread_id);
CREATE INDEX IF NOT EXISTS idx_fs_mensagens_created   ON public.fale_sindico_mensagens(created_at);

-- =============================================
-- 4. ROW LEVEL SECURITY
-- =============================================
ALTER TABLE public.fale_sindico_threads   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fale_sindico_mensagens ENABLE ROW LEVEL SECURITY;

-- THREADS: Morador vê apenas suas threads
CREATE POLICY "morador_ve_proprias_threads" ON public.fale_sindico_threads
  FOR SELECT
  USING (resident_id = auth.uid());

-- THREADS: Admin/Síndico vê todas do condomínio
CREATE POLICY "admin_ve_threads_condo" ON public.fale_sindico_threads
  FOR SELECT
  USING (
    condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
    AND (
      (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid()) ILIKE '%sindico%'
      OR (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid()) ILIKE '%síndico%'
      OR (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid()) = 'ADMIN'
    )
  );

-- THREADS: Morador pode criar thread
CREATE POLICY "morador_cria_thread" ON public.fale_sindico_threads
  FOR INSERT
  WITH CHECK (resident_id = auth.uid());

-- THREADS: Admin pode atualizar status
CREATE POLICY "admin_atualiza_thread" ON public.fale_sindico_threads
  FOR UPDATE
  USING (
    (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid()) ILIKE '%sindico%'
    OR (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid()) ILIKE '%síndico%'
    OR (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid()) = 'ADMIN'
  );

-- MENSAGENS: Morador vê mensagens das suas threads
CREATE POLICY "morador_ve_proprias_mensagens" ON public.fale_sindico_mensagens
  FOR SELECT
  USING (
    thread_id IN (
      SELECT id FROM public.fale_sindico_threads WHERE resident_id = auth.uid()
    )
  );

-- MENSAGENS: Admin vê todas mensagens do seu condomínio
CREATE POLICY "admin_ve_mensagens_condo" ON public.fale_sindico_mensagens
  FOR SELECT
  USING (
    thread_id IN (
      SELECT t.id FROM public.fale_sindico_threads t
      WHERE t.condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
    )
    AND (
      (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid()) ILIKE '%sindico%'
      OR (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid()) ILIKE '%síndico%'
      OR (SELECT papel_sistema FROM public.perfil WHERE id = auth.uid()) = 'ADMIN'
    )
  );

-- MENSAGENS: Qualquer participante da thread pode enviar mensagem
CREATE POLICY "participante_envia_mensagem" ON public.fale_sindico_mensagens
  FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND (
      -- Morador enviando na sua thread
      thread_id IN (SELECT id FROM public.fale_sindico_threads WHERE resident_id = auth.uid())
      -- Admin enviando em thread do seu condo
      OR thread_id IN (
        SELECT t.id FROM public.fale_sindico_threads t
        WHERE t.condominio_id = (SELECT condominio_id FROM public.perfil WHERE id = auth.uid())
      )
    )
  );
