# Diretrizes e Regras do Projeto — Condomeet

## Política Oficial de Classificação de Mensagens

O Condomeet não realiza comunicações promocionais, campanhas comerciais, cross-sell, upsell, publicidade ou qualquer forma de marketing via WhatsApp.

Todas as mensagens emitidas pelo ecossistema Condomeet possuem caráter exclusivamente operacional, transacional, administrativo ou de segurança, decorrentes da prestação do serviço condominial e de solicitações realizadas pelo próprio morador, síndico, administração ou condomínio.

### Diretrizes de Categoria de Templates (Meta Cloud API):

1. **Utility (Utilidade):** Categoria padrão e obrigatória para todas as mensagens operacionais (encomendas, visitantes, reservas, documentos, ocorrências, boletos, assembleias e alertas).
2. **Authentication (Autenticação):** Utilizada exclusivamente para OTP, login, recuperação de senha e validação de identidade.
3. **Marketing:** Proibido no ecossistema Condomeet. Nenhum template deve ser submetido ou mantido nessa categoria.

Sempre que um novo template for criado, ele deverá ser inicialmente projetado e submetido como Utility, exceto se for explicitamente autenticação. Caso a Meta classifique como Marketing, o texto deve ser revisado e reenquadrado para Utility.

---

## 🚦 Baseline Operacional e Piloto Real Park (Fase 1)

O projeto encontra-se sob **Ordem de Operação Assistida** do piloto **Real Park** (ID `ed90ec35-95f0-4a04-92b4-35fe4217f0e1`) no estágio **`encomendas`** a partir de 12/07/2026.

### Diretrizes e Restrições de Desenvolvimento (Congelamento):
1. **Congelamento da Arquitetura do WhatsApp:** É proibido realizar novos deploies estruturais, alterações de banco, modificações de webhooks, workers, failover ou lógica de janela de 24h relacionadas ao WhatsApp durante este período de observação assistida de 7 dias (salvo correções críticas de produção autorizadas).
2. **Escopo Restrito do Piloto:** Apenas o condomínio Real Park e o módulo de encomendas estão autorizados a transitar pela Meta Cloud API. Demais condomínios e módulos permanecem canalizados pelo BotConversa.
3. **Mapeamento de Avanço:** O avanço para a Fase 2 (Visitantes) só será autorizado após a manutenção contínua e sem falhas dos KPIs de qualidade: Delivery Rate > 98%, Failovers = 0, Latência média < 3s, e 0 Reclamações operacionais.

---

## 📌 Dívidas Técnicas Registradas (WhatsApp)

1. **Substituição da lógica de roteamento textual por metadados / message_type:**
   - **Descrição:** Substituir a validação atual por texto (`textBody.includes("Chegou uma encomenda")`) na tomada de decisão de envio do piloto Real Park.
   - **Solução Futura:** Utilizar lógica baseada em `condominio_id` e `message_type` operacional (e/ou payload de metadados estruturado).
   - **Objetivo:** Permitir que mensagens de texto, imagens e outros anexos do módulo de encomendas do piloto Real Park sejam roteadas de forma consistente pela `META_CLOUD_API` (API Oficial).

2. **Implementação de Jitter (Tempo de Envio Aleatório):**
   - **Descrição:** Substituir os intervalos de espera estáticos (`COOLDOWN_TEXT_MS = 15000` e `COOLDOWN_FILE_MS = 25000`) por um atraso aleatório oscilando entre 20 e 40 segundos no envio de mensagens.
   - **Solução Futura:** Utilizar um gerador de atraso dinâmico no loop do worker (ex: `Math.floor(Math.random() * (40000 - 20000 + 1) + 20000)`).
   - **Objetivo:** Dificultar a detecção de padrões repetitivos automatizados pelos algoritmos anti-spam da Meta, reduzindo o risco de bloqueios e banimentos do número de disparo.


---

## 📊 Baseline Oficial — Dashboard de Consumo Meta (Fase de Homologação Concluída)

O Dashboard de Consumo por Condomínio da API Oficial Meta encontra-se homologado e implantado.

### Premissas Consolidadas de Operação e Segurança:
1. **Atribuição Obrigatória de Custos:** Todos os custos de mensagens e conversas Meta são atribuídos obrigatoriamente a um `condominio_id` válido. Não devem ser permitidos registros de envios órfãos sem condomínio.
2. **Aderência Financeira Total:** A soma consolidada de consumo de todos os condomínios na view/RPC deve possuir aderência de 100% com o faturamento consolidado emitido pela fatura da Meta Cloud API no período.
3. **Isolamento de Performance (Analytics Read-Only):** O módulo de dashboard opera exclusivamente sobre Views e RPCs read-only (`whatsapp_metrics_by_condo_view` e `get_whatsapp_consumption_by_condo`). É expressamente proibida qualquer concorrência, travamento ou escrita que impacte workers de envio, filas de processamento de mensagens ou webhooks transacionais da Meta.
4. **Isolamento de Escopo por Perfil (Segurança):**
   - **MASTER Admins:** Possuem acesso exclusivo ao módulo com visão global de faturamento e volumes de todos os condomínios (incluindo o ranking Top 5 de maiores consumidores).
   - **Síndicos / Subsíndicos:** Não possuem acesso a este módulo administrativo/operacional da plataforma.
5. **Preparação para Faturamento:** O modelo de dados retorna as métricas de volumetria segregadas (mensagens enviadas, conversas pagas/templates e mensagens gratuitas) de forma a garantir a compatibilidade arquitetural com regras futuras de billing (franquias, excedentes e repasses integrais).
6. **Centralização de SuperAdmins (Hardening):** Todas as verificações de privilégios de administrador global (SuperAdmin) devem ser feitas exclusivamente consultando a tabela de banco de dados `public.system_superadmins(email TEXT PRIMARY KEY)` ou o campo de perfil correspondente. É expressamente proibido manter listas de e-mails administrativas em arquivos estáticos (hardcode) do frontend ou backend.

### Observação Operacional — Dashboard de Consumo WhatsApp

Os indicadores financeiros do dashboard interno do Condomeet representam custos estimados operacionais baseados nos eventos processados pela plataforma e não necessariamente o faturamento efetivamente liquidado pela Meta.

O faturamento oficial deve sempre ser considerado aquele apresentado no WhatsApp Manager / Billing da Meta.

Caso futuramente seja implementada integração com APIs oficiais de billing da Meta, os indicadores deverão ser renomeados para:
- Custo Estimado
- Custo Faturado
- Diferença de Faturamento

---


## 📊 Baseline Oficial — SuperAdmin Centralizado (Homologado)

A plataforma passa a utilizar exclusivamente a tabela `public.system_superadmins` como fonte única de verdade para privilégios administrativos globais.

### Premissas Obrigatórias de Governança:
1. **Fim dos Hardcodes:** É proibido utilizar listas hardcoded de e-mails em código.
2. **Consulta Centralizada:** Todo acesso administrativo global deve consultar `system_superadmins`.
3. **Segregação de Papéis:** Roles locais (síndico, subsíndico, morador, porteiro, etc.) continuam sendo gerenciadas pela tabela `perfil`.
4. **Escopo Corporativo:** A tabela `system_superadmins` representa privilégios corporativos da plataforma Condomeet e não privilégios do condomínio.

---

## 📊 Regra Permanente — Ativação de WABA em Produção

Toda nova implantação de WhatsApp Cloud API em produção deve obrigatoriamente validar os seguintes itens antes da homologação final:

### Checklist Obrigatório
- Business Verification = VERIFIED
- WABA Status = ACTIVE
- Phone Status = VERIFIED
- Quality Rating = GREEN
- App inscrito via:
  `POST /{WABA_ID}/subscribed_apps`
- Webhook recebendo eventos:
  - `sent`
  - `delivered`
  - `read`
- Forma de pagamento válida cadastrada na WABA

### Erro Crítico Conhecido
Meta Error:
`131042 - Business eligibility payment issue`

Sintoma:
- Graph API retorna HTTP 200.
- Mensagem assume status "sent".
- Webhook posteriormente converte para "failed".
- Destinatário nunca recebe a mensagem.

Causa:
Ausência de forma de pagamento válida na WABA.

Observação:
Esse erro pode ocorrer mesmo quando:
- Business Verification = VERIFIED
- WABA Status = ACTIVE
- Phone Status = VERIFIED
- Quality Rating = GREEN
- Token possui todos os escopos necessários
- Webhook está operacional
- `subscribed_apps` está ativo

### Propagação da Cobrança
Após inclusão do cartão de crédito na WABA, a ativação financeira da Meta pode levar alguns minutos para propagar internamente.

Durante esse período podem coexistir mensagens:
- entregues normalmente;
- falhadas com erro 131042;
- pendentes de sincronização.

Não assumir falha sistêmica até transcorrer pelo menos 15 minutos após o cadastro da forma de pagamento.

### Comportamento Esperado da Outbox
Mensagens marcadas como FAILED não devem ser reenviadas automaticamente após a correção da causa raiz.

Motivo:
Evitar entrega tardia de eventos sensíveis como:
- autorizações de visitantes;
- liberações temporárias;
- notificações operacionais expiradas.

Reenvios devem ocorrer somente por ação administrativa explícita.

---

## 📊 Regra Permanente — Hash obrigatório em whatsapp_outbox

Toda inserção na tabela `whatsapp_outbox` deve obrigatoriamente gerar e persistir `message_hash`.

### Objetivo
Garantir:
- deduplicação;
- prevenção de spam;
- idempotência de webhooks;
- proteção contra múltiplos envios acidentais;
- consistência entre fluxos automáticos e manuais.

### Regra
É proibido executar qualquer:

```sql
INSERT INTO whatsapp_outbox (...)
```

sem preencher o campo `message_hash`.

A ausência do campo viola a constraint:

```sql
message_hash NOT NULL
```

e interrompe imediatamente o fluxo de envio.

### Implementação Oficial

Todos os canais de envio devem utilizar o mesmo algoritmo de geração de hash baseado em:

- telefone normalizado;
- tipo do payload;
- conteúdo da mensagem;
- condomínio de origem.

Implementação conceitual:

```text
SHA256(
  telefone_normalizado +
  payload_type +
  conteudo +
  condominio_id
)
```

### Fluxos obrigatoriamente cobertos

- smartSend (Edge Functions)
- sendManualMessage (Painel Administrativo)
- reenvio manual
- campanhas futuras
- automações futuras
- integrações externas
- qualquer novo produtor de registros em `whatsapp_outbox`

### Helpers Oficiais

As implementações homologadas para geração do hash são:

- `normalizePhone()`
- `sha256()`

É proibida a criação de algoritmos alternativos ou hashes incompatíveis entre fluxos.

### Observação operacional

O comportamento atual é determinístico e idempotente.

Caso futuramente seja necessário permitir múltiplos envios manuais idênticos para o mesmo destinatário, o fluxo manual poderá incorporar um componente temporal (`timestamp`) ou `UUID` ao cálculo do hash, sem alterar o comportamento dos fluxos automáticos.

Até nova decisão arquitetural, permanece obrigatório o comportamento determinístico para todos os produtores da tabela `whatsapp_outbox`.

---

## 📊 Baseline Oficial — API Oficial Meta em Produção

A implantação da API Oficial Meta foi promovida para produção no ambiente Condomeet.

### Premissas Obrigatórias:

1. **system_superadmins como Fonte Única:** A tabela `system_superadmins` é a única fonte de verdade para privilégios administrativos globais.
2. **Sem Listas Estáticas (Hardcode):** É proibido utilizar listas hardcoded de e-mails em frontend ou backend.
3. **Módulos Exclusivos:** O Dashboard e o Chat da API Oficial são módulos exclusivos para SuperAdmins.
4. **Isolamento do Ecossistema WhatsApp:** O módulo opera exclusivamente sobre Views, RPCs e tabelas próprias do ecossistema WhatsApp.
5. **Sem Impacto Transacional:** Nenhuma consulta do dashboard poderá impactar:
   - workers;
   - filas de envio;
   - webhooks Meta;
   - processamento transacional.
6. **Vínculo com Condomínio:** Todas as mensagens enviadas pela plataforma devem possuir obrigatoriamente um `condominio_id` válido.
7. **Aderência Financeira:** O custo consolidado dos condomínios deve possuir aderência integral com o custo global da Meta.
8. **Banco Oficial Único:** O ecossistema opera exclusivamente sobre o banco oficial `avypyaxthvgaybplnwxu` (`condomeet_Antigravity`). O banco legado `ivdgvpvifhfiktolmbvy` está descontinuado e proibido.

### Status:
- Produção: **APROVADO**
- Observabilidade: **ATIVA**
- Billing futuro: **COMPATÍVEL**
- Hardening: **CONCLUÍDO**

---

## 📊 Baseline Oficial — Módulo de Visitantes (convites)

A migração estrutural do módulo de visitantes foi concluída, e a arquitetura final está homologada em produção.

### Premissas Obrigatórias:
1. **Relação de Produção Única**: O módulo de visitantes utiliza exclusivamente a tabela física `public.convites` para persistência, leitura e escrita de dados.
2. **Estrutura Legacy Descontinuada**: Toda a estrutura legada anterior (`vw_convites_legacy`, `tb_autorizacao_visitante`, `fn_convites_view_insert` e respectivos triggers e relacionamentos) está oficialmente descontinuada e expurgada.
3. **Estratégia de Alteração de Schema**: Futuras alterações estruturais neste módulo devem seguir obrigatoriamente a estratégia *Expand → Migrate → Contract (Cleanup)* para garantir indisponibilidade zero e compatibilidade retroativa.
4. **Preservação de Backups**: Backups estruturais e de dados permanentes devem ser obrigatoriamente preservados antes de qualquer operação DDL destrutiva.
5. **Documento de Referência**: O Walkthrough desta migração (`walkthrough.md`) passa a ser o documento oficial de referência arquitetural e operacional para este módulo.

---

## 📊 Baseline Oficial — WhatsApp Split-Worker (Fase 1)

A evolução de infraestrutura da Fase 1 da arquitetura Split-Worker do enfileirador de WhatsApp encontra-se homologada e congelada.

### Diretrizes e Premissas de Projeto (Fase 1):
1. **Fila Única Relacional**: A persistência e o enfileiramento baseiam-se estritamente na tabela física `public.whatsapp_outbox` como fonte única da verdade para mensagens enviadas.
2. **Workers Dinâmicos Desacoplados**: O processamento é dividido em dois workers concorrentes gerenciados por parâmetros HTTP:
   * **Alta Prioridade (`queue=high`)**: Lock de lease `'high_priority'`, processa faixas `[1, 5]`, cooldown curto (1s a 3s).
   * **Baixa Prioridade (`queue=low`)**: Lock de lease `'low_priority'`, processa faixas `[6, 99]`, cooldown longo (12s a 17s) com Safe Mode (20s).
3. **Classificação Desacoplada (message_type)**: O helper `smartSend()` popula explicitamente a coluna operacional `message_type` no banco (valores: `'SOS'`, `'CONVITE'`, `'LIBERACAO_VISITANTE'`, `'ENCOMENDA'`, `'AVISO'`), permitindo que queries de observabilidade analisem SLAs e volumes de negócio sem realizar buscas textuais ou parses de JSON.
4. **Convenção Oficial de Prioridades Numéricas**:
   * Prioridade `1` ➔ SOS (Canal High)
   * Prioridade `2` ➔ Convites / Liberações (Canal High)
   * Prioridade `3` a `5` ➔ Reservado para eventos críticos transacionais (Canal High)
   * Prioridade `6` a `9` ➔ Reservado para canais futuros (Canal Low)
   * Prioridade `10` ➔ Encomendas / Entregas (Canal Low)
   * Prioridade `15` ➔ Avisos / Comunicados (Canal Low)
   * Prioridade `≥20` ➔ Lembretes de cobrança / Rotinas em lote (Canal Low)
5. **Compatibilidade Provisória**: O worker aceita o parâmetro temporário `queue=all` (lock `'singleton'`, faixas `[1, 99]`) para garantir transição suave sem indisponibilidade.
6. **Estratégia de Rollback**:
   * **Na Janela de Migração**: Reversão para a cron sem parâmetros (modo `'all'` unificado sob o lease `'singleton'`).
   * **Pós-Descontinuação do Modo 'all'**: Direcionar a cron rápida para a cron lenta usando parâmetros operacionais válidos, ou reverter a Edge Function e DDLs para a versão singleton original.

### Escopo Excluído (Fase 2):
A desativação definitiva do modo retrocompatível `all`, a ativação de crons paralelas em produção, a validação de SLAs funcionais de entrega e a aplicação de otimizações de throughput estão fora do escopo desta baseline da Fase 1, constituindo entregáveis estritos da Fase 2.

---

## 📊 Baseline Oficial — Priorização de Mensagens por Tipo de Evento (smartSend)

A prioridade das mensagens emitidas pelo ecossistema Condomeet é determinada **exclusivamente pelo tipo do evento de negócio (`messageType`)**, com resolução centralizada no helper `smartSend()` a partir do mapa imutável `EVENT_PRIORITY_MAP`.

### Diretrizes e Regras de Governança:
1. **Contrato de Tipos Único:** É proibido criar strings literais soltas de tipo de mensagem espalhadas pelo código. Todas as Edge Functions devem obrigatoriamente importar as constantes tipadas do arquivo compartilhado `supabase/functions/_shared/message_types.ts` (`MessageType`).
2. **Validação Rígida:** O `smartSend()` valida se o `messageType` recebido pertence ao conjunto homologado `VALID_MESSAGE_TYPES`.
3. **Resolução de Prioridade e Fila:**
   * `MessageType.SOS` / `MessageType.OTP` ➔ Prioridade `1` (`queue=high`)
   * `MessageType.VISITOR_INVITE` / `MessageType.VISITOR_AUTHORIZED` ➔ Prioridade `2` (`queue=high`)
   * `MessageType.PARCEL` ➔ Prioridade `10` (`queue=low`)
   * `MessageType.NOTICE` ➔ Prioridade `15` (`queue=low`)
   * `MessageType.FINANCIAL` ➔ Prioridade `20` (`queue=low`)
4. **Fase de Transição e Fallback:** Durante as Fases 1 e 2, invocações com `messageType` ausente ou não homologado acionarão o fallback temporário por texto (`includes(...)`), emitindo obrigatoriamente um warning estruturado de observabilidade (`DEPRECATED_FALLBACK_TRIGGERED`).
5. **Remoção Definitiva (Fase 3):** Na Fase 3, o fallback por texto será totalmente expurgado, tornando o `messageType` homologado um requisito obrigatório e rejeitando imediatamente chamadas não conformes com erro explícito.

---

## 📊 Baseline Oficial — Contrato Estruturado de Templates Meta (FASE 2)

A infraestrutura de mensageria via Meta Cloud API opera com **contratos estruturados, fortemente tipados e desacoplados** gravados no nó `message_content.template` da tabela `public.whatsapp_outbox`.

### Diretrizes e Regras de Governança (Fase 2):
1. **Template Registry Centralizado:** O arquivo compartilhado `supabase/functions/_shared/message_types.ts` centraliza a constante imutável `TEMPLATE_REGISTRY`, fortemente tipada por `MessageType`. É proibido manter nomes de templates ou idiomas hardcoded dentro das Edge Functions.
2. **Validação Rígida no `smartSend()`:** Antes de gravar qualquer registro na `whatsapp_outbox`, o `smartSend()` valida a existência do template, a presença do array de parâmetros e a quantidade mínima de parâmetros obrigatórios (`minParameters`). Requisições inconsistentes são rejeitadas com erro estruturado `CONTRACT_VALIDATION_FAILED` e não são persistidas no banco.
3. **Contrato Estruturado Versionado:** O nó `message_content.template` deve obrigatoriamente informar o campo `contract_version` (baseline `contract_version = 1`), permitindo evolução arquitetural e compatibilidade futura sem quebras de schema.
4. **Worker Genérico (Structured First):** Todas as novas mensagens da plataforma utilizam exclusivamente o contrato estruturado. O `whatsapp-outbox-worker` consome diretamente o nó `message_content.template`, injetando os parâmetros ordenados nos placeholders `{{1}}` a `{{N}}` da Meta sem aplicar regras de negócio ou buscar padrões textuais.
5. **Fallback Deprecado para Mensagens Legadas:** O parsing por expressões regulares no Worker permanece estritamente marcado como `[DEPRECATED_REGEX_FALLBACK]`, atuando de forma secundária apenas para garantir compatibilidade temporária com mensagens legadas enfileiradas. Sua remoção definitiva ocorrerá na Fase 3 após auditoria comprovar zero utilização.

---

## 📊 Baseline Oficial — Identidade Canônica de Telefones (E.164)

A chave lógica e de relacionamento para conversas e telefones no ecossistema Condomeet é unicamente o **Telefone Normalizado no Formato E.164 sem o sinal `+`** (`55` + DDD + Número).

