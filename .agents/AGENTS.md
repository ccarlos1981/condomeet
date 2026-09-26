# 🏛️ Condomeet AI-OS — Operational Loader
## Sistema Operacional de Governança, Engenharia e Contexto Modular

> **STATUS:** `OPERATIONAL / ACTIVE`  
> **ARQUITETURA:** `AI-OS (ANTIGRAVITY OPERATING SYSTEM)`  
> **INSTÂNCIA:** `CONDOMEET (SOBERANO)`  
> **HISTÓRICO ARQUIVADO:** [`ai-os/archive/legacy-agents-monolith-baseline.md`](../ai-os/archive/legacy-agents-monolith-baseline.md)

---

## 1. Identificação do AI-OS

O **AI-OS (Antigravity Operating System)** é a arquitetura modular soberana de governança, engenharia e contexto do ecossistema Condomeet, estruturada nas seguintes camadas:

- **Governance (`ai-os/governance/`):** Regras normativas mandatórias, DDLs, triggers, constraints relacionais, contratos de payloads e restrições técnicas permanentes.
- **Decisions (`ai-os/decisions/`):** Registros de Decisão Arquitetural (ADRs) documentando a fundamentação técnica, contexto, alternativas avaliadas e justificativas de design.
- **Runbooks (`ai-os/runbooks/`):** Checklists e procedimentos operacionais prescritivos passo a passo para execuções críticas (migrations, deploys, integrações).
- **Context (`ai-os/context/`):** Topologia de ambientes, arquitetura sistêmica global e catálogo funcional de módulos.
- **Current State (`ai-os/CURRENT_STATE.md`):** Estado operacional presente, identificadores de instâncias ativas, credenciais públicas de homologação e dívidas técnicas sob observação.
- **Archive (`ai-os/archive/`):** Memória fria de auditoria forense e baseline imutável para recuperação de desastres (rollback).

---

## 2. Invariantes Globais Supremas (Regras Invioláveis)

Independentemente do domínio técnico ou funcional da tarefa, as seguintes 5 invariantes são obrigatórias e universais em todo o ecossistema:

1. **Banco de Produção Oficial Único:**  
   O ecossistema opera exclusivamente sobre o banco Supabase oficial `avypyaxthvgaybplnwxu` (`condomeet_Antigravity`). O banco legado `ivdgvpvifhfiktolmbvy` está formal e fisicamente descontinuado, sendo expressamente proibida qualquer conexão, leitura ou escrita nele.  
   *(Ref: [`ADR-001`](../ai-os/decisions/ADR-001-banco-producao-oficial-unico.md), [`database-rules.md`](../ai-os/governance/database-rules.md))*

2. **Isolamento Multi-Tenant e RLS Mandatório:**  
   Todas as tabelas do schema `public` devem possuir Row Level Security (RLS) habilitado. Toda e qualquer consulta, view, mutation, Edge Function ou RPC deve filtrar obrigatoriamente por `condominio_id` válido.  
   *(Ref: [`ADR-003`](../ai-os/decisions/ADR-003-isolamento-multi-tenant-rls.md), [`rls-multitenancy.md`](../ai-os/governance/rls-multitenancy.md))*

3. **SuperAdmin Centralizado:**  
   A tabela `public.system_superadmins(email TEXT PRIMARY KEY)` é a única fonte da verdade para privilégios administrativos globais da plataforma. É expressamente proibido hardcode de e-mails em código frontend ou backend.  
   *(Ref: [`ADR-002`](../ai-os/decisions/ADR-002-centralizacao-superadmins.md), [`security-access.md`](../ai-os/governance/security-access.md))*

