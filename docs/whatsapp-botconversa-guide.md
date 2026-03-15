# Guia de Integração WhatsApp — Condomeet v2

> Referência completa sobre o envio de mensagens WhatsApp via BotConversa.
> Última atualização: 2026-03-14

---

## Visão Geral

O Condomeet envia mensagens WhatsApp usando a **API não-oficial do BotConversa** (endpoint `send_message`), centralizada na Edge Function `botconversa-send`.

```
┌──────────────┐     ┌──────────────────────┐     ┌──────────────┐
│ Flutter/Web  │     │  botconversa-send     │     │ BotConversa  │
│ (JWT user)   │────▶│  _shared/auth.ts      │────▶│ API          │
└──────────────┘     │  _shared/botconversa  │     │ send_message │
                     └──────────────────────┘     └──────────────┘
┌──────────────┐            ▲
│ DB Trigger   │────────────┘
│ (pg_net)     │   (sb_secret_ key)
└──────────────┘
```

---

## Arquitetura

### Edge Functions

| Função | Status | Descrição |
|--------|--------|-----------|
| `botconversa-send` | ✅ Ativo (v5) | Envio unificado de mensagens e flows (`verify_jwt: false`, auth no código) |
| `whatsapp-parcel-notify` | 🟡 Legacy | API oficial (cria subscriber), manter temporariamente |

### Shared Modules (`supabase/functions/_shared/`)

| Arquivo | Exports |
|---------|---------|
| `auth.ts` | `authorizeRequest()`, `getCallerProfile()`, `checkFunctionAccess()`, `normalizeRole()`, `createAdminClient()` |
| `botconversa.ts` | `sendMessage()`, `sendFlow()`, `sendToRecipients()`, `ensureJpegUrl()` |

---

## API do BotConversa

**Base URL:** `https://backend.botconversa.com.br/api/v1/webhook`

### Autenticação
```
Header: API-KEY: <BOTCONVERSA_API_KEY>
```

### Endpoints Utilizados

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/subscriber/{id}/send_message/` | POST | Enviar texto ou arquivo |
| `/subscriber/{id}/send_flow/` | POST | Disparar um flow |
| `/subscriber/` | POST | Criar/atualizar subscriber (**API oficial**, usada apenas no legacy) |

### Rate Limits
- **Texto:** 1 requisição/s (delay 1000ms entre envios)
- **Arquivo:** 1 requisição/2s (delay 2000ms entre envios)
- **Encomendas:** delay aleatório 15-25s entre envios (anti-ban Meta)

### Enviar Mensagem de Texto
```json
POST /subscriber/{botconversa_id}/send_message/
{
  "type": "text",
  "value": "Olá! Sua encomenda chegou."
}
```

### Enviar Arquivo (imagem, PDF)
```json
POST /subscriber/{botconversa_id}/send_message/
{
  "type": "file",
  "value": "https://storage.supabase.co/path/to/file.jpeg"
}
```
> ⚠️ PNGs são automaticamente reescritos para `.jpeg` (BotConversa não renderiza PNGs corretamente).

### Enviar Flow
```json
POST /subscriber/{botconversa_id}/send_flow/
{
  "flow": 12345
}
```

---

## Variáveis de Ambiente (Supabase Secrets)

| Variável | Descrição |
|----------|-----------|
| `BOTCONVERSA_API_KEY` | Chave de API do BotConversa |
| `BOTCONVERSA_FLOW_ID` | ID do flow de encomendas (usado pelo legacy) |
| `SUPABASE_URL` | URL do projeto (auto-disponível) |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (auto-disponível) |

---

## `botconversa-send` — Payload

> **Nota:** `verify_jwt` está desabilitado no gateway. A autenticação é feita 100% no código via `_shared/auth.ts`. Isso é necessário porque o Supabase não suporta `verify_jwt` com keys `sb_secret_*` (não são JWTs).

```json
POST /functions/v1/botconversa-send
Authorization: Bearer <JWT_usuario ou sb_secret_key>
Content-Type: application/json