### Diretrizes e Regras de Governança:
1. **Fonte Única da Verdade:** A função `normalizePhone()` localizada em `supabase/functions/_shared/botconversa.ts` e seus equivalentes oficiais são a **única fonte da verdade** para a regra de normalização de telefones na aplicação.
2. **Proibição de Duplicação de Regras no Banco:** Funções SQL de normalização criadas em migrations destinam-se exclusivamente à etapa única de saneamento e migração de dados legados, não devendo se tornar dependência permanente das rotinas da aplicação.
3. **Normalização Obrigatória Pré-Persistência e Comparação:** Toda entrada de telefone na plataforma deve obrigatoriamente passar por `normalizePhone()` antes de qualquer persistência, inserção no banco ou comparação de igualdade (cobrindo `smartSend()`, Edge Functions, `whatsapp-outbox-worker`, `whatsapp-webhook`, Server Actions, Chat, API Oficial e novos módulos).
4. **Segregação entre Persistência e Apresentação:**
   - **Banco de Dados / APIs:** Armazenam exclusivamente o telefone canônico E.164 (ex: `5531988887777`).
   - **Interface de Usuário (UI):** Utiliza funções dedicadas de formatação visual (ex: `formatPhone()`), sem jamais mutar ou alterar o valor persistido.
5. **Etapa Obrigatória de Auditoria Pré-Migração:** Antes da execução definitiva de qualquer script de migração no banco de dados, uma etapa de auditoria deverá gerar um relatório formal contendo:
   - Quantidade de telefones já canônicos;
   - Quantidade de telefones a serem alterados;
   - Registros duplicados a serem consolidados;
   - Conflitos potenciais e impacto estimado.
   A migração no banco só poderá ser executada após aprovação explícita desse relatório de auditoria.

---

## 🎯 Critérios de Aceite da Baseline FASE 2

A FASE 2 será considerada totalmente concluída quando todos os critérios abaixo estiverem atendidos:

1. **Piloto Real Park:** Estabilizado em produção.
2. **Fluxos Homologados:** Testes ponta a ponta concluídos com sucesso (envio, entrega, leitura e histórico).
3. **Auditoria de Telefones:** Auditoria da identidade canônica de telefones concluída e aprovada.
4. **Migração Segura:** Migração dos telefones legados executada sem perda de histórico.
5. **Estabilidade Meta Cloud API:** Zero novos incidentes críticos relacionados à Meta Cloud API durante o período de observação assistida do piloto.
6. **Sincronização de Documentação:** Documentação técnica e `AGENTS.md` mantidos em 100% de sincronismo com a implementação implantada.

> **Restrição de Desenvolvimento:** Enquanto estes criteria não forem atingidos, são autorizados apenas correções de bugs, ajustes operacionais e melhorias de estabilidade. Fica expressamente vedada qualquer alteração arquitetural da FASE 2 sem abertura de uma nova RFC.

---

## 🔒 Governança Pós-Baseline

Após a aprovação desta Baseline:

- Correções de bugs, ajustes operacionais, melhorias de desempenho e atividades de estabilização são permitidas, desde que não alterem os contratos públicos definidos nesta FASE.
- Qualquer alteração de arquitetura, contratos públicos, modelo de dados, protocolo Structured First, Template Registry ou identidade canônica de telefones exigirá abertura de uma nova RFC e atualização prévia do `AGENTS.md`.

---

## 🛡️ Baseline Permanente — Governança de Funções SQL Críticas e Mensageria

Após a resolução e homologação do Incidente de Regressão do Módulo de Encomendas (21/07/2026), ficam estabelecidas as seguintes regras obrigatórias de governança permanente para todo o ecossistema Condomeet:

### 1. Diretrizes de Infraestrutura e DDL Crítico
- **Classificação de Infraestrutura Crítica:** Funções SQL críticas (`push_notify_parcel`, `smartSend`, `claim_single_whatsapp_message`, `notify_parcel_arrival` e demais funções de integração externa com Meta, WhatsApp, FCM, Edge Functions ou `pg_net`) são consideradas **componentes críticos de infraestrutura**.
- **Alteração Exclusiva via Migration Oficial:** Toda e qualquer alteração nessas funções deverá ocorrer exclusivamente por arquivo de migration oficial do Supabase mantido no repositório Git.
- **Proibição de Redefinições Concorrentes:** É estritamente proibida a existência de migrations concorrentes que redefinam a mesma função SQL sem prévia consolidação do código homologado.
- **Proibição de Sobrescrita Histórica:** É expressamente proibida a reaplicação ou reexecução de migrations históricas que sobrescrevam versões de funções SQL já homologadas em produção.
- **Fonte de Verdade vs Auditoria via `pg_proc`:** O versionamento oficial da plataforma é realizado exclusivamente pelas migrations do repositório Git. A visão de sistema `pg_proc` é utilizada unicamente como mecanismo de auditoria e validação da definição efetivamente instalada no banco após a aplicação da migration. Qualquer divergência entre o código da migration oficial do repositório e o `pg_proc` deverá ser tratada como incidente de governança e investigada antes da realização de novas alterações.
- **Menor Delta Funcional Baseado em `pg_proc`:** Antes da elaboração de qualquer migration corretiva, deverá ser realizada uma comparação entre a definição oficial versionada nas migrations do repositório e a definição efetivamente instalada no banco (`pg_proc`). O objetivo é confirmar que o ambiente encontra-se consistente. Caso exista divergência entre a migration oficial e o código compilado em `pg_proc`, a divergência deverá ser tratada como incidente de governança antes da implementação da alteração. Confirmada a consistência, a migration corretiva deverá representar apenas o menor delta funcional necessário para atender ao requisito.
- **Escopo Estritamente Corretivo para Incidentes:** Correções de incidentes em produção deverão ser estritamente corretivas, sendo vedadas refatorações, mudanças de contrato, alterações de payload, reorganizações de código ou melhorias não diretamente relacionadas ao incidente.

### 2. Protocolo de Validação Pós-Migration (Ciclo em 8 Etapas)
Toda alteração em funções críticas deverá obrigatoriamente possuir homologação ponta a ponta contendo evidências de:
1. **SQL (`pg_proc`):** Confirmação da definição final da função compilada no banco.
2. **Trigger:** Inserção do evento de negócio e confirmação de execução da trigger.
3. **Edge Function:** Chamada HTTP realizada com sucesso.
4. **Outbox:** Criado registro em `whatsapp_outbox` com `message_type`, `contract_version = 1` e `message_hash`.
5. **Worker:** Consumo pelo worker e transição de status para `sent`.
6. **Meta API:** Retorno de HTTP 200 com Message ID (`wamid`) válido.
7. **Webhook:** Atualização automática dos status `sent`, `delivered` e `read`.
8. **Chat:** Exibição correta da mensagem no histórico da API Oficial.

### 3. Checklist Obrigatório de Não-Regressão
Antes da homologação final em produção, deverá ser executado o checklist de validação dos 6 fluxos vitais da plataforma:
- [ ] `VISITOR_INVITE` (Convites de visitantes)
- [ ] `VISITOR_AUTHORIZED` (Liberações de entrada na portaria)
- [ ] `PARCEL` (Notificações de encomendas)
- [ ] `SOS` (Alertas de emergência)
- [ ] `RESERVAS` (Confirmações de áreas comuns)
- [ ] `AVISOS` (Comunicados do condomínio)

### 4. Registro de Baseline Histórica
- **Incidente 21/07/2026 (Módulo de Encomendas):** Regressão na função `public.push_notify_parcel()` corrigida via migration `20260721_fix_push_notify_parcel_dual_channel.sql`. Homologação ponta a ponta aprovada e convertida na presente Baseline Oficial de Governança.

> **Observação de Governança:** Esta baseline estabelece regras de governança e validação operacional, não substituindo o fluxo oficial de versionamento por migrations do Supabase.

---

## Baseline Permanente — BotConversa como Provedor Primário

Status: HOMOLOGADO E CONGELADO

A arquitetura oficial do ecossistema WhatsApp do Condomeet passa a adotar como configuração permanente:

- Provedor Primário: BOTCONVERSA
- Provedor de Contingência (Failover): META_CLOUD_API

### Estado homologado

- BOTCONVERSA autenticado e operacional.
- BOTCONVERSA_API_KEY obrigatoriamente armazenada nos Supabase Secrets.
- Health Check operacional (HTTP 200).
- Runtime com active_provider = BOTCONVERSA.
- Meta Cloud API mantida exclusivamente como contingência.
- message_hash obrigatório em toda inserção na whatsapp_outbox.
- Deduplicação SHA-256 mantida.
- Worker de Outbox homologado.
- Circuit Breaker homologado.
- Failover homologado.
- Auto Recovery homologado.

### Regras Permanentes

É proibido:

- inverter os provedores sem nova homologação;
- remover a Meta Cloud API do ambiente;
- alterar a estratégia de failover sem atualização desta baseline;
- criar novos fluxos de envio sem utilização do message_hash oficial.

Qualquer alteração nesta arquitetura exige nova homologação formal e atualização do AGENTS.md.

---

## 📊 Baseline Permanente — Notificações de Autorização de Visitantes

Status: HOMOLOGADA E CONGELADA

### Objetivo

Padronizar o comportamento oficial do módulo de autorização de visitantes do Condomeet.

### Regras Permanentes

1. Toda autorização de visitante registrada com sucesso deverá gerar uma notificação de confirmação ao morador solicitante.

2. Caso o telefone do visitante seja informado, deverá ser gerada também uma notificação independente para o visitante.

3. As notificações deverão ser produzidas exclusivamente através da arquitetura oficial de mensageria:

UI
→ Edge Function
→ smartSend()
→ whatsapp_outbox
→ Worker
→ BOTCONVERSA
→ META Cloud API (contingência)

É proibido enviar mensagens diretamente pela UI ou por Edge Functions sem utilizar `smartSend()`.

4. Todas as mensagens deverão obedecer às regras oficiais de:

- message_hash obrigatório;
- deduplicação SHA-256;
- prioridade definida por `message_type`;
- persistência na `whatsapp_outbox`;
- roteamento via `active_provider`.

5. A interface deverá informar ao usuário o resultado do envio da notificação, distinguindo claramente:

- autorização registrada;
- WhatsApp enviado com sucesso;
- WhatsApp não enviado.

A falha no envio da notificação não invalida a autorização registrada.

### Governança

Qualquer alteração neste fluxo deverá preservar a arquitetura oficial de mensageria e passar por nova homologação antes de atualização desta baseline.

---

## 📊 Baseline Permanente — Processamento Imediato da WhatsApp Outbox

Status: **HOMOLOGADA E CONGELADA**

### Objetivo

Garantir processamento em tempo quase real das mensagens da `whatsapp_outbox`, preservando toda a arquitetura oficial de mensageria do Condomeet.

### Regras Permanentes

1. Toda mensagem inserida com sucesso na `whatsapp_outbox` poderá acionar imediatamente o `whatsapp-outbox-worker` de forma assíncrona (Fire & Forget).

2. O disparo imediato NÃO substitui o `pg_cron`.
   O `pg_cron` permanece obrigatório como mecanismo oficial de recuperação (fallback), garantindo processamento mesmo quando o wake-up imediato não ocorrer.

3. Toda tentativa de processamento deverá continuar respeitando obrigatoriamente:
   - `worker_leases`;
   - `acquire_worker_lease()`;
   - exclusão mútua;
   - advisory locks;
   - `claim_single_whatsapp_message()`;
   - `FOR UPDATE SKIP LOCKED`.

4. É proibida qualquer implementação que permita múltiplos workers processando simultaneamente a mesma fila lógica.

5. O wake-up imediato não poderá alterar:
   - `active_provider`;
   - `fallback_provider`;
   - `circuit breaker`;
   - política de retry;
   - deduplicação;
   - `message_hash`;
   - arquitetura oficial de failover.

### Governança

Toda evolução futura do worker deverá preservar o modelo Singleton baseado em leases e manter o `pg_cron` como mecanismo oficial de recuperação.












---

## 🛡️ Baseline Permanente — Gerenciamento Oficial de Templates da Meta (LOCKED)

Toda Edge Function, Worker ou serviço que envie mensagens utilizando templates da API Oficial da Meta deverá consultar previamente o MetaTemplateService para resolver automaticamente o template correto.

É proibido utilizar nomes de templates hardcoded no código.

O MetaTemplateService (whatsapp-template-manager) passa a ser a única fonte oficial de resolução, sincronização e gerenciamento dos templates do Condomeet.

O sistema nunca deverá solicitar novamente o WABA_ID ou PHONE_NUMBER_ID ao operador, devendo consumir essas configurações oficiais do ambiente. O META_ACCESS_TOKEN continuará sendo obtido através do Vault/Secrets.

A sincronização de templates deve ser bidirecional e nunca recriar templates existentes, servindo apenas para atualizar metadados (status, versão, qualidade) na tabela oficial do sistema.

---

## 🛡️ Baseline Oficial — MetaTemplateService

MetaTemplateService passa a ser a única camada autorizada para criação, sincronização, resolução e utilização dos templates da API Oficial da Meta.

Fica proibido:
- utilizar nomes hardcoded de templates;
- chamar diretamente endpoints da Graph API relacionados a templates;
- criar templates manualmente por qualquer Edge Function, Worker ou serviço fora do MetaTemplateService.

Toda evolução futura deverá obrigatoriamente utilizar esta camada centralizada.

Status: BASELINE OFICIAL CONGELADA.


### 👑 Governança Funcional e Técnica

Todo novo módulo do Condomeet deverá indicar explicitamente o proprietário funcional dos templates que criar.

O MetaTemplateService permanece como proprietário técnico único da infraestrutura de templates.

---

## 🛡️ Baseline Oficial — Recuperação de Senha via WhatsApp (OTP AUTHENTICATION)

Status: **HOMOLOGADA E CONGELADA** (29/07/2026)

### Objetivo
Padronizar o comportamento oficial do fluxo de recuperação de senha (OTP) via WhatsApp no ecossistema Condomeet, garantindo 100% de conformidade com as regras da Meta Cloud API e do MetaTemplateService.

### Regras Permanentes
1. **MessageType Oficial & Roteamento Global Meta:** Todo envio de código de verificação ou recuperação de senha deverá utilizar exclusivamente `MessageType.OTP` (prioridade `1`, fila `high`). As mensagens de autenticação (`OTP`) possuem roteamento global prioritário para a `META_CLOUD_API`, independentemente do estágio de transição do piloto do condomínio. Quando o template `condomeet_recuperacao_senha_v1` possuir status `APPROVED`, o disparo será 100% direcionado para a Meta Cloud API.
2. **Fonte Única de Resolução:** O `MetaTemplateService` (via `TEMPLATE_REGISTRY` e a RPC `resolve_whatsapp_template()`) é a única fonte autorizada para resolução do template de recuperação de senha (`condomeet_recuperacao_senha_v1`, categoria `AUTHENTICATION`).
3. **Proibição de Texto Livre na Meta:** É expressamente proibido enviar mensagens de recuperação de senha como texto livre quando o provider ativo for Meta Cloud API. Todas as mensagens OTP enviadas via Meta deverão utilizar obrigatoriamente o template `AUTHENTICATION` aprovado.
4. **Contrato Estruturado Único:** Todos os providers de transporte (`META_CLOUD_API` e `BOTCONVERSA`) deverão consumir a mesma representação lógica e o mesmo contrato estruturado gravado em `whatsapp_outbox.message_content.template`.
5. **Worker Desacoplado (template_renderer.ts):** É proibido ao `whatsapp-outbox-worker` interpretar ou manipular diretamente a estrutura interna do `definition_payload` (ex: `components`, `type: "body"`, placeholders). O worker deverá utilizar exclusivamente o módulo compartilhado `template_renderer.ts` (`renderTemplateText()`) para obter o texto renderizado quando o transporte exigir envio por texto (BotConversa).
6. **Sincronismo Estrito de Status Meta (PENDING → APPROVED):** É expressamente proibido registrar o status `APPROVED` no banco de dados local (`whatsapp_meta_templates`) antes da confirmação oficial emitida pela Meta Cloud API. Novos templates devem ser cadastrados como `PENDING` e transitar para `APPROVED` apenas após a aprovação na WABA. A RPC `resolve_whatsapp_template()` filtra estritamente por `status = 'APPROVED'`, garantindo zero falso-positivo.

### Governança Funcional e Técnica
Qualquer evolução no fluxo de recuperação de senha deverá manter intactas a geração do OTP, as regras de expiração (5min), o rate limit triplo e o contrato estruturado com o MetaTemplateService.

---

## 🛡️ Baseline Permanente — Governança Preventiva de Templates Meta (LOCKED)

Status: **HOMOLOGADA E CONGELADA** (29/07/2026)

### Regras Permanentes
1. **Validação Preventiva Obrigatória:** Antes de qualquer chamada à Graph API da Meta Cloud API (`POST /v21.0/{PHONE_NUMBER_ID}/messages`), o sistema (Edge Functions, `smartSend()` e `whatsapp-outbox-worker`) DEVERÁ consultar obrigatoriamente a RPC `resolve_whatsapp_template()`.
2. **Bloqueio Preventivo em Caso de NULL:** Se `resolve_whatsapp_template()` retornar `NULL` (devido a status `PENDING`, `REJECTED`, `DISABLED` ou ausência de cadastro):
   - É **EXPRESSAMENTE PROIBIDO** realizar chamadas HTTP à Graph API da Meta;
   - É **EXPRESSAMENTE PROIBIDO** registrar envios fáticos com templates não-aprovados;
   - O worker/serviço DEVERÁ emitir log estruturado de aviso:
     `Template '[nome_template]' não está APPROVED na WABA Meta. Envio bloqueado preventivamente.`
   - O erro da Meta 132001 (HTTP 404) passa a ser **EVITADO PREVENTIVAMENTE** antes da chamada à Graph API.
3. **Conjunto Padronizado de Estados de Templates:** Todo template no ecossistema Condomeet deverá utilizar estritamente um dos seguintes estados padronizados:
   - `PENDING`: Submetido e aguardando homologação na Meta WABA;
   - `APPROVED`: Aprovado pela Meta e liberado para envio transacional;
   - `REJECTED`: Rejeitado pela Meta com motivo registrado em `rejected_reason`;
   - `DISABLED`: Desativado pela administração ou suspenso pela Meta;
   - `ARCHIVED`: Descontinuado e preservado para histórico/auditoria.
4. **Fidelidade de Sincronismo Meta:** Toda rotina de sincronização entre a Meta e `whatsapp_meta_templates` deverá espelhar exatamente o status retornado pela Graph API, sendo proibido qualquer artifício que antecipe o estado `APPROVED` no banco local antes da aprovação na WABA.
5. **Proibição de Atualização Manual para APPROVED:** Fica expressamente proibido atualizar manualmente o campo `status` da tabela `whatsapp_meta_templates` para `APPROVED` sem confirmação oficial obtida via Graph API ou WhatsApp Manager da Meta.
6. **Sincronização Automatizada via MetaTemplateService:** Toda alteração de status local deverá ocorrer via sincronização da Graph API realizada preferencialmente pelo serviço `whatsapp-template-manager` (ação `sync`). Toda atualização de status DEVERÁ registrar a data/hora exata em `last_synced_at` e manter o payload oficial retornado pela Meta em `meta_payload`.
7. **Identificação Oficial de Rastreabilidade (`meta_template_id`):** O campo `meta_template_id` armazena o ID numérico oficial retornado pela Graph API da Meta. Esse identificador é utilizado estritamente para auditoria, rastreabilidade e sincronização, sem substituir o nome do template como chave lógica de negócio do ecossistema Condomeet.
8. **Preservação de Campos de Auditoria:** Toda rotina de sincronização DEVERÁ atualizar obrigatoriamente os campos `meta_template_id`, `last_synced_at`, `meta_payload` e `quality_score`.
9. **Guarda de Validação de Divergência de ID:** A cada sincronização executada pelo `whatsapp-template-manager`, o sistema valida se o `meta_template_id` retornado da Graph API corresponde ao `meta_template_id` já persistido localmente.
10. **Bloqueio por Divergência de ID:** Em caso de divergência de `meta_template_id` para um mesmo nome de template, o sistema DEVERÁ:
    - Emitir log de erro estruturado `TEMPLATE_ID_DIVERGENCE_DETECTED`;
    - Bloquear a sincronização automática daquele template;
    - Exigir intervenção e validação administrativa manual antes de qualquer atualização.

---

## 🏆 Baseline Final — Critério Oficial de Homologação do Módulo de Recuperação de Senha via WhatsApp (LOCKED)

Status Operacional Atual: **`STATUS: IMPLEMENTADO, PORÉM AGUARDANDO HOMOLOGAÇÃO OPERACIONAL META`**

A arquitetura, governança, contrato estruturado, renderização unificada (`template_renderer.ts`), sincronização e auditoria dos templates Meta encontram-se totalmente homologadas no código.

Entretanto, o módulo de **Recuperação de Senha via WhatsApp** somente será classificado como **HOMOLOGADO EM PRODUÇÃO** quando TODOS os 8 critérios abaixo forem atendidos simultaneamente:

1. **Permissões no System User:** O System User possuir permissão `whatsapp_business_management` sobre a WABA oficial (`2264548117365601`).
2. **Escopos do Access Token:** O Access Token em produção possuir simultaneamente os escopos:
   - `whatsapp_business_messaging`
   - `whatsapp_business_management`