4. **WhatsApp Estritamente Transacional / Operacional (Anti-Marketing):**  
   O canal WhatsApp destina-se exclusivamente a mensagens operacionais transacionais (`Utility`) e códigos de acesso (`Authentication`). É terminantemente proibido qualquer envio ou template de Marketing no ecossistema Condomeet.  
   *(Ref: [`ADR-007`](../ai-os/decisions/ADR-007-segregacao-canais-push-whatsapp.md), [`messaging-rules.md`](../ai-os/governance/messaging-rules.md))*

5. **Governança de Migrations com Git Soberano:**  
   Nenhuma alteração estrutural no PostgreSQL (tabelas, triggers, RPCs, constraints, RLS) pode ser executada manualmente via dashboard. Toda evolução exige migration versionada no repositório Git, validada pelo ciclo formal de 8 etapas.  
   *(Ref: [`ADR-009`](../ai-os/decisions/ADR-009-governanca-migrations-git-soberano.md), [`sql-migration-8-steps.md`](../ai-os/runbooks/sql-migration-8-steps.md))*

---

## 3. Protocolo Mandatório de Leitura e Ação

Antes de propor código, planejar refatorações ou executar modificações em qualquer módulo:

1. **Identificar o Domínio:** Mapeie o domínio funcional solicitado (ex: Encomendas, Notificações, Autenticação, Banco).
2. **Consultar o Mapa de Roteamento:** Localize no Mapa de Roteamento (Seção 4) os arquivos especializados aplicáveis.
3. **Leitura Prévia Obrigatória:** Execute a leitura do arquivo normativo correspondente utilizando a ferramenta `view_file`.
4. **Verificar ADRs Relacionados:** Caso a tarefa envolva decisões estruturais, verifique os ADRs indicados para respeitar as decisões arquiteturais prévias.
5. **Avaliar Consulta ao AI Advisor (Segundo Cérebro):** Se a tarefa demandar decisão arquitetural, proposta técnica de alto impacto, resolução de ambiguidade, mitigação de risco de runtime, análise de incidente ou comparação de alternativas concorrentes, avalie o acionamento consultivo do Advisor (`consult_advisor` via `chatgpt-advisor-mcp` ou `ai-os/router/`). A consulta ocorre estritamente na fase de Design / Planejamento Técnico. O retorno é subsídio cognitivo não-confiável (`ADVISOR != AUTHORITY`). Toda recomendação (mesmo `PROCEED`) exige parada obrigatória em `AWAIT_HUMAN_REVIEW` antes de qualquer mutação. *(Ref: [`advisor-consultation-policy.md`](../ai-os/governance/advisor-consultation-policy.md), [`ADR-016`](../ai-os/decisions/ADR-016-orquestracao-cognitiva-chatgpt-advisor.md))*
6. **Checar Estado Mutável:** Se a solicitação depender de credenciais, IDs vigentes, instâncias ativas ou status de piloto, consulte [`CURRENT_STATE.md`](../ai-os/CURRENT_STATE.md).
7. **Seguir Runbook Operacional:** Se a tarefa for uma operação de deploy, migration de banco, ativação de WABA ou homologação de OTP, siga estritamente o Runbook correspondente passo a passo.
8. **Execução:** Proponha alterações somente após absorver as constraints e regras específicas do domínio e obter autorização humana explícita.

---

## 4. Mapa de Roteamento Especializado por Domínio

