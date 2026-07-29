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
8. **Banco de Homologação:** O módulo foi homologado em produção utilizando o banco `ivdgvpvifhfiktolmbvy` (`condomeetBD`).

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

## ✅ STATUS OFICIAL

**Situação:** BASELINE HOMOLOGADA E CONGELADA.

Esta diretriz passa a integrar a governança permanente da plataforma Condomeet.

Qualquer alteração nesta política deverá ocorrer exclusivamente mediante uma nova RFC (Request for Change), acompanhada de evidências técnicas, auditoria do código-fonte e homologação formal antes de sua incorporação à arquitetura oficial.