3. **Existência do Template na WABA:** O template oficial `condomeet_recuperacao_senha_v1` existir cadastrado na WABA oficial.
4. **Status APPROVED Confirmado:** O template possuir status `APPROVED` confirmado diretamente via Meta Graph API.
5. **Sincronização de Auditoria Completa:** A sincronização oficial registrar no banco de dados local (`whatsapp_meta_templates`):
   - `meta_template_i---

## 📜 REGISTRO FINAL E ENCERRAMENTO DA ENGENHARIA — Módulo de Recuperação de Senha via WhatsApp (OTP Authentication) (LOCKED)

Data de Encerramento da Engenharia: **29/07/2026**

Registra-se oficialmente a consolidação do encerramento formal da engenharia do módulo de **Recuperação de Senha via WhatsApp (OTP Authentication)** como baseline oficial e congelada. Este registro substitui quaisquer registros parciais anteriores relacionados ao encerramento.

### 📌 Estado Oficial Registrado do Módulo
`STATUS: ENGENHARIA CONCLUÍDA, AGUARDANDO HOMOLOGAÇÃO OPERACIONAL META`

---

### 📚 Histórico Consolidado dos Entregáveis da Engenharia
- **Arquitetura FASE 2:** Baseada em contratos estruturados e versionados;
- **MessageType.OTP:** Tipagem estrita com prioridade `1` (fila `high`);
- **TEMPLATE_REGISTRY:** Mapeamento imutável por tipo de evento de negócio;
- **template_renderer.ts:** Módulo compartilhado para renderização de texto unificada sem acoplamento do worker ao payload;
- **MetaTemplateService:** Camada centralizada e RPC `resolve_whatsapp_template()` com filtro estrito de aprovação (`WHERE status = 'APPROVED'`);
- **Governança Oficial dos Templates Meta:** Fluxo oficial `PENDING` $\rightarrow$ `APPROVED` sem falso-positivo local;
- **Sincronização Oficial via Graph API:** Automação em `whatsapp-template-manager` (ação `sync`);
- **Rastreabilidade por meta_template_id:** Registro e persistência de `meta_template_id`, `last_synced_at`, `meta_payload` e `quality_score`;
- **Auditoria de Divergência de Templates:** Emissão de log `TEMPLATE_ID_DIVERGENCE_DETECTED` e bloqueio de sync automático em caso de incompatibilidade de ID;
- **Bloqueio Preventivo para Templates Não Aprovados:** Validação pré-Graph API no `smartSend` e worker (mitigação preventiva do erro Meta 132001 / HTTP 404);
- **Integração com whatsapp-outbox-worker:** Consumo puro de contratos estruturados;
- **Testes Unitários & Testes E2E:** Suíte automatizada em `password_reset_whatsapp_e2e_test.ts` (100% aprovada);
- **Smoke Test Operacional CLI:** Utilitário `run_password_reset_smoke_test.ts` (100% aprovado);
- **Baseline de Homologação:** Diretrizes de integridade arquitetural;
- **Baseline Complementar do Critério 8:** Detalhamento do teste funcional em produção e evidências obrigatórias;
- **Critérios Oficiais de Homologação em Produção:** Régua com 8 condições restritivas;
- **Termo de Encerramento da Engenharia:** Encerramento oficial do ciclo de desenvolvimento de software.

---

### 🏆 Régua dos 8 Critérios Oficiais para Homologação em Produção
A transição para `STATUS: HOMOLOGADO EM PRODUÇÃO` somente poderá ocorrer após evidência objetiva de que TODOS os 8 critérios abaixo forem atendidos simultaneamente:

1. **Permissão no System User:** Permissão `whatsapp_business_management` concedida ao System User (`122100934695392451`) na WABA oficial (`2264548117365601`).
2. **Escopos do Access Token:** Access Token de produção contendo os escopos `whatsapp_business_messaging` e `whatsapp_business_management`.
3. **Existência do Template na WABA:** Template `condomeet_recuperacao_senha_v1` existente na WABA oficial.
4. **Status APPROVED na Meta:** Template com status `APPROVED` confirmado pela Graph API da Meta.
5. **Sincronização de Auditoria Completa:** Sincronização oficial refletindo no banco: `meta_template_id`, `status` (`APPROVED`), `quality_score`, `last_synced_at` e `meta_payload`.
6. **Resolução por RPC:** RPC `resolve_whatsapp_template('recuperacao_senha')` retornando o template ativo.
7. **Disparo pelo Worker:** `whatsapp-outbox-worker` realizando o envio via Meta Cloud API com resposta HTTP 200/201 sem erros.
8. **Validação Funcional em Produção (Critério de Aceite Final):** Execução bem-sucedida de um fluxo real em produção, comprovando:
   - [ ] Solicitação de recuperação de senha pelo aplicativo;
   - [ ] Geração do OTP;
   - [ ] Persistência do OTP na tabela `password_reset_codes`;
   - [ ] Registro da mensagem na `whatsapp_outbox`;
   - [ ] Processamento pelo `whatsapp-outbox-worker`;
   - [ ] Envio pela Meta Cloud API sem erros;
   - [ ] Recebimento da mensagem pelo usuário;
   - [ ] Validação correta do OTP;
   - [ ] Redefinição da senha;
   - [ ] Autenticação bem-sucedida utilizando a nova senha.

#### 📑 Evidências Obrigatórias
A homologação para `STATUS: HOMOLOGADO EM PRODUÇÃO` deverá ser obrigatoriamente acompanhada das seguintes evidências:
- Logs estruturados do `smartSend`;
- Logs estruturados do `whatsapp-outbox-worker`;
- Resposta HTTP 200/201 da Graph API da Meta;
- Registros de auditoria na tabela `whatsapp_meta_templates` (`meta_template_id`, `status`, `last_synced_at`, `quality_score`, `meta_payload`);
- Confirmação funcional do fluxo completo executado no aplicativo em ambiente de produção.

---

### 🔄 Critério Oficial de Reabertura do Módulo
Após o encerramento da engenharia, este módulo somente poderá ser reaberto mediante uma das seguintes condições:
- Alteração da API ou das políticas da Meta que impactem a arquitetura vigente;
- Identificação de defeito funcional reproduzível em produção;
- Aprovação formal de uma RFC para evolução funcional;
- Requisitos regulatórios ou de segurança que exijam adequações.

*Nota: Demandas operacionais, criação de templates, concessão de permissões, aprovações da Meta ou configurações da WABA não caracterizam reabertura da engenharia do módulo.*

---

### 🔒 Diretrizes Permanentes Pós-Encerramento
1. Considera-se oficialmente encerrado o ciclo de engenharia deste módulo.
2. A partir desta data, **são permitidas apenas atividades operacionais de homologação na Meta** até que os critérios oficiais sejam integralmente atendidos.
3. Não deverão ser adicionadas novas funcionalidades ou alterações de código sem a abertura formal de uma RFC ou Sprint aprovada.
4. Somente após a validação funcional em produção e a comprovação dos 8 critérios oficiais com suas evidências, o status poderá ser atualizado para `STATUS: HOMOLOGADO EM PRODUÇÃO`.

---

## 🛡️ REGISTRO DE ENCERRAMENTO — TRANSPORTE BOTCONVERSA (LOCKED)

**Data de Registro:** 29/07/2026  
**Status da Engenharia Backend:** 🟢 HOMOLOGADO

---

### 📌 Diretrizes Permanentes de Governança de Transporte

1. **Backend Homologado:** O backend da plataforma Condomeet foi integralmente homologado.

2. **Integração REST Comprovada:** O fluxo foi validado de ponta a ponta até o aceite da requisição pela API REST do BotConversa, incluindo geração do OTP, persistência em `password_reset_codes`, criação da `whatsapp_outbox`, processamento pelo worker, renderização pelo `template_renderer.ts`, envio HTTP POST e resposta síncrona `HTTP 200 OK`.

3. **Limitação do Provedor Terceirizado:** O provedor BotConversa não fornece webhooks de rastreamento de entrega (`delivered`) e leitura (`read`) para mensagens enviadas por sua API REST.

4. **Fronteira de Responsabilidade:** Validações relativas à fila interna do provedor, estado da instância WhatsApp, conexão via QR Code ou exibição na interface gráfica do BotConversa constituem validações operacionais do fornecedor e não da engenharia do Condomeet.

5. **Homologação Definitiva da Mensageria:** O rastreamento completo do ciclo de vida da mensagem (`sent`, `delivered` e `read`) será realizado quando o transporte oficial ocorrer pela Meta Cloud API, utilizando os webhooks nativos da plataforma Meta.

6. **Critério de Reabertura de Engenharia:** Na ausência de evidências de falha na plataforma Condomeet, não serão iniciadas alterações na engenharia do módulo de recuperação de senha ou da infraestrutura de mensageria quando o backend apresentar execução completa até o aceite da API REST do provedor (`HTTP 200 OK`) e não houver erros registrados na plataforma. Investigações deverão concentrar-se prioritariamente na camada operacional do provedor de mensageria ou na Meta Cloud API, conforme o transporte utilizado. A reabertura da engenharia ocorrerá somente mediante evidências objetivas de falha na plataforma Condomeet.

---

## 🛡️ REGISTRO DE BASELINE — ROTEAMENTO OFICIAL DE OTP VIA META (LOCKED)

**Data de Registro:** 29/07/2026  
**Status:** 🟢 **HOMOLOGADA E CONGELADA**

---

### 📌 Diretrizes Permanentes de Roteamento Oficial de OTP

#### 1. Roteamento Global Prioritário
O `MessageType.OTP` utiliza a regra global prioritária de roteamento para a `META_CLOUD_API`, independentemente do estágio de transição do piloto do condomínio.

#### 2. Descontinuação do BotConversa para Autenticação
Na arquitetura oficial vigente, o provider `BOTCONVERSA` não é considerado um transporte válido para mensagens de autenticação (`MessageType.OTP`), permanecendo apenas para os fluxos oficialmente definidos para esse provider.

#### 3. Bloqueio Preventivo por Status do Template
Enquanto o template `condomeet_recuperacao_senha_v1` permanecer com status `PENDING` (ou qualquer status diferente de `APPROVED`) na tabela `whatsapp_meta_templates`, o worker deverá bloquear preventivamente e de forma intencional o envio antes da chamada à Meta Graph API, registrando obrigatoriamente o motivo na auditoria da outbox.

#### 4. Comutação Automática Pós-Aprovação
Após o template `condomeet_recuperacao_senha_v1` atingir status `APPROVED` na WABA da Meta e esse status ser sincronizado para a tabela `whatsapp_meta_templates` pelo `whatsapp-template-manager`, os disparos de `MessageType.OTP` utilizarão automaticamente a `META_CLOUD_API`, sem necessidade de alterações de código, configuração adicional ou novo deploy.

#### 5. Critério de Responsabilidade da Engenharia
Falhas no recebimento de `MessageType.OTP` decorrentes exclusivamente do bloqueio preventivo causado pelo status `PENDING` do template não caracterizam defeito da engenharia do Condomeet.

Após o template atingir status `APPROVED`, qualquer falha de envio, entrega ou processamento deverá ser objeto de nova auditoria técnica, seguindo o fluxo oficial de diagnóstico da plataforma.

---

## 🛡️ EXECUTIVE SUMMARY & ENGINEERING SIGN-OFF (LOCKED)

**Date:** 29/07/2026  
**Status:** 🟢 **ENGINEERING SIGN-OFF | HOMOLOGADO | CONGELADO | DOCUMENTAÇÃO OFICIAL**

---

### Summary of Work

- **Engineered & Homologated OTP Authentication Module:** Integrated structured contracts, `MessageType.OTP`, `template_renderer.ts`, and `MetaTemplateService` for WhatsApp password reset workflows.
- **Preventive Governance & Audit:** Implemented pre-Graph API template validation to prevent Meta error #132001 (HTTP 404), deterministic `message_hash` deduplication, and strict template status governance.
- **Global OTP Meta Routing Rule:** Updated `whatsapp-outbox-worker` so that `MessageType.OTP` is globally prioritized for `META_CLOUD_API` whenever Meta credentials are available and the template governance conditions are satisfied, removing pilot-stage dependency from the routing decision.
- **Documentation & Locked Baselines:** Registered all architectural decisions, routing rules, transport boundaries, rate limiting audits, and governance procedures in `.agents/AGENTS.md`.

---

### Outstanding Operational Dependency

The remaining work is operational rather than engineering:
- Confirm or create the template `condomeet_recuperacao_senha_v1` in the Meta WABA (`2264548117365601`);
- Obtain/confirm the required `whatsapp_business_management` permission when applicable;
- Synchronize the template metadata via `whatsapp-template-manager`;
- Perform the final production validation after the template becomes available.

---


---

## 📊 Baseline Oficial — Governança e Contrato de Templates Meta de Encomendas (FASE 3C.3)

A FASE 3C.3 homologou o contrato técnico oficial dos dois templates operacionais de encomendas que devem ser submetidos e aprovados no Meta WhatsApp Business Manager.

### Diretrizes e Regras de Governança dos Templates de Encomendas:

1. **Template de Encomenda Recebida (`condomeet_encomenda_recebida_v2`):**
   - **Nome:** `condomeet_encomenda_recebida_v2`
   - **Categoria:** `UTILITY`
   - **Idioma:** `pt_BR`
   - **Quantidade de Parâmetros:** 9 parâmetros
   - **Botões:** Sem botões
   - **MessageType:** `MessageType.PARCEL`
   - **Versão do Contrato:** `contract_version = 1`

2. **Template de Retirada de Encomenda (`retirada_de_encomenda`):**
   - **Nome:** `retirada_de_encomenda`
   - **Categoria:** `UTILITY`
   - **Idioma:** `pt_BR`
   - **Quantidade de Parâmetros:** 7 parâmetros
   - **Botões:** Sem botões
   - **MessageType:** `MessageType.PARCEL_DELIVERED`
   - **Versão do Contrato:** `contract_version = 2`

3. **Invariabilidade de Contrato:** Os textos e a ordem exata dos parâmetros definidos na FASE 3C.3 constituem o **CONTRATO OFICIAL OBRIGATÓRIO** para o cadastro no Meta WhatsApp Manager. É expressamente proibido alterar o `TEMPLATE_REGISTRY`, `whatsapp-parcel-notify` ou `whatsapp-outbox-worker` para adaptar o código aos templates criados fora da especificação.
4. **Proibição de Forçar Status no Banco:** É expressamente proibido alterar ou inserir manualmente o status `APPROVED` na tabela `public.whatsapp_meta_templates`. O status deve ser proveniente unicamente do retorno oficial da Meta Graph API.
5. **Sequenciamento Operacional de Liberação:**
   - **Etapa Atual (FASE 3C.3):** Depende exclusivamente do cadastro manual e aprovação dos dois templates no painel Meta WhatsApp Business Manager.
   - **Etapa Seguinte (FASE 3C.4):** Após ambos os templates apresentarem status `APPROVED` na Meta, será executada a action `sync` da Edge Function `whatsapp-template-manager` no Projeto A (`avypyaxthvgaybplnwxu`) para sincronizar os dados reais para a tabela `whatsapp_meta_templates` do Projeto B (`ivdgvpvifhfiktolmbvy`).

### Status de Governança da FASE 3C.3:
```text
FASE 3C.3
[X] CONTRATO HOMOLOGADO
[X] PRONTO PARA CADASTRO NA META
[X] AGUARDANDO APROVAÇÃO META
[X] SYNC
[X] FASE 3D
```

---

## 📊 Baseline Oficial — Homologação Definitiva da Meta Cloud API para Encomendas (FASE 3D.13)

**Data de Registro:** 12/08/2026  
**Status:** 🟢 **ENGINEERING SIGN-OFF | HOMOLOGADO | CONGELADO | DOCUMENTAÇÃO OFICIAL**

A FASE 3D (WhatsApp de Encomendas / Meta Cloud API) encontra-se totalmente concluída, auditada e homologada em ambiente de produção para o piloto Real Park.

### Status Final da Homologação:
- [x] **FASE 3C — Templates Meta Homologados:** Templates operacionais sincronizados na tabela `public.whatsapp_meta_templates`.
- [x] **FASE 3D.11 — Canary Chegada de Encomenda:** Fluxo `condomeet_encomenda_recebida_v2` aprovado (`PROVIDER_ACCEPTED` + `SENT` + `DELIVERED`).
- [x] **FASE 3D.12 — Canary Retirada de Encomenda:** Fluxo `retirada_de_encomenda` aprovado (`PROVIDER_ACCEPTED` + `SENT` + `DELIVERED`).
- [x] **Entregabilidade em Produção:** 100% de entregabilidade confirmada via webhook Meta (`delivered`).

---

### Templates Homologados e Versionados:

1. **Template de Chegada de Encomenda (`condomeet_encomenda_recebida_v2`):**
   - **MessageType:** `MessageType.PARCEL`
   - **Versão do Contrato:** `contract_version = 1`
   - **Categoria:** `UTILITY`
   - **Idioma:** `pt_BR`
   - **Quantidade de Parâmetros:** 9 parâmetros
   - **Meta Status:** `APPROVED`
   - **Meta Template ID:** `37488708074107869`

2. **Template de Retirada de Encomenda (`retirada_de_encomenda`):**
   - **MessageType:** `MessageType.PARCEL_DELIVERED`
   - **Versão do Contrato:** `contract_version = 2`
   - **Categoria:** `UTILITY`
   - **Idioma:** `pt_BR`
   - **Quantidade de Parâmetros:** 7 parâmetros
   - **Meta Status:** `APPROVED`
   - **Meta Template ID:** `2051452675456698`

---

### Infraestrutura e Arquitetura de Produção:

- **WABA Oficial:** `2264548117365601`
- **Phone Number ID de Produção:** `983786528153564` (`+55 61 8232-5516`, Status `CONNECTED`, Quality `GREEN`)
- **Versão da Graph API:** `v21.0`
- **Aplicativo Meta:** `Condomeet` (App ID `2320194451814580`)
- **System User:** `Employee` (ASID `122100934695392451`) com vínculo explícito do ativo WABA
- **Secret Access Token:** `WHATSAPP_ACCESS_TOKEN`
- **Secret Phone ID:** `WHATSAPP_PHONE_NUMBER_ID`
- **Worker de Mensageria:** `whatsapp-outbox-worker` (`queue=low`, faixa `[6, 99]`)
- **Webhook oficial:** `whatsapp-webhook` (`https://avypyaxthvgaybplnwxu.supabase.co/functions/v1/whatsapp-webhook`)

---

### Evidências Empíricas de Produção:

- **FASE 3D.11 (Chegada de Encomenda):**
  - Template: `condomeet_encomenda_recebida_v2`
  - Meta HTTP Response: `200 OK`
  - `PROVIDER_ACCEPTED`: SIM
  - `SENT`: SIM
  - `DELIVERED`: SIM (5/5 mensagens entregues aos moradores)
  - Retries efetuados: 0
  - Reprocessamento de backlog: 0

- **FASE 3D.12 (Retirada de Encomenda):**
  - Template: `retirada_de_encomenda`
  - Meta HTTP Response: `200 OK`
  - `PROVIDER_ACCEPTED`: SIM
  - `SENT`: SIM
  - `DELIVERED`: SIM (5/5 mensagens entregues aos moradores)
  - Retries efetuados: 0
  - Reprocessamento de backlog: 0

---

### Saneamento e Registro da Outbox Histórica:

- **Backlog Histórico:** O backlog de 8.928 mensagens represadas entre 29/07/2026 e 12/08/2026 foi permanentemente eliminado do banco de dados conforme autorização operacional prévia.
- **Estado Final da Outbox Histórica:**
  - Backlog antigo represado: 0
  - Mensagens históricas reenviadas: 0
  - Backfill executado: 0
  - Retry histórico: 0

---

### Diretrizes e Regras Permanentes de Governança do Módulo de Encomendas:

1. **Exclusividade de Templates Homologados:** O envio de mensagens do módulo de encomendas deve utilizar exclusivamente os templates homologados no `TEMPLATE_REGISTRY`.
2. **Imutabilidade de Contratos:** É expressamente proibido alterar o nome, idioma, versão do contrato ou a ordem/quantidade de parâmetros dos templates sem a abertura de uma nova RFC e nova homologação técnica.
3. **Proibição de Mutation Manual no Banco:** É expressamente proibido inserir ou atualizar manualmente o status `APPROVED` na tabela `public.whatsapp_meta_templates`.
4. **Sincronização Canônica com Meta Graph API:** O status dos templates no banco de dados deve ser mantido unicamente via sincronização oficial a partir da Meta Graph API (`whatsapp-template-manager`).
5. **Alinhamento WABA × Phone Number ID:** O Phone Number ID de produção (`983786528153564`) deve permanecer estritamente alinhado com a WABA oficial (`2264548117365601`) onde residem os templates homologados.
6. **Proteção da Secret `WHATSAPP_PHONE_NUMBER_ID`:** É proibido alterar o Phone Number ID de produção sem validação prévia do vínculo de ativos na Meta.
7. **Governança do Token do System User (`WHATSAPP_ACCESS_TOKEN`):** Qualquer rotação do `WHATSAPP_ACCESS_TOKEN` exige a validação do System User, a verificação dos escopos (`whatsapp_business_messaging`, `whatsapp_business_management`) e a confirmação do vínculo explícito dos ativos WABA/Telefone no diálogo de permissões.
8. **Proibição de Disparo em Massa Sem Auditoria:** Mensagens represadas ou pendentes na `whatsapp_outbox` não devem ser liberadas ou reprocessadas em massa sem auditoria prévia.
9. **Trava de Segurança Anti-Retry (Erros Meta 4xx/5xx):** Erros HTTP 4xx/5xx ou Meta Error Codes (ex: 200, 132001) devem acionar imediatamente a trava de segurança, impedindo retries automáticos indiscriminados.
949. **Isolamento Multicondomínio e Opt-in:** O módulo de encomendas deve preservar rigorosamente o isolamento multicondomínio e respeitar as preferências de opt-in dos moradores.