{
  "msg": "Olá |nome|! Sua encomenda chegou.",
  "tipo": "texto",
  "condominio_id": "uuid",
  "modo_envio": "por_condominio",
  "bloco": "A",
  "apto": "101",
  "perfil": "Morador",
  "user_id": "uuid",
  "botconversa_id": "123456",
  "flow_id": 12345,
  "tipo_notificacao": "encomenda"
}
```

### Campos Obrigatórios

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `msg` | string | Mensagem (max 4096 chars). Use `\|nome\|` para personalizar. |
| `condominio_id` | UUID | Condomínio alvo |
| `modo_envio` | enum | Como resolver os destinatários |

### `modo_envio` — Modos de Envio

| Modo | Campos extras | Descrição |
|------|---------------|-----------|
| `por_condominio` | — | Todos os moradores aprovados do condomínio |
| `por_bloco` | `bloco` | Todos de um bloco |
| `por_apto` | `bloco`, `apto` | Moradores de um apartamento |
| `por_perfil` | `perfil` | Por papel (ex: "Morador", "Síndico") |
| `por_morador` | `user_id` | Um morador específico (perfil.id) |
| `por_botconversa` | `botconversa_id` | Direto por botconversa_id |

### `tipo` — Tipo da Mensagem

| Valor | Descrição |
|-------|-----------|
| `texto` ou `text` | Mensagem de texto |
| `file` | Arquivo (URL pública) |

### Personalização

O placeholder `|nome|` é substituído pelo **primeiro nome** de cada destinatário:
```
"Olá |nome|! Reunião amanhã." → "Olá Cristiano! Reunião amanhã."
```
Se o nome não existir, usa "Morador" como fallback.

### Mensagem Secundária (`msg2`)

Para enviar **duas mensagens em sequência** (ex: boas-vindas), use os campos opcionais:

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `msg2` | string | Segunda mensagem (enviada após delay) |
| `msg2_delay_ms` | number | Delay antes de `msg2` (default: 5000ms) |

Exemplo (usado pelo trigger de boas-vindas):
```json
{
  "msg": "Primeira mensagem...",
  "msg2": "Segunda mensagem...",
  "msg2_delay_ms": 5000,
  "tipo_notificacao": "boas_vindas"
}
```

---

## Autorização

> `verify_jwt: false` no gateway — autenticação é feita integralmente no código.

### Fluxo para usuários (Flutter/Web)

```
1. JWT → auth.getUser() → user_id
2. user_id → perfil.papel_sistema + condominio_id
3. condominio_id === request.condominio_id? → ou 403
4. condominios.features_config → functions[botconversa_send].roles[papel].visible? → ou 403
```

### Fluxo para triggers (pg_net)

```
1. Authorization header contém sb_secret_* ou SUPABASE_SERVICE_ROLE_KEY?
2. Se sim → bypass total (sistema confiável)
```

### Quem pode enviar

| Caller | Resultado |
|--------|-----------|
| **`sb_secret_*`** (trigger pg_net) | ✅ Bypass total |
| **`SUPABASE_SERVICE_ROLE_KEY`** (JWT legado) | ✅ Bypass total |
| **Síndico** (default) | ✅ Permitido |
| **Sub-síndico** (default) | ✅ Permitido |
| **Portaria** (default) | ✅ Permitido |
| **Morador** (default) | ❌ 403 |
| **Qualquer papel** (configurado) | ✅ Se `visible: true` em `features_config` |
| **Outro condomínio** | ❌ 403 |
| **Sem header** | ❌ 401 |
| **JWT inválido/expirado** | ❌ 401 |

### features_config

Configurado pelo admin na tela **Configurar Menu** (`configure_menu_screen.dart`):

```json
{
  "functions": [
    {
      "id": "botconversa_send",
      "roles": {
        "sindico": { "visible": true },
        "portaria": { "visible": true },
        "morador": { "visible": false }
      }
    }
  ]
}
```

Quando `features_config` não contém `botconversa_send`, o fallback permite apenas: `sindico`, `admin`, `sub_sindico`.

---

## Triggers de Banco de Dados

### Encomenda — Notificação Automática (WhatsApp + Push)

```sql
-- Trigger: tr_encomenda_arrived
-- Tabela: encomendas (AFTER INSERT)
-- Função: tr_fn_encomenda_arrived()
--   1. Chama push_notify_parcel() → parcel-push-notify (push notification)
--   2. Chama botconversa-send via pg_net (WhatsApp)
-- Autenticação: sb_secret_* key via header Authorization
-- modo_envio: por_apto (todos os moradores da unidade recebem)
-- tipo_notificacao: encomenda (ativa delay aleatório 15-25s entre envios)
```

**Template da mensagem:**
```
📦 Condomínio {nome do condomínio}

