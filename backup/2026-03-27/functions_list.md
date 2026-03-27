# Funções Customizadas — 2026-03-27

| Função | Tipo | Retorno | Linguagem |
|--------|------|---------|-----------|
| _is_admin_or_sindico | FUNCTION | boolean | SQL |
| change_apartment | FUNCTION | json | PLPGSQL |
| check_email_exists | FUNCTION | boolean | PLPGSQL |
| check_needs_password_setup | FUNCTION | boolean | PLPGSQL |
| dinglo_resgatar_cupom | FUNCTION | jsonb | PLPGSQL |
| fn_set_delivery_time | FUNCTION | trigger | PLPGSQL |
| garage_calculate_price | FUNCTION | numeric | PLPGSQL |
| garage_check_availability | FUNCTION | boolean | PLPGSQL |
| garage_create_reservation | FUNCTION | jsonb | PLPGSQL |
| get_meu_condominio_id | FUNCTION | uuid | SQL |
| get_user_condo_id | FUNCTION | uuid | SQL |
| handle_updated_at | FUNCTION | trigger | PLPGSQL |
| is_admin_of_condo | FUNCTION | boolean | PLPGSQL |
| lista_add_points | FUNCTION | void | PLPGSQL |
| lista_check_price_alerts | FUNCTION | trigger | PLPGSQL |
| lista_increment_confirmations | FUNCTION | void | PLPGSQL |
| lista_increment_variant_popularity | FUNCTION | void | PLPGSQL |
| lista_mark_stale_prices | FUNCTION | void | PLPGSQL |
| lista_redeem_coupon | FUNCTION | jsonb | PLPGSQL |
| lista_update_search_tokens | FUNCTION | trigger | PLPGSQL |
| notify_novo_album | FUNCTION | trigger | PLPGSQL |
| notify_novo_aviso | FUNCTION | trigger | PLPGSQL |
| notify_sos_alert | FUNCTION | trigger | PLPGSQL |
| notify_vistoria_concluida | FUNCTION | trigger | PLPGSQL |
| push_notify_contrato | FUNCTION | void | PLPGSQL |
| push_notify_documento | FUNCTION | void | PLPGSQL |
| push_notify_parcel | FUNCTION | void | PLPGSQL |
| setup_user_password | FUNCTION | void | PLPGSQL |
| tr_fn_contrato_avisar_moradores | FUNCTION | trigger | PLPGSQL |
| tr_fn_convite_created | FUNCTION | trigger | PLPGSQL |
| tr_fn_convite_liberado | FUNCTION | trigger | PLPGSQL |
| tr_fn_documento_avisar_moradores | FUNCTION | trigger | PLPGSQL |
| tr_fn_encomenda_arrived | FUNCTION | trigger | PLPGSQL |
| tr_fn_encomenda_delivered | FUNCTION | trigger | PLPGSQL |
| tr_fn_fale_sindico_admin_reply | FUNCTION | trigger | PLPGSQL |
| tr_fn_fale_sindico_thread_criada | FUNCTION | trigger | PLPGSQL |
| tr_fn_ocorrencia_criada | FUNCTION | trigger | PLPGSQL |
| tr_fn_ocorrencia_respondida | FUNCTION | trigger | PLPGSQL |
| tr_fn_perfil_approved | FUNCTION | trigger | PLPGSQL |
| tr_fn_perfil_welcome | FUNCTION | trigger | PLPGSQL |
| tr_fn_perfil_welcome_uazapi | FUNCTION | trigger | PLPGSQL |
| tr_fn_reserva_criada | FUNCTION | trigger | PLPGSQL |
| tr_fn_reserva_status_changed | FUNCTION | trigger | PLPGSQL |
| tr_fn_resolve_botconversa | FUNCTION | trigger | PLPGSQL |
| update_album_fotos_updated_at | FUNCTION | trigger | PLPGSQL |
| update_classificados_updated_at | FUNCTION | trigger | PLPGSQL |
| update_profile | FUNCTION | json | PLPGSQL |
| update_vistorias_updated_at | FUNCTION | trigger | PLPGSQL |

**Total: 48 funções customizadas (excl. unaccent/C)**