---

## 🛡️ Baseline Oficial — Retirada de Encomendas por Terceiros

**STATUS: BASELINE OFICIAL CONGELADA**  
**HOMOLOGADA E VALIDADA EM:** 14/08/2026  
**ESCOPO: WEB + APP MOBILE (FLUTTER) + POSTGRESQL**  
**INTEGRAÇÃO WHATSAPP: PRESERVADA E INALTERADA**  
**ALTERAÇÕES FUTURAS: SOMENTE MEDIANTE NOVA AUDITORIA E HOMOLOGAÇÃO FORMAL**  

### 1. Status Normativo
Esta seção constitui uma **BASELINE OFICIAL E PERMANENTE** do módulo de Encomendas do ecossistema Condomeet. A regra é obrigatória para quaisquer futuras alterações do módulo. Nenhuma alteração futura poderá modificar o comportamento aqui definido sem nova auditoria técnica e nova homologação.

---

### 2. Escopo Congelado
Compõem o escopo oficial e exclusivo desta baseline os seguintes arquivos:
- `supabase/migrations/20260814_validate_encomenda_third_party.sql`
- `web-app/app/condo/encomendas/parcel-list.tsx`
- `lib/features/portaria/presentation/screens/pending_deliveries_screen.dart`
- `lib/features/portaria/presentation/screens/parcel_dashboard_screen.dart`

---

### 3. Regra Funcional e Matriz de Consistência Congelada

| Cenário de Baixa | `picked_up_by_id` | `picked_up_by_name` | Validação UI | Proteção Banco (Trigger) |
| :--- | :--- | :--- | :--- | :--- |
| **Morador Cadastrado** | `UUID` do morador | Nome do morador (ou NULL) | Exige morador selecionado | Permitido |
| **Terceiro com Nome** | `NULL` | `BTRIM(thirdPartyName)` | Exige `thirdPartyName.trim().length > 0` | Permitido |
| **Terceiro sem Nome** | `NULL` | `NULL` / `""` / `'   '` | **Botão Desabilitado** | **REJEITADO (`RAISE EXCEPTION`)** |

* **Entrega ao Morador:** Quando entregue a morador cadastrado, `picked_up_by_id` deve obrigatoriamente ser o `UUID` do morador e `picked_up_by_name` o seu nome correspondente.
* **Entrega a Terceiro (`isThirdParty = true`):** Exige obrigatoriamente `picked_up_by_id = NULL` e `picked_up_by_name = BTRIM(nome_do_terceiro)`. Nome vazio, nulo ou composto apenas por espaços não pode resultar em baixa válida.
* **Terceiro sem Nome:** Impedido na UI Web e App. Adicionalmente, o PostgreSQL rejeita a operação independentemente do frontend através da função `public.fn_validate_encomenda_discharge()` e trigger `tr_validate_encomenda_discharge`.

---

### 4. Proteção de Banco Congelada (PostgreSQL)
A trigger `tr_validate_encomenda_discharge BEFORE INSERT OR UPDATE ON public.encomendas` atua como barreira de integridade física.
- Quando `NEW.status = 'delivered'`, `NEW.picked_up_by_id IS NULL` e `COALESCE(NEW.silent_discharge, false) = false`: exige que `NEW.picked_up_by_name` possua valor válido após `BTRIM()`. Caso contrário, gera exceção `RAISE EXCEPTION 'Nome do terceiro é obrigatório para baixa de encomenda entregue a terceiro.' USING ERRCODE = '23502'`.
- A exceção funcional para `silent_discharge = true` permanece totalmente preservada para baixas administrativas.

---

### 5. Regras Congeladas no Frontend Web (`parcel-list.tsx`)
O componente `DeliveryModal` deve preservar obrigatoriamente:
- Proteção contra corrida assíncrona na busca de moradores via `isThirdPartyRef` e flag de cancelamento (`cancelled`).
- Zerar `pickedById = null` ao marcar a opção de terceiro.
- Limpar `thirdPartyName = ''` ao retornar para a seleção de morador.
- Validação por `thirdPartyName.trim().length > 0`.
- Impossibilidade de enviar simultaneamente ID de morador e nome de terceiro no mesmo payload.
- Identificação visual no histórico do card (`"Terceiro: [Nome]"` vs `"Morador: [Nome]"`).

---

### 6. Regras Congeladas no App Mobile Flutter
Telas `pending_deliveries_screen.dart` e `parcel_dashboard_screen.dart` devem preservar:
- Listener ativo no `_thirdPartyCtrl` (`initState`) para reatividade imediata no recálculo da UI.
- Getter `_canConfirm` derivado do estado real (`_isThirdParty ? _thirdPartyCtrl.text.trim().isNotEmpty : _selectedResidentId != null`).
- Zerar `_selectedResidentId = null` e `_selectedResidentName = null` ao selecionar terceiro.
- Limpar `_thirdPartyCtrl.clear()` ao retornar para a opção de morador.
- Exibição explícita do recebedor no card do histórico entregue.

---

### 7. Infraestrutura de WhatsApp Preservada
A infraestrutura transacional do WhatsApp de Encomendas NÃO sofreu alteração e permanece 100% preservada. Continuam protegidos e inalterados:
- `tr_fn_encomenda_delivered`
- `push_notify_parcel`
- `smartSend`
- `whatsapp_outbox`
- `message_type`
- `message_hash`
- `whatsapp-outbox-worker`
- `claim_single_whatsapp_message()`
- `whatsapp-parcel-notify`

---

### 8. Arquivos Excluídos da Baseline de Encomendas
Fica registrado que os arquivos abaixo NÃO pertencem à baseline de Retirada por Terceiros, sendo classificados estritamente como *Fixes Isolados de Build*:
- `web-app/app/admin/whatsapp-templates/actions.ts`
- `web-app/app/admin/whatsapp-templates/whatsapp-templates-client.tsx`

---

### 9. Regra Permanente de Governança
Nenhuma alteração futura que afete a lógica de retirada de encomendas (`picked_up_by_id`, `picked_up_by_name`, `silent_discharge`, `DeliveryModal`, `_canConfirm`, `_thirdPartyCtrl`, `tr_validate_encomenda_discharge`, `fn_validate_encomenda_discharge`) poderá ser realizada sem nova auditoria técnica, execução de suíte de testes de regressão Web/App/PostgreSQL/WhatsApp e homologação formal.

---

## 📊 Baseline Oficial — Governança de Mensageria WhatsApp: Utility/Auth Only e Bloqueio de Marketing

Status: 🟢 HOMOLOGADO E CONGELADO (15/08/2026)

### Premissas e Regras de Governança
1. **Regra Zero (Canal Exclusivamente Transacional/Auth):** O WhatsApp Oficial do Condomeet opera exclusivamente para mensagens operacionais/transacionais (`UTILITY`) e autenticação (`AUTHENTICATION`). Qualquer comunicação promocional, comercial, publicidade, upsell, cross-sell, prospecção de clientes, oferta de destaque pago de perfil, cupom de desconto ou divulgação de redes sociais com finalidade promocional é TERMINANTEMENTE PROIBIDA no canal de mensageria.
2. **Hardening do `smartSend()` e Validador Central `validateWhatsAppSendPolicy()`:** Toda mensagem submetida para enfileiramento ou disparo no WhatsApp passa obrigatoriamente pela validação central de política (`validateWhatsAppSendPolicy`). Disparos contendo categoria `MARKETING`, expressões de upsell ("destacar seu perfil", "atrair mais clientes"), links promocionais de redes sociais em fluxos automáticos ou tentativas de envio em lote sem template aprovado são sumariamente BLOQUEADOS.
3. **Bloqueio Obrigatório para Campanhas em Lote:** O motor de campanhas (`notification-campaign-manager` e `notification-campaign-worker`) obrigatoriamente exige templates homologados presentes no `REGISTERED_OFFICIAL_TEMPLATES` / `TEMPLATE_REGISTRY`. O envio de texto livre via campanhas é ESTRITAMENTE PROIBIDO.
4. **TEMPLATE_REGISTRY como Fonte Única de Verdade:** Nenhuma função ou worker pode inventar nomes de templates, categorias ou número de variáveis. Variações e inconsistências de contrato resultam em bloqueio preventivo (`WHATSAPP_POLICY_INVALID_CONTRACT`).
5. **Observabilidade e Logs de Governança:** Qualquer tentativa de envio não conforme gera um log estruturado na tabela `public.botconversa_monitoring` e no outbox com códigos de erro rastreáveis:
   - `WHATSAPP_POLICY_MARKETING_BLOCKED`
   - `WHATSAPP_POLICY_TEMPLATE_REQUIRED`
   - `WHATSAPP_POLICY_TEMPLATE_NOT_APPROVED`
   - `WHATSAPP_POLICY_TEMPLATE_NOT_REGISTERED`
   - `WHATSAPP_POLICY_INVALID_CONTRACT`
   - `WHATSAPP_POLICY_CAMPAIGN_FREE_TEXT_BLOCKED`
6. **Classificação Interna de `condomeet_documento_disponivel_v2`:** O alerta de vencimento de documentos e contratos condominiais enviado a síndicos é classificado e cobrado internamente como `UTILITY` (operacional).
 7. **Suíte de Testes Obrigatória:** A suíte de testes `supabase/functions/tests/whatsapp_governance_policy_test.ts` valida permanentemente os 14 cenários operacionais e de segurança do ecossistema.

---

## 🛡️ Baseline Oficial — Resiliência de Comunicação com Supabase

**STATUS: BASELINE OFICIAL HOMOLOGADA E CONGELADA**  
**HOMOLOGADA E VALIDADA EM:** 18/08/2026  
**ESCOPO: APP MOBILE (FLUTTER) + REST/RPC SUPABASE**  
**ALTERAÇÕES FUTURAS: SOMENTE MEDIANTE NOVA AUDITORIA E HOMOLOGAÇÃO FORMAL**  

### 1. Camada Central
Toda comunicação com o Supabase que necessite de resiliência deverá utilizar a camada central de resiliência definida pela arquitetura (`SupabaseResilienceService`).
É proibida a criação de políticas independentes de retry em telas, BLoCs ou repositórios sem justificativa arquitetural explícita.

### 2. Classificação de Operações por Idempotência
Toda operação no Supabase deverá ser classificada em uma de três categorias:
- `READ_ONLY`: Consultas e leituras puras sem efeitos colaterais.
- `IDEMPOTENT_WRITE`: Escritas idempotentes comprovadas (ex: `updateFcmToken` por `userId` onde o valor é sobrescrito deterministicamente).
- `NON_IDEMPOTENT_WRITE`: Escritas não idempotentes (ex: `signInWithPassword`, `signUp`, inserção de registros sem chave idempotente).

### 3. Política de Retry
Retry automático é permitido **somente** para:
- Operações `READ_ONLY`;
- Operações explicitamente classificadas como `IDEMPOTENT_WRITE`.

Operações `NON_IDEMPOTENT_WRITE` não devem sofrer retry automático por padrão.

### 4. Limite de Tentativas
A política de tentativas padrão é de **3 tentativas totais**:
- 1 chamada inicial;
- até 2 retries com exponential backoff (`500ms` / `1500ms`) e jitter aleatório.

É expressamente proibido retry infinito, recursivo ou em loop.

### 5. Erros Transitórios de Infraestrutura
Podem ser classificados como transitórios e sofrer retry (respeitando a idempotência da operação):
- `Connection reset by peer` / `ClientException` de socket encravado;
- `Connection closed` / `Software caused connection abort`;
- `SocketException` de transporte de rede;
- `TimeoutException`;
- HTTP `408` (Request Timeout);
- HTTP `502` (Bad Gateway);
- HTTP `503` (Service Unavailable);
- HTTP `504` (Gateway Timeout).

### 6. Erros Permanentes (Sem Retry)
Não devem sofrer retry automático sob hipótese alguma:
- Credenciais inválidas (`invalid_credentials`);
- Sessão inválida/expirada sem autorização de refresh;
- RLS Violation (`42501` / `Permission denied`);
- Tabela inexistente (`42P01`) / Coluna inexistente (`42703`);
- Violações de integridade e chave única (`23505`, `23503`);
- Erros de validação do cliente (HTTP 400, 422);
- Demais erros permanentes de negócio ou schema do banco.

### 7. Desacoplamento da Autenticação e Perfil no Login
O fluxo de login deve permanecer estritamente desacoplado em etapas independentes:
`SIGN IN` ➔ `SESSION ESTABELECIDA` ➔ `FETCH PROFILE` ➔ `APP AUTHENTICATED`

Se `signInWithPassword()` for bem-sucedido e a busca do perfil (`fetchProfile`) falhar por problema transitório de rede:
- NÃO emitir `unauthenticated` com erro de senha;
- NÃO fazer logout;
- NÃO informar "senha incorreta";
- NÃO apagar/destruir a sessão válida.

A sessão permanece mantida e o usuário é notificado com mensagem amigável de instabilidade de perfil/conexão, podendo tentar novamente sem re-digitar a senha.

### 8. Sanitização de Mensagens de UI
Exceções técnicas não podem ser exibidas diretamente na interface do usuário. É proibido expor:
- Stack traces;
- URLs internas do Supabase;
- Tokens de acesso ou API keys;
- Detalhes de schema/tabelas de banco de dados;
- Mensagens de erro de infraestrutura como `ClientException: Connection reset by peer`.

As mensagens exibidas na UI devem ser amigáveis e em português funcional.

### 9. Observabilidade e Telemetria
Os logs técnicos mantidos internamente para diagnóstico devem registrar:
- Nome da operação;
- Número da tentativa (`X/3`);
- Duração (ms);
- Classificação (`READ_ONLY` / `IDEMPOTENT_WRITE`);
- Erro sanitizado;
- Timestamp.

É estritamente proibido logar dados sensíveis (senhas, `access_token`, `refresh_token`, `anonKey`, `service_role` ou segredos).

### 10. Escritas Idempotentes
Uma operação somente poderá ser classificada como `IDEMPOTENT_WRITE` quando houver evidência técnica concreta de que sua repetição não produzirá efeitos duplicados ou inconsistentes. Não generalizar essa classificação para todos os `update()` ou `upsert()`.

### 11. Governança de Novas Integrações
Toda nova integração ou chamada crítica ao Supabase deverá obrigatoriamente respeitar esta baseline. Exceções deverão ser justificadas tecnicamente de forma prévia.

### 12. Suíte de Testes Obrigatória
Alterações na camada de resiliência deverão preservar e executar a suíte de testes unitários para:
- Classificação de erros transitórios vs. permanentes;
- Retry por nível de idempotência;
- Limite de 3 tentativas totais;
- Timeouts;
- Desacoplamento e preservação de sessão;
- Sanitização de mensagens de UI.

### 13. Timeout Obrigatório — Independente de Retry
Toda operação de comunicação de rede com Supabase deverá possuir um limite de duração efetivamente aplicado à `Future` da operação. Essa regra se aplica independentemente da classificação de idempotência.

| Classificação | Timeout | Retry |
| --- | --- | --- |
| `READ_ONLY` | OBRIGATÓRIO | Permitido para erros transitórios |
| `IDEMPOTENT_WRITE` | OBRIGATÓRIO | Permitido para erros transitórios |
| `NON_IDEMPOTENT_WRITE` | OBRIGATÓRIO | PROIBIDO por padrão |

**Regra Fundamental:** Não sofrer retry NÃO significa poder permanecer aguardando indefinidamente. Toda operação de rede deverá obrigatoriamente terminar por sucesso, erro ou timeout controlado. É proibido manter uma `Future` de rede sem limite de duração quando isso puder deixar a aplicação em estado indefinido de loading.

**Autenticação:** Para operações de autenticação (como `signInWithPassword`), o comportamento padrão é:
- Timeout obrigatório (homologado em 20 segundos);
- Retry automático proibido;
- Erro de timeout tratado de forma amigável;
- Nunca permanecer indefinidamente em estado de autenticação/loading.

---

## 🛡️ Governança — RLS Administrativa por Condomínio

Para tabelas administrativas pertencentes a módulos com controle por condomínio, a autorização deverá utilizar a função centralizada e homologada:

`public.is_admin_of_condo(condominio_id)`

Quando aplicável, a policy deverá proteger explicitamente:

`USING (public.is_admin_of_condo(condominio_id))`

e:

`WITH CHECK (public.is_admin_of_condo(condominio_id))`

É proibido recriar novas policies administrativas utilizando funções legadas de identificação de papel, como:

`public._is_admin_or_sindico()`

quando a função centralizada `public.is_admin_of_condo(condominio_id)` for aplicável.

### Escopo Homologado

A regra foi validada no módulo:

- `public.documentos`
- `public.doc_pastas`
- `public.contratos`
- `public.contrato_pastas`

A função centralizada deve continuar sendo a fonte única da regra de autorização administrativa por condomínio.

### Diretrizes de Segurança

É proibido solucionar falhas de RLS:

- liberando INSERT para todo usuário `authenticated`;
- removendo RLS;
- utilizando `service_role` no aplicativo mobile;
- ignorando a associação do usuário ao condomínio;
- permitindo operação sobre outro condomínio.

A autorização deve continuar respeitando o condomínio e o perfil/permissão definidos pela função centralizada.

### Regra para Alterações Futuras

Qualquer alteração futura dessas policies deverá:

1. preservar a segregação entre condomínios;
2. preservar o bloqueio de usuários sem permissão;
3. preservar o bloqueio de moradores para operações administrativas;
4. utilizar `is_admin_of_condo()` quando aplicável;
5. possuir migration explícita;
6. ser validada com testes RLS positivos e negativos.

---

## 📊 Baseline Oficial — Cadastro de Morador / Seletores Responsivos

### Status: **HOMOLOGADA E CONGELADA**

Os seletores modais utilizados no fluxo de **Cadastro de Morador** devem garantir que **100% das opções disponíveis permaneçam acessíveis em dispositivos móveis**, independentemente da quantidade de itens.

### Diretrizes e Regras de Responsividade e UX/UI:
1. **Controle de Altura e Limitação:** O modal deve ser exibido com controle total de altura (`isScrollControlled: true`) e ter sua altura máxima limitada a uma proporção adequada da tela útil (preferencialmente **80–85% da altura disponível** via `ConstrainedBox`), evitando transbordar ou cobrir a tela inteira sem necessidade.
2. **Rolagem Vertical Interna Obrigatória:** Quando o número de opções exceder o espaço visível, a lista deve possuir rolagem vertical interna fluida (`Flexible` + `ListView.builder`), permitindo deslizar com o toque/gesto para visualizar e selecionar qualquer opção.
3. **Cabeçalho Fixo:** O título do seletor (ex.: *"Perfil de Usuário"*, *"Tipo de Usuário"*) e a barra indicadora de arraste (*handle bar*) devem permanecer fixos no topo do modal, sem rolar com a lista.
4. **Proteção de Área Útil (`SafeArea`):** O modal deve obrigatoriamente respeitar os `SafeAreaInsets` inferiores do dispositivo (`SafeArea(top: false)`), garantindo que nenhuma opção ou espaçamento fique escondido ou inacessível atrás da barra de navegação de 3 botões do Android ou da barra de gestos do iOS.
5. **Indicador Visual de Seleção:** A opção atualmente selecionada deve continuar exibindo o checkmark (`Icons.check`) com a cor primária (`AppColors.primary`) e destaque visual.
6. **Escalabilidade Automática:** Quaisquer novas opções de perfil ou tipo adicionadas futuramente deverão ser automaticamente acessíveis pela rolagem interna, sem necessidade de alterações estruturais no componente.

### Escopo Validado:
A baseline foi aplicada e validada nos componentes e seletores do fluxo de cadastro e edição de perfil:
- **Perfil de Usuário** (`self_registration_screen.dart` / `edit_profile_screen.dart`)
- **Tipo de Usuário** (`self_registration_screen.dart` / `edit_profile_screen.dart`)