Chegou uma encomenda para o seu apartamento.

📨 Tipo de encomenda:
{tipo}

🏢 Unidade
Bloco: {bloco} / Apto: {apto}

🔍 Cod. rastreio
{tracking_code ou 'Não informado'}

⏱ Retirar até:
{created_at + 7 dias, formato DD/MM/YYYY}

🗒️ Observação da encomenda:
{observacao ou '-'}

Condomeet agradece!
Cod. interno: {5 chars aleatórios - anti-ban Meta}
```

> ⚠️ A tabela real é `encomendas` (não `parcels`). A tabela `parcels` é legada e também tem um trigger (`tr_on_parcel_inserted → notify_parcel_arrival`).

O trigger busca nome do condomínio, `bloco_txt` e `apto_txt` do `perfil`, dados da encomenda (`tipo`, `tracking_code`, `observacao`), calcula prazo de 7 dias e gera código aleatório anti-ban. Usa `modo_envio: por_apto` para que **todos os moradores aprovados da mesma unidade** recebam, com **delay aleatório de 15-25 segundos** entre cada envio para evitar banimento pela Meta.

### Encomenda — Notificação de Entrega (WhatsApp)

```sql
-- Trigger: tr_encomenda_delivered
-- Tabela: encomendas (AFTER UPDATE OF status)
-- Condição: status muda para 'delivered'
-- Função: tr_fn_encomenda_delivered()
--   Chama botconversa-send via pg_net (WhatsApp)
-- Autenticação: sb_secret_* key via header Authorization
-- modo_envio: por_apto (todos os moradores da unidade recebem)
-- tipo_notificacao: encomenda_entrega (delay aleatório 15-25s)
```

**Template da mensagem:**
```
✔ Condomínio {nome do condomínio}

Encomenda acabou de ser retirada.

📨 Tipo de encomenda
{tipo}

🔍 Cod. rastreio
{tracking_code ou 'Não informado'}

🏨 Unidade
Bloco: {bloco} | Apto: {apto}

🗒️ Observação
{observacao ou '-'}

😊 Retirado por:
{picked_up_by_name ou 'Não informado'}

Condomeet agradece!
Cód. interno: {5 chars aleatórios - anti-ban Meta}
```

O trigger dispara quando o `status` muda de qualquer valor para `'delivered'`. Busca nome do condomínio, dados do perfil e da encomenda. Também usa delay aleatório de 15-25 segundos entre envios.

### Perfil — Auto-resolve `botconversa_id`

```sql
-- Triggers: tr_perfil_resolve_botconversa_insert / _update
-- Tabela: perfil (AFTER INSERT / AFTER UPDATE OF whatsapp)
-- Função: tr_fn_resolve_botconversa()
--   Chama botconversa-resolve-subscriber via pg_net
--   Que faz upsert no BotConversa (POST /subscriber/)
--   E salva o subscriber ID de volta em perfil.botconversa_id
-- Condições:
--   INSERT: só quando whatsapp não é NULL/vazio
--   UPDATE: só quando whatsapp muda (IS DISTINCT FROM)
```

Quando um morador é cadastrado com telefone, ou quando o telefone é alterado, o trigger automaticamente:
1. Chama a Edge Function `botconversa-resolve-subscriber`
2. Que cria/atualiza o subscriber no BotConversa via `POST /subscriber/`
3. E salva o `id` retornado em `perfil.botconversa_id`

Isso garante que **novos moradores** já tenham `botconversa_id` preenchido automaticamente.

### Novo Cadastro — Mensagens de Boas-Vindas (WhatsApp)

```sql
-- Trigger: tr_perfil_welcome
-- Tabela: perfil (AFTER UPDATE OF botconversa_id)
-- Condição: botconversa_id muda de NULL para não-NULL (primeiro cadastro)
-- Função: tr_fn_perfil_welcome()
--   Chama botconversa-send via pg_net com msg + msg2
-- Autenticação: sb_secret_* key
-- modo_envio: por_botconversa (direto ao novo usuário)
-- tipo_notificacao: boas_vindas
```

**Mensagem 1 — Boas-vindas:**
```
😀 {nome do condomínio}

Olá {primeiro nome}, seu cadastro foi feito com sucesso.

Em breve o Adm/Síndico do {nome do condomínio} irá liberar seu acesso.

