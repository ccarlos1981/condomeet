# Triggers — 2026-03-27

| Trigger | Tabela | Evento | Timing | Função |
|---------|--------|--------|--------|--------|
| trg_album_fotos_updated_at | album_fotos | UPDATE | BEFORE | update_album_fotos_updated_at() |
| trg_notify_novo_album | album_fotos | INSERT | AFTER | notify_novo_album() |
| trg_notify_novo_aviso | avisos | INSERT | AFTER | notify_novo_aviso() |
| trg_classificados_updated_at | classificados | UPDATE | BEFORE | update_classificados_updated_at() |
| tr_contrato_avisar_moradores | contratos | INSERT/UPDATE | AFTER | tr_fn_contrato_avisar_moradores() |
| tr_convite_created | convites | INSERT | AFTER | tr_fn_convite_created() |
| tr_convite_liberado | convites | UPDATE | AFTER | tr_fn_convite_liberado() |
| tr_documento_avisar_moradores | documentos | INSERT/UPDATE | AFTER | tr_fn_documento_avisar_moradores() |
| tr_encomenda_arrived | encomendas | INSERT | AFTER | tr_fn_encomenda_arrived() |
| tr_encomenda_delivered | encomendas | UPDATE | AFTER | tr_fn_encomenda_delivered() |
| tr_set_delivery_time | encomendas | UPDATE | BEFORE | fn_set_delivery_time() |
| tr_fale_sindico_admin_reply | fale_sindico_mensagens | INSERT | AFTER | tr_fn_fale_sindico_admin_reply() |
| tr_fale_sindico_thread_criada | fale_sindico_threads | INSERT | AFTER | tr_fn_fale_sindico_thread_criada() |
| trigger_lista_check_alerts | lista_prices_current | INSERT/UPDATE | AFTER | lista_check_price_alerts() |
| trg_products_base_search | lista_products_base | INSERT/UPDATE | BEFORE | lista_update_search_tokens() |
| tr_ocorrencia_criada | ocorrencias | INSERT | AFTER | tr_fn_ocorrencia_criada() |
| tr_ocorrencia_respondida | ocorrencias | UPDATE | AFTER | tr_fn_ocorrencia_respondida() |
| tr_perfil_approved | perfil | UPDATE | AFTER | tr_fn_perfil_approved() |
| tr_perfil_welcome_uazapi_insert | perfil | INSERT | AFTER | tr_fn_perfil_welcome_uazapi() |
| tr_perfil_welcome_uazapi_update | perfil | UPDATE | AFTER | tr_fn_perfil_welcome_uazapi() |
| tr_reserva_criada | reservas | INSERT | AFTER | tr_fn_reserva_criada() |
| tr_reserva_status_changed | reservas | UPDATE | AFTER | tr_fn_reserva_status_changed() |
| trg_notify_sos_alert | sos_alertas | INSERT | AFTER | notify_sos_alert() |
| trg_notify_vistoria_concluida | vistorias | UPDATE | AFTER | notify_vistoria_concluida() |
| trg_vistorias_updated_at | vistorias | UPDATE | BEFORE | update_vistorias_updated_at() |

**Total: 29 triggers em 15 tabelas**