Validada a acessibilidade e seleção de todas as opções, incluindo explicitamente:
- *Morador(a)*
- *Proprietário não morador*
- *Locatário (a)*
- *Locador*
- *Funcionário (a)*
- *Porteiro (a)*
- *Zelador (a)*
- **Síndico (a)** *(comprovadamente selecionável)*
- *Sub Síndico (a)*
- *Afiliado (a)*
- *Terceirizado (a)*
- *Financeiro*
- *Serviços*

### Governança e Regras de Negócio:
Esta baseline é estritamente de **UX/UI e responsividade**. Não autoriza nem implica alteração em:
- banco de dados;
- schema;
- migrations;
- RLS;
- permissões;
- roles / papéis existentes;
- autenticação;
- endpoints ou APIs;
- regras de negócio;
- valores das opções existentes.

### Evidências da Homologação:
- **`flutter test`:** 100% aprovado;
- **`flutter analyze`:** Aprovado sem erros;
- **Validação Mobile Padrão:** Viewport `360 x 800 dp` (densidade `3.0x`, barra de 3 botões do Android de `48 dp`) — aprovada;
- **Validação Mobile Compacto:** Viewport `320 x 568 dp` (densidade `2.0x`, barra de sistema de `34 dp`) — aprovada;
- **Rolagem Vertical:** Deslizamento até o final da lista comprovado;
- **Seleção de Síndico(a):** Seleção, fechamento do modal e atualização do formulário comprovados;
- **Persistência Visual do Check:** Checkmark renderizado na reabertura do modal comprovado;
- **Proteção contra Barra de Navegação:** Nenhuma opção cortada ou sobreposta;
- **Ausência de Regressão:** Seletor de Tipo de Usuário 100% funcional.

### Regra para Futuras Alterações:
Qualquer alteração futura nesses seletores deverá preservar obrigatoriamente a presente baseline de **acessibilidade integral das opções em dispositivos móveis**. É vedada a remoção do mecanismo de scroll ou de limitação proporcional de altura sem nova homologação visual e funcional.

---

## 📊 Histórico — Nome do Condomínio no Cabeçalho da Home (Badge/Chip)

### Status: ⚠️ **SUPERADA / SUBSTITUÍDA PELA EVOLUÇÃO DE LAYOUT EM 3ª LINHA**

*(Registro histórico da versão anterior implementada como Badge/Chip contextual central-direito, descontinuada e substituída pela baseline vigente abaixo).*

---

## 📊 Baseline Oficial — Nome do Condomínio no Cabeçalho da Home (3ª Linha Integrada)

### Status: 🟢 **HOMOLOGADA E CONGELADA (REGRA OFICIAL VIGENTE)**

A Home do Condomeet apresenta o **nome do condomínio ativo do usuário no cabeçalho**, integrado diretamente na **coluna da marca CONDOMEET como terceira linha**, abaixo do slogan institucional.

### Estrutura Visual Homologada:
```text
[LOGO] CONDOMEET
       seu condomínio digital
       Nome do Condomínio
```

### Diretrizes e Regras de Layout e UX/UI:
1. **Posicionamento e Composição:** O nome do condomínio fica posicionado na mesma coluna da marca, logo abaixo de *"seu condomínio digital"*, funcionando como uma extensão natural e harmoniosa da identificação do app.
2. **Padrão Tipográfico Idêntico ao Slogan:** O nome do condomínio replica exatamente o estilo visual de *"seu condomínio digital"*:
   * **Tamanho:** `fontSize: 10`
   * **Peso:** `FontWeight.normal` (Regular)
   * **Cor:** `AppColors.textSecondary` (`#6B7280`)
   * **Linha única com Truncamento:** `maxLines: 1`, `overflow: TextOverflow.ellipsis`
3. **Ausência de Elementos de Chip:** Fica terminantemente vedada a utilização de:
   * `Container` de badge/chip;
   * Fundo cinza ou colorido;
   * Borda ou `BorderRadius`;
   * Ícone `Icons.apartment_rounded` ou qualquer outro ícone no cabeçalho;
   * Ocupação do espaço central-direito do cabeçalho (que permanece livre e arejado).
4. **Responsividade e Comportamento para Nomes Extensos:** A coluna está encapsulada em `Expanded`, permitindo que o nome utilize o espaço horizontal disponível até os botões de ação e trunque suavemente com `...` em telas compactas (ex.: *"Condomínio Residencial Parque das Flores..."*), sem jamais quebrar linhas ou causar `RenderFlex overflow`.
5. **Preservação Integral de Elementos da Home:** Ficam formalmente congelados e preservados:
   * Logotipo CONDOMEET (`40x40px`);
   * Tipografia CONDOMEET (16px, `w900`, vermelho);
   * Slogan institucional *"seu condomínio digital"* (10px, cinza);
   * Sino de notificações à direita com badge de avisos;
   * Avatar circular de perfil do usuário (`radius: 18`);
   * Altura do cabeçalho (~64–67px, compatível com a logo de 40px e avatar de 36px);
   * Banner de selfie / avisos;
   * Grade de atalhos em 2 linhas;
   * Card de encomendas pendentes;
   * Menu inferior de navegação.

### Segurança e Isolamento Multi-tenant:
1. **Fonte Única da Verdade:** O nome exibido é derivado exclusivamente do fluxo oficial já estabelecido na sessão do usuário:
   `authState.condominiumId ➔ CondominiumRepository ➔ _condominiumStream ➔ condominium.name`
2. **Proibição de Duplicações:** É proibido criar novas consultas ao banco de dados, endpoints paralelos, tabelas ou mecanismos duplicados para identificação do condomínio.
3. **Isolamento Estrito:** Cada usuário visualiza unicamente o condomínio correspondente à sua sessão autenticada.

### Evidências da Homologação:
* **`flutter analyze`:** 0 erros / 0 warnings no código da aplicação;
* **`flutter test`:** 44/44 testes aprovados (100% de sucesso);
* **Testes Específicos do Cabeçalho (`home_header_test.dart`):** 3/3 testes aprovados;
* **Validação Mobile Compacto:** Viewport `360 x 800 dp` — aprovado sem overflow;
* **Validação Mobile Padrão (iOS):** Viewport `390 x 844 dp` — aprovado;
* **Validação Mobile Padrão (Android):** Viewport `412 x 915 dp` — aprovado;
* **Tratamento de Nomes Extensos:** Truncamento com `ellipsis` validado;
* **Ausência de Regressão Visual:** 100% validado;
* **Multi-tenant:** Isolamento validado.

### Governança e Regras Permanentes:
Esta baseline é de **UX/UI e apresentação contextual segura**. Não autoriza nem implica alteração em:
* banco de dados;
* schema;
* migrations;
* RLS;
* permissões;
* autenticação;
* roles / papéis existentes;
* regras de negócio.

Qualquer alteração futura que modifique a posição, tipografia ou comportamento do nome do condomínio deverá passar por nova validação de UX/UI antes de substituir esta baseline.

---

## 📊 Baseline Oficial — DUAL_NUMBER_NOTICE e Mensageria WhatsApp (Produção)

### Status: 🟢 **HOMOLOGADA E CONGELADA (REGRA OFICIAL VIGENTE EM PRODUÇÃO)**

Esta baseline consolida as regras operacionais, arquiteturais, funcionais e de governança do fluxo de mensageria WhatsApp do ecossistema Condomeet, incluindo a notificação informativa de múltiplos números (`DUAL_NUMBER_NOTICE`), testada e validada com 100% de conformidade no ambiente de **PRODUÇÃO** (`ivdgvpvifhfiktolmbvy`).

---

### 1. Arquitetura de Mensageria e Provedores

1. **BotConversa First (Canal Primário):**
   * Toda mensagem de negócio (`PARCEL`, `AVISO`, `SOS`, `CONVITE`, etc.) utiliza o **BotConversa** (`+55 61 8251-6083`) como provedor primário obrigatório.
2. **Meta Cloud API (Fallback Restrito de Contingência):**
   * A Meta Cloud API (`+55 62 9918-8555`) permanece como canal de contingência exclusivo, sendo acionada in-flight unicamente após constatação de falha real do BotConversa (HTTP 503, HTTP 408, desconexão de linha ou erro de rede).
3. **Exclusividade do BotConversa para o `DUAL_NUMBER_NOTICE`:**
   * O aviso de múltiplos números (`DUAL_NUMBER_NOTICE`) transita exclusivamente pelo BotConversa.
4. **Bloqueio Permanente da Meta para o `DUAL_NUMBER_NOTICE`:**
   * A Meta Cloud API é permanentemente bloqueada para o `DUAL_NUMBER_NOTICE` (`allow_meta_fallback = false` / `isMetaFallbackForbidden`). Caso o BotConversa falhe no envio do aviso, a mensagem permanece em retry exclusivo no BotConversa e jamais é transferida para a Meta.

---

### 2. Regras Operacionais e Funcionais do `DUAL_NUMBER_NOTICE`

1. **Gatilho Pós-Primeiro Sucesso Real:**
   * O `DUAL_NUMBER_NOTICE` é enfileirado exclusivamente após o sucesso real (HTTP 200) no envio da primeira mensagem de negócio para o destinatário.
2. **Envio Único e Idempotência Estrita:**
   * O aviso é emitido uma única vez por número de telefone em toda a vida útil do cadastro.
   * A idempotência é garantida no banco de dados pela chave primária `public.whatsapp_dual_number_notices.recipient_phone` e pela cláusula `ON CONFLICT (recipient_phone) DO NOTHING` na RPC `enqueue_dual_number_notice_if_needed`.
   * A existência prévia do registro bloqueia imediatamente qualquer novo enfileiramento para futuras mensagens de negócio.
3. **Delay de Pacing Programado:**
   * O aviso é enfileirado com delay obrigatório de **120 segundos (2 minutos)** (`next_attempt_at = now() + INTERVAL '2 minutes'`), impedindo rajadas ou sobreposição imediata à mensagem de negócio.
4. **Prioridade na Fila:**
   * Enfileirado na fila de baixa prioridade (`queue=low`) com **prioridade 25**.
5. **Independência Total da Resposta "OK" (Ciclo Exclusivamente Outbound):**
   * O fluxo NÃO armazena, NÃO consulta, NÃO valida e NÃO depende da resposta "OK" do morador.
   * O recebimento ou não recebimento de qualquer resposta do morador NÃO faz parte do ciclo funcional do `DUAL_NUMBER_NOTICE`.
   * Se o morador responder "OK", a interação ocorre normalmente no WhatsApp, mas o `DUAL_NUMBER_NOTICE` não executa nenhuma ação adicional, não altera estado, não gera resposta automática e não depende dessa interação.
   * Se o morador não responder, o comportamento é exatamente o mesmo.
   * O ciclo do `DUAL_NUMBER_NOTICE` é exclusivamente OUTBOUND e termina após o envio bem-sucedido do aviso pelo BotConversa.
   * Portanto, webhook inbound, captura de resposta, processamento de "OK" e qualquer lógica de confirmação NÃO são dependências do `DUAL_NUMBER_NOTICE`.
   * A IA / Google Gemini permanece permanentemente desativada (`botForcedDisabled = true`).

---

### 3. Texto Oficial Homologado

```text
📱 *Aviso importante do Condomeet*

O Condomeet utiliza dois números de WhatsApp para enviar as notificações do seu condomínio.

Para garantir que você receba todas as nossas comunicações, recomendamos cadastrar os dois números nos seus contatos.

*Números oficiais de notificações:*

+55 62 9918-8555
+55 61 98251-6083

Tudo bem para você?

Responda *OK* para confirmar.
```

---

### 4. Evidências de Homologação em Produção (`ivdgvpvifhfiktolmbvy`)

O fluxo foi testado e homologado ponta a ponta em PRODUÇÃO no dia 23/08/2026 com as seguintes confirmações forenses:
* **Mensagem `PARCEL`:** Enviada via BotConversa com HTTP 200 e finalizada como `sent`.
* **Chamadas à Meta Cloud API na PARCEL:** `0` (não acionada).
* **Gatilho do Aviso:** `DUAL_NUMBER_NOTICE` enfileirado automaticamente vinculado à mensagem de encomenda.
* **Delay de 120 Segundos:** Transcurso exato confirmado (`created_at: 13:25:10` ➔ `next_attempt_at: 13:27:10`).
* **Mensagem `DUAL_NUMBER_NOTICE`:** Enviada via BotConversa com HTTP 200 e finalizada como `sent`.
* **Chamadas à Meta Cloud API no Aviso:** `0` (bloqueio estrito respeitado).
* **Chamadas ao Google Gemini / IA:** `0` (silêncio operacional mantido).
* **Dois Números Oficiais no Texto:** Presença de `+55 62 9918-8555` e `+55 61 98251-6083` comprovada no payload entregue.
* **Duplicidade:** `0` (exatamente 2 mensagens criadas e enviadas no ciclo).
* **Estado Final da Outbox em Produção:** `sent: 27`, `failed: 1`, `pending: 0`.

---

### 5. Governança e Regras de Congelamento

Esta baseline está formalmente **HOMOLOGADA E CONGELADA**. Qualquer alteração futura que impacte:
* A esteira `BotConversa First` ou fallback da Meta;
* A regra de delay de 120s ou prioridade 25;
* O bloqueio da Meta para o `DUAL_NUMBER_NOTICE`;
* A idempotência por `recipient_phone`;
* O texto homologado do aviso;
* O silêncio operacional e desativação de IA,

exigirá abertura formal de nova RFC e validação prévia de conformidade antes de qualquer alteração de código ou banco.

---

## 📊 FASE 4.15 — Baseline Oficial — whatsapp-guest / VISITOR_AUTHORIZED

### Status: 🟢 **HOMOLOGADA E CONGELADA (EM DEV)**

Esta baseline consolida as regras arquiteturais, funcionais, de transporte e de governança para o módulo `whatsapp-guest` e o tipo de evento `VISITOR_AUTHORIZED` (solicitações de aprovação e autorização de visitantes na portaria).

---

### 1. Diretrizes e Contrato de Mensageria

1. **MessageType Oficial:** `VISITOR_AUTHORIZED`
2. **Prioridade Numérica:** `2` (Canal de Alta Prioridade)
3. **Fila Operacional (`queue`):** `high` (Faixa `[1, 5]`, lease lock `high_priority`)
4. **`callerFunction`:** `"whatsapp-guest"`
5. **Solicitações de Aprovação (Outbound):**
   * Persistidas na tabela `public.whatsapp_outbox` com `payload_type = "interactive"`.
   * O payload JSON interativo original (contendo `body`, `header`, `footer` e botões com IDs `approve_<uuid>` e `reject_<uuid>`) permanece 100% íntegro na outbox.
   * O worker converte a mensagem exclusivamente na **camada de transporte do BotConversa** para `type: "text"`, sem mutar o registro do banco.
   * O payload nativo original permanece disponível para contingência caso ocorra fallback.
6. **Transporte Primário (BotConversa First):**
   * Todas as solicitações de autorização de visitante utilizam o **BotConversa** como canal primário obrigatório.
   * O payload `interactive` não deve ser despachado diretamente com `type: "interactive"` para o endpoint `/subscriber/{id}/send_message/` do BotConversa (pois aceita apenas `"text"` ou `"file"`).
   * O worker renderiza o payload interativo em texto estruturado formatado com opções claras de resposta rápida:
     ```text
     🔔 *Visita pendente para aprovação:*
     [texto original da mensagem]

     Responda com:
     1️⃣ *Aprovar Entrada*
     2️⃣ *Recusar Entrada*
     ```
7. **Fallback de Contingência (Meta Cloud API):**
   * Acionado unicamente após falha real do BotConversa (HTTP 503, HTTP 408, desconexão de linha ou erro de rede).
   * Quando acionado, despacha o payload nativo com botões interativos clicáveis (`type: "interactive"`).
   * Não altera o payload original armazenado na outbox.
8. **Reconhecimento e Parser de Respostas do Morador (Inbound):**
   * **Por ID de Botão:** `approve_<uuid>` ➔ `decision = "approve"`, `reject_<uuid>` ➔ `decision = "reject"`
   * **Por Texto de Aprovação:** `"1"`, `"aprovar"`, `"aprovado"`, `"sim"`, `"autorizar"`, `"liberar"` ➔ `decision = "approve"`
   * **Por Texto de Recusa:** `"2"`, `"recusar"`, `"recusado"`, `"nao"`, `"não"`, `"rejeitar"`, `"bloquear"` ➔ `decision = "reject"`
9. **Resolução Contextual Segura (Anti-Ambiguidade):**
   * Identifica o morador pelo telefone (`incoming.phone` normalizado) na tabela `perfil`.
   * Resolve `condominio_id`, `bloco_txt` e `apto_txt` da unidade.
   * Consulta visitantes pendentes com `status = 'aguardando_aprovacao'` para a unidade.
   * **Se existir exatamente 1 visitante pendente:** aplica a decisão no registro correspondente em `visitante_registros`.
   * **Se existirem múltiplos visitantes pendentes simultâneos:** **NÃO aplica nenhuma decisão**, bloqueando mutações arbitrárias e retornando `"Ambiguous text reply: multiple pending visitors"`.
   * **Se nenhum visitante pendente for encontrado:** ignora a mensagem com segurança.
10. **Feedback de Decisão ao Morador:**
    * Emitido obrigatoriamente via `smartSend()`.
    * Enfileirado na `public.whatsapp_outbox` com:
      * `message_type = VISITOR_AUTHORIZED`
      * `payload_type = "text"`
      * `priority = 2`
      * `queue = "high"`
      * `callerFunction = "whatsapp-guest"`
    * Enviado via **BotConversa First**.
11. **Idempotência do DUAL_NUMBER_NOTICE:**
    * Preservado e compatível em toda a esteira do módulo de visitantes.
12. **Governança Estrita:**
    * Zero bypass da outbox.
    * Zero envio direto pelo `whatsapp-guest`.
    * `TEMPLATE_REGISTRY` e `validateTemplateContract()` permanecem 100% intactos em `_shared/message_types.ts`.
    * Produção permanece 100% intocada.

---

### 2. Evidências Forenses de Homologação em DEV (`avypyaxthvgaybplnwxu`)

O ciclo do `whatsapp-guest` foi homologado com 100% de conformidade com os seguintes resultados:

* **TESTE A (Solicitação de Aprovação):** `send_approval_request` ➔ `whatsapp_outbox` (`interactive`, prioridade 2, queue high) ➔ worker converte no transporte ➔ BotConversa HTTP 200 (`type: "text"`) ➔ outbox `sent` (Meta Calls = 0).
* **TESTE 1 (Resposta Textual "1"):** `text: "1"` ➔ resolução contextual da unidade 10/101 ➔ `decision: "approve"` ➔ `visitante_registros` atualizado para `liberado` (`aprovado_por: perfil_id`, `canal_liberacao: "whatsapp"`) ➔ feedback outbox ID `9c391881-...` ➔ BotConversa HTTP 200 ➔ outbox `sent` (Meta = 0).
* **TESTE 2 (Resposta Textual "2"):** `text: "2"` ➔ resolução contextual da unidade 10/101 ➔ `decision: "reject"` ➔ `visitante_registros` atualizado para `rejeitado` ➔ feedback outbox ID `fcd654c8-...` ➔ BotConversa HTTP 200 ➔ outbox `sent` (Meta = 0).
* **TESTE B (Botão Approve):** `approve_<uuid>` ➔ `decision: "approve"` ➔ visitante liberado ➔ feedback outbox ID `419a4dd3-...` ➔ BotConversa HTTP 200 ➔ outbox `sent` (Meta = 0).
* **TESTE B (Botão Reject):** `reject_<uuid>` ➔ `decision: "reject"` ➔ visitante rejeitado ➔ feedback outbox ID `dc6aecf7-...` ➔ BotConversa HTTP 200 ➔ outbox `sent` (Meta = 0).
* **TESTE de Segurança (Ambiguidade):** Múltiplos pendentes na mesma unidade + `text: "1"` ➔ retorno `"Ambiguous text reply: multiple pending visitors"` ➔ ZERO mutações no banco ➔ ZERO mensagens na outbox.

---

### 3. Status Final

* 🟢 **TESTE 4 HOMOLOGADO**
* 🟢 **CICLO `whatsapp-guest` FECHADO EM DEV**
* 🟢 **BASELINE HOMOLOGADA E CONGELADA**
* 🟢 **PRODUÇÃO 100% INTOCADA**

---

## 📊 FASE 4.15 — Baseline Oficial — Mensageria Global DEV

### Status: 🟢 **HOMOLOGADA E CONGELADA (EM DEV)**

Esta baseline consolida formalmente a conclusão da **FASE 4.15** com a homologação integral dos 5 módulos de mensageria na arquitetura central de outbox:

```text
EDGE FUNCTION / MÓDULO
        ↓
    smartSend()
        ↓
 public.whatsapp_outbox
        ↓
whatsapp-outbox-worker
        ↓
  BotConversa First
        ↓
Meta Cloud API (contingência exclusiva)
```

---

### 1. Módulos Homologados e Tipagem Oficial