Condomeet agradece!
Cód interno: {5 chars aleatórios}
```

**Mensagem 2 — Info do app (5s depois):**
```
Ah, esse é número do aplicativo Condomeet.

Cadastre nosso número no seu celular!

Se precisar falar com o suporte do aplicativo Condomeet,
cadastre no seu celular para não perder informação.

Não temos informações internas do Condomínio.

Se quiser saber das nossas novidades, siga a gente:

www.instagram.com/condomeet.app

Seja Bem vindo(a)!
Cód interno: {5 chars aleatórios}
```

O trigger dispara automaticamente quando o `botconversa_id` é resolvido pela primeira vez (após o `botconversa-resolve-subscriber`). A segunda mensagem é enviada com delay de 5 segundos via campo `msg2` + `msg2_delay_ms`.

### Aprovação de Cadastro — Notificação (WhatsApp)

```sql
-- Trigger: tr_perfil_approved
-- Tabela: perfil (AFTER UPDATE OF status_aprovacao)
-- Condição: status_aprovacao muda para 'aprovado'
-- Função: tr_fn_perfil_approved()
--   Chama botconversa-send via pg_net
-- Autenticação: sb_secret_* key
-- modo_envio: por_botconversa (direto ao morador aprovado)
-- tipo_notificacao: aprovacao
```

**Template da mensagem:**
```
😄
{nome do condomínio}

Seu cadastro foi aprovado e/ou ativado.

Agora você poderá acessar o aplicativo Condomeet no {nome do condomínio}.

Sua unidade está em:

Bloco: {bloco}
Apto: {apto}

Condomeet agradece!
Cód interno: {5 chars aleatórios}
```

O trigger dispara quando o admin/síndico aprova o cadastro. Só envia se o morador já tiver `botconversa_id` cadastrado.

### Autorização de Visitante — Notificações (WhatsApp)

```sql
-- Trigger: tr_convite_created
-- Tabela: convites (AFTER INSERT)
-- Função: tr_fn_convite_created()
--   Cenário A: SEM celular do visitante → msg só pro morador
--   Cenário B: COM celular do visitante → msg pro morador + msg pro visitante
-- Também: salva contato na tabela contatos_visitantes (agenda)
-- tipo_notificacao: autorizacao_visitante
```

**Cenário A — Sem celular do visitante (msg pro morador):**
```
🚪
Autorização confirmada!

Ei, {nome do morador}, avise seu visitante! 👋

Ele(a) já pode entrar! 😊

Peça para ele(a) apresentar este código na portaria:

🔐 {código 3 chars}

Visita para a Data: {DD/MM/YYYY}

Qualquer dúvida no uso do aplicativo, estamos por aqui.

Obrigado por usar o Condomeet 🧡
cód interno: {5 chars}
```

**Cenário B — Com celular (msg diferente pro morador):**
```
🚪
Autorização confirmada!

Ei, {morador}, avise seu/sua visitante {nome visitante}

Acabamos de enviar uma autorização de entrada para ele(a). 👋

Ele(a) já pode entrar! 😊

Peça para ele(a) apresentar este código na portaria:

🔐 {código 3 chars}

Visita para a Data: {DD/MM/YYYY}

Qualquer dúvida no uso do aplicativo, estamos por aqui.

Obrigado por usar o Condomeet 🧡
cód interno: {5 chars}
```

**Cenário B — Mensagem para o VISITANTE (10s depois):**
```
🚪
{nome do condomínio}

Olá, {nome visitante}! 👋

O(a) morador(a) {nome morador} acabou de autorizar a sua entrada no condomínio.

📅 Data da visita: {DD/MM/YYYY}

🔑 Código de autorização: {código 3 chars}

👉 Ao chegar na portaria, informe seu nome e o código acima para liberar a entrada.

