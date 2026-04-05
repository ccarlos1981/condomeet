-- ============================================================
-- Migration: 20260405121936_assembleia_live_dashboard
-- Setup for Live Dashboard Features (Websockets, Statuses)
-- ============================================================

-- 1. Add status column to assembleia_pautas to manage poll states in real-time
ALTER TABLE public.assembleia_pautas 
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'fechada'; -- fechada | aberta | encerrada

-- 2. Add REALTIME to Assembly tables
-- Assumes publication "supabase_realtime" exists (Supabase default)

ALTER PUBLICATION supabase_realtime ADD TABLE assembleias;
ALTER PUBLICATION supabase_realtime ADD TABLE assembleia_pautas;
ALTER PUBLICATION supabase_realtime ADD TABLE assembleia_votos;
ALTER PUBLICATION supabase_realtime ADD TABLE assembleia_chat;
ALTER PUBLICATION supabase_realtime ADD TABLE assembleia_presencas;
