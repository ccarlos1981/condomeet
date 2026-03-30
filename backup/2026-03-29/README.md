# Backup Completo — 2026-03-29 21:23 BRT

## Conteúdo

| Arquivo | Descrição |
|---------|-----------|
| `db_functions.json` | Todas as 48 RPCs/funções do schema `public` |
| `db_rls_policies.json` | Todas as políticas RLS do schema `public` |
| `db_triggers.json` | Todos os triggers do schema `public` |
| `db_table_schema.json` | Schema completo de todas as tabelas (colunas, tipos, defaults) |
| `db_indexes.json` | Todos os índices do schema `public` |
| `db_migrations_list.json` | Lista de 82 migrations aplicadas |
| `edge_functions_list.json` | Lista de 36 Edge Functions ativas |
| `supabase_types.ts` | TypeScript types gerados do banco |

## Projeto

- **Supabase Project ID:** `avypyaxthvgaybplnwxu`
- **Projeto:** Condomeet v2 (condomeet_Antigravity)
- **Migrations:** 82 (de `01_schema_cleanup` até `harden_password_reset_rate_limit`)
- **Edge Functions:** 36 ativas

## Contexto

Backup realizado após:
1. Investigação de solicitação não autorizada de reset de senha via WhatsApp
2. Correção de typo no perfil (Cristianos → Cristiano)
3. Implementação de IP logging nas solicitações de reset
4. Hardening do rate limit (5min cooldown, 5/dia máximo, 10/hora por IP)
5. Remoção de permissão PUBLIC da RPC `request_password_reset_whatsapp`
