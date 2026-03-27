-- ============================================================
-- Migration: Fix search_path on SECURITY DEFINER functions
-- Date: 2026-03-26
-- Description: Adds SET search_path = public to all SECURITY
--   DEFINER functions that don't have it set, preventing
--   potential search_path injection attacks.
--   This does NOT change function behavior.
-- ============================================================

-- HIGH RISK: Auth/Profile functions
ALTER FUNCTION public.setup_user_password(text, text) SET search_path = public;
ALTER FUNCTION public.check_email_exists(text) SET search_path = public;
ALTER FUNCTION public.check_needs_password_setup(text) SET search_path = public;
ALTER FUNCTION public.change_apartment(uuid, text, text) SET search_path = public;
ALTER FUNCTION public.update_profile(uuid, text, text, text) SET search_path = public;
ALTER FUNCTION public.get_meu_condominio_id() SET search_path = public;

-- MEDIUM RISK: Business logic functions
ALTER FUNCTION public.garage_create_reservation(uuid, text, text, text, timestamptz, timestamptz, text, text) SET search_path = public;
ALTER FUNCTION public.garage_calculate_price(uuid, text, timestamptz, timestamptz) SET search_path = public;
ALTER FUNCTION public.garage_check_availability(uuid, timestamptz, timestamptz) SET search_path = public;
ALTER FUNCTION public.lista_add_points(uuid, integer) SET search_path = public;
ALTER FUNCTION public.lista_redeem_coupon(text) SET search_path = public;
ALTER FUNCTION public.lista_increment_confirmations(uuid) SET search_path = public;
ALTER FUNCTION public.lista_increment_variant_popularity(uuid) SET search_path = public;
ALTER FUNCTION public.lista_check_price_alerts() SET search_path = public;
ALTER FUNCTION public.dinglo_resgatar_cupom(text) SET search_path = public;
ALTER FUNCTION public.push_notify_parcel(uuid, text, uuid, text, text, text, text) SET search_path = public;
ALTER FUNCTION public.push_notify_contrato(uuid, uuid, text, text) SET search_path = public;
ALTER FUNCTION public.push_notify_documento(uuid, uuid, text, text) SET search_path = public;

-- LOW RISK: Trigger functions
ALTER FUNCTION public.tr_fn_convite_created() SET search_path = public;
ALTER FUNCTION public.tr_fn_convite_liberado() SET search_path = public;
ALTER FUNCTION public.tr_fn_encomenda_arrived() SET search_path = public;
ALTER FUNCTION public.tr_fn_encomenda_delivered() SET search_path = public;
ALTER FUNCTION public.tr_fn_fale_sindico_admin_reply() SET search_path = public;
ALTER FUNCTION public.tr_fn_fale_sindico_thread_criada() SET search_path = public;
ALTER FUNCTION public.tr_fn_ocorrencia_criada() SET search_path = public;
ALTER FUNCTION public.tr_fn_ocorrencia_respondida() SET search_path = public;
ALTER FUNCTION public.tr_fn_perfil_approved() SET search_path = public;
ALTER FUNCTION public.tr_fn_perfil_welcome_uazapi() SET search_path = public;
ALTER FUNCTION public.tr_fn_reserva_criada() SET search_path = public;
ALTER FUNCTION public.tr_fn_reserva_status_changed() SET search_path = public;
ALTER FUNCTION public.tr_fn_resolve_botconversa() SET search_path = public;
ALTER FUNCTION public.tr_fn_contrato_avisar_moradores() SET search_path = public;
ALTER FUNCTION public.tr_fn_documento_avisar_moradores() SET search_path = public;
ALTER FUNCTION public.notify_novo_album() SET search_path = public;
ALTER FUNCTION public.notify_novo_aviso() SET search_path = public;
ALTER FUNCTION public.notify_sos_alert() SET search_path = public;
ALTER FUNCTION public.notify_vistoria_concluida() SET search_path = public;
