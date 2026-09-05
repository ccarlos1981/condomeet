-- Add channel and tenant to whatsapp_meta_templates
ALTER TABLE public.whatsapp_meta_templates 
ADD COLUMN IF NOT EXISTS channel TEXT NOT NULL DEFAULT 'whatsapp',
ADD COLUMN IF NOT EXISTS tenant TEXT NOT NULL DEFAULT 'default';

-- Drop the old indexes
DROP INDEX IF EXISTS public.idx_whatsapp_meta_templates_name_lang;
DROP INDEX IF EXISTS public.idx_whatsapp_meta_templates_family;

-- Recreate constraints and indexes with channel and tenant
ALTER TABLE public.whatsapp_meta_templates DROP CONSTRAINT IF EXISTS whatsapp_meta_templates_name_language_key;
ALTER TABLE public.whatsapp_meta_templates ADD CONSTRAINT whatsapp_meta_templates_name_language_channel_tenant_key UNIQUE (name, language, channel, tenant);

CREATE INDEX IF NOT EXISTS idx_whatsapp_meta_templates_family
  ON public.whatsapp_meta_templates (template_family, template_version, channel, tenant);

-- Update the resolve_whatsapp_template RPC
CREATE OR REPLACE FUNCTION public.resolve_whatsapp_template(
  p_family TEXT, 
  p_language TEXT DEFAULT 'pt_BR',
  p_channel TEXT DEFAULT 'whatsapp',
  p_tenant TEXT DEFAULT 'default'
)
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
    AND t.channel = p_channel
    AND t.tenant = p_tenant
    AND t.status = 'APPROVED'
  ORDER BY t.template_version DESC
  LIMIT 1;

  RETURN v_result;
END;
$$;