Condomeet agradece sua colaboração.
cód interno: {5 chars}
```

**Tabela `contatos_visitantes`**: Quando o visitante tem celular, o contato é salvo automaticamente (upsert) para formar uma agenda de visitantes do morador, e o `botconversa_id` do visitante é resolvido via `botconversa-resolve-subscriber`.

---

## Tabela `perfil` — Campos Relevantes

| Coluna | Tipo | Uso |
|--------|------|-----|
| `botconversa_id` | text | ID do subscriber no BotConversa (auto-preenchido via trigger) |
| `whatsapp` | text | Telefone do morador (dispara auto-resolve do botconversa_id) |
| `nome_completo` | text | Para personalização `\|nome\|` |
| `papel_sistema` | text | Role para autorização |
| `condominio_id` | UUID | Isolamento por condomínio |
| `bloco_txt` | text | Bloco para resolução de destinatários |
| `apto_txt` | text | Apartamento |
| `status_aprovacao` | text | Deve ser "aprovado" |
| `bloqueado` | bool | Deve ser `false` |

> Somente moradores com `botconversa_id` cadastrado, `status_aprovacao = 'aprovado'` e `bloqueado = false` recebem mensagens. O `botconversa_id` é populado automaticamente quando o whatsapp do perfil é preenchido.

---

## Deduplicação

O `botconversa-send` possui deduplicação **in-memory** com janela de 30 segundos.

**Chave de dedup:** `condominio_id:bloco:apto:modo_envio:tipo_notificacao:tipo`

> ⚠️ A dedup é perdida ao reiniciar a function. Para alto volume, considerar persistência em tabela.

---

## Resolução de Problemas

| Problema | Causa | Solução |
|----------|-------|---------|
| Morador novo não recebe | `botconversa_id` vazio | Verificar se `whatsapp` está preenchido (trigger resolve automaticamente) |
| 401 ao enviar (user) | JWT inválido ou expirado | Refazer login |
| 401 ao enviar (trigger) | Key `sb_secret_*` não reconhecida | Verificar `isSecretKey()` no `_shared/auth.ts` |
| 401 com `verify_jwt: true` | sb_secret keys não são JWT | Manter `verify_jwt: false`, auth no código |
| 403 ao enviar | Papel sem permissão | Configurar `features_config` via admin |
| 403 cross-condo | Enviando para outro condomínio | Verificar `condominio_id` |
| Trigger não dispara | Trigger na tabela errada | Usar `encomendas` (não `parcels`) |
| PNG não aparece | BotConversa issue | Já convertido automaticamente para JPEG |
| Mensagem duplicada | Dedup 30s | Aguardar ou enviar com `tipo_notificacao` diferente |

---

## Exemplos de Uso

### Flutter — Enviar aviso para todo o condomínio
```dart
await Supabase.instance.client.functions.invoke(
  'botconversa-send',
  body: {
    'msg': 'Olá |nome|! Reunião de condomínio amanhã às 19h no salão.',
    'tipo': 'texto',
    'condominio_id': condominioId,
    'modo_envio': 'por_condominio',
  },
);
```

### Flutter — Enviar para um morador específico
```dart
await Supabase.instance.client.functions.invoke(
  'botconversa-send',
  body: {
    'msg': 'Olá |nome|! Sua encomenda chegou na portaria.',
    'tipo': 'texto',
    'condominio_id': condominioId,
    'modo_envio': 'por_morador',
    'user_id': perfilId,
  },
);
```

### cURL — Teste direto
```bash
curl -X POST \
  https://avypyaxthvgaybplnwxu.supabase.co/functions/v1/botconversa-send \
  -H "Authorization: Bearer <JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "msg": "Teste |nome|!",
    "tipo": "texto",
    "condominio_id": "<uuid>",
    "modo_envio": "por_morador",
    "user_id": "<perfil_id>"
  }'
```

---

## Arquivos Relevantes

| Arquivo | Descrição |
|---------|-----------|
| `supabase/functions/botconversa-send/index.ts` | Edge Function principal de envio |
| `supabase/functions/botconversa-resolve-subscriber/index.ts` | Auto-resolve botconversa_id (upsert subscriber) |
| `supabase/functions/_shared/auth.ts` | Módulo de autorização |
| `supabase/functions/_shared/botconversa.ts` | Módulo de envio BotConversa |
| `supabase/functions/whatsapp-parcel-notify/index.ts` | Legacy (API oficial) |
| `lib/.../configure_menu_screen.dart` | Config de permissões por role |
| `supabase/migrations/20260301_parcel_notification_trigger.sql` | Trigger original (parcels) |
| `supabase/migrations/20260308c_encomendas_push_triggers.sql` | Triggers da tabela encomendas |
| `migration: encomenda_trigger_por_apto` | Trigger encomenda atualizado (por_apto) |
| `migration: perfil_resolve_botconversa_trigger` | Trigger auto-resolve botconversa_id |