| Domínio Funcional / Técnico | Governança Normativa | Decisão Arquitetural (ADR) | Runbook / Operação |
|---|---|---|---|
| **Banco de Dados & Migrations** | [`database-rules.md`](../ai-os/governance/database-rules.md) | [`ADR-001`](../ai-os/decisions/ADR-001-banco-producao-oficial-unico.md), [`ADR-009`](../ai-os/decisions/ADR-009-governanca-migrations-git-soberano.md) | [`sql-migration-8-steps.md`](../ai-os/runbooks/sql-migration-8-steps.md) |
| **Segurança & SuperAdmins** | [`security-access.md`](../ai-os/governance/security-access.md) | [`ADR-002`](../ai-os/decisions/ADR-002-centralizacao-superadmins.md) | — |
| **RLS & Multi-Tenancy** | [`rls-multitenancy.md`](../ai-os/governance/rls-multitenancy.md) | [`ADR-003`](../ai-os/decisions/ADR-003-isolamento-multi-tenant-rls.md) | — |
| **Mensageria WhatsApp (Geral)** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | [`ADR-005`](../ai-os/decisions/ADR-005-deduplicacao-idempotencia-outbox.md), [`ADR-006`](../ai-os/decisions/ADR-006-contrato-estruturado-templates.md), [`ADR-013`](../ai-os/decisions/ADR-013-split-worker-roteamento-tipo-evento.md) | — |
| **WhatsApp — Identidade Telefônica** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | [`ADR-004`](../ai-os/decisions/ADR-004-identidade-canonica-telefonia.md) (E.164) | — |
| **WhatsApp — Proibição de Emuladores**| [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | [`ADR-008`](../ai-os/decisions/ADR-008-proibicao-emuladores-whatsapp-web.md) | — |
| **Push Notifications FCM & Áudio** | [`push-audio-rules.md`](../ai-os/governance/push-audio-rules.md) | [`ADR-007`](../ai-os/decisions/ADR-007-segregacao-canais-push-whatsapp.md) | — |
| **IA / OCR Encomendas** | [`ai-vision-rules.md`](../ai-os/governance/ai-vision-rules.md) | [`ADR-014`](../ai-os/decisions/ADR-014-visao-computacional-assistiva-segura.md) | — |
| **Visitantes & Convites** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | [`ADR-012`](../ai-os/decisions/ADR-012-unificacao-modulo-visitantes-convites.md) (`convites`) | — |
| **Encomendas & Baixa por Terceiro** | [`parcels-rules.md`](../ai-os/governance/parcels-rules.md) | [`ADR-006`](../ai-os/decisions/ADR-006-contrato-estruturado-templates.md) | — |
| **Módulo Documentos** | [`documents-rules.md`](../ai-os/governance/documents-rules.md) | — | — |
| **Módulo Contratos Inteligentes** | [`contracts-module.md`](../ai-os/governance/contracts-module.md) | — | — |
| **Padrões de UI/UX & Responsividade** | [`ui-ux-standards.md`](../ai-os/governance/ui-ux-standards.md) | — | — |
| **Resiliência Supabase / Auth Sessão**| — | [`ADR-010`](../ai-os/decisions/ADR-010-resiliencia-conexao-supabase-cliente.md), [`ADR-011`](../ai-os/decisions/ADR-011-desacoplamento-auth-sessao-perfil.md) | — |
| **Recuperação de Senha (OTP)** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | [`ADR-006`](../ai-os/decisions/ADR-006-contrato-estruturado-templates.md) | [`otp-homologation-checklist.md`](../ai-os/runbooks/otp-homologation-checklist.md) |
| **Ativação WABA & Billing Meta** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | — | [`waba-activation-checklist.md`](../ai-os/runbooks/waba-activation-checklist.md) |
| **Validação Pré-Deploy** | — | — | [`pre-deploy-validation.md`](../ai-os/runbooks/pre-deploy-validation.md) |
| **Topologia & Ambientes** | — | — | [`environments.md`](../ai-os/context/environments.md), [`modules-catalog.md`](../ai-os/context/modules-catalog.md) |
| **AI Advisor / Segundo Cérebro** | [`advisor-consultation-policy.md`](../ai-os/governance/advisor-consultation-policy.md) | [`ADR-016`](../ai-os/decisions/ADR-016-orquestracao-cognitiva-chatgpt-advisor.md) | [`advisor-consultation-runbook.md`](../ai-os/runbooks/advisor-consultation-runbook.md) |

---

## 5. Diretrizes Específicas de Navegação

### 5.1. Consulta a ADRs
Quando uma solicitação envolver refatoração arquitetural, mudança de contratos públicos ou introdução de novos provedores, consulte os ADRs aplicáveis. Os ADRs não substituem a governança normativa; fornecem as justificativas históricas e os limites acordados de engenharia.

### 5.2. Consulta a Runbooks
Operações de banco de dados, homologação de canais de mensageria, deploys ou ativações em produção exigem conformidade estrita aos procedimentos prescritos nos runbooks. É proibido executar migrations ou deploys sem validação prévia dos checklists operacionais.

### 5.3. Tratamento de Estado Atual (`CURRENT_STATE.md`)
O arquivo [`CURRENT_STATE.md`](../ai-os/CURRENT_STATE.md) contém o **estado transitório do ambiente** (identificadores de telefone, WABA IDs, instâncias em teste, status do Piloto Real Park e dívidas técnicas). Essas informações são mutáveis e **NÃO devem ser interpretadas como regras de negócio permanentes**.

### 5.4. Isolamento do Baseline Histórico (`Archive`)
O arquivo [`ai-os/archive/legacy-agents-monolith-baseline.md`](../ai-os/archive/legacy-agents-monolith-baseline.md) é uma **âncora de segurança, histórico frio e referência para rollback**. Ele **NÃO deve ser carregado automaticamente** nas rotinas operacionais padrão do agente. Sua consulta é restrita a auditorias forenses ou investigação de eventuais perdas semânticas.

### 5.5. Papel e Limites do AI Advisor (Segundo Cérebro)
O ChatGPT Advisor (`chatgpt-advisor-mcp`) atua exclusivamente como **segundo cérebro analítico e consultivo**:
- **Axioma Fundamental:** `ADVISOR != AUTHORITY != APPROVER != EXECUTOR`.
- **Proibição de Semântica Autoritativa:** É expressamente vedado o uso de expressões como "ChatGPT aprovou", "Advisor autorizou", "AI aprovou" ou "PROCEED autorizado". O parecer do Advisor é estritamente subsídio cognitivo à deliberação humana.
- **Invariante `PROCEED != EXECUTE`:** A recomendação `PROCEED` atesta unicamente a ausência de objeção lógica na análise do modelo; **jamais constitui aprovação ou autorização de mutação**. Toda tarefa que demandar mutação técnica de código, banco de dados ou infraestrutura deve parar obrigatoriamente no estado `AWAIT_HUMAN_REVIEW`.
- **Orçamento e Loops:** Teto rígido de 2 consultas por tarefa/subtask. Loops recursivos de reconsulta são terminantemente proibidos.
- **Roteamento Determinístico:** O Consultation Decision Router (`ai-os/router/decision-router.js`) classifica tarefas entre `CONSULT_REQUIRED` e `CONSULT_NOT_REQUIRED`. Tarefas puramente mecânicas, DDLs já especificados ou testes prontos NÃO devem consultar o Advisor.
*(Ref: [`advisor-consultation-policy.md`](../ai-os/governance/advisor-consultation-policy.md), [`ADR-016`](../ai-os/decisions/ADR-016-orquestracao-cognitiva-chatgpt-advisor.md), [`advisor-consultation-runbook.md`](../ai-os/runbooks/advisor-consultation-runbook.md), [`ai-os/router/README.md`](../ai-os/router/README.md))*

---

## 6. Protocolo de Fallback e Segurança Operacional

Caso uma regra técnica específica pareça ausente ou ambígua durante a execução:

1. **NÃO INVENTAR:** É estritamente proibido inventar regras, valores, configurações ou comportamentos não documentados.
2. **NÃO ASSUMIR:** Não faça inferências destrutivas ou suposições sobre convenções de código sem respaldo explícito.
3. **ORDEM DE RESOLUÇÃO:**
   - 1º: Verificar o arquivo de **Governance** correspondente;
   - 2º: Verificar os **ADRs** do domínio;
   - 3º: Verificar os **Runbooks** operacionais;
   - 4º: Verificar a topologia em **Context**;
   - 5º: Verificar o estado presente em **CURRENT_STATE**;
   - 6º: Em caso extremo de dúvida histórica, consultar o baseline arquivado em **Archive**.
4. **PARADA DE SEGURANÇA (STOP / HUMAN REVIEW):** Se a ambiguidade persistir ou houver risco de regressão em produção, **INTERROMPA A EXECUÇÃO** e solicite instrução humana formal.

---

## 7. Baseline Oficial — Base Cadastral Unificada
### Ciclo 3B → 3C.7-B: Bloqueio · Inativação · Novo Vínculo · Histórico 360º

> **STATUS:** `🟢 CONCLUÍDO` · `🟢 HOMOLOGADO` · `🔒 FROZEN` · `🔒 OFFICIAL BASELINE`  
> **DATA DE CONGELAMENTO:** 25/09/2026  
> **ESCOPO TÉCNICO:** Gates 3B, 3B.2, 3C.3, 3C.4, 3C.5, 3C.7 e 3C.7-B.

#### A. Base Cadastral
- **Visão Geral:** Gestão centralizada de residentes no módulo administrativo `/admin/moradores`, unificando os estados do ciclo de vida do morador.
- **Indicadores (KPIs):** Contadores reativos em tempo real para Total, Ativos, Pendentes, Inativos e Bloqueados.
- **Filtros e Cards:** Filtros rápidos por status de aprovação / vínculo e filtro por bloco; listagem otimizada em batch (superando limites do PostgREST sem truncamento).
- **Página 360º (`/admin/moradores/[id]`):** Visão administrativa detalhada contendo dados cadastrais, crachá de identificação, bloco de ocupação atual (`Ocupação Atual`), bloco de histórico de moradias encerradas (`Ocupação Anterior`), linha do tempo de auditoria administrativa (`Histórico Administrativo`) e ações operacionais com modais contextuais.

#### B. Status Cadastrais Canônicos
- **Ativo:** Morador aprovado (`status_aprovacao = 'aprovado'`, `bloqueado = false`) com vínculo residencial ativo em `public.unidade_perfil`.
- **Pendente:** Auto-cadastro aguardando validação pela administração (`status_aprovacao = 'pendente'`).
- **Bloqueado:** Acesso suspenso administrativamente (`bloqueado = true` e `status_aprovacao = 'bloqueado'`).
- **Inativo:** Ex-morador sem vínculo residencial vigente (`status_aprovacao = 'inativo'`), decorrente de mudança ou desvinculação administrativa.
- **Rejeitado/Reprovado:** Cadastro não aceito pela administração (`status_aprovacao = 'rejeitado'`).

#### C. Bloqueio e Reativação Administrativa (Gate 3B)
- **Bloqueio:** Operação que define `bloqueado = true` e `status_aprovacao = 'bloqueado'`. Impede login e revoga acessos imediatos.
- **Reativação:** Ação de desbloqueio que restaura `bloqueado = false` e `status_aprovacao = 'aprovado'`. Mantém os vínculos inalterados.

#### D. Inativação Canônica de Morador (Gate 3C.3 / 3C.5)
- **Encerramento de Vínculo:** Executada exclusivamente pela RPC transacional `public.admin_inativar_morador`. Encerra o vínculo ativo (`status = 'inativo'`, `data_saida = p_data_saida`), limpa campos desnormalizados transitórios (`bloco_txt`, `apto_txt`) e marca o perfil como `status_aprovacao = 'inativo'`.
- **Preservação de Integridade:** Preserva o registro físico do perfil em `public.perfil` e o histórico completo em `public.unidade_perfil`. Não equivale a bloqueio punitivo.
- **Auditoria Obrigatória:** Registra evento formal `UNIT_INACTIVATED` na tabela `public.perfil_audit_log` com snapshot de `estado_anterior` e `estado_posterior`.

#### E. Retorno de Morador / Novo Vínculo Residencial (Gate 3C.7)
- **Regra Soberana:** Retorno = Novo Vínculo / Novo Período (`INSERT` de novo registro em `public.unidade_perfil`).
- **Imutabilidade Histórica:** Jamais executa `UPDATE` de status em vínculo histórico inativo. O histórico anterior permanece permanentemente congelado e intacto.
- **Restauração de Perfil:** A RPC `public.admin_criar_vinculo_morador` atualiza atomicamente o perfil para `status_aprovacao = 'aprovado'`, reconecta `bloco_txt` e `apto_txt`, e registra evento `UNIT_LINK_CREATED` em `public.perfil_audit_log`.

#### F. Regra Temporal Canônica e Hardening (Gate 3C.7-B)
- **Mesma Unidade Anterior:** Para o mesmo par `perfil_id + unidade_id`, a nova data de entrada deve ser estritamente posterior à última data de saída (`data_saida >= p_data_entrada` é rejeitado pela RPC com mensagem amigável).
- **Sugestão Automática no Modal:** Ao selecionar a mesma unidade ocupada anteriormente, o modal sugere automaticamente o dia seguinte (`D+1`) calculado de forma determinística sobre data civil (livre de shifts UTC).
- **Validação Client-Side:** O modal bloqueia confirmações com datas anteriores ou iguais à data de saída da mesma unidade.
- **Unidade Distinta:** Ao selecionar unidade diferente, a restrição temporal específica da unidade anterior não se aplica.
- **Evento de Auditoria de Correção:** Eventos de retificação de data são documentados via `UNIT_LINK_ENTRY_DATE_CORRECTED` preservando o evento original.

#### G. Histórico Residencial e Administrativo
- **Histórico de Ocupação:** Exibe na Página 360º todos os períodos passados e presentes (bloco, apto, data de entrada e data de saída formatadas).
- **Histórico Administrativo:** Exibe a linha do tempo de ações administrativas executadas por operadores (Inativações, Criação de Vínculos, Correções, Bloqueios e Desbloqueios) com motivos e datas.

#### H. Autenticação e Proteções Sistêmicas (Gate 3C.4)
- **Perfil Inativo:** Não possui acesso às rotas residenciais nem operacionais comuns. No Web App é redirecionado para `/inactive-account`; no Flutter emite `AuthState.inactiveAccount` e navega para `InactiveAccountScreen`.
- **Retorno / Recuperação de Acesso:** Ao receber um novo vínculo aprovado, recupera acesso pleno de forma transparente pelas credenciais e fluxos nativos existentes.
- **Inibição de FCM:** Perfis com status inativo têm persistência e atualização de tokens FCM ignoradas, prevenindo envio inadvertido de notificações.

#### I. Multi-Tenancy e Isolamento RLS
- **Isolamento Mandatório:** `condominio_id` é validado estritamente no backend/RPCs a partir do contexto do operador e das unidades do condomínio, jamais confiado cegamente do payload do cliente.
- **RLS em Reservas e Módulos:** Políticas RLS e rotas de API garantem que apenas moradores com `status_aprovacao = 'aprovado'` e `bloqueado = false` criem reservas ou interajam com áreas comuns.

#### J. Notificações e Desacoplamento (Gate 3B.2)
- **Trigger `tr_fn_perfil_approved`:** Dispara a Edge Function `approval-notify` (WhatsApp/Push) SOMENTE na transição estrita `OLD.status_aprovacao = 'pendente' AND NEW.status_aprovacao = 'aprovado'`.
- **Transições Silenciosas:** Reativações (`bloqueado` → `aprovado`) e novos vínculos de ex-moradores (`inativo` → `aprovado`) são silenciosas, não gerando spam de boas-vindas. Credenciais são obtidas dinamicamente via Supabase Vault.

#### K. Segurança Operacional e Transacionalidade
- **RPCs `SECURITY DEFINER`:** `admin_inativar_morador` e `admin_criar_vinculo_morador` executam com `SET search_path TO 'public'` e checagem estrita de permissões (`system_superadmins` ou perfil com papel de síndico/administrador no condomínio).
- **Atomicidade e Integridade:** Todas as mutações de perfil, vínculo e audit log ocorrem dentro da mesma transação PostgreSQL.

#### L. Dívidas Técnicas Sob Observação
- **Policy Legada de Insert em `unidade_perfil`:** A policy `Permitir inserção de perfil em unidade para o próprio condom` permanece identificada como excessivamente permissiva (`WITH CHECK (true)`). Não foi alterada neste ciclo para mitigar riscos de regressão em fluxos legados e está catalogada no AI-OS para hardening futuro.

#### M. Portal do Morador (Privacidade)
- **Segregação de Auditoria:** O histórico administrativo de auditoria (`perfil_audit_log`) destina-se exclusivamente a síndicos e administradores no painel de gestão. É terminantemente vedada a sua exibição no Portal do Morador ou aplicativo móvel do morador.

---

## TRACEABILITY

| Bloco do Loader Operacional | Fonte Primária no AI-OS | Origem no Monólito / Gate 5.1 |
|---|---|---|
| **Identificação do AI-OS** | [`ai-os/README.md`](../ai-os/README.md) | Gate 5.1 (Seção 3 e 4) |
| **Invariante 1 (Banco Único)** | [`database-rules.md`](../ai-os/governance/database-rules.md), [`ADR-001`](../ai-os/decisions/ADR-001-banco-producao-oficial-unico.md) | `.agents/AGENTS.md:L2070-L2190` |
| **Invariante 2 (RLS Multi-Tenant)** | [`rls-multitenancy.md`](../ai-os/governance/rls-multitenancy.md), [`ADR-003`](../ai-os/decisions/ADR-003-isolamento-multi-tenant-rls.md) | `.agents/AGENTS.md:L1182-L1237` |
| **Invariante 3 (SuperAdmin)** | [`security-access.md`](../ai-os/governance/security-access.md), [`ADR-002`](../ai-os/decisions/ADR-002-centralizacao-superadmins.md) | `.agents/AGENTS.md:L73-L84` |
| **Invariante 4 (WhatsApp Anti-Marketing)** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md), [`ADR-007`](../ai-os/decisions/ADR-007-segregacao-canais-push-whatsapp.md) | `.agents/AGENTS.md:L1-L18`, `L1042-L1062` |
| **Invariante 5 (Git Soberano)** | [`sql-migration-8-steps.md`](../ai-os/runbooks/sql-migration-8-steps.md), [`ADR-009`](../ai-os/decisions/ADR-009-governanca-migrations-git-soberano.md) | `.agents/AGENTS.md:L369-L408` |
| **Protocolo de Consulta** | Gate 5.1 (Seções 6 e 7) | Gate 5.1 |
| **Mapa de Roteamento** | `ai-os/governance/*`, `decisions/*`, `runbooks/*` | Matriz de Cobertura Gate 4.4.4 |
| **Diretrizes de Navegação** | Gate 5.1 (Seções 5, 8, 9, 10) | Gate 5.1 |
| **Fallback e Parada** | Gate 5.1 (Seções 11 e 12) | Gate 5.1 |
| **AI Advisor (Segundo Cérebro)** | [`advisor-consultation-policy.md`](../ai-os/governance/advisor-consultation-policy.md), [`ADR-016`](../ai-os/decisions/ADR-016-orquestracao-cognitiva-chatgpt-advisor.md), [`advisor-consultation-runbook.md`](../ai-os/runbooks/advisor-consultation-runbook.md) | Gate 7.1.3 e Gate 7.1.4 |
