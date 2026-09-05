-- Create table for storing Meta Whatsapp Templates locally
CREATE TABLE IF NOT EXISTS public.whatsapp_meta_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  meta_template_id TEXT UNIQUE,
  name TEXT NOT NULL,
  template_family TEXT NOT NULL,
  template_version INTEGER NOT NULL DEFAULT 1,
  category TEXT NOT NULL,
  language TEXT NOT NULL,
  status TEXT NOT NULL,
  quality_score TEXT,
  rejected_reason TEXT,
  allow_category_change BOOLEAN DEFAULT FALSE,
  definition_payload JSONB NOT NULL,
  meta_payload JSONB,
  last_synced_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_whatsapp_meta_templates_name_lang
  ON public.whatsapp_meta_templates (name, language);

CREATE INDEX IF NOT EXISTS idx_whatsapp_meta_templates_family
  ON public.whatsapp_meta_templates (template_family, template_version);

ALTER TABLE public.whatsapp_meta_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "SuperAdmins can manage whatsapp_meta_templates"
  ON public.whatsapp_meta_templates
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.system_superadmins
      WHERE system_superadmins.email = auth.jwt() ->> 'email'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.system_superadmins
      WHERE system_superadmins.email = auth.jwt() ->> 'email'
    )
  );

-- Create table for storing sync logs
CREATE TABLE IF NOT EXISTS public.whatsapp_template_sync_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  executed_at TIMESTAMPTZ DEFAULT now(),
  executed_by TEXT,
  created_count INTEGER DEFAULT 0,
  updated_count INTEGER DEFAULT 0,
  rejected_count INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  duration_ms INTEGER DEFAULT 0,
  execution_log JSONB
);

ALTER TABLE public.whatsapp_template_sync_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "SuperAdmins can view whatsapp_template_sync_logs"
  ON public.whatsapp_template_sync_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.system_superadmins
      WHERE system_superadmins.email = auth.jwt() ->> 'email'
    )
  );

-- Helper RPC function to allow edge functions (Service Role) to resolve templates without hardcoding names
-- This returns the highest version of an APPROVED template for a given family
CREATE OR REPLACE FUNCTION public.resolve_whatsapp_template(p_family TEXT, p_language TEXT DEFAULT 'pt_BR')
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT row_to_json(t) INTO v_result
  FROM public.whatsapp_meta_templates t
  WHERE t.template_family = p_family
    AND t.language = p_language
    AND t.status = 'APPROVED'
  ORDER BY t.template_version DESC
  LIMIT 1;

  RETURN v_result;
END;
$$;
