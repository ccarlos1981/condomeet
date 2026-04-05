-- =====================================================================================
-- Migration: Support Chat (Suporte Sistema)
-- Description: Creates tables for global admin support chat, similar to WhatsApp Web.
-- =====================================================================================

-- 1. Create the chats table (one row per user who opens a support chat)
CREATE TABLE IF NOT EXISTS public.suporte_sistema_chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resident_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE UNIQUE,
    condominio_id UUID REFERENCES public.condominios(id) ON DELETE CASCADE,
    last_message TEXT,
    unread_user INT DEFAULT 0,
    unread_admin INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.suporte_sistema_chats ENABLE ROW LEVEL SECURITY;

-- 2. Create the messages table (stores the actual chat lines)
CREATE TABLE IF NOT EXISTS public.suporte_sistema_mensagens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID NOT NULL REFERENCES public.suporte_sistema_chats(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
    is_admin BOOLEAN NOT NULL DEFAULT false,
    texto TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.suporte_sistema_mensagens ENABLE ROW LEVEL SECURITY;

-- 3. Create a function to check if the current user is a superadmin
-- We define a superadmin based on specific emails: cristiano.santos@gmx.com or erikaosc@gmail.com
-- This looks at auth.users implicitly by fetching their email using auth.jwt()
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT (auth.jwt() ->> 'email' = 'cristiano.santos@gmx.com') 
      OR (auth.jwt() ->> 'email' = 'erikaosc@gmail.com');
$$;

-- 4. Set up Policies for `suporte_sistema_chats`

-- Residents can see their own chat
CREATE POLICY "Residents can view their own chat" 
ON public.suporte_sistema_chats 
FOR SELECT 
USING (resident_id = auth.uid() OR is_super_admin());

-- Residents can insert their own chat if it doesn't exist
CREATE POLICY "Residents can insert their own chat" 
ON public.suporte_sistema_chats 
FOR INSERT 
WITH CHECK (resident_id = auth.uid() OR is_super_admin());

-- Residents can update their own chat (e.g. mark as read)
CREATE POLICY "Residents can update their own chat" 
ON public.suporte_sistema_chats 
FOR UPDATE 
USING (resident_id = auth.uid() OR is_super_admin());

-- SuperAdmins have ALL access
CREATE POLICY "SuperAdmins have full access to chats" 
ON public.suporte_sistema_chats 
FOR ALL 
USING (is_super_admin());

-- 5. Set up Policies for `suporte_sistema_mensagens`

-- Residents can read messages from their chat and insert into it
CREATE POLICY "Residents can view messages in their chat" 
ON public.suporte_sistema_mensagens 
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.suporte_sistema_chats c 
    WHERE c.id = suporte_sistema_mensagens.chat_id AND (c.resident_id = auth.uid() OR is_super_admin())
  )
);

CREATE POLICY "Residents can insert messages" 
ON public.suporte_sistema_mensagens 
FOR INSERT 
WITH CHECK (
  sender_id = auth.uid() AND 
  EXISTS (
    SELECT 1 FROM public.suporte_sistema_chats c 
    WHERE c.id = chat_id AND (c.resident_id = auth.uid() OR is_super_admin())
  )
);

-- SuperAdmins have ALL access
CREATE POLICY "SuperAdmins have full access to messages" 
ON public.suporte_sistema_mensagens 
FOR ALL 
USING (is_super_admin());


-- 6. Trigger to automatically update the `last_message` and `updated_at` on the `chats` table.
CREATE OR REPLACE FUNCTION public.suporte_sistema_update_chat_trigger()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.suporte_sistema_chats
  SET 
    last_message = NEW.texto,
    updated_at = now(),
    -- Increment unread based on who sent it
    unread_admin = CASE WHEN NEW.is_admin = false THEN unread_admin + 1 ELSE unread_admin END,
    unread_user = CASE WHEN NEW.is_admin = true THEN unread_user + 1 ELSE unread_user END
  WHERE id = NEW.chat_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_suporte_sistema_mensagem_inserted ON public.suporte_sistema_mensagens;
CREATE TRIGGER trg_suporte_sistema_mensagem_inserted
AFTER INSERT ON public.suporte_sistema_mensagens
FOR EACH ROW EXECUTE PROCEDURE public.suporte_sistema_update_chat_trigger();

-- Add Realtime support for these tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.suporte_sistema_chats;
ALTER PUBLICATION supabase_realtime ADD TABLE public.suporte_sistema_mensagens;
