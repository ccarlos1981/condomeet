-- Migration: 20260830_create_app_version_policy.sql
-- Descrição: Cria tabela de política permanente de atualização obrigatória (Force Update)

CREATE TABLE IF NOT EXISTS public.app_version_policy (
  id INTEGER PRIMARY KEY DEFAULT 1,
  min_android_build INTEGER NOT NULL DEFAULT 101,
  min_ios_build INTEGER NOT NULL DEFAULT 101,
  latest_android_version TEXT NOT NULL DEFAULT '3.9.3',
  latest_ios_version TEXT NOT NULL DEFAULT '3.9.3',
  force_update_title TEXT NOT NULL DEFAULT 'Atualização Necessária',
  force_update_message TEXT NOT NULL DEFAULT 'Uma nova versão do Condomeet está disponível com melhorias essenciais de estabilidade e segurança. Atualize para continuar.',
  store_url_android TEXT NOT NULL DEFAULT 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
  store_url_ios TEXT NOT NULL DEFAULT 'https://apps.apple.com/app/condomeet/id6740927806',
  is_kill_switch_active BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by TEXT,
  CONSTRAINT single_row_policy CHECK (id = 1),
  CONSTRAINT valid_android_build CHECK (min_android_build BETWEEN 1 AND 50000),
  CONSTRAINT valid_ios_build CHECK (min_ios_build BETWEEN 1 AND 50000)
);

-- Habilitar RLS
ALTER TABLE public.app_version_policy ENABLE ROW LEVEL SECURITY;

-- Política de Leitura Pública (Anon e Authenticated podem consultar a política da versão)
DROP POLICY IF EXISTS "app_version_policy_select_public" ON public.app_version_policy;
CREATE POLICY "app_version_policy_select_public"
  ON public.app_version_policy
  FOR SELECT
  TO public, anon, authenticated
  USING (true);

-- Política de Escrita Restrita (Somente SuperAdmin corporativo pode alterar)
DROP POLICY IF EXISTS "app_version_policy_update_superadmin" ON public.app_version_policy;
CREATE POLICY "app_version_policy_update_superadmin"
  ON public.app_version_policy
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.system_superadmins
      WHERE system_superadmins.email = (auth.jwt() ->> 'email')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.system_superadmins
      WHERE system_superadmins.email = (auth.jwt() ->> 'email')
    )
  );

-- Inserir registro inicial seguro com baseline min_build = 101 (sem bloqueios)
INSERT INTO public.app_version_policy (
  id,
  min_android_build,
  min_ios_build,
  latest_android_version,
  latest_ios_version,
  force_update_title,
  force_update_message,
  store_url_android,
  store_url_ios,
  is_kill_switch_active,
  updated_at,
  updated_by
) VALUES (
  1,
  101,
  101,
  '3.9.3',
  '3.9.3',
  'Atualização Necessária',
  'Uma nova versão do Condomeet está disponível com melhorias essenciais de estabilidade e segurança. Atualize para continuar.',
  'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
  'https://apps.apple.com/app/condomeet/id6740927806',
  false,
  now(),
  'system_initialization'
) ON CONFLICT (id) DO NOTHING;