| Módulo | `MessageType` | `callerFunction` | `priority` | `queue` | Provedor Primário | Status |
| :--- | :--- | :--- | :---: | :---: | :--- | :---: |
| **`garagem-notify`** | `NOTICE` | `"garagem-notify"` | `15` | `low` | BotConversa First | 🟢 Homologado |
| **`classificados-notify`** | `NOTICE` | `"classificados-notify"` | `15` | `low` | BotConversa First | 🟢 Homologado |
| **`optin-whatsapp-cron`** | `NOTICE` | `"optin-whatsapp-cron"` | `15` | `low` | BotConversa First | 🟢 Homologado |
| **`whatsapp-guest`** | `VISITOR_AUTHORIZED` | `"whatsapp-guest"` | `2` | `high` | BotConversa First | 🟢 Homologado |
| **`whatsapp-chatbot`** | `NOTICE` | `"whatsapp-chatbot"` | `15` | `low` | BotConversa First | 🟢 Homologado |

---

### 2. Regras e Princípios de Governança Consolidados

1. **Outbox Central Obrigatória:**
   * Todo tráfego outbound gerado pelos módulos homologados deve obrigatoriamente persistir registros na tabela `public.whatsapp_outbox` através do helper `smartSend()`.
   * São terminantemente proibidos bypasses diretos, fetches externos para endpoints de envio do BotConversa ou chamadas diretas para a Meta Cloud API a partir de Edge Functions operacionais.
2. **Tipagem Estrita e Desacoplamento:**
   * O `MessageType` e a `callerFunction` devem ser informados explicitamente em todas as chamadas.
   * Não é permitida a criação de strings literais não mapeadas no `_shared/message_types.ts`.
3. **Resolução de Prioridades e Filas:**
   * `VISITOR_AUTHORIZED` ➔ `priority = 2` ➔ `queue = high` (Faixa `[1, 5]`, lease lock `high_priority`).
   * `NOTICE` ➔ `priority = 15` ➔ `queue = low` (Faixa `[6, 99]`, lease lock `low_priority`).
   * Toda priorização segue o mapa estático `EVENT_PRIORITY_MAP`.
4. **Worker Central Desacoplado:**
   * O `whatsapp-outbox-worker` é o único agente executor responsável pelo despacho HTTP final.
   * Respeita: `claim_single_whatsapp_message`, lease locks desacoplados, Rate Limiter global (`acquire_botconversa_slot`), `BotConversa First`, contingência in-flight da Meta e atualização de status da outbox.
5. **Esteira BotConversa First:**
   * O BotConversa é o provedor primário obrigatório para todos os fluxos homologados.
   * O retorno HTTP 200 do BotConversa finaliza a mensagem como `sent`, com registro de **zero chamadas à Meta Cloud API**.
6. **Fallback de Contingência Meta Cloud API:**
   * A Meta Cloud API opera exclusivamente como contingência técnica in-flight (após 503, timeout, desconexão de linha ou erro de rede do BotConversa).
   * Para o módulo `whatsapp-guest`: o payload `interactive` original permanece íntegro na outbox; no transporte BotConversa ele é convertido para texto estruturado, e no fallback Meta ele é despachado como payload interativo nativo com botões clicáveis.
7. **Regras Homologadas do `whatsapp-guest`:**
   * `VISITOR_AUTHORIZED`, prioridade 2, queue high, `callerFunction = "whatsapp-guest"`.
   * Payload `interactive` preservado na outbox e adaptado para `type: "text"` no transporte BotConversa.
   * Parser flexível de respostas do morador: botões (`approve_<uuid>`, `reject_<uuid>`) e textos (`"1"`, `"2"`, `"aprovar"`, `"recusar"`).
   * Resolução contextual por morador + condomínio + bloco/apto.
   * Bloqueio estrito de decisão e zero mutação em caso de múltiplos visitantes pendentes concorrentes.
   * Feedback de autorização/recusa obrigatoriamente enfileirado via `smartSend()`.
8. **Regras Homologadas do `whatsapp-chatbot`:**
   * `NOTICE`, prioridade 15, queue low, `callerFunction = "whatsapp-chatbot"`.
   * Comandos administrativos (`STATUS`, `DESATIVAR`, `ATIVAR`) transitam 100% via outbox.
   * Silêncio operacional de IA mantido: `botForcedDisabled = true` bloqueia respostas autônomas e chamadas ao Google Gemini.
9. **Governança de Templates Meta:**
   * `TEMPLATE_REGISTRY` e `validateTemplateContract()` permanecem 100% intactos em `_shared/message_types.ts`.
   * Templates oficiais continuam exigindo validação rígida de parâmetros. Mensagens `NOTICE` e payloads operacionais não-template não são submetidos a contratos incompatíveis.
10. **Idempotência do DUAL_NUMBER_NOTICE:**
    * A regra de aviso de múltiplos números é universalmente respeitada, garantindo envio único por telefone sem duplicações.
11. **Segurança e Anti-Ambiguidade:**
    * A homologação comprovou que respostas textuais concorrentes nunca produzem mutações arbitrárias no banco de dados.
12. **Isolamento Integral de Produção:**
    * O ambiente de **PRODUÇÃO** (`ivdgvpvifhfiktolmbvy`) permaneceu 100% intocado durante toda a FASE 4.15 (zero deploys, zero migrations, zero mutações, zero chamadas de API, zero mensagens enviadas).

---

### 3. Status Consolidado

* 🟢 **FASE 4.15 — HOMOLOGADA EM DEV**
* 🟢 **TESTES 1 A 5 HOMOLOGADOS**
* 🟢 **ARQUITETURA CENTRAL DE MENSAGERIA HOMOLOGADA**
* 🟢 **ZERO BYPASS IDENTIFICADO**
* 🟢 **PRODUÇÃO 100% INTOCADA**
* 🟢 **BASELINE CONGELADA**

---

## 📊 FASE 4.15 — ENCERRAMENTO OFICIAL — PRODUÇÃO VALIDADA

### Status Final Consolidado:
* 🟢 **HOMOLOGADA EM DEV** (`avypyaxthvgaybplnwxu`)
* 🟢 **BASELINE CONGELADA**
* 🟢 **PROMOVIDA PARA PRODUÇÃO** (`ivdgvpvifhfiktolmbvy`)
* 🟢 **PRODUÇÃO VALIDADA**
* 🟢 **FASE ENCERRADA**

---

### 1. Edge Functions Ativas em Produção (`ivdgvpvifhfiktolmbvy`)

As 6 Edge Functions da FASE 4.15 foram promovidas e encontram-se no estado **ACTIVE** em produção:

| Edge Function | Versão | Deployment ID | Status |
| :--- | :---: | :--- | :---: |
| **`whatsapp-outbox-worker`** | v8 | `27882bd5-cf9a-4488-8fc9-11168e4d117f` | 🟢 ACTIVE |
| **`whatsapp-guest`** | v4 | `90da950d-b258-491a-9c84-8ac6efa966c7` | 🟢 ACTIVE |
| **`whatsapp-chatbot`** | v8 | `6e6dfb6a-4bd5-4144-9003-429164a36f1f` | 🟢 ACTIVE |
| **`garagem-notify`** | v4 | `ac4d037c-dcdd-4b4b-88a1-a15f6876d80d` | 🟢 ACTIVE |
| **`classificados-notify`** | v4 | `b17db750-5a41-40ab-b747-77c2e127e2e7` | 🟢 ACTIVE |
| **`optin-whatsapp-cron`** | v4 | `4a541882-a90e-46ab-9570-a048308eac58` | 🟢 ACTIVE |

---

### 2. Evidências Forenses de Produção (`ivdgvpvifhfiktolmbvy`)

* **Edge Functions:** 6 de 6 com status `ACTIVE`.
* **Saúde e Conectividade (`whatsapp_health_status`):**
  * `status = "ok"`
  * `api_status = "ok"`
  * `whatsapp_connection_status = "connected"`
  * `fail_count = 0`
* **Fila de Mensagens (`whatsapp_outbox`):**
  * `pending = 0`
  * `sending = 0`
  * Zero mensagens órfãs criadas pelo deploy.
* **Estabilidade e Logs:**
  * 0 erros pós-deploy.
  * 0 dead letters recentes.
  * 0 bypasses identificados.
* **Arquitetura e Governança:**
  * Esteira `BotConversa First` preservada como provedor primário.
  * Fallback `Meta Cloud API` preservado exclusivamente para contingência técnica in-flight.
  * `DUAL_NUMBER_NOTICE` preservado com idempotência estrita.
  * `TEMPLATE_REGISTRY` e `validateTemplateContract()` 100% intactos e preservados.
  * `whatsapp-guest`: payload interativo íntegro na outbox, conversão exclusivamente no transporte do BotConversa, parser contextual flexível (botões e textos 1/2) e bloqueio anti-ambiguidade preservados.
  * `whatsapp-chatbot`: `botForcedDisabled = true` e silêncio operacional de IA mantidos.

---

### 3. Garantias de Integridade de Produção

* **Zero Migrations:** Nenhuma migration SQL foi executada em produção.
* **Zero Alterações de Schema:** Tabelas, constraints, RLS e triggers preservados.
* **Zero Alterações de Secrets:** Variáveis de ambiente mantidas.
* **Zero Disparos Artificiais:** Nenhuma mensagem fictícia ou teste foi disparado em produção.
* **Zero Escopo Extra:** Nenhum módulo fora da FASE 4.15 foi alterado.

---

## 🛡️ Diretriz Permanente de Governança — Segregação de Canais: Push FCM (Broadcast Livre) vs. WhatsApp (Transactional First / Zero Broadcast)

### Status: 🟢 **DIRETRIZ PERMANENTE HOMOLOGADA E EM VIGOR**

Esta diretriz estabelece a política oficial e definitiva de segregação de canais de mensageria e comunicação no ecossistema Condomeet, atuando de forma complementar às baselines existentes (especialmente à `Política Oficial de Classificação de Mensagens` e à `FASE 4.15`), regendo o desenvolvimento de todos os módulos presentes e futuros.

---

### 1. Princípio Central Normativo

> **"BROADCAST PODE. BROADCAST VIA WHATSAPP NÃO."**
> 
> *O Condomeet autoriza e adota comunicação em massa/broadcast via Push Notification (FCM), porém estabelece tolerância ZERO para broadcast de WhatsApp, independentemente do provedor utilizado.*

---

### 2. Matriz Oficial de Segregação de Canais

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      COMUNICAÇÃO GERAL / BROADCAST                     │
│  → PUSH FCM (Firebase Cloud Messaging)                                 │
│  → Feed In-App / Murais                                                │
│  → E-mail (quando aplicável)                                           │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│                 COMUNICAÇÃO TRANSACIONAL / OPERACIONAL                 │
│  → WhatsApp via BotConversa First                                      │
│  → Meta Cloud API (somente como contingência técnica in-flight)        │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 3. Regras de Governança por Canal

#### A. Push Notification (FCM) — Canal Oficial de Broadcast
1. **Uso Livre para Massa:** O Push Notification (Firebase Cloud Messaging) é o canal oficial e prioritário para qualquer comunicação destinada a todos os moradores, a múltiplos blocos ou a grandes segmentos de um condomínio.
2. **Ausência de Restrição por Volume:** Não há restrição de volumetria ou de quantidade de destinatários para disparos via FCM nesta política.
3. **Escopo Canônico do Push FCM:**
   - Avisos gerais e comunicados do condomínio;
   - Notificação de novo anúncio aprovado nos Classificados;
   - Notificação de nova indicação de serviços publicada;
   - Convocação geral e avisos de assembleias;
   - Publicação e disponibilização de atas;
   - Alertas operacionais gerais, enquetes, documentos e informativos coletivos.

#### B. WhatsApp — Canal Estritamente Transacional / Operacional
1. **Proibição Absoluta de Broadcast:** É terminantemente proibido utilizar o WhatsApp como canal de broadcast, mensagem em massa, campanhas coletivas ou envios automáticos para toda a base ou listas amplas de moradores de um condomínio.
2. **Independência de Provedor (Regra Universal):** A proibição de broadcast no WhatsApp é absoluta e aplica-se igualmente a:
   - **BotConversa**;
   - **Meta Cloud API**;
   - Qualquer novo provedor, gateway ou integrador que venha a ser incorporado futuramente.
3. **Escopo Exclusivamente Transacional e Individual:** O canal de WhatsApp permanece estritamente restrito a fluxos transacionais, operacionais ponto a ponto ou direcionados a pequenos destinatários diretamente vinculados ao evento de negócio:
   - Notificação de chegada e retirada de encomendas (morador da unidade);
   - Solicitação e feedback de autorização de visitantes (morador da unidade / visitante);
   - Notificações de locação de garagem (proprietário e locatário);
   - Confirmações e cancelamentos de reservas de áreas comuns (morador solicitante e administração);
   - Mensagens de atendimento em Ocorrências e Fale com o Síndico (morador e síndico);
   - Alertas de emergência SOS (síndicos e contatos de emergência do morador);
   - Recuperação de senha / OTP (destinatário individual solicitante);
   - Rotinas de opt-in individual e segmentado controlado.
4. **Proibição de Alternativa de Massa:** Nenhuma funcionalidade de comunicação geral ou coletiva poderá utilizar o WhatsApp como canal alternativo ou redundante de massa.

---

### 4. Proteção contra Fallback e Transbordamento Indevido de Canais

1. **Isolamento de Contingência da Meta Cloud API:** A Meta Cloud API opera unicamente como contingência técnica in-flight para mensagens transacionais legítimas que falharem no BotConversa. É expressamente proibido utilizar o fallback Meta para absorver ou executar disparos em massa.
2. **Proibição de Conversão Automática entre Canais:** A eventual indisponibilidade do Push FCM, do BotConversa ou da Meta Cloud API JAMAIS autorizará a conversão automática de uma comunicação geral/broadcast em disparos de WhatsApp em massa. Se um fluxo for de natureza coletiva/massa, ele deve permanecer fora da esteira de WhatsApp, mesmo sob falha do canal primário.

---

### 5. Arquitetura Central de Mensageria e Governança do Outbox

1. **Manutenção da Esteira Transacional Homologada:** A arquitetura central homologada na FASE 4.15 permanece integralmente em vigor para fluxos transacionais:
   `smartSend() ➔ public.whatsapp_outbox ➔ whatsapp-outbox-worker ➔ BotConversa First ➔ Meta Cloud API (contingência)`
2. **Proibição Universal de Provedores e Gatilhos para Broadcast:** Não importa o meio técnico empregado — seja via inserção direta na `whatsapp_outbox`, chamada a `smartSend()`, crons, Edge Functions, campanhas, rotinas em lote ou integrações externas: se a operação resultar no envio de WhatsApp para múltiplos moradores sem relação transacional individual com o evento, o fluxo é classificado como **BROADCAST PROIBIDO** e será rejeitado pelas travas de governança.

---

### 6. Governança para Novos Módulos e Backlog

1. **Padrão Obrigatório para Novas Funcionalidades:** Todo novo módulo que necessite comunicar múltiplos moradores deverá obrigatoriamente adotar **Push FCM / Feed In-App / E-mail** como canal de difusão padrão. A inclusão de WhatsApp exigirá justificativa técnica prévia demonstrando a natureza estritamente transacional e individual do destinatário.
2. **Assembleia Online (Atualização e Adequação de Backlog):** Fica formalmente registrada como **SUPERADA** qualquer especificação ou planejamento histórico de Assembleia que preveja o envio de edital de convocação ou ata via WhatsApp para toda a base de moradores. A comunicação geral de Assembleia Online transitará exclusivamente por Push FCM, Feed In-App e E-mail.
3. **Motor de Notificações / Campanhas (`notification-campaign-manager` / `worker`):** O motor de campanhas permanece congelado e inativo para produção enquanto possuir capacidade de broadcast WhatsApp, sendo vedada sua promoção sem reformulação prévia de arquitetura.
4. **Registro de Dívida Técnica (`botconversa-send`):** O suporte a `modo_envio: "por_condominio"` e `modo_envio: "por_bloco"` na Edge Function `botconversa-send` é formalmente classificado como **DÍVIDA TÉCNICA E SUPERFÍCIE RESIDUAL DE RISCO**. O código permanece inalterado nesta etapa e seu saneamento/remoção definitiva será realizado em ciclo próprio mediante prévia auditoria e homologação técnica.

---

## 📊 FASE 4.16G — ENCERRAMENTO OFICIAL — PROTEÇÃO POSTGRESQL DA MENSAGERIA HOMOLOGADA EM DEV

**Status da Fase:**
- 🟢 IMPLEMENTADA EM DEV
- 🟢 TESTADA EM DEV
- 🟢 HOMOLOGADA EM DEV
- 🟢 PRODUÇÃO INTOCADA
- 🟢 FASE ENCERRADA EM DEV
- 🛑 PROMOÇÃO PARA PRODUÇÃO NÃO AUTORIZADA

---

### 1. Ambientes de Execução

- **DEV (`avypyaxthvgaybplnwxu`):** Ambiente exclusivo onde todas as migrations, RPCs, constraints, permissões e testes foram aplicados, executados e homologados com 100% de sucesso.
- **PRODUÇÃO (`ivdgvpvifhfiktolmbvy`):** 100% INTOCADO. Nenhuma alteração foi executada no ambiente produtivo.

---

### 2. Migration Oficial Aplicada em DEV

- **Arquivo Versionado:** `supabase/migrations/20260824140000_phase_4_16g_whatsapp_postgresql_governance.sql`
- **Status:** 🟢 Aplicada e validada com sucesso no banco de dados DEV (`avypyaxthvgaybplnwxu`).
- **Produção:** Nenhuma aplicação da migration ocorreu em produção.

---

### 3. Proteções Arquiteturais Implementadas no PostgreSQL

1. **Colunas de Governança na `public.whatsapp_outbox`:**
   - `entity_type`: Identificador categórico da tabela de negócio física de origem.
   - `entity_id`: UUID da linha de negócio real emissora do evento.
   - `caller_function`: Nome canônico da Edge Function homologada.
   - `transaction_id`: UUID de idempotência transacional (chave única com `recipient_phone`).
2. **RPC Canônica Centralizada (`public.enqueue_whatsapp_transactional_message`):**
   - Função `SECURITY DEFINER` com `SET search_path = public, pg_temp;`.
   - Único ponto de entrada autorizado para enfileiramento na `public.whatsapp_outbox`.
3. **Derivação Automática de Multi-Tenancy:**
   - O `condominio_id` é derivado diretamente da consulta à tabela física da entidade de negócio, eliminando qualquer possibilidade de spoofing de condomínio pelo chamador.
4. **Whitelist e Matriz Fechada de Callers:**
   - Validação da amarração estrita `caller_function` $\rightarrow$ `message_type` $\rightarrow$ `entity_type`.
5. **Trava de Cardinalidade Atômica com Advisory Lock:**
   - `PERFORM pg_advisory_xact_lock(hashtext(v_normalized_entity || ':' || COALESCE(p_entity_id::text, v_canonical_phone)));`
   - Serializa requisições simultâneas e impede race conditions em cenários massivos ou de chunking.
6. **Quotas Horárias Especializadas:**
   - **`OTP` (`auth_users`):** Máximo de 5 solicitações por telefone a cada 60 minutos.
   - **`MANUAL_ADMIN` (`botconversa-send`):** Máximo de 5 destinatários por lote e cota de 15 mensagens por condomínio a cada 60 minutos.
7. **Proteção e Compatibilidade com `DUAL_NUMBER_NOTICE`:**
   - Cardinalidade estrita de 1 mensagem por telefone na tabela de controle, com agendamento seguro de 2 minutos de delay.
8. **Hardening Rígido de Permissões (DML):**
   - `REVOKE ALL ON public.whatsapp_outbox FROM anon, authenticated;`
   - `REVOKE INSERT, DELETE, TRUNCATE ON public.whatsapp_outbox FROM service_role;`
   - `GRANT SELECT, UPDATE ON public.whatsapp_outbox TO service_role;` (Permite ao worker executar claims e registrar status `sent`/`failed`).
   - `REVOKE EXECUTE ON FUNCTION public.enqueue_whatsapp_transactional_message FROM PUBLIC, anon;`
   - `GRANT EXECUTE ON FUNCTION public.enqueue_whatsapp_transactional_message TO authenticated, service_role;`

---

### 4. Regra Central de Governança

> **"BROADCAST PODE. BROADCAST VIA WHATSAPP NÃO."**

- **Push Notification (FCM):** Canal oficial e irrestrito para difusão ampla, comunicados em massa e avisos gerais.
- **Feed In-App / E-mail:** Canais oficiais autorizados para comunicação coletiva do condomínio.
- **WhatsApp:** Canal estritamente transacional, ponto a ponto e operacional.
- **BotConversa:** Transporte primário exclusivo para mensagens transacionais homologadas.
- **Meta Cloud API:** Contingência técnica *in-flight* exclusivamente para falhas transitórias de mensagens transacionais legítimas.
- **Isolamento Total de Fallback:** Falhas ou indisponibilidades de Push FCM, Feed In-App ou E-mail JAMAIS poderão ser convertidas em disparos de WhatsApp em massa.
- **Rejeição Automática:** Qualquer tentativa de disparo em massa via WhatsApp é terminantemente abortada pelo PostgreSQL com erro estruturado `GOVERNANCE_BLOCKED`.

---

