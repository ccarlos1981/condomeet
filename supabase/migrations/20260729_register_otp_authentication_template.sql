-- =================================================================
-- Migration: 20260729_register_otp_authentication_template
-- Objective: Register the OTP password recovery template in the 
--            MetaTemplateService (whatsapp_meta_templates table).
-- Category: AUTHENTICATION (required by Meta for OTP messages)
-- Governança: Status inicial é PENDING até a confirmação de 
--             aprovação na Meta WABA (APPROVED).
-- =================================================================

-- 1. Insert the OTP template definition
-- Category: AUTHENTICATION — obrigatório pela Meta para OTP/senha
INSERT INTO public.whatsapp_meta_templates (
    name,
    template_family,
    template_version,
    category,
    language,
    channel,
    tenant,
    status,
    quality_score,
    definition_payload
) VALUES (
    'condomeet_recuperacao_senha_v1',
    'recuperacao_senha',
    1,
    'AUTHENTICATION',
    'pt_BR',
    'whatsapp',
    'default',
    'PENDING',
    'GREEN',
    '{
        "template_name": "condomeet_recuperacao_senha_v1",
        "category": "AUTHENTICATION",
        "language": "pt_BR",
        "components": [
            {
                "type": "body",
                "text": "Olá {{1}}, seu código de verificação do Condomeet é {{2}}. Ele expira em 5 minutos. Por sua segurança, não compartilhe este código com ninguém.",
                "example": {
                    "body_text": [["Morador", "123456"]]
                }
            }
        ]
    }'::jsonb
) ON CONFLICT (name, language, channel, tenant) DO UPDATE SET
    template_family = EXCLUDED.template_family,
    template_version = EXCLUDED.template_version,
    category = EXCLUDED.category,
    definition_payload = EXCLUDED.definition_payload,
    updated_at = now();