### 5. Validação de Testes em DEV

- **18/18 Testes Funcionais Executados:** 🟢 **PASS (100% de sucesso)**
- **21/21 Testes Adversariais de Ataque:** 🟢 **BLOQUEADOS RIGOROSAMENTE**
- **70/70 Testes Automatizados Deno (`deno test`):** 🟢 **PASS (0 falhas)**

#### Vetores Adversariais Validados e Bloqueados:
- Caller Spoofing (`hacker-script`) ➔ 🟢 BLOQUEADO
- Condomínio Spoofing (Divergente / Forjado) ➔ 🟢 BLOQUEADO
- Entity ID Inexistente / Falsificado ➔ 🟢 BLOQUEADO
- Matriz Inválida (ex.: parcel com OTP) ➔ 🟢 BLOQUEADO
- NOTICE sem Entidade de Negócio Válida ➔ 🟢 BLOQUEADO
- NOTICE em Entidade Não Homologada ➔ 🟢 BLOQUEADO
- Tentativa de Inserção com `system_test` ➔ 🟢 BLOQUEADO
- Telefone Inválido fora do Padrão E.164 ➔ 🟢 BLOQUEADO
- Estouro de Cardinalidade por Entidade (Convites > 3) ➔ 🟢 BLOQUEADO
- Estouro de Quota de OTP (> 5/h por telefone) ➔ 🟢 BLOQUEADO
- Estouro de Quota de Mensagens Manuais (> 15/h por condomínio) ➔ 🟢 BLOQUEADO
- Direct INSERT na outbox como `authenticated` ➔ 🟢 BLOQUEADO (`42501 permission denied`)
- Direct INSERT na outbox como `service_role` ➔ 🟢 BLOQUEADO (`42501 permission denied`)
- EXECUTE na RPC como `anon` ➔ 🟢 BLOQUEADO (`42501 permission denied`)
- Duplicação com mesmo `transaction_id` ➔ 🟢 IDEMPOTENTE (Retorna ID original)
- Duplicação de Hash Idêntico Pendente ➔ 🟢 BLOQUEADO (Índice único parcial)
- Concorrência Paralela (`Promise.all`) ➔ 🟢 BLOQUEADO / SERIALIZADO via Advisory Lock
- Worker Claim & Update de Status ➔ 🟢 OPERACIONAL
- Rotina de Aviso de 2 Números (`DUAL_NUMBER_NOTICE`) ➔ 🟢 OPERACIONAL
- Tentativa de Duplicação de `DUAL_NUMBER_NOTICE` ➔ 🟢 BLOQUEADO por PK
- Tentativa de Transbordamento FCM ➔ WhatsApp ➔ 🟢 100% SEGREGADO

---

### 6. Fluxos Transacionais Preservados e Operacionais

Todos os 18 fluxos transacionais legítimos do ecossistema Condomeet permanecem plenamente operacionais e homologados:
1. `PARCEL` (Chegada de Encomenda — até 5 moradores da unidade)
2. `PARCEL_DELIVERED` (Retirada de Encomenda — comprovante aos moradores)
3. `VISITOR_INVITE` (Convite Emitido pelo Morador)
4. `VISITOR_AUTHORIZED` (Liberação de Visitante na Portaria)
5. `SOS` (Alerta de Emergência — Staff e 2 Contatos SOS)
6. `RESERVATION` (Reserva de Áreas Comuns)
7. `GARAGE NOTICE` (Locação de Vagas de Garagem)
8. `CLASSIFICADOS` (Moderação de Anúncios)
9. `INDICAÇÕES` (Notificação ao Profissional Recomendado)
10. `DOCUMENTOS` (Alertas de Vencimento de Documentos e Contratos)
11. `OCORRÊNCIAS` (Abertura e Resposta de Ocorrências)
12. `FALE SÍNDICO` (Notificação na Thread de Atendimento)
13. `WELCOME` (Boas-Vindas e Orientações de Cadastro)
14. `APPROVAL` (Aprovação de Morador)
15. `OTP` (Código de Recuperação de Senha)
16. `DUAL_NUMBER_NOTICE` (Aviso Oficial de Dois Números)
17. `CHATBOT` (Atendimento Interativo — até 10 msgs/24h)
18. `MANUAL_ADMIN` (Envio Manual Pontual do Síndico)

---

### 7. 🛡️ Produção — Intocada

- **Ambiente de Produção:** `ivdgvpvifhfiktolmbvy`
- **Status:** 🟢 **100% INTOCADO**
- **Evidências de Isolamento:**
  - Zero execuções SQL em produção;
  - Zero migrations aplicadas em produção;
  - Zero alterações de DDL ou DML em produção;
  - Zero alterações de RLS em produção;
  - Zero alterações de permissões em produção;
  - Zero alterações de secrets em produção;
  - Zero deploys de Edge Functions em produção;
  - Zero disparos ou mensagens reais enviadas para a base de produção.

---

### 8. Estado da Fase

- **FASE 4.16G:** 🟢 **HOMOLOGADA EM DEV** / 🟢 **ENCERRADA EM DEV**
- **Produção:** 🔴 **NÃO PROMOVIDA PARA PRODUÇÃO** / 🔴 **PROMOÇÃO AUTOMÁTICA PROIBIDA**

---

### 9. Próximo Gate Formal de Governança

A conclusão e homologação da FASE 4.16G no ambiente DEV **NÃO autoriza e NÃO constitui deploy automático em produção**.

A eventual promoção para produção exigirá a abertura de um novo ciclo formal contendo:
1. Revisão estática da migration e scripts de implantação;
2. Análise de impacto operacional em produção;
3. Verificação de compatibilidade reversa das Edge Functions em produção;
4. Validação da estratégia de observabilidade e métricas de erro;
5. Plano detalhado e testado de rollback;
6. Definição da janela e ordem estrita de execução de deploy;
7. Autorização explícita e formal do responsável pelo projeto.

---

## 📊 FASE 4.16G — ENCERRAMENTO OFICIAL — GOVERNANÇA POSTGRESQL DA MENSAGERIA EM PRODUÇÃO

### Status Final
- 🟢 Implementada em DEV
- 🟢 Homologada em DEV
- 🟢 Promovida para PRODUÇÃO
- 🟢 Produção validada
- 🟢 FASE ENCERRADA
- 🟢 Governança anti-broadcast ativa em PostgreSQL

### Ambientes
- **DEV:** `avypyaxthvgaybplnwxu`
- **PRODUÇÃO:** `ivdgvpvifhfiktolmbvy`

---

### Principais Controles Promovidos em Produção

1. **Colunas de Governança na `whatsapp_outbox`:**
   - `entity_type` (TEXT)
   - `entity_id` (TEXT)
   - `caller_function` (TEXT)
   - `transaction_id` (UUID)

2. **RPC Outbound Canônica:**
   - `public.enqueue_whatsapp_transactional_message`
   - `SECURITY DEFINER` com `SET search_path = public, pg_temp`
   - Validação atômica de Whitelist fechada de 18 callers autorizados, matriz Caller × MessageType, derivação física de multi-tenancy, advisory locks por entidade/telefone e cardinalidade.

3. **RPC Inbound Canônica:**
   - `public.record_whatsapp_incoming_message`
   - `SECURITY DEFINER` com `SET search_path = public, pg_temp`
   - Gravação estrita e exclusiva de mensagens inbound recebidas dos moradores (`status = 'received'`, `message_type = 'RESPOSTA_MORADOR'`), preservando o histórico do Chat Administrativo.

4. **Hardening de Permissões no PostgreSQL:**
   - `REVOKE INSERT, DELETE, TRUNCATE ON public.whatsapp_outbox FROM anon, authenticated, service_role;`
   - `GRANT SELECT, UPDATE ON public.whatsapp_outbox TO service_role;`
   - `GRANT EXECUTE ON FUNCTION public.enqueue_whatsapp_transactional_message TO authenticated, service_role;`
   - `GRANT EXECUTE ON FUNCTION public.record_whatsapp_incoming_message TO authenticated, service_role;`
   - Nenhuma role da aplicação possui acesso a `INSERT` direto na tabela `whatsapp_outbox`.

5. **Split-Worker e Provedores:**
   - `whatsapp-outbox-worker` preservado operando exclusivamente com `SELECT` e `UPDATE` via lock atômico `claim_single_whatsapp_message()`.
   - Webhook inbound operando exclusivamente via RPC `record_whatsapp_incoming_message`.
   - Provedor primário **BotConversa First** integralmente mantido.
   - Provedor secundário **Meta Cloud API** preservado estritamente como fallback transacional in-flight.

---

### Regra Central Permanente

> **"BROADCAST PODE VIA PUSH. BROADCAST VIA WHATSAPP NÃO."**

1. **Canais Coletivos Autorizados:** Push FCM / Feed In-App / E-mail continuam totalmente livres e autorizados para qualquer comunicação coletiva, avisos gerais, comunicados, enquetes, álbuns e convocações de assembleias.
2. **Restrição Absoluta do WhatsApp:** O canal WhatsApp permanece estritamente reservado para eventos transacionais, operacionais, unitários e vinculados a entidades registradas.
3. **Proibições Estruturais:**
   - Nenhum broadcast WhatsApp é permitido;
   - Nenhuma campanha WhatsApp é permitida;
   - Nenhum envio em massa por condomínio, por bloco ou por perfil é permitido no WhatsApp;
   - Falha do Push FCM jamais poderá gerar fallback de massa para o WhatsApp;
   - Falha do BotConversa jamais poderá transformar broadcast em fallback para a Meta Cloud API.

---

### Edge Functions Promovidas em Produção

- **`whatsapp-webhook`** — Versão `v4` — Status: `ACTIVE`
- **`botconversa-send`** — Versão `v4` — Status: `ACTIVE`
- **`whatsapp-outbox-worker`** — Versão `v9` — Status: `ACTIVE`

---

### Evidências de Validação em Produção

- **Migration:** Aplicada com sucesso (`20260824150000_phase_4_16g_whatsapp_postgresql_governance_prod.sql`);
- **Fila Outbox:** 0 mensagens `pending`, 0 mensagens `sending`;
- **Health Status:** `status = ok`, `whatsapp_connection_status = connected`, `fail_count = 0`, `last_error = null`;
- **Runtime / Circuit Breaker:** `Circuit State = CLOSED`, `Operational Mode = NORMAL`, `Consecutive Failures = 0`;
- **Erros de Banco / Permissão:** 0 erros `42501 (permission denied)`;
- **Erros de RPC:** 0 erros de execução de RPC;
- **Auditoria de Tráfego:** 0 disparos artificiais (validação passiva e orgânica);
- **Critérios de Abort:** Nenhum critério de abort acionado;
- **Regressão:** Nenhuma regressão operacional ou de negócio identificada.

---

### Integridade e Governança

- Produção auditada e validada;
- Nenhuma alteração realizada fora do escopo estrito da FASE 4.16G;
- Histórico arquitetural cronológico e FASE 4.15 integralmente preservados;
- Diretriz permanente de governança "BROADCAST PODE VIA PUSH. BROADCAST VIA WHATSAPP NÃO." consolidada e blindada na camada do PostgreSQL.

---

### Declaração de Encerramento

**FASE 4.16G — HOMOLOGADA, PROMOVIDA, VALIDADA E ENCERRADA EM PRODUÇÃO.**

---

## 🛡️ BASELINE OFICIAL — BANCO DE PRODUÇÃO

### Status: 🟢 **HOMOLOGADA E CONGELADA**

O banco oficial e único banco de produção do ecossistema Condomeet é:

```text
Nome: condomeet_Antigravity
Project Ref: avypyaxthvgaybplnwxu
Supabase URL: https://avypyaxthvgaybplnwxu.supabase.co
Região: us-east-2 (Ohio)
```

A aplicação oficial de produção:

```text
condomeet.app.br
```

deve obrigatoriamente utilizar esse projeto Supabase.

---

### 🚫 Banco Legado

O seguinte projeto **NÃO é banco de produção**:

```text
Nome: condomeetBD
Project Ref: ivdgvpvifhfiktolmbvy
```

**Classificação: BASE LEGADA / HISTÓRICA**

Esse projeto não deve ser utilizado pelas variáveis de ambiente `Production` da Vercel.

Não utilizar esse banco para:
- produção;
- deploy;
- migrations;
- correções funcionais;
- auditorias de produção;
- homologações de produção;
- validações de schema da aplicação atual.

---

### 🔐 Regra de Produção

Qualquer alteração futura das variáveis de ambiente da Vercel que possa modificar:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
```

deve obrigatoriamente validar o Project Ref antes do deploy.

O resultado esperado em `Production` é:

```text
avypyaxthvgaybplnwxu
```

Nunca:

```text
ivdgvpvifhfiktolmbvy
```

---

### 🔎 Validação Obrigatória Antes de Alterações de Produção

Antes de qualquer migration, alteração de schema, RLS, view, função ou correção funcional relacionada ao banco:

1. Identificar o Supabase Project Ref;
2. Confirmar que é `avypyaxthvgaybplnwxu`;
3. Confirmar que o nome é `condomeet_Antigravity`;
4. Confirmar que o ambiente é Production;
5. Somente depois executar a alteração autorizada.

Se o Project Ref não corresponder ao banco oficial:
**PARAR A EXECUÇÃO. NÃO REALIZAR ALTERAÇÕES.**

---

### 🧭 Regra de Governança

Nenhum agente, ferramenta ou processo automatizado deve assumir que `condomeetBD` é o banco oficial apenas porque contém dados históricos de encomendas. O nome oficial e o Project Ref são definidos por esta baseline.

---

### 🔒 Relação com Baselines Existentes

Esta baseline não altera nenhuma regra funcional existente.

Permanece integralmente preservada a:
- **Baseline Oficial — Retirada de Encomendas por Terceiros**

E permanecem preservadas todas as baselines relacionadas ao:
- WhatsApp;
- `whatsapp_outbox`;
- Workers;
- RLS;
- Módulos existentes;
- Contratos do banco oficial.

---

### Declaração de Status

- **STATUS:** 🟢 **HOMOLOGADA E CONGELADA**
- **BANCO OFICIAL:** `condomeet_Antigravity`
- **PROJECT REF:** `avypyaxthvgaybplnwxu`
- **BANCO LEGADO:** `condomeetBD` (`ivdgvpvifhfiktolmbvy`)
- **PRODUÇÃO:** `condomeet.app.br`
- **ALTERAÇÃO FUTURA DE APONTAMENTO:** Somente mediante auditoria e homologação formal.

---

## 📊 Baseline Oficial — Homologação da UX de Encomendas para Portaria

### 1. Status
🟢 **BASELINE / CORREÇÃO HOMOLOGADA E CONGELADA**

### 2. Escopo
Flutter Mobile — Home / Encomendas / Portaria

### 3. Causa Raiz
O perfil Porteiro estava sendo tratado visualmente como usuário/morador na Home, fazendo com que o card consultasse contexto pessoal e exibisse *"Nenhuma encomenda pendente nos últimos 7 dias"*, apesar da existência de encomendas pendentes no condomínio.

### 4. Regra Homologada

#### Porteiro / Portaria:
- **Contexto:** Condomínio (`condominio_id = authState.condominiumId`);
- Considera todas as encomendas `status = 'pending'`;
- Sem filtro artificial de 7 dias;
- Contador representa o volume real e exato de pendências;
- Ação principal direciona para `/pending-deliveries`.

#### Morador:
- **Contexto:** Usuário / unidade (`resident_id`);
- Mantém a visão pessoal;
- Mantém o filtro dos últimos 7 dias;
- Direciona para `/parcel-dashboard`.

### 5. Ambiente Oficial
- **Banco Único Autorizado:** `condomeet_Antigravity`
- **Project Ref:** `avypyaxthvgaybplnwxu`
- **Banco Legado:** `condomeetBD` / `ivdgvpvifhfiktolmbvy` permanece formalmente classificado como **LEGADO e FORA DE PRODUÇÃO**.

### 6. Homologação Final (25/08/2026)

#### Porteiro Montserrat:
- Login: **PASS**
- Card Home: **PASS**
- Contagem: **PASS**
- Navegação: **PASS**
- Encomendas visíveis: **PASS**

#### Morador:
- Home: **PASS**
- Parcel Dashboard: **PASS**

#### Ambiente:
- Banco oficial: **PASS**
- Banco legado: **NÃO UTILIZADO**

#### Testes Técnicos:
- Flutter tests: **50/50 PASS**
- Flutter analyze: **0 issues**

### 7. Não Regressão
Permanecem integralmente preservados:
- Baseline Retirada de Encomendas por Terceiros;
- Infraestrutura WhatsApp;
- RLS;
- Contratos existentes;
- Banco oficial;
- Histórico de migrations.

### 8. Regra Futura
Qualquer alteração no comportamento de encomendas da Portaria deverá passar por nova auditoria e homologação formal.

---

## 📊 Baseline Oficial — Isolamento Definitivo do Banco de Produção

### 1. Status
🟢 **BASELINE OFICIAL — BANCO ÚNICO E EXCLUSIVO**

### 2. Banco Oficial
- **Nome:** `condomeet_Antigravity`
- **Project Ref:** `avypyaxthvgaybplnwxu`
- **Supabase URL:** `https://avypyaxthvgaybplnwxu.supabase.co`

### 3. Banco Legado
- **Nome:** `condomeetBD`
- **Project Ref:** `ivdgvpvifhfiktolmbvy`
- **Status:** **LEGADO / FORA DE PRODUÇÃO / NÃO UTILIZAR**

### 4. Resultado da Auditoria Forense (25/08/2026)
Auditoria realizada em regime **READ-ONLY ABSOLUTO** em todo o ecossistema.
**Resultado:** **ZERO DEPENDÊNCIA OPERACIONAL DO BANCO LEGADO.**

Validado integralmente que:
- Mobile Flutter utiliza exclusivamente o banco oficial;
- Web Next.js utiliza exclusivamente o banco oficial;
- Supabase Client/Server utiliza exclusivamente o banco oficial;
- Edge Functions utilizam exclusivamente o banco oficial;
- Workers utilizam exclusivamente o banco oficial;
- PostgreSQL Functions e Triggers do banco oficial não possuem referência executável ao banco legado;
- pg_cron utiliza exclusivamente o banco oficial;
- Storage operacional utiliza exclusivamente o banco oficial;
- PowerSync utiliza exclusivamente o ambiente oficial;
- Supabase CLI está vinculada ao Project Ref oficial;
- Não existem consultas ao banco legado;
- Não existem gravações no banco legado;
- Não existem RPCs direcionadas ao banco legado;
- Não existem fallbacks operacionais para o banco legado;
- Não existem conexões secundárias ativas para o banco legado.

### 5. Regra Permanente
A partir desta baseline, o único banco autorizado para qualquer operação do Condomeet é `avypyaxthvgaybplnwxu`.

É expressamente proibida a introdução de:
- URLs do banco legado;
- Project Ref legado;
- Credenciais do banco legado;
- Fallbacks para o banco legado;
- Conexões secundárias;
- Sincronizações;
- Workers;
- Cron jobs;
- Edge Functions;
- RPCs;
- Storage;
- Integrações externas

que utilizem `ivdgvpvifhfiktolmbvy`.

### 6. Governança
Qualquer alteração futura envolvendo Supabase, Vercel, Flutter, Web, Edge Functions, Workers, Storage, PowerSync, migrations, RPCs ou cron deverá validar previamente que o destino permanece `avypyaxthvgaybplnwxu`.

Qualquer tentativa de introduzir novamente o banco legado deverá ser tratada como violação de baseline e bloqueada até nova auditoria formal.

### 7. Preservação
Permanecem integralmente preservadas:
- Baseline Retirada de Encomendas por Terceiros;
- Baseline WhatsApp / Meta / BotConversa;
- Baselines de RLS;
- Histórico de migrations;
- Contratos existentes.

---

## 🛡️ Baseline Oficial — Leitura Automática de Bloco e Apartamento por Foto (IA)

### 1. Identificação e Status
- **Título Oficial:** Baseline Oficial — Leitura Automática de Bloco e Apartamento por Foto (IA)
- **Status:** **HOMOLOGADA E CONGELADA**
- **Escopo:** App Mobile Flutter + Painel Web Next.js + Supabase Edge Function
- **Funcionalidade:** Leitura automática de Bloco e Apartamento a partir da fotografia de uma encomenda via IA.

### 2. Banco Oficial Único
- **Banco Oficial:** `condomeet_Antigravity`
- **Project Ref:** `avypyaxthvgaybplnwxu`
- **Supabase URL:** `https://avypyaxthvgaybplnwxu.supabase.co`
- **Banco Legado (`ivdgvpvifhfiktolmbvy` / `condomeetBD`):** FORA DE PRODUÇÃO e PROIBIDO para qualquer operação da aplicação. Não utilizar fallback, conexão alternativa, retry ou failover para o banco legado.

### 3. Modelo de IA Homologado
- **Provedor:** Google Gemini
- **Modelo Oficial:** `gemini-2.5-flash-lite` (Model ID: `gemini-2.5-flash-lite`)
- **Papel da IA:** A IA é utilizada exclusivamente para leitura visual da fotografia da encomenda. A IA NÃO é fonte de verdade da unidade.

### 4. Camada de Edge Function Oficial
- **Edge Function Única:** `parcel-ai-extract`
- **Isolamento de Comunicação:** É a única camada autorizada a conversar com a API Gemini.
- **Unificação:** Flutter e Web utilizam a mesma Edge Function; não existem implementações separadas.

### 5. Regra Fundamental de Não-Invenção
- A IA NÃO pode inventar, deduzir ou supor Bloco ou Apartamento.
- Se o Bloco não estiver legível: `bloco = null`.
- Se o Apartamento não estiver legível: `apartamento = null`.
- Se somente o Apartamento for identificado, o sistema NÃO deve deduzir o Bloco.
- Se a fotografia estiver ilegível ou não possuir dados suficientes: `leitura_ok = false`.

### 6. Validação Estrita Contra o Condomínio
- A resposta da IA deve ser obrigatoriamente validada contra a estrutura real de unidades do condomínio atualmente autenticado (`public.blocos`, `public.apartamentos`, `public.unidades`).
- A unidade somente poderá ser autopreenchida quando a combinação **BLOCO + APARTAMENTO** existir efetivamente no condomínio.
- A IA nunca cria uma unidade.
- Se a unidade identificada não existir no condomínio: **NÃO selecionar automaticamente** e exibir alerta explicativo ao operador (`"⚠️ A unidade identificada na foto não foi encontrada neste condomínio. Confira os dados manualmente."`).

### 7. Comportamento de Sucesso
- Quando a unidade for identificada e validada:
  - Bloco → preenchido automaticamente.
  - Apartamento → preenchido automaticamente.
  - Exibir: `"✓ Unidade identificada automaticamente pela foto"`.
- O usuário permanece 100% livre para alterar os campos a qualquer momento.

### 8. Fallback Manual Obrigatório
- A IA possui caráter estritamente **AUXILIAR**.
- Em qualquer situação de:
  - Foto ilegível;
  - Leitura parcial;
  - Timeout de conexão;
  - Erro HTTP (4xx, 5xx);
  - Indisponibilidade de serviço;
  - Resposta inválida;
  - Unidade inexistente no condomínio;
- O formulário deve permanecer 100% operacional, permitindo ao operador preencher Bloco, Apartamento, Morador e demais campos manualmente.
- A falha da IA jamais pode impedir ou travar o cadastro da encomenda.

### 9. Proteção Contra Race Condition (Concorrência de Fotos)
- Quando duas fotografias forem analisadas em sequência, somente a resposta correspondente à fotografia mais recente poderá atualizar o estado atual do formulário.
- Respostas atrasadas de fotografias anteriores devem ser sumariamente descartadas através do controle atômico de ID de requisição (`analysisRequestId`).
- Regra homologada tanto no Flutter (`_analysisRequestId`) quanto no Web (`analysisRequestId.current`).

### 10. Plataformas e Arquivos Homologados
- **App Mobile (Flutter):**
  - Arquivo principal: `lib/features/portaria/presentation/screens/parcel_registration_screen.dart`
  - Fluxo: `ImagePicker` → `parcel-ai-extract` → validação → autopreenchimento → confirmação → cadastro.
- **Painel Web (Next.js):**
  - Arquivo principal: `web-app/app/condo/registrar-encomenda/parcel-register-form.tsx`
  - Contextos atendidos: `/condo/registrar-encomenda` (Portaria) e `/admin/registrar-encomenda` (Administração).
  - Fluxo: Câmera ou Arquivo → `parcel-ai-extract` → validação → autopreenchimento → confirmação → cadastro.

### 11. Persistência e Não-Interferência
- A IA **NÃO** realiza `INSERT` diretamente no banco de dados.
- O fluxo homologado permanece:
  - Foto → Análise IA → Preenchimento/Ajuste dos campos → Confirmação do operador → Upload definitivo para bucket `parcel-photos` → `INSERT` em `public.encomendas`.
- O fluxo original e transacional de cadastro permanece preservado.

### 12. Privacidade e Segurança de Secrets
- A imagem enviada para análise é processada **em memória**.
- O Base64 utilizado no processamento não é persistido em banco, storage temporário ou logs.
- A `GEMINI_API_KEY`:
  - **NÃO** existe no Flutter;
  - **NÃO** existe no código cliente Web;
  - **NÃO** aparece em bundles de frontend;
  - **NÃO** é retornada em payloads HTTP ao navegador.
- A chave reside exclusivamente no ambiente seguro de backend da Edge Function (`Deno.env.get("GEMINI_API_KEY")`).

### 13. Integração com Estruturas Existentes
- A funcionalidade não altera o modelo de dados de encomendas (`public.encomendas`), preservando as relações estruturais com:
  - `public.blocos`
  - `public.apartamentos`
  - `public.unidades`
  - `public.perfil`

### 14. Não-Regressão — Mensageria WhatsApp
- A implementação da IA não altera nenhuma das seguintes estruturas homologadas:
  - `whatsapp_outbox`
  - `smartSend()`
  - `whatsapp-parcel-notify`
  - `whatsapp-outbox-worker`
  - `tr_fn_encomenda_delivered`
  - `message_type`
  - Prioridades e regras de fila do Split-Worker
- A mensageria permanece 100% intacta.

### 15. Não-Regressão — Retirada de Encomendas por Terceiros
- Permanecem integralmente preservadas as colunas, triggers e regras:
  - `picked_up_by_id`
  - `picked_up_by_name`
  - `silent_discharge`
  - `fn_validate_encomenda_discharge`
  - `tr_validate_encomenda_discharge`
- Nenhuma regra da Baseline de Retirada por Terceiros foi modificada.

### 16. Resultados Oficiais da Homologação (FASE 5)
- **Supabase Edge Function (`parcel-ai-extract`):** 15/15 cenários aprovados (`deno test`).
- **Flutter (Mobile):** 19/19 testes aprovados (`flutter test`) e `flutter analyze` com 0 issues.
- **Web (Next.js):** 9/9 cenários E2E aprovados (`deno test`), TypeScript (`tsc --noEmit`) 0 erros, ESLint 0 erros/warnings e Build de Produção (`next build`) com 102/102 páginas compiladas com sucesso.
- **Critérios Gerais:** 22/22 critérios de aceite atendidos e aprovados.

### 17. Cenários Homologados
- Leitura completa (Bloco + Apto);
- Leitura parcial (somente Apto);
- Leitura parcial (somente Bloco);
- Foto ilegível / borrada;
- Ausência de etiqueta / pacote liso;
- Unidade inexistente no condomínio;
- Preenchimento manual puro;
- Alteração manual após IA (prevalência da escolha do operador);
- Race condition (Foto A vs Foto B concorrentes);
- Timeout de conexão;
- Erro HTTP / indisponibilidade;
- Cadastro final transacional;
- Upload da imagem para `parcel-photos`;
- Triggers e notificações de entrega;
- Mensageria WhatsApp;
- Contexto de Portaria e Administração (Web e Mobile).

### 18. Banco Legado
- Não existe dependência operacional do banco `ivdgvpvifhfiktolmbvy` (`condomeetBD` / `https://ivdgvpvifhfiktolmbvy.supabase.co`).
- Auditoria forense final: **ZERO dependência operacional**.

### 19. Regra de Governança Permanente
Qualquer alteração futura na funcionalidade de leitura automática por foto deverá obrigatoriamente:
1. Ser precedida de auditoria técnica.
2. Preservar a regra de não-invenção.
3. Preservar a validação contra unidades do condomínio.
4. Preservar o fallback manual.
5. Preservar a proteção contra race condition.
6. Preservar a segurança da `GEMINI_API_KEY`.
7. Preservar o banco oficial (`avypyaxthvgaybplnwxu`).
8. Preservar as baselines de WhatsApp.
9. Preservar a Baseline de Retirada por Terceiros.
10. Passar por nova bateria de testes automatizados.
11. Ser formalmente homologada antes de substituir esta baseline.

### 20. Declaração Final de Homologação
```text
================================================================================
BASELINE OFICIAL — LEITURA AUTOMÁTICA DE BLOCO E APARTAMENTO POR FOTO
STATUS: HOMOLOGADA E CONGELADA

BANCO OFICIAL:
condomeet_Antigravity (avypyaxthvgaybplnwxu)

EDGE FUNCTION:
parcel-ai-extract

MODELO:
gemini-2.5-flash-lite

PLATAFORMAS:
Flutter + Web Next.js

RESULTADO:
22/22 critérios de aceite aprovados.

INTEGRAÇÃO WHATSAPP:
PRESERVADA E INALTERADA.

RETIRADA POR TERCEIROS:
PRESERVADA E INALTERADA.

BANCO LEGADO:
FORA DE PRODUÇÃO E SEM DEPENDÊNCIA OPERACIONAL.

ALTERAÇÕES FUTURAS:
SOMENTE MEDIANTE NOVA AUDITORIA, TESTES E HOMOLOGAÇÃO FORMAL.
================================================================================
```

---

## 📊 Baseline Oficial — Módulo Documentos (Web + Mobile) — Homologado e Congelado

A evolução estrutural do módulo **Documentos** foi concluída, homologada e formalmente congelada em 26/08/2026.

### 1. Arquitetura e Contrato de Dados (Fonte Canônica)
- **`tipo_id` (UUID FK -> `documento_tipos.id` ON DELETE SET NULL):** É a fonte canônica e obrigatória para classificação estruturada de tipos de documentos.
- **`tipo` (VARCHAR):** Mantido exclusivamente para compatibilidade legada e preenchido com o slug derivado do nome do tipo.
- **`sem_validade` (BOOLEAN NOT NULL DEFAULT false):** Define explicitamente a vigência permanente de documentos. Protegido pela constraint `check_documentos_sem_validade_consistente` (exige `data_validade IS NULL` e `lembrar_* = false` quando `sem_validade = true`).
- **`documento_tipos`:** Armazena tipos de sistema (`is_system = true`, `condominio_id IS NULL`, 17 tipos oficiais) e tipos customizados por condomínio (`is_system = false`, `condominio_id = <UUID>`).
- **`documento_tipo_prioridades`:** Tabela de configuração deliberada pelo síndico/administrador de quais tipos são prioritários no condomínio (`is_prioritario = true`).

### 2. Desacoplamento: Prioritários vs Mais Utilizados
- **Prioritários:** Decisão administrativa deliberada, persistida em `documento_tipo_prioridades`.
- **Mais Utilizados:** Métrica dinâmica calculada em tempo real com base no volume efetivo de documentos de cada `tipo_id` no condomínio.

### 3. Preservação de Dados Legados
- Documentos existentes com `tipo = 'obrigatorio'` e `tipo_id = NULL` devem ser rigorosamente preservados sem inferência automática.
- A interface Web e Mobile exibe o fallback seguro `"Tipo não classificado"` ou o `tipo` legado, permitindo classificação manual posterior pelo administrador.

### 4. Notificações e Anti-Duplicidade
- Notificações de publicação respeitam o trigger `tr_documento_avisar_moradores`:
  - `INSERT` com `avisar_moradores = true` ➔ Notifica;
  - `UPDATE` de `avisar_moradores = false -> true` ➔ Notifica;
  - `UPDATE` de `avisar_moradores = true -> true` ➔ **Anti-duplicidade ativo (Zero disparos repetidos)**.

### 5. Isolamento Multi-Tenant e Módulo Contratos
- Triggers de guarda `tr_documentos_tipo_condo_guard`, `tr_doc_prioridades_condo_guard` e `tr_documento_tipo_delete_guard` impedem vínculos cruzados entre condomínios e exclusão de tipos em uso.
- O módulo **Contratos** (`contratos`, `contrato_pastas`, `/admin/contratos`, `AdminContratosScreen`, `contracts_screen.dart`) opera de forma 100% isolada e independente do módulo Documentos.

### 6. Regra Permanente de Congelamento
É terminantemente proibido realizar alterações de schema, migrations, DDLs, RLS, triggers ou refatorações no módulo Documentos sem abertura de nova RFC, análise de impacto e aprovação explícita.

---

## 🔒 Baseline Oficial — Módulo Contratos Inteligentes (Web + Mobile) — Homologado e Congelado

A evolução estrutural e funcional do módulo **Contratos** para **Contratos Inteligentes (Fase 4)** foi concluída, homologada ponta a ponta e formalmente congelada em 26/08/2026.

### 1. Arquitetura e Contrato de Dados (Fonte Canônica)
- **`fornecedor_id` (UUID FK -> `public.fornecedores(id)` ON DELETE RESTRICT):** Fonte canônica e obrigatória quando houver fornecedor cadastrado na plataforma.
- **`fornecedor_nome` (TEXT DEFAULT NULL):** Identificação textual de fornecedor avulso/informal, preenchido **exclusivamente quando `fornecedor_id IS NULL`**.
- **Constraint de Precedência:** `check_contratos_fornecedor_consistente` exige `fornecedor_id IS NULL OR fornecedor_nome IS NULL` (bloqueando estados semanticamente conflitantes).
- **`valor_mensal` (NUMERIC(12,2) DEFAULT NULL):** Custo mensal recorrente em R$ (com constraint `check_contratos_valor_positivo` exigindo `valor_mensal >= 0`). O campo é puramente gerencial e não constitui módulo financeiro ou ERP.
- **`sem_validade` (BOOLEAN NOT NULL DEFAULT false):** Define contratos por prazo indeterminado / permanentes. Protegido pela constraint `check_contratos_sem_validade_consistente` (exige `data_validade IS NULL` e lembretes desativados).

### 2. Status Dinâmico Derivado (Sem Coluna Física)
O status do contrato não é armazenado fisicamente no banco de dados. É derivado dinamicamente da vigência em tempo real:
- ⚪ **`PERMANENTE`:** `sem_validade = true` (Badge cinza).
- ⚪ **`INDETERMINADO`:** `data_validade IS NULL` em contratos legados (Badge cinza).
- 🟢 **`VIGENTE`:** `data_validade - HOJE > 30 dias` (Badge verde).
- 🟡 **`VENCENDO`:** `0 < data_validade - HOJE <= 30 dias` (Badge amarelo).
- 🟠 **`VENCE_HOJE`:** `data_validade = HOJE` (Badge laranja).
- 🔴 **`VENCIDO`:** `data_validade < HOJE` (Badge vermelho).

### 3. Visão Executiva no Topo (Web & Mobile)
- **Contratos Ativos:** Quantidade de contratos vigentes ou permanentes (`sem_validade = true` OU `data_validade >= HOJE`).
- **Vencendo ≤ 30 dias:** Quantidade de contratos demandando renovação imediata.
- **Contratos Vencidos:** Quantidade de contratos expirados (exibindo sub-indicador financeiro caso haja contratos vencidos com valor a regularizar).
- **Custo Mensal Ativo:** Soma de `valor_mensal` exclusivamente dos contratos ativos/permanentes. Contratos vencidos **não** entram nesta soma.

### 4. Experiência Web e Mobile
- **Web Next.js:** Rota `/admin/contratos` opera sobre o componente dedicado `ContratosClient`, com formulário de baixa carga cognitiva, `FornecedorSelector` com modal inline `+ Novo Fornecedor`, busca unificada e pílulas de filtro rápido.
- **Mobile Flutter:** Tela `AdminContratosScreen` com paridade total, cards comerciais ricos e `FornecedorBottomSheet` mobile-first.
- **Visibilidade de Moradores:** `mostrar_moradores = true` permite acesso condômino no Portal de Transparência (`/condo/contratos` e `ContractsScreen`). `mostrar_moradores = false` mantém o contrato estritamente administrativo (protegido por RLS via `public.is_admin_of_condo`).

### 5. Alertas Administrativos e Destinatários Canônicos
- **Edge Functions:** `contratos-vencimento-check` (varredura diária de prazos) e `contratos-push-notify` (envio de push FCM).
- **Janelas Oficiais de Alerta:** `90_DIAS` (preventivo), `30_DIAS` (atenção), `VENCE_HOJE` (crítico) e `VENCIDO` (pós-vencimento 1 dia após expiração).
- **Destinatários Exclusivamente Administrativos:** Alertas são enviados estritamente para perfis com papéis canônicos administrativos (`'síndico'`, `'sindico'`, `'admin'`, `'administrador'`, `'subsíndico'`, `'subsindico'`). Moradores comuns possuem **zero recebimento** de alertas de contratos.
- **Contratos Ignorados:** Contratos com `sem_validade = true` ou `data_validade IS NULL` não geram alertas.

### 6. Anti-Spam e Idempotência Rigorosa
- A tabela `public.contrato_notificacoes_log` armazena o histórico com chave única `(contrato_id, tipo_alerta, data_referencia, destinatario_id)`.
- Cada evento é disparado no máximo uma única vez por destinatário, suprimindo qualquer disparo repetido em re-execuções da rotina.

### 7. Multi-Tenancy e Segurança Relacional
- Isolamento absoluto entre condomínios em contratos, fornecedores e notificações.
- Trigger `tr_contratos_fornecedor_condo_guard` bloqueia no PostgreSQL qualquer vínculo cruzado de fornecedores entre condomínios.
- Trigger `tr_fornecedores_delete_guard` impede a exclusão física de fornecedores que possuam contratos ativos vinculados.

### 8. Preservação de Dados Legados (Zero Inferência)
- O contrato legado existente em produção (`"TEste contrato"`) permanece 100% preservado com `fornecedor_id = NULL`, `valor_mensal = NULL` e status derivado *"Vencido"*, sem inferências textuais forçadas.

### 9. Escopo Excluído da Baseline
Ficam expressamente excluídos desta baseline: WhatsApp para contratos, assinatura digital, gestão de reajustes/índices, workflow jurídico, contas a pagar e ERP financeiro. Qualquer adição futura dependerá de abertura de nova RFC.

---

## 🔒 BASELINE OFICIAL — SISTEMA DE NOTIFICAÇÕES COM ÁUDIO CONDOMEET

A infraestrutura de notificações push com assinatura sonora exclusiva do ecossistema Condomeet encontra-se **auditada, padronizada, validada estruturalmente e homologada em produção**.

### 1. Padrão Arquitetural de Áudio por Plataforma

#### Android:
- **Canal Oficial Único:** `avisos_v2`
- **Nome do Som:** `condomeet`
- **Arquivo Físico:** `android/app/src/main/res/raw/condomeet.mp3` (MPEG ADTS Layer III, 128 kbps, 44.1 kHz Mono)
- **Importância do Canal:** `Importance.high`
- **Fallback Padrão (AndroidManifest.xml):** `com.google.firebase.messaging.default_notification_channel_id = avisos_v2`

#### iOS (Apple):
- **Nome do Som:** `condomeet.aiff`
- **Arquivo Físico:** `ios/Runner/condomeet.aiff` (16-bit Linear PCM, 44.1 kHz Mono, empacotado no `Main Bundle` do Runner.app)
- **Prioridade APNs:** `"apns-priority": "10"`
- **Apresentação em Primeiro Plano:** `setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true)`

### 2. Contrato de Payload Unificado no Backend (Edge Functions)
Todas as 25 rotinas de envio de push via FCM v1 no Supabase seguem estritamente a estrutura:
```json
{
  "message": {
    "token": "<FCM_TOKEN>",
    "notification": { "title": "<TITULO>", "body": "<CORPO>" },
    "data": { ... },
    "android": {
      "priority": "high",
      "notification": { "channel_id": "avisos_v2", "sound": "condomeet" }
    },
    "apns": {
      "headers": { "apns-priority": "10" },
      "payload": {
        "aps": { "sound": "condomeet.aiff", "badge": 1 }
      }
    }
  }
}
```

### 3. Módulos Cobertos e Padronizados
- Encomendas (`parcel-push-notify`)
- Avisos e Comunicados (`avisos-push-notify`, `scheduled-push-worker`, `universal-push-notify`)
- SOS / Emergência (`sos-push-notify`)
- Visitantes e Convites (`visita-proprietario-push-notify`, `convite-whatsapp-notify`)
- Reservas de Áreas Comuns (`reserva-notify`, `reservas-reminder`)
- Álbum de Fotos (`album-push-notify`)
- Documentos e Contratos (`documentos-push-notify`, `contratos-push-notify`)
- Multas e Ocorrências (`multas-push-notify`, `ocorrencia-notify`)
- Financeiro (`finance-push-worker`)
- Garagem, Classificados, Vistorias, Estoque e Enquetes

### 4. Limitações Soberanas do Sistema Operacional
A reprodução do áudio permanece condicionada aos controles de hardware e sistema operacional do aparelho do usuário (Modo Silencioso/Vibração, Foco/Não Perturbe, Volume de Alertas e Permissões de Notificação concedidas pelo usuário). A supressão por esses controles do SO não constitui falha do Condomeet.

### 5. Regra Permanente de Congelamento
Esta implementação encontra-se **HOMOLOGADA E CONGELADA**. É expressamente proibido alterar identificadores de canal (`avisos_v2`), nomes de áudio (`condomeet`, `condomeet.aiff`), arquivos de mídia física ou parâmetros de payload sem abertura formal de nova RFC e autorização explícita.


